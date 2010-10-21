-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 28 Jun. 2010
--
--  Copyright (C) 2010 Oleg Belozeorov
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

module Location.View
  ( initView
  , locationView
  , locationSel
  , locationEntry
  ) where

import Data.List
import Data.Char

import Graphics.UI.Gtk

import Context
import Location.Model
import Location.PathComp


data View
  = View { vView  :: TreeView
         , vSel   :: TreeSelection
         , vEntry :: Entry
         }

locationView  = vView context
locationSel   = vSel context
locationEntry = vEntry context


initView builder = do
  context <- initContext builder
  let ?context = context

  treeViewSetModel locationView sortModel

  treeSelectionSetMode locationSel SelectionMultiple

  column <- treeViewColumnNew
  treeViewAppendColumn locationView column
  treeViewColumnSetTitle column "Name"
  treeViewColumnSetSortOrder column =<< getSortOrder
  treeViewColumnSetSortIndicator column True
  treeViewColumnSetClickable column True
  column `onColClicked` do
    order <- treeViewColumnGetSortOrder column
    let order' = case order of
          SortAscending  -> SortDescending
          SortDescending -> SortAscending
    treeViewColumnSetSortOrder column order'
    setSortOrder order'

  cell <- cellRendererPixbufNew
  treeViewColumnPackStart column cell False
  cellLayoutSetAttributeFunc column cell sortModel $ \iter -> do
    item <- itemByIter iter
    cell `set` [ cellPixbufStockId :=
                 if iIsDir item
                 then stockDirectory
                 else stockFile ]

  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributeFunc column cell sortModel $ \iter -> do
    item <- itemByIter iter
    cell `set` [ cellText := iName item ]

  treeViewSetEnableSearch locationView True
  treeViewSetSearchEqualFunc locationView $ Just $ \str iter -> do
    item <- itemByIter iter
    return $ isInfixOf (map toLower str) (map toLower $ iName item)

  comp <- makePathComp
  entrySetCompletion locationEntry $ pathComp comp
  locationEntry `onEditableChanged` do
    url <- entryGetText locationEntry
    updatePathComp comp url

  return ?context


initContext builder = do
  view  <- builderGetObject builder castToTreeView "location-view"
  sel   <- treeViewGetSelection view
  entry <- builderGetObject builder castToEntry "location-entry"
  return $ augmentContext
    View { vView  = view
         , vSel   = sel
         , vEntry = entry
         }

