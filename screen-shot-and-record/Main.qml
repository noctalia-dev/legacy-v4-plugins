import QtQuick
import Quickshell.Io
import qs.Services.UI
import QtQml.Models
import Quickshell
import qs.Commons

Item {
    id: root
    property var pluginApi: null
    property bool active: false
    property string target: ""

    // 存储当前所有屏幕
    property var screens: Quickshell.screens

    // 使用 Instantiator 管理选择框
    Instantiator {
        id: selectorInstantiator
        active: root.active
        model: Quickshell.screens
        delegate: Loader {
            required property int index
            source: "ScreenShot.qml"
            onLoaded: {
                item.pluginApi = root.pluginApi
                // 通过 index 重新取 QuickshellScreenInfo*
                item.screen = Quickshell.screens[index]
                Logger.d("ScreenShot", (root.target))
                item.target = root.target
                item.closed.connect(() => root.close())
                item.startCapture()
            }
        }
        onObjectAdded: (index, object) => Logger.d("ScreenShot", ("Selector added for screen", index))
        onObjectRemoved: (index, object) => Logger.d("ScreenShot", ("Selector removed for screen", index))
    }

    function open(target) {
        if (active) return
        root.target = target
        active = true
    }

    function close() {
        active = false
        root.target = ""
    }

    IpcHandler {
        target: "plugin:screen-shot-and-record"
        function screenshot() {
            open("screenshot")
        }

        function search() {
            open("search")
        }

        function ocr() {
            open("ocr")
        }

        function record() {
            open("record")
        }

        function recordsound() {
            open("recordsound")
        }
    }
}
