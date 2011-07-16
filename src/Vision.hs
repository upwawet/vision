-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 11 Jun. 2010
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

module Main
  where

import Control.Concurrent
import Control.Monad.Trans
import Control.Monad.EnvIO

import Graphics.UI.Gtk

import Environment
import About
import Properties
import XMMS
import Medialib
import Playback
import Volume
import Playtime
import Clipboard
import Playlist
import Registry


main = do
  initGUI

  timeoutAdd (yield >> return True) 100

  flip runEnvIO () $ withRegistry $ do
    context <- liftIO $ initEnvironment
    let ?context = context

    context <- liftIO $ initAbout
    let ?context = context

    context <- liftIO $ initXMMS
    let ?context = context

    context <- liftIO $ initMedialib
    let ?context = context

    context <- liftIO $ initProperties
    let ?context = context

    context <- liftIO $ initPlayback
    let ?context = context

    initVolume
    liftIO $ initPlaytime
    initClipboard

    context <- liftIO $ initPlaylist
    let ?context = context

    showPlaylist

  mainGUI
