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
    // Required properties
    required property var    screenData
    required property string screenName
    required property int    screenWidth
    required property int    screenHeight

    // Monitor specific properties
    readonly property string currentWallpaper:     pluginApi?.pluginSettings?.[screenName]?.currentWallpaper     ?? ""
    readonly property bool   hardwareAcceleration: pluginApi?.pluginSettings?.[screenName]?.hardwareAcceleration ?? pluginApi?.manifest?.metadata?.defaultSettings?.hardwareAcceleration ?? false
    readonly property string fillMode:             pluginApi?.pluginSettings?.[screenName]?.fillMode             ?? pluginApi?.manifest?.metadata?.defaultSettings?.fillMode             ?? ""
    readonly property bool   isMuted:              pluginApi?.pluginSettings?.[screenName]?.isMuted              ?? false
    readonly property bool   isPlaying:            pluginApi?.pluginSettings?.[screenName]?.isPlaying            ?? false
    readonly property int    orientation:          pluginApi?.pluginSettings?.[screenName]?.orientation          ?? 0
    readonly property string profile:              pluginApi?.pluginSettings?.[screenName]?.profile              ?? pluginApi?.manifest?.metadata?.defaultSettings?.profile ?? ""
    readonly property double volume:               pluginApi?.pluginSettings?.[screenName]?.volume               ?? pluginApi?.manifest?.metadata?.defaultSettings?.volume  ?? 0

    // Global properties
    readonly property bool   enabled:   pluginApi?.pluginSettings?.enabled   ?? false
    readonly property string mpvSocket: pluginApi?.pluginSettings?.mpvSocket ?? pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket ?? ""

    // Constants
    readonly property string mpvSocketScreen: `${mpvSocket}-${screenName}`

    // Local properties
    property bool mpvpaperExists: false


    /***************************
    * FUNCTIONS
    ***************************/
    function buildMpvCommand() {
        let options = [
            `input-ipc-server='${root.mpvSocketScreen}'`,
            `profile='${root.profile}'`,
            `panscan=${root.fillMode === "crop" ? 1 : 0}`,
            `keepaspect='${root.fillMode === "stretch" ? "no" : "yes"}'`,
            "loop"
        ];

        if (root.hardwareAcceleration) {
            options.push("hwdec=auto");
        }

        if (root.isMuted) {
            options.push("no-audio"); }

        const optionsString = options.join(" ");
        const command = `mpvpaper -o "${optionsString}" ${root.screenName} "${root.currentWallpaper}"`;

        return ["sh", "-c", command];
    }

    function activateMpvpaper() {
        // Just call this again if we are still checking
        if (mpvCheck.running) {
            Qt.callLater(activateMpvpaper);
            return;
        }

        if (!mpvpaperExists) return;

        Logger.d("video-wallpaper", "Activating mpvpaper...");

        mpvProc.command = buildMpvCommand();
        mpvProc.running = true;

        if(pluginApi?.pluginSettings?.[screenName] === undefined) {
            pluginApi.pluginSettings[screenName] = {};
        }

        if (pluginApi.pluginSettings[screenName].isPlaying == undefined || !pluginApi.pluginSettings[screenName].isPlaying) {
            pluginApi.pluginSettings[screenName].isPlaying = true;
            pluginApi.saveSettings();
        }
    }

    function deactivateMpvpaper() {
        Logger.d("video-wallpaper", "Deactivating mpvpaper...");

        socket.connected = false;
        mpvProc.running = false;
    }

    function sendCommandToMPV(command: string) {
        socket.connected = true;
        socket.path = mpvSocketScreen;
        socket.write(`${command}\n`);
        socket.flush();
    }


    /***************************
    * EVENTS
    ***************************/
    Component.onDestruction: {
        // Clean up mpvpaper
        deactivateMpvpaper();
    }

    Component.onCompleted: {
        activateMpvpaper();
    }


    onCurrentWallpaperChanged: {
        if (!root.enabled) return;

        Logger.d("video-wallpaper", "Current wallpaper changed from mpvpaper");

        if (root.currentWallpaper != "") {
            Logger.d("video-wallpaper", "Changing current wallpaper:", root.currentWallpaper);

            if(mpvProc.running) {
                // If mpvpaper is already running
                sendCommandToMPV(`loadfile "${root.currentWallpaper}"`);
            } else {
                // Start mpvpaper
                activateMpvpaper();
            }
        } else if(mpvProc.running) {
            Logger.d("video-wallpaper", "Current wallpaper is empty, turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }

    onEnabledChanged: {
        if(root.enabled && !mpvProc.running && root.currentWallpaper != "") {
            Logger.d("video-wallpaper", "Turning mpvpaper on.");

            activateMpvpaper();
        } else if(!root.enabled) {
            Logger.d("video-wallpaper", "Turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }

    onHardwareAccelerationChanged: {
        if(!root.enabled || !mpvProc.running) return;

        Logger.d("video-wallpaper", "Changing hardware acceleration");

        if(hardwareAcceleration) {
            sendCommandToMPV("set hwdec auto");
        } else {
            sendCommandToMPV("set hwdec no");
        }
    }

    onFillModeChanged: {
        if (!root.enabled || !mpvProc.running) return;

        Logger.d("video-wallpaper", "Changing current fill mode");

        switch(fillMode){
            case "fit": // Fit
                sendCommandToMPV(`no-osd set panscan 0; no-osd set keepaspect yes`);
                break;
            case "crop": // Crop
                sendCommandToMPV(`no-osd set panscan 1; no-osd set keepaspect yes`);
                break;
            case "stretch": // Stretch
                sendCommandToMPV(`no-osd set keepaspect no; no-osd set panscan 0`);
                break;
            default:
                Logger.e("video-wallpaper", "Error, fill mode not found:", fillMode);
        }
    }

    onIsMutedChanged: {
        if (!root.enabled || !mpvProc.running) return;

        // This sets the audio id to null or to auto
        if (isMuted) {
            sendCommandToMPV("no-osd set aid no");
        } else {
            sendCommandToMPV("no-osd set aid auto");
        }
    }

    onIsPlayingChanged: {
        if (!root.enabled || !mpvProc.running) return;

        // Pause or unpause the video
        if(isPlaying) {
            sendCommandToMPV("set pause no");
        } else {
            sendCommandToMPV("set pause yes");
        }
    }

    onOrientationChanged: {
        if (!root.enabled || !mpvProc.running) return;

        Logger.d("video-wallpaper", "Changing orientation");

        sendCommandToMPV(`set video-rotate ${orientation}`);
    }

    onProfileChanged: {
        if (!root.enabled || !mpvProc.running) return;

        Logger.d("video-wallpaper", "Changing current profile");

        sendCommandToMPV(`set profile ${profile}`);
    }


    onVolumeChanged: {
        if (!root.enabled || !mpvProc.running) return;

        const clampedVolume = Math.min(Math.max(volume, 0), 1);
        const mpvVolume = clampedVolume * 100;

        // Mpv has volume from 0 to 100 instead of 0 to 1
        sendCommandToMPV(`no-osd set volume ${mpvVolume}`)

        // Clamp the volume
        if(clampedVolume != volume) {
            if (pluginApi?.pluginSettings?.[screenName] === undefined) {
                pluginApi.pluginSettings[screenName] = {};
            }

            pluginApi.pluginSettings[screenName].volume = clampedVolume;
            pluginApi.saveSettings();
        }
    }

    /***************************
    * COMPONENTS
    ***************************/
    Process {
        id: mpvCheck
        running: true
        command: ["sh", "-c", "mpvpaper --help"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.mpvpaperExists = true;
            } else {
                ToastService.showError(root.pluginApi?.tr("main.no_backend_found", {"backend": "Mpvpaper"}));
            }
        }
    }

    Process {
        id: mpvProc
    }

    Socket {
        id: socket
        path: root.mpvSocketScreen
    }
}
