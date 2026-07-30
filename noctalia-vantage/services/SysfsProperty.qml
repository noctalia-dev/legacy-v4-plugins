import QtQuick
import qs.Commons
import Quickshell.Io

QtObject {
    id: root

    required property string path
    required property string label

    property bool available: false
    property bool writeable: false
    property var value: null
    property var validValues: null
    property var transformWrite: v => typeof v === "boolean" ? (v ? 1 : 0) : v

    readonly property string sudoPrefix: "pkexec"
    property var writeCommand: val => ["sh", "-c", `echo ${val} > ${root.path}`]
    property var parser: function (raw) {
        const v = parseInt(raw?.trim());

        if (isNaN(v)) {
            Logger.w("NoctaliaVantage", root.label + ": invalid value:", raw);
            return undefined;
        }

        return v === 1;
    }

    signal writeFinished(bool success)

    property var _availabilityChecker: Process {
        id: availabilityChecker
        running: false
        command: ["/bin/sh", "-c", `test -f ${root.path} && (test -w ${root.path} && echo "2" || echo "1") || echo "0"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = parseInt(text);
                root.available = r >= 1;
                root.writeable = r === 2;
                Logger.i("NoctaliaVantage", root.label, "available:", root.available, "writable:", root.writeable);
                if (root.available)
                    root.reload();
            }
        }
    }

    onWriteFinished: success => {
        if (success)
            reload();
    }

    property var _reader: FileView {
        id: reader
        path: root.path
        printErrors: false

        onLoaded: {
            const parsed = root.parser(text());
            if (parsed === undefined)
                return;
            if (parsed !== root.value) {
                root.value = parsed;
                Logger.i("NoctaliaVantage", `${root.label} ->`, parsed);
            } else {
                Logger.d("NoctaliaVantage", `${root.label} unchanged:`, parsed);
            }
        }
    }

    property var _writer: Process {
        id: writer
        running: false
        property var pending: null

        onStarted: Logger.i("NoctaliaVantage", `Writing ${root.label}:`, pending)

        onExited: code => {
            if (code === 0) {
                Logger.i("NoctaliaVantage", `${root.label} write success:`, pending);
                root.value = pending;
                root.writeFinished(true);
            } else {
                Logger.e("NoctaliaVantage", `${root.label} write failed, code: `, code);
                root.writeFinished(false);
            }
        }
    }

    function checkAvailability() {
        availabilityChecker.running = true;
    }

    function set(newVal) {
        Logger.i("NoctaliaVantage", `Setting ${root.label} mode ->`, newVal);
        if (!root.available) {
            Logger.e("NoctaliaVantage", `${root.label}: not available`);
            return;
        }

        if (root.validValues && !root.validValues.includes(newVal)) {
            Logger.e("NoctaliaVantage", `${root.label}: invalid value:`, newVal);
            return;
        }

        if (!writeCommand) {
            Logger.e("NoctaliaVantage", `${root.label}: no writeCommand set`);
            return;
        }

        const finalVal = root.transformWrite(newVal);

        let cmd = root.writeCommand(finalVal);
        if (!root.writeable) {
            cmd = [sudoPrefix, ...cmd];
        }

        writer.pending = finalVal;
        writer.command = cmd;
        writer.running = true;
    }

    function reload() {
        reader.path = ""; // Force QML to recognize the refresh
        reader.path = root.path;
    }
}
