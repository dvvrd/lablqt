open Core.Std
open Simplexmlparser
open Printf
let (|>) a f  = f a

let name  = function Element(x,_,_) -> x | PCData _ -> assert false
let attrs = function Element(_,x,_) -> x | PCData _ -> assert false
let sons  = function Element(_,_,x) -> x | PCData _ -> assert false
let find_node_exn ~name xs = List.find_exn xs ~f:(function Element(s,_,_) -> (s=name) | _ -> false)
let get_attr_exn ~name xs  = List.Assoc.find_exn xs name

let is_abstract ch =
  try
    let _ = find_node_exn ~name:"modifiers" ch |> sons |> find_node_exn ~name:"abstract" in
    true
  with Not_found -> false

let protectedConstructors  = function
  | Element(name,attr,ch) -> begin
    let newSons = List.filter_map ch ~f:(function
      | Element("constructor",attr,sons) -> begin
        let newSons = List.filter_map sons ~f:(function
          | (Element ("accessPolicy",att,_)) as e ->
              let v = get_attr_exn ~name:"value" att in
              if (v="private" || v="protected") then None else Some e
          | x -> Some x
        ) in
        Some (Element("constructor",attr,newSons) )
      end
      | x -> Some x
    ) in
    Some (Element(name,attr,newSons) )
  end
  | x -> Some x

let noPrivateNonAbstract = function
  | Element(name,attr,ch) -> begin
    let newSons = List.filter_map ch ~f:(function
      | Element("function",attr,children) -> begin
        let is_abstract =
          let modif_node = find_node_exn ~name:"modifiers" children in
          try let _ = find_node_exn ~name:"virtual" (sons modif_node) in
              true
          with Not_found -> false
        in
        let new_children = List.filter_map children ~f:(function
          | (Element ("accessPolicy",att,_)) as e ->
              let v = get_attr_exn ~name:"value" att in
              if ((v="private" || v="protected") && not is_abstract) then None else Some e
          | x -> Some x
        ) in
        Some (Element("function",attr,new_children) )
      end
      | x -> Some x
    ) in
    Some (Element(name,attr,newSons) )
  end
  | x -> Some x



let noDestructors = function
  | Element(n,attr,ch) ->
      let new_children = List.filter ch ~f:(fun node -> (name node)<>"destructor") in
      Some( Element(n,attr,new_children) )
  | x -> Some x

let noMETAfuncs = function
  | Element(n,a,ch) ->
      let new_ch = List.filter ch  ~f:(function
        | Element ("function",a2,_) ->
            let name = get_attr_exn ~name:"name" a2 in
            let ans  = not (List.mem ["d_func";"operator=";"operator!";"operator<<";"operator>>"] name) in
            ans
        | x -> true) in
      Some( Element(n,a,new_ch) )
  | x -> Some x


let noTemplates = function
  | Element (n,att,ch) ->
      let ans = List.filter ch ~f:(function
        | Element ("function",att2,xs) ->
            let ret_node  = find_node_exn ~name:"return" xs in
            let ret_typ   = ret_node |> attrs |> get_attr_exn ~name:"type" in
            (ret_typ <> "T") && (ret_typ <> "QList<T>")
        | _ -> true
      ) in
      Some( Element(n,att,ans) )
  | x -> Some x

