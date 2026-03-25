import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null
    property var widgetSettings: null

    property string widgetImage:          widgetSettings?.data?.image          ?? ""
    property real   widgetOpacity:        widgetSettings?.data?.opacity        ?? 1.0
    property bool   widgetMirror:         widgetSettings?.data?.mirror         ?? false
    property bool   widgetVerticalMirror: widgetSettings?.data?.verticalMirror ?? false
    property bool   showBackground:       widgetSettings?.data?.showBackground ?? widgetSettings?.metadata?.showBackground ?? true
    property bool   roundedCorners:       widgetSettings?.data?.roundedCorners ?? widgetSettings?.metadata?.roundedCorners ?? true

    function saveSettings() {
        if (widgetSettings == undefined || widgetSettings.data == undefined) return;

        widgetSettings.data.image          = widgetImage;
        widgetSettings.data.opacity        = widgetOpacity;
        widgetSettings.data.mirror         = widgetMirror;
        widgetSettings.data.verticalMirror = widgetVerticalMirror;
        widgetSettings.data.showBackground = showBackground;
        widgetSettings.data.roundedCorners = roundedCorners;
        widgetSettings.save();
    }

    RowLayout {
        spacing: Style.marginS

        NLabel {
            label:       root.pluginApi?.tr("desktopWidgetSettings.selection-title")       ?? ""
            description: root.pluginApi?.tr("desktopWidgetSettings.selection-description") ?? ""
        }

        NIconButton {
            icon: "wallpaper-selector"
            tooltipText: root.pluginApi?.tr("desktopWidgetSettings.selection-tooltip") ?? ""
            onClicked: imageSelection.openFilePicker()
        }

        NFilePicker {
            id: imageSelection
            title: root.pluginApi?.tr("desktopWidgetSettings.selection-title") ?? ""
            selectionMode: "files"

            onAccepted: paths => {
                if (paths.length > 0) {
                    root.widgetImage = paths[0];
                    root.saveSettings();
                }
            }
        }
    }

    NValueSlider {
        property real _value: root.widgetOpacity

        from: 0.0
        to: 1.0
        defaultValue: 1.0
        value: _value
        text: `${_value * 100.0}%`
        label:       root.pluginApi?.tr("desktopWidgetSettings.opacity-label")       ?? ""
        description: root.pluginApi?.tr("desktopWidgetSettings.opacity-description") ?? ""
        onMoved: value => _value = value
        onPressedChanged: (pressed, value) => {
            // When slider is let go
            if (!pressed) {
                root.widgetOpacity = value;
                root.saveSettings();
            }
        }
    }

    NToggle {
        label:       root.pluginApi?.tr("desktopWidgetSettings.mirror-label")       ?? ""
        description: root.pluginApi?.tr("desktopWidgetSettings.mirror-description") ?? ""
        checked: root.widgetMirror
        onToggled: checked => {
            root.widgetMirror = checked;
            root.saveSettings();
        }
        defaultValue: false
    }

    NToggle {
        label:       root.pluginApi?.tr("desktopWidgetSettings.vertical-mirror-label")       ?? ""
        description: root.pluginApi?.tr("desktopWidgetSettings.vertical-mirror-description") ?? ""
        checked: root.widgetVerticalMirror
        onToggled: checked => {
            root.widgetVerticalMirror = checked;
            root.saveSettings();
        }
        defaultValue: false
    }

    NToggle {
        label:       root.pluginApi?.tr("desktopWidgetSettings.show-background-label")       ?? ""
        description: root.pluginApi?.tr("desktopWidgetSettings.show-background-description") ?? ""
        checked: root.showBackground
        onToggled: checked => {
            root.showBackground = checked;
            root.saveSettings();
        }
        defaultValue: root.widgetSettings?.metadata?.showBackground ?? true
    }

    NToggle {
        label:       root.pluginApi?.tr("desktopWidgetSettings.rounded-corners-label")       ?? ""
        description: root.pluginApi?.tr("desktopWidgetSettings.rounded-corners-description") ?? ""
        visible: root.showBackground
        checked: root.roundedCorners
        onToggled: checked => {
            root.roundedCorners = checked;
            root.saveSettings();
        }
        defaultValue: root.widgetSettings?.metadata?.roundedCorners ?? true
    }
}
