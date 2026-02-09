pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

import qs.Commons

Item {
    id: root
    
    required property string folder
    property list<string> filters: []

    readonly property bool ready: internal.ready
    readonly property list<string> files: internal.files
    readonly property int count: files.length

    function reload() {
        if (!proc.running) {
            forceReload();
        }
    }

    function forceReload() {
        internal.ready = false
        internal.files = [];
        proc.running = false;
        proc.command = ["sh", "-c", proc._command]
        proc.running = true;
    }

    function get(index: int): string {
        return files[index];
    }

    function indexOf(file: string): int {
        return files.indexOf(file);
    }

    onFolderChanged: forceReload();

    QtObject {
        id: internal
        property bool ready: false
        property list<string> files: []
    }

    Process {
        id: proc

        readonly property string _command: {
            let command = `find ${root.folder} -maxdepth 1`
            let filters = []
            for (const filter of root.filters) {
                filters.push(`-name "${filter}"`);
            }
            return `${command} ${filters.join(" -o ")}`;
        }
        running: true
        command: ["sh", "-c", `${_command}`]

        stdout: SplitParser {
            onRead: line => internal.files.push(line);
        }
        onExited: {
            internal.ready = true;
        }
    }
}
