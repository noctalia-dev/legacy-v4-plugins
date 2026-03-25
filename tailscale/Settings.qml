import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  // Local state - initialized from saved settings or defaults
  property int editRefreshInterval:
    pluginApi?.pluginSettings?.refreshInterval ||
    pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval ||
    5000

  property bool editCompactMode:
    pluginApi?.pluginSettings?.compactMode ??
    pluginApi?.manifest?.metadata?.defaultSettings?.compactMode ??
    false

  property bool editShowIpAddress:
    pluginApi?.pluginSettings?.showIpAddress ??
    pluginApi?.manifest?.metadata?.defaultSettings?.showIpAddress ??
    true

  property bool editShowPeerCount:
    pluginApi?.pluginSettings?.showPeerCount ??
    pluginApi?.manifest?.metadata?.defaultSettings?.showPeerCount ??
    true

  property bool editHideDisconnected:
    pluginApi?.pluginSettings?.hideDisconnected ??
    pluginApi?.manifest?.metadata?.defaultSettings?.hideDisconnected ??
    false

  property bool editHideMullvadExitNodes:
    pluginApi?.pluginSettings?.hideMullvadExitNodes ??
    pluginApi?.manifest?.metadata?.defaultSettings?.hideMullvadExitNodes ??
    true

  property string editTerminalCommand:
    pluginApi?.pluginSettings?.terminalCommand ||
    pluginApi?.manifest?.metadata?.defaultSettings?.terminalCommand ||
    ""

  property int editPingCount:
    pluginApi?.pluginSettings?.pingCount ||
    pluginApi?.manifest?.metadata?.defaultSettings?.pingCount ||
    5

  property string editDefaultPeerAction:
    pluginApi?.pluginSettings?.defaultPeerAction ||
    pluginApi?.manifest?.metadata?.defaultSettings?.defaultPeerAction ||
    "copy-ip"

  spacing: Style.marginM

  // Title section
  NText {
    text: pluginApi?.tr("settings.title")
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: pluginApi?.tr("settings.description")
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  // Refresh interval section
  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NLabel {
    label: pluginApi?.tr("settings.refresh-interval")
    description: pluginApi?.tr("settings.refresh-interval-desc") + " (" + root.editRefreshInterval + " ms)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1000
    to: 60000
    stepSize: 1000
    value: root.editRefreshInterval
    onValueChanged: root.editRefreshInterval = value
  }

  // Display options section
  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NLabel {
    label: pluginApi?.tr("settings.display-options")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.compact-mode")
    description: pluginApi?.tr("settings.compact-mode-desc")
    checked: root.editCompactMode
    onToggled: checked => {
      root.editCompactMode = checked
      if (checked) {
        root.editShowIpAddress = false
        root.editShowPeerCount = false
      }
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-ip")
    description: pluginApi?.tr("settings.show-ip-desc")
    checked: root.editShowIpAddress
    enabled: !root.editCompactMode
    onToggled: checked => {
      root.editShowIpAddress = checked
      if (checked) {
        root.editCompactMode = false
      } else if (!checked && !root.editShowPeerCount) {
        root.editCompactMode = true
      }
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-peers")
    description: pluginApi?.tr("settings.show-peers-desc")
    checked: root.editShowPeerCount
    enabled: !root.editCompactMode
    onToggled: checked => {
      root.editShowPeerCount = checked
      if (checked) {
        root.editCompactMode = false
      } else if (!checked && !root.editShowIpAddress) {
        root.editCompactMode = true
      }
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hide-disconnected")
    description: pluginApi?.tr("settings.hide-disconnected-desc")
    checked: root.editHideDisconnected
    onToggled: checked => root.editHideDisconnected = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hide-mullvad-exit-nodes")
    description: pluginApi?.tr("settings.hide-mullvad-exit-nodes-desc")
    checked: root.editHideMullvadExitNodes
    onToggled: checked => root.editHideMullvadExitNodes = checked
  }

  // Terminal section
  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NLabel {
    label: pluginApi?.tr("settings.terminal")
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.terminal-command")
    description: pluginApi?.tr("settings.terminal-command-desc")
    placeholderText: "ghostty"
    text: root.editTerminalCommand
    onTextChanged: root.editTerminalCommand = text
  }

  NLabel {
    label: pluginApi?.tr("settings.ping-count")
    description: pluginApi?.tr("settings.ping-count-desc") + " (" + root.editPingCount + ")"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1
    to: 20
    stepSize: 1
    value: root.editPingCount
    onValueChanged: root.editPingCount = value
  }

  // Peer action section
  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NLabel {
    label: pluginApi?.tr("settings.peer-action")
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.default-peer-action")
    description: pluginApi?.tr("settings.default-peer-action-desc")

    model: [
      { key: "copy-ip", name: pluginApi?.tr("context.copy-ip") },
      { key: "ssh", name: pluginApi?.tr("context.ssh") },
      { key: "ping", name: pluginApi?.tr("context.ping") }
    ]

    currentKey: root.editDefaultPeerAction
    onSelected: key => root.editDefaultPeerAction = key
  }

  // Save function - called by the dialog
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Tailscale", "Cannot save: pluginApi is null")
      return
    }

    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.compactMode = root.editCompactMode
    pluginApi.pluginSettings.showIpAddress = root.editShowIpAddress
    pluginApi.pluginSettings.showPeerCount = root.editShowPeerCount
    pluginApi.pluginSettings.hideDisconnected = root.editHideDisconnected
    pluginApi.pluginSettings.hideMullvadExitNodes = root.editHideMullvadExitNodes
    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.pingCount = root.editPingCount
    pluginApi.pluginSettings.defaultPeerAction = root.editDefaultPeerAction

    pluginApi.saveSettings()

    Logger.i("Tailscale", "Settings saved successfully")
  }
}
