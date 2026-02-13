import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI

Item {
    id: root
    required property var pluginApi

    /***************************
    * PROPERTIES
    ***************************/
    required property bool active 
    required property string currentWallpaper 
    required property bool hardwareAcceleration
    required property bool isPlaying
    required property bool isMuted
    required property string mpvSocket
    required property string profile
    required property string fillMode
    required property real volume

    required property Thumbnails thumbnails
    required property InnerService innerService


    /***************************
    * FUNCTIONS
    ***************************/
    function buildMpvCommand() {
        let options = [
            `input-ipc-server='${root.mpvSocket}'`,
            `profile='${root.profile}'`,
            `panscan=${root.fillMode === "fit" ? 0 : 1}`,
            "loop"
        ];

        if (root.hardwareAcceleration) {
            options.push("hwdec=auto");
        }

        if (root.isMuted) {
            options.push("no-audio");
        }

        const optionsString = options.join(" ");
        const command = `mpvpaper -o "${optionsString}" ALL "${root.currentWallpaper}"`;

        return ["sh", "-c", command];
    }

    function activateMpvpaper() {
        Logger.d("mpvpaper", "Activating mpvpaper...");

        // Save the old wallpapers of the user.
        innerService.saveOldWallpapers();

        mpvProc.command = buildMpvCommand();
        mpvProc.running = true;

        pluginApi.pluginSettings.isPlaying = true;
        pluginApi.saveSettings();
    }

    function deactivateMpvpaper() {
        Logger.d("mpvpaper", "Deactivating mpvpaper...");

        // Apply the old wallpapers back
        innerService.applyOldWallpapers();

        socket.connected = false;
        mpvProc.running = false;
    }

    function sendCommandToMPV(command: string) {
        socket.connected = true;
        socket.path = mpvSocket;
        socket.write(`${command}\n`);
        socket.flush();
    }


    /***************************
    * EVENTS
    ***************************/
    onActiveChanged: {
        if(root.active && !mpvProc.running && root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Turning mpvpaper on.");

            activateMpvpaper();

            thumbnails.startColorGen();
        } else if(!root.active) {
            Logger.d("mpvpaper", "Turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }

    onCurrentWallpaperChanged: {
        Logger.d("mpvpaper", "Current wallpaper changed from mpvpaper");

        if (!root.active)
            return;

        if (root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Changing current wallpaper:", root.currentWallpaper);

            if(mpvProc.running) {
                // If mpvpaper is already running
                sendCommandToMPV(`loadfile "${root.currentWallpaper}"`);
            } else {
                // Start mpvpaper
                activateMpvpaper();
            }

            thumbnails.startColorGen();
        } else if(mpvProc.running) {
            Logger.d("mpvpaper", "Current wallpaper is empty, turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }

    onHardwareAccelerationChanged: {
        Logger.d("mpvpaper", "Changing hardware acceleration");

        if(!root.active || !mpvProc.running) return;

        if(hardwareAcceleration) {
            sendCommandToMPV("set hwdec auto");
        } else {
            sendCommandToMPV("set hwdec no");
        }
    }

    onIsMutedChanged: {
        if (!mpvProc.running) {
            Logger.d("mpvpaper", "No wallpaper is running!");
            return;
        }

        // This sets the audio id to null or to auto
        if (isMuted) {
            sendCommandToMPV("no-osd set aid no");
        } else {
            sendCommandToMPV("no-osd set aid auto");
        }
    }

    onIsPlayingChanged: {
        if (!mpvProc.running) {
            Logger.d("mpvpaper", "No wallpaper is running!");
            return;
        }

        // Pause or unpause the video
        if(isPlaying) {
            sendCommandToMPV("set pause no");
        } else {
            sendCommandToMPV("set pause yes");
        }
    }

    onProfileChanged: {
        Logger.d("mpvpaper", "Changing current profile");

        if (!root.active || !mpvProc.running) return;

        sendCommandToMPV(`set profile ${profile}`)
    }

    onFillModeChanged:{
        Logger.d("mpvpaper", "Changing current fill mode");

        if (!root.active || !mpvProc.running) return;

        switch(fillMode){
            case "fit":
                sendCommandToMPV(`no-osd set panscan 0; no-osd set keepaspect yes`);
                break;
            case "crop":
                sendCommandToMPV(`no-osd set panscan 1; no-osd set keepaspect yes`);
                break;
            case "stretch":
                sendCommandToMPV(`no-osd set keepaspect no; no-osd set panscan 0`);
                break;
            default:
                Logger.e("mpvpaper", "Error, fill mode not found:", fillMode);
        }
    }

    onVolumeChanged: {
        if(!mpvProc.running) {
            Logger.d("mpvpaper", "No wallpaper is running!");
            return;
        }

        // Mpv has volume from 0 to 100 instead of 0 to 1
        const v = Math.min(Math.max(volume, 0), 100);

        sendCommandToMPV(`no-osd set volume ${v}`)

        // Clamp the volume
        if(v != volume) {
            pluginApi.pluginSettings.volume = v;
            pluginApi.saveSettings();
        }
    }

    /***************************
    * COMPONENTS
    ***************************/
    Process {
        id: mpvProc
    }

    Socket {
        id: socket
        path: root.mpvSocket
    }
}
