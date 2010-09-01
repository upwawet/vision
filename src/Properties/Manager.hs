-- -*-haskell-*-
--  Vision (for the Voice): an XMMS2 client.
--
--  Author:  Oleg Belozeorov
--  Created: 5 Jul. 2010
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

module Properties.Manager
  ( initPropertyManager
  , showPropertyManager
  ) where

import Control.Concurrent.MVar
import Control.Applicative
import Control.Monad

import Data.IORef
import Data.Maybe
import qualified Data.Map as Map
import Data.Ord
import Data.Char

import Graphics.UI.Gtk

import Utils
import Compound
import Config
import Context
import UI
import Properties.Property
import Properties.Model


data MD
  = MD { mDialog :: ConfigDialog
       , mShown  :: Bool
       }

data Manager
  = Manager { pManager :: MVar (Maybe MD) }

manager = pManager context

initPropertyManager = do
  manager <- newMVar Nothing
  return $ augmentContext
    Manager { pManager = manager }

showPropertyManager =
  modifyMVar_ manager $ \m -> do
    md <- case m of
      Just md -> return md
      Nothing -> do
        dialog <- makePropertyManager
        return MD { mDialog = dialog, mShown = False }
    let dialog = mDialog md
        outerw = outer dialog
    unless (mShown md) $ do
      prepareToShow dialog
      windowSetTransientFor outerw window
      windowPresent outerw
    return $ Just md { mShown = True }

makePropertyManager = do
  dialog <- makeConfigDialog makePropertyManagerWidget False
            getProperties setProperties
  let outerw = outer dialog
  hideOnDeleteEvent outerw
  outerw `on` hideSignal $ modifyMVar_ manager $ \maybeMD ->
    case maybeMD of
      Just md ->
        return $ Just md { mShown = False }
      Nothing ->
        return Nothing
  windowSetTitle outerw "Manage properties"
  windowSetDefaultSize outerw 500 400
  return dialog


data PM
  = PM { pStore   :: ListStore Property
       , pView    :: TreeView
       , pBox     :: VBox
       , pChanged :: IORef Bool
       }

instance CompoundWidget PM where
  type Outer PM = VBox
  outer = pBox

instance ConfigWidget PM where
  type Config PM = [Property]
  getConfig = listStoreToList . pStore
  setConfig pm config = do
    let store = pStore pm
    listStoreClear store
    mapM_ (listStoreAppend store) config
    treeViewSetCursor (pView pm) [0] Nothing
  clearConfig pm = listStoreClear $ pStore pm
  getChanged = readIORef .  pChanged
  clearChanged pm = writeIORef (pChanged pm) False
  grabFocus = widgetGrabFocus . pView

