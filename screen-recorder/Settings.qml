import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    // General
    property string editIconColor: pluginApi?.pluginSettings?.iconColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.iconColor ?? "none"
    property string editButtonAction: pluginApi?.pluginSettings?.buttonAction || pluginApi?.manifest?.metadata?.defaultSettings?.buttonAction || "toggle-recording"
    property bool editHideInactive: pluginApi?.pluginSettings?.hideInactive ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ?? false
    property string editDirectory: pluginApi?.pluginSettings?.directory || pluginApi?.manifest?.metadata?.defaultSettings?.directory || ""
    property string editScriptPath: pluginApi?.pluginSettings?.scriptPath || pluginApi?.manifest?.metadata?.defaultSettings?.scriptPath || ""
    property bool editShowCursor: pluginApi?.pluginSettings?.showCursor ?? pluginApi?.manifest?.metadata?.defaultSettings?.showCursor ?? true
    property bool editCopyToClipboard: pluginApi?.pluginSettings?.copyToClipboard ?? pluginApi?.manifest?.metadata?.defaultSettings?.copyToClipboard ?? false
    property bool editRestorePortalSession: pluginApi?.pluginSettings?.restorePortalSession ?? pluginApi?.manifest?.metadata?.defaultSettings?.restorePortalSession ?? false

    // Video
    readonly property var _validFrameRates: ["30", "60", "120", "custom"]
    readonly property string _rawFrameRate: pluginApi?.pluginSettings?.frameRate || pluginApi?.manifest?.metadata?.defaultSettings?.frameRate || "60"

    property string editVideoSource: pluginApi?.pluginSettings?.videoSource || pluginApi?.manifest?.metadata?.defaultSettings?.videoSource || "portal"
    property string editResolution: pluginApi?.pluginSettings?.resolution || pluginApi?.manifest?.metadata?.defaultSettings?.resolution || "original"
    property string editFrameRate: _validFrameRates.includes(_rawFrameRate) ? _rawFrameRate : "custom"
    property string editCustomFrameRate: _validFrameRates.includes(_rawFrameRate) ? (pluginApi?.pluginSettings?.customFrameRate || pluginApi?.manifest?.metadata?.defaultSettings?.customFrameRate || "60") : _rawFrameRate
    property string editRateControl: pluginApi?.pluginSettings?.rateControl || pluginApi?.manifest?.metadata?.defaultSettings?.rateControl || "qp"
    property string editQuality: pluginApi?.pluginSettings?.quality || pluginApi?.manifest?.metadata?.defaultSettings?.quality || "very_high"
    property string editBitrate: pluginApi?.pluginSettings?.bitrate || pluginApi?.manifest?.metadata?.defaultSettings?.bitrate || "6000"
    property string editVideoCodec: pluginApi?.pluginSettings?.videoCodec || pluginApi?.manifest?.metadata?.defaultSettings?.videoCodec || "h264"
    property string editColorRange: pluginApi?.pluginSettings?.colorRange || pluginApi?.manifest?.metadata?.defaultSettings?.colorRange || "limited"

    // Audio
    property string editAudioSource: pluginApi?.pluginSettings?.audioSource || pluginApi?.manifest?.metadata?.defaultSettings?.audioSource || "default_output"
    property string editAudioCodec: pluginApi?.pluginSettings?.audioCodec || pluginApi?.manifest?.metadata?.defaultSettings?.audioCodec || "opus"

    // Replay
    readonly property var _validReplayDurations: ["15", "30", "60", "120", "300", "custom"]
    readonly property string _rawReplayDuration: pluginApi?.pluginSettings?.replayDuration || pluginApi?.manifest?.metadata?.defaultSettings?.replayDuration || "30"

    property string editReplayDuration: _validReplayDurations.includes(_rawReplayDuration) ? _rawReplayDuration : "custom"
    property string editCustomReplayDuration: _validReplayDurations.includes(_rawReplayDuration) ? (pluginApi?.pluginSettings?.customReplayDuration || pluginApi?.manifest?.metadata?.defaultSettings?.customReplayDuration || "30") : _rawReplayDuration
    property string editReplayStorage: pluginApi?.pluginSettings?.replayStorage || pluginApi?.manifest?.metadata?.defaultSettings?.replayStorage || "ram"
    property bool editReplayNotifications: pluginApi?.pluginSettings?.replayNotifications ?? pluginApi?.manifest?.metadata?.defaultSettings?.replayNotifications ?? true
    property bool editAutoStartReplay: pluginApi?.pluginSettings?.autoStartReplay ?? pluginApi?.manifest?.metadata?.defaultSettings?.autoStartReplay ?? false

    function saveSettings() {
        if (!pluginApi || !pluginApi.pluginSettings) {
            Logger.e("ScreenRecorder", "Cannot save: pluginApi or pluginSettings is null");
            return;
        }

        // General
        pluginApi.pluginSettings.iconColor = root.editIconColor;
        pluginApi.pluginSettings.buttonAction = root.editButtonAction;
        pluginApi.pluginSettings.hideInactive = root.editHideInactive;
        pluginApi.pluginSettings.directory = root.editDirectory;
        pluginApi.pluginSettings.scriptPath = root.editScriptPath;
        pluginApi.pluginSettings.showCursor = root.editShowCursor;
        pluginApi.pluginSettings.copyToClipboard = root.editCopyToClipboard;
        pluginApi.pluginSettings.restorePortalSession = root.editRestorePortalSession;

        // Video
        pluginApi.pluginSettings.videoSource = root.editVideoSource;
        pluginApi.pluginSettings.resolution = root.editResolution;
        pluginApi.pluginSettings.frameRate = root.editFrameRate;
        pluginApi.pluginSettings.customFrameRate = root.editCustomFrameRate;
        pluginApi.pluginSettings.rateControl = root.editRateControl;
        pluginApi.pluginSettings.quality = root.editQuality;
        pluginApi.pluginSettings.bitrate = root.editBitrate;
        pluginApi.pluginSettings.videoCodec = root.editVideoCodec;
        pluginApi.pluginSettings.colorRange = root.editColorRange;

        // Audio
        pluginApi.pluginSettings.audioSource = root.editAudioSource;
        pluginApi.pluginSettings.audioCodec = root.editAudioCodec;

        // Replay
        pluginApi.pluginSettings.replayDuration = root.editReplayDuration;
        pluginApi.pluginSettings.customReplayDuration = root.editCustomReplayDuration;
        pluginApi.pluginSettings.replayStorage = root.editReplayStorage;
        pluginApi.pluginSettings.replayNotifications = root.editReplayNotifications;
        pluginApi.pluginSettings.autoStartReplay = root.editAutoStartReplay;

        pluginApi.saveSettings();

        Logger.i("ScreenRecorder", "Settings saved successfully");
    }

    // Icon Color
    NComboBox {
        label: I18n.tr("common.select-icon-color")
        description: I18n.tr("common.select-color-description")
        model: Color.colorKeyModel
        currentKey: root.editIconColor
        onSelected: key => root.editIconColor = key
        minimumWidth: 200
    }

    // Button Action
    NComboBox {
        label: pluginApi.tr("settings.general.button-action")
        description: pluginApi.tr("settings.general.button-action-description")
        model: [
            {
                "key": "toggle-recording",
                "name": pluginApi.tr("settings.general.button-action-toggle-recording")
            },
            {
                "key": "toggle-replay",
                "name": pluginApi.tr("settings.general.button-action-toggle-replay")
            },
            {
                "key": "save-replay",
                "name": pluginApi.tr("settings.general.button-action-save-replay")
            },
            {
                "key": "open-panel",
                "name": pluginApi.tr("settings.general.button-action-toggle-panel")
            }
        ]
        currentKey: root.editButtonAction
        onSelected: key => root.editButtonAction = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.buttonAction || "toggle-recording"
    }

    // Hide When Inactive
    NToggle {
        label: pluginApi.tr("settings.general.hide-when-inactive")
        description: pluginApi.tr("settings.general.hide-when-inactive-description")
        checked: root.editHideInactive
        onToggled: c => root.editHideInactive = c
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ?? false
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Output Folder
    NTextInputButton {
        label: pluginApi.tr("settings.general.output-folder")
        description: pluginApi.tr("settings.general.output-folder-description")
        placeholderText: Quickshell.env("HOME") + "/Videos"
        text: root.editDirectory
        buttonIcon: "folder-open"
        buttonTooltip: pluginApi.tr("settings.general.output-folder")
        onInputEditingFinished: root.editDirectory = text
        onButtonClicked: folderPicker.openFilePicker()
    }

    // Script Path
    NTextInputButton {
        label: pluginApi.tr("settings.general.script-path")
        description: pluginApi.tr("settings.general.script-path-description")
        placeholderText: ""
        text: root.editScriptPath
        buttonIcon: "folder-open"
        buttonTooltip: pluginApi.tr("settings.general.script-path")
        onInputEditingFinished: root.editScriptPath = text
        onButtonClicked: filePicker.openFilePicker()
    }

    // Show Cursor
    NToggle {
        label: pluginApi.tr("settings.general.show-cursor")
        description: pluginApi.tr("settings.general.show-cursor-description")
        checked: root.editShowCursor
        onToggled: c => root.editShowCursor = c
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.showCursor ?? true
    }

    // Copy to Clipboard
    NToggle {
        label: pluginApi.tr("settings.general.copy-to-clipboard")
        description: pluginApi.tr("settings.general.copy-to-clipboard-description")
        checked: root.editCopyToClipboard
        onToggled: c => root.editCopyToClipboard = c
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.copyToClipboard ?? false
    }

    // Restore Portal Session
    NToggle {
        label: pluginApi.tr("settings.general.restore-portal-session")
        description: pluginApi.tr("settings.general.restore-portal-session-description")
        checked: root.editRestorePortalSession
        onToggled: c => root.editRestorePortalSession = c
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.restorePortalSession ?? false
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Video Settings
    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        // Source
        NComboBox {
            label: pluginApi.tr("settings.video.source")
            description: pluginApi.tr("settings.video.source-description")
            model: {
                let options = [
                    {
                        "key": "portal",
                        "name": pluginApi.tr("settings.video.sources-portal")
                    },
                    {
                        "key": "screen",
                        "name": pluginApi.tr("settings.video.sources-screen")
                    }
                ];
                if (CompositorService.isHyprland) {
                    options.push({
                        "key": "focused-monitor",
                        "name": pluginApi.tr("settings.video.sources-focused-monitor")
                    });
                }
                return options;
            }
            currentKey: root.editVideoSource
            onSelected: key => root.editVideoSource = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.videoSource || "portal"
        }

        // Resolution
        NComboBox {
            label: pluginApi.tr("settings.video.resolution")
            description: pluginApi.tr("settings.video.resolution-description")
            model: [
                {
                    "key": "original",
                    "name": pluginApi.tr("settings.video.resolution-original")
                },
                {
                    "key": "1920x1080",
                    "name": "1920x1080 (Full HD)"
                },
                {
                    "key": "1920x1200",
                    "name": "1920x1200 (WUXGA)"
                },
                {
                    "key": "2560x1440",
                    "name": "2560x1440 (QHD)"
                },
                {
                    "key": "3840x2160",
                    "name": "3840x2160 (4K)"
                },
                {
                    "key": "1280x720",
                    "name": "1280x720 (HD)"
                }
            ]
            currentKey: root.editResolution
            onSelected: key => root.editResolution = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.resolution || "original"
        }

        // Frame Rate
        NComboBox {
            label: pluginApi.tr("settings.video.frame-rate")
            description: pluginApi.tr("settings.video.frame-rate-description")
            model: [
                {
                    "key": "30",
                    "name": "30 FPS"
                },
                {
                    "key": "60",
                    "name": "60 FPS"
                },
                {
                    "key": "120",
                    "name": "120 FPS"
                },
                {
                    "key": "custom",
                    "name": pluginApi.tr("settings.video.frame-rate-custom")
                }
            ]
            currentKey: root.editFrameRate
            onSelected: key => root.editFrameRate = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.frameRate || "60"
        }

        // Custom Frame Rate
        NTextInput {
            visible: root.editFrameRate === "custom"
            label: pluginApi.tr("settings.video.custom-frame-rate")
            description: pluginApi.tr("settings.video.custom-frame-rate-description")
            placeholderText: "60"
            text: root.editCustomFrameRate
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '');
                if (numeric !== text) {
                    text = numeric;
                }
                if (numeric) {
                    root.editCustomFrameRate = numeric;
                }
            }
            Layout.fillWidth: true
        }

        // Rate Control
        NComboBox {
            label: pluginApi.tr("settings.video.rate-control")
            description: pluginApi.tr("settings.video.rate-control-description")
            model: [
                {
                    "key": "qp",
                    "name": pluginApi.tr("settings.video.rate-control-qp")
                },
                {
                    "key": "vbr",
                    "name": pluginApi.tr("settings.video.rate-control-vbr")
                },
                {
                    "key": "cbr",
                    "name": pluginApi.tr("settings.video.rate-control-cbr")
                }
            ]
            currentKey: root.editRateControl
            onSelected: key => root.editRateControl = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.rateControl || "qp"
        }

        // Video Quality (qp/vbr)
        NComboBox {
            visible: root.editRateControl !== "cbr"
            label: pluginApi.tr("settings.video.quality")
            description: pluginApi.tr("settings.video.quality-description")
            model: [
                {
                    "key": "medium",
                    "name": pluginApi.tr("settings.video.quality-medium")
                },
                {
                    "key": "high",
                    "name": pluginApi.tr("settings.video.quality-high")
                },
                {
                    "key": "very_high",
                    "name": pluginApi.tr("settings.video.quality-very-high")
                },
                {
                    "key": "ultra",
                    "name": pluginApi.tr("settings.video.quality-ultra")
                }
            ]
            currentKey: root.editQuality
            onSelected: key => root.editQuality = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.quality || "very_high"
        }

        // Bitrate (cbr)
        NTextInput {
            visible: root.editRateControl === "cbr"
            label: pluginApi.tr("settings.video.bitrate")
            description: pluginApi.tr("settings.video.bitrate-description")
            placeholderText: "6000"
            text: root.editBitrate
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '');
                if (numeric !== text)
                    text = numeric;
                if (numeric)
                    root.editBitrate = numeric;
            }
            Layout.fillWidth: true
        }

        // Video Codec
        NComboBox {
            label: pluginApi.tr("settings.video.codec")
            description: pluginApi.tr("settings.video.codec-description")
            model: {
                let options = [
                    {
                        "key": "h264",
                        "name": "H264"
                    },
                    {
                        "key": "hevc",
                        "name": "HEVC"
                    },
                    {
                        "key": "av1",
                        "name": "AV1"
                    },
                    {
                        "key": "vp8",
                        "name": "VP8"
                    },
                    {
                        "key": "vp9",
                        "name": "VP9"
                    }
                ];
                // Only add HDR options if source is 'screen' or 'focused-monitor'
                if (root.editVideoSource === "screen" || root.editVideoSource === "focused-monitor") {
                    options.push({
                        "key": "hevc_hdr",
                        "name": "HEVC HDR"
                    });
                    options.push({
                        "key": "av1_hdr",
                        "name": "AV1 HDR"
                    });
                }
                return options;
            }
            currentKey: root.editVideoCodec
            onSelected: key => {
                root.editVideoCodec = key;
                // If an HDR codec is selected, change the colorRange to full
                if (key.includes("_hdr")) {
                    root.editColorRange = "full";
                }
            }
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.videoCodec || "h264"

            Connections {
                target: root
                function onEditVideoSourceChanged() {
                    if (root.editVideoSource !== "screen" && root.editVideoSource !== "focused-monitor" && (root.editVideoCodec === "av1_hdr" || root.editVideoCodec === "hevc_hdr")) {
                        root.editVideoCodec = "h264";
                    }
                }
            }
        }

        // Color Range
        NComboBox {
            label: pluginApi.tr("settings.video.color-range")
            description: pluginApi.tr("settings.video.color-range-description")
            model: [
                {
                    "key": "limited",
                    "name": pluginApi.tr("settings.video.color-range-limited")
                },
                {
                    "key": "full",
                    "name": pluginApi.tr("settings.video.color-range-full")
                }
            ]
            currentKey: root.editColorRange
            onSelected: key => root.editColorRange = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.colorRange || "limited"
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Audio Settings
    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        // Audio Source
        NComboBox {
            label: pluginApi.tr("settings.audio.source")
            description: pluginApi.tr("settings.audio.source-description")
            model: [
                {
                    "key": "none",
                    "name": pluginApi.tr("settings.audio.audio-sources-none")
                },
                {
                    "key": "default_output",
                    "name": pluginApi.tr("settings.audio.audio-sources-system-output")
                },
                {
                    "key": "default_input",
                    "name": pluginApi.tr("settings.audio.audio-sources-microphone-input")
                },
                {
                    "key": "both",
                    "name": pluginApi.tr("settings.audio.audio-sources-both")
                }
            ]
            currentKey: root.editAudioSource
            onSelected: key => root.editAudioSource = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.audioSource || "default_output"
        }

        // Audio Codec
        NComboBox {
            label: pluginApi.tr("settings.audio.codec")
            description: pluginApi.tr("settings.audio.codec-description")
            model: [
                {
                    "key": "opus",
                    "name": "Opus"
                },
                {
                    "key": "aac",
                    "name": "AAC"
                }
            ]
            currentKey: root.editAudioCodec
            onSelected: key => root.editAudioCodec = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.audioCodec || "opus"
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Replay Settings
    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        // Replay Duration
        NComboBox {
            label: pluginApi.tr("settings.replay.duration")
            description: pluginApi.tr("settings.replay.duration-description")
            model: [
                {
                    "key": "15",
                    "name": "15s"
                },
                {
                    "key": "30",
                    "name": "30s"
                },
                {
                    "key": "60",
                    "name": "60s"
                },
                {
                    "key": "120",
                    "name": "2 min"
                },
                {
                    "key": "300",
                    "name": "5 min"
                },
                {
                    "key": "custom",
                    "name": pluginApi.tr("settings.replay.duration-custom")
                }
            ]
            currentKey: root.editReplayDuration
            onSelected: key => root.editReplayDuration = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.replayDuration || "30"
        }

        // Custom Replay Duration
        NTextInput {
            visible: root.editReplayDuration === "custom"
            label: pluginApi.tr("settings.replay.custom-duration")
            description: pluginApi.tr("settings.replay.custom-duration-description")
            placeholderText: "30"
            text: root.editCustomReplayDuration
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '');
                if (numeric !== text) {
                    text = numeric;
                }
                if (numeric) {
                    root.editCustomReplayDuration = numeric;
                }
            }
            Layout.fillWidth: true
        }

        // Replay Storage
        NComboBox {
            label: pluginApi.tr("settings.replay.storage")
            description: pluginApi.tr("settings.replay.storage-description")
            model: [
                {
                    "key": "ram",
                    "name": pluginApi.tr("settings.replay.storage-ram")
                },
                {
                    "key": "disk",
                    "name": pluginApi.tr("settings.replay.storage-disk")
                }
            ]
            currentKey: root.editReplayStorage
            onSelected: key => root.editReplayStorage = key
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.replayStorage || "ram"
        }

        // Replay Notifications
        NToggle {
            label: pluginApi.tr("settings.replay.replay-notifications")
            description: pluginApi.tr("settings.replay.replay-notifications-description")
            checked: root.editReplayNotifications
            onToggled: c => root.editReplayNotifications = c
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.replayNotifications ?? true
        }

        // Auto-start Replay Buffer
        NToggle {
            label: pluginApi.tr("settings.replay.auto-start-replay")
            description: pluginApi.tr("settings.replay.auto-start-replay-description")
            checked: root.editAutoStartReplay
            onToggled: c => root.editAutoStartReplay = c
            defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.autoStartReplay ?? false
        }
    }

    Item {
        Layout.fillHeight: true
    }

    NFilePicker {
        id: folderPicker
        selectionMode: "folders"
        title: pluginApi.tr("settings.general.output-folder")
        initialPath: root.editDirectory || Quickshell.env("HOME") + "/Videos"
        onAccepted: paths => {
            if (paths.length > 0) {
                root.editDirectory = paths[0];
            }
        }
    }

    NFilePicker {
        id: filePicker
        selectionMode: "files"
        title: pluginApi.tr("settings.general.script-path")
        initialPath: root.editScriptPath || Quickshell.env("HOME")
        onAccepted: paths => {
            if (paths.length > 0) {
                root.editScriptPath = paths[0];
            }
        }
    }
}
