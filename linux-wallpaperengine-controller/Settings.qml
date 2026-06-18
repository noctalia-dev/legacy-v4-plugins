import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "helpers/shared/ColorCacheHelpers.js" as ColorCacheHelpers
import "helpers/panel/BadgeHelpers.js" as BadgeHelpers

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  width: parent ? parent.width : 640 * Style.uiScaleRatio
  implicitHeight: 720 * Style.uiScaleRatio
  Layout.fillWidth: true

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editWallpapersFolder: cfg.wallpapersFolder ?? defaults.wallpapersFolder ?? ""
  property string editIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property bool editEnableExtraPropertiesEditor: cfg.enableExtraPropertiesEditor ?? defaults.enableExtraPropertiesEditor ?? true
  property string editDefaultScaling: cfg.defaultScaling ?? defaults.defaultScaling ?? "fill"
  property string editDefaultClamp: cfg.defaultClamp ?? defaults.defaultClamp ?? "clamp"
  property int editDefaultFps: cfg.defaultFps ?? defaults.defaultFps ?? 30
  property int editDefaultVolume: cfg.defaultVolume ?? defaults.defaultVolume ?? 100
  property bool editDefaultMuted: cfg.defaultMuted ?? defaults.defaultMuted ?? true
  property bool editDefaultAudioReactiveEffects: cfg.defaultAudioReactiveEffects ?? defaults.defaultAudioReactiveEffects ?? true
  property bool editDefaultNoAutomute: cfg.defaultNoAutomute ?? defaults.defaultNoAutomute ?? false
  property bool editDefaultDisableMouse: cfg.defaultDisableMouse ?? defaults.defaultDisableMouse ?? false
  property bool editDefaultDisableParallax: cfg.defaultDisableParallax ?? defaults.defaultDisableParallax ?? false
  property bool editDefaultNoFullscreenPause: cfg.defaultNoFullscreenPause ?? defaults.defaultNoFullscreenPause ?? false
  property bool editDefaultFullscreenPauseOnlyActive: cfg.defaultFullscreenPauseOnlyActive ?? defaults.defaultFullscreenPauseOnlyActive ?? false
  property bool editAutoApplyOnStartup: cfg.autoApplyOnStartup ?? defaults.autoApplyOnStartup ?? true
  property bool editShowSidebarDescription: cfg.showSidebarDescription ?? defaults.showSidebarDescription ?? false
  property int editWallpaperScanCacheMinutes: cfg.wallpaperScanCacheMinutes ?? defaults.wallpaperScanCacheMinutes ?? 10
  readonly property var defaultBadgeOrder: BadgeHelpers.normalizedDefaultOrder(defaults.badgeOrder)
  readonly property var defaultBadgeEnabled: BadgeHelpers.normalizedDefaultEnabled(defaults.badgeEnabled)
  property var editBadgeOrder: BadgeHelpers.normalizeBadgeOrder(cfg.badgeOrder, defaultBadgeOrder)
  property var editBadgeEnabled: BadgeHelpers.normalizeBadgeEnabled(cfg.badgeEnabled, defaultBadgeEnabled)
  property bool scanning: false
  property bool refreshingCacheSize: false
  property bool clearingCache: false
  property string cacheSizeLabel: pluginApi?.tr("settings.cache.sizeUnknown")

  readonly property string pluginCacheDir: ColorCacheHelpers.pluginCacheDir(
    Settings.cacheDir,
    pluginApi?.manifest?.id || pluginApi?.pluginId || "linux-wallpaperengine-controller"
  )

  spacing: Style.marginL

  function badgeLabel(key) {
    return BadgeHelpers.settingsBadgeLabel(key, badgeKey => pluginApi?.tr(badgeKey));
  }

  function badgeIcon(key) {
    return BadgeHelpers.settingsBadgeIcon(key);
  }

  function setBadgeEnabled(key, enabled) {
    const normalizedKey = String(key || "").trim();
    const next = Object.assign({}, root.editBadgeEnabled || ({}));
    next[normalizedKey] = enabled;
    root.editBadgeEnabled = next;
  }

  function moveBadge(fromIndex, toIndex) {
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= editBadgeOrder.length || toIndex >= editBadgeOrder.length || fromIndex === toIndex) {
      return;
    }

    const next = editBadgeOrder.slice();
    const moved = next[fromIndex];
    next.splice(fromIndex, 1);
    next.splice(toIndex, 0, moved);
    editBadgeOrder = next;
  }

  function refreshCacheSize() {
    if (root.refreshingCacheSize) {
      return;
    }

    root.refreshingCacheSize = true;
    cacheSizeProcess.running = true;
  }

  function formatBytes(bytes) {
    return ColorCacheHelpers.formatBytes(bytes, pluginApi?.tr("settings.cache.sizeUnknown"));
  }

  function preservedWallpaperColorScreenshots() {
    return ColorCacheHelpers.preservedEntriesForScreens(
      pluginApi?.pluginSettings?.wallpaperColorScreenshots,
      Quickshell.screens
    );
  }

  function clearCacheCommand() {
    const preserved = root.preservedWallpaperColorScreenshots();
    return ColorCacheHelpers.clearCacheCommand(root.pluginApi?.pluginDir || "", root.pluginCacheDir, preserved);
  }

  Component.onCompleted: refreshCacheSize()

  NTabBar {
    id: tabBar
    Layout.fillWidth: true
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: pluginApi?.tr("settings.category.interfaceTitle")
      tabIndex: 0
      checked: tabBar.currentIndex === 0
    }

    NTabButton {
      text: pluginApi?.tr("settings.category.compatibilityTitle")
      tabIndex: 1
      checked: tabBar.currentIndex === 1
    }

    NTabButton {
      text: pluginApi?.tr("settings.defaults.title")
      tabIndex: 2
      checked: tabBar.currentIndex === 2
    }
  }

  NTabView {
    id: tabView
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 640 * Style.uiScaleRatio
    Layout.minimumHeight: 640 * Style.uiScaleRatio
    currentIndex: tabBar.currentIndex

    NScrollView {
      id: interfaceScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      showScrollbarWhenScrollable: true
      gradientColor: "transparent"

      ColumnLayout {
        width: interfaceScroll.availableWidth
        Layout.fillWidth: true
        spacing: Style.marginL

        ColumnLayout {
          id: interfaceSection
          Layout.fillWidth: true
          spacing: Style.marginM

          NColorChoice {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.iconColor.label")
            description: pluginApi?.tr("settings.iconColor.description")
            currentKey: root.editIconColor
            onSelected: key => root.editIconColor = key
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.enableExtraPropertiesEditor.label")
            description: pluginApi?.tr("settings.enableExtraPropertiesEditor.description")
            checked: root.editEnableExtraPropertiesEditor
            onToggled: checked => root.editEnableExtraPropertiesEditor = checked
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.showSidebarDescription.label")
            description: pluginApi?.tr("settings.showSidebarDescription.description")
            checked: root.editShowSidebarDescription
            onToggled: checked => root.editShowSidebarDescription = checked
          }

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.badges.title")
            color: Color.mOnSurface
            font.weight: Font.Bold
          }

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.badges.description")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }

          Item {
            id: badgeEditorContainer
            Layout.fillWidth: true
            implicitHeight: badgeEditorColumn.implicitHeight

            property int draggedIndex: -1
            property int dropTargetIndex: -1
            property bool dragStarted: false
            property bool potentialDrag: false
            property point startPos: Qt.point(0, 0)
            readonly property real dragThreshold: 8

            function cardRect(i) {
              const card = badgeCardRepeater.itemAt(i);
              if (!card) return Qt.rect(0, 0, 0, 0);
              const mapped = card.mapToItem(badgeEditorContainer, 0, 0);
              return Qt.rect(mapped.x, mapped.y, card.width, card.height);
            }

            function computeDropIndex(mouseY) {
              let best = draggedIndex;
              let bestDist = Infinity;
              const count = root.editBadgeOrder.length;

              for (let i = 0; i < count; ++i) {
                if (i === draggedIndex) continue;
                const rect = cardRect(i);
                if (rect.height <= 0) continue;
                const centerY = rect.y + rect.height / 2;
                const dist = Math.abs(mouseY - centerY);
                if (dist < bestDist) {
                  bestDist = dist;
                  best = mouseY < centerY ? i : i + 1;
                }
              }

              if (best > draggedIndex) best = best - 1;
              return Math.max(0, Math.min(count - 1, best));
            }

            function updateDropIndicator() {
              const count = root.editBadgeOrder.length;
              if (!dragStarted || dropTargetIndex < 0 || count <= 0) return;
              const refIndex = Math.min(dropTargetIndex, count - 1);
              const refCard = badgeCardRepeater.itemAt(refIndex);
              if (!refCard) return;
              const mapped = refCard.mapToItem(badgeEditorContainer, 0, 0);
              dropIndicator.width = Math.max(0, refCard.width - Style.marginL * 2);
              dropIndicator.x = mapped.x + Style.marginL;
              dropIndicator.y = dropTargetIndex <= draggedIndex
                ? mapped.y - Style.marginXS
                : mapped.y + refCard.height - dropIndicator.height + Style.marginXS;
            }

            function resetDrag() {
              draggedIndex = -1;
              dropTargetIndex = -1;
              dragStarted = false;
              potentialDrag = false;
              dragGhost.visible = false;
            }

            Rectangle {
              id: dropIndicator
              width: 0
              height: 3
              radius: Style.radiusXS
              color: Color.mPrimary
              visible: badgeEditorContainer.dragStarted && badgeEditorContainer.dropTargetIndex !== -1
              z: 10
            }

            Rectangle {
              id: dragGhost
              width: Math.min(badgeEditorContainer.width, ghostRow.implicitWidth + Style.marginL * 2)
              height: ghostRow.implicitHeight + Style.marginM * 2
              radius: Style.radiusM
              color: Color.mPrimary
              border.width: Style.borderS
              border.color: Qt.alpha(Color.mOnPrimary, 0.18)
              opacity: 0.9
              visible: false
              z: 20

              RowLayout {
                id: ghostRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                NIcon {
                  icon: "grip-vertical"
                  pointSize: Style.fontSizeS
                  color: Qt.alpha(Color.mOnPrimary, 0.75)
                }

                NIcon {
                  icon: root.badgeIcon(modelData)
                  pointSize: Style.fontSizeM
                  color: Color.mOnPrimary
                }

                NText {
                  id: ghostText
                  Layout.fillWidth: true
                  text: ""
                  color: Color.mOnPrimary
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }
              }
            }

            ColumnLayout {
              id: badgeEditorColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                id: badgeCardRepeater
                model: root.editBadgeOrder

                Rectangle {
                  required property int index
                  required property var modelData
                  Layout.fillWidth: true
                  width: badgeEditorColumn.width
                  height: badgeCardRow.implicitHeight + Style.marginS * 2
                  radius: Style.radiusM
                  color: Qt.alpha(Color.mSurfaceVariant, 0.6)
                  border.width: Style.borderS
                  border.color: badgeDragHandleMouseArea.containsMouse
                    ? Qt.alpha(Color.mPrimary, 0.55)
                    : Qt.alpha(Color.mOutline, 0.35)
                  opacity: badgeEditorContainer.draggedIndex === index && badgeEditorContainer.dragStarted ? 0.3 : 1.0

                  RowLayout {
                    id: badgeCardRow
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    spacing: Style.marginS

                    Item {
                      Layout.preferredWidth: 24 * Style.uiScaleRatio
                      Layout.preferredHeight: 34 * Style.uiScaleRatio

                      NIcon {
                        anchors.centerIn: parent
                        icon: "grip-vertical"
                        pointSize: Style.fontSizeS
                        color: badgeDragHandleMouseArea.containsMouse || badgeEditorContainer.draggedIndex === index
                          ? Color.mPrimary
                          : Color.mOnSurfaceVariant
                      }

                      MouseArea {
                        id: badgeDragHandleMouseArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: badgeEditorContainer.dragStarted && badgeEditorContainer.draggedIndex === index
                          ? Qt.ClosedHandCursor
                          : Qt.OpenHandCursor
                        hoverEnabled: true
                        preventStealing: true

                        onPressed: mouse => {
                          const mapped = badgeDragHandleMouseArea.mapToItem(badgeEditorContainer, mouse.x, mouse.y);
                          badgeEditorContainer.startPos = Qt.point(mapped.x, mapped.y);
                          badgeEditorContainer.draggedIndex = index;
                          badgeEditorContainer.dropTargetIndex = index;
                          badgeEditorContainer.dragStarted = false;
                          badgeEditorContainer.potentialDrag = true;
                          mouse.accepted = true;
                        }

                        onPositionChanged: mouse => {
                          if (!badgeEditorContainer.potentialDrag || badgeEditorContainer.draggedIndex !== index) return;
                          const mapped = badgeDragHandleMouseArea.mapToItem(badgeEditorContainer, mouse.x, mouse.y);
                          const dx = mapped.x - badgeEditorContainer.startPos.x;
                          const dy = mapped.y - badgeEditorContainer.startPos.y;
                          const dist = Math.sqrt(dx * dx + dy * dy);
                          if (!badgeEditorContainer.dragStarted && dist > badgeEditorContainer.dragThreshold) {
                            badgeEditorContainer.dragStarted = true;
                            ghostText.text = root.badgeLabel(modelData);
                            dragGhost.visible = true;
                          }
                          if (badgeEditorContainer.dragStarted) {
                            dragGhost.x = mapped.x - dragGhost.width / 2;
                            dragGhost.y = mapped.y - dragGhost.height / 2;
                            badgeEditorContainer.dropTargetIndex = badgeEditorContainer.computeDropIndex(mapped.y);
                            badgeEditorContainer.updateDropIndicator();
                          }
                        }

                        onReleased: mouse => {
                          if (badgeEditorContainer.dragStarted) {
                            const from = badgeEditorContainer.draggedIndex;
                            const to = badgeEditorContainer.dropTargetIndex;
                            if (to !== -1 && to !== from) {
                              root.moveBadge(from, to);
                            }
                          }
                          badgeEditorContainer.resetDrag();
                          mouse.accepted = true;
                        }

                        onCanceled: badgeEditorContainer.resetDrag()
                      }
                    }

                    Rectangle {
                      Layout.preferredWidth: 34 * Style.uiScaleRatio
                      Layout.preferredHeight: 34 * Style.uiScaleRatio
                      radius: Style.radiusS
                      color: Qt.alpha(Color.mPrimary, 0.12)

                      NIcon {
                        anchors.centerIn: parent
                        icon: root.badgeIcon(modelData)
                        pointSize: Style.fontSizeM
                        color: Color.mPrimary
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      text: root.badgeLabel(modelData)
                      color: Color.mOnSurface
                      font.weight: Font.Medium
                      elide: Text.ElideRight
                    }

                    NIconButton {
                      icon: "chevron-up"
                      tooltipText: pluginApi?.tr("settings.badges.moveUp")
                      enabled: index > 0
                      onClicked: root.moveBadge(index, index - 1)
                    }

                    NIconButton {
                      icon: "chevron-down"
                      tooltipText: pluginApi?.tr("settings.badges.moveDown")
                      enabled: index < root.editBadgeOrder.length - 1
                      onClicked: root.moveBadge(index, index + 1)
                    }

                    NToggle {
                      Layout.alignment: Qt.AlignVCenter
                      checked: !!root.editBadgeEnabled[String(modelData || "")]
                      onToggled: checked => root.setBadgeEnabled(modelData, checked)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    NScrollView {
      id: resourcesScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      showScrollbarWhenScrollable: true
      gradientColor: "transparent"

      ColumnLayout {
        width: resourcesScroll.availableWidth
        Layout.fillWidth: true
        spacing: Style.marginL

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("settings.category.compatibilityTitle")
          color: Color.mOnSurface
          font.weight: Font.Bold
          font.pointSize: Style.fontSizeL
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("settings.resourcesIntro")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
        }

        ColumnLayout {
          id: resourcesSection
          Layout.fillWidth: true
          spacing: Style.marginM

          NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.wallpapersFolder.label")
            description: pluginApi?.tr("settings.wallpapersFolder.description")
            placeholderText: pluginApi?.tr("settings.wallpapersFolder.placeholder")
            text: root.editWallpapersFolder
            onTextChanged: root.editWallpapersFolder = text
          }

          NButton {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.wallpapersFolder.scan")
            icon: root.scanning ? "loader" : "search"
            enabled: !root.scanning
            onClicked: {
              root.scanning = true;
              scanProcess.running = true;
            }
          }

          NSpinBox {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.wallpaperScanCacheMinutes.label")
            description: pluginApi?.tr("settings.wallpaperScanCacheMinutes.description")
            from: 0
            to: 1440
            stepSize: 1
            value: root.editWallpaperScanCacheMinutes
            suffix: pluginApi?.tr("settings.units.minutes")
            onValueChanged: if (value !== root.editWallpaperScanCacheMinutes) root.editWallpaperScanCacheMinutes = value
          }

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.cache.currentSize", { size: root.cacheSizeLabel })
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
              Layout.fillWidth: true
              text: pluginApi?.tr("settings.cache.refresh")
              icon: root.refreshingCacheSize ? "loader" : "refresh"
              enabled: !root.refreshingCacheSize && !root.clearingCache
              onClicked: root.refreshCacheSize()
            }

            NButton {
              Layout.fillWidth: true
              text: pluginApi?.tr("settings.cache.clear")
              icon: root.clearingCache ? "loader" : "trash"
              enabled: !root.clearingCache && !root.refreshingCacheSize
              onClicked: {
                root.clearingCache = true;
                clearCacheProcess.command = root.clearCacheCommand();
                clearCacheProcess.running = true;
              }
            }
          }
        }
      }
    }

    NScrollView {
      id: defaultsScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      showScrollbarWhenScrollable: true
      gradientColor: "transparent"

      ColumnLayout {
        width: defaultsScroll.availableWidth
        Layout.fillWidth: true
        spacing: Style.marginL

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("settings.defaults.title")
          color: Color.mOnSurface
          font.weight: Font.Bold
          font.pointSize: Style.fontSizeL
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("settings.defaults.description")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
        }

        ColumnLayout {
          id: defaultsSection
          Layout.fillWidth: true
          spacing: Style.marginM

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.category.performanceTitle")
            color: Color.mOnSurface
            font.weight: Font.Bold
          }

          NSpinBox {
            id: defaultFpsSpinBox
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultFps.label")
            description: pluginApi?.tr("settings.defaultFps.description")
            from: 1
            to: 240
            stepSize: 1
            value: root.editDefaultFps
            suffix: pluginApi?.tr("settings.units.fps")
            onValueChanged: if (value !== root.editDefaultFps) root.editDefaultFps = value
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultNoFullscreenPause.label")
            description: pluginApi?.tr("settings.defaultNoFullscreenPause.description")
            checked: root.editDefaultNoFullscreenPause
            onToggled: checked => root.editDefaultNoFullscreenPause = checked
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultFullscreenPauseOnlyActive.label")
            description: pluginApi?.tr("settings.defaultFullscreenPauseOnlyActive.description")
            checked: root.editDefaultFullscreenPauseOnlyActive
            onToggled: checked => root.editDefaultFullscreenPauseOnlyActive = checked
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.autoApplyOnStartup.label")
            description: pluginApi?.tr("settings.autoApplyOnStartup.description")
            checked: root.editAutoApplyOnStartup
            onToggled: checked => root.editAutoApplyOnStartup = checked
          }

          NDivider {
            Layout.fillWidth: true
          }

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.category.audioTitle")
            color: Color.mOnSurface
            font.weight: Font.Bold
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultMuted.label")
            description: pluginApi?.tr("settings.defaultMuted.description")
            checked: root.editDefaultMuted
            onToggled: checked => root.editDefaultMuted = checked
          }

          NSpinBox {
            id: defaultVolumeSpinBox
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultVolume.label")
            description: pluginApi?.tr("settings.defaultVolume.description")
            from: 0
            to: 100
            stepSize: 1
            suffix: pluginApi?.tr("settings.units.percent")
            value: root.editDefaultVolume
            enabled: !root.editDefaultMuted
            onValueChanged: if (value !== root.editDefaultVolume) root.editDefaultVolume = value
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultAudioReactiveEffects.label")
            description: pluginApi?.tr("settings.defaultAudioReactiveEffects.description")
            checked: root.editDefaultAudioReactiveEffects
            onToggled: checked => root.editDefaultAudioReactiveEffects = checked
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultNoAutomute.label")
            description: pluginApi?.tr("settings.defaultNoAutomute.description")
            checked: root.editDefaultNoAutomute
            onToggled: checked => root.editDefaultNoAutomute = checked
          }

          NDivider {
            Layout.fillWidth: true
          }

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("settings.category.displayTitle")
            color: Color.mOnSurface
            font.weight: Font.Bold
          }

          NComboBox {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultScaling.label")
            description: pluginApi?.tr("settings.defaultScaling.description")
            model: [
              { "key": "fill", "name": pluginApi?.tr("panel.scalingFill") },
              { "key": "fit", "name": pluginApi?.tr("panel.scalingFit") },
              { "key": "stretch", "name": pluginApi?.tr("panel.scalingStretch") },
              { "key": "default", "name": pluginApi?.tr("panel.scalingDefault") }
            ]
            currentKey: root.editDefaultScaling
            onSelected: key => root.editDefaultScaling = key
          }

          NComboBox {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultClamp.label")
            description: pluginApi?.tr("settings.defaultClamp.description")
            model: [
              { "key": "clamp", "name": pluginApi?.tr("panel.clampClamp") },
              { "key": "border", "name": pluginApi?.tr("panel.clampBorder") },
              { "key": "repeat", "name": pluginApi?.tr("panel.clampRepeat") }
            ]
            currentKey: root.editDefaultClamp
            onSelected: key => root.editDefaultClamp = key
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultDisableMouse.label")
            description: pluginApi?.tr("settings.defaultDisableMouse.description")
            checked: root.editDefaultDisableMouse
            onToggled: checked => root.editDefaultDisableMouse = checked
          }

          NToggle {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.defaultDisableParallax.label")
            description: pluginApi?.tr("settings.defaultDisableParallax.description")
            checked: root.editDefaultDisableParallax
            onToggled: checked => root.editDefaultDisableParallax = checked
          }
        }
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("LWEController", "Cannot save settings: pluginApi is null");
      return;
    }

    if (pluginApi.pluginSettings.screens === undefined || pluginApi.pluginSettings.screens === null) {
      pluginApi.pluginSettings.screens = {};
    }

    pluginApi.pluginSettings.wallpapersFolder = root.editWallpapersFolder;
    pluginApi.pluginSettings.iconColor = root.editIconColor;
    pluginApi.pluginSettings.enableExtraPropertiesEditor = root.editEnableExtraPropertiesEditor;
    pluginApi.pluginSettings.defaultScaling = root.editDefaultScaling;
    pluginApi.pluginSettings.defaultClamp = root.editDefaultClamp;
    pluginApi.pluginSettings.defaultFps = defaultFpsSpinBox.value;
    pluginApi.pluginSettings.defaultVolume = defaultVolumeSpinBox.value;
    pluginApi.pluginSettings.defaultMuted = root.editDefaultMuted;
    pluginApi.pluginSettings.defaultAudioReactiveEffects = root.editDefaultAudioReactiveEffects;
    pluginApi.pluginSettings.defaultNoAutomute = root.editDefaultNoAutomute;
    pluginApi.pluginSettings.defaultDisableMouse = root.editDefaultDisableMouse;
    pluginApi.pluginSettings.defaultDisableParallax = root.editDefaultDisableParallax;
    pluginApi.pluginSettings.defaultNoFullscreenPause = root.editDefaultNoFullscreenPause;
    pluginApi.pluginSettings.defaultFullscreenPauseOnlyActive = root.editDefaultFullscreenPauseOnlyActive;
    pluginApi.pluginSettings.autoApplyOnStartup = root.editAutoApplyOnStartup;
    pluginApi.pluginSettings.showSidebarDescription = root.editShowSidebarDescription;
    pluginApi.pluginSettings.wallpaperScanCacheMinutes = root.editWallpaperScanCacheMinutes;
    pluginApi.pluginSettings.badgeOrder = BadgeHelpers.normalizeBadgeOrder(root.editBadgeOrder, root.defaultBadgeOrder);
    pluginApi.pluginSettings.badgeEnabled = BadgeHelpers.normalizeBadgeEnabled(root.editBadgeEnabled, root.defaultBadgeEnabled);

    pluginApi.saveSettings();

    if (pluginApi.mainInstance) {
      pluginApi.mainInstance.refreshWallpaperCache(true, false);
      if (pluginApi.mainInstance.hasAnyConfiguredWallpaper()) {
        pluginApi.mainInstance.reload();
      }
    }
  }

  Process {
    id: scanProcess
    running: false

    command: {
      const pluginDir = root.pluginApi?.pluginDir || "";
      const scriptPath = pluginDir + "/scripts/detect-steam-workshop.sh";
      return ["bash", scriptPath];
    }

    onExited: function () {
      root.scanning = false;
      const detected = String(stdout.text || "").trim();
      if (detected.length > 0 && root.editWallpapersFolder.length === 0) {
        root.editWallpapersFolder = detected;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: cacheSizeProcess
    running: false

    command: {
      const pluginDir = root.pluginApi?.pluginDir || "";
      const scriptPath = pluginDir + "/scripts/get-cache-size-bytes.sh";
      return ["bash", scriptPath, root.pluginCacheDir];
    }

    onExited: function (exitCode) {
      root.refreshingCacheSize = false;

      if (exitCode !== 0) {
        const errorOutput = String(stderr.text || "").trim();
        if (errorOutput.length > 0) {
          Logger.w("LWEController", "Failed to get cache size", errorOutput);
        }
        root.cacheSizeLabel = pluginApi?.tr("settings.cache.sizeUnknown");
        return;
      }

      const output = String(stdout.text || "").trim();
      const bytes = Number(output);
      if (output.length === 0 || isNaN(bytes) || bytes < 0) {
        root.cacheSizeLabel = pluginApi?.tr("settings.cache.sizeUnknown");
        return;
      }

      root.cacheSizeLabel = root.formatBytes(bytes);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: clearCacheProcess
    running: false
    command: root.clearCacheCommand()

    onExited: function () {
      root.clearingCache = false;
      if (pluginApi) {
        pluginApi.pluginSettings.wallpaperColorScreenshots = root.preservedWallpaperColorScreenshots();
        pluginApi.saveSettings();
      }
      root.refreshCacheSize();
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
}
