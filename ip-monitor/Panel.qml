import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "." as Local
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null
  property var ipMonitorService: pluginApi?.mainInstance?.ipMonitorService || null

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 435 * Style.uiScaleRatio
  property real contentPreferredHeight: 530 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  // IP data state - read from service
  readonly property var ipData: ipMonitorService?.ipData ?? null
  readonly property string fetchState: ipMonitorService?.fetchState ?? "idle"

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("IpMonitor", "Panel initialized with service data");
    }
  }

  // Trigger refresh via service
  function refreshIp() {
    Logger.d("IpMonitor", "Panel triggering service refresh");
    if (ipMonitorService)
      ipMonitorService.fetchIp();
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      // Header with refresh button
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: "IP Information"
          font.pointSize: Style.fontSizeL * Style.uiScaleRatio
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NButton {
          text: "Refresh"
          icon: "refresh"
          enabled: root.fetchState !== "loading"
          onClicked: {
            root.refreshIp();
          }
        }
      }

      // Main IP display
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: ipDisplayLayout.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          id: ipDisplayLayout
          anchors.centerIn: parent
          spacing: Style.marginM

          NIcon {
            icon: {
              if (root.fetchState === "loading")
                return "loader";
              if (root.fetchState === "error")
                return "alert-circle";
              return "network";
            }
            Layout.alignment: Qt.AlignHCenter
            pointSize: Style.fontSizeXXL * 2 * Style.uiScaleRatio
            color: {
              if (root.fetchState === "success")
                return Color.mPrimary;
              if (root.fetchState === "error")
                return Color.mError;
              return Color.mOnSurfaceVariant;
            }
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: {
              if (root.fetchState === "loading")
                return "Fetching IP...";
              if (root.fetchState === "error")
                return "Failed to fetch IP";
              if (root.ipData?.ip)
                return root.ipData.ip;
              return "n/a";
            }
            font.pointSize: Style.fontSizeXXL * Style.uiScaleRatio
            font.weight: Font.Bold
            font.family: Settings.data.ui.fontFixed
            color: Color.mOnSurface
          }

          NText {
            visible: root.fetchState === "success" && root.ipData
            Layout.alignment: Qt.AlignHCenter
            text: {
              var parts = [];
              if (root.ipData?.city)
                parts.push(root.ipData.city);
              if (root.ipData?.country)
                parts.push(root.ipData.country);
              return parts.join(", ");
            }
            font.pointSize: Style.fontSizeM * Style.uiScaleRatio
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // Details section
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM
        visible: root.fetchState === "success" && root.ipData

        NText {
          text: pluginApi?.tr("panel.details.title")
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            Repeater {
              model: [
                {
                  label: pluginApi?.tr("panel.details.ip"),
                  value: root.ipData?.ip
                },
                {
                  label: pluginApi?.tr("panel.details.city"),
                  value: root.ipData?.city
                },
                {
                  label: pluginApi?.tr("panel.details.country"),
                  value: root.ipData?.country
                },
                {
                  label: pluginApi?.tr("panel.details.region"),
                  value: root.ipData?.region
                },
                {
                  label: pluginApi?.tr("panel.details.continent"),
                  value: root.ipData?.continent
                },
                {
                  label: pluginApi?.tr("panel.details.postal-code"),
                  value: root.ipData?.postal
                },
                {
                  label: pluginApi?.tr("panel.details.location"),
                  value: root.ipData?.loc
                },
                {
                  label: pluginApi?.tr("panel.details.timezone"),
                  value: root.ipData?.timezone
                },
                {
                  label: pluginApi?.tr("panel.details.currency"),
                  value: root.ipData?.currency
                },
                {
                  label: pluginApi?.tr("panel.details.org"),
                  value: root.ipData?.org
                },
                {
                  label: pluginApi?.tr("panel.details.as-name"),
                  value: root.ipData?.as
                },
              ]

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                  text: modelData.label + ":"
                  font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                  color: Color.mOnSurfaceVariant
                  Layout.preferredWidth: 100
                }

                NText {
                  text: modelData.value
                  font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                  font.family: Settings.data.ui.fontFixed
                  color: Color.mOnSurface
                  Layout.fillWidth: index !== 0
                  elide: Text.ElideRight
                }

                NIcon {
                  id: copyIcon
                  visible: index === 0 && root.fetchState === "success"
                  icon: "copy"
                  pointSize: Style.fontSizeS * Style.uiScaleRatio
                  color: copyHover.containsMouse ? Color.mOnSurfaceVariant : Color.mPrimary
                  Layout.alignment: Qt.AlignVCenter

                  MouseArea {
                    id: copyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var ip = root.ipData?.ip;
                      if (ip && ip !== "n/a") {
                        Quickshell.execDetached(["sh", "-c", `printf '%s' '${ip}' | wl-copy`]);
                        ToastService.showNotice("IP copied to clipboard: " + ip);
                        Logger.d("IpMonitor", "Copied IP to clipboard:", ip);
                      } else {
                        ToastService.showNotice("No IP to copy");
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
