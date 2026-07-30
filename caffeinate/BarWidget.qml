pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets
import "DurationLanguage.js" as DurationLanguage
import "LauncherModel.js" as LauncherModel

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Noctalia caches plugin directory entries for the shell runtime. Reusing a
  // v1.0.2 entry file lets updates add the panel without requiring a restart.
  readonly property bool isBarInstance: widgetId !== ""
  readonly property bool allowAttach: true
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool sessionActive: mainInstance?.sessionActive ?? false
  readonly property bool indefinite: sessionActive && (mainInstance?.remainingSeconds === null)
  readonly property bool hideWhenInactive: pluginApi?.pluginSettings?.hideInactiveWidget ?? false
  readonly property string compactStatusText: formatStatusText(false)
  readonly property string detailedStatusText: formatStatusText(true)
  readonly property string statusText: showDetailedTime ? detailedStatusText : compactStatusText
  readonly property var sessionSnapshot: ({
                                            "active": sessionActive
                                          })
  readonly property var presetActions: LauncherModel.presetActions(pluginApi?.pluginSettings
                                                                   ?.presets ?? [], pluginApi
                                                                   ?.pluginSettings
                                                                   ?.includeIndefinitePreset ?? true,
                                                                   sessionSnapshot,
                                                                   DurationLanguage.parse)

  property bool showDetailedTime: false
  property real contentPreferredWidth: 360 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.min((contentLoader.item?.contentImplicitHeight ?? 0)
                                                 + Style.marginL * 2,
                                                 560 * Style.uiScaleRatio)

  visible: isBarInstance ? sessionActive || !hideWhenInactive : true
  implicitWidth: isBarInstance ? (visible ? contentLoader.item?.implicitWidth ?? 0 : 0) :
                                 contentPreferredWidth
  implicitHeight: isBarInstance ? (visible ? contentLoader.item?.implicitHeight ?? 0 : 0) :
                                  contentPreferredHeight

  onSessionActiveChanged: {
    if (!sessionActive) {
      hoverDetailTimer.stop();
      showDetailedTime = false;
    }
  }

  function formatStatusText(includeSeconds) {
    if (!sessionActive)
      return pluginApi?.tr("bar.inactiveText") ?? "";
    if (indefinite)
      return pluginApi?.tr("bar.indefiniteText") ?? "∞";

    const remainingSeconds = mainInstance?.remainingSeconds ?? 0;
    const hasCurrentFormatter = typeof DurationLanguage.formatCompactBarDuration === "function";
    if (includeSeconds) {
      return hasCurrentFormatter ? DurationLanguage.formatBarDuration(remainingSeconds) :
                                   formatDetailedBarDuration(remainingSeconds);
    }
    return hasCurrentFormatter ? DurationLanguage.formatCompactBarDuration(remainingSeconds) :
                                 DurationLanguage.formatDuration(
                                   Math.max(60, Math.ceil(remainingSeconds / 60) * 60));
  }

  function formatDetailedBarDuration(seconds) {
    // v1.0.2's DurationLanguage object remains cached during an in-place
    // update. Remove this fallback when upgrades from v1.0.2 are no longer
    // supported.
    let remaining = Math.max(0, Math.floor(seconds));
    const units = [
      ["w", 604800],
      ["d", 86400],
      ["h", 3600],
      ["m", 60],
      ["s", 1]
    ];
    const parts = [];
    let hasHigherUnit = false;

    for (let index = 0; index < units.length; index++) {
      const value = Math.floor(remaining / units[index][1]);
      const isSeconds = index === units.length - 1;
      if (value > 0 || hasHigherUnit || isSeconds) {
        parts.push(value + units[index][0]);
        hasHigherUnit = true;
      }
      remaining %= units[index][1];
    }

    return parts.join(" ");
  }

  function tooltip() {
    if (!sessionActive)
      return pluginApi?.tr("bar.inactiveTooltip");
    if (indefinite)
      return pluginApi?.tr("bar.indefiniteTooltip");
    return pluginApi?.tr("bar.finiteTooltip", {
                           "duration": detailedStatusText
                         });
  }

  function panelStatusText() {
    if (!sessionActive)
      return pluginApi?.tr("status.off");
    if (indefinite)
      return pluginApi?.tr("status.indefinite");
    return pluginApi?.tr("status.finite", {
                           "duration": DurationLanguage.formatDuration(mainInstance
                                                                       ?.remainingSeconds ?? 0)
                         });
  }

  function presetLabel(action) {
    if (action.action === "start-indefinite")
      return pluginApi?.tr("panel.untilStopped");
    return action.normalized ?? "";
  }

  function closePanel() {
    if (pluginApi?.panelOpenScreen)
      pluginApi.closePanel(pluginApi.panelOpenScreen);
  }

  function activatePreset(action) {
    if (!mainInstance)
      return;

    const started = action.action === "start-indefinite" ? mainInstance.startIndefinite() :
                                                           mainInstance.startFinite(action.seconds);
    if (started)
      closePanel();
  }

  function cancelSession() {
    if (mainInstance?.endSession())
      closePanel();
  }

  function openLauncher() {
    if (pluginApi?.panelOpenScreen)
      pluginApi.openLauncher(pluginApi.panelOpenScreen);
  }

  Timer {
    id: hoverDetailTimer

    interval: Style.pillDelay
    onTriggered: root.showDetailedTime = true
  }

  Loader {
    id: contentLoader

    anchors.fill: parent
    sourceComponent: root.isBarInstance ? barComponent : panelComponent
  }

  Component {
    id: barComponent

    Item {
      implicitWidth: pill.implicitWidth
      implicitHeight: pill.implicitHeight

      NPopupContextMenu {
        id: contextMenu

        model: [
          {
            "label": I18n.tr("actions.widget-settings"),
            "action": "widget-settings",
            "icon": "settings"
          }
        ]

        onTriggered: action => {
          contextMenu.close();
          PanelService.closeContextMenu(root.screen);

          if (action === "widget-settings" && root.pluginApi)
            BarService.openPluginSettings(root.screen, root.pluginApi.manifest);
        }
      }

      BarPill {
        id: pill

        screen: root.screen
        icon: root.sessionActive ? "coffee" : "coffee-off"
        text: root.statusText
        forceOpen: root.sessionActive
        oppositeDirection: BarService.getPillDirection(root)
        tooltipText: root.tooltip()
        customIconColor: root.sessionActive ? Color.mPrimary :
                                              Qt.alpha(Color.mOnSurfaceVariant, 0.38)
        customTextColor: root.sessionActive ? Color.mOnSurface : Color.mOnSurfaceVariant

        onEntered: {
          if (root.sessionActive && !root.indefinite)
            hoverDetailTimer.restart();
        }

        onExited: {
          hoverDetailTimer.stop();
          root.showDetailedTime = false;
        }

        onClicked: {
          if (root.pluginApi)
            root.pluginApi.openPanel(root.screen, root);
        }

        onRightClicked: PanelService.showContextMenu(contextMenu, pill, root.screen)
      }
    }
  }

  Component {
    id: panelComponent

    Item {
      readonly property real contentImplicitHeight: contentColumn.implicitHeight

      ColumnLayout {
        id: contentColumn

        anchors {
          fill: parent
          margins: Style.marginL
        }
        spacing: Style.marginL

        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: statusRow.implicitHeight + Style.marginM * 2

          RowLayout {
            id: statusRow

            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginM

            NIcon {
              icon: root.sessionActive ? "coffee" : "coffee-off"
              pointSize: Style.fontSizeXL
              color: root.sessionActive ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NText {
                Layout.fillWidth: true
                text: root.pluginApi?.tr("panel.title")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              NText {
                Layout.fillWidth: true
                text: root.panelStatusText()
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: root.pluginApi?.tr(root.sessionActive ? "panel.replaceSession" :
                                                          "panel.startSession")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
          }

          NText {
            Layout.fillWidth: true
            text: root.pluginApi?.tr("panel.presetsDescription")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }
        }

        NScrollView {
          id: presetsScroll

          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(presetsGrid.implicitHeight, 224 * Style.uiScaleRatio)
          visible: root.presetActions.length > 0
          horizontalPolicy: ScrollBar.AlwaysOff
          showScrollbarWhenScrollable: true
          gradientColor: Color.mSurface

          GridLayout {
            id: presetsGrid

            width: presetsScroll.availableWidth
            columns: 2
            rowSpacing: Style.marginS
            columnSpacing: Style.marginS
            uniformCellWidths: true

            Repeater {
              model: root.presetActions

              delegate: NButton {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.columnSpan: root.presetLabel(modelData).length > 14 ? 2 : 1
                text: root.presetLabel(modelData)
                icon: modelData.action === "start-indefinite" ? "infinity" : "clock"
                fontSize: Style.fontSizeS
                outlined: true
                onClicked: root.activatePreset(modelData)
              }
            }
          }
        }

        NText {
          Layout.fillWidth: true
          visible: root.presetActions.length === 0
          text: root.pluginApi?.tr("panel.noPresets")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
        }

        NDivider {
          Layout.fillWidth: true
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NButton {
            Layout.fillWidth: true
            text: root.pluginApi?.tr("panel.cancel")
            icon: "coffee-off"
            enabled: root.sessionActive
            outlined: true
            backgroundColor: Color.mError
            textColor: Color.mOnError
            onClicked: root.cancelSession()
          }

          NButton {
            Layout.fillWidth: true
            text: root.pluginApi?.tr("panel.openLauncher")
            icon: "search"
            onClicked: root.openLauncher()
          }
        }
      }
    }
  }
}
