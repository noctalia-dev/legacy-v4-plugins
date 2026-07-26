import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var configList: main?.configList ?? []
    readonly property var sessionList: main?.sessionList ?? []
    property real contentPreferredWidth: Math.round(400 * Style.uiScaleRatio)
    property real contentPreferredHeight: Math.min(600, mainColumn.implicitHeight + Style.marginL * 2)

    property bool showImport: false
    property bool showLogs: false
    property string importFilePath: ""
    property string importName: ""
    property bool importPersistent: cfg.defaultPersistent ?? defaults.defaultPersistent ?? true

    Component.onCompleted: {
        if (main) {
            main.logStreamActive = true
            main.refreshFull()
        }
    }

    Component.onDestruction: {
        if (main) main.logStreamActive = false
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // --- Header ---
            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(header.implicitHeight + Style.marginM * 2 + 1)

                ColumnLayout {
                    id: header
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        OpenVpnIcon {
                            Layout.alignment: Qt.AlignVCenter
                            pointSize: Style.fontSizeXXL
                            applyUiScale: false
                            color: Color.mPrimary
                        }

                        NLabel {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            label: pluginApi?.tr("panel.title")
                        }

                        NIconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "plus"
                            tooltipText: pluginApi?.tr("panel.importConfig")
                            baseSize: Style.baseWidgetSize * 0.8
                            enabled: true
                            onClicked: root.showImport = !root.showImport
                        }

                        NIconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "file-text"
                            tooltipText: pluginApi?.tr("panel.logs")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: root.showLogs ? Qt.alpha(Color.mPrimary, 0.2) : "transparent"
                            onClicked: {
                                root.showLogs = !root.showLogs
                                if (main) main.logStreamActive = root.showLogs
                            }
                        }

                        NIconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "refresh"
                            tooltipText: pluginApi?.tr("panel.refresh")
                            baseSize: Style.baseWidgetSize * 0.8
                            enabled: true
                            onClicked: {
                                if (main) main.refresh()
                            }
                        }

                        NIconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "close"
                            tooltipText: pluginApi?.tr("panel.close")
                            baseSize: Style.baseWidgetSize * 0.8
                            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }
                    }
                }
            }

            // --- Import Section ---
            NBox {
                Layout.fillWidth: true
                visible: root.showImport
                Layout.preferredHeight: Math.round(importColumn.implicitHeight + Style.marginM * 2 + 1)

                ColumnLayout {
                    id: importColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NLabel {
                        label: pluginApi?.tr("import.title")
                        Layout.fillWidth: true
                    }

                    NTextInput {
                        id: importNameInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("import.nameLabel")
                        placeholderText: pluginApi?.tr("import.namePlaceholder")
                        text: ""
                        onTextChanged: root.importName = text
                    }

                    NTextInputButton {
                        id: importFileInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("import.fileLabel")
                        placeholderText: pluginApi?.tr("import.filePlaceholder")
                        text: ""
                        buttonIcon: "filepicker-folder"
                        buttonTooltip: pluginApi?.tr("tooltip.browse")
                        onInputTextChanged: (text) => root.importFilePath = text
                        onButtonClicked: filePicker.open()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NText {
                            text: pluginApi?.tr("import.persistent")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NToggle {
                            checked: root.importPersistent
                            onToggled: root.importPersistent = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NButton {
                            text: pluginApi?.tr("import.importBtn")
                            icon: "plus"
                            enabled: root.importFilePath.trim() !== "" && root.importName.trim() !== ""
                            onClicked: {
                                if (main) main.importConfig(root.importFilePath.trim(), root.importName.trim(), root.importPersistent)
                                root.showImport = false
                                root.importFilePath = ""
                                root.importName = ""
                                importNameInput.text = ""
                                importFileInput.text = ""
                                root.importPersistent = cfg.defaultPersistent ?? defaults.defaultPersistent ?? true
                            }
                        }

                        NButton {
                            text: pluginApi?.tr("import.cancel")
                            outlined: true
                            onClicked: {
                                root.showImport = false
                                root.importFilePath = ""
                                root.importName = ""
                                importNameInput.text = ""
                                importFileInput.text = ""
                                root.importPersistent = cfg.defaultPersistent ?? defaults.defaultPersistent ?? true
                            }
                        }
                    }
                }
            }

            // --- Main content ---
            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalPolicy: ScrollBar.AlwaysOff
                verticalPolicy: ScrollBar.AsNeeded
                reserveScrollbarSpace: false

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginM

                    // --- Connected section ---
                    NBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(activeColumn.implicitHeight + Style.marginXL)
                        visible: root.sessionList.length > 0

                        ColumnLayout {
                            id: activeColumn
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginM

                            NLabel {
                                label: pluginApi?.tr("status.connected")
                                Layout.fillWidth: true
                                Layout.leftMargin: Style.marginS
                            }

                            Repeater {
                                model: root.sessionList

                                VpnListItem {
                                    pluginApi: root.pluginApi
                                    name: modelData.name
                                    configPath: modelData.configPath
                                    sessionPath: modelData.sessionPath
                                    isConnected: true
                                    isLoading: main?.isPending(modelData.sessionPath) ?? false
                                    isPersistent: main?.configDetails[modelData.configPath]?.persistent ?? false
                                    isPaused: modelData.isPaused ?? false
                                    stats: main && main.sessionStats ? main.sessionStats[modelData.sessionPath] ?? null : null
                                    onButtonClicked: {
                                        if (!main) return
                                        main.disconnectFrom(modelData.sessionPath)
                                    }
                                    onRenameRequested: (path, newName) => {
                                        if (!main) return
                                        main.renameConfig(path, newName)
                                    }
                                    onDeleteRequested: (path) => {
                                        if (!main) return
                                        main.deleteConfig(path)
                                    }
                                    onRestartRequested: (sessionPath) => {
                                        if (!main) return
                                        main.restartSession(sessionPath)
                                    }
                                }
                            }
                        }
                    }

                    // --- Disconnected section ---
                    NBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(inactiveColumn.implicitHeight + Style.marginXL)
                        visible: {
                            let count = 0
                            for (const c of root.configList) {
                                if (!main?.isSessionActive(c.path))
                                    count++
                            }
                            return count > 0
                        }

                        ColumnLayout {
                            id: inactiveColumn
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginM

                            NLabel {
                                label: pluginApi?.tr("status.disconnected")
                                Layout.fillWidth: true
                                Layout.leftMargin: Style.marginS
                            }

                            Repeater {
                                model: {
                                    const inactive = []
                                    for (const c of root.configList) {
                                        if (!main?.isSessionActive(c.path))
                                            inactive.push(c)
                                    }
                                    return inactive
                                }

                                VpnListItem {
                                    pluginApi: root.pluginApi
                                    name: modelData.name
                                    configPath: modelData.path
                                    sessionPath: ""
                                    isConnected: false
                                    isLoading: main?.isPending(modelData.path) ?? false
                                    isPersistent: main?.configDetails[modelData.path]?.persistent ?? false
                                    details: main?.configDump[modelData.path] ?? null
                                    onButtonClicked: {
                                        if (!main) return
                                        main.connectTo(modelData.path)
                                    }
                                    onRenameRequested: (path, newName) => {
                                        if (!main) return
                                        main.renameConfig(path, newName)
                                    }
                                    onDeleteRequested: (path) => {
                                        if (!main) return
                                        main.deleteConfig(path)
                                    }
                                    onShowDetailsRequested: (path) => {
                                        if (!main) return
                                        main.loadConfigDetails(path)
                                    }
                                }
                            }
                        }
                    }

                    // --- Empty state ---
                    NBox {
                        visible: root.configList.length < 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(emptyColumn.implicitHeight + Style.marginM * 2 + 1)

                        ColumnLayout {
                            id: emptyColumn
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginL

                            Item { Layout.fillHeight: true }

                            OpenVpnIcon {
                                pointSize: Style.fontSizeXXL
                                applyUiScale: false
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.noConfigs")
                                pointSize: Style.fontSizeL
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.clickToImport")
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NButton {
                                text: pluginApi?.tr("panel.refresh")
                                icon: "refresh"
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: {
                                    if (main) main.refresh()
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    // --- Logs section ---
                    NBox {
                        visible: root.showLogs
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(logsColumn.implicitHeight + Style.marginM * 2 + 1)

                        ColumnLayout {
                            id: logsColumn
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginS

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginS

                                NIcon {
                                    icon: "file-text"
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurfaceVariant
                                }

                                NText {
                                    text: pluginApi?.tr("panel.logs")
                                    pointSize: Style.fontSizeS
                                    font.weight: Style.fontWeightMedium
                                    color: Color.mOnSurface
                                }

                                NBox { Layout.fillWidth: true }

                                NText {
                                    text: (main?.sessionLogs?.length ?? 0) + " " + pluginApi?.tr("panel.lines")
                                    pointSize: Style.fontSizeXXS
                                    color: Color.mOnSurfaceVariant
                                }

                                NIconButton {
                                    icon: "trash"
                                    tooltipText: pluginApi?.tr("panel.clearLogs")
                                    baseSize: Style.baseWidgetSize * 0.6
                                    onClicked: {
                                        if (main) main.clearLogs()
                                    }
                                }
                            }

                            NScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 200
                                horizontalPolicy: ScrollBar.AlwaysOff
                                verticalPolicy: ScrollBar.AsNeeded
                                reserveScrollbarSpace: false

                                Column {
                                    width: parent.width
                                    spacing: Style.marginXS

                                    Repeater {
                                        model: main?.sessionLogs ?? []

                                        delegate: NText {
                                            width: parent ? parent.width : 0
                                            text: modelData.raw
                                            pointSize: Style.fontSizeXXS
                                            color: _logColor(modelData.raw)
                                            wrapMode: Text.Wrap
                                            font.family: "monospace"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _logColor(raw) {
        if (raw.match(/ERR|ERROR|FAIL|FATAL/i)) return Color.mError
        if (raw.match(/WARN/i)) return Color.mSurfaceVariant
        if (raw.match(/INIT|SUCCESS|CONNECTED/i)) return Color.mPrimary
        return Color.mOnSurfaceVariant
    }

    Connections {
        target: root
        function onImportFilePathChanged() {
            if (importFileInput) importFileInput.text = root.importFilePath
        }
        function onImportNameChanged() {
            if (importNameInput) importNameInput.text = root.importName
        }
    }

    NFilePicker {
        id: filePicker
        title: pluginApi?.tr("import.title")
        selectionMode: "files"
        nameFilters: ["*.ovpn", "*.conf"]
        initialPath: Quickshell.env("HOME") || "/home"
        onAccepted: (paths) => {
            if (paths.length > 0) {
                root.importFilePath = paths[0]
                if (root.importName.trim() === "") {
                    const fileName = paths[0].split("/").pop()
                    const baseName = fileName.replace(/\.(ovpn|conf)$/, "")
                    root.importName = baseName
                    importNameInput.text = baseName
                }
            }
        }
    }
}