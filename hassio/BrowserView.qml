import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var main: null

    property var _allEntities: []
    property string _searchText: ""
    property bool _loading: false
    property int _pinVersion: 0

    clip: true

    function load() {
        searchInput.text = "";
        root._searchText = "";
        _fetchAll();
    }

    function _isPinned(entity_id) {
        const pinned = pluginApi?.pluginSettings?.entities ?? [];
        return pinned.includes(entity_id);
    }

    function _togglePin(entity_id) {
        let pinned = pluginApi?.pluginSettings?.entities ?? [];
        pinned = [...pinned];
        const idx = pinned.indexOf(entity_id);
        if (idx >= 0) {
            pinned.splice(idx, 1);
        } else {
            pinned.push(entity_id);
        }
        pluginApi.pluginSettings.entities = pinned;
        pluginApi.saveSettings();
        root.main.refreshEntities();
        root._pinVersion++;
    }

    ListModel {
        id: _filteredModel
    }

    function _refilter() {
        const q = root._searchText.toLowerCase();
        const source = root._allEntities;

        _filteredModel.clear();

        for (const e of source) {
            if (!q || e.entity_id.toLowerCase().includes(q) || e.friendly_name.toLowerCase().includes(q)) {
                _filteredModel.append(e);
            }
        }
    }

    function _fetchAll() {
        root._loading = true;
        root.main.getAllStates(function (results) {
            root._allEntities = results;
            root._refilter();
            root._loading = false;
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.marginM

        NTextInput {
            id: searchInput
            Layout.fillWidth: true
            label: pluginApi?.tr("browser.search_label")
            placeholderText: pluginApi?.tr("browser.search_placeholder")
            onTextChanged: {
                root._searchText = text;
                root._refilter();
            }
        }

        // Loading state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._loading

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.marginM

                NIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "loader"
                    color: Color.mOnSurfaceVariant

                    RotationAnimation on rotation {
                        running: root._loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }

                NText {
                    Layout.alignment: Qt.AlignHCenter
                    text: pluginApi?.tr("browser.loading")
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeM
                }
            }
        }

        // Entity list
        NScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root._loading
            clip: true

            ListView {
                width: parent.width
                height: parent.height
                clip: true

                model: _filteredModel
                spacing: Style.marginS

                delegate: Rectangle {
                    id: entityRow
                    width: ListView.view.width
                    height: Math.round(56 * Style.uiScaleRatio)
                    color: Color.mSurfaceVariant
                    radius: Style.radiusM

                    readonly property bool pinned: {
                        root._pinVersion;
                        return root._isPinned(model.entity_id);
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: Style.marginM
                        }
                        spacing: Style.marginM

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXXS

                            NText {
                                text: model.friendly_name
                                color: Color.mOnSurface
                                pointSize: Style.fontSizeM
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            NText {
                                text: model.entity_id
                                color: Color.mOnSurfaceVariant
                                pointSize: Style.fontSizeS
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        NIconButton {
                            icon: entityRow.pinned ? "pin-filled" : "pin"
                            color: entityRow.pinned ? Color.mTertiary : Color.mOutline

                            onClicked: root._togglePin(model.entity_id)
                        }
                    }
                }
            }
        }
    }
}
