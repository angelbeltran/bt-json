module Lib
    ( btToJSON
    ) where

import GHC.IO.Handle (Handle)
import Streamly
import Data.Word
import qualified Streamly.Prelude as S
import qualified Streamly.FileSystem.Handle as FH
import qualified Streamly.Data.Fold as FL
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as B
import qualified Data.ByteString.Builder as BB
import Data.Function ((&))
import Data.String (fromString)
import Data.Aeson as A


btToJSON :: Handle -> Handle -> IO ()
btToJSON src dst =
    S.unfold FH.read src &
        groupWordsIntoStringBuilderByRecord &
        S.map BB.toLazyByteString &
        S.map (\s -> parseRecord s <> bs "\n") &
        S.concatMap (S.fromList . B.unpack) &
        S.fold (FH.write dst)

        where
            groupWordsIntoStringBuilderByRecord = S.groupsByRolling isNotStartOfNewRecord concatWordsIntoByteString
            isNotStartOfNewRecord :: Word8 -> Word8 -> Bool
            isNotStartOfNewRecord w1 w2 = not ((w1 `wec` '\n') && (w2 `wec` '-'))
            concatWordsIntoByteString = FL.foldMap BB.word8

parseRecord :: B.ByteString -> B.ByteString
parseRecord s =
    bs "{" <> B.intercalate (bs ",") renderedLines <> bs "}"

        where
            renderedLines :: [B.ByteString]
            renderedLines =
                renderKeyValue (bs "key") rowKeyLine
                : renderedColumnsLines
            renderedColumnsLines :: [B.ByteString]
            renderedColumnsLines =
                map (\(k, v) -> renderKeyValue k v) parsedColumnLines
            renderKeyValue :: B.ByteString -> B.ByteString -> B.ByteString
            renderKeyValue k v =
                quote k <> bs ":" <> renderAsJSON v
            rowKeyLine :: B.ByteString
            rowKeyLine = head lines
            parsedColumnLines :: [(B.ByteString, B.ByteString)]
            parsedColumnLines =
                splitColumnLines columnLines &
                    map trimColumnContents
                        where
                            trimColumnContents :: (B.ByteString, B.ByteString) -> (B.ByteString, B.ByteString)
                            trimColumnContents (a, b) = 
                                ( (trimEmptySuffix . dropEnd 2. trimNonemptySuffix . trim) a
                                , (B.drop 1 . dropEnd 1 . trim) b
                                )
                            -- @ 2020/04/01-14:14:07.555000
            splitColumnLines :: [B.ByteString] -> [(B.ByteString, B.ByteString)]
            splitColumnLines [] = []
            splitColumnLines (x1:x2:xs) =
                (x1, x2) : splitColumnLines xs
            columnLines :: [B.ByteString]
            columnLines = tail lines
            lines :: [B.ByteString]
            lines = (splitOnNewLine . trimTrailingNewLines . trimHeader) s

trimHeader :: B.ByteString -> B.ByteString
trimHeader =
    B.drop 1 .
    B.dropWhile (\w -> w `wec` '-')

trimTrailingNewLines :: B.ByteString -> B.ByteString
trimTrailingNewLines =
    dropWhileEnd (\w -> w `wec` '\n')

splitOnNewLine :: B.ByteString -> [B.ByteString]
splitOnNewLine = B.split $ (toEnum . fromEnum) '\n'

wec :: Word8 -> Char -> Bool
wec w c =
    (toEnum . fromEnum) w == c

trim :: B.ByteString -> B.ByteString
trim = trimEmptySuffix . trimEmptyPrefix

trimEmptyPrefix :: B.ByteString -> B.ByteString
trimEmptyPrefix = B.dropWhile (\w -> w `wec` '\n' || w `wec` ' ')

trimNonemptyPrefix :: B.ByteString -> B.ByteString
trimNonemptyPrefix = B.dropWhile (\w -> not (w `wec` '\n' || w `wec` ' '))

trimEmptySuffix = B.reverse . trimEmptyPrefix . B.reverse
trimNonemptySuffix = B.reverse . trimNonemptyPrefix . B.reverse
dropWhileEnd p = B.reverse . B.dropWhile p . B.reverse
dropEnd n = B.reverse . B.drop n . B.reverse

quote :: B.ByteString -> B.ByteString
quote v =
    bs "\"" <> v <> bs "\""

renderAsJSON :: B.ByteString -> B.ByteString
renderAsJSON s =
    case decoded of
        Just value -> A.encode value
        Nothing -> case decodedUnescaped of
            Just decoded -> A.encode decoded
            Nothing -> quote s

    where
        decoded :: Maybe A.Value
        decoded = A.decode s
        decodedUnescaped :: Maybe A.Value
        decodedUnescaped = A.decode $ unescape s

unescape :: B.ByteString -> B.ByteString
unescape =
    B.fromStrict
    . unescapeQuotes
    . unescapeNewlines
    . unescapeBackslashes
    . B.toStrict

unescapeQuotes :: BS.ByteString -> BS.ByteString
unescapeQuotes = unescapeTo (bs' "\\\"") (bs' "\"")

unescapeNewlines :: BS.ByteString -> BS.ByteString
unescapeNewlines = unescapeTo (bs' "\\n") (bs' "\n")

unescapeBackslashes :: BS.ByteString -> BS.ByteString
unescapeBackslashes = unescapeTo (bs' "\\\\") (bs' "\\")

unescapeTo :: BS.ByteString -> BS.ByteString -> BS.ByteString -> BS.ByteString
unescapeTo from to s =
    if BS.null t
        then s
        else h <> to <> (unescapeTo from to $ snd $ BS.splitAt (BS.length from) t)
    where
        (h, t) = BS.breakSubstring from s

bs :: String -> B.ByteString
bs = fromString

bs' :: String -> BS.ByteString
bs' = fromString
