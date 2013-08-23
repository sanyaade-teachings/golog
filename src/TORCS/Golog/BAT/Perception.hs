{-# LANGUAGE TypeFamilies, MultiParamTypeClasses #-}

-- | Low-level BAT for perception.
-- Offline perception is done by simple simulation.
-- For that, however, we need the current 'CarControl', which is why the 'Sense'
-- action takes this as argument.
module TORCS.Golog.BAT.Perception (A, mkS0, sense, cs) where

import Control.Concurrent.SSem
import Data.IORef
import Data.Maybe (fromMaybe)
import Golog.Interpreter
import Golog.Macro
import TORCS.CarControl
import TORCS.CarState
import TORCS.Golog.Simulation

type TickDur = Double

data A = Sense CarControl (Maybe CarState) (Maybe TickDur)

instance BAT A where
   data Sit A = Sit {
      cs      :: CarState,
      cc      :: CarControl,
      tickDur :: TickDur,
      csRef   :: IORef CarState,
      ticker  :: SSem
   }

   s0 = Sit defaultState defaultControl tickDurInSec undefined undefined

   do_ (Sense cc' mcs' mt') s = s{cs = cs', cc = cc', tickDur = t'}
      where cs' = fromMaybe (simulateState tickDurInSec cc' (cs s)) mcs'
            t' = maybe (tickDur s) (\t -> (t + tickDur s) / 2) mt'

   poss _ _ = True

mkS0 :: IORef CarState -> SSem -> Sit A
mkS0 csRef' ticker' = s0{csRef = csRef', ticker = ticker'}

instance IOBAT A IO where
   syncA (Sense cc' Nothing Nothing) s =
      do wait (ticker s)
         cs' <- readIORef (csRef s)
         let t' = curLapTime cs' - curLapTime (cs s)
         return $ do_ (Sense cc' (Just cs') (Just t')) s
   syncA (Sense _ _ _) _ = error "syncA: unrefinable Sense"

tickDurInSec :: TickDur
tickDurInSec = 10 / 1000

sense :: CarControl -> Prog A
sense cc' = prim $ Sense cc' Nothing Nothing
