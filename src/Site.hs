{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}


------------------------------------------------------------------------------
-- | This module is where all the routes and handlers are defined for your
-- site. The 'app' function is the initializer that combines everything
-- together and is exported by this module.
module Site
  ( app
  ) where

------------------------------------------------------------------------------
import           Control.Applicative
import           Data.ByteString (ByteString)
import qualified Data.Text as T
import           Snap.Core
import           Snap.Snaplet
import           Snap.Snaplet.Auth
import           Snap.Snaplet.Auth.Backends.JsonFile
import           Snap.Snaplet.Heist
import           Snap.Snaplet.Session.Backends.CookieSession
import           Snap.Util.FileServe
import           Heist
import qualified Heist.Interpreted as I
import           Snap.Snaplet.PostgresqlSimple
import           Snap.Snaplet.Auth.Backends.PostgresqlSimple
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import           Control.Monad
------------------------------------------------------------------------------
import           Application

import Text.Digestive
import Text.Digestive.Heist
import Text.Digestive.Snap hiding(method)
import Text.Read
import Data.Maybe
import Control.Monad.State.Class as SC
import qualified Data.Vector as V
import qualified Data.Aeson as Aeson
import Hierarchy
import qualified Data.IntMap as Map

instance HasPostgres (Handler App (AuthManager App)) where
    getPostgresState = withTop db SC.get

instance HasPostgres (Handler b App) where
    getPostgresState = with db SC.get


------------------------------------------------------------------------------
-- | Render login form
handleLogin :: Maybe T.Text -> Handler App (AuthManager App) ()
handleLogin authError = heistLocal (I.bindSplices errs) $ render "login"
  where
    errs = maybe noSplices splice authError
    splice err = "loginError" ## I.textSplice err


------------------------------------------------------------------------------
-- | Handle login submit
handleLoginSubmit :: Handler App (AuthManager App) ()
handleLoginSubmit =
    loginUser "login" "password" Nothing
              (\_ -> handleLogin err) (redirect "/")
  where
    err = Just "Unknown user or password"


------------------------------------------------------------------------------
-- | Logs out and redirects the user to the site index.
handleLogout :: Handler App (AuthManager App) ()
handleLogout = logout >> redirect "/"


------------------------------------------------------------------------------
-- | 

validateSet :: Map.IntMap (String, [Int]) -> String -> Result T.Text [Integer]
validateSet m s =
  if (all isJust $ map (\x -> readMaybe x :: Maybe Integer) $ words s) &&
     (all (flip Map.member m) l)
  then Success $ map toInteger l
  else Error "not a proper list"
  where l = map read $ words s

  -- if all isJust $ map (\x -> readMaybe x :: Maybe Integer) $ words s
  -- then Success $ map read $ words s
  -- else Error "not a proper list"

data NewMessage = NewMessage
                  { nmsgReplyTo :: Maybe Integer
                  , nmsgTopics :: [Integer]
                  , nmsgRestrictions :: [Integer]
                  , nmsgText :: T.Text
                  } deriving (Show)

nmsgForm :: Monad m => Form T.Text m NewMessage
nmsgForm = NewMessage
    <$> "reply_to" .: optionalStringRead "Not an integer" Nothing
    <*> "topics" .: validate (validateSet topics) (string Nothing) --listOf (stringRead "Not a list of integers") Nothing
    <*> "restrictions" .: validate (validateSet restrictions) (string Nothing)
    <*> "message" .: text Nothing

