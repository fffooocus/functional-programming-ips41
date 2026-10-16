module Main (main) where

import Control.Concurrent (setNumCapabilities)
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM, forM_, replicateM, unless)
import Data.List (sort)
import Gaussian
import GHC.Clock (getMonotonicTimeNSec)
import System.Environment (getArgs)
import System.Exit (die)
import System.Mem (performGC)
import Text.Printf (printf)
import Text.Read (readMaybe)

positive :: Int -> String -> IO Int
positive limit value = case readMaybe value of
  Just n | n > 0 && n <= limit -> pure n
  _ -> die ("Expected integer between 1 and " ++ show limit)

solutionText :: LinearSystem -> [Double] -> String
solutionText system values = unlines
  ([printf "x%d = %.12g" i value | (i,value) <- zip [1::Int ..] values] ++
   [printf "max_absolute_residual = %.6e" (residual system values),
    printf "relative_residual = %.6e" (relativeResidual system values)])

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["solve",rawWorkers,file] -> run rawWorkers file Nothing
    ["solve",rawWorkers,file,"--output",destination] -> run rawWorkers file (Just destination)
    ["benchmark",rawSize,rawWorkers] -> do
      n <- positive 2000 rawSize
      count <- positive 256 rawWorkers
      system <- evaluate (force (generateSystem n))
      _ <- solveParallel 1 system >>= evaluate . force
      printf "# order=%d repetitions=3 partial_pivoting=true\n" n
      measurements <- forM (filter (<=count) [1,2,4,8,16,32,64,128,256]) $ \workers -> do
        setNumCapabilities workers
        samples <- replicateM 3 $ do
          performGC
          start <- getMonotonicTimeNSec
          result <- solveParallel workers system >>= evaluate . force
          stop <- getMonotonicTimeNSec
          values <- either (die . show) pure result
          unless (relativeResidual system values < 1e-10) (die "Residual check failed")
          unless (maximum (zipWith (\a b -> abs (a-b)) values (expectedSolution n)) < 1e-8)
            (die "Known-solution check failed")
          pure (fromIntegral (stop-start)/1e9 :: Double)
        pure (workers,sort samples !! 1)
      putStrLn "workers,median_seconds,speedup,efficiency"
      let baseline = snd (head measurements)
      forM_ measurements $ \(workers,seconds) ->
        printf "%d,%.6f,%.4f,%.4f\n" workers seconds (baseline/seconds) (baseline/seconds/fromIntegral workers)
    _ -> die "Usage: lab2 solve WORKERS MATRIX.txt [--output RESULT.txt] | benchmark SIZE MAX_WORKERS\nCompile with -O2 -threaded -rtsopts; run with +RTS -N4 -RTS."
  where
    run rawWorkers file destination = do
      workers <- positive 256 rawWorkers
      input <- readFile file
      system <- either die pure (parseSystem input)
      result <- solveParallel workers system
      values <- either (die . show) pure result
      let output = solutionText system values
      putStr output
      maybe (pure ()) (\target -> writeFile target output) destination
