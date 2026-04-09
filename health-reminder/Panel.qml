import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 460 * Style.uiScaleRatio
  property real contentPreferredHeight: 460 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  anchors.fill: parent

  function badgeWidth(textItem) {
    return textItem.implicitWidth + Style.marginS * 2;
  }

  function badgeHeight(textItem) {
    return textItem.implicitHeight + Style.marginXS * 2;
  }

  function badgeHeightWithIcon(textItem) {
    return Math.max(textItem.implicitHeight, Style.fontSizeXS) + Style.marginXS * 2;
  }

  function countdownBadgeBackground(seconds, enabled) {
    if (!enabled) return Qt.alpha(Color.mOutline, 0.18);
    if (seconds <= 15 * 60) return Qt.alpha(Color.mError, 0.18);
    if (seconds <= 60 * 60) return Qt.alpha(Color.mPrimary, 0.18);
    return Qt.alpha(Color.mSecondary, 0.18);
  }

  function countdownBadgeForeground(seconds, enabled) {
    if (!enabled) return Color.mOnSurfaceVariant;
    if (seconds <= 15 * 60) return Color.mError;
    if (seconds <= 60 * 60) return Color.mPrimary;
    return Color.mSecondary;
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NScrollView {
        id: remindersScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
          id: contentColumn
          width: remindersScrollView.availableWidth
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("panel.system.title")
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
            }

            NIconButton {
              icon: mainInstance?.remindersPaused ? "media-play" : "media-pause"
              tooltipText: mainInstance?.remindersPaused ? pluginApi?.tr("panel.resume") : pluginApi?.tr("panel.pause")
              onClicked: {
                if (mainInstance) {
                  mainInstance.setPaused(!mainInstance.remindersPaused);
                }
              }
            }

            NIconButton {
              icon: "refresh"
              tooltipText: pluginApi?.tr("panel.reset")
              onClicked: mainInstance?.resetReminderTimers()
            }

            NIconButton {
              icon: "settings"
              tooltipText: pluginApi?.tr("panel.openSettings")
              onClicked: {
                const screen = pluginApi?.panelOpenScreen;
                if (screen && pluginApi?.manifest) {
                  pluginApi.closePanel(screen);
                  Qt.callLater(function () {
                    BarService.openPluginSettings(screen, pluginApi.manifest);
                  });
                }
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: sedentaryContent.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: sedentaryContent
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                id: sedentaryRow
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: "armchair"
                  pointSize: Style.fontSizeL
                  color: mainInstance?.sedentaryEnabled ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                NText {
                  text: pluginApi?.tr("panel.sedentary.title")
                  color: Color.mOnSurface
                  font.weight: Style.fontWeightBold
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                Rectangle {
                  visible: mainInstance?.sedentaryEnabled ?? false
                  color: Qt.alpha(Color.mPrimary, 0.14)
                  radius: Style.radiusXS
                  implicitWidth: root.badgeWidth(sedentaryIntervalBadgeText)
                  implicitHeight: root.badgeHeight(sedentaryIntervalBadgeText)

                  NText {
                    id: sedentaryIntervalBadgeText
                    anchors.centerIn: parent
                    text: String(mainInstance?.sedentaryIntervalMinutes || 0) + "m"
                    color: Color.mPrimary
                    font.pointSize: Style.fontSizeXS
                    font.weight: Font.Medium
                  }
                }

                Rectangle {
                  color: mainInstance?.sedentaryEnabled
                    ? root.countdownBadgeBackground(mainInstance?.sedentaryRemainingSeconds || 0, true)
                    : root.countdownBadgeBackground(0, false)
                  radius: Style.radiusXS
                  implicitWidth: root.badgeWidth(sedentaryStateBadgeText)
                  implicitHeight: root.badgeHeight(sedentaryStateBadgeText)

                  NText {
                    id: sedentaryStateBadgeText
                    anchors.centerIn: parent
                    text: mainInstance?.sedentaryEnabled
                      ? mainInstance?.formatDuration(mainInstance?.sedentaryRemainingSeconds || 0)
                      : pluginApi?.tr("panel.badge.off")
                    color: root.countdownBadgeForeground(mainInstance?.sedentaryRemainingSeconds || 0, mainInstance?.sedentaryEnabled ?? false)
                    font.pointSize: Style.fontSizeXS
                    font.weight: Font.Medium
                  }
                }

                NIconButton {
                  visible: mainInstance?.debugMode ?? false
                  icon: "armchair"
                  tooltipText: pluginApi?.tr("panel.testSedentary")
                  onClicked: mainInstance?.sendSedentaryReminder(true)
                }

                NToggle {
                  checked: mainInstance?.sedentaryEnabled ?? false
                  onToggled: checked => mainInstance?.setReminderEnabled("sedentary", checked)
                }
              }

              NText {
                visible: ((mainInstance?.sedentaryMessage || "").trim() !== "")
                text: mainInstance?.sedentaryMessage || ""
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: hydrationContent.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: hydrationContent
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                id: hydrationRow
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: "bottle"
                  pointSize: Style.fontSizeL
                  color: mainInstance?.hydrationEnabled ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                NText {
                  text: pluginApi?.tr("panel.hydration.title")
                  color: Color.mOnSurface
                  font.weight: Style.fontWeightBold
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                Rectangle {
                  visible: mainInstance?.hydrationEnabled ?? false
                  color: Qt.alpha(Color.mPrimary, 0.14)
                  radius: Style.radiusXS
                  implicitWidth: root.badgeWidth(hydrationIntervalBadgeText)
                  implicitHeight: root.badgeHeight(hydrationIntervalBadgeText)

                  NText {
                    id: hydrationIntervalBadgeText
                    anchors.centerIn: parent
                    text: String(mainInstance?.hydrationIntervalMinutes || 0) + "m"
                    color: Color.mPrimary
                    font.pointSize: Style.fontSizeXS
                    font.weight: Font.Medium
                  }
                }

                Rectangle {
                  color: mainInstance?.hydrationEnabled
                    ? root.countdownBadgeBackground(mainInstance?.hydrationRemainingSeconds || 0, true)
                    : root.countdownBadgeBackground(0, false)
                  radius: Style.radiusXS
                  implicitWidth: root.badgeWidth(hydrationStateBadgeText)
                  implicitHeight: root.badgeHeight(hydrationStateBadgeText)

                  NText {
                    id: hydrationStateBadgeText
                    anchors.centerIn: parent
                    text: mainInstance?.hydrationEnabled
                      ? mainInstance?.formatDuration(mainInstance?.hydrationRemainingSeconds || 0)
                      : pluginApi?.tr("panel.badge.off")
                    color: root.countdownBadgeForeground(mainInstance?.hydrationRemainingSeconds || 0, mainInstance?.hydrationEnabled ?? false)
                    font.pointSize: Style.fontSizeXS
                    font.weight: Font.Medium
                  }
                }

                NIconButton {
                  visible: mainInstance?.debugMode ?? false
                  icon: "bottle"
                  tooltipText: pluginApi?.tr("panel.testHydration")
                  onClicked: mainInstance?.sendHydrationReminder(true)
                }

                NToggle {
                  checked: mainInstance?.hydrationEnabled ?? false
                  onToggled: checked => mainInstance?.setReminderEnabled("hydration", checked)
                }
              }

              NText {
                visible: ((mainInstance?.hydrationMessage || "").trim() !== "")
                text: mainInstance?.hydrationMessage || ""
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }
          }

          NText {
            text: pluginApi?.tr("panel.medication.title")
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mOnSurfaceVariant
            visible: (mainInstance?.activeMedicationReminders ?? []).length > 0
          }

          Repeater {
            model: mainInstance?.activeMedicationReminders ?? []

            delegate: NBox {
              required property int index
              required property var modelData

              Layout.fillWidth: true
              Layout.preferredHeight: medicationContent.implicitHeight + Style.marginM * 2

              ColumnLayout {
                id: medicationContent
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                RowLayout {
                  id: medicationRow
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NIcon {
                  icon: "pill-filled"
                    pointSize: Style.fontSizeL
                    color: modelData.enabled ? Color.mPrimary : Color.mOnSurfaceVariant
                  }

                  NText {
                    text: modelData.name
                    color: Color.mOnSurface
                    font.weight: Style.fontWeightBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    color: Qt.alpha(Color.mPrimary, 0.14)
                    radius: Style.radiusXS
                    implicitWidth: medicationTimeBadge.implicitWidth + Style.marginS * 2
                    implicitHeight: root.badgeHeightWithIcon(medicationTimeBadgeText)

                    Row {
                      id: medicationTimeBadge
                      anchors.centerIn: parent
                      spacing: Style.marginXS

                      NIcon {
                        icon: "alarm"
                        pointSize: Style.fontSizeXS
                        color: Color.mPrimary
                      }

                      NText {
                        id: medicationTimeBadgeText
                        text: modelData.time
                        color: Color.mPrimary
                        font.pointSize: Style.fontSizeXS
                        font.weight: Font.Medium
                      }
                    }
                  }

                  Rectangle {
                    visible: !modelData.enabled
                    color: root.countdownBadgeBackground(0, false)
                    radius: Style.radiusXS
                    implicitWidth: root.badgeWidth(medicationDisabledBadgeText)
                    implicitHeight: root.badgeHeight(medicationDisabledBadgeText)

                    NText {
                      id: medicationDisabledBadgeText
                      anchors.centerIn: parent
                      text: pluginApi?.tr("panel.badge.off")
                      color: Color.mOnSurfaceVariant
                      font.pointSize: Style.fontSizeXS
                      font.weight: Font.Medium
                    }
                  }

                  NIconButton {
                    visible: mainInstance?.debugMode ?? false
                    icon: "pill-filled"
                    tooltipText: pluginApi?.tr("panel.testMedication")
                    onClicked: mainInstance?.sendMedicationReminder(modelData, true)
                  }

                  NToggle {
                    checked: modelData.enabled
                    onToggled: checked => mainInstance?.setMedicationReminderEnabled(index, checked)
                  }
                }

                NText {
                  visible: (modelData.message || "").trim() !== ""
                  text: modelData.message || ""
                  color: Color.mOnSurfaceVariant
                  pointSize: Style.fontSizeS
                  wrapMode: Text.Wrap
                  Layout.fillWidth: true
                }
              }
            }
          }

          NText {
            visible: (mainInstance?.activeMedicationReminders ?? []).length === 0
            text: pluginApi?.tr("panel.medication.empty")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }
        }
      }

    }
  }
}
