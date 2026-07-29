import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets
import qs.Services.UI
import Quickshell.Io

ColumnLayout {
    id: root

    Process {
        id: callbackServer
        command: ["python3", pluginApi?.pluginDir + "/callback_server.py", pluginApi?.pluginSettings?.callbackPort.toString()]
        stdout: SplitParser {
            onRead: result => {
                const [code, state, error] = result.split(":")
                if (error !== "None") {
                    Logger.e("spotify-player", "Auth request returned with error:", error)
                    return
                }
                else if (state !== expectedState) {
                    Logger.w("spotify-player", "State mismatch, possible CSRF - Expected state:", expectedState, "State returned:", state)
                    return
                }
                else {
                    exchangeCodeForToken(code)
                }
            }
        }
    }

    Process {
        id: authProcess
        command: ["xdg-open"]
    }

    Process {
        id: getAvailableDevices
        command: ["curl", "https://api.spotify.com/v1/me/player/devices", "-H", "Authorization: Bearer " + pluginApi?.pluginSettings?.accessToken]

        stdout: StdioCollector {
            onStreamFinished: {
                const devices = JSON.parse(text).devices
                availableDevices = ""
                for (const device of devices) {
                    availableDevices = availableDevices + device.name + ": " + device.id + "\n"
                }
                availableDevices = availableDevices.trim()
            }
        }
    }

    property var pluginApi: null

    property string availableDevices: ""

    onAvailableDevicesChanged: deviceList.text = availableDevices

    property string editClientId:
        pluginApi?.pluginSettings?.clientId ||
        pluginApi?.manifest?.metadata?.defaultSettings?.clientId ||
        ""

    property string editClientSecret:
        pluginApi?.pluginSettings?.clientSecret ||
        pluginApi?.manifest?.metadata?.defaultSettings?.clientSecret ||
        ""

    property string editPlayerId:
        pluginApi?.pluginSettings?.playerId ??
        pluginApi?.manifest?.metadata?.defaultSettings?.playerId ??
        ""

    property int editCallbackPort:
        pluginApi?.pluginSettings?.callbackPort ||
        pluginApi?.manifest?.metadata?.defaultSettings?.callbackPort ||
        8888

    // state will be checked when running auth process
    property string expectedState: ""
        

    spacing: Style.marginM

    Component.onCompleted: {
        Logger.i("spotify-player", "Settings UI loaded")
        pluginApi?.mainInstance.refreshAccessToken()
    }

    // Text input
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.cid")
        description: pluginApi?.tr("settings.cid_desc")
        placeholderText: pluginApi?.tr("settings.cid_placeholder")
        text: root.editClientId
        onTextChanged: root.editClientId = text
    }

    // Text input
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.secret")
        description: pluginApi?.tr("settings.secret_desc")
        placeholderText: pluginApi?.tr("settings.secret_placeholder")
        text: root.editClientSecret
        onTextChanged: root.editClientSecret = text
    }

    RowLayout {

        NText {
            text: pluginApi?.tr("settings.callback")
        }

        NSpinBox {
            from: 0
            to: 65535
            value: root.editCallbackPort
            onValueChanged: root.editCallbackPort = value
        }

        NText {
            text: pluginApi?.tr("settings.callback_warning")
            pointSize: Style.fontSizeS
        }
    }
    

    NText {
        text: pluginApi?.tr("settings.tokengen_info")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    NButton {
        text: pluginApi?.tr("settings.tokengen_btn")
        onClicked: startAuth()
    }

    NText {
        text: pluginApi?.tr("settings.devicelist_info")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    NButton {
        text: pluginApi?.tr("settings.devicelist_btn")
        onClicked: getAvailableDevices.running = true
    }

    TextArea {
        id: deviceList
        Layout.fillWidth: true
        Layout.maximumWidth: parent.width

        background: Rectangle {
            radius: Style.radiusS
            color: Color.mSurface
            border.color: Color.mSurfaceVariant
        }

        text: root.availableDevices
        onTextChanged: text = root.availableDevices
    }

    // Text input
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.pid")
        description: pluginApi?.tr("settings.pid_desc")
        placeholderText: pluginApi?.tr("settings.pid_placeholder")
        inputMethodHints: Qt.ImhDigitsOnly
        text: root.editPlayerId
        onTextChanged: root.editPlayerId = text
    }

    
    function randomString(length) {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let result = ""
        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length))
        }
        return result
    }

    function startAuth() {
        // save plugin settings to avoid issues
        Logger.i("spotify-player", "Auth started, saving settings")
        pluginApi.pluginSettings.clientId = root.editClientId
        pluginApi.pluginSettings.clientSecret = root.editClientSecret
        pluginApi.pluginSettings.callbackPort = root.editCallbackPort
        pluginApi.saveSettings()
    
        const state = randomString(16)
        expectedState = state
        const scope = "user-read-playback-state user-modify-playback-state playlist-read-private"
        const redirectUri = "http://127.0.0.1:" + pluginApi?.pluginSettings?.callbackPort + "/callback"

        const params = new URLSearchParams({
            response_type: "code",
            client_id: pluginApi?.pluginSettings?.clientId,
            scope: scope,
            redirect_uri: redirectUri,
            state: state
        })

        const url = "https://accounts.spotify.com/authorize?" + params.toString()

        Logger.i("spotify-player", "Starting auth")

        callbackServer.command = ["python3", pluginApi?.pluginDir + "/callback_server.py", pluginApi?.pluginSettings?.callbackPort.toString()]
        callbackServer.running = true
        authProcess.command = ["xdg-open", url]
        authProcess.running = true
    }

    function exchangeCodeForToken(code) {
        Logger.i("spotify-player", "Found code:", code)

        const credentials = Qt.btoa(pluginApi?.pluginSettings?.clientId + ":" + pluginApi?.pluginSettings?.clientSecret)

        const xhr = new XMLHttpRequest()
        xhr.open("POST", "https://accounts.spotify.com/api/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.setRequestHeader("Authorization", "Basic " + credentials)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                const data = JSON.parse(xhr.responseText)
                pluginApi.pluginSettings.accessToken = data.access_token
                pluginApi.pluginSettings.refreshToken = data.refresh_token
                pluginApi.pluginSettings.tokenExpiresAt = Date.now() + (data.expires_in * 1000)
                pluginApi.saveSettings()
            }
        }
        xhr.send(new URLSearchParams({
            code: code,
            redirect_uri: "http://127.0.0.1:" + pluginApi?.pluginSettings?.callbackPort + "/callback",
            grant_type: "authorization_code"
        }).toString())
    }


    // Save function - called by the dialog
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("spotify-player", "Cannot save: pluginApi is null")
            return
        }

        pluginApi.pluginSettings.clientId = root.editClientId
        pluginApi.pluginSettings.clientSecret = root.editClientSecret
        pluginApi.pluginSettings.playerId = root.editPlayerId
        pluginApi.pluginSettings.callbackPort = root.editCallbackPort

        pluginApi.saveSettings()

        Logger.i("spotify-player", "Settings saved successfully")
    }
}
