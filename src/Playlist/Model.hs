-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 20 Jun. 2010
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

module Playlist.Model
  ( initModel
  , clearModel
  , playlistStore
  , getPlaylistName
  , setPlaylistName
  , getPlaylistSize
  , touchPlaylist
  ) where

import Control.Concurrent.MVar

import Data.Int

import Graphics.UI.Gtk

import Env


data State
  = State { sName :: Maybe String }

data Model
  = Model { mStore :: ListStore Int32
          , mState :: MVar State
          }

playlistStore = mStore getEnv

state = mState getEnv

getPlaylistName      = withMVar state (return . sName)
setPlaylistName name = modifyMVar_ state $ \s ->
  return s { sName = name }

getPlaylistSize = listStoreGetSize playlistStore

touchPlaylist n = do
  Just iter <- treeModelGetIter playlistStore [n]
  treeModelRowChanged playlistStore [n] iter


initModel = do
  env <- initEnv
  let ?env = env

  return ?env

clearModel =
  listStoreClear playlistStore


initEnv = do
  store <- listStoreNewDND [] Nothing Nothing
  state <- newMVar makeState
  return $ augmentEnv
    Model { mStore = store
          , mState = state
          }

makeState =
  State { sName = Nothing }
