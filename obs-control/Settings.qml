import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginL
  width: 560

  required property var pluginApi

  readonly property var defaults: root.pluginApi.manifest?.metadata?.defaultSettings ?? ({})
  readonly property var settings: root.pluginApi.pluginSettings ?? ({})
  readonly property var service: root.pluginApi.mainInstance
  readonly property bool durationLabelsSelected: root.valueBarLabelMode === "duration"

  property int valuePollIntervalMs: root.settings.pollIntervalMs ?? root.defaults.pollIntervalMs ?? 2500
  property string valueLeftClickAction: root.settings.leftClickAction ?? root.defaults.leftClickAction ?? "panel"
  property string valueLaunchBehavior: root.settings.launchBehavior ?? root.defaults.launchBehavior ?? "minimized-to-tray"
  property string valueBarLabelMode: root.settings.barLabelMode ?? root.defaults.barLabelMode ?? "short-label"
  property string valueVideosPath: root.settings.videosPath ?? root.defaults.videosPath ?? ""
  property string valueVideosOpener: root.settings.videosOpener ?? root.defaults.videosOpener ?? "xdg-open"
  property bool valueAutoCloseManagedObs: root.settings.autoCloseManagedObs ?? root.defaults.autoCloseManagedObs ?? true
  property bool valueOpenVideosAfterStop: root.settings.openVideosAfterStop ?? root.defaults.openVideosAfterStop ?? true
  property bool valueShowBarWhenRecording: root.settings.showBarWhenRecording ?? root.defaults.showBarWhenRecording ?? true
  property bool valueShowBarWhenReplay: root.settings.showBarWhenReplay ?? root.defaults.showBarWhenReplay ?? false
  property bool valueShowBarWhenStreaming: root.settings.showBarWhenStreaming ?? root.defaults.showBarWhenStreaming ?? true
  // Stored under the legacy showBarWhenReady key for settings compatibility.
  property bool valueAlwaysShowInBar: root.settings.showBarWhenReady ?? root.defaults.showBarWhenReady ?? true
  property bool valueShowControlCenterWhenRecording: root.settings.showControlCenterWhenRecording ?? root.defaults.showControlCenterWhenRecording ?? true
  property bool valueShowControlCenterWhenReplay: root.settings.showControlCenterWhenReplay ?? root.defaults.showControlCenterWhenReplay ?? true
  property bool valueShowControlCenterWhenStreaming: root.settings.showControlCenterWhenStreaming ?? root.defaults.showControlCenterWhenStreaming ?? true
  property bool valueShowControlCenterWhenReady: root.settings.showControlCenterWhenReady ?? root.defaults.showControlCenterWhenReady ?? false
  property bool valueShowElapsedInBar: root.settings.showElapsedInBar ?? root.defaults.showElapsedInBar ?? false

  function saveSettings() {
    const settings = root.pluginApi.pluginSettings

    settings.pollIntervalMs = root.valuePollIntervalMs
    settings.leftClickAction = root.valueLeftClickAction
    settings.launchBehavior = root.valueLaunchBehavior
    settings.barLabelMode = root.valueBarLabelMode
    settings.videosPath = root.valueVideosPath.trim()
    settings.videosOpener = root.valueVideosOpener.trim()
    settings.autoCloseManagedObs = root.valueAutoCloseManagedObs
    settings.openVideosAfterStop = root.valueOpenVideosAfterStop
    settings.showBarWhenRecording = root.valueShowBarWhenRecording
    settings.showBarWhenReplay = root.valueShowBarWhenReplay
    settings.showBarWhenStreaming = root.valueShowBarWhenStreaming
    settings.showBarWhenReady = root.valueAlwaysShowInBar
    settings.showControlCenterWhenRecording = root.valueShowControlCenterWhenRecording
    settings.showControlCenterWhenReplay = root.valueShowControlCenterWhenReplay
    settings.showControlCenterWhenStreaming = root.valueShowControlCenterWhenStreaming
    settings.showControlCenterWhenReady = root.valueShowControlCenterWhenReady
    settings.showElapsedInBar = root.valueShowElapsedInBar
    root.pluginApi.saveSettings()
  }

  NHeader {
    label: root.pluginApi.tr("settings.header.label")
    description: root.pluginApi.tr("settings.header.description")
  }

  NBox {
    visible: root.service?.websocketSupportMissing || root.service?.websocketConfigMissing
    Layout.fillWidth: true
    implicitHeight: warningColumn.implicitHeight + Style.marginXL

    ColumnLayout {
      id: warningColumn

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginXS

      NText {
        text: root.service?.websocketSupportMissing
              ? root.pluginApi.tr("settings.runtime.qt_websockets_missing_title")
              : root.pluginApi.tr("settings.runtime.websocket_config_missing_title")
        font.weight: Style.fontWeightSemiBold
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: root.service?.websocketSupportMissing
              ? root.pluginApi.tr("settings.runtime.qt_websockets_missing")
              : root.pluginApi.tr("settings.runtime.websocket_config_missing")
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: behaviorSection.implicitHeight + Style.marginXL

    ColumnLayout {
      id: behaviorSection

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: root.pluginApi.tr("settings.sections.behavior.label")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: root.pluginApi.tr("settings.sections.behavior.description")
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.left_click_action.label")
        description: root.pluginApi.tr("settings.left_click_action.description")
        model: [
          { key: "panel", name: root.pluginApi.tr("settings.left_click_action.options.open_controls") },
          { key: "toggle-record", name: root.pluginApi.tr("settings.left_click_action.options.toggle_recording") },
          { key: "toggle-stream", name: root.pluginApi.tr("settings.left_click_action.options.toggle_streaming") },
        ]
        currentKey: root.valueLeftClickAction
        minimumWidth: 220
        onSelected: key => root.valueLeftClickAction = key
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.launch_behavior.label")
        description: root.pluginApi.tr("settings.launch_behavior.description")
        model: [
          { key: "normal", name: root.pluginApi.tr("settings.launch_behavior.options.normal") },
          { key: "minimized-to-tray", name: root.pluginApi.tr("settings.launch_behavior.options.minimized_to_tray") },
        ]
        currentKey: root.valueLaunchBehavior
        minimumWidth: 220
        onSelected: key => root.valueLaunchBehavior = key
      }

      NSpinBox {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.poll_interval.label")
        description: root.pluginApi.tr("settings.poll_interval.description")
        from: 750
        to: 10000
        stepSize: 250
        value: root.valuePollIntervalMs
        onValueChanged: root.valuePollIntervalMs = value
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: barSection.implicitHeight + Style.marginXL

    ColumnLayout {
      id: barSection

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: root.pluginApi.tr("settings.sections.bar.label")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: root.pluginApi.tr("settings.sections.bar.description")
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.bar_label_mode.label")
        description: root.pluginApi.tr("settings.bar_label_mode.description")
        model: [
          { key: "icon-only", name: root.pluginApi.tr("settings.bar_label_mode.options.icon_only") },
          { key: "short-label", name: root.pluginApi.tr("settings.bar_label_mode.options.short_label") },
          { key: "duration", name: root.pluginApi.tr("settings.bar_label_mode.options.duration") },
        ]
        currentKey: root.valueBarLabelMode
        minimumWidth: 220
        onSelected: key => root.valueBarLabelMode = key
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.durationLabelsSelected
        label: root.pluginApi.tr("settings.show_elapsed_in_bar.label")
        description: root.pluginApi.tr("settings.show_elapsed_in_bar.description")
        checked: root.valueShowElapsedInBar
        onToggled: checked => root.valueShowElapsedInBar = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.always_show_in_bar.label")
        description: root.pluginApi.tr("settings.always_show_in_bar.description")
        checked: root.valueAlwaysShowInBar
        onToggled: checked => root.valueAlwaysShowInBar = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_bar_recording.label")
        description: root.pluginApi.tr("settings.show_bar_recording.description")
        checked: root.valueShowBarWhenRecording
        onToggled: checked => root.valueShowBarWhenRecording = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_bar_streaming.label")
        description: root.pluginApi.tr("settings.show_bar_streaming.description")
        checked: root.valueShowBarWhenStreaming
        onToggled: checked => root.valueShowBarWhenStreaming = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_bar_replay.label")
        description: root.pluginApi.tr("settings.show_bar_replay.description")
        checked: root.valueShowBarWhenReplay
        onToggled: checked => root.valueShowBarWhenReplay = checked
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: controlCenterSection.implicitHeight + Style.marginXL

    ColumnLayout {
      id: controlCenterSection

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: root.pluginApi.tr("settings.sections.control_center.label")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: root.pluginApi.tr("settings.sections.control_center.description")
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_control_center_ready.label")
        description: root.pluginApi.tr("settings.show_control_center_ready.description")
        checked: root.valueShowControlCenterWhenReady
        onToggled: checked => root.valueShowControlCenterWhenReady = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_control_center_recording.label")
        description: root.pluginApi.tr("settings.show_control_center_recording.description")
        checked: root.valueShowControlCenterWhenRecording
        onToggled: checked => root.valueShowControlCenterWhenRecording = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_control_center_streaming.label")
        description: root.pluginApi.tr("settings.show_control_center_streaming.description")
        checked: root.valueShowControlCenterWhenStreaming
        onToggled: checked => root.valueShowControlCenterWhenStreaming = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.show_control_center_replay.label")
        description: root.pluginApi.tr("settings.show_control_center_replay.description")
        checked: root.valueShowControlCenterWhenReplay
        onToggled: checked => root.valueShowControlCenterWhenReplay = checked
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: videosSection.implicitHeight + Style.marginXL

    ColumnLayout {
      id: videosSection

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: root.pluginApi.tr("settings.sections.videos.label")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: root.pluginApi.tr("settings.sections.videos.description")
      }

      NTextInput {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.videos_path.label")
        description: root.pluginApi.tr("settings.videos_path.description")
        placeholderText: "~/Videos"
        text: root.valueVideosPath
        onTextChanged: root.valueVideosPath = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.videos_opener.label")
        description: root.pluginApi.tr("settings.videos_opener.description")
        placeholderText: "xdg-open"
        text: root.valueVideosOpener
        onTextChanged: root.valueVideosOpener = text
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.open_videos_after_stop.label")
        description: root.pluginApi.tr("settings.open_videos_after_stop.description")
        checked: root.valueOpenVideosAfterStop
        onToggled: checked => root.valueOpenVideosAfterStop = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.auto_close_managed.label")
        description: root.pluginApi.tr("settings.auto_close_managed.description")
        checked: root.valueAutoCloseManagedObs
        onToggled: checked => root.valueAutoCloseManagedObs = checked
      }
    }
  }
}
