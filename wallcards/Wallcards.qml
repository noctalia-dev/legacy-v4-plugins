import "src"
import "src/Utils.js" as Utils
import qs.Commons
import qs.Widgets
import qs.Services.UI
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import qs.Commons

PanelWindow {
  id: root

  property int animationCardsDuration: pluginApi?.pluginSettings?.animation_cards_duration ?? pluginApi?.manifest?.metadata?.defaultSettings?.animation_cards_duration
  property int animationWindowDuration: pluginApi?.pluginSettings?.animation_window_duration ?? pluginApi?.manifest?.metadata?.defaultSettings?.animation_window_duration
  property bool animateWindow: pluginApi?.pluginSettings?.animate_window ?? pluginApi?.manifest?.metadata?.defaultSettings?.animate_window ?? true
  property color backgroundColor: pluginApi?.pluginSettings?.background_color ?? pluginApi?.manifest?.metadata?.defaultSettings?.background_color
  property real backgroundOpacity: pluginApi?.pluginSettings?.background_opacity ?? pluginApi?.manifest?.metadata?.defaultSettings?.background_opacity
  property int cardHeight: pluginApi?.pluginSettings?.card_height ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_height
  property int cardRadius: Style.radiusM
  property int cardSpacing: pluginApi?.pluginSettings?.card_spacing ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_spacing
  property int cardStripWidth: pluginApi?.pluginSettings?.card_strip_width ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_strip_width
  property int cardsShown: pluginApi?.pluginSettings?.cards_shown ?? pluginApi?.manifest?.metadata?.defaultSettings?.cards_shown
  property real centerWidthRatio: pluginApi?.pluginSettings?.center_width_ratio ?? pluginApi?.manifest?.metadata?.defaultSettings?.center_width_ratio
  property int currentIndex: cardDeck.currentIndex
  property string currentCardColor: filteredFiles[currentIndex]?.filterColor ?? ""
  property var imageFilter: pluginApi?.manifest?.metadata?.defaultSettings?.image_filter
  property var videoFilter: pluginApi?.manifest?.metadata?.defaultSettings?.video_filter
  property var filteredFiles: []
  property var availableColors: []
  property bool hideHelp: pluginApi?.pluginSettings?.hide_help ?? pluginApi?.manifest?.metadata?.defaultSettings?.hide_help ?? true
  property bool hideTopBar: pluginApi?.pluginSettings?.hide_top_bar ?? pluginApi?.manifest?.metadata?.defaultSettings?.hide_top_bar ?? false
  property bool livePreview: pluginApi?.pluginSettings?.live_preview ?? pluginApi?.manifest?.metadata?.defaultSettings?.live_preview
  property bool loading: thumbnailService.loading
  property int pendingProcesses: 0
  property var pluginApi: null
  property string selectedFilter: pluginApi?.pluginSettings?.selected_filter || pluginApi?.manifest?.metadata?.defaultSettings?.selected_filter
  property string selectedColorFilter: ""
  property real shearFactor: pluginApi?.pluginSettings?.shear_factor ?? pluginApi?.manifest?.metadata?.defaultSettings?.shear_factor
  property int thumbnailRevision: thumbnailService.thumbnailRevision
  property int topBarHeight: pluginApi?.pluginSettings?.top_bar_height ?? pluginApi?.manifest?.metadata?.defaultSettings?.top_bar_height
  property int topBarRadius: Style.radiusM
  property int duration: Settings.data.wallpaper.transitionDuration

  signal quitRequested

  function applyCurrentCard() {
        var f = filteredFiles[cardDeck.currentIndex];
        if (!f)
            return;

        var wallpaperPath = f.isVideo ? f.thumbnail : f.filePath;
        WallpaperService.changeWallpaper(wallpaperPath);

        if (f.isVideo) {
            applicant.command = ["bash", "-c", Utils.wallpaperCommand(f, duration)];
            applicant.running = true;
        } else {
            applicant.command = ["bash", "-c", Utils.mpvpaperKill];
            applicant.running = true;
        }
    }

  function applyFilterToFiles() {
    var currentFile = filteredFiles[cardDeck.currentIndex]?.filePath ?? "";

    var all = thumbnailService.files ?? [];
    var result = all;

    if (selectedFilter === "images")
      result = result.filter(f => !f.isVideo);
    else if (selectedFilter === "videos")
      result = result.filter(f => f.isVideo);

    var colors = {};
    for (var c = 0; c < result.length; c++)
      colors[result[c].filterColor] = true;
    availableColors = Object.keys(colors);

    if (selectedColorFilter !== "")
      result = result.filter(f => f.filterColor === selectedColorFilter);

    filteredFiles = result;

    var newIdx = 0;
    if (currentFile !== "") {
      for (var i = 0; i < result.length; i++) {
        if (result[i].filePath === currentFile) {
          newIdx = i;
          break;
        }
      }
    }

    cardDeck.jumpTo(newIdx);
  }

  function close() {
    if (exitAnimation.running)
      return;
    if (root.animateWindow) {
      exitAnimation.start();
    } else {
      root.quitRequested();
    }
  }

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.layer: WlrLayer.Overlay
  aboveWindows: true
  color: "transparent"
  exclusionMode: "Ignore"
  exclusiveZone: 0
  implicitHeight: screen.height
  implicitWidth: screen.width
  screen: pluginApi.panelOpenScreen

  onCurrentIndexChanged: {
    if (root.livePreview)
      applyCurrentCard();
  }

  onSelectedFilterChanged: applyFilterToFiles()
  onSelectedColorFilterChanged: applyFilterToFiles()
  onVisibleChanged: {
    if (visible) {
      if (root.animateWindow) {
        enterAnimation.start();
      } else {
        content.opacity = 1;
        content.scale = 1;
        background.opacity = root.backgroundOpacity;
      }
    }
  }

  Process {
    id: applicant

    command: []
    running: false
  }

  Connections {
    function onFilesChanged() {
      root.applyFilterToFiles();
    }

    target: thumbnailService
  }

  ThumbnailService {
    id: thumbnailService

    cacheDir: root.pluginApi?.Settings.cacheDir + "/wallcards"
    imageFilter: root.imageFilter
    videoFilter: root.videoFilter
    wallpaperDir: root.pluginApi?.Settings.data.wallpaper.directory
  }

  ParallelAnimation {
    id: enterAnimation

    NumberAnimation {
      duration: root.animationWindowDuration
      easing.type: Easing.OutCubic
      from: 0.85
      property: "scale"
      target: content
      to: 1.0
    }
    NumberAnimation {
      duration: root.animationWindowDuration
      easing.type: Easing.OutCubic
      from: 0
      property: "opacity"
      target: content
      to: 1
    }
    NumberAnimation {
      duration: root.animationWindowDuration
      easing.type: Easing.OutCubic
      from: 0
      property: "opacity"
      target: background
      to: root.backgroundOpacity
    }
  }

  ParallelAnimation {
    id: exitAnimation

    property int duration: root.animationWindowDuration * 0.4

    onFinished: root.quitRequested()

    NumberAnimation {
      duration: exitAnimation.duration
      easing.type: Easing.InCubic
      property: "opacity"
      target: content
      to: 0
    }
    NumberAnimation {
      duration: exitAnimation.duration
      easing.type: Easing.InCubic
      property: "scale"
      target: content
      to: 0.85
    }
    NumberAnimation {
      duration: exitAnimation.duration
      easing.type: Easing.InCubic
      property: "opacity"
      target: background
      to: 0
    }
  }

  Rectangle {
    id: background

    anchors.fill: parent
    color: root.backgroundColor
    opacity: 0

    MouseArea {
      anchors.fill: parent

      onClicked: root.close()
    }
  }

  Item {
    id: content

    anchors.fill: parent
    focus: true
    opacity: 0
    scale: 0.85

    Keys.onPressed: event => {
      if (event.modifiers & Qt.ShiftModifier) {
        if (event.key === Qt.Key_H) {
          root.cardHeight = Math.max(root.cardHeight - 10, parent.height * 0.10);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_L) {
          root.cardHeight = Math.min(root.cardHeight + 10, parent.height * 0.75);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_J) {
          cardDeck.centerWidthRatio = Math.max(cardDeck.centerWidthRatio - 0.01, 0.2);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_K) {
          cardDeck.centerWidthRatio = Math.min(cardDeck.centerWidthRatio + 0.01, 0.6);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_N) {
          root.cardsShown = Math.max(root.cardsShown - 2, 5);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_P) {
          root.cardsShown = Math.min(root.cardsShown + 2, 15);
          event.accepted = true;
          return;
        }
      }

      if (event.modifiers & Qt.ControlModifier) {
        if (event.key === Qt.Key_K) {
          root.cardSpacing = Math.max(root.cardSpacing + 2, 0);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_J) {
          root.cardSpacing = Math.max(root.cardSpacing - 2, 0);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_L) {
          root.cardStripWidth = Math.min(root.cardStripWidth + 5, 300);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_H) {
          root.cardStripWidth = Math.max(root.cardStripWidth - 5, 20);
          event.accepted = true;
          return;
        } else if (event.key === Qt.Key_S) {
          root.pluginApi.pluginSettings.card_height = root.cardHeight;
          root.pluginApi.pluginSettings.center_width_ratio = cardDeck.centerWidthRatio;
          root.pluginApi.pluginSettings.cards_shown = root.cardsShown;
          root.pluginApi.pluginSettings.card_spacing = root.cardSpacing;
          root.pluginApi.pluginSettings.card_strip_width = root.cardStripWidth;
          root.pluginApi.pluginSettings.hide_top_bar = root.hideTopBar;
          root.pluginApi.pluginSettings.live_preview = root.livePreview;
          root.pluginApi.pluginSettings.selected_filter = root.selectedFilter;
          root.pluginApi.pluginSettings.hide_help = root.hideHelp;
          root.pluginApi.pluginSettings.animate_window = root.animateWindow;
          root.pluginApi.saveSettings();
          event.accepted = true;
          return;
        }
      }

      function handleKey(event, bindings) {
        const action = bindings[event.key];
        if (action) {
          action();
          event.accepted = true;
        }
      }

      const bindings = {
        [Qt.Key_Question]: () => sideBar.expanded = !sideBar.expanded,
        [Qt.Key_Q]: () => root.close(),
        [Qt.Key_Return]: () => {
          root.applyCurrentCard();
          root.close();
        },
        [Qt.Key_Space]: () => root.applyCurrentCard(),
        [Qt.Key_Escape]: () => root.close(),
        [Qt.Key_A]: () => root.selectedFilter = "all",
        [Qt.Key_I]: () => root.selectedFilter = "images",
        [Qt.Key_V]: () => root.selectedFilter = "videos",
        [Qt.Key_T]: () => root.hideTopBar = !root.hideTopBar,
        [Qt.Key_F]: () => {
          if (root.selectedColorFilter !== "")
            root.selectedColorFilter = "";
          else
            root.selectedColorFilter = root.currentCardColor;
        },
        [Qt.Key_R]: () => {
          cardDeck.randomJump();
          topBar.flashShuffle();
        },
        [Qt.Key_P]: () => root.livePreview = !root.livePreview,
        [Qt.Key_K]: () => cardDeck.navigateTo(cardDeck.currentIndex + 1),
        [Qt.Key_J]: () => cardDeck.navigateTo(cardDeck.currentIndex - 1),
        [Qt.Key_L]: () => cardDeck.navigateTo(cardDeck.currentIndex + root.cardsShown - 2),
        [Qt.Key_H]: () => cardDeck.navigateTo(cardDeck.currentIndex - root.cardsShown + 2)
      };

      const action = bindings[event.key];
      if (action) {
        action();
        event.accepted = true;
      }
    }

    LoadingBar {
      id: loadingBar

      anchors.centerIn: parent
      pending: thumbnailService.pendingProcesses
      total: thumbnailService.fileCount
    }

    TopBar {
      id: topBar

      anchors.bottom: cardDeck.top
      anchors.bottomMargin: root.topBarHeight / 3
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: shearFactor * -root.topBarHeight * 4 / 3
      animationDuration: root.animationCardsDuration
      availableColors: root.availableColors
      colorOrder: thumbnailService.colorOrder
      colorOrderColors: thumbnailService.colorOrderColors
      currentCardColor: root.currentCardColor
      currentIndex: cardDeck.currentIndex
      filteredCount: root.filteredFiles.length
      height: root.topBarHeight
      livePreview: root.livePreview
      pluginApi: root.pluginApi
      radius: root.topBarRadius
      selectedColorFilter: root.selectedColorFilter
      selectedFilter: root.selectedFilter
      shearFactor: root.shearFactor
      visible: !loadingBar.visible && !root.hideTopBar
      width: cardDeck.width

      onColorFilterSelected: key => root.selectedColorFilter = key
      onFilterSelected: key => root.selectedFilter = key
      onLivePreviewToggled: root.livePreview = !root.livePreview
      onShuffleRequested: cardDeck.randomJump()
    }

    SideBar {
      id: sideBar

      anchors.left: parent.left
      anchors.leftMargin: Style.marginL
      anchors.verticalCenter: parent.verticalCenter
      hideHelp: root.hideHelp
      visible: !loadingBar.visible
    }

    CardDeck {
      id: cardDeck

      anchors.centerIn: parent
      animationDuration: root.animationCardsDuration
      cardRadius: root.cardRadius
      cardSpacing: root.cardSpacing
      cardStripWidth: root.cardStripWidth
      cardsShown: root.cardsShown
      centerWidthRatio: root.centerWidthRatio
      filteredCount: root.filteredFiles.length
      filteredModel: root.filteredFiles
      height: root.cardHeight
      shearFactor: root.shearFactor
      visible: !loadingBar.visible

      onApplyRequested: root.applyCurrentCard()
    }
  }
}
