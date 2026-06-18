import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications

import qs.Services.System

Item {
    id: root
    property var pluginApi: null

    property var trackedNotifs: []

    property var niriWindowListProcess: Component {
        Process {
            property string appEntry: ""
            property bool unset: false

            command: ["niri", "msg", "--json", "windows"]

            stdout: SplitParser {
                onRead: data => {
                    try {
                        const windows = JSON.parse(data);
                        const matches = windows.filter(w => w.app_id && w.app_id.toLowerCase() === appEntry || w.app_id.includes(appEntry) || appEntry.includes(w.app_id));
                        if (matches.length > 0) {
                            matches.forEach(m => {
                                niriUrgentProcess.createObject(root, {
                                    windowId: m.id,
                                    unset: unset
                                }).running = true;
                            });
                        }
                    } catch (e) {}
                    destroy();
                }
            }
        }
    }

    property var niriUrgentProcess: Component {
        Process {
            property int windowId: 0
            property bool unset: false
            command: ["niri", "msg", "action", unset ? "unset-window-urgent" : "set-window-urgent", "--id", String(windowId)]
            onExited: destroy()
        }
    }

    property var server: NotificationServer {
        keepOnReload: false
        imageSupported: true
        actionsSupported: true

        onNotification: notification => {
            const entry = (notification.desktopEntry || notification.appName || "").toLowerCase();
            if (!entry)
                return;
            trackedNotifs = [...trackedNotifs,
                {
                    id: notification.id,
                    entry: entry
                }
            ];
            niriWindowListProcess.createObject(root, {
                appEntry: entry.toLowerCase()
            }).running = true;
        }
    }

    property var historyWatcher: Connections {
        target: NotificationService.historyModel

        function onCountChanged() {
            const model = NotificationService.historyModel;

            const currentIds = new Set();
            for (let i = 0; i < model.count; i++) {
                const n = model.get(i);
                currentIds.add(n.originalId);
            }

            const removedNotifs = trackedNotifs.filter(n => !currentIds.has(n.id));
            const remainingNotifs = trackedNotifs.filter(n => currentIds.has(n.id));

            for (const n of removedNotifs) {
                const appHasMultipleNotifs = remainingNotifs.some(r => r.entry === n.entry);
                if (!appHasMultipleNotifs) {
                    niriWindowListProcess.createObject(root, {
                        appEntry: n.entry.toLowerCase(),
                        unset: true
                    }).running = true;
                }
            }

            trackedNotifs = remainingNotifs;
        }
    }
}
