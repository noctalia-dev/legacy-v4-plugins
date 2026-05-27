import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 320 * Style.uiScaleRatio
  property real contentPreferredHeight: contentCol.implicitHeight + Style.marginM * 2
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool allowAttach: true
  readonly property bool active: mainInstance ? mainInstance.active : false

  // Selection state. While a session is active, the panel snapshots the
  // session's values on open/(re)activation; clicking a button locally
  // mutates these and either silently reconfigures (if active) or serves
  // as the start arg (if off).
  property int selectedMinutes: _initialSelectedMinutes()
  property string selectedScope: root.active
    ? mainInstance.scope
    : (mainInstance?.defaultScope ?? "partial")
  readonly property bool selectedScopeIsFull: selectedScope === "full"

  Connections {
    target: mainInstance
    function onActiveChanged() {
      if (mainInstance.active) {
        root.selectedScope = mainInstance.scope;
        root.selectedMinutes = root._minutesFromState();
      }
    }
  }

  function _initialSelectedMinutes() {
    if (root.active) return _minutesFromState();
    return mainInstance?.durations?.[0] ?? 30;
  }

  function _minutesFromState() {
    if (mainInstance.endEpoch === null) return -1;  // unlimited
    const list = mainInstance.durations ?? [];
    const label = mainInstance.durationLabel;
    for (const m of list) if (mainInstance.formatLabel(m * 60) === label) return m;
    return list[0] ?? 30;
  }

  function _onDurationClicked(minutes) {
    root.selectedMinutes = minutes;
    if (root.active) {
      const secs = (minutes === -1) ? -1 : minutes * 60;
      mainInstance.start(secs, root.selectedScope);
    }
  }

  function _onScopeToggled(keepDisplayAwake) {
    const newScope = keepDisplayAwake ? "full" : "partial";
    root.selectedScope = newScope;
    if (!root.active) return;
    // Preserve remaining time; fall back to the selected duration if the
    // poll's remainingSeconds is 0 (`timeout 0s` would mean unlimited).
    let dur;
    if (mainInstance.endEpoch === null) {
      dur = -1;
    } else if (mainInstance.remainingSeconds >= 1) {
      dur = mainInstance.remainingSeconds;
    } else {
      dur = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
    }
    mainInstance.start(dur, newScope);
  }

  function _onMainToggleClicked() {
    if (root.active) {
      mainInstance.off();
    } else {
      const secs = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
      mainInstance.start(secs, root.selectedScope);
    }
  }

  Item {
    id: panelContainer
    anchors.fill: parent

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      // ───────────── Header ─────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: root.active ? "coffee" : "coffee-off"
          pointSize: Style.fontSizeXL
          color: root.active
            ? (mainInstance.scope === "full" ? Color.mPrimary : Color.mSecondary)
            : Color.mOnSurfaceVariant
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }
          NText {
            text: {
              if (!root.active) return pluginApi?.tr("panel.off");
              const key = mainInstance.scope === "full"
                ? "panel.remaining-display-on"
                : "panel.remaining-display-may-sleep";
              return pluginApi?.tr(key, { time: mainInstance.formatRemaining() });
            }
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      // ───────────── Duration grid ─────────────
      GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        columns: 3
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginXS

        Repeater {
          model: {
            const base = (mainInstance?.durations ?? []).slice();
            const arr = base.map(m => ({ minutes: m, label: mainInstance.formatLabel(m * 60) }));
            if (mainInstance?.includeUnlimited) arr.push({ minutes: -1, label: pluginApi?.tr("panel.unlimited") });
            return arr;
          }
          delegate: NButton {
            Layout.fillWidth: true
            text: modelData.label
            fontSize: Style.fontSizeM
            readonly property bool isSelected: modelData.minutes === root.selectedMinutes
            outlined: !isSelected
            backgroundColor: root.selectedScopeIsFull ? Color.mPrimary : Color.mSecondary
            textColor: root.selectedScopeIsFull ? Color.mOnPrimary : Color.mOnSecondary
            onClicked: root._onDurationClicked(modelData.minutes)
          }
        }
      }

      // ───────────── Keep-display-awake toggle ─────────────
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        spacing: Style.marginS

        Item {
          readonly property real iconSlot: Style.fontSizeXL * 1.4
          Layout.preferredWidth: iconSlot
          Layout.preferredHeight: iconSlot
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            anchors.centerIn: parent
            icon: "sun"
            pointSize: Style.fontSizeXL
            color: Color.mPrimary
            opacity: root.selectedScopeIsFull ? 1.0 : 0.0
            rotation: root.selectedScopeIsFull ? 0 : -90
            scale: root.selectedScopeIsFull ? 1.0 : 0.6
            Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
          }
          NIcon {
            anchors.centerIn: parent
            icon: "moon"
            pointSize: Style.fontSizeXL
            color: Color.mSecondary
            opacity: root.selectedScopeIsFull ? 0.0 : 1.0
            rotation: root.selectedScopeIsFull ? 90 : 0
            scale: root.selectedScopeIsFull ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
          }
        }

        NToggle {
          Layout.fillWidth: true
          label: pluginApi?.tr("panel.keep-display.label")
          description: pluginApi?.tr("panel.keep-display.desc")
          checked: root.selectedScopeIsFull
          onToggled: checked => root._onScopeToggled(checked)
        }
      }

      // ───────────── Bottom action row ─────────────
      // Anchor-based instead of RowLayout: avoids the per-frame layout
      // reflow that made `Layout.fillWidth` + sibling preferredWidth
      // animation feel laggy. Both buttons drive width directly via
      // bindings + Behavior, animated on the render thread.
      Item {
        id: actionRow
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.preferredHeight: mainBtn.implicitHeight

        readonly property bool extendShown: root.active && mainInstance.endEpoch !== null
        readonly property real halfWidth: (width - Style.marginS) / 2

        NButton {
          id: extendBtn
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: actionRow.halfWidth
          height: implicitHeight
          opacity: actionRow.extendShown ? 1.0 : 0.0
          enabled: actionRow.extendShown
          text: pluginApi?.tr("panel.extend", { minutes: mainInstance?.quickExtendMinutes ?? 30 })
          icon: "clock-plus"
          outlined: true
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: mainInstance.extend((mainInstance.quickExtendMinutes ?? 30) * 60)

          Behavior on opacity {
            NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutCubic }
          }
        }

        // When inactive, the tint mirrors the bar pill so the user can
        // preview which scope the button is about to activate.
        NButton {
          id: mainBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: actionRow.extendShown ? actionRow.halfWidth : actionRow.width
          height: implicitHeight
          text: pluginApi?.tr(root.active ? "panel.turn-off" : "panel.turn-on")
          icon: "power"
          backgroundColor: root.active
            ? Color.mError
            : (root.selectedScopeIsFull ? Color.mPrimary : Color.mSecondary)
          textColor: root.active
            ? Color.mOnError
            : (root.selectedScopeIsFull ? Color.mOnPrimary : Color.mOnSecondary)
          onClicked: root._onMainToggleClicked()

          // Suppress one-shot animation on initial panel open (width: 0
          // → final). Once parent.width is non-zero we're past the
          // initial layout pass and subsequent toggles animate normally.
          Behavior on width {
            enabled: actionRow.width > 0
            NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutCubic }
          }
        }
      }
    }
  }
}
