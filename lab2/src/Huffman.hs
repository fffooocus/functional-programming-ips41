{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE BangPatterns #-}
module Huffman
  ( Encoded(..), encode, decode, crc32, buildTree ) where

import Control.DeepSeq (NFData)
import Data.Array (Array, (!), array)
import Data.Bits
import qualified Data.ByteString as BS
import qualified Data.IntMap.Strict as IM
import Data.List (foldl', sortOn, insertBy)
import Data.Ord (comparing)
import Data.Word
import GHC.Generics (Generic)

data Tree = Leaf Word8 | Branch Tree Tree deriving (Eq, Show)
data Encoded = Encoded
  { originalSize :: Word64
  , frequencies :: [(Word8, Word64)]
  , bitLength :: Word64
  , checksum :: Word32
  , payload :: BS.ByteString
  } deriving (Eq, Show, Generic)
instance NFData Encoded

buildTree :: [(Word8, Word64)] -> Maybe Tree
buildTree frequencies' = combine (sortOn key [(n, byte, Leaf byte) | (byte,n) <- frequencies'])
  where
    key (n,b,_) = (n,b)
    combine [] = Nothing
    combine [(_,_,tree)] = Just tree
    combine ((n,a,left):(m,b,right):rest) =
      combine (insertBy (comparing key) (n+m, min a b, Branch left right) rest)

codes :: Tree -> Array Int (Integer, Int)
codes tree = array (0,255) ([(i,(0,0)) | i <- [0..255], i `notElem` map fst entries] ++ entries)
  where
    entries = walk 0 0 tree
    walk value depth (Leaf b) = [(fromIntegral b, (value, depth))]
    walk value depth (Branch left right) =
      walk (shiftL value 1) (depth+1) left ++ walk (shiftL value 1 .|. 1) (depth+1) right

encode :: BS.ByteString -> Encoded
encode input =
  let counts = BS.foldl' (\m b -> IM.insertWith (+) (fromIntegral b) 1 m) IM.empty input
      histogram = [(fromIntegral b,n) | (b,n) <- IM.toAscList counts]
      tree = buildTree histogram
      (bits, compressed) = case tree of
        Nothing -> (0, BS.empty)
        Just root ->
          let table = codes root
              total = sum [n * fromIntegral (snd (table ! fromIntegral b)) | (b,n) <- histogram]
              next (!index, !buffer, !available)
                | available >= 8 =
                    let remaining = available - 8
                    in Just (fromIntegral (shiftR buffer remaining .&. 255),
                             (index, buffer .&. (shiftL 1 remaining - 1), remaining))
                | index < BS.length input =
                    let (value,width) = table ! fromIntegral (BS.index input index)
                    in next (index+1, shiftL buffer width .|. value, available+width)
                | available > 0 = Just (fromIntegral (shiftL buffer (8-available)), (index,0,0))
                | otherwise = Nothing
          in (total, BS.unfoldr next (0,0 :: Integer,0))
  in Encoded (fromIntegral (BS.length input)) histogram bits (crc32 input) compressed

decode :: Encoded -> Either String BS.ByteString
decode item
  | originalSize item > fromIntegral (maxBound :: Int) = Left "File exceeds platform limit"
  | length histogram > 256 || any ((==0) . snd) histogram = Left "Invalid frequencies"
  | map (fromIntegral . fst) histogram /= IM.keys (IM.fromList [(fromIntegral b,()) | (b,_) <- histogram]) = Left "Unsorted or duplicate symbols"
  | sum (map (toInteger . snd) histogram) /= toInteger (originalSize item) = Left "Frequency sum mismatch"
  | toInteger (BS.length bytes) /= (toInteger (bitLength item)+7) `div` 8 = Left "Payload length mismatch"
  | otherwise = do
      restored <- case buildTree histogram of
        Nothing -> if bitLength item == 0 then Right BS.empty else Left "Empty tree has bits"
        Just (Leaf b) -> if bitLength item == 0 then Right (BS.replicate size b) else Left "Single symbol has bits"
        Just root -> do
          let decodeOne pos tree = case tree of
                Leaf byte -> Right (byte,pos)
                Branch left right
                  | pos >= bitLength item -> Left "Truncated Huffman code"
                  | otherwise -> let byte = BS.index bytes (fromIntegral (pos `div` 8))
                                     direction = testBit byte (7-fromIntegral (pos `mod` 8))
                                 in decodeOne (pos+1) (if direction then right else left)
              restore 0 pos acc = if pos == bitLength item then Right (BS.pack (reverse acc)) else Left "Extra encoded bits"
              restore n pos acc = do
                (byte,next) <- decodeOne pos root
                restore (n-1) next (byte:acc)
          restore size 0 []
      if crc32 restored /= checksum item then Left "CRC32 mismatch" else
        if bitLength item `mod` 8 /= 0 && not (BS.null bytes) &&
           (BS.last bytes .&. (shiftL 1 (8-fromIntegral (bitLength item `mod` 8))-1) /= 0)
        then Left "Non-zero padding" else Right restored
  where
    histogram = frequencies item
    bytes = payload item
    size = fromIntegral (originalSize item)

crc32 :: BS.ByteString -> Word32
crc32 = complement . BS.foldl' (\crc byte -> shiftR crc 8 `xor` (crcTable ! fromIntegral ((crc `xor` fromIntegral byte) .&. 255))) maxBound

crcTable :: Array Int Word32
crcTable = array (0,255) [(i, foldl' (\value _ -> if testBit value 0 then shiftR value 1 `xor` 0xedb88320 else shiftR value 1) (fromIntegral i) [1::Int ..8]) | i <- [0..255]]
