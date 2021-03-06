{-# LANGUAGE TypeFamilies, MultiParamTypeClasses #-}

-- An elevator which can move and down and serve floors.
--
-- The example appears in the first Golog paper and Reiter's book (with
-- additional Open and Close actions):
--
--  GOLOG: A Logic Programming Language for Dynamic Domains. Levesque, H.;
--  Reiter, R.; Lesperance, Y.; Lin, F.; and Scherl, R. Journal of Logic
--  Programming, 31:59--84. 1997. 
--
--  Knowledge in Action. Logical Foundations for Specifying and Implementing
--  Dynamical Systems. Reiter, R. MIT Press, 2001. 
--
module Main where

import Prelude hiding (floor, until)
import Data.List (delete)
import Data.Time.Clock
import Golog.Interpreter
import Golog.Macro
import Golog.Util

-- Floors are identified by a integer number.
type Floor = Int

floors :: [Floor]
floors = [0..1001]

-- There are three actions: Up and Down move the elevator to a floor,
-- TurnOff switches off the call-button. Test is a test-action, because
-- they are not part of our Golog interpreter but need to be simulated
-- in the BAT.
data A = Up Floor | Down Floor | TurnOff Floor | Test (Sit A -> Bool)

-- This declaration is necessary to use the 'test' helper function from
-- Golog.Macro.
instance TestAction A where
   testAction = Test

-- Our situation is no situation in Reiter's sense. Instead we maintain a state
-- which is progressed by 'do_' when an action is executed.
instance BAT A where
   data Sit A = State { floor :: Floor, onButtons :: [Floor] }

   s0 = State { floor = 7, onButtons = take ((length floors - 1) `div` 2) [3,5..] }

   do_ (Up n)      s = s{floor = n}
   do_ (Down n)    s = s{floor = n}
   do_ (TurnOff n) s = s{onButtons = delete n (onButtons s)}
   do_ (Test _)    s = s

   poss (Up n)      s = n > floor s
   poss (Down n)    s = n < floor s
   poss (TurnOff n) s = n `elem` onButtons s
   poss (Test phi)  s = phi s

on :: Floor -> Sit A -> Bool
on n s = n `elem` onButtons s

goFloor :: (Sit A -> Floor) -> Prog A
goFloor n = choice [ primf (Up . n)
                   , test (\s -> floor s == n s)
                   , primf (Down . n) ]

control :: Prog A
control = until (null.onButtons)
                (pickInf floors (\n -> test (\s -> n `elem` onButtons s) `Seq`
                                       goFloor (const n) `Seq`
                                       primf (TurnOff . const n))) `Seq`
                --(pickInf [0..] (\i -> test (\s -> i < length (onButtons s)) `Seq`
                --                      goFloor (n i) `Seq`
                --                      primf (TurnOff . n i))) `Seq`
          goFloor (const 1)
   where n i s = onButtons s !! i

-- The IOBAT typeclass is for defining real world effects of actions. We use
-- this here to just print the state.
instance IOBAT A IO where
   syncA a s = putStr as >> return s'
      where s' = do_ a s
            as = case a of Up      n -> "Up "++ show n ++ "; "
                           Down    n -> "Down "++ show n ++ "; "
                           TurnOff n -> "TurnOff "++ show n ++ "; "
                           Test _    -> ""
{-
   syncA a s = maybe (return s') (\str -> putStrLn str >> return s') as
      where s' = do_ a s
            as = case a of Up      n -> Just $ "Up "++ show n ++":      "++ info
                           Down    n -> Just $ "Down "++ show n ++":    "++ info
                           TurnOff n -> Just $ "TurnOff "++ show n ++": "++ info
                           Test _    -> Nothing
            info = "Floor = "++ show (floor s') ++", On-buttons = "++ show (onButtons s')
-}

main :: IO ()
main = do t1 <- getCurrentTime
          Just c1 <- dooIO (const (Offline DFS)) (treeNDIO control s0)
          t2 <- getCurrentTime
          putStrLn ""
          putStrLn $ show (diffUTCTime t2 t1)
          --let Just c1 = dooBFS' (treeNDIO control s0)
          --_ <- sync c1 -- prints all states
          return ()

