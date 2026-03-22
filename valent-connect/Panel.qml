import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import Quickshell

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth:  440 * Style.uiScaleRatio
  property real contentPreferredHeight: 360 * Style.uiScaleRatio * Settings.data.ui.fontDefaultScale

  readonly property bool allowAttach: true

  property bool deviceSwitcherOpen: false

  readonly property var main: pluginApi?.mainInstance ?? ({})

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: deviceData

      function getBatteryIcon(percentage, isCharging) {
        if (isCharging)      return "battery-charging"
        if (percentage <  5) return "battery"
        if (percentage < 25) return "battery-1"
        if (percentage < 50) return "battery-2"
        if (percentage < 75) return "battery-3"
        return "battery-4"
      }

      function getCellularTypeIcon(type) {
        switch (type) {
          case "5G":       return "signal-5g"
          case "LTE":      return "signal-4g"
          case "HSPA":     return "signal-h"
          case "UMTS":     return "signal-3g"
          case "EDGE":     return "signal-e"
          case "GPRS":     return "signal-g"
          case "GSM":      return "signal-2g"
          case "CDMA":
          case "CDMA2000": return "signal-3g"
          case "iDEN":     return "signal-2g"
          default:         return "wave-square"
        }
      }

      function getCellularStrengthIcon(strength) {
        switch (strength) {
          case 0:  return "antenna-bars-1"
          case 1:  return "antenna-bars-2"
          case 2:  return "antenna-bars-3"
          case 3:  return "antenna-bars-4"
          case 4:  return "antenna-bars-5"
          default: return "antenna-bars-off"
        }
      }

      function getSignalStrengthText(strength) {
        switch (strength) {
          case 0:  return pluginApi?.tr("panel.signal.very-weak")
          case 1:  return pluginApi?.tr("panel.signal.weak")
          case 2:  return pluginApi?.tr("panel.signal.fair")
          case 3:  return pluginApi?.tr("panel.signal.good")
          case 4:  return pluginApi?.tr("panel.signal.excellent")
          default: return pluginApi?.tr("panel.signal.unknown")
        }
      }

      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginL

      // ── Header ───────────────────────────────────────────────────────────────
      NBox {
        id: headerBox
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.marginXL

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "device-mobile"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          NText {
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          Item {
            Layout.preferredWidth:  Style.baseWidgetSize * 0.8
            Layout.preferredHeight: Style.baseWidgetSize * 0.8

            NIconButton {
              anchors.fill: parent
              visible: !main.isRefreshing
              icon: "refresh"
              tooltipText: pluginApi?.tr("panel.refresh")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: main.refreshDevices()
              enabled: main.daemonAvailable ?? false
            }

            NIcon {
              anchors.centerIn: parent
              visible: main.isRefreshing
              icon: "refresh"
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant

              NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: main && main.isRefreshing
              }
            }
          }

          NIconButton {
            readonly property bool multipleDevices: (main.devices?.length ?? 0) > 1
            icon: "swipe"
            tooltipText: multipleDevices ? pluginApi?.tr("panel.other-devices") : ""
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: deviceSwitcherOpen = !deviceSwitcherOpen
            enabled: (main.daemonAvailable ?? false) && multipleDevices
            opacity: multipleDevices ? 1.0 : 0.0
          }

          Item { Layout.fillWidth: true }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi)
                pluginApi.withCurrentScreen(s => pluginApi.closePanel(s))
            }
          }
        }
      }

      // ── Content loader ───────────────────────────────────────────────────────
      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: true
        sourceComponent: {
          var m = main
          if (!m.daemonAvailable)                                       return daemonNotRunningCard
          if (deviceSwitcherOpen)                                        return deviceSwitcherCard
          if (m.mainDevice !== null && m.mainDevice !== undefined) {
            if (!m.mainDevice.isReachable)                               return deviceNotReachableCard
            if ( m.mainDevice.isPaired)                                  return deviceConnectedCard
            if (!m.mainDevice.isPaired)                                  return noDevicePairedCard
          }
          if (!m.devices || m.devices.length === 0)                      return noDevicesAvailableCard
          return null
        }
      }

      // ── CARD: connected ──────────────────────────────────────────────────────
      Component {
        id: deviceConnectedCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          Component.onCompleted: {
            root.contentPreferredHeight = headerBox.height + contentLayout.implicitHeight + Style.marginL * 8
          }
          Component.onDestruction: {
            root.contentPreferredHeight = 360 * Style.uiScaleRatio * Settings.data.ui.fontDefaultScale
          }

          ColumnLayout {
            id: contentLayout
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL

            RowLayout {
              NText {
                text: main.mainDevice?.name ?? ""
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
              }

              NFilePicker {
                id: shareFilePicker
                title: pluginApi?.tr("panel.send-file-picker")
                selectionMode: "files"
                initialPath: Quickshell.env("HOME")
                nameFilters: ["*"]
                onAccepted: paths => {
                  if (paths.length > 0) {
                    for (const path of paths) {
                      main.shareFile(main.mainDevice.id, path)
                    }
                  }
                }
              }

              NIconButton {
                icon: "device-mobile-search"
                tooltipText: pluginApi?.tr("panel.browse-device")
                onClicked: main.browseFiles(main.mainDevice.id)
              }

              NIconButton {
                icon: "device-mobile-share"
                tooltipText: pluginApi?.tr("panel.send-file")
                onClicked: shareFilePicker.open()
              }

              NIconButton {
                icon: "radar"
                tooltipText: pluginApi?.tr("panel.find-device")
                onClicked: main.triggerFindMyPhone(main.mainDevice.id)
              }
            }

            Loader {
              Layout.fillWidth: true
              Layout.fillHeight: true
              active: main.mainDevice !== null && main.mainDevice !== undefined
              sourceComponent: deviceStatsComponent
            }
          }

          Component {
            id: deviceStatsComponent

            RowLayout {
              spacing: Style.marginM

              Rectangle {
                width: 100 * Style.uiScaleRatio
                color: "transparent"
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter

                PhoneDisplay {
                  Layout.alignment: Qt.AlignCenter
                  backgroundImage: ""
                }
              }

              Item { width: Style.marginL }

              GridLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                columns: 1
                rowSpacing: Style.marginL

                // Battery
                RowLayout {
                  spacing: Style.marginM
                  NIcon {
                    icon: deviceData.getBatteryIcon(main.mainDevice?.batteryCharge ?? -1, main.mainDevice?.batteryCharging ?? false)
                    pointSize: Style.fontSizeXXXL; applyUiScale: true; color: Color.mOnSurface
                  }
                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio
                    NText { text: pluginApi?.tr("panel.card.battery"); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText {
                      text: (main.mainDevice?.batteryCharge ?? -1) !== -1 ? (main.mainDevice.batteryCharge + "%") : pluginApi?.tr("panel.signal.unknown")
                      pointSize: Style.fontSizeL; font.weight: Style.fontWeightMedium; color: Color.mOnSurface
                    }
                  }
                }

                // Network type
                RowLayout {
                  spacing: Style.marginM
                  NIcon {
                    icon: deviceData.getCellularTypeIcon(main.mainDevice?.networkType ?? "")
                    pointSize: Style.fontSizeXXXL; applyUiScale: true; color: Color.mOnSurface
                  }
                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio
                    NText { text: pluginApi?.tr("panel.card.network"); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText {
                      text: main.mainDevice?.networkType || pluginApi?.tr("panel.signal.unknown")
                      pointSize: Style.fontSizeL; font.weight: Style.fontWeightMedium; color: Color.mOnSurface
                    }
                  }
                }

                // Signal strength
                RowLayout {
                  spacing: Style.marginM
                  NIcon {
                    icon: deviceData.getCellularStrengthIcon(main.mainDevice?.networkStrength ?? -1)
                    pointSize: Style.fontSizeXXXL; applyUiScale: true; color: Color.mOnSurface
                  }
                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio
                    NText { text: pluginApi?.tr("panel.card.signal-strength"); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText {
                      text: deviceData.getSignalStrengthText(main.mainDevice?.networkStrength ?? -1)
                      pointSize: Style.fontSizeL; font.weight: Style.fontWeightMedium; color: Color.mOnSurface
                    }
                  }
                }

                // Notifications
                RowLayout {
                  spacing: Style.marginM
                  NIcon {
                    icon: "notification"
                    pointSize: Style.fontSizeXXXL; applyUiScale: true; color: Color.mOnSurface
                  }
                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio
                    NText { text: pluginApi?.tr("panel.card.notifications"); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText {
                      text: main.mainDevice?.notificationIds?.length ?? 0
                      pointSize: Style.fontSizeL; font.weight: Style.fontWeightMedium; color: Color.mOnSurface
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ── CARD: not paired ─────────────────────────────────────────────────────
      Component {
        id: noDevicePairedCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL

            NText {
              text: main.mainDevice?.name ?? ""
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              color: "transparent"

              ColumnLayout {
                anchors { fill: parent; margins: Style.marginM }
                spacing: Style.marginM

                NButton {
                  text: pluginApi?.tr("panel.pair")
                  Layout.alignment: Qt.AlignHCenter
                  enabled: !(main.mainDevice?.isPairRequested ?? false)
                  onClicked: {
                    main.requestPairing(main.mainDevice.id)
                    main.refreshDevices()
                  }
                }

                RowLayout {
                  Layout.alignment: Qt.AlignHCenter
                  spacing: Style.marginM

                  NIcon {
                    icon: "key"
                    pointSize: Style.fontSizeXL
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
                    opacity: (main.mainDevice?.isPairRequested ?? false) ? 1.0 : 0.0
                  }

                  NText {
                    text: main.mainDevice?.verificationKey ?? ""
                    Layout.alignment: Qt.AlignHCenter
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    opacity: (main.mainDevice?.isPairRequested ?? false) ? 1.0 : 0.0
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  opacity: (main.mainDevice?.isPairRequested ?? false) ? 1.0 : 0.0
                  size: Style.baseWidgetSize * 0.5
                  running: main.mainDevice?.isPairRequested ?? false
                }
              }
            }
          }
        }
      }

      // ── CARD: no devices ─────────────────────────────────────────────────────
      Component {
        id: noDevicesAvailableCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors { fill: parent; margins: Style.marginM }
            spacing: Style.marginM

            Item { Layout.fillHeight: true }
            NIcon {
              icon: "device-mobile-off"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.valent-error.no-devices")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true }
          }
        }
      }

      // ── CARD: device not reachable ───────────────────────────────────────────
      Component {
        id: deviceNotReachableCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors { fill: parent; margins: Style.marginM }
            spacing: Style.marginM

            Item { Layout.fillHeight: true }
            NIcon {
              icon: "device-mobile-off"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.valent-error.device-unavailable")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
            NButton {
              text: pluginApi?.tr("panel.unpair")
              Layout.alignment: Qt.AlignHCenter
              onClicked: main.unpairDevice(main.mainDevice.id)
            }
            Item { Layout.fillHeight: true }
          }
        }
      }

      // ── CARD: daemon not running ─────────────────────────────────────────────
      Component {
        id: daemonNotRunningCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors { fill: parent; margins: Style.marginM }
            spacing: Style.marginM

            Item { Layout.fillHeight: true }
            NIcon {
              icon: "exclamation-circle"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.valent-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.valent-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
          }
        }
      }

      // ── CARD: device switcher ────────────────────────────────────────────────
      Component {
        id: deviceSwitcherCard

        Rectangle {
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          NScrollView {
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            contentWidth: parent.width
            reserveScrollbarSpace: false
            gradientColor: Color.mSurface

            ColumnLayout {
              anchors { fill: parent; margins: Style.marginM }
              spacing: Style.marginM

              Repeater {
                model: main.devices ?? []
                Layout.fillWidth: true

                NButton {
                  required property var modelData
                  text: modelData.name
                  Layout.fillWidth: true
                  backgroundColor: modelData.id === (main.mainDevice?.id ?? "")
                    ? Color.mSecondary
                    : Color.mPrimary
                  onClicked: {
                    main.setMainDevice(modelData.id)
                    deviceSwitcherOpen = false
                    if (pluginApi) {
                      pluginApi.pluginSettings.mainDeviceId = modelData.id
                      pluginApi.saveSettings()
                    }
                  }
                }
              }

              Item { Layout.fillHeight: true }
            }
          }
        }
      }

    }
  }
}
