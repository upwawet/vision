-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 22 Mar. 2010
--
--  Copyright (C) 2009-2010 Oleg Belozeorov
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

{-# LANGUAGE TupleSections #-}

module Properties.View
  ( PropertyView
  , makePropertyView
  , propertyViewStore
  , propertyViewRight
  ) where

import Control.Monad
import Control.Monad.Trans

import Data.IORef

import Graphics.UI.Gtk

import Atoms
import DnD
import Compound
import Editor
import Properties.Property
import Properties.Model


data PropertyView a
  = PropertyView
    { vPaned            :: HPaned
    , vLeft             :: TreeView
    , propertyViewStore :: ListStore (Property, a)
    , propertyViewRight :: TreeView
    , vModified         :: IORef Bool
    }

instance CompoundWidget (PropertyView a) where
  type Outer (PropertyView a) = HPaned
  outer = vPaned

instance EditorWidget (PropertyView a) where
  type Data (PropertyView a) = [(Property, a)]
  getData       = propertyViewGetData
  setData       = propertyViewSetData
  clearData     = propertyViewClearData
  setupView     = propertyViewSetupView
  focusView     = propertyViewFocusView
  getState      = propertyViewGetState
  resetModified = propertyViewResetModified

propertyViewGetData =
  listStoreToList . propertyViewStore

propertyViewSetData v d = do
  listStoreClear $ propertyViewStore v
  mapM_ (listStoreAppend $ propertyViewStore v) d

propertyViewClearData =
  listStoreClear . propertyViewStore

propertyViewSetupView pm =
  treeViewSetCursor (vLeft pm) [0] Nothing

propertyViewFocusView =
  widgetGrabFocus . vLeft

propertyViewGetState =
  liftM (True, ) . readIORef . vModified

propertyViewResetModified =
  flip writeIORef False . vModified

makePropertyView make _ notify = do
  modified <- newIORef False
  let onChanged = do
        writeIORef modified True
        notify

  paned <- hPanedNew
  containerSetBorderWidth paned 7

  scroll <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetPolicy scroll PolicyAutomatic PolicyAutomatic
  scrolledWindowSetShadowType scroll ShadowIn
  panedPack1 paned scroll True False

  left <- treeViewNewWithModel propertyStore
  treeViewSetHeadersVisible left False

  sel <- treeViewGetSelection left
  treeSelectionSetMode sel SelectionMultiple

  column <- treeViewColumnNew
  treeViewAppendColumn left column
  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributes column cell propertyStore $ \prop ->
    [ cellText := propName prop ]

  containerAdd scroll left

  scroll <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetPolicy scroll PolicyAutomatic PolicyAutomatic
  scrolledWindowSetShadowType scroll ShadowIn
  panedPack2 paned scroll True False

  store <- listStoreNew []
  store `on` rowChanged $ const $ const onChanged
  store `on` rowInserted $ const $ const onChanged
  store `on` rowDeleted $ const onChanged

  right <- treeViewNewWithModel store
  treeViewSetHeadersVisible right False
  treeViewSetReorderable right True

  sel <- treeViewGetSelection right
  treeSelectionSetMode sel SelectionMultiple

  column <- treeViewColumnNew
  treeViewAppendColumn right column
  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributes column cell store $ \(prop, _) ->
    [ cellText := propName prop ]

  containerAdd scroll right

  left `on` keyPressEvent $ tryEvent $ do
    []       <- eventModifier
    "Return" <- eventKeyName
    liftIO $ do
      sel  <- treeViewGetSelection left
      rows <- treeSelectionGetSelectedRows sel
      forM_ rows $ \[n] ->
        listStoreAppend store . make =<<
        listStoreGetValue propertyStore n

  right `on` keyPressEvent $ tryEvent $ do
    []       <- eventModifier
    "Delete" <- eventKeyName
    liftIO $ do
      sel  <- treeViewGetSelection right
      rows <- treeSelectionGetSelectedRows sel
      mapM_ (listStoreRemove store . head) $ reverse rows

  setupDnDReorder propPosList store right $
    mapM_ $ \(f, t) -> do
      v <- listStoreGetValue store f
      listStoreRemove store f
      listStoreInsert store t v

  return PropertyView { vPaned            = paned
                      , vLeft             = left
                      , propertyViewStore = store
                      , propertyViewRight = right
                      , vModified         = modified
                      }


