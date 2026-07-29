import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets
import Quickshell.Io
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 600 * Style.uiScaleRatio
    property real contentPreferredHeight: 400 * Style.uiScaleRatio

    property bool playlistViewActive: false 

    property bool shuffleState: false

    anchors.fill: parent

    property string playlistSelectionId: ""

    property var searchResults: []

    property var playlistResults: []

    property bool closeAfterShuffle: false

    property string nowPlaying: ""

    Process {
        id: readShuffleState
        command: ["curl", "https://api.spotify.com/v1/me/player", "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken]

        stdout: StdioCollector {
            onStreamFinished: {
                shuffleState = JSON.parse(text).shuffle_state
            }
        }
    }

    Component.onCompleted: {
        readShuffleState.running = true
    }

    Process {
        id: shuffle
        command: ["curl", "-X", "PUT", "https://api.spotify.com/v1/me/player/shuffle?state=" + shuffleState.toString() 
            + ((pluginApi?.pluginSettings?.playerId !== "") ? "&device_id=" + pluginApi?.pluginSettings?.playerId : ""),
            "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken]

        onExited: (code, status) => {
            if (closeAfterShuffle) {
                closeAfterShuffle = false
                pluginApi?.closePanel(pluginApi?.panelOpenScreen)
            }
        }
    }

    function shufflePlayback() {
        shuffleState = !shuffleState
        shuffle.command = ["curl", "-X", "PUT", "https://api.spotify.com/v1/me/player/shuffle?state=" + shuffleState.toString() 
            + ((pluginApi?.pluginSettings?.playerId !== "") ? "&device_id=" + pluginApi?.pluginSettings?.playerId : ""),
            "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken]
        shuffle.running = true
    }

    Process {
        id: playRequestProcess
        command: ["curl"]

        onStarted: closeAfterShuffle = true

        stdout: StdioCollector {
            onStreamFinished: {
                Logger.i("spotify-player", text)
            }
        }

        onExited: (code, status) => {
            ToastService.showNotice(pluginApi?.tr("panel.notif"), nowPlaying, "music")
            shuffle.running = true
        }
    }

    function sendPlayRequest(data) {
        const requestBody = (data.type === "track")
            ? JSON.stringify({
                uris: [data.uri]
            })
            : JSON.stringify({
                context_uri: data.uri
            })
        nowPlaying = (data.type !== "playlist") ? data.artists[0].name + " - " + data.name : data.name
        
        playRequestProcess.command = ["curl", "-X", "PUT", "https://api.spotify.com/v1/me/player/play" 
            + ((pluginApi?.pluginSettings?.playerId !== "") ? "?device_id=" + pluginApi?.pluginSettings?.playerId : ""), 
            "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken,
            "--json", requestBody]
        playRequestProcess.running = true
    }

    Process {
        id: searchProcess
        command: ["curl"]

        onStarted: Logger.i("spotify-player", "starting search...")
        
        stdout: StdioCollector {
            onStreamFinished: {
                const result = JSON.parse(text)
                searchResults = [...result.tracks.items, ...result.albums.items, ...result.playlists.items.filter(Boolean)]
            }
        }
        
        onExited: (code, status) => {
            Logger.i("spotify-player", "finished search")
        }
    }

    Timer {
        id: searchDebounce
        interval: 300
        repeat: false
        onTriggered: searchForQuery(searchField.text)
    }


    function searchForQuery(query) {
        if (query !== "") {
            searchProcess.command = ["curl", "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken, "https://api.spotify.com/v1/search?q=" + encodeURIComponent(query) + "&type=album%2Cplaylist%2Ctrack"]
            searchProcess.running = true
        }
    }

    Process {
        id: fetchPlaylistsProcess
        command: ["curl", "https://api.spotify.com/v1/me/playlists", "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken]

        stdout: StdioCollector {
            onStreamFinished: {
                playlistResults = JSON.parse(text).items
            }
        }
    }

    onPlaylistViewActiveChanged: {
        if (playlistViewActive) {
            fetchPlaylistsProcess.running = true
        }
    }

    onPlaylistSelectionIdChanged: {
        playPlaylistProcess.command = ["sh", "-c", "spotify_player playback start context --shuffle --id " + playlistSelectionId + " playlist"]
        playPlaylistProcess.running = true
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL
 
            // Header
            RowLayout {
                    spacing: Style.marginL
                    
                    NText {
                        text: pluginApi?.tr("panel.title")
                        pointSize: Style.fontSizeL
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                }

                Rectangle {
                width: 90
                    height: 30
                    color: !(root.playlistViewActive) ? Color.mPrimary : searchArea.containsMouse ? Color.mHover : Color.mSurfaceVariant 
                    radius: Style.radiusS

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: Style.marginS
                        }
                        spacing: Style.marginS
                        
                        NIcon {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "search"
                            color: searchArea.containsMouse ? Color.mSurfaceVariant : !(root.playlistViewActive) ? Color.mSurfaceVariant : Color.mOnSurface
                        }
                            
                        NText {
                            pointSize: Style.fontSizeM
                            text: pluginApi?.tr("panel.search")
                            color: searchArea.containsMouse ? Color.mSurfaceVariant : !(root.playlistViewActive) ? Color.mSurfaceVariant : Color.mOnSurface
                        }
                    }

                    MouseArea {
                        id: searchArea
                        anchors.fill: parent    
                        hoverEnabled: true
                        onClicked: {
                            root.playlistViewActive = false
                        }
                    }
                }

                Rectangle {
                    width: 110
                    height: 30
                    color: root.playlistViewActive ? Color.mPrimary : playlistArea.containsMouse ? Color.mHover : Color.mSurfaceVariant 
                    radius: Style.radiusS

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: Style.marginS
                        }
                        spacing: Style.marginS
                            
                        NIcon {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "playlist"
                            color: playlistArea.containsMouse ? Color.mSurfaceVariant : root.playlistViewActive ? Color.mSurfaceVariant : Color.mOnSurface
                        }
                            
                        NText {
                            pointSize: Style.fontSizeM
                            text: pluginApi?.tr("panel.playlist")
                            color: playlistArea.containsMouse ? Color.mSurfaceVariant : root.playlistViewActive ? Color.mSurfaceVariant : Color.mOnSurface

                        }
                    }

                    MouseArea {
                        id: playlistArea
                        anchors.fill: parent    
                        hoverEnabled: true
                        onClicked: {
                            root.playlistViewActive = true
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                NText { text: pluginApi?.tr("panel.shuffle") }

                NToggle {
                    checked: root.shuffleState
                    MouseArea {
                        anchors.fill: parent
                        onClicked: shufflePlayback()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
            
            // Content
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                visible: !playlistViewActive

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Style.marginM
                    }
                    spacing: Style.marginM

                    NTextInput {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: pluginApi?.tr("panel.search_placeholder")

                        onTextChanged: searchDebounce.restart()
                    }

                    ColumnLayout {
                        visible: searchResults.length === 0
                        anchors {
                            fill: parent
                            margins: Style.marginM
                        }
                        spacing: Style.marginL

                        Item {
                            height: 50
                        }

                        NIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "search"
                            pointSize: Style.fontSizeXXL * 2
                            
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.search")
                            pointSize: Style.fontSizeL
                            font.weight: Font.Medium
                            color: Color.mPrimary
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.search_hint")
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    ListView {
                        id: searchResultsView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: searchResults
                        clip: true
                        visible: searchResults.length != 0

                        property int selectedIndex: -1

                        delegate: Rectangle {
                            width: searchResultsView.width
                            height: 40
                            color: searchResultsView.selectedIndex === index ? Color.mPrimary : hovering ? Color.mHover : Color.mSurfaceVariant
                            radius: Style.radiusS

                            property bool hovering: false

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Style.marginM

                                NIcon {
                                	icon: (modelData.type === "track")
                                		? "music"
                                		: (modelData.type === "album")
                                		? "disc"
                                		: "playlist"
                                }

                                NText {
                                    text: modelData.name
                                }

                                Item { Layout.fillWidth: true }

                                NText {
                                    text: (modelData.artists) ? modelData.artists[0].name : modelData.owner.display_name
                                    
                                }
                            }

                            MouseArea {
                                anchors.fill: parent    
                                hoverEnabled: true
                                onClicked: {
                                    searchResultsView.selectedIndex = index
                                    sendPlayRequest(modelData)
                                }
                                onEntered: hovering = true
                                onExited: hovering = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                visible: playlistViewActive

                ListView {
                    id: playlistList
                    anchors.fill: parent
                    model: playlistResults
                    clip: true

                    property int selectedIndex: -1

                    delegate: Rectangle {
                        width: playlistList.width
                        height: 40
                        color: playlistList.selectedIndex === index ? Color.mPrimary : hovering ? Color.mHover : Color.mSurfaceVariant
                        radius: Style.radiusS

                        property bool hovering: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Style.marginM

                            NText {
                                text: modelData.name
                            }
                        }

                        MouseArea {
                            anchors.fill: parent    
                            hoverEnabled: true
                            onClicked: {
                                playlistList.selectedIndex = index
                                sendPlayRequest(modelData)
                            }
                            onEntered: hovering = true
                            onExited: hovering = false
                        }
                    }
                }
            }
        }
    }
}
