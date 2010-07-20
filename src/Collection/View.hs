-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 14 Jul. 2010
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

module Collection.View
  ( initView
  , collView
  ) where

import Graphics.UI.Gtk

import Context
import Collection.Model


data View
  = View { vView :: TreeView }

collView = vView context


initView = do
  context <- initContext
  let ?context = context

  return ?context


initContext = do
  view <- treeViewNewWithModel collStore
  return $ augmentContext
    View { vView = view }
