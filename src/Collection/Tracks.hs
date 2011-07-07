-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 5 Jul. 2011
--
--  Copyright (C) 2011 Oleg Belozeorov
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License as
--  published by the Free Software Foundation; either version 3 of
--  the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--

module Collection.Tracks
  ( TrackView (..)
  , makeTrackView
  , loadTracks
  , showTracks
  , onTracksSelected
  ) where

import Prelude hiding (lookup)

import Control.Concurrent
import Control.Concurrent.STM
import Control.Concurrent.STM.TGVar

import Control.Applicative
import Control.Monad
import Control.Monad.Trans

import Data.Char
import Data.List hiding (lookup)
import Data.Maybe
import Data.IORef

import Graphics.UI.Gtk

import XMMS2.Client

import XMMS
import Utils
import Properties
import Config
import Index hiding (getInfo)
import qualified Index
import Medialib

import Collection.Actions


data TrackView
  = TV { tStore  :: ListStore MediaId
       , tIndex  :: Index MediaInfo
       , tView   :: TreeView
       , tScroll :: ScrolledWindow
       }


makeTrackView abRef popup = do
  store  <- listStoreNewDND [] Nothing Nothing
  index  <- makeIndex store return
  view   <- treeViewNewWithModel store
  scroll <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetShadowType scroll ShadowIn
  scrolledWindowSetPolicy scroll PolicyNever PolicyAutomatic
  containerAdd scroll view
  let tv = TV { tStore  = store
              , tIndex  = index
              , tView   = view
              , tScroll = scroll
              }
  setupView abRef popup tv
  setupXMMS tv
  return tv

setupView abRef popup tv = do
  let view  = tView tv
      store = tStore tv

  sel <- treeViewGetSelection view
  treeSelectionSetMode sel SelectionMultiple

  treeViewSetRulesHint view True
  setupTreeViewPopup view popup

  let doAdd replace = do
        rows <- treeSelectionGetSelectedRows sel
        unless (null rows) $ do
          ids <- mapM (listStoreGetValue store . head) rows
          sel <- collNewIdlist ids
          addToPlaylist replace sel

  view `on` focusInEvent $ liftIO $ do
    writeIORef abRef
      AB { aAdd       = doAdd False
         , aReplace   = doAdd True
         , aSelection = Just sel
         }
    return False

  setColumns tv False =<< loadConfig

setupXMMS tv = do
  xcW <- atomically $ newTGWatch connectedV
  void $ atomically $ watch xcW -- sync with current state
  forkIO $ forever $ do
    void $ atomically $ watch xcW
    postGUISync $ resetModel tv

loadTracks tv coll =
  collQueryIds xmms coll [] 0 0 >>* do
    ids <- result
    liftIO $ populateModel tv ids

setColumns tv save props = do
  let view = tView tv
  mapM_ (treeViewRemoveColumn view) =<< treeViewGetColumns view
  mapM_ (addColumn tv) props
  setupSearch tv props
  when save $ saveConfig props

addColumn tv prop = do
  let view  = tView tv
      store = tStore tv
  column <- treeViewColumnNew
  treeViewAppendColumn view column
  treeViewColumnSetTitle column $ propName prop
  treeViewColumnSetResizable column True
  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributeFunc column cell store $ \iter -> do
    maybeInfo <- getInfoIfNeeded tv iter
    let text = case maybeInfo of
          Just info -> fromMaybe "" $ lookup prop info
          Nothing   -> ""
    cell `set` [ cellText := text ]

getInfoIfNeeded tv iter = do
  let n = listStoreIterToIndex iter
  mid <- listStoreGetValue (tStore tv) n
  rng <- treeViewGetVisibleRange $ tView tv
  getInfo tv mid $ case rng of
    ([f], [t]) | n >= f && t >= n -> Visible
    _                             -> Background

loadConfig =
  catMaybes <$> (mapM property =<< config configFile defaultConfig)

saveConfig props = do
  writeConfig configFile $ map propName props
  return ()

configFile =
  "collection-view.conf"

defaultConfig =
  ["Artist", "Album", "Track", "Title"]

setupSearch tv props = do
  let store = tStore tv
      view  = tView tv
  treeViewSetEnableSearch view True
  treeViewSetSearchEqualFunc view $ Just $ \str iter -> do
    mid <- listStoreGetValue store $ listStoreIterToIndex iter
    search (map toLower str) props <$> getInfo tv mid Search

search _ _ Nothing = False
search _ [] _ = False
search str (prop:props) (Just info) =
  let ptext = map toLower $ fromMaybe "" $ lookup prop info in
  str `isInfixOf` ptext || search str props (Just info)

getInfo tv = Index.getInfo (tIndex tv)

populateModel tv ids = do
  mapM_ addOne ids
  where addOne id = do
          n <- listStoreAppend store id
          addToIndex index id n
        store = tStore tv
        index = tIndex tv

resetModel tv = do
  clearIndex $ tIndex tv
  listStoreClear $ tStore tv

showTracks tv coll = do
  resetModel tv
  loadTracks tv coll

addToPlaylist replace coll = do
  when replace $ playlistClear xmms Nothing >> return ()
  playlistAddCollection xmms Nothing coll []
  return ()

onTracksSelected tv f = do
  let store = tStore tv
      view  = tView tv
  sel <- treeViewGetSelection view
  let doit = do
        rows <- treeSelectionGetSelectedRows sel
        unless (null rows) $ do
          ids <- mapM (listStoreGetValue store . head) rows
          sel <- collNewIdlist ids
          f sel
  view `on` keyPressEvent $ tryEvent $ do
    "Return" <- eventKeyName
    []       <- eventModifier
    liftIO doit
  view `on` buttonPressEvent $ tryEvent $ do
    LeftButton  <- eventButton
    DoubleClick <- eventClick
    (x, y)      <- eventCoordinates
    liftIO $ do
      Just (p, _, _) <- treeViewGetPathAtPos view (round x, round y)
      treeSelectionSelectPath sel p
      doit