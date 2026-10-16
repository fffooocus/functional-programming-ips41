{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (forM_, unless)
import Data.Either (isLeft)
import Department
import Gaussian
import TextAnalysis
import WorkerPool

assert :: String -> Bool -> IO ()
assert name condition = unless condition (error ("FAIL: " ++ name)) >> putStrLn ("PASS: " ++ name)

checkSolution :: String -> Int -> LinearSystem -> [Double] -> IO ()
checkSolution name workers system expected = do
  result <- solveParallel workers system
  assert name (case result of
    Left _ -> False
    Right values -> length values == length expected &&
                    maximum (0:zipWith (\a b -> abs (a-b)) values expected) < 1e-9 &&
                    relativeResidual system values < 1e-10)

main :: IO ()
main = do
  let classic = LinearSystem [[2,1,-1],[-3,-1,2],[-2,1,2]] [8,-11,-3]
  checkSolution "Gaussian classic one worker" 1 classic [2,3,-1]
  checkSolution "Gaussian classic four workers" 4 classic [2,3,-1]
  checkSolution "Pivot row exchange" 4 (LinearSystem [[0,2],[1,3]] [4,7]) [1,2]
  checkSolution "Single equation" 4 (LinearSystem [[2]] [6]) [3]
  checkSolution "Equation scaling" 2 (LinearSystem [[1e-20,0],[0,1e20]] [2e-20,3e20]) [2,3]
  forM_ [1,2,3,5,8,16,32] $ \n -> checkSolution ("Generated known solution " ++ show n) 4 (generateSystem n) (expectedSolution n)
  one <- solveParallel 1 (generateSystem 25)
  four <- solveParallel 4 (generateSystem 25)
  assert "Sequential and parallel agreement" (one == four)
  singular <- solveParallel 2 (LinearSystem [[1,2],[2,4]] [3,6])
  assert "Singular system rejected" (isLeft singular)
  inconsistent <- solveParallel 2 (LinearSystem [[1,2],[2,4]] [3,7])
  assert "Inconsistent system rejected" (isLeft inconsistent)
  empty <- solveParallel 2 (LinearSystem [] [])
  assert "Empty matrix rejected" (isLeft empty)
  badShape <- solveParallel 2 (LinearSystem [[1,2]] [1])
  assert "Non-square matrix rejected" (isLeft badShape)
  badRhs <- solveParallel 2 (LinearSystem [[1]] [])
  assert "Invalid RHS rejected" (isLeft badRhs)
  notFinite <- solveParallel 2 (LinearSystem [[0/0]] [1])
  assert "Non-finite matrix rejected" (isLeft notFinite)
  noWorkers <- solveParallel 0 classic
  assert "Zero solver workers rejected" (isLeft noWorkers)
  assert "Parse matrix comments" (parseSystem "# matrix\n2\n1 0 2\n0 1 3\n" == Right (LinearSystem [[1,0],[0,1]] [2,3]))
  assert "Malformed matrix rejected" (isLeft (parseSystem "2\n1 2\n3 4"))
  assert "Invalid matrix token rejected" (isLeft (parseSystem "1\nx 2"))
  ordered <- parallelMap 4 (\n -> n*n) [1::Int ..30]
  assert "Worker result order" (ordered == map (\n -> n*n) [1..30])
  emptyPool <- parallelMap 4 id ([] :: [Int])
  assert "Worker empty input" (null emptyPool)
  workerError <- try (parallelMap 2 (\n -> if n == (2::Int) then error "expected" else n) [1,2,3]) :: IO (Either SomeException [Int])
  assert "Worker exceptions propagate" (isLeft workerError)
  let analyzeText = analyze . parseDocument
  assert "First sentence unique word" (analyzeText "Haskell є чистою мовою. Haskell підтримує типи. Мовою описують код." == map WordToken ["є","чистою"])
  assert "Empty text" (null (analyzeText " \t\n "))
  assert "No exclusive word" (null (analyzeText "Код працює. Працює код."))
  assert "First sentence order" (analyzeText "Бета альфа. Гама." == map WordToken ["бета","альфа"])
  assert "Deduplicate first sentence" (analyzeText "Код код код! Тип." == [WordToken "код"])
  assert "Single sentence" (analyzeText "Тип код." == map WordToken ["тип","код"])
  assert "Punctuation only" (null (analyzeText "... !!!"))
  assert "Case folding" (null (analyzeText "HASKELL. Haskell?"))
  assert "Apostrophe normalization" (null (analyzeText "Пам’ять. ПАМ'ЯТЬ."))
  assert "Whitespace normalization" (normalizeSpaces " a\t  b\n c " == "a b c")
  let Document decimals = parseDocument "Число 3.14 є значенням. Інше речення?!"
  assert "Decimal and grouped punctuation" (length decimals == 2)
  assert "Word absent from every later sentence" (analyzeText "Код тип слово. Тип. Код." == [WordToken "слово"])
  let draft = ResourceDraft "Програма" "1.0" "Анотація" 1 1 "2026-10-01" Nothing
  assert "Valid software record" (validate draft == Right ())
  assert "Invalid resource date" (isLeft (validate (draft {draftStart="2026-02-30"})))
  assert "Invalid resource period" (isLeft (validate (draft {draftEnd=Just "2026-09-01"})))
  assert "Blank title rejected" (isLeft (validate (draft {draftTitle="  "})))
  assert "Blank version rejected" (isLeft (validate (draft {draftVersion=""})))
  assert "SQL hostile literal encoded" (sqlText "x'; DROP TABLE resources;--" == "CONVERT(X'78273b2044524f50205441424c45207265736f75726365733b2d2d' USING utf8mb4)")
  putStrLn "ALL TESTS PASSED"
