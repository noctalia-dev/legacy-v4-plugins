import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
    id: root
    property var    pluginApi:  null
    property string scriptsDir: ""

    property string qrResult:      ""
    property string qrCapturePath: ""

    signal done()
    signal failed()

    function run(grimGeometry) {
        qrProc.exec({ command: [root.scriptsDir + "capture.sh", "qr", grimGeometry] })
    }

    function clearResults() {
        root.qrResult      = ""
        root.qrCapturePath = ""
    }

    function loadState(s) {
        if ((s.qrResult ?? "") === "") return
        root.qrResult      = s.qrResult
        root.qrCapturePath = s.qrCapturePath ?? ""
    }

    Process {
        id: qrProc
        stdout: StdioCollector {}
        onExited: (code) => {
            var result = qrProc.stdout.text.trim()
            if (code !== 0 || result === "") { root.failed(); return }

            root.qrResult      = result
            root.qrCapturePath = "/tmp/screen-toolkit-qr.png"

            if (root.pluginApi) {
                root.pluginApi.pluginSettings.qrResult      = result
                root.pluginApi.pluginSettings.qrCapturePath = "/tmp/screen-toolkit-qr.png"
                root.pluginApi.saveSettings()
            }

            root.done()
        }
    }
}
