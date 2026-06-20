import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
	id: root
	property var pluginApi: null
	property ShellScreen screen

	readonly property var main: pluginApi?.mainInstance
	readonly property string vpnState: main?.state ?? "disconnected"
	readonly property bool locked: main?.locked ?? false
	readonly property bool installed: main?.installed ?? false

	readonly property var geometryPlaceholder: panelContainer
	readonly property bool allowAttach: true

	property real contentPreferredWidth: 380 * Style.uiScaleRatio
	property real contentPreferredHeight: contentColumn.implicitHeight + Style.marginL * 2

	anchors.fill: parent

	function _flag(code) {
		var c = (code || "").toUpperCase()
		if (c.length !== 2) return ""
		return String.fromCodePoint(0x1F1E6 + c.charCodeAt(0) - 65, 0x1F1E6 + c.charCodeAt(1) - 65)
	}

	function _stateLabel() {
		if (!installed) return pluginApi?.tr("state.not-installed")
		if (vpnState === "error") return pluginApi?.tr("state.error")
		if (locked && vpnState !== "connected") return pluginApi?.tr("state.blocked")
		return pluginApi?.tr("state." + vpnState)
	}

	function _countryName(code) {
		var rl = main?.relayList || []
		for (var i = 0; i < rl.length; i++) if (rl[i].code === code) return rl[i].country
		return code ? code.toUpperCase() : ""
	}

	// Reactive bindings - QML tracks each property access here
	readonly property string _selectionLabel: {
		var loc = main ? main.currentLocation : null
		var sel = main ? main.relaySelection : null
		var rl = main ? main.relayList : []
		if (vpnState === "connected" && loc && loc.country) {
			var s = _flag(loc.country) + " " + (loc.city || _countryName(loc.country))
			if (loc.hostname) s += " / " + loc.hostname
			return s.trim()
		}
		if (sel && sel.country) {
			var t = _flag(sel.country) + " " + _countryName(sel.country)
			if (sel.city) t += " / " + sel.city
			if (sel.hostname) t += " / " + sel.hostname
			return t.trim()
		}
		return pluginApi?.tr("action.auto-select")
	}

	Rectangle {
		id: panelContainer
		anchors.fill: parent
		color: "transparent"
	}

	ColumnLayout {
		id: contentColumn
		anchors.fill: parent
		anchors.margins: Style.marginL
		spacing: Style.marginL

		// ─── Header ───
		ColumnLayout {
			Layout.fillWidth: true
			spacing: Style.marginS

			RowLayout {
				Layout.fillWidth: true
				spacing: Style.marginL

				MullvadIcon {
					pointSize: Style.fontSizeXL
					crossed: root.vpnState === "error" || !root.installed
					color: {
						if (root.vpnState === "connected") return Color.mPrimary
						if (root.locked) return Color.mError
						return Color.mOnSurface
					}
				}

				ColumnLayout {
					Layout.fillWidth: true
					spacing: Style.marginXXS
					NText {
						text: root._stateLabel()
						pointSize: Style.fontSizeL
						color: Color.mOnSurface
					}
					NText {
						Layout.fillWidth: true
						pointSize: Style.fontSizeS
						color: Color.mOnSurfaceVariant
						wrapMode: Text.Wrap
						// Read every property upfront so QML's binding tracker
						// registers them all as dependencies (otherwise props
						// only read inside conditionals get missed).
						readonly property var _m: root.main
						readonly property var _loc: _m ? _m.currentLocation : null
						readonly property var _sel: _m ? _m.relaySelection : null
						readonly property bool _mh: _m ? _m.multihop : false
						readonly property string _mhe: _m ? (_m.multihopEntry || "") : ""
						readonly property string _iv: _m ? (_m.ipVersion || "any") : "any"
						readonly property bool _ld: _m ? _m.lockdownMode : false
						readonly property bool _ac: _m ? _m.autoConnect : false
						readonly property string _lan: _m ? (_m.lanSharing || "allow") : "allow"
						text: {
							var parts = []
							if (root.vpnState === "connected" && _loc && _loc.country) {
								var s = (_loc.city || root._countryName(_loc.country))
								if (_loc.hostname) s += " / " + _loc.hostname
								parts.push(s)
							} else if (_sel && _sel.country) {
								var t = root._countryName(_sel.country)
								if (_sel.city) t += " / " + _sel.city
								if (_sel.hostname) t += " / " + _sel.hostname
								parts.push(t)
							} else {
								parts.push(root.pluginApi?.tr("action.auto-select"))
							}
							if (_mh) parts.push(_mhe ? root.pluginApi?.tr("badges.multihop-via", { country: root._countryName(_mhe) }) : root.pluginApi?.tr("badges.multihop"))
							if (_iv !== "any") parts.push(root.pluginApi?.tr("badges.ip-version", { version: _iv }))
							if (_ld) parts.push(root.pluginApi?.tr("badges.lockdown"))
							if (_ac) parts.push(root.pluginApi?.tr("badges.auto-connect"))
							if (_lan === "block") parts.push(root.pluginApi?.tr("badges.lan-blocked"))
							return parts.join(" · ")
						}
					}
					NText {
						visible: !!(root.main?.currentLocation?.ipv4)
						text: root.main?.currentLocation?.ipv4 || ""
						font.family: Settings.data.ui.fontFixed
						pointSize: Style.fontSizeS
						color: Color.mOnSurfaceVariant
						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							onClicked: {
								Quickshell.clipboardText = parent.text
								ToastService.showNotice(pluginApi?.tr("toast.title"), parent.text, "copy")
							}
						}
					}
				}
			}

			NButton {
				Layout.fillWidth: true
				text: root.vpnState === "connected"
					? pluginApi?.tr("action.disconnect")
					: (root.vpnState === "connecting" ? pluginApi?.tr("action.cancel") : pluginApi?.tr("action.connect"))
				enabled: root.installed
				onClicked: root.main?.toggleVpn()
			}

			// Account expiry warning
			Rectangle {
				visible: root.installed && root.main?.accountDaysLeft !== undefined && root.main.accountDaysLeft <= (root.main?.expiryWarningDays ?? 7)
				Layout.fillWidth: true
				Layout.preferredHeight: expiryText.implicitHeight + Style.marginS * 2
				color: Color.mError
				radius: Style.radiusS
				NText {
					id: expiryText
					anchors.fill: parent
					anchors.margins: Style.marginS
					text: (root.main?.accountDaysLeft ?? 0) <= 0
						? pluginApi?.tr("account.expired")
						: pluginApi?.tr("account.expires-in", { days: root.main?.accountDaysLeft ?? 0 })
					color: Color.mOnError
					wrapMode: Text.Wrap
				}
			}
		}

		// ─── Quick toggles ───
		ColumnLayout {
			Layout.fillWidth: true
			spacing: Style.marginM

			NToggle {
				Layout.fillWidth: true
				label: pluginApi?.tr("toggles.lockdown")
				description: pluginApi?.tr("toggles.lockdown-tooltip")
				checked: root.main?.lockdownMode ?? false
				onToggled: checked => root.main?.setLockdown(checked)
			}

			NToggle {
				Layout.fillWidth: true
				label: pluginApi?.tr("toggles.auto-connect")
				description: pluginApi?.tr("toggles.auto-connect-tooltip")
				checked: root.main?.autoConnect ?? false
				onToggled: checked => root.main?.setAutoConnect(checked)
			}

			NToggle {
				Layout.fillWidth: true
				label: pluginApi?.tr("toggles.lan")
				description: pluginApi?.tr("toggles.lan-tooltip")
				checked: (root.main?.lanSharing ?? "allow") === "allow"
				onToggled: checked => root.main?.setLanSharing(checked)
			}
		}

		// ─── Relay picker ───
		ColumnLayout {
			Layout.fillWidth: true
			spacing: Style.marginS

			RowLayout {
				Layout.fillWidth: true
				NTextInput {
					id: searchInput
					Layout.fillWidth: true
					placeholderText: pluginApi?.tr("relay.search-placeholder")
					onTextChanged: relayModel.refresh()
				}
				NIconButton {
					icon: "refresh"
					tooltipText: pluginApi?.tr("action.refresh-relays")
					onClicked: root.main?.refreshRelayList()
				}
			}

			NButton {
				Layout.fillWidth: true
				text: pluginApi?.tr("action.auto-select")
				onClicked: {
					root.main?.setLocation("", "", "")
					if (root.main?.relayClickConnects ?? true) root.main?.connectVpn()
				}
			}

			NListView {
				id: relayListView
				Layout.fillWidth: true
				Layout.preferredHeight: 160
				clip: true
				model: relayModel
				spacing: Style.marginXXS
				horizontalPolicy: ScrollBar.AlwaysOff
				verticalPolicy: ScrollBar.AsNeeded

				delegate: Rectangle {
					width: relayListView.width
					height: rowText.implicitHeight + Style.marginS * 2
					color: rowMouse.containsMouse ? Color.mHover :
						(model.isCurrent ? Color.mPrimary : "transparent")
					radius: Style.radiusS

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: Style.marginM
						anchors.rightMargin: Style.marginM
						spacing: Style.marginS

						NText {
							id: rowText
							Layout.fillWidth: true
							text: model.label
							pointSize: Style.fontSizeS
							color: model.isCurrent ? Color.mOnPrimary : Color.mOnSurface
							elide: Text.ElideRight
						}
						NText {
							visible: model.kind === "country"
							text: String(model.count)
							pointSize: Style.fontSizeXS
							color: Color.mOnSurfaceVariant
						}
					}

					MouseArea {
						id: rowMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: relayModel.activate(index)
					}
				}

				NText {
					visible: relayModel.count === 0
					anchors.centerIn: parent
					text: (root.main?.relayList?.length ?? 0) === 0
						? pluginApi?.tr("relay.loading")
						: pluginApi?.tr("relay.no-results")
					color: Color.mOnSurfaceVariant
				}
			}
		}

		// ─── Advanced (collapsed) ───
		NCollapsible {
			Layout.fillWidth: true
			label: pluginApi?.tr("advanced.title")
			expanded: false

			ColumnLayout {
				Layout.fillWidth: true
				spacing: Style.marginXS

				NToggle {
					Layout.fillWidth: true
					label: pluginApi?.tr("advanced.multihop")
					description: pluginApi?.tr("advanced.multihop-tooltip")
					checked: root.main?.multihop ?? false
					onToggled: checked => root.main?.setMultihop(checked)
				}

				NComboBox {
					Layout.fillWidth: true
					visible: root.main?.multihop ?? false
					label: pluginApi?.tr("advanced.multihop-entry")
					model: (root.main?.relayList || []).map(function (c) { return ({ key: c.code, name: c.country }) })
					currentKey: root.main?.multihopEntry ?? ""
					onSelected: key => root.main?.setMultihopEntry(key)
				}

				NComboBox {
					Layout.fillWidth: true
					label: pluginApi?.tr("advanced.ip-version")
					model: [
						{ key: "any", name: "any" },
						{ key: "v4", name: "v4" },
						{ key: "v6", name: "v6" }
					]
					currentKey: root.main?.ipVersion ?? "any"
					onSelected: key => root.main?.setIpVersion(key)
				}
			}
		}
	}

	ListModel {
		id: relayModel

		function refresh() {
			clear()
			var query = (searchInput.text || "").toLowerCase().trim()
			var rl = root.main?.relayList || []
			var fav = root.main?.favoriteCountries || []
			var sel = root.main?.relaySelection || { country: "", city: "", hostname: "" }

			function matches(c, ci, h) {
				if (!query) return true
				var hay = (c.country + " " + c.code + " " +
					(ci ? ci.city + " " + ci.code : "") + " " +
					(h ? h.name : "")).toLowerCase()
				return hay.indexOf(query) !== -1
			}

			var ordered = rl.slice()
			ordered.sort(function (a, b) {
				var af = fav.indexOf(a.code) !== -1, bf = fav.indexOf(b.code) !== -1
				if (af !== bf) return af ? -1 : 1
				return a.country.localeCompare(b.country)
			})

			for (var i = 0; i < ordered.length; i++) {
				var c = ordered[i]
				if (!matches(c, null, null) && !c.cities.some(function (ci) {
						return matches(c, ci, null) || ci.hostnames.some(function (h) { return matches(c, ci, h) })
					})) continue

				append({
					"kind": "country",
					"flag": root._flag(c.code),
					"label": c.country,
					"countryCode": c.code,
					"cityCode": "",
					"hostname": "",
					"count": c.cities.reduce(function (n, ci) { return n + ci.hostnames.length }, 0),
					"isCurrent": sel.country === c.code && !sel.city
				})

				if (!query) continue   // collapsed by default

				for (var j = 0; j < c.cities.length; j++) {
					var ci = c.cities[j]
					if (!matches(c, ci, null) && !ci.hostnames.some(function (h) { return matches(c, ci, h) })) continue
					append({
						"kind": "city",
						"flag": "  " + root._flag(c.code),
						"label": "  " + ci.city,
						"countryCode": c.code,
						"cityCode": ci.code,
						"hostname": "",
						"count": ci.hostnames.length,
						"isCurrent": sel.country === c.code && sel.city === ci.code && !sel.hostname
					})
					for (var k = 0; k < ci.hostnames.length; k++) {
						var h = ci.hostnames[k]
						if (!matches(c, ci, h)) continue
						append({
							"kind": "host",
							"flag": "    ",
							"label": "    " + h.name + "  " + h.ipv4,
							"countryCode": c.code,
							"cityCode": ci.code,
							"hostname": h.name,
							"count": 0,
							"isCurrent": sel.hostname === h.name
						})
					}
				}
			}
		}

		function activate(index) {
			if (index < 0 || index >= count) return
			var row = get(index)
			root.main?.setLocation(row.countryCode, row.cityCode, row.hostname)
			if (root.main?.relayClickConnects ?? true) root.main?.connectVpn()
		}
	}

	Connections {
		target: root.main
		function onRelayListChanged() { relayModel.refresh() }
		function onRelayListReadyChanged() { relayModel.refresh() }
		function onRelaySelectionChanged() { relayModel.refresh() }
		function onFavoriteCountriesChanged() { relayModel.refresh() }
	}

	onVisibleChanged: if (visible) {
		relayModel.refresh()
		// Re-fetch in case the list isn't loaded yet
		if ((main?.relayList?.length ?? 0) === 0) main?.refreshRelayList()
	}

	Component.onCompleted: relayModel.refresh()
}
