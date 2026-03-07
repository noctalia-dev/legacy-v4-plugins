import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Services.Compositor
import qs.Widgets

Item {
  id: root

  // ===== REQUIRED PROPERTIES =====
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  visible: CompositorService.isMango

  // ===== DATA BINDING =====
  readonly property string layoutCode: (pluginApi?.mainInstance?.monitorLayouts ?? {})[screen?.name] || "?"
  readonly property string layoutName: pluginApi?.mainInstance?.getLayoutName(layoutCode) || layoutCode

  // ===== ICON MAPPING =====
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

  // ===== SIZING =====
  implicitWidth: pill.width
  implicitHeight: pill.height

  // ===== COMPONENT =====
  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)

    // Dynamic Icon
    icon: root.iconMap[root.layoutCode] || "layout-board"
    
    // Text shown on hover
    text: root.layoutName
    tooltipText: "Layout: " + root.layoutName

    onClicked: {
      if (pluginApi) pluginApi.openPanel(root.screen, root)
    }

    onRightClicked: {
      if (pluginApi) pluginApi.openPanel(root.screen, root)
    }
  }
}
