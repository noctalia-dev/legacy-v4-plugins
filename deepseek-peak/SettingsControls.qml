import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Settings controls embedded by Settings.qml (Plugins window). The panel is
// info-only by design, so this is the single settings surface.
ColumnLayout {
    id: root
    property var pluginApi: null

    property string editDisplayMode: (pluginApi?.pluginSettings?.displayMode || pluginApi?.manifest?.metadata?.defaultSettings?.displayMode || "compact")
    property color editOffPeakColor: (pluginApi?.pluginSettings?.offPeakColor || pluginApi?.manifest?.metadata?.defaultSettings?.offPeakColor || "#4ade80")
    property color editPeakColor: (pluginApi?.pluginSettings?.peakColor || pluginApi?.manifest?.metadata?.defaultSettings?.peakColor || "#f87171")
    property color editDriftColor: (pluginApi?.pluginSettings?.driftColor || pluginApi?.manifest?.metadata?.defaultSettings?.driftColor || "#fbbf24")
    property bool editShowTooltip: (pluginApi?.pluginSettings?.showTooltip ?? pluginApi?.manifest?.metadata?.defaultSettings?.showTooltip ?? true)
    property bool editAutoCheck: (pluginApi?.pluginSettings?.autoCheck ?? pluginApi?.manifest?.metadata?.defaultSettings?.autoCheck ?? true)
    property bool editOfflineOnly: (pluginApi?.pluginSettings?.offlineOnly ?? pluginApi?.manifest?.metadata?.defaultSettings?.offlineOnly ?? false)
    property string editCheckIntervalH: String(pluginApi?.pluginSettings?.checkIntervalH ?? pluginApi?.manifest?.metadata?.defaultSettings?.checkIntervalH ?? 6)
    property string editCustomSourceUrl: (pluginApi?.pluginSettings?.customSourceUrl ?? pluginApi?.manifest?.metadata?.defaultSettings?.customSourceUrl ?? "")
    property string editWeekendMode: (pluginApi?.pluginSettings?.weekendMode || pluginApi?.manifest?.metadata?.defaultSettings?.weekendMode || "beijing-anchored")

    spacing: Style.marginM

    function t(key, params) {
        return (pluginApi && pluginApi.tr) ? pluginApi.tr(key, params) : key;
    }

    NLabel {
        label: root.t("settings.displayMode.label")
        description: root.t("settings.displayMode.description")
    }
    NComboBox {
        Layout.fillWidth: true
        model: [
            {key: "compact", name: root.t("settings.displayMode.compact")},
            {key: "icon", name: root.t("settings.displayMode.icon")},
            {key: "full", name: root.t("settings.displayMode.full")}
        ]
        currentKey: root.editDisplayMode
        onSelected: function (key) { root.editDisplayMode = key; }
    }

    NLabel {
        label: root.t("settings.offPeakColor.label")
        description: root.t("settings.offPeakColor.description")
    }
    NColorPicker {
        Layout.preferredWidth: Style.sliderWidth
        Layout.preferredHeight: Style.baseWidgetSize
        selectedColor: root.editOffPeakColor
        onColorSelected: function (color) {
            root.editOffPeakColor = color;
        }
    }

    NLabel {
        label: root.t("settings.peakColor.label")
        description: root.t("settings.peakColor.description")
    }
    NColorPicker {
        Layout.preferredWidth: Style.sliderWidth
        Layout.preferredHeight: Style.baseWidgetSize
        selectedColor: root.editPeakColor
        onColorSelected: function (color) {
            root.editPeakColor = color;
        }
    }

    NLabel {
        label: root.t("settings.driftColor.label")
        description: root.t("settings.driftColor.description")
    }
    NColorPicker {
        Layout.preferredWidth: Style.sliderWidth
        Layout.preferredHeight: Style.baseWidgetSize
        selectedColor: root.editDriftColor
        onColorSelected: function (color) {
            root.editDriftColor = color;
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: root.t("settings.showTooltip.label")
        description: root.t("settings.showTooltip.description")
        checked: root.editShowTooltip
        onToggled: function (checked) { root.editShowTooltip = checked; }
    }
    NToggle {
        Layout.fillWidth: true
        label: root.t("settings.autoCheck.label")
        description: root.t("settings.autoCheck.description")
        checked: root.editAutoCheck
        onToggled: function (checked) { root.editAutoCheck = checked; }
    }
    NToggle {
        Layout.fillWidth: true
        label: root.t("settings.offlineOnly.label")
        description: root.t("settings.offlineOnly.description")
        checked: root.editOfflineOnly
        onToggled: function (checked) { root.editOfflineOnly = checked; }
    }

    NTextInput {
        Layout.fillWidth: true
        label: root.t("settings.checkIntervalH.label")
        description: root.t("settings.checkIntervalH.description")
        text: root.editCheckIntervalH
        onTextChanged: root.editCheckIntervalH = text
    }
    NTextInput {
        Layout.fillWidth: true
        label: root.t("settings.customSourceUrl.label")
        description: root.t("settings.customSourceUrl.description")
        placeholderText: root.t("settings.customSourceUrl.placeholder")
        text: root.editCustomSourceUrl
        onTextChanged: root.editCustomSourceUrl = text
    }

    NLabel {
        label: root.t("settings.weekendMode.label")
        description: root.t("settings.weekendMode.description")
    }
    NComboBox {
        Layout.fillWidth: true
        model: [
            {key: "beijing-anchored", name: root.t("settings.weekendMode.beijing")},
            {key: "utc", name: root.t("settings.weekendMode.utc")}
        ]
        currentKey: root.editWeekendMode
        onSelected: function (key) { root.editWeekendMode = key; }
    }

    // Collect without persisting; the host (Settings dialog) writes the result
    // into pluginSettings itself.
    function collectSettings() {
        return {
            displayMode: root.editDisplayMode,
            offPeakColor: root.editOffPeakColor.toString(),
            peakColor: root.editPeakColor.toString(),
            driftColor: root.editDriftColor.toString(),
            showTooltip: root.editShowTooltip,
            autoCheck: root.editAutoCheck,
            offlineOnly: root.editOfflineOnly,
            checkIntervalH: parseInt(root.editCheckIntervalH, 10) || 6,
            customSourceUrl: root.editCustomSourceUrl,
            weekendMode: root.editWeekendMode
        };
    }
}
