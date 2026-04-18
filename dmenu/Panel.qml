import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

FocusScope {
    id: root

    property var pluginApi: null

    // ── SmartPanel integration ──
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    // Match launcher sizing
    property real contentPreferredWidth: Math.round(500 * Style.uiScaleRatio) + Style.margin2L
    property real contentPreferredHeight: Math.round(600 * Style.uiScaleRatio)

    // ── Positioning ──
    // Reads panelPosition from plugin settings. Values:
    //   "follow_launcher" (default) — same position as the app launcher
    //   "center", "top_center", "bottom_center", "top_left", etc.
    readonly property string screenBarPosition: Settings.getBarPositionForScreen(pluginApi?.panelOpenScreen?.name)

    readonly property string configuredPosition: {
        var pos = pluginApi?.pluginSettings?.panelPosition
            || pluginApi?.manifest?.metadata?.defaultSettings?.panelPosition
            || "follow_launcher";
        if (pos === "follow_launcher")
            return Settings.data.appLauncher.position;
        return pos;
    }

    readonly property string panelPosition: {
        var pos = configuredPosition;
        if (pos === "follow_bar") {
            if (screenBarPosition === "left" || screenBarPosition === "right")
                return "center_" + screenBarPosition;
            return screenBarPosition + "_center";
        }
        return pos;
    }

    // Expose anchor properties that PluginPanelSlot passes to SmartPanel
    readonly property bool panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
    readonly property bool panelAnchorVerticalCenter: panelPosition === "center" || panelPosition.startsWith("center_")
    readonly property bool panelAnchorTop: panelPosition.startsWith("top_")
    readonly property bool panelAnchorBottom: panelPosition.startsWith("bottom_")
    readonly property bool panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
    readonly property bool panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")

    // ── Visual settings ──
    readonly property bool showMatchCount: pluginApi?.pluginSettings?.showMatchCount
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showMatchCount ?? true
    readonly property bool showFooter: pluginApi?.pluginSettings?.showFooter
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showFooter ?? true

    anchors.fill: parent
    focus: true

    // ── Convenience ──
    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var dmenuState: main?.state ?? null

    // ── Local state ──
    property string filterText: ""
    property int selectedIndex: 0
    property var filteredItems: []

    // ── Filtering ──
    function updateFilter() {
        var st = dmenuState;
        if (!st || !st.active) {
            filteredItems = [];
            return;
        }
        var query = filterText.trim().toLowerCase();
        var items = st.items;
        var results = [];
        var max = st.maxResults || 200;

        for (var i = 0; i < items.length && results.length < max; i++) {
            var item = items[i];
            var nm = item.name || "";
            var desc = item.description || "";
            var val = item.value || item.name || "";
            if (query === ""
                || nm.toLowerCase().indexOf(query) !== -1
                || desc.toLowerCase().indexOf(query) !== -1
                || val.toLowerCase().indexOf(query) !== -1) {
                results.push({
                    name: nm, description: desc, value: val,
                    icon: item.icon || "", image: item.image || "",
                    originalIndex: i, isCustomInput: false
                });
            }
        }

        if (st.allowCustomInput && query !== "") {
            var hasExact = results.some(function(r) {
                return r.name.toLowerCase() === query;
            });
            if (!hasExact) {
                results.push({
                    name: query, description: root.pluginApi?.tr("provider.customInput"),
                    value: query, icon: "text-plus",
                    originalIndex: -1, isCustomInput: true
                });
            }
        }

        filteredItems = results;
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1);
    }

    function activateItem(idx) {
        if (idx < 0 || idx >= filteredItems.length) return;
        var item = filteredItems[idx];
        if (!main) return;
        if (item.isCustomInput) main.handleCustomInput(item.value);
        else main.handleSelection(item.value, item.originalIndex, "");
    }

    function scrollToSelected() {
        var itemY = selectedIndex * 50;
        if (itemY < flickable.contentY)
            flickable.contentY = itemY;
        else if (itemY + 48 > flickable.contentY + flickable.height)
            flickable.contentY = itemY + 48 - flickable.height;
    }

    function handleKeyPress(event) {
        if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(selectedIndex + 1, filteredItems.length - 1);
            scrollToSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(selectedIndex - 1, 0);
            scrollToSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateItem(selectedIndex);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (main) main.endSession();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            selectedIndex = (selectedIndex + 1) % Math.max(1, filteredItems.length);
            scrollToSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            selectedIndex = selectedIndex <= 0
                ? filteredItems.length - 1 : selectedIndex - 1;
            scrollToSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            selectedIndex = 0;
            scrollToSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            selectedIndex = Math.max(0, filteredItems.length - 1);
            scrollToSelected();
            event.accepted = true;
        }
    }

    // ── Signals ──
    Connections {
        target: root.main
        enabled: root.main !== null

        function onItemsChanged() {
            root.filterText = "";
            root.selectedIndex = 0;
            if (searchInput.inputItem) searchInput.inputItem.text = "";
            root.updateFilter();
            focusTimer.restart();
        }

        function onSessionEnded(sid) {
            if (root.main && root.main.replacingSession) return;
            if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
        }
    }

    onDmenuStateChanged: {
        if (dmenuState && dmenuState.active) updateFilter();
    }

    onFilterTextChanged: {
        selectedIndex = 0;
        updateFilter();
    }

    Component.onCompleted: {
        updateFilter();
        focusTimer.start();
        retryTimer.start();
    }

    Timer {
        id: retryTimer
        interval: 100
        onTriggered: root.updateFilter()
    }

    Timer {
        id: focusTimer
        interval: 150
        onTriggered: {
            if (searchInput.inputItem) {
                searchInput.inputItem.forceActiveFocus();
            }
        }
    }

    // ── UI ──
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Style.marginL
            anchors.bottomMargin: Style.marginL
            spacing: Style.marginL

            // ── Search input — same as LauncherCore ──
            NTextInput {
                id: searchInput
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                radius: Style.iRadiusM
                fontSize: Style.fontSizeM
                placeholderText: {
                    var st = root.dmenuState;
                    return (st && st.prompt) ? st.prompt : root.pluginApi?.tr("provider.typeToFilterPlaceholder");
                }
                text: root.filterText
                onTextChanged: root.filterText = text

                Component.onCompleted: {
                    if (searchInput.inputItem) {
                        searchInput.inputItem.forceActiveFocus();
                        searchInput.inputItem.Keys.onPressed.connect(function(event) {
                            root.handleKeyPress(event);
                        });
                    }
                }
            }

            // ── Custom input hint ──
            NText {
                visible: {
                    var st = root.dmenuState;
                    return st && st.allowCustomInput;
                }
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                text: root.pluginApi?.tr("provider.customInputHint")
                pointSize: Style.fontSizeXS
                color: Color.mPrimary
            }

            // ── Results area ──
            Rectangle {
                id: resultsArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                radius: Style.radiusL
                color: Color.mSurfaceVariant
                clip: true

                Flickable {
                    id: flickable
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    contentHeight: resultsColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: resultsColumn
                        width: flickable.width
                        spacing: Style.marginS

                        Repeater {
                            model: root.filteredItems.length

                            Rectangle {
                                id: itemRect
                                width: resultsColumn.width
                                height: 48
                                radius: Style.radiusM
                                property int itemIndex: index
                                property var itemData: root.filteredItems[index] || {}
                                property bool isSelected: index === root.selectedIndex

                                color: isSelected ? Color.mPrimary
                                    : itemMouse.containsMouse ? Qt.lighter(Color.mSurfaceVariant, 1.15)
                                    : Color.mSurface

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.marginM
                                    anchors.rightMargin: Style.marginM
                                    spacing: Style.marginM

                                    // Icon or image
                                    Item {
                                        width: 32
                                        height: parent.height
                                        visible: (itemRect.itemData.icon || "") !== "" || (itemRect.itemData.image || "") !== ""

                                        // Tabler icon (when no image)
                                        NIcon {
                                            anchors.centerIn: parent
                                            visible: (itemRect.itemData.image || "") === "" && (itemRect.itemData.icon || "") !== ""
                                            icon: itemRect.itemData.icon || ""
                                            color: itemRect.isSelected ? Color.mOnPrimary : Color.mOnSurface
                                        }

                                        // File image (when image path is set)
                                        Image {
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            visible: (itemRect.itemData.image || "") !== ""
                                            source: (itemRect.itemData.image || "") !== ""
                                                ? "file://" + itemRect.itemData.image : ""
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            sourceSize.width: 56
                                            sourceSize.height: 56
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Style.marginM * 2 - ((itemRect.itemData.icon || itemRect.itemData.image) ? 44 : 0)
                                        spacing: Style.marginXS

                                        Text {
                                            width: parent.width
                                            text: itemRect.itemData.name || ""
                                            font.pointSize: Style.fontSizeM
                                            font.weight: Font.Medium
                                            color: itemRect.isSelected ? Color.mOnPrimary : Color.mOnSurface
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            visible: (itemRect.itemData.description || "") !== ""
                                            text: itemRect.itemData.description || ""
                                            font.pointSize: Style.fontSizeS
                                            color: itemRect.isSelected ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedIndex = itemIndex;
                                        root.activateItem(itemIndex);
                                    }
                                    onEntered: root.selectedIndex = itemIndex
                                }
                            }
                        }
                    }
                }

                // Empty state — centered in resultsArea
                NText {
                    anchors.centerIn: parent
                    visible: root.filteredItems.length === 0
                    text: {
                        var st = root.dmenuState;
                        if (!st || !st.active) return root.pluginApi?.tr("provider.loading");
                        if (root.filterText !== "") return root.pluginApi?.tr("provider.noMatches");
                        return root.pluginApi?.tr("provider.noItems");
                    }
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                }
            }

            // ── Footer ──
            ColumnLayout {
                visible: root.showFooter
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL

                NText {
                    Layout.fillWidth: true
                    text: {
                        if (root.filteredItems.length === 0) {
                            if (root.filterText) return root.pluginApi?.tr("provider.noResults");
                            return "";
                        }
                        if (root.filterText && root.showMatchCount) {
                            return root.pluginApi?.trp(
                                "provider.filteredResultsCount",
                                root.filteredItems.length,
                                {
                                    filtered: root.filteredItems.length,
                                    total: root.dmenuState ? root.dmenuState.items.length : 0
                                }
                            );
                        }
                        return root.pluginApi?.trp(
                            "provider.resultsCount",
                            root.filteredItems.length
                        );
                    }
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignCenter
                }
            }
        }
    }
}
