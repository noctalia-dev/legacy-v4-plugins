import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: provider
    property var launcher: null
    property var pluginApi: null
    property string name: "Password Store"
    property bool handleSearch: true
    property var passwords: []

    function init() {
        listProcess.running = true;
    }

    function onOpened() {
        if (passwords.length === 0)
            listProcess.running = true;
    }

    function getResults(query) {
        const isPass = query === "pass" || query.startsWith("pass ");
        const isOtp  = query === "po"   || query.startsWith("po ");
        if (!isPass && !isOtp)
            return [];

        const search = isPass
            ? (query.startsWith("pass ") ? query.substring(5).trim() : "")
            : (query.startsWith("po ")   ? query.substring(3).trim() : "");

        const otp = isOtp;

        let matches;
        if (!search) {
            matches = passwords.slice(0, 15).map(p => ({ target: p, score: 1.0 }));
        } else {
            const results = FuzzySort.go(search, passwords, { limit: 15 });
            matches = Array.from({ length: results.length }, (_, i) => results[i]);
        }

        return matches.map(function(match) {
            const passName = match.target;
            return {
                "name": passName,
                "description": otp ? "Copy OTP to clipboard" : "Copy password to clipboard",
                "icon": otp ? "clock-shield" : "lock",
                "isTablerIcon": true,
                "isImage": false,
                "_score": match.score,
                "onActivate": function() {
                    if (provider.launcher)
                        provider.launcher.closeImmediately();
                    Qt.callLater(function() {
                        Quickshell.execDetached(otp
                            ? ["pass", "otp", "-c", passName]
                            : ["pass", "-c", passName]);
                    });
                }
            };
        });
    }

    Process {
        id: listProcess
        command: [
            "sh", "-c",
            "store=\"${PASSWORD_STORE_DIR:-$HOME/.password-store}\"; " +
            "find \"$store\" -name '*.gpg' | sed \"s|$store/||;s|\\.gpg$||\" | sort"
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim())
                    provider.passwords = text.trim().split("\n").filter(p => p.length > 0);
            }
        }
        stderr: StdioCollector {}
    }
}
