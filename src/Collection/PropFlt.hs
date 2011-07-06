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

module Collection.PropFlt
  ( PropFlt (..)
  , mkPropFlt
  ) where

import Prelude hiding (lookup)

import Control.Concurrent
import Control.Concurrent.STM

import Control.Monad
import Control.Monad.Trans

import Data.IORef
import Data.Set (Set)
import qualified Data.Set as Set

import Graphics.UI.Gtk

import XMMS2.Client hiding (Property)

import Properties
import Medialib
import XMMS
import Utils


data PropFlt
  = PF { pStore  :: ListStore String
       , pView   :: TreeView
       , pScroll :: ScrolledWindow
       , pSetRef :: IORef (Set String)
       , pColl   :: Coll
       , pProp   :: Property
       }

mkPropFlt prop coll = do
  store <- listStoreNewDND [] Nothing Nothing
  view  <- treeViewNewWithModel store
  treeViewSetHeadersVisible view False

  column <- treeViewColumnNew
  treeViewAppendColumn view column
  cell <- cellRendererTextNew
  treeViewColumnPackStart column cell True
  cellLayoutSetAttributes column cell store $ \n ->
    [ cellText := n ]

  scroll <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetPolicy scroll PolicyNever PolicyAutomatic
  containerAdd scroll view
  widgetShowAll scroll

  setRef <- newIORef Set.empty

  collQueryIds xmms coll [] 0 0 >>* do
    ids <- result
    liftIO $ do
      let idSet = Set.fromList ids
      mc <- atomically $ dupTChan mediaInfoChan
      forkIO $ forever $ do
        (id, _, info) <- atomically $ readTChan mc
        when (Set.member id idSet) $
          withJust (lookup prop info) $ \str -> do
            vs <- readIORef setRef
            unless (Set.member str vs) $ do
              writeIORef setRef (Set.insert str vs)
              postGUIAsync $ void $ listStoreAppend store str
      forkIO $ mapM_ (requestInfo Background) ids

  return PF { pStore  = store
            , pView   = view
            , pScroll = scroll
            , pSetRef = setRef
            , pColl   = coll
            , pProp   = prop
            }
