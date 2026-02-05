import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  function copyToClipboard(text) {
    var escaped = text.replace(/'/g, "'\\''")
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"])
  }

  // Shared state for context menu
  property var selectedPeer: null
  property var selectedPeerDelegate: null

  function openPeerContextMenu(peer, delegate, mouseX, mouseY) {
    selectedPeer = peer
    selectedPeerDelegate = delegate
    peerContextMenu.openAtItem(delegate, mouseX, mouseY)
  }

  function filterIPv4(ips) {
    return mainInstance?.filterIPv4(ips) || []
  }

  function getOSIcon(os) {
    if (!os) return "circle-check"
    switch (os.toLowerCase()) {
      case "linux":
        return "brand-debian"
      case "macos":
        return "brand-apple"
      case "ios":
        return "device-mobile"
      case "android":
        return "device-mobile"
      case "windows":
        return "brand-windows"
      default:
        return "circle-check"
    }
  }



  function requireTerminal() {
    if (!isTerminalConfigured) {
      ToastService.showError(
        pluginApi?.tr("toast.terminal-not-configured.title") || "Terminal Not Configured",
        pluginApi?.tr("toast.terminal-not-configured.message") || "Please set a terminal command in plugin settings",
        "alert-circle"
      )
      return false
    }
    return true
  }

  function copySelectedPeerIp() {
    if (selectedPeer) {
      var ips = filterIPv4(selectedPeer.TailscaleIPs)
      if (ips.length > 0) {
        copyToClipboard(ips[0])
        ToastService.showNotice(
          pluginApi?.tr("toast.ip-copied.title") || "IP Copied",
          ips[0],
          "clipboard"
        )
      }
    }
  }

  function sshToSelectedPeer() {
    if (!requireTerminal()) return
    if (selectedPeer) {
      var ips = filterIPv4(selectedPeer.TailscaleIPs)
      if (ips.length > 0) {
        Quickshell.execDetached([root.terminalCommand, "-e", "ssh", ips[0]])
      }
    }
  }

  function pingSelectedPeer() {
    if (!requireTerminal()) return
    if (selectedPeer) {
      var ips = filterIPv4(selectedPeer.TailscaleIPs)
      if (ips.length > 0) {
        Quickshell.execDetached([root.terminalCommand, "-e", "ping", "-c", root.pingCount.toString(), ips[0]])
      }
    }
  }

  function executePeerAction(action, peer) {
    selectedPeer = peer
    switch (action) {
      case "copy-ip":
        copySelectedPeerIp()
        break
      case "ssh":
        sshToSelectedPeer()
        break
      case "ping":
        pingSelectedPeer()
        break
    }
  }

  NContextMenu {
    id: peerContextMenu
    model: [
      { 
        label: pluginApi?.tr("context.copy-ip") || "Copy IP", 
        action: "copy-ip", 
        icon: "clipboard" 
      },
      { 
        label: pluginApi?.tr("context.ssh") || "SSH to host", 
        action: "ssh", 
        icon: "terminal",
        enabled: (root.selectedPeer?.Online || false) && root.isTerminalConfigured
      },
      { 
        label: pluginApi?.tr("context.ping") || "Ping host", 
        action: "ping", 
        icon: "activity",
        enabled: root.isTerminalConfigured
      }
    ]
    onTriggered: function(action) {
      switch (action) {
        case "copy-ip":
          root.copySelectedPeerIp()
          break
        case "ssh":
          root.sshToSelectedPeer()
          break
        case "ping":
          root.pingSelectedPeer()
          break
      }
    }
  }

  onPluginApiChanged: {
    if (pluginApi && pluginApi.mainInstance) {
      mainInstanceChanged()
    }
  }

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined

  readonly property bool hideDisconnected:
    pluginApi?.pluginSettings?.hideDisconnected ??
    pluginApi?.manifest?.metadata?.defaultSettings?.hideDisconnected ??
    false

  readonly property string terminalCommand:
    pluginApi?.pluginSettings?.terminalCommand ||
    pluginApi?.manifest?.metadata?.defaultSettings?.terminalCommand ||
    ""

  readonly property int pingCount:
    pluginApi?.pluginSettings?.pingCount ||
    pluginApi?.manifest?.metadata?.defaultSettings?.pingCount ||
    5

  readonly property string defaultPeerAction:
    pluginApi?.pluginSettings?.defaultPeerAction ||
    pluginApi?.manifest?.metadata?.defaultSettings?.defaultPeerAction ||
    "copy-ip"

  readonly property bool isTerminalConfigured: terminalCommand.trim() !== ""

  readonly property var sortedPeerList: {
    if (!mainInstance?.peerList) return []
    var peers = mainInstance.peerList.slice()
    
    // Filter out disconnected peers if setting is enabled
    if (hideDisconnected) {
      peers = peers.filter(function(peer) {
        return peer.Online === true
      })
    }
    
    peers.sort(function(a, b) {
      // Online peers first
      if (a.Online && !b.Online) return -1
      if (!a.Online && b.Online) return 1
      // Then alphabetically by hostname
      var nameA = (a.HostName || a.DNSName || "").toLowerCase()
      var nameB = (b.HostName || b.DNSName || "").toLowerCase()
      return nameA.localeCompare(nameB)
    })
    return peers
  }

  property real contentPreferredWidth: panelReady ? 400 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? Math.min(500, 100 + (mainInstance?.peerList?.length || 0) * 60) * Style.uiScaleRatio : 0

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    visible: panelReady

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginL

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM
          clip: true

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "network"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: pluginApi?.tr("panel.title") || "Tailscale Network"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: mainInstance?.tailscaleRunning
                ? (mainInstance?.peerList?.length || 0) + " " + (pluginApi?.tr("panel.peers") || "peers")
                : (pluginApi?.tr("panel.not-connected") || "Not connected")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          NText {
            Layout.fillWidth: true
            text: mainInstance?.tailscaleIp || ""
            visible: (mainInstance?.tailscaleRunning ?? false) && (mainInstance?.tailscaleIp ?? false)
            pointSize: Style.fontSizeS
            color: mainIpMouseArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
            
            MouseArea {
              id: mainIpMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() {
                if (mainInstance?.tailscaleIp) {
                  root.copyToClipboard(mainInstance.tailscaleIp)
                  ToastService.showNotice(
                    pluginApi?.tr("toast.ip-copied.title") || "IP Copied",
                    mainInstance.tailscaleIp,
                    "clipboard"
                  )
                }
              }
            }
          }

          // Exit node status
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: exitNodeLayout.implicitHeight + Style.marginS * 2
            visible: mainInstance?.exitNodeStatus !== null && mainInstance?.exitNodeStatus !== undefined
            color: Qt.alpha(Color.mPrimary, 0.1)
            radius: Style.radiusS
            border.width: 1
            border.color: Qt.alpha(Color.mPrimary, 0.3)

            RowLayout {
              id: exitNodeLayout
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: "globe"
                pointSize: Style.fontSizeS
                color: mainInstance?.exitNodeStatus?.Online ? Color.mPrimary : Color.mOnSurfaceVariant
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                NText {
                  text: pluginApi?.tr("panel.exit-node.active") || "Exit Node Active"
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightMedium
                  color: Color.mPrimary
                }

                NText {
                  Layout.fillWidth: true
                  text: {
                    if (!mainInstance?.exitNodeStatus) return ""
                    var ipv4 = filterIPv4(mainInstance.exitNodeStatus.TailscaleIPs)[0]
                    var status = mainInstance.exitNodeStatus.Online ? (pluginApi?.tr("panel.exit-node.online") || "Online") : (pluginApi?.tr("panel.exit-node.offline") || "Offline")
                    return ipv4 ? ipv4 + " • " + status : status
                  }
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                  font.family: Settings.data.ui.fontFixed
                  wrapMode: Text.Wrap
                }
              }
            }
          }

          // Warning banner for missing terminal configuration
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: terminalWarningLayout.implicitHeight + Style.marginM * 2
            visible: !root.isTerminalConfigured
            color: Qt.alpha(Color.mError, 0.1)
            radius: Style.radiusM
            border.width: 1
            border.color: Qt.alpha(Color.mError, 0.3)

            RowLayout {
              id: terminalWarningLayout
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              NIcon {
                icon: "alert-circle"
                pointSize: Style.fontSizeM
                color: Color.mError
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                  text: pluginApi?.tr("panel.terminal-warning.title") || "Terminal Not Configured"
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightMedium
                  color: Color.mError
                }

                NText {
                  Layout.fillWidth: true
                  text: pluginApi?.tr("panel.terminal-warning.message") || "Set a terminal command in settings to enable SSH and ping"
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                  wrapMode: Text.Wrap
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
            visible: (mainInstance?.tailscaleRunning ?? false) && (mainInstance?.peerList?.length ?? 0) > 0
          }

          Flickable {
            id: peerFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: peerListColumn.height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            pressDelay: 0

              ColumnLayout {
              id: peerListColumn
              width: peerFlickable.width
              spacing: Style.marginS

              Repeater {
                model: sortedPeerList

                delegate: ItemDelegate {
                  id: peerDelegate
                  Layout.fillWidth: true
                  Layout.preferredWidth: peerFlickable.width
                  implicitWidth: peerFlickable.width
                  height: 48
                  topPadding: Style.marginS
                  bottomPadding: Style.marginS
                  leftPadding: Style.marginL
                  rightPadding: Style.marginL

                  readonly property var peerData: modelData
                  readonly property string peerIp: filterIPv4(peerData.TailscaleIPs)[0] || ""
                  readonly property string peerHostname: peerData.HostName || peerData.DNSName || "Unknown"
                  readonly property bool peerOnline: peerData.Online || false

                  background: Rectangle {
                    anchors.fill: parent
                    color: peerDelegate.hovered ? Qt.alpha(Color.mPrimary, 0.1) : "transparent"
                    radius: Style.radiusM
                    border.width: peerDelegate.hovered ? 1 : 0
                    border.color: Qt.alpha(Color.mPrimary, 0.3)
                  }

                  contentItem: RowLayout {
                    spacing: Style.marginM

                    NIcon {
                      icon: root.getOSIcon(peerDelegate.peerData.OS)
                      pointSize: Style.fontSizeM
                      color: peerDelegate.peerOnline ? Color.mPrimary : Color.mOnSurfaceVariant
                    }

                    NText {
                      text: peerDelegate.peerHostname
                      color: Color.mOnSurface
                      font.weight: Style.fontWeightMedium
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    NText {
                      text: peerDelegate.peerIp
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      font.family: Settings.data.ui.fontFixed
                      visible: peerDelegate.peerIp !== ""
                      Layout.alignment: Qt.AlignRight
                    }
                  }

                  onClicked: {
                    if (peerDelegate.peerIp) {
                      root.executePeerAction(root.defaultPeerAction, peerDelegate.peerData)
                    }
                  }

                  TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: root.openPeerContextMenu(peerDelegate.peerData, peerDelegate, point.position.x, point.position.y)
                  }
                }
              }

              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginL
                text: pluginApi?.tr("panel.no-peers") || "No connected peers"
                visible: !(mainInstance?.tailscaleRunning ?? false) || (mainInstance?.peerList?.length ?? 0) === 0
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        visible: mainInstance?.tailscaleRunning ?? false
        text: pluginApi?.tr("panel.admin-console") || "Admin Console"
        icon: "external-link"
        onClicked: {
          Qt.openUrlExternally("https://login.tailscale.com/admin")
        }
      }

      NButton {
        Layout.fillWidth: true
        text: mainInstance?.tailscaleRunning 
          ? (pluginApi?.tr("context.disconnect") || "Disconnect")
          : (pluginApi?.tr("context.connect") || "Connect")
        icon: mainInstance?.tailscaleRunning ? "plug-x" : "plug"
        backgroundColor: mainInstance?.tailscaleRunning ? Color.mError : Color.mPrimary
        textColor: mainInstance?.tailscaleRunning ? Color.mOnError : Color.mOnPrimary
        enabled: mainInstance?.tailscaleInstalled ?? false
        onClicked: {
          if (mainInstance) {
            mainInstance.toggleTailscale()
          }
        }
      }
    }
  }
}
