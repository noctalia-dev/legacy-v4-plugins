import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: 500 * Style.uiScaleRatio
  property real contentPreferredHeight: 680 * Style.uiScaleRatio

  anchors.fill: parent

  readonly property var main: pluginApi?.mainInstance
  readonly property bool configured: main?.isConfigured ?? false
  readonly property bool showHabits: pluginApi?.pluginSettings?.showHabits ?? false
  readonly property bool showChecklistItems: pluginApi?.pluginSettings?.showChecklistItems ?? false

  function closePanel() {
    if (pluginApi) pluginApi.withCurrentScreen(s => pluginApi.closePanel(s))
  }

  function relativeUpdateText() {
    if (!main?.lastFetchTimestamp) return "Not synced yet"
    var age = Math.floor(Date.now() / 1000) - main.lastFetchTimestamp
    var minutes = Math.floor(age / 60)
    if (minutes < 1) return "Updated just now"
    if (minutes < 60) return "Updated " + minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    return "Updated " + hours + "h ago"
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value))
  }

  function statRatio(value, maxValue) {
    var max = Number(maxValue || 0)
    if (max <= 0) return 0
    return clamp(Number(value || 0) / max, 0, 1)
  }

  function hpRatio() {
    return statRatio(main?.stats?.hp || 0, main?.stats?.maxHealth || 50)
  }

  function xpRatio() {
    return statRatio(main?.stats?.exp || 0, main?.stats?.toNextLevel || 1)
  }

  function mpRatio() {
    return statRatio(main?.stats?.mp || 0, main?.stats?.maxMP || 1)
  }

  function mpText() {
    if (!main?.stats || main.stats.mp === undefined) return "-- MP"
    return Math.max(0, Math.round(main.stats.mp)) + " MP"
  }

  function classText() {
    var habitClass = main?.stats?.class || ""
    if (!habitClass) return ""
    return habitClass.charAt(0).toUpperCase() + habitClass.slice(1)
  }

  function taskToneColor(task) {
    var value = Number(task?.value || 0)
    if (task?.type === "todo") return Color.mTertiary
    if (value < -10) return Color.mError
    if (value < -1) return Color.mTertiary
    if (value < 1) return Color.mSecondary
    return Color.mPrimary
  }

  function taskToneLabel(task) {
    var value = Number(task?.value || 0)
    if (value < -10) return "high risk"
    if (value < -1) return "weak"
    if (value < 1) return "neutral"
    if (value < 5) return "steady"
    return "strong"
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.mSurface

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      RowLayout {
        id: headerContent
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
          Layout.preferredWidth: 128 * Style.uiScaleRatio
          spacing: Style.marginS

          Rectangle {
            id: avatarFrame
            Layout.preferredWidth: 112 * Style.uiScaleRatio
            Layout.preferredHeight: 116 * Style.uiScaleRatio
            radius: Style.radiusS
            color: Qt.alpha(Color.mPrimary, 0.24)
            border.color: Color.mPrimary
            border.width: Style.uiScaleRatio * 2

            HabiticaAvatar {
              id: avatarImage
              anchors.fill: parent
              anchors.margins: 0
              user: root.main?.user || ({})
              stats: root.main?.stats || ({})
            }

            NIcon {
              anchors.centerIn: parent
              visible: !avatarImage.hasAvatarData
              icon: "sword"
              pointSize: Style.fontSizeXXL * 1.6
              color: Color.mPrimary
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "sword"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              Layout.fillWidth: true
              text: root.configured ? root.main.levelText().replace("Level", "Lv.") + (root.classText() ? " " + root.classText() : "") : "Lv. --"
              pointSize: Style.fontSizeS
              font.weight: Font.Bold
              color: Color.mOnSurface
              elide: Text.ElideRight
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              Layout.fillWidth: true
              text: root.configured ? root.main.displayName() : "Habitica"
              pointSize: Style.fontSizeXL
              font.weight: Font.Bold
              color: Color.mOnSurface
              elide: Text.ElideRight
            }

            NIconButton {
              icon: "refresh"
              enabled: root.configured && !root.main?.isLoading && !root.main?.isScoring
              tooltipText: pluginApi?.tr("panel.refreshTooltip")
              baseSize: Style.baseWidgetSize * 0.85
              onClicked: root.main.refresh()
            }

            NIconButton {
              icon: "x"
              tooltipText: pluginApi?.tr("panel.closeTooltip")
              baseSize: Style.baseWidgetSize * 0.85
              onClicked: root.closePanel()
            }
          }

          StatBar {
            Layout.fillWidth: true
            label: pluginApi?.tr("panel.health")
            value: root.main?.hpText() || "--"
            ratio: root.hpRatio()
            fillColor: Color.mError
          }

          StatBar {
            Layout.fillWidth: true
            label: pluginApi?.tr("panel.experience")
            value: root.main?.xpText() || "--"
            ratio: root.xpRatio()
            fillColor: Color.mPrimary
          }

          StatBar {
            Layout.fillWidth: true
            label: pluginApi?.tr("panel.mana")
            value: root.mpText()
            ratio: root.mpRatio()
            fillColor: Color.mSecondary
            visible: root.main?.stats?.mp !== undefined
          }

          RowLayout {
            Layout.fillWidth: true
            visible: root.configured
            spacing: Style.marginL

            CurrencyPill {
              icon: "coin"
              value: root.main?.goldText().replace(" gold", "") || "--"
              colorKey: Color.mTertiary
            }

            Item { Layout.fillWidth: true }

            NText {
              text: root.relativeUpdateText()
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }
      }

      Rectangle {
        visible: root.main?.hasError ?? false
        Layout.fillWidth: true
        implicitHeight: errorText.implicitHeight + Style.marginM * 2
        radius: Style.radiusM
        color: Qt.alpha(Color.mError, 0.12)
        border.color: Color.mError
        border.width: Style.uiScaleRatio

        NText {
          id: errorText
          anchors.fill: parent
          anchors.margins: Style.marginM
          text: root.main?.errorMessage || ""
          color: Color.mError
          pointSize: Style.fontSizeS
          wrapMode: Text.Wrap
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.mSurface

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          EmptyState {
            visible: !root.configured
            Layout.fillWidth: true
            icon: "user-circle"
            title: pluginApi?.tr("panel.credentialsRequired")
            description: pluginApi?.tr("panel.credentialsDescription")
          }

          EmptyState {
            visible: root.configured && root.main?.isLoading && (root.main?.visibleDailies.length || 0) === 0 && (root.main?.visibleTodos.length || 0) === 0
            Layout.fillWidth: true
            icon: "loader"
            title: pluginApi?.tr("panel.loadingTitle")
            description: pluginApi?.tr("panel.loadingDescription")
          }

          TaskSection {
            visible: root.configured
            Layout.fillWidth: true
            title: pluginApi?.tr("panel.today")
            emptyText: pluginApi?.tr("panel.noDailies")
            tasks: root.main?.visibleDailies || []
            kind: "daily"
            main: root.main
            showChecklistItems: root.showChecklistItems
          }

          TaskSection {
            visible: root.configured
            Layout.fillWidth: true
            title: pluginApi?.tr("panel.todos")
            emptyText: pluginApi?.tr("panel.noTodos")
            tasks: root.main?.visibleTodos || []
            kind: "todo"
            main: root.main
            showChecklistItems: root.showChecklistItems
          }

          TaskSection {
            visible: root.configured && root.showHabits
            Layout.fillWidth: true
            title: pluginApi?.tr("panel.habits")
            emptyText: pluginApi?.tr("panel.noHabits")
            tasks: root.main?.visibleHabits || []
            kind: "habit"
            main: root.main
            showChecklistItems: false
          }
        }
      }
    }
  }

  component StatBar: Rectangle {
    property string label
    property string value: ""
    property real ratio: 0
    property color fillColor: Color.mPrimary

    implicitHeight: statLayout.implicitHeight + Style.marginXS * 2
    radius: Style.radiusS
    color: "transparent"

    ColumnLayout {
      id: statLayout
      anchors.fill: parent
      anchors.margins: Style.marginXS
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: value
          pointSize: Style.fontSizeS
          font.weight: Font.Bold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: label
          pointSize: Style.fontSizeXS
          font.weight: Font.Bold
          color: Color.mOnSurfaceVariant
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 8 * Style.uiScaleRatio
        radius: height / 2
        color: Qt.alpha(Color.mOnSurface, 0.12)
        clip: true

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: parent.width * Math.max(0, Math.min(1, ratio))
          radius: parent.radius
          color: fillColor

          Behavior on width {
            NumberAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }

  component CurrencyPill: RowLayout {
    id: currencyRoot

    property string icon: ""
    property string value: ""
    property color colorKey: Color.mPrimary

    spacing: Style.marginXS

    Rectangle {
      Layout.preferredWidth: 22 * Style.uiScaleRatio
      Layout.preferredHeight: 22 * Style.uiScaleRatio
      radius: width / 2
      color: Qt.alpha(colorKey, 0.18)

      NIcon {
        anchors.centerIn: parent
        icon: currencyRoot.icon
        pointSize: Style.fontSizeS
        color: currencyRoot.colorKey
      }
    }

    NText {
      text: value
      pointSize: Style.fontSizeS
      font.weight: Font.Bold
      color: currencyRoot.colorKey
    }
  }

  component EmptyState: NBox {
    id: emptyRoot

    property string icon: "info-circle"
    property string title: ""
    property string description

    implicitHeight: emptyLayout.implicitHeight + Style.marginL

    ColumnLayout {
      id: emptyLayout
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NIcon {
        Layout.alignment: Qt.AlignHCenter
        icon: emptyRoot.icon
        pointSize: Style.fontSizeXXL
        color: Color.mOnSurfaceVariant
      }

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: emptyRoot.title
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
      }

      NText {
        Layout.fillWidth: true
        text: emptyRoot.description
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }
  }

  component TaskSection: ColumnLayout {
    property string title: ""
    property string emptyText: ""
    property var tasks: []
    property string kind: ""
    property var main: null
    property bool showChecklistItems: false

    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true

      NText {
        text: title
        pointSize: Style.fontSizeS
        font.weight: Font.Bold
        color: Color.mSecondary
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        implicitWidth: countText.implicitWidth + Style.marginS * 2
        implicitHeight: countText.implicitHeight + Style.marginXS * 2
        radius: implicitHeight / 2
        color: Qt.alpha(Color.mSecondary, 0.14)

        NText {
          id: countText
          anchors.centerIn: parent
          text: tasks.length.toString()
          pointSize: Style.fontSizeXS
          font.weight: Font.Bold
          color: Color.mSecondary
        }
      }
    }

    NBox {
      visible: tasks.length === 0
      Layout.fillWidth: true
      implicitHeight: emptyLabel.implicitHeight + Style.marginL

      NText {
        id: emptyLabel
        anchors.centerIn: parent
        text: emptyText
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }
    }

    Repeater {
      model: tasks

      Rectangle {
        id: taskCard
        Layout.fillWidth: true
        implicitHeight: taskContent.implicitHeight + Style.marginM * 2
        radius: Style.radiusM
        color: taskMouse.containsMouse ? Qt.alpha(root.taskToneColor(taskCard.task), 0.12) : Color.mSurface
        border.color: Qt.alpha(root.taskToneColor(taskCard.task), taskMouse.containsMouse ? 0.42 : 0.22)
        border.width: Style.uiScaleRatio

        property var task: modelData
        property string taskId: task?.id || task?._id || ""
        property color toneColor: root.taskToneColor(task)

        Behavior on color {
          ColorAnimation {
            duration: Style.animationFast
          }
        }

        Rectangle {
          id: controlRail
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 52 * Style.uiScaleRatio
          radius: Style.radiusM
          color: Qt.alpha(taskCard.toneColor, 0.82)

          Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.radius
            color: parent.color
          }

          NIconButton {
            anchors.centerIn: parent
            visible: kind !== "habit"
            enabled: main && !main.isScoring
            icon: taskCard.task?.completed ? "check-check" : "check"
            tooltipText: pluginApi?.tr("panel.complete")
            baseSize: Style.baseWidgetSize * 0.78
            colorBg: Qt.alpha(Color.mSurface, 0.78)
            colorFg: taskCard.toneColor
            colorBgHover: Color.mHover
            colorFgHover: Color.mOnHover
            onClicked: main.completeTask(taskCard.task)
          }

          NIconButton {
            anchors.centerIn: parent
            visible: kind === "habit" && !(taskCard.task?.up ?? true)
            enabled: false
            icon: "plus"
            tooltipText: pluginApi?.tr("panel.scoreUpDisabled")
            baseSize: Style.baseWidgetSize * 0.78
            colorBg: Qt.alpha(Color.mSurface, 0.26)
            colorFg: Qt.alpha(Color.mOnSurface, 0.42)
          }

          ColumnLayout {
            anchors.centerIn: parent
            visible: kind === "habit" && (taskCard.task?.up ?? true)
            spacing: Style.marginXS

            NIconButton {
              visible: taskCard.task?.up ?? true
              enabled: main && !main.isScoring
              icon: "plus"
              tooltipText: pluginApi?.tr("panel.scoreUp")
              baseSize: Style.baseWidgetSize * 0.58
              colorBg: Qt.alpha(Color.mSurface, 0.78)
              colorFg: taskCard.toneColor
              colorBgHover: Color.mHover
              colorFgHover: Color.mOnHover
              onClicked: main.scoreHabit(taskCard.task, "up")
            }

          }
        }

        Rectangle {
          id: rightControlRail
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: kind === "habit" ? 52 * Style.uiScaleRatio : 0
          visible: kind === "habit"
          radius: Style.radiusM
          color: (taskCard.task?.down ?? false) ? Qt.alpha(taskCard.toneColor, 0.82) : Qt.alpha(Color.mOnSurfaceVariant, 0.18)

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.radius
            color: parent.color
          }

          NIconButton {
            anchors.centerIn: parent
            enabled: main && !main.isScoring && (taskCard.task?.down ?? false)
            icon: "minus"
            tooltipText: (taskCard.task?.down ?? false) ? pluginApi?.tr("panel.scoreDown") : pluginApi?.tr("panel.scoreDownDisabled")
            baseSize: Style.baseWidgetSize * 0.78
            colorBg: Qt.alpha(Color.mSurface, enabled ? 0.78 : 0.16)
            colorFg: enabled ? taskCard.toneColor : Qt.alpha(Color.mOnSurface, 0.42)
            colorBgHover: Color.mHover
            colorFgHover: Color.mOnHover
            onClicked: main.scoreHabit(taskCard.task, "down")
          }
        }

        MouseArea {
          id: taskMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
          id: taskContent
          anchors.fill: parent
          anchors.leftMargin: controlRail.width + Style.marginM
          anchors.rightMargin: (rightControlRail.visible ? rightControlRail.width : 0) + Style.marginM
          anchors.topMargin: Style.marginM
          anchors.bottomMargin: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.uiScaleRatio * 2

              NText {
                Layout.fillWidth: true
                text: taskCard.task?.text || pluginApi?.tr("panel.untitledTask")
                pointSize: Style.fontSizeS
                font.weight: Font.Medium
                color: Color.mOnSurface
                wrapMode: Text.Wrap
              }

              NText {
                Layout.fillWidth: true
                visible: (taskCard.task?.notes || "") !== "" || (main?.taskSummary(taskCard.task) || "") !== ""
                text: (main?.taskSummary(taskCard.task) || "") || taskCard.task.notes
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }
            }

            Rectangle {
              implicitWidth: toneText.implicitWidth + Style.marginS * 2
              implicitHeight: toneText.implicitHeight + Style.marginXS * 2
              radius: implicitHeight / 2
              color: Qt.alpha(taskCard.toneColor, 0.14)

              NText {
                id: toneText
                anchors.centerIn: parent
                text: root.taskToneLabel(taskCard.task)
                pointSize: Style.fontSizeXS
                color: taskCard.toneColor
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            visible: showChecklistItems && taskCard.task?.checklist && taskCard.task.checklist.length > 0
            spacing: Style.uiScaleRatio * 2

            Repeater {
              model: taskCard.task?.checklist || []

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NIconButton {
                  enabled: main && !main.isScoring
                  icon: modelData.completed ? "checkbox" : "square"
                  tooltipText: pluginApi?.tr("panel.toggleChecklist")
                  baseSize: Style.baseWidgetSize * 0.55
                  onClicked: main.scoreChecklistItem(taskCard.task, modelData)
                }

                NText {
                  Layout.fillWidth: true
                  text: modelData.text || ""
                  pointSize: Style.fontSizeXS
                  color: modelData.completed ? Color.mOnSurfaceVariant : Color.mOnSurface
                  font.strikeout: modelData.completed
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }
    }
  }
}
