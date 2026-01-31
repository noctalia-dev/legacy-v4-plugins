import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Io

ColumnLayout {
    id: root

    property var pluginApi: null
    property var service: pluginApi?.mainInstance?.service

    property string editBatteryDevice: pluginApi?.pluginSettings?.batteryDevice || service.batteries[0] || pluginApi?.manifest?.metadata?.defaultSettings?.batteryDevice || "/sys/class/power_supply/BAT0"

    spacing: Style.marginL

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.battery-device") || "Battery Device"
        description: pluginApi?.tr("settings.battery-device-desc") || "Select the battery to configure it's threshold"

        model: service.batteries.map(path => ({
                    key: path,
                    name: `${modelNameOf(path)} (${path.split("/").slice(-1)})`
                }))

        currentKey: root.editBatteryDevice
        onSelected: key => root.editBatteryDevice = key
    }

    function modelNameOf(battery) {
        modelNameView.path = `${battery}/model_name`;
        modelNameView.reload();
        modelNameView.waitForJob();
        return modelNameView.text().trim();
    }

    FileView {
        id: modelNameView
        path: `${pluginApi?.pluginSettings?.batteryDevice || service.batteries[0]}/model_name`
        printErrors: false
    }

    function saveSettings() {
        pluginApi.pluginSettings.batteryDevice = root.editBatteryDevice;
        pluginApi.saveSettings();
        service.refresh();
        Logger.i("BatteryThreshold", "Current battery: " + pluginApi.pluginSettings.batteryDevice);
    }
}
