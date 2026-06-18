import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property string txSpeed: (SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s").padStart(8, " ")
  property string rxSpeed: (SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s").padStart(8, " ")

  // ── Configuration ──

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string iconType: cfg.iconType ?? defaults.iconType
  property int byteThresholdActive: cfg.byteThresholdActive ?? defaults.byteThresholdActive
  property string layout: cfg.layout ?? defaults.layout
  property var slots: cfg.slots ?? defaults.slots

  property real fontSizeModifier: cfg.fontSizeModifier ?? defaults.fontSizeModifier
  property real iconSizeModifier: cfg.iconSizeModifier ?? defaults.iconSizeModifier

  property real columnSpacing: cfg.columnSpacing ?? defaults.columnSpacing
  property real rowSpacing: cfg.rowSpacing ?? defaults.rowSpacing
  property real paddingLeft: cfg.paddingLeft ?? defaults.paddingLeft
  property real paddingRight: cfg.paddingRight ?? defaults.paddingRight

  property bool useCustomColors: cfg.useCustomColors ?? defaults.useCustomColors
  property color colorSilent: root.useCustomColors && cfg.colorSilent || Color.mSurfaceVariant
  property color colorTx: root.useCustomColors && cfg.colorTx || Color.mSecondary
  property color colorRx: root.useCustomColors && cfg.colorRx || Color.mPrimary
  property color colorText: root.useCustomColors && cfg.colorText || Color.mOnSurfaceVariant

  property bool useCustomFont: cfg.useCustomFont ?? defaults.useCustomFont
  property string customFontFamily: cfg.customFontFamily ?? defaults.customFontFamily
  property bool customFontBold: cfg.customFontBold ?? defaults.customFontBold
  property bool customFontItalic: cfg.customFontItalic ?? defaults.customFontItalic

  readonly property string resolvedFontFamily: {
    if (root.useCustomFont && root.customFontFamily)
      return root.customFontFamily;
    return Settings.data.ui.fontDefault;
  }

  readonly property int resolvedFontWeight: {
    if (root.useCustomFont && root.customFontBold)
      return Font.Bold;
    return Style.fontWeightMedium;
  }

  readonly property bool resolvedFontItalic: root.useCustomFont && root.customFontItalic

  // ── Widget ──

  property bool txActive: SystemStatService.txSpeed >= root.byteThresholdActive
  property bool rxActive: SystemStatService.rxSpeed >= root.byteThresholdActive

  property string barPosition: Settings.data.bar.position || "top"
  property string barDensity: Settings.data.bar.density || "compact"
  property bool barIsSpacious: barDensity != "mini"
  property bool barIsVertical: barPosition === "left" || barPosition === "right"

  readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : content.implicitWidth + root.paddingLeft + root.paddingRight
  readonly property real contentHeight: barIsVertical ? Math.round(content.implicitHeight + Style.marginM * 2) : Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  NIcon {
    id: txIconElement
    icon: root.iconType + "-up"
    color: root.txActive ? root.colorTx : root.colorSilent
    pointSize: Style.fontSizeL * root.iconSizeModifier
  }

  NIcon {
    id: rxIconElement
    icon: root.iconType + "-down"
    color: root.rxActive ? root.colorRx : root.colorSilent
    pointSize: Style.fontSizeL * root.iconSizeModifier
  }

  NText {
    id: txSpeedElement
    text: root.txSpeed
    color: root.colorText
    pointSize: Style.barFontSize * root.fontSizeModifier
    font.family: root.resolvedFontFamily
    font.weight: root.resolvedFontWeight
    font.italic: root.resolvedFontItalic
  }

  NText {
    id: rxSpeedElement
    text: root.rxSpeed
    color: root.colorText
    pointSize: Style.barFontSize * root.fontSizeModifier
    font.family: root.resolvedFontFamily
    font.weight: root.resolvedFontWeight
    font.italic: root.resolvedFontItalic
  }

  function getElement(name) {
    switch (name) {
    case "txIcon":
      return txIconElement;
    case "rxIcon":
      return rxIconElement;
    case "txSpeed":
      return txSpeedElement;
    case "rxSpeed":
      return rxSpeedElement;
    default:
      return null;
    }
  }

  readonly property var spacers: [spacer0, spacer1, spacer2, spacer3]

  Item {
    id: spacer0
  }
  Item {
    id: spacer1
  }
  Item {
    id: spacer2
  }
  Item {
    id: spacer3
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: Style.capsuleColor
    radius: Style.radiusM
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    GridLayout {
      id: content

      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: root.paddingLeft
      anchors.right: parent.right
      anchors.rightMargin: root.paddingRight

      rows: root.layout === "horizontal" ? 1 : 2
      columns: root.layout === "horizontal" ? 4 : 2
      columnSpacing: root.columnSpacing
      rowSpacing: root.rowSpacing
    }
  }

  function rebuildLayout() {
    rxIconElement.parent = root;
    rxIconElement.visible = false;
    rxSpeedElement.parent = root;
    rxSpeedElement.visible = false;
    txIconElement.parent = root;
    txIconElement.visible = false;
    txSpeedElement.parent = root;
    txSpeedElement.visible = false;

    for (let s of spacers) {
      s.parent = root;
      s.visible = false;
    }

    for (let idx = 0; idx < root.slots.length; idx++) {
      const elem = root.getElement(root.slots[idx]);
      if (elem) {
        elem.parent = content;
        elem.visible = true;
      } else {
        const s = spacers[idx];
        s.parent = content;
        s.visible = true;
      }
    }
  }

  onSlotsChanged: rebuildLayout()
  onLayoutChanged: rebuildLayout()
  Component.onCompleted: rebuildLayout()

  // ── Interaction ──

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: mouse => {
      if (mouse.button == Qt.LeftButton)
        pluginApi.togglePanel(root.screen, root);

      if (mouse.button == Qt.RightButton)
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
      id: contextMenu

      model: [
        {
          "label": root.pluginApi?.tr("actions.toggle-panel"),
          "action": "toggle-panel",
          "icon": "activity"
        },
        {
          "label": root.pluginApi?.tr("actions.widget-settings"),
          "action": "widget-settings",
          "icon": "settings"
        },
      ]

      onTriggered: action => {
        contextMenu.close();
        PanelService.closeContextMenu(screen);

        if (action === "toggle-panel")
          pluginApi.togglePanel(root.screen, root);
        else if (action === "widget-settings") {
          BarService.openPluginSettings(screen, pluginApi.manifest);
        }
      }
    }
  }
}
