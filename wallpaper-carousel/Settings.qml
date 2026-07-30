import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Noctalia settings page
ColumnLayout {
    id: root
    spacing: 12

    property var pluginApi: null
    property var s: JSON.parse(
        JSON.stringify(pluginApi?.pluginSettings ??
        pluginApi?.manifest?.metadata?.defaultSettings ?? {})
    )

    function save() {
        pluginApi.pluginSettings = s;
        pluginApi.saveSettings();
    }

    // ── Reusable slider row ───────────────────────────────────────────────────
    component SettingSlider: ColumnLayout {
        id: sl
        property string label: ""
        property string description: ""
        property string key: ""
        property real min: 0
        property real max: 100
        property real defaultValue: 0
        property string unit: ""

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Label { text: sl.label; font.bold: true; Layout.fillWidth: true }
            Label {
                text: Math.round(root.s[sl.key] ?? sl.defaultValue) + sl.unit
                font.pixelSize: 12; opacity: 0.7
            }
        }
        Slider {
            Layout.fillWidth: true
            from: sl.min; to: sl.max; stepSize: 1
            value: root.s[sl.key] ?? sl.defaultValue
            onMoved: { root.s[sl.key] = Math.round(value); root.save(); }
        }
        Label {
            text: sl.description
            font.pixelSize: 12; opacity: 0.6; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }
    }

    // ── Reusable combo row ────────────────────────────────────────────────────
    component SettingCombo: ColumnLayout {
        id: cb
        property string label: ""
        property string description: ""
        property string key: ""
        property var options: []
        property string defaultValue: ""

        Layout.fillWidth: true
        spacing: 2

        Label { text: cb.label; font.bold: true }
        ComboBox {
            Layout.fillWidth: true
            model: cb.options
            textRole: "text"
            valueRole: "value"
            currentIndex: {
                const v = root.s[cb.key] ?? cb.defaultValue;
                for (let i = 0; i < cb.options.length; i++)
                    if (cb.options[i].value === v) return i;
                return 0;
            }
            onActivated: { root.s[cb.key] = model[currentIndex].value; root.save(); }
        }
        Label {
            text: cb.description
            font.pixelSize: 12; opacity: 0.6; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }
    }

    // ── General ───────────────────────────────────────────────────────────────
    Label { text: "General"; font.bold: true; font.pixelSize: 14 }

    Label { text: "Wallpaper Directory"; font.bold: true }
    TextField {
        Layout.fillWidth: true
        placeholderText: "/home/user/Pictures/Wallpapers"
        text: root.s.wallpaperDirectory ?? ""
        onTextChanged: { root.s.wallpaperDirectory = text; root.save(); }
    }
    Label {
        text: "Override the wallpaper directory. Leave empty to follow the current wallpaper's directory."
        font.pixelSize: 12; opacity: 0.6; wrapMode: Text.WordWrap; Layout.fillWidth: true
    }

    SettingCombo {
        label: "Carousel Mode"
        description: "Standard stops at the edges. Wrap loops the index. Infinite shows a seamless repeating view."
        key: "carouselMode"; defaultValue: "wrap"
        options: [
            { text: "Standard", value: "standard" },
            { text: "Wrap",     value: "wrap"     },
            { text: "Infinite", value: "infinite" }
        ]
    }

    // ── Visual ────────────────────────────────────────────────────────────────
    Label { text: "Visual"; font.bold: true; font.pixelSize: 14; Layout.topMargin: 8 }

    SettingSlider {
        label: "Background Dimming"; description: "Opacity of the dark overlay behind the carousel."
        key: "overlayOpacity"; min: 0; max: 100; defaultValue: 80; unit: "%"
    }

    SettingSlider {
        label: "Border Width"; description: "Width of the skewed border around thumbnails."
        key: "borderWidth"; min: 0; max: 20; defaultValue: 3; unit: "px"
    }

    SettingSlider {
        label: "Corner Radius"; description: "Corner radius of thumbnails. Set to 0 to disable."
        key: "cornerRadius"; min: 0; max: 60; defaultValue: 0; unit: "px"
    }

    // ── Size ──────────────────────────────────────────────────────────────────
    Label { text: "Size"; font.bold: true; font.pixelSize: 14; Layout.topMargin: 8 }

    SettingSlider {
        label: "Item Width"; description: "Width of each wallpaper thumbnail."
        key: "itemWidth"; min: 100; max: 1000; defaultValue: 300; unit: "px"
    }

    SettingSlider {
        label: "Item Height"; description: "Height of each wallpaper thumbnail."
        key: "itemHeight"; min: 100; max: 1440; defaultValue: 420; unit: "px"
    }

    SettingSlider {
        label: "Center Tile Zoom"; description: "Size of the centered tile relative to the surrounding tiles."
        key: "selectedScale"; min: 100; max: 150; defaultValue: 108; unit: "%"
    }

    // ── Expansion ─────────────────────────────────────────────────────────────
    Label { text: "Expansion"; font.bold: true; font.pixelSize: 14; Layout.topMargin: 8 }

    SettingCombo {
        label: "Expand Selected"
        description: "Expand the centered tile's width to reveal more of the image."
        key: "expandSelected"; defaultValue: "false"
        options: [
            { text: "Disabled", value: "false" },
            { text: "Enabled",  value: "true"  }
        ]
    }

    SettingSlider {
        label: "Expansion Amount"; description: "Width multiplier applied when the centered tile is expanded."
        key: "expandMultiplier"; min: 100; max: 300; defaultValue: 120; unit: "%"
    }

    SettingCombo {
        label: "Hold to Expand"
        description: "Dwell on a tile to trigger a large immersive preview."
        key: "enableHoldExpand"; defaultValue: "false"
        options: [
            { text: "Disabled", value: "false" },
            { text: "Enabled",  value: "true"  }
        ]
    }

    SettingSlider {
        label: "Hold Coverage"; description: "Screen coverage for the hold preview."
        key: "holdExpandRatio"; min: 30; max: 100; defaultValue: 35; unit: "%"
    }

    SettingSlider {
        label: "Hold Delay"; description: "Time to dwell on a tile before the preview activates."
        key: "holdDelay"; min: 200; max: 10000; defaultValue: 1500; unit: "ms"
    }

    Item { Layout.fillHeight: true }
}
