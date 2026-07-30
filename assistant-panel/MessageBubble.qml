import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var message
  property var pluginApi

  readonly property int bubblePadding: Style.marginM
  readonly property bool isToolMessage: message.role === "tool"
  readonly property bool hasToolCalls: message.role === "assistant" && message.tool_calls && message.tool_calls.length > 0

  signal regenerateRequested
  signal copyRequested(string text)
  signal editRequested(string id, string newText)

  property bool isEditing: false
  property string editBuffer: ""
  property bool toolExpanded: false

  height: mainLayout.implicitHeight
  width: parent ? parent.width : 400

  // ---------------------------------------------------------
  // User Row Hover Logic
  // ---------------------------------------------------------
  MouseArea {
    id: userHoverArea
    visible: message.role === "user"
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    z: 0
  }

  RowLayout {
    id: mainLayout
    z: 1

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.marginS

    // ---------------------------------------------------------
    // Left Side Items
    // ---------------------------------------------------------

    NIcon {
      Layout.alignment: Qt.AlignTop
      visible: message.role === "assistant" && !root.hasToolCalls
      icon: "sparkles"
      color: Color.mPrimary
      pointSize: Style.fontSizeL
      applyUiScale: false
    }

    NIcon {
      Layout.alignment: Qt.AlignTop
      visible: root.hasToolCalls
      icon: "tool"
      color: Color.mTertiary
      pointSize: Style.fontSizeL
      applyUiScale: false
    }

    NIcon {
      Layout.alignment: Qt.AlignTop
      visible: root.isToolMessage
      icon: "terminal-2"
      color: Color.mSecondary
      pointSize: Style.fontSizeL
      applyUiScale: false
    }

    Item {
      visible: message.role === "user"
      Layout.fillWidth: true
    }

    // ---------------------------------------------------------
    // Message Bubble
    // ---------------------------------------------------------
    Rectangle {
      id: bubbleRect

      Layout.maximumWidth: parent.width * 0.8
      Layout.preferredWidth: root.isEditing ? (parent.width * 0.8) : (contentCol.implicitWidth + (root.bubblePadding * 2))
      Layout.preferredHeight: contentCol.implicitHeight + (root.bubblePadding * 2)

      color: {
        if (root.isToolMessage) return Qt.alpha(Color.mSecondary, 0.1);
        if (root.hasToolCalls) return Qt.alpha(Color.mTertiary, 0.1);
        if (message.role === "user") return Color.mSurfaceVariant;
        return Color.mSurface;
      }
      radius: Style.radiusM

      // Sharp Corner Hack for User (Top Right)
      Rectangle {
        visible: message.role === "user"
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.radius
        height: parent.radius
        color: parent.color
      }

      // ---------------------------------------------------------
      // User Action Buttons (Floating Outside Left)
      // ---------------------------------------------------------
      Row {
        id: userActionButtons
        visible: message.role === "user" && !root.isEditing && (userHoverArea.containsMouse || copyBtnMouse.containsMouse || editBtnMouse.containsMouse)
        z: 2
        spacing: Style.marginXS

        anchors.right: parent.left
        anchors.top: parent.top
        anchors.rightMargin: Style.marginXS

        // Copy Button
        Rectangle {
          width: 28
          height: 28
          radius: 4
          color: copyBtnMouse.containsMouse ? Color.mSurfaceVariant : "transparent"

          NIcon {
            anchors.centerIn: parent
            icon: "copy"
            pointSize: Style.fontSizeS
            applyUiScale: false
            color: copyBtnMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          MouseArea {
            id: copyBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyRequested(message.content)

            ToolTip.visible: containsMouse
            ToolTip.text: pluginApi?.tr("chat.copy") ?? "Copy"
          }
        }

        // Edit Button
        Rectangle {
          width: 28
          height: 28
          radius: 4
          color: editBtnMouse.containsMouse ? Color.mSurfaceVariant : "transparent"

          NIcon {
            anchors.centerIn: parent
            icon: "pencil"
            pointSize: Style.fontSizeS
            applyUiScale: false
            color: editBtnMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          MouseArea {
            id: editBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.editBuffer = message.content;
              root.isEditing = true;
            }

            ToolTip.visible: containsMouse
            ToolTip.text: pluginApi?.tr("chat.edit") ?? "Edit"
          }
        }
      }

      // ---------------------------------------------------------
      // Bubble Content
      // ---------------------------------------------------------
      ColumnLayout {
        id: contentCol
        z: 2

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.bubblePadding

        spacing: Style.marginS

        // ---------------------------------------------------------
        // Tool Call Header (for assistant messages requesting tools)
        // ---------------------------------------------------------
        ColumnLayout {
          visible: root.hasToolCalls
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: pluginApi?.tr("chat.usingTools")
            color: Color.mTertiary
            pointSize: Style.fontSizeS
            applyUiScale: false
            font.weight: Font.Medium
          }

          Repeater {
            model: message.tool_calls || []

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS

              NIcon {
                icon: "chevron-right"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                applyUiScale: false
              }

              NText {
                text: modelData.name + "(" + formatToolArgs(modelData.arguments) + ")"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                applyUiScale: false
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: "monospace"
              }
            }
          }
        }

        // ---------------------------------------------------------
        // Tool Result Header (for tool response messages)
        // ---------------------------------------------------------
        RowLayout {
          visible: root.isToolMessage
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            text: message.tool_name || "tool"
            color: Color.mSecondary
            pointSize: Style.fontSizeS
            applyUiScale: false
            font.weight: Font.Medium
            font.family: "monospace"
          }

          NText {
            visible: message.tool_args !== undefined
            text: formatToolArgs(message.tool_args)
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            applyUiScale: false
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: "monospace"
          }

          // Expand/collapse toggle
          Rectangle {
            width: 24
            height: 24
            radius: Style.radiusS
            color: expandMouse.containsMouse ? Color.mSurfaceVariant : "transparent"

            NIcon {
              anchors.centerIn: parent
              icon: root.toolExpanded ? "chevron-up" : "chevron-down"
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              applyUiScale: false
            }

            MouseArea {
              id: expandMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toolExpanded = !root.toolExpanded
            }
          }
        }

        // Tool result content (collapsed by default)
        TextEdit {
          Layout.maximumWidth: bubbleRect.Layout.maximumWidth - (root.bubblePadding * 2)
          Layout.fillWidth: true
          wrapMode: TextEdit.Wrap

          visible: root.isToolMessage && root.toolExpanded
          text: message.content || ""
          textFormat: Text.PlainText
          readOnly: true
          selectByMouse: true

          color: Color.mOnSurface
          font.family: "monospace"
          font.pointSize: Math.max(1, Style.fontSizeS * Settings.data.ui.fontDefaultScale * Style.uiScaleRatio)

          selectionColor: Color.mPrimary
          selectedTextColor: Color.mOnPrimary
        }

        // Collapsed tool result preview
        NText {
          visible: root.isToolMessage && !root.toolExpanded
          text: {
            var content = message.content || "";
            var firstLine = content.split("\n")[0];
            if (firstLine.length > 80) return firstLine.substring(0, 80) + "...";
            if (content.split("\n").length > 1) return firstLine + "...";
            return firstLine;
          }
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          applyUiScale: false
          Layout.fillWidth: true
          elide: Text.ElideRight
          font.family: "monospace"
        }

        // ---------------------------------------------------------
        // Regular Message Content
        // ---------------------------------------------------------
        TextEdit {
          Layout.maximumWidth: bubbleRect.Layout.maximumWidth - (root.bubblePadding * 2)
          Layout.fillWidth: true
          wrapMode: TextEdit.Wrap

          visible: !root.isEditing && !root.isToolMessage && !(root.hasToolCalls && (!message.content || message.content.trim() === ""))
          text: message.content || ""
          textFormat: message.role === "assistant" ? Text.MarkdownText : Text.PlainText
          readOnly: true
          selectByMouse: true

          color: Color.mOnSurface
          font.family: Settings.data.ui.fontDefault
          font.pointSize: Math.max(1, Style.fontSizeM * Settings.data.ui.fontDefaultScale * Style.uiScaleRatio)
          font.weight: Style.fontWeightMedium

          selectionColor: Color.mPrimary
          selectedTextColor: Color.mOnPrimary

          onLinkActivated: link => Qt.openUrlExternally(link)
        }

        // Edit Area
        ColumnLayout {
          visible: root.isEditing
          Layout.fillWidth: true
          spacing: Style.marginS

          TextArea {
            id: editArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(80, contentHeight + 20)
            text: root.editBuffer
            wrapMode: TextEdit.Wrap
            focus: root.isEditing

            color: Color.mOnSurface
            background: Rectangle {
              color: Color.mSurface
              radius: Style.radiusS
              border.width: 1
              border.color: editArea.activeFocus ? Color.mPrimary : "transparent"
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Style.marginS

            NButton {
              text: pluginApi?.tr("chat.save")
              backgroundColor: Color.mPrimary
              textColor: Color.mOnPrimary
              hoverColor: Qt.lighter(Color.mPrimary, 1.2)
              textHoverColor: Color.mOnPrimary
              onClicked: {
                root.isEditing = false;
                if (editArea.text !== message.content) {
                  root.editRequested(message.id, editArea.text);
                }
              }
            }

            NButton {
              text: pluginApi?.tr("chat.cancel")
              backgroundColor: Color.mSurface
              textColor: Color.mOnSurface
              hoverColor: Qt.lighter(Color.mSurface, 1.3)
              textHoverColor: Color.mOnSurface
              onClicked: root.isEditing = false
            }
          }
        }

        // Assistant Buttons (Bottom)
        RowLayout {
          visible: message.role === "assistant" && !message.isStreaming && !root.hasToolCalls
          spacing: Style.marginS
          Layout.alignment: Qt.AlignLeft

          // Copy Button
          Rectangle {
            width: 28
            height: 28
            radius: 4
            color: copyMouse.containsMouse ? Color.mSurfaceVariant : "transparent"

            NIcon {
              anchors.centerIn: parent
              icon: "copy"
              pointSize: Style.fontSizeM
              applyUiScale: false
              color: copyMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            MouseArea {
              id: copyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyRequested(message.content)
              ToolTip.visible: containsMouse
              ToolTip.text: pluginApi?.tr("chat.copy") ?? "Copy"
            }
          }

          // Regenerate Button
          Rectangle {
            width: 28
            height: 28
            radius: 4
            color: regenMouse.containsMouse ? Color.mSurfaceVariant : "transparent"

            NIcon {
              anchors.centerIn: parent
              icon: "refresh"
              pointSize: Style.fontSizeM
              applyUiScale: false
              color: regenMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            MouseArea {
              id: regenMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.regenerateRequested()
              ToolTip.visible: containsMouse
              ToolTip.text: pluginApi?.tr("chat.regenerate") ?? "Regenerate"
            }
          }
        }
      }
    }

    // ---------------------------------------------------------
    // Right Side Items
    // ---------------------------------------------------------

    Item {
      visible: message.role === "assistant" || root.isToolMessage
      Layout.fillWidth: true
    }

    NIcon {
      Layout.alignment: Qt.AlignTop
      visible: message.role === "user"
      icon: "user"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeL
      applyUiScale: false
    }
  }

  function formatToolArgs(args) {
    if (!args) return "";
    var obj = args;
    if (typeof args === "string") {
      try { obj = JSON.parse(args); } catch (e) { return args; }
    }
    var parts = [];
    var keys = Object.keys(obj);
    for (var i = 0; i < keys.length; i++) {
      var val = obj[keys[i]];
      if (typeof val === "string" && val.length > 40) val = val.substring(0, 40) + "...";
      parts.push(keys[i] + "=" + JSON.stringify(val));
    }
    return parts.join(", ");
  }
}