let wut_methods_to_remove =
  let (<<) t el = String.Set.add t el in
  let empty = String.Set.empty in
  [ ("QObject",
     empty << "installEventFilter" << "userData" << "operator=" << "disconnect" << "connect"
    << "dumpObjectInfo" << "moveToThread" << "removeEventFilter" << "isWidgetType" << "deleteLater" <<
    "receivers" << "dumpObjectTree" << "findChildren" << "connect_functor" << "connectImpl" << "thread"
    <<"signalsBlocked" << "registerUserData" << "setUserData" <<  "disconnectImpl" << "dynamicPropertyNames"
    << "connectNotify" << "disconnectNotify" << "isSignalConnected" << "childEvent" << "timerEvent"
    << "sender" << "senderSignalIndex" << "blockSignals" << "inherits" << "killTimer" << "parent"
    << "destroy" << "customEvent" << "children" << "eventFilter" << "setObjectName"
    << "property" << "setProperty" << "startTimer" << "objectName"
  )
  ; ("QPaintDevice", empty << "paintEngine" << "logicalDpiY" << "metric" << "qt_paint_device_metric"
    << "physicalDpiX" << "physicalDpiY" << "devType" << "logicalDpiX" << "colorCount"
    << "depth" << "height" << "heightMM" << "paintingActive" << "initPainter" << "redirected"
    << "sharedPainter" << "width" << "widthMM"
  )
  ; ("QGraphicsEvent",
    empty << "dragEnterEvent" << "zValue" << "qt_closestLeaf" << "childItems"
    << "addToIndex" << "grabMouse" << "isUnderMouse" << "collidingItems" << "effectiveOpacity"
    << "acceptDrops" << "setFiltersChildEvents" << "hoverMoveEvent" << "boundingRegionGranularity"
    << "handlesChildEvents" << "dropEvent" << "wheelEvent" << "inputMethodEvent"
    << "installSceneEventFilter"  << "setCacheMode" << "setAcceptedMouseButtons")
  ; ("QFrame", empty << "frameShadow" << "frameStyle" << "setMidLineWidth" << "changeEvent" << "frameShape"
    << "midLineWidth" << "setFrameStyle" << "drawFrame" << "frameRect" << "frameWidth" << "isWindowType"
    << "lineWidth" << "mapToParent" << "setFocusProxy" << "setFrameRect" << "setFrameShape"
    << "setInputMethodHints"  << "setLayout" << "setFrameShadow" << "setLineWidth" << "sizeHint"
    (* inner emums *)
    << "QFrame::Shadow" << "QFrame::Shape" << "QFrame::StyleMask"
  )
  ; ("QPixmap",
     empty << "handle" << "setDevicePixelRatio" << "operator QVariant" << "metric"
     << "defaultDepth" << "data_ptr" << "devicePixelRatio" << "createMaskFromColor" << "isDetached" <<
     "devType" << "grabWindow"<< "fromImageReader" << "cacheKey" << "isQBitmap" << "createHeuristicMask"
     << "doImageIO" << "save")
  ; ("QWidget", empty << "fontMetrics" << "insertAction" << "insertActions" << "addActions"
    << "removeAction" << "actions" << "setFont" << "font" << "event" << "objectName" <<"setLocale"
    << "backgroundRole" << "foregroundRole" << "setBackgroundRole" << "setForegroundRole"
    << "dragLeaveEvent" << "testAttribute_helper" << "focusPreviousChild" << "focusNextChild"
    << "metric" << "destroy" << "findChild" << "raise" << "mapFromParent" << "style" << "ungrabGesture"
    << "contextMenuPolicy" << "setMinimumHeight" << "sizeHint" << "contentsRect" <<"setWindowModality"
    << "windowModality" << "toolTip" << "baseSize" << "isEnabledTo" << "tabletEvent" << "setAcceptDrops"
    << "focusProxy" << "mouseGrabber" << "releaseShortcut" << "normalGeometry" << "setMaximumSize"
    << "fontInfo" << "addAction" << "setShortcutAutoRepeat" << "focusNextPrevChild"
    << "setWhatsThis" << "visibleRegion" << "focusOutEvent" << "setContextMenuPolicy"
    << "accessibleDescription" << "overrideWindowFlags" << "dragMoveEvent" << "grabMouse" << "unsetCursor"
    << "window" << "mapTo" << "redirected" << "whatsThis" << "updateMicroFocus" << "windowHandle"
    << "overrideWindowState" << "setMask" << "winId"
    << "restoreGeometry" << "setWindowIcon" << "isWindowModified" << "setFixedHeight" << "maximumSize"
    << "mask" << "heightForWidth" << "setFocus" << "setHidden" << "setDisabled" << "setEnabled"
    << "lower" << "windowIconText" << "windowRole" << "windowState" << "widthMM" << "windowFilePath"
    << "updatesEnabled" << "usetLocale" << "unsetLayoutDirection" << "underMouse" << "topLevelWidget"
    << "testAttribute" << "statusTip" << "stackUnder" << "setWindowIconText" << "setWindowFlags"
    << "setUpdatesEnabled" << "setTabOrder" << "setStatusTip" << "setSizeIncrement" << "setShortcutEnabled"
    << "setMouseTracking" << "internalWinId" << "moveEvent" << "mapToParent" << "setLocale"
     << "setMinimumSize" << "setMinimumWidth" << "setFoxusProxy" << "setFocusPolicy" << "setFixedWidth"
     << "setBaseSize" << "setContentsMargins" << "setAutoFillBackground" << "setAttribute"  << "setBaseSize"
     << "setAccessibleDescription" << "setAccessibleName" << "releaseMouse" << "previousInFocusChain"
     << "parentWidget" << "paintingActive" << "nextInFocusChain" << "nativeParentWidget" << "minimumWidth"
     << "minimumHeight" << "maximumWidth" << "maximumHeight" << "leaveEvent" << "killTimer"
    << "keyboardGrabber" << "isWindowType" << "isWindow" << "isVisibleTo" << "isTopLevel" << "isRightToLeft"
    << "isModal" << "isMaximized" << "isMinimized" << "isLeftToRight" << "isHidden" << "isFullScreen"
    << "isEnabledToTLW" << "mapToParent" << "setLayout" << "setLayoutDirection"
    << "isEnabled" << "isAncestorOf" << "isActiveWindow" << "heightMM" << "height" << "hasMouseTracking"
    << "hasHeightForWidth" << "grabKeyboard" << "grabGesture" << "focusPolicy" << "eventFilter"
    << "enterEvent" << "ensurePolished" << "devType" << "depth" << "customEvent" << "createWinId"
    << "colorCount" << "isWindowType" << "setInputMethodHints" << "setFocusProxy"
    << "clearMask" << "clearFocus" << "childAt" << "changeEvent" << "blockSignals" << "autoFillBackground"
    << "acceptDrops" << "accessibleName" << "activateWindow" << "actionEvent" << "adjustSize"
    << "backingStore" << "childrenRect" << "childrenRegion" << "closeEvent" << "contentsMargins"
    << "contextMenuEvent" << "create" << "cursor" << "dragEnterEvent" << "dropEvent"
    << "effectiveWinId" << "focusInEvent" << "focusWidget" << "frameGeometry" << "frameSize"
    << "geometry" << "getContentsMargins" << "grab" << "grabShortcut" << "graphicsEffect"
    << "graphicsProxyWidget" << "hasFocus" << "hideEvent" << "initPainter" << "inputMethodEvent"
    << "inputMethodHints" << "inputMethodQuery" << "isVisible" << "layout" << "layoutDirection"
    << "locale" << "mapFrom" << "mapFromGlobal" << "mapToGlobal" << "mapToGlobal" << "minimumSize"
    << "minimumSizeHint" << "move" << "nativeEvent" << "paintEvent" <<"paintingActive"
    << "palette" << "pos" << "qt_qwidget_data" << "qt_widget_private" << "rect" << "redirected"
    << "releaseKeyboard" << "render" << "repaint" << "resize" << "scroll" << "resizeEvent" << "saveGeometry"
    << "setBackingStore" << "setCursor" << "setFixedSize" << "setGeometry" << "setGraphicsEffect"
    << "setSizePolicy" << "setPalette" << "setMaximumWidth" << "setMaximumHeight" <<  "setStyle"
    << "setToolTip" << "setWindowFilePath" << "setWindowOpacity" << "setWindowRole" << "setWindowState"
    << "sharedPainter" << "size" << "sizeIncrement" << "sizePolicy" << "startTimer"
    << "styleSheet" << "takeLayout" << "unsetLocale"<< "update" << "wheelEvent" << "wheelEvent" << "width"
    << "windowIcon" << "windowTitle" << "close" << "hide" << "setStyleSheet" << "setVisible"
    << "setWindowModified" << "showMaximized" << "showMinimized" << "showNormal"
    << "x" << "y" << "windowType" << "windowOpacity" << "winId" << "windowFlags" << "showEvent"
    << "mouseMoveEvent" << "mousePressEvent" << "mouseReleaseEvent"
  )
  ; ("QGraphicsScene",
    empty << "style" << "palette" << "setPalette" << "setStyle" << "items" << "itemIndexMethod"
     << "setFont" << "font" << "dropEvent" << "dragMoveEvent" << "dragLeaveEvent" << "dragEnterEvent"
     << "dragMoveEvent")
  ; ("QGraphicsItem",
     empty << "cursor" << "setCursor")
  ; ("QGraphicsPixmapItem",
     empty << "shapeMode" << "setShapeMode" << "transformationMode" << "type")
  ; ("QGraphicsView",
     empty << "dragMode" << "setDragMode" << "setTransformationAnchor" <<
     "setResizeAnchor" << "transformationAnchor" << "resizeAnchor" << "items" << "dragEnterEvent"
     << "inputMethodQuery" << "resizeEvent" << "showEvent" << "dropEvent" << "dragMoveEvent"
     << "rubberBandSelectionMode" << "updateScene" << "inputMethodEvent" << "viewportEvent"
     << "dragLeaveEvent" << "paintEvent" << "contextMenuEvent" << "focusOutEvent" << "focusNextPrevChild"
     << "event")
  ; ("QAbstractItemModel", empty << "endInsertColumns" << "endInsertRows" << "endMoveColumns"
    << "endMoveRows" << "endRemoveColumns" << "endRemoveRows" << "endResetModel" << "eventFilter"
    << "revert" << "submit" << "parent" << "beginInsertColumns" << "beginInsertRows"
    << "beginMoveColumns" << "beginMoveRows" << "beginRemoveColumns" << "beginRemoveRows"
    << "beginResetModel" << "buddy" << "canDropMimeData" << "canFetchMore" << "changePersistentIndex"
    << "changePersistentIndexList" << "createIndex" << "decodeData" << "doSetRoleNames"
    << "doSetSupportedDragActions" << "dropMimeData" << "encodeData" << "fetchMore" << "hasChildren"
    << "hasIndex" << "headerData" << "insertColumn" << "insertColumns" << "insertRow" << "insertRows"
    << "itemData" << "match"<< "mimeData" << "mimeTypes" << "moveColumn" << "moveColumns"
    << "moveRow" << "moveRows" << "persistentIndexList" << "removeColumn" << "removeColumns"
    << "removeRow" << "removeRows" << "setData" << "setHeaderData" << "setItemData" << "sibling"
    << "sort" << "span" << "startTimer" << "supportedDragActions" << "supportedDropActions" << "flags"
    (* enums *)

    << "LayoutChangeHint"
  )
  ; ("QAbstractItemView", empty << "alternatingRowColors" << "autoScrollMargin" << "doAutoScroll"
    << "dirtyRegionOffset" << "dragDropMode" << "dragDropOverwriteMode" << "dragEnabled"
    << "dragEnterEvent" << "dragLeaveEvent" << "dragMoveEvent" << "dropEvent" << "dropIndicatorPosition"
    << "edit" << "editTriggers" << "executeDelayedItemsLayout" << "focusInEvent" << "focusNextPrevChild"
    << "focusOutEvent" << "hasAutoScroll" << "horizontalScrollMode" << "horizontalStepsPerItem"
    << "iconSize" << "indexWidget" << "inputMethodEvent" << "inputMethodQuery" << "itemDelegate"
    << "itemDelegateForColumn" << "itemDelegateForRow" << "keyboardSearch" << "mouseDoubleClickEvent"
    << "mouseMoveEvent" << "mousePressEvent" << "mouseReleaseEvent" << "openPersistentEditor"
    << "resizeEvent" << "rootIndex" << "scheduleDelayedItemsLayout" << "scrollDirtyRegion"
    << "selectedIndexes" << "selectionBehavior" << "selectionCommand" << "selectionMode"
    << "selectionModel" << "setAlternatingRowColors" << "setAutoScroll" << "setAutoScrollMargin"
    << "setDefaultDropAction" << "setDirtyRegion" << "setDragDropMode" << "setDragDropOverwriteMode"
    << "setDragEnabled" << "setDropIndicatorShown" << "setEditTriggers" << "setHorizontalScrollMode"
    << "setHorizontalStepsPerItem" << "setIconSize" << "setIndexWidget" << "setItemDelegate"
    << "setItemDelegateForColumn" << "setItemDelegateForRow" << "setSelectionBehavior"
    << "setSelectionMode" << "setSelectionModel" << "setState" << "setTabKeyNavigation"
    << "setTextElideMode" << "setVerticalScrollMode" << "setVerticalStepsPerItem" << "showDropIndicator"
    << "sizeHintForColumn" << "sizeHintForIndex" << "sizeHintForRow" << "startAutoScroll" << "startDrag"
    << "state" << "stopAutoScroll" << "tabKeyNavigation" << "textElideMode" << "timerEvent"
    << "verticalScrollMode" << "verticalStepsPerItem" << "viewOptions" << "viewportEvent"
    << "clearSelection"
    (* enums *)
    << "QAbstractItemView::EditTrigger"
  )
  ; ("QAbstractListModel", empty << "setParent" <<  "isWindowType" << "dropMimeData"
  )
  ; ("QAbstractScrollArea", empty << "horizontalScrollBar" << "verticalScrollBarPolicy" <<
    "horizontalScrollBarPolicy" << "setHorizontalScrollBar" << "verticalScrollBar" << "setVerticalScrollBar"
     << "dragLeaveEvent" << "dropEvent" << "addScrollBarWidget" << "contextMenuEvent" << "cornerWidget"
    << "maximumViewportSize" << "minimumSizeHint" << "scrollBarWidgets" << "scrollContentsBy"
    << "setCornerWidget" << "setHorizontalScrollBarPolicy" << "setViewport" << "setViewportMargins"
    << "setViewportMargins" << "sizeHint" << "setupViewport" << "viewport" << "viewportEvent"
    << "viewportSizeHint" << "wheelEvent"
    << "mouseMoveEvent" << "mousePressEvent" << "mouseReleaseEvent"
  )
  ; ("QEvent", empty << "QEvent::Type"
  )

  ; ("QListView", empty << "visualIndex" << "visualRect" << "wheelEvent" << "viewMode" << "batchSize"
    << "clearPropertyFlags" << "indexAt" << "isRowHidden" << "isSelectionRectVisible"
    << "isWrapping" << "modelColumn" << "moveCursor" << "movement" << "rectForIndex" << "resizeContents"
    << "resizeMode" << "scrollContentsBy" << "scrollTo" << "selectedIndexes" << "setBatchSize"
    << "setModelColumn" << "setPositionForIndex" << "setRowHidden" << "setSelectionRectVisible"
    << "setSpacing" << "setUniformItemSizes" << "spacing" << "uniformItemSizes" << "clearSelection"
    << "commitData" << "doItemsLayout" << "horizontalScrollbarValueChanged" << "verticalScrollbarAction"
    << "verticalScrollbarValueChanged" << "setFlow" << "setGridSize" << "setLayoutMode"
    << "setMovement" << "setResizeMode" << "setViewMode" << "setWordWrap" << "setWrapping"
    << "startDrag" << "timerEvent" << "verticalOffset" << "viewOptions" << "wordWrap" << "commitData"
    << "currentChanged" << "doItemsLayout" << "editorDestroyed" << "horizontalScrollbarAction"
    << "horizontalScrollbarValueChanged" << "reset"
    << "rowsAboutToBeRemoved" << "scrollToBottom" << "rowsInserted" << "scrollToTop"
    << "selectAll" << "selectionChanged" << "setCurrentIndex" << "setRootIndex" <<"setWindowTitle"
    << "update" << "updateEditorData" << "updateEditorGeometries" << "updateGeometries"
    << "verticalScrollbarAction" << "verticalScrollbarValueChanged"
  )
  ; ("QPaintDevice", empty << "QPaintDevice::PaintDeviceMetric"
  )
  ; ("QByteArray", empty << "data" )
  ; ("QImage",     empty << "bits" << "scanLine")
  ; ("QTreeWidget",empty << "indexOfTopLevelItem")
  ]
