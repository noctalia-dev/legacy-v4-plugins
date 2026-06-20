import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property string platform: cfg.platform ?? defaults.platform
    readonly property string bin: platform === 'gitlab' ? 'glab' : 'gh'
    readonly property string repo: cfg.repo ?? ""
    readonly property string group: cfg.group ?? ""
    readonly property bool hasScope: (group && group.length > 0) || (repo && repo.length > 0)
    readonly property int refreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 60

    property bool loading: false
    property string lastError: ""
    property string lastUpdate: ""
    property bool isBinInstalled: false
    property bool isAuthenticated: false

    property string username: ""
    property string avatarUrl: ""
    property string bio: ""

    property int issuesCount: 0
    property var issuesList: []
    property int prsCount: 0
    property var prsList: []

    // Counts pending fetches for the parallel issue+pr stage so we can detect the join
    property int pendingFetches: 0

    function setError(msg) {
        root.lastError = msg || "";
        if (msg)
            Logger.e("Git Companion", msg);
    }

    function parseJsonArray(stdout) {
        const raw = (stdout || "").trim();
        if (!raw)
            return [];
        try {
            const data = JSON.parse(raw);
            if (Array.isArray(data))
                return data;
            if (data && Array.isArray(data.items))
                return data.items;
            if (data && Array.isArray(data.data))
                return data.data;
        } catch (e) {}
        return [];
    }

    function clearData() {
        root.issuesList = [];
        root.issuesCount = 0;
        root.prsList = [];
        root.prsCount = 0;
    }

    function scopeArgs() {
        const g = (root.group || "").trim();
        const r = (root.repo || "").trim();
        const groupFlag = root.platform === 'gitlab' ? "--group" : "--owner";
        if (g)
            return [groupFlag, g];
        if (r)
            return ["--repo", r];
        return [];
    }

    // kind: "pr" | "issue"
    function listCommand(kind) {
        if (root.platform === 'gitlab') {
            const sub = kind === 'pr' ? 'mr' : 'issue';
            return ["glab", sub, "list"].concat(scopeArgs()).concat(["--assignee=@me", "--output", "json"]);
        }
        const sub = kind === 'pr' ? 'prs' : 'issues';
        const filter = kind === 'pr' ? "--author=@me" : "--assignee=@me";
        return ["gh", "search", sub, filter, "--state=open", "--json", "number,title,url,repository", "--limit", "15"].concat(scopeArgs());
    }

    function normalize(raw, kind) {
        if (root.platform === 'gitlab') {
            const prefix = kind === 'pr' ? '!' : '#';
            return {
                title: raw.title || "",
                url: raw.web_url || "",
                ref: (raw.references && raw.references.full) || (prefix + (raw.iid || ""))
            };
        }
        const repoName = (raw.repository && (raw.repository.nameWithOwner || raw.repository.name)) || "";
        return {
            title: raw.title || "",
            url: raw.url || "",
            ref: repoName + "#" + (raw.number || "")
        };
    }

    function openUrl(url) {
        if (!url)
            return;
        Quickshell.execDetached(["xdg-open", url]);
        if (pluginApi?.panelOpenScreen)
            pluginApi.closePanel(pluginApi.panelOpenScreen);
    }

    function refresh() {
        if (!pluginApi)
            return;
        Logger.i("Git Companion", "Refreshing...");
        root.lastError = "";
        root.loading = true;

        // GitLab requires a scope; GitHub works globally
        if (platform === 'gitlab' && !hasScope) {
            root.loading = false;
            root.clearData();
            return;
        }
        binProcess.running = true;
    }

    function startListFetches() {
        if (!root.isAuthenticated)
            return;
        root.pendingFetches = 2;
        issueProcess.running = true;
        prProcess.running = true;
    }

    function finishFetch() {
        root.pendingFetches = Math.max(0, root.pendingFetches - 1);
        if (root.pendingFetches === 0) {
            root.loading = false;
            root.lastUpdate = new Date().toLocaleTimeString();
        }
    }

    Component.onCompleted: refresh()

    onPlatformChanged: refresh()
    onRepoChanged: refresh()
    onGroupChanged: refresh()

    Process {
        id: binProcess
        command: [root.bin, "--version"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.isBinInstalled = false;
                root.isAuthenticated = false;
                root.setError(pluginApi?.tr("panel.bin-not-installed", {
                    bin: root.bin
                }) || "");
                root.loading = false;
                return;
            }
            root.isBinInstalled = true;
            authProcess.running = true;
        }
    }

    Process {
        id: authProcess
        command: [root.bin, "auth", "status"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.isAuthenticated = false;
                root.setError(pluginApi?.tr("panel.auth-error", {
                    bin: root.bin
                }) || "");
                root.loading = false;
                return;
            }
            root.isAuthenticated = true;
            userProcess.running = true;
        }
    }

    Process {
        id: userProcess
        command: [root.bin, "api", "user"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    root.username = data.username || data.login || "";
                    root.avatarUrl = data.avatar_url || "";
                    root.bio = data.bio || "";
                } catch (e) {
                    Logger.w("Git Companion", "Could not parse user response: " + e.message);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                Logger.w("Git Companion", "User fetch exited with code " + exitCode);
            }
            root.startListFetches();
        }
    }

    Process {
        id: issueProcess
        command: root.listCommand("issue")
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = root.parseJsonArray(this.text);
                root.issuesList = raw.map(item => root.normalize(item, "issue"));
                root.issuesCount = root.issuesList.length;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.issuesList = [];
                root.issuesCount = 0;
                Logger.w("Git Companion", "Issue list exited with code " + exitCode);
            }
            root.finishFetch();
        }
    }

    Process {
        id: prProcess
        command: root.listCommand("pr")
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = root.parseJsonArray(this.text);
                root.prsList = raw.map(item => root.normalize(item, "pr"));
                root.prsCount = root.prsList.length;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.prsList = [];
                root.prsCount = 0;
                Logger.w("Git Companion", "PR list exited with code " + exitCode);
            }
            root.finishFetch();
        }
    }

    Timer {
        interval: root.refreshInterval * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "plugin:git-companion"

        function toggle() {
            if (root.pluginApi) {
                root.pluginApi.withCurrentScreen(screen => {
                    root.pluginApi.openPanel(screen);
                });
            }
        }

        function refresh() {
            root.refresh();
        }
    }
}
