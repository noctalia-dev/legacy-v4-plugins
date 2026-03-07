import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen currentScreen
  readonly property var geometryPlaceholder: root
  readonly property bool allowAttach: true

  anchors.fill: parent

  // ===== SETTINGS =====

  property var cfg: pluginApi?.pluginSettings || {}
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || {}

  // Persisted monitor order (array of monitor name strings)
  property var savedMonitorOrder: cfg.monitorOrder ?? defaults.monitorOrder ?? []

  // Ordered monitor list: respects savedMonitorOrder, appends any new/unknown monitors at end
  property var orderedMonitors: {
    var all = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.availableMonitors)
      ? pluginApi.mainInstance.availableMonitors
      : []
    var order = root.savedMonitorOrder

    if (!order || order.length === 0) return all

    var result = []
    // Add monitors in saved order (only if they still exist)
    for (var i = 0; i < order.length; i++) {
      if (all.indexOf(order[i]) !== -1) result.push(order[i])
    }
    // Append any monitors not yet in saved order (e.g. newly connected)
    for (var j = 0; j < all.length; j++) {
      if (order.indexOf(all[j]) === -1) result.push(all[j])
    }
    return result
  }

  function applyMonitorReorder(fromIndex, toIndex) {
    if (fromIndex === toIndex) return
    var newOrder = root.orderedMonitors.slice()
    var item = newOrder.splice(fromIndex, 1)[0]
    newOrder.splice(toIndex, 0, item)

    // Persist
    if (pluginApi) {
      pluginApi.pluginSettings.monitorOrder = newOrder
      pluginApi.saveSettings()
    }
    // Trigger re-render
    root.savedMonitorOrder = newOrder
  }

  // ===== DATA & MAPPING =====

  readonly property string panelMonitor: {
    if (currentScreen && currentScreen.name) return currentScreen.name
    if (pluginApi && pluginApi.currentScreen && pluginApi.currentScreen.name) return pluginApi.currentScreen.name
    if (root.orderedMonitors.length > 0) return root.orderedMonitors[0]
    return ""
  }

  readonly property var layouts: (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.availableLayouts) ? pluginApi.mainInstance.availableLayouts : []

  readonly property string activeLayout: {
    var layoutsDict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts) ? pluginApi.mainInstance.monitorLayouts : {}
    return layoutsDict[root.selectedMonitors[0] || root.panelMonitor] || ""
  }

  // Matches BarWidget mapping and grouping
  readonly property var iconMap: ({
    "T":  "layout-sidebar",
    "M":  "rectangle",
    "S":  "carousel-horizontal",
    "G":  "layout-grid",
    "K":  "versions",
    "RT": "layout-sidebar-right",
    "CT": "layout-distribute-vertical",
    "TG": "layout-dashboard",
    "VT": "layout-rows",
    "VS": "carousel-vertical",
    "VG": "grid-dots",
    "VK": "chart-funnel"
  })

  property bool applyToAll: false
  property var selectedMonitors: []
  property real contentPreferredWidth: 360 * Style.uiScaleRatio
  property real contentPreferredHeight: panelContent.implicitHeight + Style.margin2L

  function toggleMonitor(monitorName) {
    if (root.selectedMonitors.includes(monitorName)) {
      root.selectedMonitors = root.selectedMonitors.filter(m => m !== monitorName)
    } else {
      root.selectedMonitors = root.selectedMonitors.concat([monitorName])
    }
  }

  Component.onCompleted: {
    if (pluginApi && pluginApi.mainInstance) {
      pluginApi.mainInstance.refresh()
    }
  }

  // ===== UI =====

  // Background Click Catcher (Closes Panel)
  MouseArea {
    anchors.fill: parent
    onClicked: {
      if (pluginApi) {
        pluginApi.closePanel()
      }
    }
  }

  // Panel Window Surface
  Rectangle {
    anchors.centerIn: parent
    width: root.contentPreferredWidth
    height: root.contentPreferredHeight

    color: Color.mSurface
    radius: Style.radiusL
    border.width: 1
    border.color: Color.mOutline

    // Inner Click Catcher (Prevents closing when clicking the panel itself)
    MouseArea {
      anchors.fill: parent
      onClicked: mouse => mouse.accepted = true
    }

    ColumnLayout {
      id: panelContent
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "layout-grid"
            pointSize: Style.fontSizeXL
            color: Color.mPrimary
          }

          NText {
            text: "Switch Layout"
            pointSize: Style.fontSizeXL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }
        }
      }

      // Options
      RowLayout {
        Layout.fillWidth: true

        NText {
          text: "Apply to all monitors"
          pointSize: Style.fontSizeL
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
        }

        NToggle {
          checked: root.applyToAll
          onToggled: checked => {
            root.applyToAll = checked
            if (!checked && root.selectedMonitors.length === 0) {
              root.selectedMonitors = [root.panelMonitor]
            }
          }
        }
      }

      // Monitor Selector (with drag-to-reorder)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        opacity: root.applyToAll ? 0.6 : 1.0
        enabled: !root.applyToAll

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            text: "Select monitors"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
          }

          // Subtle hint that items are draggable
          NIcon {
            icon: "grip-vertical"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            opacity: 0.5
          }
        }

        // Drag-to-reorder monitor chip list
        Item {
          id: monitorDragContainer
          Layout.fillWidth: true
          implicitHeight: monitorFlow.implicitHeight

          // ── Drag state ──
          property int draggedIndex: -1
          property int dropTargetIndex: -1
          property bool dragStarted: false
          property bool potentialDrag: false
          property point startPos: Qt.point(0, 0)
          readonly property real dragThreshold: 8

          // Helper: map a chip's local coords into monitorFlow coords
          function chipRect(i) {
            var chip = monitorRepeater.itemAt(i)
            if (!chip) return Qt.rect(0, 0, 0, 0)
            var mapped = chip.mapToItem(monitorFlow, 0, 0)
            return Qt.rect(mapped.x, mapped.y, chip.width, chip.height)
          }

          function computeDropIndex(mouseX, mouseY) {
            // mouseX/Y are in monitorFlow coordinates
            var best = -1
            var bestDist = Infinity
            var count = root.orderedMonitors.length

            for (var i = 0; i < count; i++) {
              if (i === monitorDragContainer.draggedIndex) continue
              var r = chipRect(i)
              if (r.width === 0) continue
              var cx = r.x + r.width / 2
              var cy = r.y + r.height / 2
              var dist = Math.sqrt(Math.pow(mouseX - cx, 2) + Math.pow(mouseY - cy, 2))
              if (dist < bestDist) {
                bestDist = dist
                // Insert before or after depending on which half was hit
                best = (mouseX < cx) ? i : i + 1
              }
            }

            // Clamp and adjust for the dragged item
            if (best === -1) return monitorDragContainer.draggedIndex
            if (best > monitorDragContainer.draggedIndex) best = best - 1
            return Math.max(0, Math.min(count - 1, best))
          }

          function resetDrag() {
            draggedIndex = -1
            dropTargetIndex = -1
            dragStarted = false
            potentialDrag = false
            dragGhost.visible = false
          }

          // Drop indicator: thin vertical bar shown between chips
          Rectangle {
            id: dropIndicator
            width: 2
            height: 36 * Style.uiScaleRatio
            radius: 1
            color: Color.mPrimary
            visible: monitorDragContainer.dragStarted && monitorDragContainer.dropTargetIndex !== -1
            z: 10

            SequentialAnimation on opacity {
              running: dropIndicator.visible
              loops: Animation.Infinite
              NumberAnimation { to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
              NumberAnimation { to: 0.5; duration: 350; easing.type: Easing.InOutQuad }
            }

            Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
          }

          // Floating ghost chip that follows the cursor
          Rectangle {
            id: dragGhost
            width: ghostText.implicitWidth + Style.margin2M
            height: 36 * Style.uiScaleRatio
            radius: Style.radiusM
            color: Color.mPrimary
            opacity: 0.85
            visible: false
            z: 20
            // x/y set dynamically by MouseArea

            NText {
              id: ghostText
              anchors.centerIn: parent
              pointSize: Style.fontSizeS
              font.weight: Font.Medium
              color: Color.mOnPrimary
            }
          }

          Flow {
            id: monitorFlow
            width: parent.width
            spacing: Style.marginS

            Repeater {
              id: monitorRepeater
              model: root.orderedMonitors

              delegate: Rectangle {
                id: monitorChip
                required property int index
                required property string modelData

                width: chipRow.implicitWidth + (Style.marginM * 2)
                height: 36 * Style.uiScaleRatio

                property bool isSelected: root.applyToAll || root.selectedMonitors.includes(modelData)
                property bool isDragging: monitorDragContainer.draggedIndex === index && monitorDragContainer.dragStarted

                property string currentLayout: {
                  var dict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts)
                    ? pluginApi.mainInstance.monitorLayouts : {}
                  return dict[modelData] || ""
                }

                color: isSelected ? Color.mPrimary : Color.mSurfaceVariant
                radius: Style.radiusM
                border.width: 2
                border.color: isSelected ? Color.mPrimary : Color.mOutline

                opacity: isDragging ? 0.35 : 1.0
                scale: isDragging ? 0.95 : 1.0

                Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
                Behavior on scale  { NumberAnimation { duration: Style.animationFast } }

                RowLayout {
                  id: chipRow
                  anchors.centerIn: parent
                  spacing: Style.marginS

                  // Drag handle
                  NIcon {
                    icon: "grip-vertical"
                    pointSize: Style.fontSizeS
                    color: isSelected ? Qt.alpha(Color.mOnPrimary, 0.6) : Color.mOnSurfaceVariant
                    opacity: 0.7
                  }

                  NIcon {
                    visible: isSelected
                    icon: "check"
                    pointSize: Style.fontSizeM
                    color: Color.mOnPrimary
                  }

                  NText {
                    text: modelData
                    color: isSelected ? Color.mOnPrimary : Color.mOnSurface
                    font.weight: Font.Medium
                    pointSize: Style.fontSizeS
                  }
                }
              }
            }
          }

          // Single MouseArea over the whole chip area to handle both select & drag
          MouseArea {
            id: chipDragArea
            anchors.fill: monitorFlow
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            hoverEnabled: monitorDragContainer.potentialDrag || monitorDragContainer.dragStarted
            cursorShape: monitorDragContainer.dragStarted ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            onPressed: mouse => {
              monitorDragContainer.startPos = Qt.point(mouse.x, mouse.y)
              monitorDragContainer.dragStarted = false
              monitorDragContainer.potentialDrag = false
              monitorDragContainer.draggedIndex = -1
              monitorDragContainer.dropTargetIndex = -1

              // Find which chip was pressed
              for (var i = 0; i < root.orderedMonitors.length; i++) {
                var chip = monitorRepeater.itemAt(i)
                if (!chip) continue
                var mapped = chip.mapToItem(monitorFlow, 0, 0)
                var r = Qt.rect(mapped.x, mapped.y, chip.width, chip.height)
                if (mouse.x >= r.x && mouse.x <= r.x + r.width &&
                    mouse.y >= r.y && mouse.y <= r.y + r.height) {
                  monitorDragContainer.draggedIndex = i
                  monitorDragContainer.potentialDrag = true
                  mouse.accepted = true
                  return
                }
              }
              mouse.accepted = false
            }

            onPositionChanged: mouse => {
              if (!monitorDragContainer.potentialDrag) return

              var dx = mouse.x - monitorDragContainer.startPos.x
              var dy = mouse.y - monitorDragContainer.startPos.y
              var dist = Math.sqrt(dx * dx + dy * dy)

              if (!monitorDragContainer.dragStarted && dist > monitorDragContainer.dragThreshold) {
                monitorDragContainer.dragStarted = true
                var chip = monitorRepeater.itemAt(monitorDragContainer.draggedIndex)
                ghostText.text = chip ? chip.modelData : ""
                dragGhost.visible = true
              }

              if (monitorDragContainer.dragStarted) {
                // Move ghost (offset so it floats above finger/cursor)
                dragGhost.x = mouse.x - dragGhost.width / 2
                dragGhost.y = mouse.y - dragGhost.height / 2 - 4

                // Compute where we'd drop
                var newDrop = monitorDragContainer.computeDropIndex(mouse.x, mouse.y)
                monitorDragContainer.dropTargetIndex = newDrop

                // Position drop indicator
                var count = root.orderedMonitors.length
                if (newDrop >= 0) {
                  // Place indicator before the chip at newDrop, or at end
                  var refIdx = (newDrop < count) ? newDrop : count - 1
                  var refChip = monitorRepeater.itemAt(refIdx)
                  if (refChip) {
                    var refMapped = refChip.mapToItem(monitorFlow, 0, 0)
                    if (newDrop < count) {
                      dropIndicator.x = refMapped.x - dropIndicator.width - Style.marginXXS
                    } else {
                      dropIndicator.x = refMapped.x + refChip.width + Style.marginXXS
                    }
                    dropIndicator.y = refMapped.y + (refChip.height - dropIndicator.height) / 2
                  }
                }
              }
            }

            onReleased: mouse => {
              if (monitorDragContainer.dragStarted) {
                var from = monitorDragContainer.draggedIndex
                var to = monitorDragContainer.dropTargetIndex
                if (to !== -1 && to !== from) {
                  root.applyMonitorReorder(from, to)
                }
              } else if (monitorDragContainer.potentialDrag && !monitorDragContainer.dragStarted) {
                // It was a tap, not a drag — treat as toggle selection
                var chip = monitorRepeater.itemAt(monitorDragContainer.draggedIndex)
                if (chip) root.toggleMonitor(chip.modelData)
              }
              monitorDragContainer.resetDrag()
            }

            onCanceled: {
              monitorDragContainer.resetDrag()
            }
          }
        }
      }

      NDivider { Layout.fillWidth: true }

      // Layout Grid
      Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        Repeater {
          model: root.layouts

          delegate: Rectangle {
            id: layoutBtn
            width: (root.contentPreferredWidth - Style.marginL * 2 - Style.marginS * 2) / 3
            height: 56 * Style.uiScaleRatio

            property bool isActive: {
              if (root.selectedMonitors.length === 0) {
                return modelData.code === root.activeLayout
              } else if (root.selectedMonitors.length === 1) {
                var mon = root.selectedMonitors[0]
                var dict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts) ? pluginApi.mainInstance.monitorLayouts : {}
                var monLayout = dict[mon] || ""
                return modelData.code === monLayout
              }
              return false
            }
            property bool isHovered: false

            color: isActive ? Color.mPrimary : Color.mSurfaceVariant
            radius: Style.radiusM

            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              color: isHovered && !isActive ? Color.mHover : "transparent"
              opacity: isHovered && !isActive ? 0.2 : 0
            }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: root.iconMap[modelData.code] || "layout-board"
                pointSize: Style.fontSizeL
                color: layoutBtn.isActive ? Color.mOnPrimary : Color.mOnSurface
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.name
                color: layoutBtn.isActive ? Color.mOnPrimary : Color.mOnSurface
                font.weight: Font.Medium
                pointSize: Style.fontSizeS
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onEntered: layoutBtn.isHovered = true
              onExited: layoutBtn.isHovered = false

              onClicked: {
                if (root.applyToAll) {
                  pluginApi.mainInstance.setLayoutGlobally(modelData.code)
                } else if (root.selectedMonitors.length > 0) {
                  root.selectedMonitors.forEach(m => {
                    pluginApi.mainInstance.setLayout(m, modelData.code)
                  })
                } else {
                  pluginApi.mainInstance.setLayout(root.panelMonitor, modelData.code)
                }
              }
            }
          }
        }
      }
    }
  }
}
