{-# LANGUAGE OverloadedStrings #-}
module TextAnalysis
  ( Character(..), WordToken(..), Punctuation(..), Element(..)
  , Sentence(..), Document(..), parseDocument, normalizeSpaces
  , sentenceWords, analyze, renderAnalysis
  ) where

import Data.Char (isAlpha, isDigit, isSpace)
import Data.List (foldl')
import qualified Data.Set as S
import qualified Data.Text as T

newtype Character = Character Char deriving (Eq, Show)
newtype WordToken = WordToken T.Text deriving (Eq, Ord, Show)
newtype Punctuation = Punctuation Character deriving (Eq, Show)
data Element = WordElement WordToken | PunctuationElement Punctuation
  deriving (Eq, Show)
data Sentence = Sentence { sentenceText :: T.Text, elements :: [Element] }
  deriving (Eq, Show)
newtype Document = Document [Sentence] deriving (Eq, Show)

normalizeSpaces :: T.Text -> T.Text
normalizeSpaces = T.unwords . T.words

canonical :: T.Text -> T.Text
canonical = T.toCaseFold . T.map (\c -> if c `elem` ['\x2019', '\x02bc'] then '\'' else c)

-- Apostrophes and hyphens belong to a word only between letters.
tokenize :: T.Text -> [Element]
tokenize = go . T.unpack
  where
    go [] = []
    go (c:cs)
      | isSpace c = go cs
      | isAlpha c = let (word, rest) = takeWord [c] cs
                    in WordElement (WordToken (canonical (T.pack word))) : go rest
      | otherwise = PunctuationElement (Punctuation (Character c)) : go cs
    takeWord acc [] = (reverse acc, [])
    takeWord acc allChars@(c:cs)
      | isAlpha c = takeWord (c:acc) cs
      | c `elem` ['\'', '\x2019', '\x02bc', '-'], n:_ <- cs, isAlpha n =
          takeWord (n:c:acc) (tail cs)
      | otherwise = (reverse acc, allChars)

-- A run of .!? ends one sentence; a decimal point between digits does not.
parseDocument :: T.Text -> Document
parseDocument input = Document (map make (split [] [] (T.unpack (normalizeSpaces input))))
  where
    make chars = let t = T.strip (T.pack chars) in Sentence t (tokenize t)
    split acc current [] = reverse (if null current then acc else reverse current : acc)
    split acc current (c:cs)
      | c `elem` (".!?" :: String), not (decimal current c cs) =
          let (marks, rest) = span (`elem` (".!?\"'»”)]}" :: String)) cs
              finished = reverse current ++ c:marks
          in split (finished:acc) [] (dropWhile isSpace rest)
      | otherwise = split acc (c:current) cs
    decimal (previous:_) '.' (next:_) = isDigit previous && isDigit next
    decimal _ _ _ = False

sentenceWords :: Sentence -> [WordToken]
sentenceWords sentence = [word | WordElement word <- elements sentence]

-- Distinct words from the first sentence absent from every later sentence.
analyze :: Document -> [WordToken]
analyze (Document []) = []
analyze (Document (first:rest)) =
  let elsewhere = S.fromList (concatMap sentenceWords rest)
      add (seen,answer) word
        | S.member word elsewhere || S.member word seen = (seen,answer)
        | otherwise = (S.insert word seen,word:answer)
  in reverse (snd (foldl' add (S.empty,[]) (sentenceWords first)))

renderAnalysis :: Document -> T.Text
renderAnalysis document@(Document sentences) =
  let findings = analyze document
      showT = T.pack . show
      heading = ["Речень: " <> showT (length sentences)]
      rows = case findings of
        [] -> ["Слова першого речення, якого немає в інших, не знайдено."]
        WordToken word:_ -> ["Слово першого речення, якого немає в інших: " <> word,
          "Усі відповідні слова: " <> T.intercalate ", " [w | WordToken w <- findings]]
      source = [showT i <> ". " <> sentenceText s | (i,s) <- zip [1 :: Int ..] sentences]
  in T.unlines (heading ++ rows ++ ["", "Нормалізований текст:"] ++ source)
