import Quickshell.Io
import QtQuick

Process {
    onExited: destroy()
    Component.onCompleted: running = true
}
