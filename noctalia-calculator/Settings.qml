import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property var mainInst: pluginApi?.mainInstance ?? null

    property bool valueShowBarValue: pluginApi?.pluginSettings?.showBarValue ?? true
    property int valuePrecision: pluginApi?.pluginSettings?.precision ?? 8
    property string valueLanguage: pluginApi?.pluginSettings?.language ?? "auto"

    spacing: Style.marginM

    function saveSettings() {
        if (!pluginApi?.pluginSettings) return;
        pluginApi.pluginSettings.showBarValue = valueShowBarValue;
        pluginApi.pluginSettings.precision = valuePrecision;
        pluginApi.pluginSettings.language = valueLanguage;
        pluginApi.saveSettings();
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.language") ?? "Language"
            description: pluginApi?.tr("settings.language-desc") ?? "Plugin display language"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
                model: ["auto", "en", "pt"]

                delegate: Rectangle {
                    required property string modelData
                    readonly property string langCode: modelData
                    readonly property bool isSelected: root.valueLanguage === langCode
                    readonly property string langLabel: {
                        if (langCode === "auto") return pluginApi?.tr("settings.lang-auto") ?? "Auto";
                        if (langCode === "en") return pluginApi?.tr("settings.lang-en") ?? "English";
                        return pluginApi?.tr("settings.lang-pt") ?? "Portuguese (Brazil)";
                    }

                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Style.iRadiusM
                    color: isSelected ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
                    border.color: isSelected ? Color.mPrimary : (langMouse.containsMouse ? Color.mOutline : "transparent")
                    border.width: isSelected ? 2 : 1

                    Behavior on color { ColorAnimation { duration: Style.animationFast } }
                    Behavior on border.color { ColorAnimation { duration: Style.animationFast } }

                    NText {
                        anchors.centerIn: parent
                        text: parent.langLabel
                        font.bold: parent.isSelected
                        color: parent.isSelected ? Color.mPrimary : Color.mOnSurface
                    }

                    MouseArea {
                        id: langMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueLanguage = parent.langCode;
                            root.saveSettings();
                        }
                    }
                }
            }
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-bar") ?? "Show value in bar"
        description: pluginApi?.tr("settings.show-bar-desc") ?? "Display the current value next to the calculator icon"
        checked: root.valueShowBarValue
        onToggled: checked => {
            root.valueShowBarValue = checked;
            root.saveSettings();
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: (pluginApi?.tr("settings.precision") ?? "Decimal precision") + ": " + root.valuePrecision
            description: pluginApi?.tr("settings.precision-desc") ?? "Maximum decimals used when formatting results"
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 10
            stepSize: 1
            value: root.valuePrecision
            onMoved: {
                root.valuePrecision = Math.round(value);
                root.saveSettings();
            }
        }
    }

    NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.about") ?? "About"
        description: (pluginApi?.tr("settings.developed-by") ?? "Developed by Pir0c0pter0")
            + "<br>v" + (pluginApi?.manifest?.version ?? "1.0.0")
            + "<br>" + (pluginApi?.tr("settings.auto-language-desc") ?? "Automatic translation follows your system language while Auto is selected.")
    }
}