(* names of methods to remove from any class *)
let just_names =
  [ "event" (* Qt doesn't recommend to override this method *)
  ; "flush"
  ; "initialize" (* because preprocesser has its own `flush` *)
  ; "d_func"
  ]
let names_cond : (string -> bool) list =
  [ (String.is_prefix ~prefix:"operator")
  ]

let filter_methods = function
  | (Element (name,att,ch)) as clas_node -> begin
    try
      let class_name = get_attr_exn ~name:"name" att in
      let set = List.Assoc.find_exn wut_methods_to_remove class_name in
      let new_ch = List.filter ch ~f:(function
        | (Element ("function",att,sons)) ->
            let name = (get_attr_exn ~name:"name" att) in
            (is_abstract sons) ||
            (not (
              (String.Set.mem set name) ||
              (List.mem just_names name) ||
              (names_cond |> List.map ~f:(fun f -> f name) |> List.fold ~init:false ~f:(||) )
             ) )
        | (Element ("signal",att,sons))  ->
            (is_abstract sons) ||
            (not (String.Set.mem set (get_attr_exn ~name:"name" att) ) )
        | (Element ("slot",att,sons))  ->
            (is_abstract sons) ||
            (not (String.Set.mem set (get_attr_exn ~name:"name" att) ) )
        | Element ("enum",att,_) ->
            not (String.Set.mem set (get_attr_exn ~name:"name" att))
        | x  -> true
      ) in
      Some (Element (name,att,new_ch))
    with Not_found -> Some clas_node
  end
  | x -> Some x

let filter_qt_enums = function
  | (Element("namespace",att,ch)) when "Qt" = get_attr_exn ~name:"name" att ->
      let new_ch = List.filter ch ~f:(function
        | Element ("enum",atts,_) ->
            let name = get_attr_exn ~name:"name" atts in
            List.mem ["Qt::WindowType"; "Qt::ItemDataRole"; "Qt::Key"] name
        | _ -> true
      ) in
      Some (Element ("namespace",att,new_ch))
  | x -> Some x
