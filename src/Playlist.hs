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

module Playlist
  ( initPlaylist
  , showPlaylist
  ) where

import Control.Monad.Trans
import Graphics.UI.Gtk

import UI

import Playlist.Model
import Playlist.Index
import Playlist.Format
import Playlist.View
import Playlist.Config
import Playlist.Search
import Playlist.Update
import Playlist.DnD
import Playlist.UI


initPlaylist =
  initFormat

showPlaylist = do
  builder <- liftIO $ makeBuilder "playlist"

  context <- liftIO $ initUI builder
  let ?context = context

  context <- liftIO $ initModel
  let ?context = context

  context <- liftIO $ initIndex
  let ?context = context

  context <- liftIO $ initView builder
  let ?context = context

  context <- liftIO $ initPlaylistConfig
  let ?context = context

  context <- liftIO $ initUpdate
  let ?context = context

  liftIO $ setupSearch
  liftIO $ setupDnD
  setupUI builder

  liftIO $ widgetShowAll window

