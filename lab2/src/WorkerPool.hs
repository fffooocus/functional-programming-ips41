{-# LANGUAGE ScopedTypeVariables #-}
module WorkerPool (parallelMap) where

import Control.Concurrent
import Control.DeepSeq (NFData, force)
import Control.Exception
import Control.Monad (replicateM, replicateM_, forM_)
import Data.List (sortOn)

-- Fixed-size worker pool; results retain input order and exceptions propagate.
parallelMap :: forall a b. NFData b => Int -> (a -> b) -> [a] -> IO [b]
parallelMap requested transform inputs
  | requested < 1 = ioError (userError "Worker count must be positive")
  | null inputs = pure []
  | otherwise = do
      jobs <- newChan :: IO (Chan (Maybe (Int, a)))
      results <- newChan :: IO (Chan (Int, Either SomeException b))
      let workers = min requested (length inputs)
          worker = do
            job <- readChan jobs
            case job of
              Nothing -> pure ()
              Just (index, value) -> do
                result <- tryJust synchronous (evaluate (force (transform value)))
                writeChan results (index, result)
                worker
          synchronous err = case fromException err :: Maybe SomeAsyncException of
            Just _ -> Nothing
            Nothing -> Just err
      bracket (replicateM workers (forkIO worker)) (mapM_ killThread) $ \_ -> do
        forM_ (zip [0..] inputs) (writeChan jobs . Just)
        replicateM_ workers (writeChan jobs Nothing)
        completed <- replicateM (length inputs) (readChan results)
        mapM (either throwIO pure . snd) (sortOn fst completed)
