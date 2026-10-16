{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Archive
import Control.Concurrent (getNumCapabilities, setNumCapabilities)
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM, forM_, replicateM, unless)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.List (sort)
import GHC.Clock (getMonotonicTimeNSec)
import GHC.IO.Encoding (setLocaleEncoding)
import Huffman
import System.Environment (getArgs)
import qualified System.Directory
import System.Exit (die)
import System.Mem (performGC)
import System.IO (hSetEncoding, stdout, stderr, utf8)
import Text.Printf (printf)
import Text.Read (readMaybe)
import WorkerPool

compress :: Int -> [(FilePath,BS.ByteString)] -> IO [Entry]
compress count = parallelMap count (\(name,bytes) -> Entry name (encode bytes))

positive :: String -> IO Int
positive value = case readMaybe value of
  Just n | n > 0 && n <= 256 -> pure n
  _ -> die "Worker count must be between 1 and 256"

main :: IO ()
main = do
  setLocaleEncoding utf8
  mapM_ (`hSetEncoding` utf8) [stdout,stderr]
  args <- getArgs
  case args of
    "pack":n:target:paths -> do
      count <- positive n
      inputs <- loadFiles paths
      outputExists <- doesFileExist' target
      unless (not outputExists) (die "Archive already exists")
      entries <- compress count inputs
      BL.writeFile target (packArchive entries)
      printf "Packed %d files using %d workers.\n" (length entries) count
    ["unpack",source,target] -> do
      bytes <- BL.readFile source
      entries <- either die pure (unpackArchive bytes)
      extractArchive target entries
      printf "Restored %d files; CRC32 verified.\n" (length entries)
    ["list",source] -> do
      bytes <- BL.readFile source
      entries <- either die pure (unpackArchive bytes)
      forM_ entries $ \(Entry name item) -> printf "%s\t%d bytes\t%d bits\n" name (originalSize item) (bitLength item)
    "benchmark":maxCount:paths -> do
      count <- positive maxCount
      inputs <- loadFiles paths >>= evaluate . force
      available <- getNumCapabilities
      printf "# files=%d bytes=%d initial_capabilities=%d repetitions=3\n" (length inputs) (sum (map (BS.length . snd) inputs)) available
      _ <- compress 1 inputs -- warm-up, excluded
      let counts = filter (<=count) [1,2,4,8,16,32,64,128,256]
      measurements <- forM counts $ \workers -> do
        setNumCapabilities workers
        samples <- replicateM 3 $ do
          performGC
          start <- getMonotonicTimeNSec
          result <- compress workers inputs
          stop <- getMonotonicTimeNSec
          forM_ (zip inputs result) $ \((_,original), Entry _ item) ->
            unless (decode item == Right original) (die "Benchmark round-trip mismatch")
          pure (fromIntegral (stop-start) / 1e9 :: Double)
        pure (workers, sort samples !! 1)
      putStrLn "workers,median_seconds,speedup,efficiency"
      let baseline = snd (head measurements)
      forM_ measurements $ \(workers,seconds) ->
        printf "%d,%.6f,%.4f,%.4f\n" workers seconds (baseline/seconds) (baseline/seconds/fromIntegral workers)
    _ -> die "Usage: lab2 pack WORKERS ARCHIVE FILE... | unpack ARCHIVE DIR | list ARCHIVE | benchmark MAX_WORKERS FILE...\nCompile with -O2 -threaded -rtsopts; run with +RTS -N4 -RTS."

doesFileExist' :: FilePath -> IO Bool
doesFileExist' = System.Directory.doesPathExist
