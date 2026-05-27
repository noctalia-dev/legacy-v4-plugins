import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
	id: root
	property var pluginApi: null
	spacing: Style.marginS

	// cfg -> defaults -> hardcoded fallback chain (per AGENTS.md)
	readonly property var cfg: pluginApi?.pluginSettings || ({})
	readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

	property int refreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 3000
	property bool showCountryFlag: cfg.showCountryFlag ?? defaults.showCountryFlag ?? false
	property bool showCityName: cfg.showCityName ?? defaults.showCityName ?? false
	property bool showIp: cfg.showIp ?? defaults.showIp ?? false
	property bool compactMode: cfg.compactMode ?? defaults.compactMode ?? false
	property string clickAction: cfg.clickAction ?? defaults.clickAction ?? "panel"
	property bool relayClickConnects: cfg.relayClickConnects ?? defaults.relayClickConnects ?? true
	property bool confirmDisconnectInLockdown: cfg.confirmDisconnectInLockdown ?? defaults.confirmDisconnectInLockdown ?? true
	property int expiryWarningDays: cfg.expiryWarningDays ?? defaults.expiryWarningDays ?? 7
	property string favoriteCountriesText: ((cfg.favoriteCountries ?? defaults.favoriteCountries ?? []).join(","))

	function saveSettings() {
		if (!pluginApi) {
			Logger.e("Mullvad", "Cannot save: pluginApi is null")
			return
		}
		pluginApi.pluginSettings.refreshInterval = root.refreshInterval
		pluginApi.pluginSettings.showCityName = root.showCityName
		pluginApi.pluginSettings.showIp = root.showIp
		pluginApi.pluginSettings.compactMode = root.compactMode
		pluginApi.pluginSettings.clickAction = root.clickAction
		pluginApi.pluginSettings.relayClickConnects = root.relayClickConnects
		pluginApi.pluginSettings.confirmDisconnectInLockdown = root.confirmDisconnectInLockdown
		pluginApi.pluginSettings.expiryWarningDays = root.expiryWarningDays
		var fav = (root.favoriteCountriesText || "")
			.split(",")
			.map(function (s) { return s.trim().toLowerCase() })
			.filter(function (s) { return s.length === 2 })
		pluginApi.pluginSettings.favoriteCountries = fav
		pluginApi.saveSettings()
		Logger.i("Mullvad", "Settings saved")
	}

	NSpinBox {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.refresh-interval")
		from: 1000; to: 60000; stepSize: 500
		value: root.refreshInterval
		onValueChanged: root.refreshInterval = value
	}

	NToggle {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.show-city")
		checked: root.showCityName
		onToggled: checked => root.showCityName = checked
	}

	NToggle {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.show-ip")
		checked: root.showIp
		onToggled: checked => root.showIp = checked
	}

	NToggle {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.compact-mode")
		checked: root.compactMode
		onToggled: checked => root.compactMode = checked
	}

	NComboBox {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.click-action")
		model: [
			{ key: "toggle", name: pluginApi?.tr("settings.click-toggle") },
			{ key: "panel", name: pluginApi?.tr("settings.click-panel") }
		]
		currentKey: root.clickAction
		onSelected: key => root.clickAction = key
	}

	NToggle {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.relay-click-connects")
		checked: root.relayClickConnects
		onToggled: checked => root.relayClickConnects = checked
	}

	NToggle {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.confirm-disconnect-lockdown")
		checked: root.confirmDisconnectInLockdown
		onToggled: checked => root.confirmDisconnectInLockdown = checked
	}

	NSpinBox {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.expiry-warning-days")
		from: 0; to: 90
		value: root.expiryWarningDays
		onValueChanged: root.expiryWarningDays = value
	}

	NTextInput {
		Layout.fillWidth: true
		label: pluginApi?.tr("settings.favorite-countries")
		text: root.favoriteCountriesText
		onTextChanged: root.favoriteCountriesText = text
	}
}
