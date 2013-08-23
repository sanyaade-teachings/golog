{-# LANGUAGE TypeFamilies, MultiParamTypeClasses #-}

-- | Low-level BAT for automatic transmission.
module TORCS.Golog.BAT.GearBox (A, mkS0, transmission, sense, fillCc) where

import Data.IORef
import Golog.Interpreter
import Golog.Macro
import TORCS.CarControl
import TORCS.CarState

data A = Gear Int | Sense CarState

instance BAT A where
   data Sit A = Sit {
      cs       :: CarState,
      cc       :: CarControl,
      ccRef    :: IORef CarControl,
      lastTime :: Double
   }

   s0 = Sit defaultState defaultControl undefined 0

   do_ a@(Gear x)  s = s{cc = updateCc a (cc s),
                         lastTime = if x == gearCmd (cc s)
                                    then lastTime s
                                    else curLapTime (cs s)}
   do_ (Sense cs') s = s{cs = cs'}

   poss _ _ = True

mkS0 :: IORef CarControl -> Sit A
mkS0 ccRef' = s0{ccRef = ccRef'}

updateCc :: A -> CarControl -> CarControl
updateCc (Gear x)  cc' = cc'{gearCmd = x}
updateCc (Sense _) cc' = cc'

-- | Updates the given 'CarControl' with the portion controlled by this BAT.
-- That is, it sets the current 'gearCmd'.
fillCc :: Sit A -> CarControl -> CarControl
fillCc s cc' = cc'{gearCmd = gearCmd (cc s)}

instance IOBAT A IO where
   syncA a s = do cc' <- readIORef (ccRef s)
                  writeIORef (ccRef s) (updateCc a cc')
                  return $ do_ a s

-- | Performs a gear change if necessary. The necessity of gear changes depends
-- on the current RPM and is defined by a simple transmission table, i.e., if
-- certain thresholds of RPM are surpassed or fallen short of, one gear is
-- shifted up or down, respectively.
-- To thrashing, shifting up is only allowed after a certain time period has
-- passed since the last change.
transmission :: Prog A
transmission = primf action
   where action s = Gear $
            case rpms (gear (cs s)) of
                 Just (lo,hi) | rpm (cs s) < lo               -> gearDown (cs s)
                              | rpm (cs s) > hi && changeOk s -> gearUp (cs s)
                 _                                            -> gear (cs s)
         changeOk s = now s - lastTime s > 1 -- min duration before shifting up
         rpms 0     = Just (-1/0,    1)
         rpms 1     = Just (   0, 5000)
         rpms 2     = Just (2500, 6000)
         rpms 3     = Just (3000, 6000)
         rpms 4     = Just (3000, 6500)
         rpms 5     = Just (3500, 7000)
         rpms 6     = Just (3500,  1/0)
         rpms _     = Nothing
         gearUp     = (+1) . gear
         gearDown   = (+ (-1)) . gear
         now        = curLapTime . cs

-- | Informs the BAT about the new 'CarState'.
sense :: CarState -> Prog A
sense cs' = prim $ Sense cs'
