import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property color sectionBackgroundColor: Color.mSurfaceVariant
    property var editSettings: JSON.parse(JSON.stringify(pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? {}))

    function ensureDefaults() {
        if (!editSettings)
            editSettings = {};
    }

    function saveSettings() {
        ensureDefaults();
        pluginApi.pluginSettings = JSON.parse(JSON.stringify(root.editSettings));
        pluginApi.saveSettings();
        pluginApi?.mainInstance?.refresh();
        ToastService.showNotice("ModelBar settings saved");
    }

    spacing: Style.marginL

    NText {
        text: "ModelBar Settings"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
    }

    Rectangle {
        Layout.fillWidth: true
        color: root.sectionBackgroundColor
        radius: Style.radiusS
        implicitHeight: generalColumn.implicitHeight + Style.marginXL

        ColumnLayout {
            id: generalColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            NText {
                text: "General"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Provider"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "auto",
                            name: "Auto"
                        },
                        {
                            key: "codex",
                            name: "Codex"
                        },
                        {
                            key: "claude",
                            name: "Claude Code"
                        }
                    ]
                    currentKey: editSettings?.providerMode ?? "auto"
                    onSelected: key => {
                        root.ensureDefaults();
                        editSettings.providerMode = key;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Codex source"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "auto",
                            name: "Auto"
                        },
                        {
                            key: "oauth",
                            name: "OAuth"
                        },
                        {
                            key: "cli",
                            name: "Codex app-server"
                        }
                    ]
                    currentKey: editSettings?.sourceMode ?? "auto"
                    onSelected: key => {
                        root.ensureDefaults();
                        editSettings.sourceMode = key;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Claude source"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "auto",
                            name: "Auto"
                        },
                        {
                            key: "oauth",
                            name: "OAuth"
                        }
                    ]
                    currentKey: editSettings?.claudeSourceMode ?? "auto"
                    onSelected: key => {
                        root.ensureDefaults();
                        editSettings.claudeSourceMode = key;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Bar metric"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "remaining",
                            name: "Remaining %"
                        },
                        {
                            key: "used",
                            name: "Used %"
                        },
                        {
                            key: "credits",
                            name: "Credits"
                        }
                    ]
                    currentKey: editSettings?.barMetric ?? "remaining"
                    onSelected: key => {
                        root.ensureDefaults();
                        editSettings.barMetric = key;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Refresh interval"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NSpinBox {
                    from: 60
                    to: 1800
                    value: editSettings?.refreshIntervalSec ?? 300
                    stepSize: 60
                    onValueChanged: {
                        root.ensureDefaults();
                        editSettings.refreshIntervalSec = value;
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        color: root.sectionBackgroundColor
        radius: Style.radiusS
        implicitHeight: pathsColumn.implicitHeight + Style.marginXL

        ColumnLayout {
            id: pathsColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            NText {
                text: "Runtime"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
            }

            NTextInput {
                Layout.fillWidth: true
                placeholderText: "python3"
                text: editSettings?.pythonPath ?? "python3"
                onTextChanged: {
                    root.ensureDefaults();
                    editSettings.pythonPath = text;
                }
            }

            NTextInput {
                Layout.fillWidth: true
                placeholderText: "codex"
                text: editSettings?.codexBinary ?? "codex"
                onTextChanged: {
                    root.ensureDefaults();
                    editSettings.codexBinary = text;
                }
            }

            NTextInput {
                Layout.fillWidth: true
                placeholderText: "claude"
                text: editSettings?.claudeBinary ?? "claude"
                onTextChanged: {
                    root.ensureDefaults();
                    editSettings.claudeBinary = text;
                }
            }

            NTextInput {
                Layout.fillWidth: true
                placeholderText: "CODEX_HOME override, optional"
                text: editSettings?.codexHome ?? ""
                onTextChanged: {
                    root.ensureDefaults();
                    editSettings.codexHome = text;
                }
            }

            NTextInput {
                Layout.fillWidth: true
                placeholderText: "Claude home override, optional"
                text: editSettings?.claudeHome ?? ""
                onTextChanged: {
                    root.ensureDefaults();
                    editSettings.claudeHome = text;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                    text: "Timeout"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NSpinBox {
                    from: 3
                    to: 30
                    value: editSettings?.requestTimeoutSec ?? 8
                    stepSize: 1
                    onValueChanged: {
                        root.ensureDefaults();
                        editSettings.requestTimeoutSec = value;
                    }
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
            text: "Reset"
            onClicked: {
                root.editSettings = JSON.parse(JSON.stringify(pluginApi?.manifest?.metadata?.defaultSettings ?? {}));
            }
        }

        Item {
            Layout.fillWidth: true
        }

        NButton {
            text: "Save"
            onClicked: root.saveSettings()
        }
    }
}