makePropertyManagerWidget parent onChanged = do
  store  <- listStoreNewDND [] Nothing Nothing
  sorted <- treeModelSortNewWithModel store

  let getByIter iter = do
        [n] <- treeModelGetPath store iter
        listStoreGetValue store n
      compBy f a b =
        comparing f <$> getByIter a <*> getByIter b

  treeSortableSetDefaultSortFunc sorted $ compBy (map toLower . propName)
  treeSortableSetSortFunc sorted 0 $ compBy (map toLower . propName)
  treeSortableSetSortFunc sorted 1 $ compBy (map toLower . propKey)
  treeSortableSetSortFunc sorted 2 $ compBy (fromEnum . propType)
  treeSortableSetSortFunc sorted 3 $ compBy (fromEnum . propReadOnly)
  treeSortableSetSortFunc sorted 4 $ compBy (fromEnum . propCustom)

  view <- treeViewNewWithModel sorted
  treeViewSetRulesHint view True

  let showType p =
        case propType p of
          PropertyInt    -> "integer"
          PropertyString -> "string"
      showBool acc p =
        if acc p then "yes" else "no"
      addColumn title id acc = do
        column <- treeViewColumnNew
        treeViewColumnSetSortColumnId column id
        treeViewAppendColumn view column
        treeViewColumnSetTitle column title
        cell <- cellRendererTextNew
        treeViewColumnPackStart column cell True
        cellLayoutSetAttributes column cell store
          (\p -> [ cellText := acc p ])

  addColumn "Name"      0   propName
  addColumn "Key"       1   propKey
  addColumn "Type"      2   showType
  addColumn "Read-only" 3 $ showBool propReadOnly
  addColumn "Custom"    4 $ showBool propCustom

  scroll <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetPolicy scroll PolicyAutomatic PolicyAutomatic
  scrolledWindowSetShadowType scroll ShadowIn
  containerAdd scroll view

  changed <- newIORef False

  let setChanged = do
        writeIORef changed True
        onChanged
      addProperty prop = do
        listStoreAppend store prop
        setChanged
        return ()

  edlg <- makePropertyEntryDialog parent
  addB <- buttonNewFromStock stockAdd
  addB `onClicked` runPropertyEntryDialog edlg addProperty

  delB <- buttonNewFromStock stockRemove
  delB `onClicked` do
    (path, _) <- treeViewGetCursor view
    case path of
      [n] -> do
        [n'] <- treeModelSortConvertPathToChildPath sorted path
        prop <- listStoreGetValue store n'
        when (propCustom prop) $ do
          listStoreRemove store n'
          s <- listStoreGetSize store
          unless (s < 1) $
            treeViewSetCursor view [min (s - 1) n] Nothing
          setChanged
      _ ->
        return ()

  view `on` cursorChanged $ do
    (path, _) <- treeViewGetCursor view
    case path of
      [_] -> do
        [n'] <- treeModelSortConvertPathToChildPath sorted path
        prop <- listStoreGetValue store n'
        widgetSetSensitive delB $ propCustom prop
      _ ->
        widgetSetSensitive delB False

  bbox <- hBoxNew True 5
  boxPackStartDefaults bbox addB
  boxPackStartDefaults bbox delB

  vbox <- vBoxNew False 5
  containerSetBorderWidth vbox 7
  boxPackStart vbox scroll PackGrow 0
  boxPackStart vbox bbox PackNatural 0

  return PM { pStore   = store
            , pView    = view
            , pBox     = vbox
            , pChanged = changed
            }

data PropertyEntryDialog
  = PropertyEntryDialog
    { dParent      :: Dialog
    , dDialog      :: Dialog
    , dWindowGroup :: WindowGroup
    , dEntry       :: PropertyEntry
    }

makePropertyEntryDialog parent = do
  dialog <- dialogNew

  parent `onDestroy` do widgetDestroy dialog
  dialogSetHasSeparator dialog False
  dialogAddButton dialog "gtk-cancel" ResponseCancel
  dialogAddButtonCR dialog "gtk-ok" ResponseOk

  entry <- makePropertyEntry
           (dialogSetResponseSensitive dialog ResponseOk)
           (\name -> isJust <$> property name)
  upper <- dialogGetUpper dialog
  boxPackStartDefaults upper $ outer entry
  widgetShowAll $ outer entry

  windowGroup <- windowGroupNew

  return PropertyEntryDialog { dParent      = parent
                             , dDialog      = dialog
                             , dWindowGroup = windowGroup
                             , dEntry       = entry
                             }

runPropertyEntryDialog d f = do
  let parent      = dParent d
      dialog      = dDialog d
      windowGroup = dWindowGroup d
      entry       = dEntry d

  windowSetTransientFor dialog parent
  windowGroupAddWindow windowGroup parent
  windowGroupAddWindow windowGroup dialog
  setData entry nullProperty
  setupView entry
  resp <- dialogRun dialog
  widgetHide dialog
  windowGroupRemoveWindow windowGroup parent
  windowGroupRemoveWindow windowGroup dialog
  when (resp == ResponseOk) $ f =<< getData entry

nullProperty =
  Property { propName      = ""
           , propKey       = ""
           , propType      = PropertyString
           , propReadOnly  = False
           , propCustom    = True
           , propReadValue = Nothing
           , propShowValue = Nothing
           }

comboGet combo =
  toEnum <$> comboBoxGetActive combo

comboSet ::
  Enum a                     =>
  ComboBox                   ->
  Maybe (ConnectId ComboBox) ->
  a                          ->
  IO ()
comboSet combo maybeCid =
  wrap . comboBoxSetActive combo . fromEnum
  where wrap | Just cid <- maybeCid = withSignalBlocked cid
             | otherwise            = id

setupCombo combo ref =
  combo `on` changed $ (writeIORef ref =<< comboGet combo)


class CompoundWidget w => EditorWidget w where
  type Data w
  setData   :: w -> Data w -> IO ()
  getData   :: w -> IO (Data w)
  setupView :: w -> IO ()

data PropertyEntry
  = PropertyEntry
    { eTable  :: Table
    , eName   :: Entry
    , eKey    :: Entry
    , eType   :: ComboBox
    , eRO     :: ComboBox
    , eExists :: String -> IO Bool
    , eValid  :: Bool -> IO ()
    }

instance CompoundWidget PropertyEntry where
  type Outer PropertyEntry = Table
  outer = eTable

instance EditorWidget PropertyEntry where
  type Data PropertyEntry = Property
  setData   = propertyEntrySetData
  getData   = propertyEntryGetData
  setupView = propertyEntrySetupView

propertyEntrySetData e p = do
  entrySetText (eName e) (propName p)
  entrySetText (eKey e) (propKey p)
  comboSet (eType e) Nothing (propType p)
  comboSet (eRO e) Nothing (propReadOnly p)
  eValid e =<< propertyEntryValid (eExists e) (propName p) (propKey p)

propertyEntryGetData e = do
  pname  <- entryGetText $ eName e
  pkey   <- entryGetText $ eKey e
  ptype  <- comboGet $ eType e
  pro    <- comboGet $ eRO e
  return Property { propName      = trim pname
                  , propKey       = trim pkey
                  , propType      = ptype
                  , propReadOnly  = pro
                  , propCustom    = True
                  , propReadValue = Nothing
                  , propShowValue = Nothing
                  }

propertyEntrySetupView e =
  widgetGrabFocus $ eName e

propertyEntryValid exists name key = do
  e <- exists name
  return . not $ e || null name || null key

makePropertyEntry valid exists = do
  table <- tableNew 4 2 False
  containerSetBorderWidth table 7
  tableSetColSpacings table 15
  tableSetRowSpacings table 5

  let addPair m w b = do
        l <- labelNewWithMnemonic m
        miscSetAlignment l 0.0 0.5
        labelSetMnemonicWidget l w
        tableAttach table l 0 1 b (b + 1) [Fill] [] 0 0
        tableAttach table w 1 2 b (b + 1) [Expand, Fill] [] 0 0

  nameE <- entryNew
  addPair "_Name" nameE 0

  keyE <- entryNew
  addPair "_Key" keyE 1

  typeC <- comboBoxNewText
  comboBoxInsertText typeC (fromEnum PropertyString) "string"
  comboBoxInsertText typeC (fromEnum PropertyInt) "integer"
  typeRef <- newIORef PropertyString
  typeCid <- setupCombo typeC typeRef
  addPair "_Type" typeC 2

  roC <- comboBoxNewText
  comboBoxInsertText roC (fromEnum False) "no"
  comboBoxInsertText roC (fromEnum True) "yes"
  roRef <- newIORef False
  roCid <- setupCombo roC roRef
  addPair "_Read-only" roC 3

  let check = do
        name  <- trim <$> entryGetText nameE
        key   <- trim <$> entryGetText keyE
        valid =<< propertyEntryValid exists name key
        case Map.lookup key builtinPropertyMap of
          Just prop -> do
            comboSet typeC (Just typeCid) $ propType prop
            widgetSetSensitive typeC False
            comboSet roC (Just roCid) $ propReadOnly prop
            widgetSetSensitive roC False
          Nothing   -> do
            comboSet typeC (Just typeCid) =<< readIORef typeRef
            widgetSetSensitive typeC True
            comboSet roC (Just roCid) =<< readIORef roRef
            widgetSetSensitive roC True

      checkInsert str pos = do
        check
        return $ (length str) + pos

      checkDelete _ _ = check

  nameE `afterInsertText` checkInsert
  nameE `afterDeleteText` checkDelete
  keyE  `afterInsertText` checkInsert
  keyE  `afterDeleteText` checkDelete

  return PropertyEntry { eTable  = table
                       , eName   = nameE
                       , eKey    = keyE
                       , eType   = typeC
                       , eRO     = roC
                       , eExists = exists
                       , eValid  = valid
                       }
