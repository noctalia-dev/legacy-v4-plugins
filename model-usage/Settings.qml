import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property color sectionBackgroundColor: Color.mSurfaceVariant

    property var editSettings: JSON.parse(JSON.stringify(pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? {}))

    function saveSettings() {
        pluginApi.pluginSettings = JSON.parse(JSON.stringify(root.editSettings));
        pluginApi.saveSettings();
    }

    spacing: Style.marginL

    NText {
        text: "Model Usage Settings"
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
                    text: "Bar display mode"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }
                NText {
                    text: "Show active provider or cycle between enabled providers"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "active",
                            name: "Active provider"
                        },
                        {
                            key: "cycle",
                            name: "Cycle providers"
                        }
                    ]
                    currentKey: editSettings?.barDisplayMode ?? "active"
                    onSelected: key => {
                        editSettings.barDisplayMode = key;
                    }
                }
            }

            ColumnLayout {
                visible: (editSettings?.barDisplayMode ?? "active") === "cycle"
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Cycle interval (seconds)"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }

                NSpinBox {
                    from: 2
                    to: 60
                    value: editSettings?.barCycleIntervalSec ?? 5
                    stepSize: 1
                    onValueChanged: {
                        editSettings.barCycleIntervalSec = value;
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
                NText {
                    text: "What number to show in the bar capsule"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                NComboBox {
                    Layout.fillWidth: true
                    model: [
                        {
                            key: "prompts",
                            name: "Prompts"
                        },
                        {
                            key: "tokens",
                            name: "Tokens"
                        },
                        {
                            key: "usage",
                            name: "Usage %"
                        }
                    ]
                    currentKey: editSettings?.barMetric ?? "prompts"
                    onSelected: key => {
                        editSettings.barMetric = key;
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
                }
                NText {
                    text: "Fallback polling interval when file watch misses changes"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                NSpinBox {
                    from: 5
                    to: 300
                    value: editSettings?.refreshIntervalSec ?? 30
                    stepSize: 5
                    onValueChanged: {
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
        implicitHeight: providersColumn.implicitHeight + Style.marginXL

        ColumnLayout {
            id: providersColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            NText {
                text: "Providers"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NToggle {
                    checked: editSettings?.providers?.claude?.enabled ?? true
                    onToggled: value => {
                        if (!editSettings.providers)
                            editSettings.providers = {};
                        if (!editSettings.providers.claude)
                            editSettings.providers.claude = {};
                        editSettings.providers.claude.enabled = value;
                        editSettingsChanged();
                    }
                }
                NText {
                    text: "Claude Code"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
                NText {
                    text: "Local files"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NToggle {
                    checked: editSettings?.providers?.codex?.enabled ?? true
                    onToggled: value => {
                        if (!editSettings.providers)
                            editSettings.providers = {};
                        if (!editSettings.providers.codex)
                            editSettings.providers.codex = {};
                        editSettings.providers.codex.enabled = value;
                        editSettingsChanged();
                    }
                }
                NText {
                    text: "Codex"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
                NText {
                    text: "Local files"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NToggle {
                    checked: editSettings?.providers?.copilot?.enabled ?? false
                    onToggled: value => {
                        if (!editSettings.providers)
                            editSettings.providers = {};
                        if (!editSettings.providers.copilot)
                            editSettings.providers.copilot = {};
                        editSettings.providers.copilot.enabled = value;
                        editSettingsChanged();
                    }
                }
                NText {
                    text: "Copilot"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
                NText {
                    text: "GitHub auth"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginM
                    NToggle {
                        checked: editSettings?.providers?.openrouter?.enabled ?? false
                        onToggled: value => {
                            if (!editSettings.providers)
                                editSettings.providers = {};
                            if (!editSettings.providers.openrouter)
                                editSettings.providers.openrouter = {};
                            editSettings.providers.openrouter.enabled = value;
                            editSettingsChanged();
                        }
                    }
                    NText {
                        text: "OpenRouter"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }
                    NText {
                        text: "API key"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }

                NTextInput {
                    visible: editSettings?.providers?.openrouter?.enabled ?? false
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.marginXL
                    placeholderText: "OPENROUTER_API_KEY env var or enter key here"
                    text: editSettings?.providers?.openrouter?.apiKey ?? ""

                    onTextChanged: {
                        if (!editSettings.providers)
                            editSettings.providers = {};
                        if (!editSettings.providers.openrouter)
                            editSettings.providers.openrouter = {};
                        editSettings.providers.openrouter.apiKey = text;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginM
                    NToggle {
                        checked: editSettings?.providers?.zen?.enabled ?? false
                        onToggled: value => {
                            if (!editSettings.providers)
                                editSettings.providers = {};
                            if (!editSettings.providers.zen)
                                editSettings.providers.zen = {};
                            editSettings.providers.zen.enabled = value;
                            editSettingsChanged();
                        }
                    }
                    NText {
                        text: "Zen (opencode.ai)"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }
                    NText {
                        text: "API key"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }

                NTextInput {
                    visible: editSettings?.providers?.zen?.enabled ?? false
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.marginXL
                    placeholderText: "OPENCODE_ZEN_API_KEY / OPENCODE_API_KEY env var or enter key here"
                    text: editSettings?.providers?.zen?.apiKey ?? ""

                    onTextChanged: {
                        if (!editSettings.providers)
                            editSettings.providers = {};
                        if (!editSettings.providers.zen)
                            editSettings.providers.zen = {};
                        editSettings.providers.zen.apiKey = text;
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

        Item {
            Layout.fillWidth: true
        }

        NButton {
            text: "Reset"
            onClicked: {
                root.editSettings = JSON.parse(JSON.stringify(pluginApi?.manifest?.metadata?.defaultSettings ?? {}));
            }
        }
    }
}
