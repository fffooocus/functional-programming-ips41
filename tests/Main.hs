{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Archive
import Control.Exception (SomeException, try)
import Control.Monad (forM_, unless)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import Data.Either (isLeft)
import qualified Data.Text.Encoding as TE
import Department
import Huffman
import TextAnalysis
import WorkerPool

assert :: String -> Bool -> IO ()
assert name condition = unless condition (error ("FAIL: " ++ name)) >> putStrLn ("PASS: " ++ name)

main :: IO ()
main = do
  let samples = [BS.empty, BS.singleton 0, BS.replicate 10000 65,
                 BS.pack [0..255], BS.concat (replicate 100 (BS.pack [0..255])),
                 BC.pack "abracadabra", TE.encodeUtf8 "Функція обробляє пам’ять та значення.",
                 BS.pack (take 50000 (map (fromIntegral . (`mod` 256)) (iterate (\n -> (1103515245*n+12345) `mod` 2147483648) (7::Integer))))]
  forM_ (zip [1::Int ..] samples) $ \(i,input) ->
    assert ("Huffman round trip " ++ show i) (decode (encode input) == Right input)
  assert "CRC32 standard vector" (crc32 (BC.pack "123456789") == 0xcbf43926)
  let items = [Entry ("file" ++ show i ++ ".bin") (encode input) | (i,input) <- zip [1::Int ..] samples]
      archive = packArchive items
  assert "Archive serialization" (unpackArchive archive == Right items)
  assert "Archive empty" (unpackArchive (packArchive []) == Right [])
  assert "Archive magic validation" (isLeft (unpackArchive "invalid"))
  assert "Archive truncation" (isLeft (unpackArchive (BL.init archive)))
  assert "Archive trailing data" (isLeft (unpackArchive (archive <> "x")))
  assert "Archive duplicate names" (isLeft (unpackArchive (packArchive [head items,head items])))
  assert "Archive case collision" (isLeft (unpackArchive (packArchive [Entry "A" (encode "a"),Entry "a" (encode "b")])) )
  assert "Archive path traversal" (isLeft (unpackArchive (packArchive [Entry "../outside" (encode "a")])))
  assert "Windows reserved names" (all (not . validName) ["CON","LPT1.txt","a:b","a\\b","a.","a "])
  let damaged = (encode "abacabad") { checksum = 0 }
  assert "Checksum corruption detected" (isLeft (decode damaged))
  assert "Duplicate histogram rejected" (isLeft (decode ((encode "aa") {frequencies=[(65,1),(65,1)]})))
  assert "Truncated Huffman payload" (isLeft (decode ((encode "ababa") {payload=BS.empty})))
  result1 <- parallelMap 1 encode samples
  result4 <- parallelMap 4 encode samples
  assert "Parallel compression deterministic" (result1 == result4)
  ordered <- parallelMap 4 (\n -> n*n) [1::Int ..30]
  assert "Worker result order" (ordered == map (\n -> n*n) [1..30])
  empty <- parallelMap 4 id ([] :: [Int])
  assert "Worker empty input" (null empty)
  workerError <- try (parallelMap 2 (\n -> if n == (2::Int) then error "expected" else n) [1,2,3]) :: IO (Either SomeException [Int])
  assert "Worker exceptions propagate" (isLeft workerError)
  zero <- try (parallelMap 0 id [1::Int]) :: IO (Either SomeException [Int])
  assert "Zero workers rejected" (isLeft zero)
  let analyzeText = analyze . parseDocument
      (count, findings) = analyzeText "Код код код! Код працює. Новий код?"
  assert "Count sentences, not word occurrences" (count == 3 && findings == [Finding (WordToken "код") [1,2,3]])
  assert "Empty text" (analyzeText " \t\n " == (0,[]))
  assert "No repeated word" (fst (analyzeText "Один. Два.") == 1)
  assert "Punctuation only" (fst (analyzeText "... !!!") == 0)
  assert "Case folding" (fst (analyzeText "HASKELL. Haskell? haskell!") == 3)
  assert "Apostrophe normalization" (fst (analyzeText "Пам’ять. ПАМ'ЯТЬ.") == 2)
  assert "Whitespace normalization" (normalizeSpaces " a\t  b\n c " == "a b c")
  let Document decimals = parseDocument "Число 3.14 є значенням. Інше речення?!"
  assert "Decimal point and grouped punctuation" (length decimals == 2)
  assert "Sentence without terminator" (fst (analyzeText "код. код") == 2)
  assert "Unicode word preserved" (fst (analyzeText "Їжак. їжак.") == 2)
  assert "Tied maxima" (length (snd (analyzeText "тип код. Код тип.")) == 2)
  let draft = ResourceDraft "Назва" "Анотація" 1 1 "2026-10-01" Nothing
  assert "Valid resource" (validate draft == Right ())
  assert "Invalid resource date" (isLeft (validate (draft {draftStart="2026-02-30"})))
  assert "Invalid resource period" (isLeft (validate (draft {draftEnd=Just "2026-09-01"})))
  assert "Blank title rejected" (isLeft (validate (draft {draftTitle="  "})))
  assert "SQL literal encodes hostile input" (sqlText "x'; DROP TABLE resources;--" == "CONVERT(X'78273b2044524f50205441424c45207265736f75726365733b2d2d' USING utf8mb4)")
  putStrLn "ALL TESTS PASSED"
