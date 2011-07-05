-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 10 Mar. 2010
--
--  Copyright (C) 2009-2010 Oleg Belozeorov
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

{-# LANGUAGE DeriveDataTypeable #-}

module Collection.List.View
  ( withListView
  , listView
  , onListSelected
  ) where

import Control.Applicative
import Control.Monad.Trans
import Control.Monad.ReaderX

import Data.Char (toLower)
import Data.List (isInfixOf)
import Data.Typeable

import Graphics.UI.Gtk

import Context
import Collection.List.Model


data Ix = Ix deriving (Typeable)
instance Index Ix where getVal = Ix

data View
  = View { vView :: TreeView
         , vSel  :: TreeSelection
         }
  deriving (Typeable)

--viewEnv :: (Ix, View)
--viewEnv = undefined

listView = asksx Ix vView

withListView m = do
  Just env <- getEnv modelEnv
  runEnvT env $ do
    store <- store
    view  <- makeView store
    runEnvT (Ix, view) m

makeView store = liftIO $ do
  view <- treeViewNewWithModel store
  treeViewSetHeadersVisible view False

  column <- treeViewColumnNew
  treeViewAppendColumn view column
  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributes column cell store $ \n ->
    case n of
      Nothing ->
        [ cellText := "All Media", cellTextWeight := 800 ]
      Just cn ->
        [ cellText := cn, cellTextWeightSet := False ]

  treeViewSetEnableSearch view True
  treeViewSetSearchEqualFunc view . Just $ \str iter ->
    maybe False (isInfixOf (map toLower str) . map toLower) <$>
      (listStoreGetValue store $ listStoreIterToIndex iter)

  sel <- treeViewGetSelection view
  treeSelectionSetMode sel SelectionMultiple

  return View { vView = view, vSel = sel }

onListSelected f = do
  sel   <- asksx Ix vSel
  view  <- asksx Ix vView
  store <- store
  liftIO $ do
    let doit = do
          rows  <- treeSelectionGetSelectedRows sel
          names <- mapM (listStoreGetValue store . head) rows
          f names
    view `on` keyPressEvent $ tryEvent $ do
      "Return" <- eventKeyName
      liftIO doit
    view `on` buttonPressEvent $ tryEvent $ do
      LeftButton  <- eventButton
      DoubleClick <- eventClick
      (x, y)      <- eventCoordinates
      liftIO $ do
        Just (p, _, _) <- treeViewGetPathAtPos view (round x, round y)
        treeSelectionSelectPath sel p
        doit
