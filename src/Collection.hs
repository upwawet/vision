-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 14 Jul. 2010
--
--  Copyright (C) 2010, 2011 Oleg Belozeorov
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

module Collection
  ( initCollection
  , browseCollection
  ) where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Concurrent.STM.TGVar

import Control.Monad
import Control.Monad.ToIO
import Control.Monad.Trans

import Data.IORef

import Graphics.UI.Gtk hiding (selectAll)

import XMMS2.Client

import UI
import Utils
import Clipboard
import Context
import XMMS
import Properties

import Collection.List
import Collection.ScrollBox
import Collection.Combo
import qualified Collection.Select as S
import Collection.Actions
import Collection.Utils


initCollection =
  initList

browseCollection _maybeName = do
  builder <- liftIO $ makeBuilder "collection-browser"
  context <- liftIO $ initUI builder
  let ?context = context

  abRef <- liftIO $ newIORef emptyAB

  Just env <- getEnv clipboardEnv
  runEnvT env $ runIn clipboardEnv $> do
    io $ \run ->
      let withColl f = do
            ab <- readIORef abRef
            aWithColl ab f
          withIds f = withColl $ \coll ->
            collQueryIds xmms coll [] 0 0 >>* do
              ids <- result
              liftIO $ f ids
          withSel f = do
            ab <- readIORef abRef
            withJust (aSelection ab) f
          withNames f = do
            ab <- readIORef abRef
            aWithNames ab f
      in bindActions builder $
        [ ("add-to-playlist", withColl $ addToPlaylist False)
        , ("replace-playlist", withColl $ addToPlaylist True)
        , ("select-all", withSel selectAll)
        , ("invert-selection", withSel invertSelection)
        , ("copy", withIds (run . copyIds))
        , ("edit-properties", withIds showPropertyEditor)
        , ("export-properties", withIds showPropertyExport)
        , ("import-properties", showPropertyImport)
        , ("manage-properties", showPropertyManager)
        , ("save-collection", withColl $ saveCollection)
        , ("rename-collection", withNames $ renameCollection)
        , ("delete-collections", withNames $ deleteCollections)
        ]

  selActs <- liftIO $ mapM (action builder)
             [ "add-to-playlist"
             , "replace-playlist"
             , "copy"
             , "edit-properties"
             , "export-properties"
             , "save-collection"
             ]
  renAct <- liftIO $ action builder "rename-collection"
  delAct <- liftIO $ action builder "delete-collections"
  let ae = AE { aEnableSel = \en -> mapM_ (`actionSetSensitive` en) selActs
              , aEnableRen = actionSetSensitive renAct
              , aEnableDel = actionSetSensitive delAct
              }

  liftIO $ do
    ag  <- builderGetObject builder castToActionGroup "server-actions"
    xcW <- atomically $ newTGWatch connectedV
    tid <- forkIO $ forever $ do
      conn <- atomically $ watch xcW
      postGUISync $ actionGroupSetSensitive ag conn
    window `onDestroy` (killThread tid)

  lpopup <- liftIO $ getWidget castToMenu "ui/list-popup"
  vpopup <- liftIO $ getWidget castToMenu "ui/view-popup"
  withListView abRef ae lpopup $ do
    view <- listView
    sbox <- liftIO $ mkScrollBox
    cmod <- liftIO $ mkModel
    kill <- getKill
    liftIO $ do
      box    <- builderGetObject builder castToVBox "views"
      scroll <- scrolledWindowNew Nothing Nothing
      scrolledWindowSetShadowType scroll ShadowNone
      scrolledWindowSetPolicy scroll PolicyAutomatic PolicyNever
      boxPackStartDefaults box scroll
      containerAdd scroll $ sViewport sbox
      adj <- scrolledWindowGetHAdjustment scroll
      adj `afterAdjChanged` do
        max <- adjustmentGetUpper adj
        pgs <- adjustmentGetPageSize adj
        adjustmentSetValue adj $ max - pgs
      scroll <- scrolledWindowNew Nothing Nothing
      scrolledWindowSetShadowType scroll ShadowIn
      scrolledWindowSetPolicy scroll PolicyNever PolicyAutomatic
      scrollBoxAdd sbox scroll
      containerAdd scroll view
    onListSelected $ \coll -> do
      s <- S.mkSelect abRef ae vpopup sbox cmod coll
      writeIORef kill $ Just $ S.killSelect s
      scrollBoxAdd sbox $ S.sBox s
      writeIORef abRef emptyAB
      widgetGrabFocus $ S.sCombo s
    return ()

  liftIO $ widgetShowAll window

