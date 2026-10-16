module Main (main) where

import Control.Exception (IOException, try)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import qualified Data.ByteString as BS
import System.Environment (getArgs)
import System.Exit (die)
import System.IO (hSetEncoding, stdout, stderr, utf8)
import TextAnalysis

main :: IO ()
main = do
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  args <- getArgs
  case args of
    [path] -> run path Nothing
    [path, "--output", destination] -> run path (Just destination)
    _ -> die "Usage: lab3 INPUT_UTF8.txt [--output RESULT.txt]"
  where
    run path destination = do
      result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
      bytes <- either (die . show) pure result
      text <- either (die . ("Invalid UTF-8: " ++) . show) pure (TE.decodeUtf8' bytes)
      let output = renderAnalysis (parseDocument (T.dropWhile (== '\xfeff') text))
      TIO.putStr output
      case destination of
        Nothing -> pure ()
        Just target -> BS.writeFile target (TE.encodeUtf8 output)
