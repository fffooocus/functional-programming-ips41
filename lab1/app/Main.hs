{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Control.Exception (IOException, catch)
import Control.Monad (forM_, unless)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Department
import GHC.IO.Encoding (setLocaleEncoding)
import System.Environment (getArgs)
import System.Exit (die)
import System.IO (hSetEncoding, stdout, stderr, stdin, utf8)
import Text.Read (readMaybe)

main :: IO ()
main = do
  setLocaleEncoding utf8
  mapM_ (`hSetEncoding` utf8) [stdin,stdout,stderr]
  application `catch` (\e -> die (show (e :: IOException)))

application :: IO ()
application = do
  config <- loadConfig
  args <- getArgs
  case args of
    ["list"] -> listResources config >>= mapM_ (TIO.putStrLn . renderResource)
    ["search",needle] -> searchResources config (T.pack needle) >>= mapM_ (TIO.putStrLn . renderResource)
    ["add",title,version,note,kind,terms,start,end] -> do
      draft <- makeDraft title version note kind terms start end
      identity <- insertResource config draft
      putStrLn ("Created resource " ++ show identity)
    ["update",rawId,title,version,note,kind,terms,start,end] -> do
      identity <- positive rawId
      draft <- makeDraft title version note kind terms start end
      found <- updateResource config identity draft
      unless found (die "Resource not found")
      putStrLn "Resource updated"
    ["delete",rawId] -> do
      identity <- positive rawId
      found <- deleteResource config identity
      unless found (die "Resource not found")
      putStrLn "Resource deleted"
    ["stats"] -> table config "SELECT id,title,visits,unique_users,total_seconds FROM resource_statistics ORDER BY visits DESC,id;"
    ["catalog"] -> forM_ ["authors","resource_types","purposes","usage_terms","users"] $ \name -> do
      putStrLn name
      table config ("SELECT * FROM " ++ name ++ " ORDER BY id;")
    ["details",rawId] -> do
      identity <- positive rawId
      let suffix = " WHERE resource_id=" ++ show identity ++ ";"
      forM_ ["resource_authors","resource_purposes","resource_urls","access_grants","usage_events"] $ \name -> do
        putStrLn name
        table config ("SELECT * FROM " ++ name ++ suffix)
    ["author-add",name] -> insertLookup config "authors" name
    ["type-add",name] -> insertLookup config "resource_types" name
    ["purpose-add",name] -> insertLookup config "purposes" name
    ["terms-add",name,conditions] -> mutation config
      ("INSERT INTO usage_terms(name,conditions_text) VALUES(" ++ sqlText (T.pack name) ++ "," ++ sqlText (T.pack conditions) ++ ");")
    ["user-add",name,group,login] -> mutation config
      ("INSERT INTO users(display_name,group_name,login) VALUES(" ++ values [name,group,login] ++ ");")
    [command,rawResource,rawOther] | command `elem` ["link-author","link-purpose","grant"] -> do
      resource <- positive rawResource
      other <- positive rawOther
      let (name,column) = case command of
            "link-author" -> ("resource_authors","author_id")
            "link-purpose" -> ("resource_purposes","purpose_id")
            _ -> ("access_grants","user_id")
      mutation config ("INSERT INTO " ++ name ++ "(resource_id," ++ column ++ ") VALUES(" ++ show resource ++ "," ++ show other ++ ");")
    ["url-add",rawId,url] -> do
      identity <- positive rawId
      mutation config ("INSERT INTO resource_urls(resource_id,url) VALUES(" ++ show identity ++ "," ++ sqlText (T.pack url) ++ ");")
    ["edit",name,rawId,column,value] -> do
      let allowed = [("authors",["name"]),("resource_types",["name"]),
            ("purposes",["name"]),("usage_terms",["name","conditions_text"]),
            ("users",["display_name","group_name","login"]),("resource_urls",["url"])]
      unless (maybe False (column `elem`) (lookup name allowed)) (die "Unsupported table or field")
      unless (not (null value)) (die "Value must not be empty")
      identity <- positive rawId
      let condition = " WHERE id=" ++ show identity ++ ";"
      existing <- runSQL config ("SELECT id FROM " ++ name ++ condition)
      unless (not (null existing)) (die "Record not found")
      mutation config ("UPDATE " ++ name ++ " SET " ++ column ++ "=" ++ sqlText (T.pack value) ++ condition)
    ["visit",rawResource,rawUser,rawDuration] -> do
      resource <- positive rawResource
      user <- positive rawUser
      duration <- positive rawDuration
      mutation config ("INSERT INTO usage_events(resource_id,user_id,duration_seconds) VALUES(" ++
                       show resource ++ "," ++ show user ++ "," ++ show duration ++ ");")
    _ -> die (unlines ["Usage: lab1 COMMAND", "  list | search TEXT | stats | catalog | details ID",
      "  add TITLE VERSION ANNOTATION TYPE_ID TERMS_ID YYYY-MM-DD END_OR_-",
      "  update ID TITLE VERSION ANNOTATION TYPE_ID TERMS_ID YYYY-MM-DD END_OR_-",
      "  delete ID | author-add NAME | type-add NAME | purpose-add NAME",
      "  terms-add NAME CONDITIONS | user-add NAME GROUP LOGIN",
      "  link-author RESOURCE AUTHOR | link-purpose RESOURCE PURPOSE",
      "  url-add RESOURCE URL | grant RESOURCE USER | visit RESOURCE USER SECONDS",
      "  edit TABLE ID FIELD VALUE"])
  where
    values = T.unpack . T.intercalate "," . map (T.pack . sqlText . T.pack)

positive :: String -> IO Int
positive raw = case readMaybe raw of
  Just value | value > 0 -> pure value
  _ -> die "Expected positive integer"

makeDraft :: String -> String -> String -> String -> String -> String -> String -> IO ResourceDraft
makeDraft title version note kind terms start end = do
  typeId <- positive kind
  termsId <- positive terms
  pure (ResourceDraft (T.pack title) (T.pack version) (T.pack note) typeId termsId start (if end == "-" then Nothing else Just end))

table :: MySQL -> String -> IO ()
table config sql = runSQL config sql >>= mapM_ (TIO.putStrLn . T.intercalate " | ")

mutation :: MySQL -> String -> IO ()
mutation config sql = runSQL config sql >> putStrLn "Saved"

insertLookup :: MySQL -> String -> String -> IO ()
insertLookup config name value = mutation config
  ("INSERT INTO " ++ name ++ "(name) VALUES(" ++ sqlText (T.pack value) ++ ");")
