import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var main: pluginApi?.mainInstance
  readonly property bool configured: main?.isConfigured ?? false
  readonly property bool hasError: main?.hasError ?? false
  readonly property bool showNotificationBadge: pluginApi?.pluginSettings?.showNotificationBadge ?? true
  readonly property bool colorizationEnabled: pluginApi?.pluginSettings?.colorizationEnabled ?? false
  readonly property string colorizationIcon: pluginApi?.pluginSettings?.colorizationIcon ?? "Primary"
  readonly property string colorizationBadge: pluginApi?.pluginSettings?.colorizationBadge ?? "Error"
  readonly property string colorizationBadgeText: pluginApi?.pluginSettings?.colorizationBadgeText ?? "Primary"

  function getThemeColor(key) {
    switch (key) {
      case "Primary": return Color.mPrimary
      case "Secondary": return Color.mSecondary
      case "Tertiary": return Color.mTertiary
      case "Error": return Color.mError
      default: return Color.mOnSurface
    }
  }

  icon: "sword"
  tooltipText: buildTooltip()
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: {
    if (hasError) return Color.mError
    if (!configured) return Color.mOnSurfaceVariant
    if (colorizationEnabled && colorizationIcon !== "None") return getThemeColor(colorizationIcon)
    return Color.mOnSurface
  }
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: "transparent"
  colorBorderHover: "transparent"

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.openPanel"),
        "action": "open-panel",
        "icon": "sword",
        "enabled": root.configured
      },
      {
        "label": pluginApi?.tr("menu.refresh"),
        "action": "refresh",
        "icon": "refresh",
        "enabled": root.configured && !(root.main?.isLoading ?? false)
      },
      {
        "label": pluginApi?.tr("menu.openSettings"),
        "action": "open-settings",
        "icon": "settings"
      },
      {
        "label": pluginApi?.tr("menu.openHabitica"),
        "action": "open-habitica",
        "icon": "external-link"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "open-panel") {
        pluginApi.openPanel(root.screen, root)
      } else if (action === "refresh") {
        if (root.main && root.configured) {
          root.main.refresh()
          ToastService.showNotice(pluginApi?.tr("toast.refreshing"))
        }
      } else if (action === "open-settings") {
        if (pluginApi?.manifest) {
          BarService.openPluginSettings(screen, pluginApi.manifest)
        }
      } else if (action === "open-habitica") {
        Qt.openUrlExternally("https://habitica.com")
      }
    }
  }

  Rectangle {
    id: badge
    visible: root.showNotificationBadge && root.configured && (root.main?.pendingCount || 0) > 0
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 2 * Style.uiScaleRatio
    anchors.topMargin: 2 * Style.uiScaleRatio
    z: 2
    height: 14 * Style.uiScaleRatio
    width: Math.max(height, badgeText.implicitWidth + 6 * Style.uiScaleRatio)
    radius: height / 2
    color: root.colorizationEnabled && root.colorizationBadge !== "None" ? root.getThemeColor(root.colorizationBadge) : Color.mError
    border.color: Color.mSurface
    border.width: Style.uiScaleRatio

    NText {
      id: badgeText
      anchors.centerIn: parent
      text: {
        var count = root.main?.pendingCount || 0
        return count > 99 ? "99+" : count.toString()
      }
      pointSize: Style.fontSizeXS * 0.8
      font.weight: Font.Bold
      color: root.colorizationEnabled && root.colorizationBadgeText !== "None" ? root.getThemeColor(root.colorizationBadgeText) : Color.mOnError
    }
  }

  onClicked: {
    if (!root.configured) {
      ToastService.showNotice(pluginApi?.tr("toast.configure"))
      return
    }
    pluginApi.openPanel(root.screen, this)
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen)
  }

  function buildTooltip() {
    if (!configured) return pluginApi?.tr("tooltip.configure")
    if (hasError) return pluginApi?.tr("tooltip.error") + (main?.errorMessage || pluginApi?.tr("tooltip.unknownError"))
    if (main?.isLoading) return pluginApi?.tr("tooltip.loading")

    var tooltip = "Habitica - " + (main?.displayName() || pluginApi?.tr("tooltip.player"))
    tooltip += "\n" + (main?.levelText() || pluginApi?.tr("tooltip.levelFallback"))
    var hpFallback = pluginApi?.tr("tooltip.hpFallback")
    var xpFallback = pluginApi?.tr("tooltip.xpFallback")
    var goldFallback = pluginApi?.tr("tooltip.goldFallback")
    tooltip += "\n" + (main?.hpText() || hpFallback) + " - " + (main?.xpText() || xpFallback) + " - " + (main?.goldText() || goldFallback)
    tooltip += "\n" + (main?.dueDailiesCount || 0) + pluginApi?.tr("tooltip.dailies") + (main?.dueTodosCount || 0) + pluginApi?.tr("tooltip.todos")

    if (main?.lastFetchTimestamp) {
      var age = Math.floor(Date.now() / 1000) - main.lastFetchTimestamp
      var minutes = Math.floor(age / 60)
      if (minutes < 1) tooltip += "\n" + pluginApi?.tr("tooltip.updatedNow")
      else if (minutes < 60) tooltip += "\n" + pluginApi?.tr("tooltip.updatedMinutesPrefix") + minutes + pluginApi?.tr("tooltip.updatedMinutesSuffix")
      else tooltip += "\n" + pluginApi?.tr("tooltip.updatedMinutesPrefix") + Math.floor(minutes / 60) + pluginApi?.tr("tooltip.updatedHoursSuffix")
    }

    tooltip += "\n\n" + pluginApi?.tr("tooltip.actionsHint")
    return tooltip
  }
}
