import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import "components" as Components

Item {
  id: root

  property var pluginApi: null

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var state: mainInstance?.state || ({})
  readonly property var bridge: state.bridge || ({})
  readonly property var hermes: state.hermes || ({})
  readonly property var session: state.session || ({})
  readonly property var approval: state.approval || ({})
  readonly property var messages: state.messages || []
  readonly property var summary: state.summary || ({})
  readonly property var activity: summary.activity || ({})
  readonly property var modelSummary: summary.model || ({})
  readonly property bool hasSession: (session.id || session.stored_id || "") !== ""
  readonly property bool bridgeOnline: (bridge.status || "offline") === "online"
  readonly property bool isBusy: session.running || (hermes.status || "") === "busy"
  readonly property bool pinned: cfg.panelPinned ?? defaults.panelPinned ?? false
  readonly property bool showToolActivity: cfg.showToolActivity ?? defaults.showToolActivity ?? false
  property var sessionList: []
  property bool sessionsLoaded: false
  readonly property string hermesIconPath: pluginApi?.pluginDir ? "file://" + pluginApi.pluginDir + "/assets/hermes-icon.png" : ""
  readonly property string status: bridgeOnline ? (hermes.status || "unknown") : "offline"
  readonly property string modelLabel: {
    var provider = modelSummary.provider || hermes.provider || cfg.defaultProvider || "";
    var model = modelSummary.name || hermes.model || cfg.defaultModel || "";
    if (provider && model) return provider + " / " + model;
    return model || provider || (pluginApi?.tr("panel.noModel"));
  }
  readonly property string activityLabel: {
    var count = activity.tool_events || 0;
    if (count === 0) return "";
    var running = activity.running_tools || 0;
    var last = activity.last_tool || "tool";
    if (running > 0) return String(running) + " " + (pluginApi?.tr("panel.backgroundRunning"));
    return String(count) + " " + (pluginApi?.tr("panel.backgroundActions")) + ", " + (pluginApi?.tr("panel.lastAction")) + ": " + last;
  }

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: Math.min(1040 * Style.uiScaleRatio, Math.max(780 * Style.uiScaleRatio, width * 0.5))
  property real contentPreferredHeight: Math.max(640 * Style.uiScaleRatio, height - Style.margin2L)
  readonly property bool allowAttach: false
  readonly property bool panelAnchorRight: true
  readonly property bool panelAnchorTop: true
  readonly property bool panelAnchorBottom: true

  anchors.fill: parent

  function statusColor() {
    switch (root.status) {
      case "offline": return Color.mError;
      case "attention": return "#f59e0b";
      case "degraded": return "#f97316";
      case "error": return Color.mError;
      default: return Color.mPrimary;
    }
  }

  function statusText() {
    switch (root.status) {
      case "offline": return pluginApi?.tr("status.offline");
      case "idle": return pluginApi?.tr("status.idle");
      case "busy": return pluginApi?.tr("status.busy");
      case "attention": return pluginApi?.tr("status.attention");
      case "degraded": return pluginApi?.tr("status.degraded");
      case "error": return pluginApi?.tr("status.error");
      default: return pluginApi?.tr("status.unknown");
    }
  }

  function sendComposerPrompt() {
    var text = composer.text.trim();
    if (text === "") return;
    composer.text = "";
    if (!root.hasSession && root.mainInstance) {
      root.mainInstance.createSession();
    }
    root.mainInstance?.sendPrompt(text);
  }

  function setPinned(value) {
    if (!pluginApi) return;
    pluginApi.pluginSettings.panelPinned = value;
    pluginApi.saveSettings();
    root.mainInstance?.setPinnedPanelRequested(value);
  }

  function closePanel() {
    if (root.pinned) {
      root.mainInstance?.closePinnedPanel();
      return;
    }
    root.pluginApi?.closePanel(root.pluginApi?.panelOpenScreen);
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
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item {
          Layout.preferredWidth: Style.baseWidgetSize
          Layout.preferredHeight: Style.baseWidgetSize
          Layout.alignment: Qt.AlignVCenter

          Components.HermesAvatar {
            anchors.fill: parent
            iconPath: root.hermesIconPath
            fallbackIcon: "sparkles"
            statusColor: root.statusColor()
            iconSize: Style.fontSizeXL
            dotSize: 9 * Style.uiScaleRatio
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            NText {
              text: root.statusText()
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightSemiBold
              color: root.statusColor()
            }
          }

          NText {
            text: root.modelLabel
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        NButton {
          text: root.pinned ? (pluginApi?.tr("panel.unpin")) : (pluginApi?.tr("panel.pin"))
          icon: root.pinned ? "pinned-off" : "pin"
          onClicked: root.setPinned(!root.pinned)
        }

        NIconButton {
          icon: "history"
          tooltipText: pluginApi?.tr("panel.sessions")
          onClicked: {
            var btn = this;
            root.mainInstance?.listSessions(function(list) {
              root.sessionList = list;
              root.sessionsLoaded = true;
              sessionPopup.openNear(btn);
            });
          }
        }

        NIconButton {
          icon: "close"
          tooltipText: pluginApi?.tr("panel.close")
          onClicked: root.closePanel()
        }
      }

      Components.ApprovalCard {
        pluginApi: root.pluginApi
        approval: root.approval
        onApprove: function(all) {
          if (mainInstance) mainInstance.respondApproval("approved", all);
        }
        onDeny: function() {
          if (mainInstance) mainInstance.respondApproval("denied", false);
        }
      }

      Rectangle {
        visible: root.activityLabel !== "" && (root.showToolActivity || root.isBusy)
        Layout.fillWidth: true
        implicitHeight: activityRow.implicitHeight + Style.margin2S
        radius: Style.radiusS
        color: Color.mSurfaceVariant

        RowLayout {
          id: activityRow
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Style.marginS
            rightMargin: Style.marginS
          }
          spacing: Style.marginS

          NIcon {
            icon: root.isBusy ? "loader" : "activity"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: root.activityLabel
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusS
        color: Color.mSurface

        ScrollView {
          id: transcriptScroll
          anchors.fill: parent
          anchors.margins: Style.marginM
          clip: true

          ColumnLayout {
            id: transcriptLayout
            width: Math.max(transcriptScroll.availableWidth, 1)
            spacing: Style.marginS

            ColumnLayout {
              visible: root.messages.length === 0
              Layout.fillWidth: true
              spacing: Style.marginS

              NIcon {
                icon: root.bridgeOnline ? "message-circle" : "power"
                pointSize: Style.fontSizeXXL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: root.bridgeOnline ? (pluginApi?.tr("panel.noSession")) : (pluginApi?.tr("panel.bridgeOffline"))
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }

            Repeater {
              model: root.messages

              delegate: Components.MessageBubble {
                pluginApi: root.pluginApi
                message: modelData
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: pluginApi?.tr("panel.newSession")
          icon: "plus"
          onClicked: mainInstance?.createSession()
        }

        NButton {
          text: pluginApi?.tr("panel.reset")
          icon: "close"
          outlined: true
          enabled: root.messages.length > 0
          onClicked: mainInstance?.createSession()
        }

        NTextInput {
          id: composer
          Layout.fillWidth: true
          placeholderText: pluginApi?.tr("panel.placeholder")
          enabled: root.bridgeOnline
          Keys.onReturnPressed: root.sendComposerPrompt()
        }

        NButton {
          text: root.isBusy ? (pluginApi?.tr("panel.interrupt")) : (pluginApi?.tr("panel.send"))
          icon: root.isBusy ? "octagon" : "send"
          enabled: root.bridgeOnline && (root.isBusy || composer.text.trim() !== "")
          onClicked: {
            if (root.isBusy) {
              mainInstance?.interrupt();
            } else {
              root.sendComposerPrompt();
            }
          }
        }
      }
    }
  }

  Connections {
    target: mainInstance
    enabled: mainInstance !== null
    function onStateChanged() {
      scrollTimer.restart();
    }
  }

  Timer {
    id: scrollTimer
    interval: 100
    repeat: false
    onTriggered: {
      transcriptScroll.contentItem.contentY = Math.max(0, transcriptScroll.contentItem.contentHeight - transcriptScroll.height);
    }
  }

  Component.onCompleted: {
    mainInstance?.setPinnedPanelRequested(root.pinned);
    mainInstance?.refreshState();
  }

  Components.SessionPopup {
    id: sessionPopup
    pluginApi: root.pluginApi
    mainInstance: root.mainInstance
    screen: root.pluginApi?.panelOpenScreen
    sessions: root.sessionList
    onSessionSelected: function(sid) {
      root.mainInstance?.resumeSession(sid);
    }
  }
}
