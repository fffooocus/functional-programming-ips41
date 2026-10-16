{-# LANGUAGE OverloadedStrings #-}
module Department
  ( MySQL(..), Resource(..), ResourceDraft(..), SqlValue(..), Validatable(..)
  , ResourceStore(..), loadConfig, runSQL, renderResource, sqlText
  ) where

import Control.Monad (unless)
import qualified Data.ByteString as BS
import Data.List (intercalate)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (Day, defaultTimeLocale, parseTimeM)
import Numeric (showHex)
import System.Environment (lookupEnv)
import System.Exit (ExitCode(..))
import System.Process (proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

data MySQL = MySQL { mysqlExecutable :: FilePath, mysqlHost :: String,
                     mysqlPort :: Int, mysqlUser :: String, mysqlDatabase :: String }
  deriving (Show)
data Resource = Resource { resourceId :: Int, resourceTitle :: T.Text,
                          resourceType :: T.Text, availableFrom :: T.Text,
                          expiresOn :: T.Text, annotation :: T.Text,
                          resourceAuthors :: T.Text } deriving (Eq, Show)
data ResourceDraft = ResourceDraft { draftTitle :: T.Text, draftAnnotation :: T.Text,
                                    draftType :: Int, draftTerms :: Int,
                                    draftStart :: String, draftEnd :: Maybe String }
  deriving (Eq, Show)

class SqlValue a where sqlValue :: a -> String
instance SqlValue T.Text where sqlValue = sqlText
instance SqlValue Int where sqlValue = show
instance SqlValue Day where sqlValue = sqlText . T.pack . show
instance SqlValue a => SqlValue (Maybe a) where
  sqlValue Nothing = "NULL"
  sqlValue (Just value) = sqlValue value

-- Hex literals prevent SQL injection independently of sql_mode and quoting.
sqlText :: T.Text -> String
sqlText value = "CONVERT(X'" ++ concatMap hex (BS.unpack (TE.encodeUtf8 value)) ++ "' USING utf8mb4)"
  where hex byte = let digits = showHex byte "" in if length digits == 1 then '0':digits else digits

class Validatable a where validate :: a -> Either String ()
instance Validatable ResourceDraft where
  validate draft = do
    unless (not (T.null (T.strip (draftTitle draft))) && T.length (draftTitle draft) <= 250)
      (Left "Title must contain 1..250 characters")
    unless (not (T.null (T.strip (draftAnnotation draft)))) (Left "Annotation is required")
    unless (draftType draft > 0 && draftTerms draft > 0) (Left "Type and terms IDs must be positive")
    start <- parseDay (draftStart draft)
    case draftEnd draft of
      Nothing -> Right ()
      Just raw -> do
        end <- parseDay raw
        unless (end >= start) (Left "End date precedes start date")
    where parseDay raw = maybe (Left "Expected date YYYY-MM-DD") Right
                        (parseTimeM True defaultTimeLocale "%Y-%m-%d" raw :: Maybe Day)

class ResourceStore store where
  listResources :: store -> IO [Resource]
  searchResources :: store -> T.Text -> IO [Resource]
  insertResource :: store -> ResourceDraft -> IO Int
  updateResource :: store -> Int -> ResourceDraft -> IO Bool
  deleteResource :: store -> Int -> IO Bool

instance ResourceStore MySQL where
  listResources connection = queryResources connection ""
  searchResources connection needle = queryResources connection
    (" WHERE INSTR(LOWER(r.title),LOWER(" ++ sqlText needle ++ "))>0 OR " ++
     "INSTR(LOWER(r.annotation),LOWER(" ++ sqlText needle ++ "))>0 OR EXISTS " ++
     "(SELECT 1 FROM resource_authors ra JOIN authors a ON a.id=ra.author_id " ++
     "WHERE ra.resource_id=r.id AND INSTR(LOWER(a.name),LOWER(" ++ sqlText needle ++ "))>0)")
  insertResource connection draft = do
    either (ioError . userError) pure (validate draft)
    rows <- runSQL connection ("INSERT INTO resources(title,annotation,type_id,terms_id,available_from,expires_on) VALUES(" ++
                 intercalate "," (draftValues draft) ++ "); SELECT LAST_INSERT_ID();")
    scalarInt rows
  updateResource connection identity draft = do
    either (ioError . userError) pure (validate draft)
    let assignments = zipWith (\column value -> column ++ "=" ++ value)
          ["title","annotation","type_id","terms_id","available_from","expires_on"] (draftValues draft)
    rows <- runSQL connection ("UPDATE resources SET " ++ intercalate "," assignments ++
               " WHERE id=" ++ show identity ++ "; SELECT COUNT(*) FROM resources WHERE id=" ++ show identity ++ ";")
    (>0) <$> scalarInt rows
  deleteResource connection identity = do
    rows <- runSQL connection ("DELETE FROM resources WHERE id=" ++ show identity ++ "; SELECT ROW_COUNT();")
    (>0) <$> scalarInt rows

draftValues :: ResourceDraft -> [String]
draftValues draft = [sqlValue (draftTitle draft), sqlValue (draftAnnotation draft),
                     sqlValue (draftType draft), sqlValue (draftTerms draft),
                     sqlText (T.pack (draftStart draft)), sqlValue (T.pack <$> draftEnd draft)]

scalarInt :: [[T.Text]] -> IO Int
scalarInt [[value]] | Just n <- readMaybe (T.unpack value) = pure n
scalarInt _ = ioError (userError "Unexpected numeric result from MySQL")

queryResources :: MySQL -> String -> IO [Resource]
queryResources connection condition = do
  rows <- runSQL connection ("SELECT r.id,r.title,t.name,r.available_from,COALESCE(CAST(r.expires_on AS CHAR),'безстроково'),r.annotation," ++
    "COALESCE((SELECT GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ') FROM resource_authors ra JOIN authors a ON a.id=ra.author_id WHERE ra.resource_id=r.id),'') " ++
    "FROM resources r JOIN resource_types t ON t.id=r.type_id" ++ condition ++ " ORDER BY r.id;")
  mapM parse rows
  where
    parse [identity,title,kind,start,end,note,authors]
      | Just n <- readMaybe (T.unpack identity) = pure (Resource n title kind start end note authors)
    parse _ = ioError (userError "Unexpected resource row from MySQL")

loadConfig :: IO MySQL
loadConfig = do
  executable <- setting "MYSQL_BIN" "mysql"
  host <- setting "MYSQL_HOST" "127.0.0.1"
  rawPort <- setting "MYSQL_PORT" "3306"
  port <- case readMaybe rawPort of
    Just n | n > 0 && n < 65536 -> pure n
    _ -> ioError (userError "Invalid MYSQL_PORT")
  user <- setting "MYSQL_USER" "department"
  database <- setting "MYSQL_DATABASE" "department_resources"
  pure (MySQL executable host port user database)
  where setting key fallback = maybe fallback id <$> lookupEnv key

runSQL :: MySQL -> String -> IO [[T.Text]]
runSQL connection sql = do
  let args = ["--protocol=TCP","--batch","--skip-column-names","--default-character-set=utf8mb4",
              "--host=" ++ mysqlHost connection,"--port=" ++ show (mysqlPort connection),
              "--user=" ++ mysqlUser connection,"--database=" ++ mysqlDatabase connection]
  (status, output, errors) <- readCreateProcessWithExitCode (proc (mysqlExecutable connection) args)
                            ("SET NAMES utf8mb4;\n" ++ sql ++ "\n")
  case status of
    ExitSuccess -> pure (map (map unescape . T.splitOn "\t") (T.lines (T.pack output)))
    ExitFailure _ -> ioError (userError ("MySQL: " ++ errors))
  where
    unescape = T.pack . go . T.unpack
    go ('\\':c:rest) = (case c of 'n' -> '\n'; 't' -> '\t'; 'r' -> '\r'; '0' -> '\0'; _ -> c) : go rest
    go (c:rest) = c : go rest
    go [] = []

renderResource :: Resource -> T.Text
renderResource resource = T.intercalate " | "
  [T.pack (show (resourceId resource)), resourceTitle resource, resourceType resource,
   availableFrom resource <> " — " <> expiresOn resource, resourceAuthors resource,
   annotation resource]
