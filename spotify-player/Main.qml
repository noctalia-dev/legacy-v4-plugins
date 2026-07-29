import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    property var pluginApi: null

    function refreshAccessToken() {

        const credentials = Qt.btoa(pluginApi?.pluginSettings?.clientId + ":" + pluginApi?.pluginSettings?.clientSecret)

        const xhr = new XMLHttpRequest()
        xhr.open("POST", "https://accounts.spotify.com/api/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.setRequestHeader("Authorization", "Basic " + credentials)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                const data = JSON.parse(xhr.responseText)
                pluginApi.pluginSettings.accessToken = data.access_token
                if (data.refresh_token) {
                    pluginApi.pluginSettings.refreshToken = data.refresh_token
                }
                pluginApi.pluginSettings.tokenExpiresAt = Date.now() + (data.expires_in * 1000)
                pluginApi?.saveSettings()
                Logger.i("spotify-player", "Token refreshed successfully")
            }
        }
        xhr.send(new URLSearchParams({
            refresh_token: pluginApi?.pluginSettings?.refreshToken,
            grant_type: "refresh_token"
        }).toString())
    }
}