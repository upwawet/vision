-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 21 Jun. 2010
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

module Atoms
  ( xmms2PosList
  , xmms2MlibId
  , allPropPosList
  , confPropPosList
  , mlibIdClipboard
  ) where

import Graphics.UI.Gtk
import System.IO.Unsafe


xmms2PosList    = unsafePerformIO $ atomNew "application/x-xmms2poslist"
xmms2MlibId     = unsafePerformIO $ atomNew "application/x-xmms2mlibid"
allPropPosList  = unsafePerformIO $ atomNew "application/x-visionallpropposlist"
confPropPosList = unsafePerformIO $ atomNew "application/x-visionconfpropposlist"
mlibIdClipboard = unsafePerformIO $ atomNew "_VISION_MEDIAID_CLIPBOARD"
