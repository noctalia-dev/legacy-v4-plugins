import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // Resolve VM directory from settings, replacing ~ with $HOME
    readonly property string vmDirectory: pluginApi?.pluginSettings?.vmDirectory || "~/quickemu/"
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string resolvedVmDirectory: vmDirectory.replace("~", homeDir)

    property real downloadProgress: 0.0
    property bool isDownloading: false
    property string lastError: ""
    property string selectedCategory: ""
    property bool _filterGuard: false

    // Models
    ListModel { id: _vmListModel }
    property alias vmListModel: _vmListModel

    ListModel { id: _osListModel }
    property alias osListModel: _osListModel

    ListModel { id: _filteredOsListModel }
    property alias filteredOsListModel: _filteredOsListModel

    ListModel { id: _osCategoryList }
    property alias osCategoryList: _osCategoryList

    // --- Processes ---

    Process {
        id: listProcess
        command: ["find", root.resolvedVmDirectory, "-maxdepth", "1", "-name", "*.conf", "-exec", "basename", "-s", ".conf", "{}", ";"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var str = data.trim();
                if (str.length > 0) {
                    _vmListModel.append({ "vmName": str });
                }
            }
        }
        stderr: SplitParser { onRead: data => root.lastError = data }
        onRunningChanged: {
            if (!running) {
                Logger.i("Quickemu", "VM list refreshed — " + _vmListModel.count + " VMs found");
            }
        }
    }

    Process {
        id: startProcess
        command: []
        running: false
        stdout: SplitParser { onRead: data => Logger.i("Quickemu", data) }
        stderr: SplitParser { onRead: data => { root.lastError = data; Logger.e("Quickemu", data); } }
    }

    Process {
        id: editProcess
        command: []
        running: false
        stderr: SplitParser { onRead: data => { root.lastError = data; Logger.e("Quickemu", data); } }
    }

    Process {
        id: deleteProcess
        command: []
        running: false
        stderr: SplitParser { onRead: data => { root.lastError = data; Logger.e("Quickemu", data); } }
        onRunningChanged: {
            if (!running) {
                refreshVmList();
            }
        }
    }

    Process {
        id: createProcess
        command: []
        workingDirectory: root.resolvedVmDirectory
        running: false
        stdout: SplitParser {
            onRead: data => {
                var str = data.trim();
                var match = str.match(/([0-9.]+)\s*%/);
                if (match) {
                    root.downloadProgress = parseFloat(match[1]) / 100.0;
                } else if (str.length > 0) {
                    Logger.i("Quickemu", str);
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                Logger.e("Quickemu", data);
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (running) {
                root.isDownloading = true;
            } else {
                root.isDownloading = false;
                Logger.i("Quickemu", "quickget finished");
                root.downloadProgress = 0.0;
                refreshVmList();
            }
        }
    }

    Process {
        id: listOsProcess
        command: ["sh", "-c", "quickget --list | awk -F',' '{if (NR>1) print $1 \" \" $2}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var str = data.trim();
                if (str.length > 0) {
                    _osListModel.append({ "osName": str });
                    _filteredOsListModel.append({ "osName": str });
                }
            }
        }
        stderr: SplitParser { onRead: data => Logger.w("Quickemu", data) }
        onRunningChanged: {
            if (!running) {
                Logger.i("Quickemu", "OS list populated with " + _osListModel.count + " options.");
                buildCategoryList();
            }
        }
    }

    // --- Functions ---

    function buildCategoryList() {
        _osCategoryList.clear();
        var seen = {};
        for (var i = 0; i < _osListModel.count; ++i) {
            var full = _osListModel.get(i).osName;
            var cat = full.split(" ")[0];
            if (!seen[cat]) {
                seen[cat] = true;
                _osCategoryList.append({ "category": cat });
            }
        }
        Logger.i("Quickemu", "Built " + _osCategoryList.count + " OS categories.");
    }

    function filterByCategory(cat) {
        _filterGuard = true;
        root.selectedCategory = cat;
        _filteredOsListModel.clear();
        for (var i = 0; i < _osListModel.count; ++i) {
            var name = _osListModel.get(i).osName;
            if (name.split(" ")[0] === cat) {
                _filteredOsListModel.append({ "osName": name });
            }
        }
        _filterGuard = false;
    }

    function clearCategoryFilter() {
        _filterGuard = true;
        root.selectedCategory = "";
        _filteredOsListModel.clear();
        for (var i = 0; i < _osListModel.count; ++i) {
            _filteredOsListModel.append({ "osName": _osListModel.get(i).osName });
        }
        _filterGuard = false;
    }

    function updateFilteredOsList(query) {
        if (_filterGuard) return;
        _filterGuard = true;
        _filteredOsListModel.clear();
        var q = query.toLowerCase();
        for (var i = 0; i < _osListModel.count; ++i) {
            var name = _osListModel.get(i).osName;
            if (name.toLowerCase().indexOf(q) !== -1) {
                if (root.selectedCategory === "" || name.split(" ")[0] === root.selectedCategory) {
                    _filteredOsListModel.append({ "osName": name });
                }
            }
        }
        _filterGuard = false;
    }

    function clearError() {
        root.lastError = "";
    }

    function refreshVmList() {
        clearError();
        _vmListModel.clear();
        listProcess.running = false;
        listProcess.running = true;
    }

    function startVm(name, useSpice) {
        clearError();
        var confPath = root.resolvedVmDirectory + name + ".conf";
        var cmd = ["quickemu", "--vm", confPath];
        if (useSpice) {
            cmd.push("--display");
            cmd.push("spice");
        }
        startProcess.command = cmd;
        startProcess.running = false;
        startProcess.running = true;
        Logger.i("Quickemu", "Starting VM: " + name + (useSpice ? " (Spice)" : ""));
    }

    function editVm(name) {
        clearError();
        var confPath = root.resolvedVmDirectory + name + ".conf";
        editProcess.command = ["sh", "-c", "editor=$(xdg-mime query default text/plain | sed 's/.desktop//'); if [ -n \"$editor\" ]; then gtk-launch \"$editor\" \"$1\"; else xdg-open \"$1\"; fi", "--", confPath];
        editProcess.running = false;
        editProcess.running = true;
        Logger.i("Quickemu", "Editing VM config: " + confPath);
    }

    function deleteVm(name) {
        clearError();
        var confFile = root.resolvedVmDirectory + name + ".conf";
        var vmDir    = root.resolvedVmDirectory + name;
        deleteProcess.command = ["rm", "-rf", confFile, vmDir];
        deleteProcess.running = false;
        deleteProcess.running = true;
        Logger.i("Quickemu", "Deleting VM: " + name);
    }

    function createVm(osArgs) {
        clearError();
        root.downloadProgress = 0.0;
        createProcess.command = ["sh", "-c", "quickget $1 | tr '\\r' '\\n'", "--", osArgs];
        createProcess.running = false;
        createProcess.running = true;
        Logger.i("Quickemu", "Creating VM: " + osArgs);
    }

    Component.onCompleted: {
        refreshVmList();
        listOsProcess.running = true;
    }
}