postHandler :: Handler App (AuthManager App) ()
postHandler = do
  (view, result) <- runForm "post" nmsgForm
  case result of
    Just x -> do  --heistLocal (bindNMsg x) $ render "nmsg"
      uid' <- currentUser
      uid <- return $ ((read $ T.unpack $ unUid $ fromJust $ userId $ fromJust uid') :: Int)
      case (nmsgReplyTo x) of
        Nothing -> newThread uid (nmsgTopics x) (nmsgRestrictions x) (nmsgText x) >> writeBS "new thread"
        Just pid -> do
          r <- getRoot pid (nmsgTopics x) (nmsgRestrictions x)
          case r of
            (Just root) -> do
              count <- newAnswer uid (nmsgTopics x) (nmsgRestrictions x) root (nmsgReplyTo x) (nmsgText x)
              writeBS $ BS.pack $ show root
            Nothing -> writeBS "error; check topics and restrictions"
    Nothing -> heistLocal (bindDigestiveSplices view) $ render "nmsg-form"
--      writeBS "error: can't parse the data"
  where
    --bindNMsg nmsg = I.bindSplice "nmsg" (I.textSplice (T.pack $ show nmsg))
    
    getRoot pid topics restrictions = do
      rq <- query "select root from messages where id = ? and topics <@ ? :: integer[] and restrictions @> ? :: integer[]"
            (pid, V.fromList topics, V.fromList restrictions)
            :: Handler App (AuthManager App) [Only Integer]
      return $ listToMaybe $ map fromOnly rq

    newThread uid topics restrictions message =
      execute "insert into messages (id, uid, topics, restrictions, root, message) select x.id, ?, ? :: integer[], ? :: integer[], x.id, ? from (select nextval('messages_id_seq') as id) x"
        (uid, V.fromList topics, V.fromList restrictions, message)
      
    newAnswer uid topics restrictions root parent message =
      execute "insert into messages (uid, topics, restrictions, root, parent, message) values (?, ? :: integer[], ? :: integer[], ?, ?, ?)"
        (uid, V.fromList topics, V.fromList restrictions, root, parent, message)

        
------------------------------------------------------------------------------
-- |
data ThreadsFilter = ThreadsFilter
                     { tfTopics :: [Integer]
                     , tfRestrictions :: [Integer]
                     , tfLimit :: Integer
                     , tfOffset :: Integer
                     } deriving (Show)

tfForm :: Monad m => Form T.Text m ThreadsFilter
tfForm = ThreadsFilter
    <$> "topics" .: validate (validateSet topics) (string Nothing)
    <*> "restrictions" .: validate (validateSet restrictions) (string Nothing)
    <*> "limit" .: stringRead "Offset: not an integer" Nothing
    <*> "offset" .: stringRead "Limit: not an integer" Nothing

tfHandler :: Handler App App ()
tfHandler = do
  (view, result) <- runForm "filter" tfForm
  case result of
    Just tf -> do
      rl <- query "select array_to_json(array_agg(row_to_json(t))) from (select id, creation_time, topics, restrictions, message, users.uid, login from messages join users on messages.uid = users.uid where parent is null and topics <@ (? :: integer[]) and restrictions @> (? :: integer[]) order by id desc limit ? offset ?) t"
            (V.fromList $ tfTopics tf, V.fromList $ tfRestrictions tf, tfLimit tf, tfOffset tf)
            :: Handler App App [Only (Maybe Aeson.Value)]
      ret <- return $ head $ map fromOnly rl
      writeLBS $ case ret of
        Just json -> Aeson.encode json
        Nothing -> "[]"
    Nothing -> writeBS "Unable to parse the post data"

------------------------------------------------------------------------------
-- |
data MessagesFilter = MessagesFilter
                     { mfThread :: Integer
                     , mfTopics :: [Integer]
                     , mfRestrictions :: [Integer]
                     } deriving (Show)

mfForm :: Monad m => Form T.Text m MessagesFilter
mfForm = MessagesFilter
    <$> "thread" .: stringRead "Not an integer" Nothing
    <*> "topics" .: validate (validateSet topics) (string Nothing)
    <*> "restrictions" .: validate (validateSet restrictions) (string Nothing)

mfHandler :: Handler App App ()
mfHandler = do
  (view, result) <- runForm "filter" mfForm
  case result of
    Just mf -> do
      rl <- query "select array_to_json(array_agg(row_to_json(t))) from (select id, creation_time, topics, restrictions, parent, message, users.uid, login from messages join users on messages.uid = users.uid where root = ? and topics <@ (? :: integer[]) and restrictions @> (? :: integer[]) order by id) t"
            (mfThread mf, V.fromList $ mfTopics mf, V.fromList $ mfRestrictions mf)
            :: Handler App App [Only (Maybe Aeson.Value)]
      ret <- return $ head $ map fromOnly rl
      writeLBS $ case ret of
        Just json -> Aeson.encode json
        Nothing -> "[]"
    Nothing -> writeBS "{\"error\"}"


------------------------------------------------------------------------------
-- |
restrictionsHandler :: Handler App App ()
restrictionsHandler = writeLBS $ Aeson.encode restrictions

topicsHandler :: Handler App App ()
topicsHandler = writeLBS $ Aeson.encode topics

------------------------------------------------------------------------------
-- | Handle new user form submit
handleNewUser :: Handler App (AuthManager App) ()
handleNewUser = method GET handleForm <|> method POST handleFormSubmit
  where
    handleForm = render "new_user"
    handleFormSubmit = registerUser "login" "password" >> redirect "/"


------------------------------------------------------------------------------
-- | The application's routes.
routes :: [(ByteString, Handler App App ())]
routes = [ ("/login",    with auth handleLoginSubmit)
         , ("/logout",   with auth handleLogout)
         , ("/new_user", with auth handleNewUser)
         , ("",          serveDirectory "static")
         , ("/post",     with auth $ requireUser auth (redirect "/") postHandler)
         , ("/threads",  tfHandler)
         , ("/messages", mfHandler)
         , ("/restrictions", restrictionsHandler)
         , ("/topics", topicsHandler)
         ]


------------------------------------------------------------------------------
-- | The application initializer.
app :: SnapletInit App App
app = makeSnaplet "app" "An snaplet example application." Nothing $ do
    h <- nestSnaplet "" heist $ heistInit "templates"
    s <- nestSnaplet "sess" sess $
           initCookieSessionManager "site_key.txt" "sess" (Just 3600)

    -- NOTE: We're using initJsonFileAuthManager here because it's easy and
    -- doesn't require any kind of database server to run.  In practice,
    -- you'll probably want to change this to a more robust auth backend.
    d <- nestSnaplet "db" db pgsInit
    a <- nestSnaplet "auth" auth $ initPostgresAuth sess d
    addRoutes routes
    addAuthSplices h auth
    return $ App h s d a

