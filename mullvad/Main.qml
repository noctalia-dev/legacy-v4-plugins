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

	readonly property int refreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 3000
	readonly property bool showCountryFlag: cfg.showCountryFlag ?? defaults.showCountryFlag ?? true
	readonly property bool showCityName: cfg.showCityName ?? defaults.showCityName ?? false
	readonly property bool showIp: cfg.showIp ?? defaults.showIp ?? false
	readonly property bool compactMode: cfg.compactMode ?? defaults.compactMode ?? false
	readonly property string clickAction: cfg.clickAction ?? defaults.clickAction ?? "toggle"
	readonly property bool relayClickConnects: cfg.relayClickConnects ?? defaults.relayClickConnects ?? true
	readonly property bool confirmDisconnectInLockdown: cfg.confirmDisconnectInLockdown ?? defaults.confirmDisconnectInLockdown ?? true
	readonly property var favoriteCountries: cfg.favoriteCountries ?? defaults.favoriteCountries ?? []
	readonly property int expiryWarningDays: cfg.expiryWarningDays ?? defaults.expiryWarningDays ?? 7

	// ─── Daemon state ───
	property bool installed: false
	property string state: "disconnected"   // connected | connecting | disconnected | disconnecting | error
	property bool locked: false             // status.details.locked_down
	property var currentLocation: null      // { country, city, hostname, ipv4, ipv6, mullvad_exit_ip }
	property var visibleLocation: null      // populated when disconnected
	property bool isRefreshing: false

	function _stateFromJson(s) {
		if (!s) return "error"
		if (s === "connected") return "connected"
		if (s === "connecting") return "connecting"
		if (s === "disconnecting") return "disconnecting"
		if (s === "disconnected") return "disconnected"
		if (s === "error") return "error"
		return "error"
	}

	// ─── Install check ───
	Process {
		id: installCheck
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			root.installed = (code === 0)
			if (root.installed) updateStatus()
		}
	}

	function checkInstalled() {
		installCheck.command = ["which", "mullvad"]
		installCheck.running = true
	}

	// ─── Status polling ───
	Process {
		id: statusProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			root.isRefreshing = false
			var raw = String(statusProcess.stdout.text || "").trim()
			if (code !== 0 || !raw) {
				root.state = "error"
				root.locked = false
				root.currentLocation = null
				root.visibleLocation = null
				return
			}
			try {
				var data = JSON.parse(raw)
				root.state = root._stateFromJson(data.state)
				var d = data.details || {}
				root.locked = !!d.locked_down

				if (root.state === "connected" && d.endpoint) {
					root.currentLocation = {
						"country": d.location?.country || "",
						"city": d.location?.city || "",
						"hostname": d.location?.hostname || "",
						"ipv4": d.location?.ipv4 || d.endpoint.address || "",
						"ipv6": d.location?.ipv6 || "",
						"mullvad_exit_ip": !!d.location?.mullvad_exit_ip
					}
					root.visibleLocation = null
				} else if (d.location) {
					root.currentLocation = null
					root.visibleLocation = {
						"country": d.location.country || "",
						"city": d.location.city || "",
						"ipv4": d.location.ipv4 || "",
						"ipv6": d.location.ipv6 || ""
					}
				}
			} catch (e) {
				Logger.e("Mullvad", "Failed to parse status: " + e)
				root.state = "error"
			}
		}
	}

	function updateStatus() {
		if (!root.installed) {
			root.state = "error"
			return
		}
		root.isRefreshing = true
		statusProcess.command = ["mullvad", "status", "--json"]
		statusProcess.running = true
	}

	Timer {
		id: updateTimer
		interval: refreshInterval
		repeat: true
		running: true
		triggeredOnStart: true
		onTriggered: {
			if (!root.installed) checkInstalled()
			else updateStatus()
		}
	}

	// ─── Connect / disconnect / reconnect ───
	Process {
		id: connectProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			if (code === 0) {
				ToastService.showNotice(pluginApi?.tr("toast.title"), pluginApi?.tr("toast.connected"), "shield")
			} else {
				ToastService.showError(pluginApi?.tr("toast.title"), pluginApi?.tr("toast.connect-failed"), "alert-circle")
			}
			refreshSoon.start()
		}
	}

	Process {
		id: disconnectProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			if (code === 0) {
				ToastService.showNotice(pluginApi?.tr("toast.title"), pluginApi?.tr("toast.disconnected"), "shield")
			}
			refreshSoon.start()
		}
	}

	Process {
		id: reconnectProcess
		onExited: function (code) { refreshSoon.start() }
	}

	Timer {
		id: refreshSoon
		interval: 500
		repeat: false
		onTriggered: updateStatus()
	}

	function connectVpn() {
		if (!root.installed) return
		connectProcess.command = ["mullvad", "connect"]
		connectProcess.running = true
	}

	function disconnectVpn() {
		if (!root.installed) return
		disconnectProcess.command = ["mullvad", "disconnect"]
		disconnectProcess.running = true
	}

	function reconnectVpn() {
		if (!root.installed) return
		reconnectProcess.command = ["mullvad", "reconnect"]
		reconnectProcess.running = true
	}

	function toggleVpn() {
		if (root.state === "connected" || root.state === "connecting") {
			disconnectVpn()
		} else {
			connectVpn()
		}
	}

	// ─── Relay selection (current constraint) ───
	property var relaySelection: null   // { country, city, hostname }
	property bool multihop: false
	property string multihopEntry: ""
	property string ipVersion: "any"

	Process {
		id: relayGetProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			var raw = String(relayGetProcess.stdout.text || "")
			_applyRelayGet(_parseRelayGet(raw))
		}
	}

	function _applyRelayGet(rg) {
		root.relaySelection = { country: rg.country, city: rg.city, hostname: rg.hostname }
		root.multihop = rg.multihop
		root.multihopEntry = rg.multihopEntry
		root.ipVersion = rg.ipVersion
	}

	function refreshRelaySelection() {
		if (!root.installed) return
		relayGetProcess.command = ["mullvad", "relay", "get"]
		relayGetProcess.running = true
	}

	function _parseRelayGet(text) {
		// Output sections:
		//   Generic constraints
		//       Location:               country se
		//       Location:               city se sto
		//       Location:               hostname se sto se-sto-wg-001
		//   WireGuard constraints
		//       IP protocol:            any|v4|v6
		//       Multihop state:         enabled|disabled
		//       Multihop entry:         country se
		var out = {
			country: "", city: "", hostname: "",
			multihop: false, multihopEntry: "",
			ipVersion: "any"
		}
		var lines = text.split("\n")
		for (var i = 0; i < lines.length; i++) {
			var ln = lines[i].trim()
			if (ln.indexOf("Location:") === 0) {
				var rest = ln.substring("Location:".length).trim()
				var parts = rest.split(/\s+/)
				if (parts[0] === "country" && parts.length >= 2) {
					out.country = parts[1]
				} else if (parts[0] === "city" && parts.length >= 3) {
					out.country = parts[1]; out.city = parts[2]
				} else if (parts[0] === "hostname" && parts.length >= 4) {
					out.country = parts[1]; out.city = parts[2]; out.hostname = parts[3]
				}
			} else if (ln.indexOf("Multihop entry:") === 0) {
				var entryRest = ln.substring("Multihop entry:".length).trim()
				var entryParts = entryRest.split(/\s+/)
				if (entryParts[0] === "country" && entryParts.length >= 2) out.multihopEntry = entryParts[1]
			} else if (/^Multihop state:\s+(enabled|disabled)/i.test(ln)) {
				out.multihop = /enabled/i.test(ln)
			} else if (/^IP protocol:\s+(\S+)/i.test(ln)) {
				var v = ln.split(":")[1].trim().toLowerCase()
				out.ipVersion = (v === "v4" || v === "v6") ? v : "any"
			}
		}
		return out
	}

	// ─── Relay list (cached at startup, refreshable) ───
	property var relayList: []   // [{ country, code, cities: [{ city, code, hostnames: [{name, ipv4}] }] }]
	property bool relayListReady: false

	Process {
		id: relayListProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			if (code !== 0) return
			root.relayList = root._parseRelayList(String(relayListProcess.stdout.text || ""))
			root.relayListReady = true
		}
	}

	function refreshRelayList() {
		if (!root.installed) return
		relayListProcess.command = ["mullvad", "relay", "list"]
		relayListProcess.running = true
	}

	function _parseRelayList(text) {
		var out = []
		var lines = text.split("\n")
		var country = null
		var city = null
		var reCountry = /^([^\t].+?)\s+\(([a-z]{2})\)\s*$/
		var reCity = /^\t([^\t].+?)\s+\(([a-z0-9]+)\)/
		var reHost = /^\t\t(\S+)\s+\(([^,)]+)/
		for (var i = 0; i < lines.length; i++) {
			var ln = lines[i]
			if (!ln.trim()) { country = null; city = null; continue }
			var m = ln.match(reCountry)
			if (m) {
				country = { country: m[1], code: m[2], cities: [] }
				out.push(country)
				city = null
				continue
			}
			m = ln.match(reCity)
			if (m && country) {
				city = { city: m[1], code: m[2], hostnames: [] }
				country.cities.push(city)
				continue
			}
			m = ln.match(reHost)
			if (m && city) {
				city.hostnames.push({ name: m[1], ipv4: m[2].trim() })
			}
		}
		return out
	}

	// ─── Apply relay constraint ───
	Process {
		id: setLocationProcess
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			refreshRelaySelection()
			refreshSoon.start()
		}
	}

	function setLocation(countryCode, cityCode, hostname) {
		if (!root.installed) return
		var args = ["mullvad", "relay", "set", "location"]
		if (countryCode) args.push(countryCode)
		if (cityCode) args.push(cityCode)
		if (hostname) args.push(hostname)
		setLocationProcess.command = args
		setLocationProcess.running = true
	}

	// ─── Quick toggles (lockdown / auto-connect / LAN) ───
	property bool lockdownMode: false
	property bool autoConnect: false
	property string lanSharing: "allow"   // "allow" | "block"

	Process {
		id: lockdownGet
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			var raw = String(lockdownGet.stdout.text || "").trim()
			root.lockdownMode = /:\s*on/i.test(raw)
		}
	}

	Process {
		id: autoConnectGet
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			var raw = String(autoConnectGet.stdout.text || "").trim()
			root.autoConnect = /:\s*on/i.test(raw)
		}
	}

	Process {
		id: lanGet
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			var raw = String(lanGet.stdout.text || "").trim()
			root.lanSharing = /block/i.test(raw) ? "block" : "allow"
		}
	}

	function refreshTogglesState() {
		if (!root.installed) return
		lockdownGet.command = ["mullvad", "lockdown-mode", "get"]; lockdownGet.running = true
		autoConnectGet.command = ["mullvad", "auto-connect", "get"]; autoConnectGet.running = true
		lanGet.command = ["mullvad", "lan", "get"]; lanGet.running = true
	}

	Process {
		id: setLockdownProc
		onExited: function (code) {
			ToastService.showNotice(
				pluginApi?.tr("toast.title"),
				pluginApi?.tr(root.lockdownMode ? "toast.lockdown-on" : "toast.lockdown-off"),
				"shield"
			)
			refreshTogglesState()
		}
	}

	Process {
		id: setAutoConnectProc
		onExited: function (code) { refreshTogglesState() }
	}

	Process {
		id: setLanProc
		onExited: function (code) { refreshTogglesState() }
	}

	function setLockdown(on) {
		if (!root.installed) return
		setLockdownProc.command = ["mullvad", "lockdown-mode", "set", on ? "on" : "off"]
		setLockdownProc.running = true
	}

	function setAutoConnect(on) {
		if (!root.installed) return
		setAutoConnectProc.command = ["mullvad", "auto-connect", "set", on ? "on" : "off"]
		setAutoConnectProc.running = true
	}

	function setLanSharing(allow) {
		if (!root.installed) return
		setLanProc.command = ["mullvad", "lan", "set", allow ? "allow" : "block"]
		setLanProc.running = true
	}

	// ─── Multihop / IP version setters ───
	Process {
		id: multihopProc
		onExited: function (code) { refreshRelaySelection() }
	}

	Process {
		id: multihopEntryProc
		onExited: function (code) { refreshRelaySelection() }
	}

	Process {
		id: ipVersionProc
		onExited: function (code) { refreshRelaySelection() }
	}

	function setMultihop(on) {
		if (!root.installed) return
		multihopProc.command = ["mullvad", "relay", "set", "multihop", on ? "on" : "off"]
		multihopProc.running = true
	}

	function setMultihopEntry(countryCode) {
		if (!root.installed) return
		multihopEntryProc.command = ["mullvad", "relay", "set", "entry", "location", countryCode]
		multihopEntryProc.running = true
	}

	function setIpVersion(v) {
		if (!root.installed) return
		ipVersionProc.command = ["mullvad", "relay", "set", "ip-version", v]
		ipVersionProc.running = true
	}

	// ─── Account expiry polling ───
	property string accountExpiry: ""
	property int accountDaysLeft: 9999

	Process {
		id: accountProc
		stdout: StdioCollector {}
		stderr: StdioCollector {}
		onExited: function (code) {
			if (code !== 0) return
			var raw = String(accountProc.stdout.text || "")
			var m = raw.match(/Expires at:\s+(\S+)/)
			if (!m) return
			root.accountExpiry = m[1]
			var now = new Date()
			var exp = new Date(m[1])
			if (!isNaN(exp.getTime())) {
				root.accountDaysLeft = Math.floor((exp.getTime() - now.getTime()) / 86400000)
			}
		}
	}

	function refreshAccount() {
		if (!root.installed) return
		accountProc.command = ["mullvad", "account", "get"]
		accountProc.running = true
	}

	Timer {
		id: accountTimer
		interval: 5 * 60 * 1000
		repeat: true
		running: true
		triggeredOnStart: false
		onTriggered: refreshAccount()
	}

	// ─── IPC ───
	IpcHandler {
		target: "plugin:mullvad"

		function toggle()      { toggleVpn() }
		function connect()     { connectVpn() }
		function disconnect()  { disconnectVpn() }
		function reconnect()   { reconnectVpn() }

		function togglePanel() {
			pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen))
		}

		function refresh() {
			updateStatus()
			refreshRelaySelection()
			refreshTogglesState()
		}

		function status(): string {
			return JSON.stringify({
				"installed": root.installed,
				"state": root.state,
				"locked": root.locked,
				"country": root.currentLocation?.country || "",
				"city": root.currentLocation?.city || "",
				"hostname": root.currentLocation?.hostname || "",
				"ip": root.currentLocation?.ipv4 || "",
				"lockdown": root.lockdownMode,
				"autoConnect": root.autoConnect,
				"lanSharing": root.lanSharing,
				"multihop": root.multihop,
				"daysLeft": root.accountDaysLeft,
				"relaySelection": root.relaySelection,
				"relayListLen": (root.relayList || []).length
			})
		}

		function setLocation(country: string, city: string, hostname: string): void {
			root.setLocation(country || "", city || "", hostname || "")
		}

		function setLockdown(on: bool): void {
			root.setLockdown(on)
		}
	}

	onInstalledChanged: {
		// Once `which mullvad` succeeds, kick off the secondary state pulls.
		if (installed) {
			refreshRelayList()
			refreshRelaySelection()
			refreshTogglesState()
			refreshAccount()
		}
	}

	Component.onCompleted: checkInstalled()
}
