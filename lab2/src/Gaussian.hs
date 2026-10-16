{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE BangPatterns #-}
module Gaussian
  ( LinearSystem(..), SolveError(..), parseSystem, solveParallel
  , residual, relativeResidual, generateSystem, expectedSolution ) where

import Control.DeepSeq (NFData(..))
import Control.Monad (unless)
import Data.Array.Unboxed (UArray, (!), listArray, elems)
import Data.List (foldl', maximumBy)
import Data.Ord (comparing)
import GHC.Generics (Generic)
import Text.Read (readMaybe)
import WorkerPool (parallelMap)

data LinearSystem = LinearSystem { coefficients :: [[Double]], rightHandSide :: [Double] }
  deriving (Eq, Show, Generic)
instance NFData LinearSystem
data SolveError = InvalidSystem String | SingularSystem Int | NumericalFailure
  deriving (Eq, Show, Generic)
instance NFData SolveError
newtype Row = Row (UArray Int Double)
instance NFData Row where rnf (Row values) = values `seq` ()

finite :: Double -> Bool
finite value = not (isNaN value || isInfinite value)

validate :: LinearSystem -> Either SolveError Int
validate (LinearSystem matrix rhs) =
  let n = length matrix in
  if n == 0 || n > 2000 || length rhs /= n || any ((/=n) . length) matrix
  then Left (InvalidSystem "Expected a square system of order 1..2000")
  else if not (all finite (rhs ++ concat matrix))
  then Left (InvalidSystem "All values must be finite") else Right n

parseSystem :: String -> Either String LinearSystem
parseSystem input = case filter (not . null) (map (words . takeWhile (/='#')) (lines input)) of
  [rawN]:rows -> do
    n <- maybe (Left "Invalid matrix order") Right (readMaybe rawN :: Maybe Int)
    unless (n > 0 && n <= 2000 && length rows == n && all ((==n+1) . length) rows)
      (Left "Expected N rows containing N coefficients and one right-hand side")
    numbers <- mapM (mapM (\raw -> maybe (Left ("Invalid number: " ++ raw)) Right (readMaybe raw))) rows
    let system = LinearSystem (map init numbers) (map last numbers)
    either (Left . show) (const (Right system)) (validate system)
  _ -> Left "First line must contain N; next N lines contain augmented matrix rows"

-- Normalize equations, choose the largest pivot, and update rows concurrently.
-- Every elimination phase ends with a barrier before the next pivot is chosen.
solveParallel :: Int -> LinearSystem -> IO (Either SolveError [Double])
solveParallel workers system
  | workers < 1 || workers > 256 = pure (Left (InvalidSystem "Workers must be between 1 and 256"))
  | otherwise = case validate system of
      Left err -> pure (Left err)
      Right n -> do
        let matrix = coefficients system
            scales = map (maximum . map abs) matrix
        if any (==0) scales then pure (Left (SingularSystem 0)) else do
          let rows = zipWith3 (\values rhs scale -> Row (listArray (0,n) (map (/scale) (values ++ [rhs]))))
                              matrix (rightHandSide system) scales
          forward n 0 [] rows
  where
    at (Row row) index = row ! index
    good (Row row) = all finite (elems row)
    forward n k upper remaining
      | null remaining = pure (backSubstitute n upper [])
      | not (all good remaining) = pure (Left NumericalFailure)
      | otherwise = do
          let (pivotIndex,pivot) = maximumBy (comparing (abs . (`at` k) . snd)) (zip [0::Int ..] remaining)
              rest = take pivotIndex remaining ++ drop (pivotIndex+1) remaining
          if abs (at pivot k) <= 1e-12 then pure (Left (SingularSystem (k+1))) else do
            reduced <- parallelMap workers (eliminate n k pivot) rest
            forward n (k+1) (pivot:upper) reduced
    eliminate n k pivot row =
      let !factor = at row k / at pivot k
      in Row (listArray (0,n) [if j <= k then 0 else at row j - factor * at pivot j | j <- [0..n]])
    backSubstitute _ [] known = Right (map snd known)
    backSubstitute n (row:rows) known =
      let k = length rows
          total = foldl' (\acc (j,x) -> acc + at row j * x) 0 known
          !value = (at row n-total) / at row k
      in if finite value then backSubstitute n rows ((k,value):known) else Left NumericalFailure

residual :: LinearSystem -> [Double] -> Double
residual (LinearSystem matrix rhs) solution = maximum (0 : zipWith (\row b -> abs (sum (zipWith (*) row solution)-b)) matrix rhs)

relativeResidual :: LinearSystem -> [Double] -> Double
relativeResidual system@(LinearSystem matrix rhs) solution =
  let denominator = maximum (0:map (sum . map abs) matrix) * maximum (0:map abs solution) + maximum (0:map abs rhs)
  in if denominator == 0 then residual system solution else residual system solution / denominator

expectedSolution :: Int -> [Double]
expectedSolution n = [fromIntegral ((i `mod` 7)-3)+0.25 | i <- [0..n-1]]

generateSystem :: Int -> LinearSystem
generateSystem n =
  let row i = let off j = fromIntegral (((i*17+j*13) `mod` 19)-9)/10
                  diagonal = 1 + sum [abs (off j) | j <- [0..n-1], j /= i]
              in [if j == i then diagonal else off j | j <- [0..n-1]]
      matrix = map row [0..n-1]
      solution = expectedSolution n
  in LinearSystem matrix [sum (zipWith (*) values solution) | values <- matrix]
