import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Dank Material Shell setting page
PluginSettings {
    id: root
    pluginId: "wallpaperCarousel"

    // -------------------------------------------------------------------------
    // Reusable Component to reduce code bloat
    // -------------------------------------------------------------------------
    component SettingSlider: Column {
        id: sliderRoot
        property string label: ""
        property string desc: ""
        property string settingKey: ""
        property int min: 0
        property int max: 100
        property int defaultVal: 0
        property string unit: ""

        width: parent.width; spacing: Theme.spacingXS
        property var val: root.loadValue(settingKey, defaultVal)

        Row {
            width: parent.width; spacing: Theme.spacingS
            StyledText { 
                text: label
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width - 24 - Theme.spacingS 
            }
            DankIcon {
                name: "restart_alt"; size: 20
                opacity: String(sliderRoot.val) !== String(defaultVal) ? 0.8 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveValue(settingKey, defaultVal) 
                }
            }
        }
        StyledText { 
            text: desc
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            opacity: 0.8 
        }
        DankSlider { 
            width: parent.width
            minimum: sliderRoot.min
            maximum: sliderRoot.max
            value: Number(sliderRoot.val) || sliderRoot.defaultVal
            unit: sliderRoot.unit
            onSliderValueChanged: v => root.saveValue(sliderRoot.settingKey, v) 
        }
    }

    // -------------------------------------------------------------------------
    // General
    // -------------------------------------------------------------------------
    StringSetting {
        settingKey: "wallpaperDirectory"
        label: "Wallpaper Directory"
        description: "Override the wallpaper directory. Leave empty to follow system wallpaper."
        placeholder: "/home/user/Pictures/Wallpapers"
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "carouselMode"
        label: "Carousel Mode"
        description: "Standard stops at the edges. Wrap loops the index. Infinite shows a seamless repeating view."
        defaultValue: "wrap"
        options: [
            { label: "Standard", value: "standard" },
            { label: "Wrap", value: "wrap" },
            { label: "Infinite", value: "infinite" }
        ]
    }

    // -------------------------------------------------------------------------
    // Visual
    // -------------------------------------------------------------------------
    SettingSlider {
        label: "Background Dimming"
        desc: "Opacity of the dark overlay behind the carousel."
        settingKey: "overlayOpacity"
        defaultVal: 80
        unit: "%"
    }

    SettingSlider {
        label: "Border Width"
        desc: "Width of the skewed border around thumbnails."
        settingKey: "borderWidth"
        max: 20; defaultVal: 3; unit: "px"
    }

    SettingSlider {
        label: "Corner Radius"
        desc: "Corner radius of thumbnails. Set to 0 to disable rounding."
        settingKey: "cornerRadius"
        defaultVal: 0
        unit: "px"
    }

    // -------------------------------------------------------------------------
    // Size
    // -------------------------------------------------------------------------
    SettingSlider {
        label: "Item Width"
        desc: "Width of each wallpaper thumbnail."
        settingKey: "itemWidth"
        min: 100; max: 1000; defaultVal: 300; unit: "px"
    }

    SettingSlider {
        label: "Item Height"
        desc: "Height of each wallpaper thumbnail."
        settingKey: "itemHeight"
        min: 100; max: 1440; defaultVal: 420; unit: "px"
    }

    SettingSlider {
        label: "Center Tile Zoom"
        desc: "Size of the centered tile relative to the surrounding tiles."
        settingKey: "selectedScale"
        min: 100; max: 150; defaultVal: 108; unit: "%"
    }

    // -------------------------------------------------------------------------
    // Expansion
    // -------------------------------------------------------------------------
    SelectionSetting {
        settingKey: "expandSelected"
        label: "Expand Selected"
        description: "Expand the centered tile's width to reveal more of the image."
        defaultValue: "false"
        options: [
            { label: "Disabled", value: "false" },
            { label: "Enabled", value: "true" }
        ]
    }

    SettingSlider {
        label: "Expansion Amount"
        desc: "Width multiplier applied when the centered tile is expanded."
        settingKey: "expandMultiplier"
        min: 100; max: 300; defaultVal: 120; unit: "%"
    }

    SelectionSetting {
        settingKey: "enableHoldExpand"
        label: "Hold to Expand"
        description: "Dwell on a tile to trigger a large immersive preview."
        defaultValue: "false"
        options: [
            { label: "Disabled", value: "false" },
            { label: "Enabled", value: "true" }
        ]
    }

    SettingSlider {
        label: "Hold Coverage"
        desc: "Screen coverage for the hold preview."
        settingKey: "holdExpandRatio"
        min: 30; max: 100; defaultVal: 35; unit: "%"
    }

    SettingSlider {
        label: "Hold Delay"
        desc: "Time to dwell on a tile before the preview activates."
        settingKey: "holdDelay"
        min: 200; max: 10000; defaultVal: 1500; unit: "ms"
    }
}
