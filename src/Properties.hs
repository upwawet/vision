-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 22 Sep. 2009
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

module Properties
  ( PropertyType (..)
  , Property (..)
  , readValue
  , showValue
  , lookup
  , initProperties
  , propertyStore
  , property
  , propertyList
  ) where

import Prelude hiding (lookup)

import Properties.Property
import Properties.Model


initProperties = do
  env <- initModel
  let ?env = env

  return ?env
