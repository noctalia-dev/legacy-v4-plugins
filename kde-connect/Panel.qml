import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "./Services"
import Quickshell

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 360 * Style.uiScaleRatio * Settings.data.ui.fontDefaultScale

  readonly property bool allowAttach: true

  property bool deviceSwitcherOpen: false

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("KDEConnect", "Panel initialized");
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: deviceData

      function getBatteryIcon(percentage, isCharging) {
        if (percentage < 0) return "battery-exclamation"
        if (isCharging) return "battery-charging-2"
        if (percentage < 5) return "battery"
        if (percentage < 25) return "battery-1"
        if (percentage < 50) return "battery-2"
        if (percentage < 75) return "battery-3"
        return "battery-4"
      }

      function getCellularTypeIcon(type) {
        switch (type) {
          case "5G":
            return "signal-5g"
          case "LTE":
            return "signal-4g"
          case "HSPA":
            return "signal-h"
          case "UMTS":
            return "signal-3g"
          case "EDGE":
            return "signal-e"
          case "GPRS":
            return "signal-g"
          case "GSM":
            return "signal-2g"
          case "CDMA":
            return "signal-3g"
          case "CDMA2000":
            return "signal-3g"
          case "iDEN":
            return "signal-2g"
          default:
            return "wave-square"
        }
      }

      function getCellularStrengthIcon(strength) {
        switch (strength) {
          case 0:
            return "antenna-bars-1"
          case 1:
            return "antenna-bars-2"
          case 2:
            return "antenna-bars-3"
          case 3:
            return "antenna-bars-4"
          case 4:
            return "antenna-bars-5"
          default:
            return "antenna-bars-off"
        }
      }

      function getSignalStrengthText(strength) {
        switch (strength) {
          case 0:
            return pluginApi?.tr("panel.signal.very-weak")
          case 1:
            return pluginApi?.tr("panel.signal.weak")
          case 2:
            return pluginApi?.tr("panel.signal.fair")
          case 3:
            return pluginApi?.tr("panel.signal.good")
          case 4:
            return pluginApi?.tr("panel.signal.excellent")
          default:
            return pluginApi?.tr("panel.unknown")
        }
      }

      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      NBox {
        id: headerBox
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (Style.marginXL)

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

          NIconButton {
            readonly property bool multipleDevices: KDEConnect.devices.length > 1
            icon: "swipe"
            tooltipText: multipleDevices ? pluginApi?.tr("panel.other-devices") : ""
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              deviceSwitcherOpen = !deviceSwitcherOpen
            }
            enabled: KDEConnect.daemonAvailable && multipleDevices
            opacity: multipleDevices ? 1.0 : 0.0
          }

          Item {
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi)
                pluginApi.withCurrentScreen(s => pluginApi.closePanel(s));
            }
          }
        }
      }

      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: true
        sourceComponent:  (KDEConnect.busctlCmd === null || KDEConnect.busctlCmd === "")       ? busctlNotFoundCard               :
                          (!KDEConnect.daemonAvailable)                                        ? kdeConnectDaemonNotRunningCard   :
                          (deviceSwitcherOpen)                                                 ? deviceSwitcherCard               :
                          (KDEConnect.mainDevice !== null && !KDEConnect.mainDevice.reachable) ? deviceNotReachableCard           :
                          (KDEConnect.mainDevice !== null &&  KDEConnect.mainDevice.paired)    ? deviceConnectedCard              :
                          (KDEConnect.mainDevice !== null && !KDEConnect.mainDevice.paired)    ? noDevicePairedCard               :
                          (KDEConnect.devices.length === 0)                                    ? noDevicesAvailableCard           :
                          null
      }

      Component {
        id: deviceConnectedCard

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          Component.onCompleted: {
            root.contentPreferredHeight = headerBox.height + contentLayout.implicitHeight + (Style.marginL * 8)
          }

          Component.onDestruction: {
            root.contentPreferredHeight = 360 * Style.uiScaleRatio * Settings.data.ui.fontDefaultScale
          }

          ColumnLayout {
            id: contentLayout
            anchors {
              fill: parent
              margins: Style.marginL
            }
            spacing: Style.marginL

            RowLayout {
              NText {
                text: KDEConnect.mainDevice.name
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
                      KDEConnect.shareFile(KDEConnect.mainDevice.id, path)
                    }
                  }
                }
              }

              NIconButton {
                icon: "device-mobile-search"
                tooltipText: pluginApi?.tr("panel.browse-device")
                onClicked: {
                  KDEConnect.browseFiles(KDEConnect.mainDevice.id)
                }
              }

              NIconButton {
                icon: "device-mobile-share"
                tooltipText: pluginApi?.tr("panel.send-file")
                onClicked: {
                  shareFilePicker.open()
                }
              }

              NIconButton {
                icon: "radar"
                tooltipText: pluginApi?.tr("panel.find-device")
                onClicked: {
                  KDEConnect.triggerFindMyPhone(KDEConnect.mainDevice.id)
                }
              }
            }

            // Device Status
            Loader {
              Layout.fillWidth: true
              Layout.fillHeight: true
              active: KDEConnect.mainDevice !== null
              sourceComponent: deviceStatsWithPhone
            }

          }

          Component {
            id: deviceStatsWithPhone

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

                  onClicked: KDEConnect.wakeUpDevice(KDEConnect.mainDevice.id)
                }
              }

              Item {
                width: Style.marginL
              }

              // Stats Grid
              GridLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                columns: 1
                rowSpacing: Style.marginL

                // Battery Section
                RowLayout {
                  spacing: Style.marginM

                  NIcon {
                    icon: deviceData.getBatteryIcon(KDEConnect.mainDevice.battery, KDEConnect.mainDevice.charging)
                    pointSize: Style.fontSizeXXXL
                    applyUiScale: true
                    color: Color.mOnSurface
                  }

                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio

                    NText {
                      text: pluginApi?.tr("panel.card.battery")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                    }

                    NText {
                      text: KDEConnect.mainDevice.battery < 0 ? pluginApi?.tr("panel.unknown") : (KDEConnect.mainDevice.battery + "%")
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightMedium
                      color: Color.mOnSurface
                    }
                  }
                }

                // Network Type Section
                RowLayout {
                  spacing: Style.marginM

                  NIcon {
                    icon: deviceData.getCellularTypeIcon(KDEConnect.mainDevice.cellularNetworkType)
                    pointSize: Style.fontSizeXXXL
                    applyUiScale: true
                    color: Color.mOnSurface
                  }

                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio

                    NText {
                      text: pluginApi?.tr("panel.card.network")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                    }

                    NText {
                      text: KDEConnect.mainDevice.cellularNetworkType || pluginApi?.tr("panel.unknown")
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightMedium
                      color: Color.mOnSurface
                    }
                  }
                }

                // Signal Strength Section
                RowLayout {
                  spacing: Style.marginM

                  NIcon {
                    icon: deviceData.getCellularStrengthIcon(KDEConnect.mainDevice.cellularNetworkStrength)
                    pointSize: Style.fontSizeXXXL
                    applyUiScale: true
                    color: Color.mOnSurface
                  }

                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio

                    NText {
                      text: pluginApi?.tr("panel.card.signal-strength")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                    }

                    NText {
                      text: deviceData.getSignalStrengthText(KDEConnect.mainDevice.cellularNetworkStrength)
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightMedium
                      color: Color.mOnSurface
                    }
                  }
                }

                // Notifications Section
                RowLayout {
                  spacing: Style.marginM

                  NIcon {
                    icon: "notification"
                    pointSize: Style.fontSizeXXXL
                    applyUiScale: true
                    color: Color.mOnSurface
                  }

                  ColumnLayout {
                    spacing: 2 * Style.uiScaleRatio

                    NText {
                      text: pluginApi?.tr("panel.card.notifications")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                    }

                    NText {
                      text: KDEConnect.mainDevice.notificationIds.length
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightMedium
                      color: Color.mOnSurface
                    }
                  }
                }

              }
            }
          }
        }
      }

      Component {
        id: noDevicePairedCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors {
              fill: parent
              margins: Style.marginL
            }
            spacing: Style.marginL

            RowLayout {
              NText {
                text: KDEConnect.mainDevice.name
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              color: "transparent"

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                NButton {
                  text: pluginApi?.tr("panel.pair")
                  Layout.alignment: Qt.AlignHCenter
                  enabled: !KDEConnect.mainDevice.pairRequested
                  onClicked: {
                    KDEConnect.requestPairing(KDEConnect.mainDevice.id)
                    KDEConnect.mainDevice.pairRequested = true
                    KDEConnect.refreshDevices()
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
                    opacity: KDEConnect.mainDevice.pairRequested ? 1.0 : 0.0
                  }

                  NText {
                    text: KDEConnect.mainDevice.verificationKey
                    Layout.alignment: Qt.AlignHCenter
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    opacity: KDEConnect.mainDevice.pairRequested ? 1.0 : 0.0
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  opacity: KDEConnect.mainDevice.pairRequested ? 1.0 : 0.0
                  size: Style.baseWidgetSize * 0.5
                  running: KDEConnect.mainDevice.pairRequested
                }
              }
            }
          }
        }
      }

      Component {
        id: noDevicesAvailableCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "device-mobile-off"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.no-devices")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: deviceNotReachableCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "device-mobile-off"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.device-unavailable")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
            }

            Item {

            }

            NButton {
              text: pluginApi?.tr("panel.unpair")
              Layout.alignment: Qt.AlignHCenter
              onClicked: {
                KDEConnect.unpairDevice(KDEConnect.mainDevice.id)
              }
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }


      Component {
        id: busctlNotFoundCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: kdeConnectDaemonNotRunningCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: deviceSwitcherCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          NScrollView{
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            contentWidth: parent.width
            reserveScrollbarSpace: false
            gradientColor: Color.mSurface

            ColumnLayout {
              id: emptyState
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              Repeater {
                model: KDEConnect.devices
                Layout.fillWidth: true

                NButton {
                  required property var modelData
                  text: modelData.name
                  Layout.fillWidth: true
                  backgroundColor: modelData.id === KDEConnect.mainDevice.id ? Color.mSecondary : Color.mPrimary

                  onClicked: {
                    KDEConnect.setMainDevice(modelData.id);
                    deviceSwitcherOpen = false;

                    pluginApi.pluginSettings.mainDeviceId = modelData.id;
                    pluginApi.saveSettings();
                  }
                }
              }

              Item {
                Layout.fillHeight: true
              }
            }
          }
        }
      }
    }
  }
}
