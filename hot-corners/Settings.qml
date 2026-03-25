import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
  id: root
  property var pluginApi: null

  readonly property var cornerPos: ({
    TopLeft: "TopLeft",
    TopRight: "TopRight",
    BottomLeft: "BottomLeft",
    BottomRight: "BottomRight"
  })

  property var currentSettings: pluginApi ? pluginApi.pluginSettings : {}

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      root.currentSettings = pluginApi.pluginSettings;
    }
  }

  // Main Settings Layout
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: 400

    Rectangle {
      id: screenBox
      width: parent.width - 40
      height: 300
      anchors.centerIn: parent
      color: "transparent"
      border.color: Qt.rgba(0.5, 0.5, 0.5, 0.4)
      border.width: 4
      radius: Style.radiusL
      clip: true

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.marginS
        opacity: 0.3

        NText {
          Layout.alignment: Qt.AlignHCenter
          text: "Screen Corners"
          font.weight: Font.Bold
          pointSize: Style.fontSizeXL
        }

        NText {
          Layout.alignment: Qt.AlignHCenter
          text: "Click on the triangle in the corner to set the command"
          pointSize: Style.fontSizeS
        }
      }

      // Reusable Triangle Corner Component
      component CornerTriangle: Item {
        id: cTri
        property string pos: root.cornerPos.TopLeft
        
        width: 40
        height: 40
        
        anchors.top: (pos === root.cornerPos.TopLeft || pos === root.cornerPos.TopRight) ? parent.top : undefined
        anchors.bottom: (pos === root.cornerPos.BottomLeft || pos === root.cornerPos.BottomRight) ? parent.bottom : undefined
        anchors.left: (pos === root.cornerPos.TopLeft || pos === root.cornerPos.BottomLeft) ? parent.left : undefined
        anchors.right: (pos === root.cornerPos.TopRight || pos === root.cornerPos.BottomRight) ? parent.right : undefined

        anchors.margins: 4
        property real r: Style.radiusL - 4

        property string currentCommand: {
          if (currentSettings && currentSettings.corners && currentSettings.corners[pos]) {
             return currentSettings.corners[pos] || "";
          }
          return "";
        }
        property bool isActive: currentCommand !== ""

        // Custom drawn triangle
        Canvas {
          id: canvas
          anchors.fill: parent
          onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            
            if (pos === root.cornerPos.TopLeft) {
              ctx.moveTo(0, r); ctx.arcTo(0, 0, r, 0, r); ctx.lineTo(width, 0); ctx.lineTo(0, height);
            } else if (pos === root.cornerPos.TopRight) {
              ctx.moveTo(0, 0); ctx.lineTo(width - r, 0); ctx.arcTo(width, 0, width, r, r); ctx.lineTo(width, height);
            } else if (pos === root.cornerPos.BottomLeft) {
              ctx.moveTo(0, 0); ctx.lineTo(0, height - r); ctx.arcTo(0, height, r, height, r); ctx.lineTo(width, height);
            } else if (pos === root.cornerPos.BottomRight) {
              ctx.moveTo(width, 0); ctx.lineTo(width, height - r); ctx.arcTo(width, height, width - r, height, r); ctx.lineTo(0, height);
            }
            
            ctx.closePath();
            // Noctalia primary color or gray
            ctx.fillStyle = isActive ? Color.mPrimary : Qt.rgba(0.5, 0.5, 0.5, 0.5);
            ctx.fill();
            
            // Hover effect outline
            if (mouseArea.containsMouse) {
               ctx.strokeStyle = Style.textColor;
               ctx.lineWidth = 2;
               ctx.stroke();
            }
          }
          
          Connections {
             target: cTri
             function onIsActiveChanged() { canvas.requestPaint(); }
             function onCurrentCommandChanged() { canvas.requestPaint(); }
          }
        }

        Connections {
           target: root
           function onCurrentSettingsChanged() { canvas.requestPaint(); }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          onEntered: {
            canvas.requestPaint();
            if (isActive) {
              TooltipService.show(cTri, currentCommand);
            }
          }
          onExited: {
            canvas.requestPaint();
            TooltipService.hide();
          }
          onCanceled: {
            TooltipService.hide();
          }
          onClicked: {
            if (isActive) {
              TooltipService.hide();
            }
            popupOverlay.targetCorner = pos;
            popupOverlay.initialText = currentCommand;
            popupOverlay.visible = true;
          }
        }
      }

      CornerTriangle { pos: root.cornerPos.TopLeft }
      CornerTriangle { pos: root.cornerPos.TopRight }
      CornerTriangle { pos: root.cornerPos.BottomLeft }
      CornerTriangle { pos: root.cornerPos.BottomRight }
    }

    // Input Popup Overlay
    Rectangle {
      id: popupOverlay
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5)
      visible: false
      
      property string targetCorner: ""
      property string initialText: ""

      MouseArea {
        anchors.fill: parent
        // Block clicks from passing through
      }

      Rectangle {
        width: 400
        height: column.height + Style.marginL * 2
        anchors.centerIn: parent
        color: Color.mSurfaceVariant
        border.color: Color.mOutline
        border.width: Style.borderM
        radius: Style.radiusL

        ColumnLayout {
          id: column
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginL
          spacing: Style.marginM

          NText {
            text: "Custom Command for " + popupOverlay.targetCorner
            color: Color.mOnSurface
          }

          RowLayout {
            Layout.fillWidth: true
            NTextInput {
              id: cmdInput
              Layout.fillWidth: true
              placeholderText: "e.g., noctalia-shell ipc call settings toggle"
              text: popupOverlay.initialText
              inputItem.onEditingFinished: column.saveAndClose()
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignRight
            NButton {
              text: "Cancel"
              outlined: true
              onClicked: popupOverlay.visible = false
            }
            NButton {
              text: "Save"
              onClicked: column.saveAndClose()
            }
          }
          
          // Local function to handle save specifically
          function saveAndClose() {
             var val = cmdInput.text.trim();
             var corner = popupOverlay.targetCorner;
             popupOverlay.visible = false;
             
             if (corner !== "") {
                 updateCornerSetting(corner, val);
             }
          }
        }
      }
      
      onVisibleChanged: {
        if (visible) {
           cmdInput.text = initialText;
           cmdInput.forceActiveFocus();
        } else {
           // Reset temporary vars on close
           popupOverlay.targetCorner = "";
           popupOverlay.initialText = "";
        }
      }
    }
  }

  Item {
    Layout.fillHeight: true
  }

  function updateCornerSetting(cornerId, value) {
    if (!pluginApi) return;
    
    var baseSettings = currentSettings || {};
    var newSettings = JSON.parse(JSON.stringify(baseSettings));
    if (!newSettings.corners) {
      newSettings.corners = {};
    }
    
    newSettings.corners[cornerId] = value;
    
    pluginApi.pluginSettings = newSettings;
    pluginApi.saveSettings();
  }
}
