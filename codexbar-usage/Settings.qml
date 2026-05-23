import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "codexbar.js" as CodexBar

ColumnLayout {
    id: root

    property var pluginApi: null
    property bool loaded: false
    property string codexbarPath: "codexbar"
    property string codexbarSource: "cli"
    property int refreshIntervalSec: 60

    spacing: Style.marginL

    function loadSettings() {
        var defaults = pluginApi && pluginApi.manifest && pluginApi.manifest.metadata
            ? pluginApi.manifest.metadata.defaultSettings || {}
            : {}
        var settings = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings : defaults
        loaded = false
        codexbarPath = settings.codexbarPath || defaults.codexbarPath || "codexbar"
        codexbarSource = settings.codexbarSource || defaults.codexbarSource || "cli"
        refreshIntervalSec = Number(settings.refreshIntervalSec !== undefined ? settings.refreshIntervalSec : (defaults.refreshIntervalSec !== undefined ? defaults.refreshIntervalSec : 60))
        if (isNaN(refreshIntervalSec))
            refreshIntervalSec = 60
        loaded = true
    }

    function saveSettings() {
        if (!pluginApi || !loaded)
            return
        pluginApi.pluginSettings.codexbarPath = codexbarPath.trim() !== "" ? codexbarPath.trim() : "codexbar"
        pluginApi.pluginSettings.codexbarSource = codexbarSource.trim() !== "" ? codexbarSource.trim() : "cli"
        pluginApi.pluginSettings.refreshIntervalSec = Math.max(5, Number(refreshIntervalSec))
        pluginApi.saveSettings()
    }

    Component.onCompleted: loadSettings()
    onPluginApiChanged: loadSettings()

    NText {
        text: "CodexBar Usage Settings"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
    }

    Rectangle {
        Layout.fillWidth: true
        color: Color.mSurfaceVariant
        radius: Style.radiusS
        implicitHeight: content.implicitHeight + Style.marginXL

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            NText {
                text: "CodexBar CLI"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
                Layout.fillWidth: true
            }

            NTextInput {
                Layout.fillWidth: true
                label: "CodexBar path"
                description: "Command name or absolute path available to Noctalia/Quickshell. Use an absolute path if your graphical session does not inherit shell PATH."
                placeholderText: "codexbar"
                text: root.codexbarPath
                onTextChanged: {
                    root.codexbarPath = text
                    root.saveSettings()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Source"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NText {
                    text: "Passed to `codexbar usage --source`. `cli` reads local Codex CLI state; use another source if your CodexBar setup requires it."
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        { key: "cli", name: "CLI" },
                        { key: "auto", name: "Auto" },
                        { key: "web", name: "Web" },
                        { key: "oauth", name: "OAuth" },
                        { key: "api", name: "API" }
                    ]
                    currentKey: root.codexbarSource
                    onSelected: key => {
                        root.codexbarSource = key
                        root.saveSettings()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Refresh interval (seconds)"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NSpinBox {
                    from: 5
                    to: 3600
                    stepSize: 5
                    value: root.refreshIntervalSec
                    onValueChanged: {
                        root.refreshIntervalSec = value
                        root.saveSettings()
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        radius: Style.radiusS
        color: Qt.alpha(Color.mPrimary, 0.10)
        implicitHeight: commandColumn.implicitHeight + Style.marginXL

        ColumnLayout {
            id: commandColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginS

            NText {
                text: "Command preview"
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
                Layout.fillWidth: true
            }

            NText {
                text: CodexBar.command(root.pluginApi).join(" ")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                font.family: "monospace"
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
        }
    }
}
