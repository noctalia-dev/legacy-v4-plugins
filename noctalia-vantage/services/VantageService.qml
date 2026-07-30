import QtQuick
import qs.Commons

Item {
    id: root
    visible: false

    property var pluginApi: null

    // ===== STATE =====
    property bool available: fan.available || conservation.available || fnLock.available

    // ===== SYSFS PROPERTIES =====
    readonly property alias fan: _fan
    readonly property alias conservation: _conservation
    readonly property alias fnLock: _fnLock
    readonly property alias alwaysOnUSB: _alwaysOnUSB
    readonly property alias superKey: _superKey
    readonly property alias touchpad: _touchpad
    readonly property alias fastCharge: _fastcharge
    readonly property alias overdrive: _overdrive
    readonly property alias hybrid: _hybrid // TODO: reboot after applying changes

    readonly property var controls: [fan, conservation, fnLock, alwaysOnUSB, superKey, touchpad, fastCharge, overdrive, hybrid]

    readonly property var fanModes: ({
            SuperSilent: 0,
            Standard: 1,
            DustCleaning: 2,
            EfficientThermalDissipation: 4
        })

    component IdeapadSysfsProperty: SysfsProperty {
        required property string file
        readonly property string basePath: "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00"

        path: basePath + "/" + file
    }

    component LegionSysfsProperty: SysfsProperty {
        required property string file
        readonly property string basePath: "/sys/bus/platform/drivers/legion/PNP0C09:00"

        path: basePath + "/" + file
    }

    IdeapadSysfsProperty {
        id: _fan
        file: "fan_mode"
        label: "fan mode"
        validValues: [root.fanModes.SuperSilent, root.fanModes.Standard, root.fanModes.DustCleaning, root.fanModes.EfficientThermalDissipation]
        parser: function (raw) {
            const v = parseInt(raw?.trim());
            if (isNaN(v)) {
                Logger.w("NoctaliaVantage", "Invalid fan value:", raw);
                return undefined;
            }
            const bits = v & 7; // Extarct last 3 bits
            if (this.validValues.includes(bits)) {
                return bits;
            }

            return root.fanModes.SuperSilent;
        }
    }

    IdeapadSysfsProperty {
        id: _conservation
        file: "conservation_mode"
        label: "conservation mode"
    }

    IdeapadSysfsProperty {
        id: _fnLock
        file: "fn_lock"
        label: "fn lock"
    }

    IdeapadSysfsProperty {
        id: _alwaysOnUSB
        file: "usb_charging"
        label: "always on usb"
    }

    LegionSysfsProperty {
        id: _superKey
        file: "winKey"
        label: "super key"
    }

    LegionSysfsProperty {
        id: _touchpad
        file: "touchpad"
        label: "touchpad"
    }

    LegionSysfsProperty {
        id: _fastcharge
        file: "rapidcharge"
        label: "fast charge"
    }

    LegionSysfsProperty {
        id: _overdrive
        file: "overdrive"
        label: "overdrive"
    }

    LegionSysfsProperty {
        id: _hybrid
        file: "gsync"
        label: "hybrid graphics"
    }

    // ===== INIT =====
    Component.onCompleted: {
        Logger.i("NoctaliaVantage", "Service starting...");
        for (let c of controls) {
            c.checkAvailability();
        }
    }

    function refresh() {
        if (!available) {
            Logger.w("NoctaliaVantage", "Refresh skipped: service not available");
            return;
        }
        Logger.i("NoctaliaVantage", "Refreshing values...");
        for (let c of controls) {
            c.reload();
        }
    }
}
