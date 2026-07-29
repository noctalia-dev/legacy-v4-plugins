import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.Modules.Panels.Launcher.Providers
import qs.Commons
import qs.Services.Keyboard
import qs.Services.UI
import qs.Widgets

// Space launcher core - Rotational Disk UI (Fixed Initialization)
Item {
  id: root

  // External interface - set by parent
  property var screen: null
  property bool isOpen: false
  signal requestClose
  signal requestCloseImmediately

  function closeImmediately() {
    requestCloseImmediately();
  }

  // State
  property string searchText: ""
  property int selectedIndex: 0
  property var results: []
  property var providers: []
  property var activeProvider: null
  property bool resultsReady: false
  property bool ignoreMouseHover: true

  readonly property bool animationsDisabled: Settings.data.general.animationDisabled

  readonly property var defaultProvider: appsProvider
  readonly property var currentProvider: activeProvider || defaultProvider

  // Providers
  ApplicationsProvider {
    id: appsProvider
    onEntriesChanged: root.updateResults()
    Component.onCompleted: {
      registerProvider(this);
    }
  }

  // Lifecycle
  onIsOpenChanged: {
    if (isOpen) {
      onOpened();
    } else {
      onClosed();
    }
  }

  onSearchTextChanged: {
    if (isOpen) {
      updateResults();
    }
  }

  function onOpened() {
    resultsReady = true;
    // Delay update slightly to ensure provider is ready
    Qt.callLater(updateResults);
    searchInput.inputItem.forceActiveFocus();
  }

  function onClosed() {
    searchText = "";
  }

  function close() {
    requestClose();
  }

  // Provider registration
  function registerProvider(provider) {
    providers.push(provider);
    provider.launcher = root;
    if (provider.init)
      provider.init();
  }

  function updateResults() {
    results = appsProvider.getResults(searchText);
    selectedIndex = 0;
  }

  function activate() {
    const idx = diskView.currentIndex;
    if (results && results.length > 0 && idx >= 0 && idx < results.length) {
      const item = results[idx];
      if (item && item.onActivate) {
        Logger.d("LauncherSpace", "Calling onActivate for: " + item.name);
        item.onActivate();
      }
    }
  }

  function handleKeyPress(event) {
    if (Keybinds.checkKey(event, 'escape', Settings)) {
      close();
      event.accepted = true;
      return;
    }

    if (Keybinds.checkKey(event, 'enter', Settings) || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activate();
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
      inertiaTimer.stop();
      offsetAnim.stop();
      offsetAnim.to = Math.round(diskView.offset) - 1;
      offsetAnim.start();
      event.accepted = true;
    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      inertiaTimer.stop();
      offsetAnim.stop();
      offsetAnim.to = Math.round(diskView.offset) + 1;
      offsetAnim.start();
      event.accepted = true;
    }
  }

  // ==================== UI Content ====================

  // 0. Hidden Search Input
  NTextInput {
    id: searchInput
    width: 0
    height: 0
    opacity: 0
    text: root.searchText
    onTextChanged: root.searchText = text
    onAccepted: root.activate()

    Component.onCompleted: {
      if (searchInput.inputItem) {
        searchInput.inputItem.Keys.onPressed.connect(function (event) {
          root.handleKeyPress(event);
        });
      }
    }
  }

  // 1. Outer Dark Ring
  Rectangle {
    id: outerRing
    anchors.centerIn: parent
    width: Math.floor(Math.min(parent.width, parent.height) / 2) * 2
    height: width
    radius: width / 2
    color: Color.mSurface
    border.width: 0
    border.color: "transparent"

    // 2. Inner Light Circle
    Rectangle {
      id: innerCircle
      anchors.centerIn: parent
      width: Math.floor((parent.width * 0.6) / 2) * 2
      height: width
      radius: width / 2
      color: Color.mSurfaceVariant
      z: 5

      // 3. Selected app in the VERY center
      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.marginS
        width: parent.width * 0.7

        Item {
          Layout.preferredWidth: parent.width * 0.5
          Layout.preferredHeight: width
          Layout.alignment: Qt.AlignHCenter

          IconImage {
            anchors.fill: parent
            source: diskView.currentItemData ? ThemeIcons.iconFromName(diskView.currentItemData.icon, "application-x-executable") : ""
            asynchronous: true
          }
        }

        NText {
          Layout.fillWidth: true
          text: diskView.currentItemData ? diskView.currentItemData.name : "Loading..."
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeL
          color: Color.mOnSurface
        }
      }
    }

    // 4. Icons rotating on the dark ring
    PathView {
      id: diskView
      anchors.fill: parent
      model: root.results
      z: 10
      interactive: false

      // DJ Momentum System
      property real velocity: 0
      property var lastTime: 0

      Timer {
        id: inertiaTimer
        interval: 16
        repeat: true
        onTriggered: {
          diskView.offset += diskView.velocity;
          diskView.velocity *= 0.94; // Deceleration
          if (Math.abs(diskView.velocity) < 0.01) {
            diskView.velocity = 0;
            diskView.offset = Math.round(diskView.offset);
            stop();
          }
        }
      }

      NumberAnimation {
        id: offsetAnim
        target: diskView
        property: "offset"
        duration: 350
        easing.type: Easing.OutQuart
      }

      DragHandler {
        id: djDrag
        onActiveChanged: {
          if (active) {
            inertiaTimer.stop();
            diskView.velocity = 0;
            diskView.lastTime = Date.now();
          } else {
            inertiaTimer.start();
          }
        }
        onTranslationChanged: {
          let now = Date.now();
          let dt = (now - diskView.lastTime) / 1000.0;
          if (dt > 0) {
            let sens = 40.0 * Style.uiScaleRatio;
            let delta = -(translation.x + translation.y) / sens;
            diskView.velocity = delta / (dt * 60); // Simple velocity estimation
            diskView.offset += delta;
            diskView.lastTime = now;
          }
        }
      }

      WheelHandler {
        acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
        onWheel: (event) => {
          inertiaTimer.stop();
          let sens = 40.0 * Style.uiScaleRatio;
          let dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 8.0;
          let dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8.0;
          let delta = -(dx + dy) / sens;

          diskView.offset += delta;
          diskView.velocity = delta * 2.5;
          inertiaTimer.start();
        }
      }

      property var currentItemData: model && model.length > 0 ? model[currentIndex] : null
      onCurrentIndexChanged: root.selectedIndex = currentIndex

      highlightMoveDuration: 250
      pathItemCount: Math.min(model.length, 12)
      preferredHighlightBegin: 0.5
      preferredHighlightEnd: 0.5
      highlightRangeMode: PathView.StrictlyEnforceRange

      path: Path {
        startX: outerRing.width / 2
        startY: outerRing.height * 0.1

        PathAngleArc {
          centerX: outerRing.width / 2
          centerY: outerRing.height / 2
          radiusX: outerRing.width * 0.4
          radiusY: outerRing.height * 0.4
          startAngle: -90
          sweepAngle: 360
        }
      }

      delegate: Item {
        id: delegateRoot
        width: 64 * Style.uiScaleRatio
        height: width
        scale: PathView.isCurrentItem ? 1.2 : 0.8
        opacity: PathView.isCurrentItem ? 0.0 : 1.0 

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        required property var modelData

        IconImage {
          anchors.fill: parent
          source: ThemeIcons.iconFromName(modelData.icon, "application-x-executable")
        }

        TapHandler {
          onTapped: {
            if (diskView.currentIndex === index) {
              root.activate();
            } else {
              diskView.currentIndex = index;
            }
          }
        }
      }
    }
  }

  // 5. Visible Search Bar (Small, at the bottom of the disk)
  NBox {
    anchors.top: outerRing.bottom
    anchors.topMargin: Style.marginL
    anchors.horizontalCenter: parent.horizontalCenter
    width: 250 * Style.uiScaleRatio
    height: 35 * Style.uiScaleRatio
    radius: Style.radiusM
    color: "#1f1f1f"
    visible: root.searchText !== "" 

    NText {
      anchors.centerIn: parent
      text: (root.pluginApi ? root.pluginApi.tr("plugin.vinyl-launcher.search") : "Search:") + " " + root.searchText
      color: Color.mOnSurface
      font.italic: true
      pointSize: Style.fontSizeS
    }
  }
}
