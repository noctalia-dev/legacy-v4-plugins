import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string mainIcon: cfg.mainIcon ?? defaults.mainIcon
    property string expandDirection: cfg.expandDirection ?? defaults.expandDirection

    property bool primaryShowPill: cfg.primaryShowPill ?? defaults.primaryShowPill
    property string primarySymbolColor: cfg.primarySymbolColor ?? defaults.primarySymbolColor
    property string primaryPillColor: cfg.primaryPillColor ?? defaults.primaryPillColor
    property real primarySize: cfg.primarySize ?? defaults.primarySize

    property bool secondaryShowPill: cfg.secondaryShowPill ?? defaults.secondaryShowPill
    property string secondarySymbolColor: cfg.secondarySymbolColor ?? defaults.secondarySymbolColor
    property string secondaryPillColor: cfg.secondaryPillColor ?? defaults.secondaryPillColor
    property real secondarySize: cfg.secondarySize ?? defaults.secondarySize
    property real borderRadius: cfg.borderRadius ?? defaults.borderRadius
    property string focusBorderColor: cfg.focusBorderColor ?? defaults.focusBorderColor

    // Local mutable copy for editing
    property var workspaces: []
    property int workspacesRevision: 0

    spacing: Style.marginL

    Component.onCompleted: {
        loadWorkspaces();
    }

    function loadWorkspaces() {
        var src = cfg.workspaces ?? defaults.workspaces;
        if (!src || !Array.isArray(src)) src = [];
        var copy = [];
        for (var i = 0; i < src.length; i++) {
            copy.push({ "name": src[i].name || "", "icon": src[i].icon || "star" });
        }
        workspaces = copy;
        workspacesRevision++;
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("SpecialWorkspaces", "Cannot save settings: pluginApi is null");
            return;
        }

        var valid = [];
        for (var i = 0; i < workspaces.length; i++) {
            var name = workspaces[i].name.trim();
            if (name !== "") {
                valid.push({ "name": name, "icon": workspaces[i].icon || "star" });
            }
        }

        pluginApi.pluginSettings.mainIcon = root.mainIcon;
        pluginApi.pluginSettings.expandDirection = root.expandDirection;
        pluginApi.pluginSettings.primaryShowPill = root.primaryShowPill;
        pluginApi.pluginSettings.primarySymbolColor = root.primarySymbolColor;
        pluginApi.pluginSettings.primaryPillColor = root.primaryPillColor;
        pluginApi.pluginSettings.primarySize = root.primarySize;
        pluginApi.pluginSettings.secondaryShowPill = root.secondaryShowPill;
        pluginApi.pluginSettings.secondarySymbolColor = root.secondarySymbolColor;
        pluginApi.pluginSettings.secondaryPillColor = root.secondaryPillColor;
        pluginApi.pluginSettings.secondarySize = root.secondarySize;
        pluginApi.pluginSettings.borderRadius = root.borderRadius;
        pluginApi.pluginSettings.focusBorderColor = root.focusBorderColor;
        pluginApi.pluginSettings.workspaces = valid;
        pluginApi.saveSettings();
        Logger.i("SpecialWorkspaces", "Settings saved");
    }

    NText {
        text: "Special Workspaces"
        pointSize: Style.fontSizeL
        font.bold: true
    }

    NText {
        text: "Configure Hyprland special workspaces shown in the bar widget."
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    RowLayout {
        spacing: Style.marginM

        NIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: root.mainIcon
            pointSize: Style.fontSizeXL
        }

        NTextInput {
            id: mainIconInput
            Layout.preferredWidth: 140
            label: "Main Button Icon"
            text: root.mainIcon
            onTextChanged: {
                if (text !== root.mainIcon) {
                    root.mainIcon = text;
                }
            }
        }

        NIconButton {
            icon: "search"
            tooltipText: "Browse icons"
            onClicked: {
                mainIconPicker.open();
            }
        }
    }

    NIconPicker {
        id: mainIconPicker
        initialIcon: root.mainIcon
        onIconSelected: function (iconName) {
            root.mainIcon = iconName;
            mainIconInput.text = iconName;
        }
    }

    NComboBox {
        Layout.fillWidth: true
        label: "Expand Direction"
        description: "Which direction the workspace pills expand from the main button."
        model: [
            { "key": "down", "name": "Down" },
            { "key": "up", "name": "Up" },
            { "key": "right", "name": "Right" },
            { "key": "left", "name": "Left" }
        ]
        currentKey: root.expandDirection
        onSelected: function (key) {
            root.expandDirection = key;
        }
        defaultValue: "down"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Border Radius"
            description: "Roundness of the buttons (" + Math.round(root.borderRadius * 100) + "%)."
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 1.0
            stepSize: 0.05
            value: root.borderRadius
            onMoved: root.borderRadius = value
        }
    }

    NColorChoice {
        label: "Focus Border Color"
        description: "Color of the border shown on the focused workspace."
        currentKey: root.focusBorderColor
        onSelected: key => { root.focusBorderColor = key; }
        defaultValue: "none"
    }

    // --- Primary Button ---

    NText {
        text: "Primary Button"
        pointSize: Style.fontSizeM
        font.bold: true
    }

    NToggle {
        label: "Show Pill"
        description: "Show a colored circle behind the main button icon."
        checked: root.primaryShowPill
        onToggled: checked => { root.primaryShowPill = checked; }
        defaultValue: true
    }

    NColorChoice {
        label: "Symbol Color"
        description: "Override the main button icon color."
        currentKey: root.primarySymbolColor
        onSelected: key => { root.primarySymbolColor = key; }
        defaultValue: "none"
    }

    NColorChoice {
        label: "Pill Color"
        description: "Override the main button pill color."
        currentKey: root.primaryPillColor
        onSelected: key => { root.primaryPillColor = key; }
        defaultValue: "none"
        visible: root.primaryShowPill
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Size"
            description: "Size of the main button (" + Math.round(root.primarySize * 100) + "%)."
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.3
            to: 1.0
            stepSize: 0.05
            value: root.primarySize
            onMoved: root.primarySize = value
        }
    }

    // --- Secondary Buttons ---

    NText {
        text: "Secondary Buttons"
        pointSize: Style.fontSizeM
        font.bold: true
    }

    NToggle {
        label: "Show Pill"
        description: "Show a colored circle behind each workspace icon."
        checked: root.secondaryShowPill
        onToggled: checked => { root.secondaryShowPill = checked; }
        defaultValue: true
    }

    NColorChoice {
        label: "Symbol Color"
        description: "Override the workspace icon color."
        currentKey: root.secondarySymbolColor
        onSelected: key => { root.secondarySymbolColor = key; }
        defaultValue: "none"
    }

    NColorChoice {
        label: "Pill Color"
        description: "Override the workspace pill color."
        currentKey: root.secondaryPillColor
        onSelected: key => { root.secondaryPillColor = key; }
        defaultValue: "none"
        visible: root.secondaryShowPill
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Size"
            description: "Size of the workspace pills (" + Math.round(root.secondarySize * 100) + "%)."
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.3
            to: 1.0
            stepSize: 0.05
            value: root.secondarySize
            onMoved: root.secondarySize = value
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Workspace list
    Repeater {
        model: {
            void root.workspacesRevision;
            return root.workspaces.length;
        }

        delegate: RowLayout {
            id: wsRow
            required property int index

            Layout.fillWidth: true
            spacing: Style.marginM

            readonly property var ws: {
                void root.workspacesRevision;
                return index >= 0 && index < root.workspaces.length ? root.workspaces[index] : null;
            }

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: wsRow.ws ? wsRow.ws.icon : "star"
                pointSize: Style.fontSizeXL
            }

            NTextInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 140
                placeholderText: "Workspace name"
                text: wsRow.ws ? wsRow.ws.name : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.name) {
                        root.workspaces[wsRow.index].name = text;
                    }
                }
            }

            NTextInput {
                id: iconInput
                Layout.preferredWidth: 120
                placeholderText: "Icon name"
                text: wsRow.ws ? wsRow.ws.icon : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.icon) {
                        root.workspaces[wsRow.index].icon = text;
                        root.workspacesRevision++;
                    }
                }

                // Re-sync text when icon is changed externally (e.g., via icon picker)
                Connections {
                    target: root
                    function onWorkspacesRevisionChanged() {
                        if (wsRow.ws && iconInput.text !== wsRow.ws.icon) {
                            iconInput.text = wsRow.ws.icon;
                        }
                    }
                }
            }

            NIconButton {
                icon: "search"
                tooltipText: "Browse icons"
                onClicked: {
                    iconPicker.activeIndex = wsRow.index;
                    iconPicker.initialIcon = wsRow.ws ? wsRow.ws.icon : "star";
                    iconPicker.query = wsRow.ws ? wsRow.ws.icon : "";
                    iconPicker.open();
                }
            }

            NIconButton {
                icon: "trash"
                tooltipText: "Remove workspace"
                onClicked: {
                    root.workspaces.splice(wsRow.index, 1);
                    root.workspacesRevision++;
                }
            }
        }
    }

    NIconPicker {
        id: iconPicker
        property int activeIndex: -1
        initialIcon: "star"
        onIconSelected: function (iconName) {
            if (activeIndex >= 0 && activeIndex < root.workspaces.length) {
                root.workspaces[activeIndex].icon = iconName;
                root.workspacesRevision++;
            }
        }
    }

    NButton {
        text: "Add Workspace"
        icon: "plus"
        onClicked: {
            root.workspaces.push({ "name": "", "icon": "star" });
            root.workspacesRevision++;
        }
    }
}
