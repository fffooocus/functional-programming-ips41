{-# LANGUAGE OverloadedStrings #-}
module Archive (Entry(..), packArchive, unpackArchive, validName, loadFiles, extractArchive) where

import Control.DeepSeq (NFData(..))
import Control.Monad (replicateM, unless, forM, forM_)
import Data.Binary.Get
import Data.Binary.Put
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Char (isControl, toLower)
import Data.List (nub)
import Huffman
import System.Directory
import System.FilePath
import System.IO.Error (catchIOError, isDoesNotExistError)

data Entry = Entry { entryName :: FilePath, entryData :: Encoded } deriving (Eq, Show)
instance NFData Entry where rnf (Entry name item) = rnf name `seq` rnf item

validName :: FilePath -> Bool
validName name = not (null name) && name `notElem` [".",".."] &&
  length name <= 240 && last name `notElem` ['.',' '] &&
  all (\c -> not (isControl c) && c `notElem` ("/\\:<>\"|?*" :: String)) name &&
  map toLower (takeWhile (/='.') name) `notElem`
    (["con","prn","aux","nul"] ++ [prefix ++ show n | prefix <- ["com","lpt"], n <- [1::Int ..9]])

packArchive :: [Entry] -> BL.ByteString
packArchive entries = runPut $ do
  putByteString "HFAR\x01"
  putWord32be (fromIntegral (length entries))
  forM_ entries $ \(Entry name item) -> do
    let filename = TE.encodeUtf8 (T.pack name)
    putWord16be (fromIntegral (BS.length filename))
    putByteString filename
    putWord64be (originalSize item)
    putWord16be (fromIntegral (length (frequencies item)))
    forM_ (frequencies item) $ \(byte,count) -> putWord8 byte >> putWord64be count
    putWord64be (bitLength item)
    putWord32be (checksum item)
    putByteString (payload item)

unpackArchive :: BL.ByteString -> Either String [Entry]
unpackArchive input = case runGetOrFail parser input of
  Left (_,offset,reason) -> Left ("Offset " ++ show offset ++ ": " ++ reason)
  Right (rest,_,entries)
    | not (BL.null rest) -> Left "Trailing data"
    | length names /= length (nub names) -> Left "Duplicate filenames"
    | otherwise -> Right entries
    where names = map (map toLower . entryName) entries
  where
    parser = do
      magic <- getByteString 5
      unless (magic == "HFAR\x01") (fail "Invalid magic or archive version")
      count <- getWord32be
      unless (count <= 10000) (fail "Too many files")
      replicateM (fromIntegral count) $ do
        nameLength <- getWord16be
        unless (nameLength > 0 && nameLength <= 960) (fail "Invalid filename length")
        nameBytes <- getByteString (fromIntegral nameLength)
        name <- either (fail . show) (pure . T.unpack) (TE.decodeUtf8' nameBytes)
        unless (validName name) (fail "Unsafe filename")
        size <- getWord64be
        unless (size <= 512*1024*1024) (fail "File exceeds 512 MiB limit")
        symbolCount <- getWord16be
        unless (symbolCount <= 256) (fail "Too many symbols")
        histogram <- replicateM (fromIntegral symbolCount) ((,) <$> getWord8 <*> getWord64be)
        bits <- getWord64be
        unless (toInteger bits <= toInteger size*255) (fail "Impossible bit count")
        crc <- getWord32be
        content <- getByteString (fromIntegral ((bits+7) `div` 8))
        pure (Entry name (Encoded size histogram bits crc content))

loadFiles :: [FilePath] -> IO [(FilePath, BS.ByteString)]
loadFiles paths = do
  unless (not (null paths)) (ioError (userError "At least one input file is required"))
  let names = map takeFileName paths
  unless (all validName names && S.size (S.fromList (map (map toLower) names)) == length names)
    (ioError (userError "Filenames must be safe and unique (case-insensitive)"))
  forM (zip names paths) $ \(name,path) -> do
    size <- getFileSize path
    unless (size <= 512*1024*1024) (ioError (userError "File exceeds 512 MiB limit"))
    bytes <- BS.readFile path
    pure (name,bytes)

-- Validate every entry before creating output files. Never overwrite existing data.
extractArchive :: FilePath -> [Entry] -> IO ()
extractArchive target entries = do
  decoded <- forM entries $ \(Entry name item) -> do
    bytes <- either (ioError . userError) pure (decode item)
    pure (name,bytes)
  exists <- doesPathExist target
  whenExists exists $ do
    link <- pathIsSymbolicLink target
    unless (not link) (ioError (userError "Output directory is a symbolic link"))
  createDirectoryIfMissing True target
  canonicalTarget <- canonicalizePath target
  forM_ decoded $ \(name,_) -> do
    unless (validName name) (ioError (userError "Unsafe filename"))
    occupied <- doesPathExist (canonicalTarget </> name)
    link <- catchIOError (pathIsSymbolicLink (canonicalTarget </> name))
              (\err -> if isDoesNotExistError err then pure False else ioError err)
    unless (not occupied && not link) (ioError (userError ("Output already exists: " ++ name)))
  forM_ decoded $ \(name,bytes) -> BS.writeFile (canonicalTarget </> name) bytes
  where whenExists True action = action
        whenExists False _ = pure ()
