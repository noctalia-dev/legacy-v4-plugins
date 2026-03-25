import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Local mutable copy for editing
    property var commands: []
    property int commandsRevision: 0

    property real preferredWidth: 800 * Style.uiScaleRatio
    spacing: Style.marginL

    Component.onCompleted: {
        loadCommands();
    }

    function loadCommands() {
        var src = cfg.commands ?? defaults.commands;
        if (!src || !Array.isArray(src)) src = [];
        var copy = [];
        for (var i = 0; i < src.length; i++) {
            copy.push({
                "name": src[i].name || "",
                "command": src[i].command || "",
                "icon": src[i].icon || "terminal-2"
            });
        }
        commands = copy;
        commandsRevision++;
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("CustomCommands", "Cannot save settings: pluginApi is null");
            return;
        }

        var valid = [];
        for (var i = 0; i < commands.length; i++) {
            var name = commands[i].name.trim();
            var command = commands[i].command.trim();
            if (name !== "" || command !== "") {
                valid.push({
                    "name": name,
                    "command": command,
                    "icon": commands[i].icon || "terminal-2"
                });
            }
        }

        pluginApi.pluginSettings.commands = valid;
        pluginApi.saveSettings();
        Logger.i("CustomCommands", "Settings saved");
    }

    NText {
        text: pluginApi.tr("settings.title")
        pointSize: Style.fontSizeL
        font.bold: true
    }

    NText {
        text: pluginApi.tr("settings.description")
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Command list (scrollable)
    NScrollView {
        id: commandsScrollView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(commandsColumn.implicitHeight, 400)
        showScrollbarWhenScrollable: true
        gradientColor: "transparent"

        ColumnLayout {
            id: commandsColumn
            width: commandsScrollView.availableWidth
            spacing: Style.marginS

            Repeater {
                model: {
                    void root.commandsRevision;
                    return root.commands.length;
                }

                delegate: ColumnLayout {
                    id: cmdDelegate
                    required property int index

                    Layout.fillWidth: true
                    spacing: Style.marginS

                    readonly property var cmd: {
                        void root.commandsRevision;
                        return index >= 0 && index < root.commands.length ? root.commands[index] : null;
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIconButton {
                            icon: cmdDelegate.cmd ? cmdDelegate.cmd.icon : "terminal-2"
                            tooltipText: pluginApi.tr("settings.chooseIcon")
                            onClicked: {
                                iconPicker.activeIndex = cmdDelegate.index;
                                iconPicker.initialIcon = cmdDelegate.cmd ? cmdDelegate.cmd.icon : "terminal-2";
                                iconPicker.query = cmdDelegate.cmd ? cmdDelegate.cmd.icon : "";
                                iconPicker.open();
                            }
                        }

                        NTextInput {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 200
                            placeholderText: pluginApi.tr("settings.commandName")
                            text: cmdDelegate.cmd ? cmdDelegate.cmd.name : ""
                            onTextChanged: {
                                if (cmdDelegate.cmd && text !== cmdDelegate.cmd.name) {
                                    root.commands[cmdDelegate.index].name = text;
                                }
                            }
                        }

                        NTextInput {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 300
                            placeholderText: pluginApi.tr("settings.shellCommand")
                            text: cmdDelegate.cmd ? cmdDelegate.cmd.command : ""
                            onTextChanged: {
                                if (cmdDelegate.cmd && text !== cmdDelegate.cmd.command) {
                                    root.commands[cmdDelegate.index].command = text;
                                }
                            }
                        }

                        NIconButton {
                            icon: "arrow-up"
                            tooltipText: pluginApi.tr("settings.moveUp")
                            enabled: cmdDelegate.index > 0
                            onClicked: {
                                var tmp = root.commands[cmdDelegate.index];
                                root.commands[cmdDelegate.index] = root.commands[cmdDelegate.index - 1];
                                root.commands[cmdDelegate.index - 1] = tmp;
                                root.commandsRevision++;
                            }
                        }

                        NIconButton {
                            icon: "arrow-down"
                            tooltipText: pluginApi.tr("settings.moveDown")
                            enabled: cmdDelegate.index < root.commands.length - 1
                            onClicked: {
                                var tmp = root.commands[cmdDelegate.index];
                                root.commands[cmdDelegate.index] = root.commands[cmdDelegate.index + 1];
                                root.commands[cmdDelegate.index + 1] = tmp;
                                root.commandsRevision++;
                            }
                        }

                        NIconButton {
                            icon: "trash"
                            tooltipText: pluginApi.tr("settings.remove")
                            onClicked: {
                                root.commands.splice(cmdDelegate.index, 1);
                                root.commandsRevision++;
                            }
                        }
                    }
                }
            }
        }
    }

    NIconPicker {
        id: iconPicker
        property int activeIndex: -1
        initialIcon: "terminal-2"
        onIconSelected: function (iconName) {
            if (activeIndex >= 0 && activeIndex < root.commands.length) {
                root.commands[activeIndex].icon = iconName;
                root.commandsRevision++;
            }
        }
    }

    NButton {
        text: pluginApi.tr("settings.add")
        icon: "plus"
        onClicked: {
            root.commands.push({ "name": "", "command": "", "icon": "terminal-2" });
            root.commandsRevision++;
        }
    }
}
