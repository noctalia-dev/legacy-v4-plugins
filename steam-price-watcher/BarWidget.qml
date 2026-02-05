import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property bool isVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Widget settings
  property var watchlist: cfg.watchlist || defaults.watchlist || []
  property int checkInterval: cfg.checkInterval ?? defaults.checkInterval ?? 30
  property var notifiedGames: cfg.notifiedGames || defaults.notifiedGames || []
  property string currency: cfg.currency || defaults.currency || "br"
  property string currencySymbol: cfg.currencySymbol || defaults.currencySymbol || "R$"

  // State
  property var gamesOnTarget: []
  property bool loading: false
  property bool hasNotifications: gamesOnTarget.length > 0

  readonly property real visualContentWidth: {
    if (isVertical) return Style.capsuleHeight;
    var iconWidth = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textWidth = gamesText ? (gamesText.implicitWidth + Style.marginS) : 60;
    return iconWidth + textWidth + Style.marginM * 2 + 24;
  }

  readonly property real visualContentHeight: {
    if (!isVertical) return Style.capsuleHeight;
    var iconHeight = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textHeight = gamesText ? gamesText.implicitHeight : 16;
    return Math.max(iconHeight, textHeight) + Style.marginS * 2;
  }

  readonly property real contentWidth: Math.max(60, isVertical ? Style.capsuleHeight : visualContentWidth)
  readonly property real contentHeight: Math.max(32, isVertical ? visualContentHeight : Style.capsuleHeight)

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Update timer
  Timer {
    id: updateTimer
    interval: checkInterval * 60000
    running: watchlist.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: checkPrices()
  }

  // Watch for configuration changes
  onCfgChanged: {
    watchlist = cfg.watchlist || defaults.watchlist || [];
    notifiedGames = cfg.notifiedGames || defaults.notifiedGames || [];
    currency = cfg.currency || defaults.currency || "br";
    currencySymbol = cfg.currencySymbol || defaults.currencySymbol || "R$";
    Logger.d("Steam", "Steam Price Watcher: Configuration updated");
    Logger.d("Steam", "New watchlist length:", watchlist.length);
  }

  Component.onCompleted: {
    Logger.d("Steam", "Steam Price Watcher Widget loaded");
    Logger.d("Steam", "Watchlist:", JSON.stringify(watchlist));
  }

  function checkPrices() {
    if (loading || watchlist.length === 0) return;
    loading = true;
    
    // Limpar lista de jogos que atingiram o alvo para revalidar
    gamesOnTarget = [];
    
    var games = [];
    for (var i = 0; i < watchlist.length; i++) {
      var game = watchlist[i];
      checkGamePrice(game);
    }
  }

  property int pendingChecks: 0
  property var activeProcesses: []

  Component {
    id: processComponent
    Process {
      property var gameData: null
      property string gameAppId: ""
      running: false
      command: ["curl", "-s", "https://store.steampowered.com/api/appdetails?appids=" + gameAppId + "&cc=" + root.currency]
      stdout: StdioCollector {}
      
      onExited: (exitCode) => {
        if (exitCode === 0) {
          try {
            var response = JSON.parse(stdout.text);
            var appData = response[gameAppId];
            if (appData && appData.success && appData.data) {
              var priceData = appData.data.price_overview;
              if (priceData) {
                var currentPrice = priceData.final / 100;
                gameData.currentPrice = currentPrice;
                gameData.currency = priceData.currency;
                
                if (currentPrice <= gameData.targetPrice) {
                  root.addGameOnTarget(gameData);
                }
              }
            }
          } catch (e) {
            Logger.e("steam-price-watcher", "Error parsing Steam API response:", e);
          }
        }
        
        root.pendingChecks--;
        if (root.pendingChecks === 0) {
          root.loading = false;
        }
        
        destroy();
      }
    }
  }

  function checkGamePrice(game) {
    pendingChecks++;
    
    var process = processComponent.createObject(root, {
      gameData: game,
      gameAppId: game.appId.toString()
    });
    process.running = true;
  }

  function addGameOnTarget(game) {
    Logger.d("Steam", "Steam Price Watcher: Game on target detected:", game.name, game.appId);
    
    // Check if already in list
    for (var i = 0; i < gamesOnTarget.length; i++) {
      if (gamesOnTarget[i].appId === game.appId) {
        Logger.d("Steam", "Steam Price Watcher: Game already in target list");
        return;
      }
    }
    
    var temp = gamesOnTarget.slice();
    temp.push(game);
    gamesOnTarget = temp;
    
    // Send notification if not already notified
    var wasNotified = isGameNotified(game.appId);
    Logger.d("Steam", "Steam Price Watcher: Was game already notified?", wasNotified);
    
    if (!wasNotified) {
      Logger.d("Steam", "Steam Price Watcher: Calling sendNotification");
      sendNotification(game);
      markGameAsNotified(game.appId);
    } else {
      Logger.d("Steam", "Steam Price Watcher: Skipping notification - already notified");
    }
  }

  function isGameNotified(appId) {
    return notifiedGames.indexOf(appId) !== -1;
  }

  function markGameAsNotified(appId) {
    if (pluginApi && pluginApi.pluginSettings) {
      var temp = notifiedGames.slice();
      temp.push(appId);
      pluginApi.pluginSettings.notifiedGames = temp;
      pluginApi.saveSettings();
    }
  }

  function sendNotification(game) {
    Logger.d("Steam", "Steam Price Watcher: Sending notification for", game.name);
    
    var symbol = root.currencySymbol;
    
    // Usar variável de ambiente HOME
    var homeProcess = Qt.createQmlObject(`
      import Quickshell.Io
      Process {
        running: true
        command: ["sh", "-c", "echo $HOME"]
        stdout: StdioCollector {}
      }
    `, root, "homeProcess");
    
    homeProcess.exited.connect((exitCode) => {
      var homeDir = homeProcess.stdout.text.trim();
      var iconPath = homeDir + "/.config/noctalia/plugins/steam-price-watcher/logo-notification.png";
      
      Logger.d("Steam", "Steam Price Watcher: Icon path:", iconPath);
      
      var notifyCmd = '["notify-send", "-a", "Noctalia Shell", "-i", "' + iconPath + '", "🎮 Steam Price Watcher", "' + game.name + ' atingiu ' + symbol + ' ' + game.currentPrice.toFixed(2) + '!\\nPreço alvo: ' + symbol + ' ' + game.targetPrice.toFixed(2) + '"]';
      
      var notifyProcess = Qt.createQmlObject(
        'import Quickshell.Io; Process { running: true; command: ' + notifyCmd + '; onExited: (exitCode) => { Logger.d("Steam", "Steam Price Watcher: Notification sent, exit code:", exitCode); destroy(); } }',
        root,
        "notifyProcess"
      );
      
      homeProcess.destroy();
    });
  }

  readonly property string displayText: {
    if (loading) return pluginApi?.tr("steam-price-watcher.loading") || "Verificando...";
    if (watchlist.length === 0) return pluginApi?.tr("steam-price-watcher.no-games") || "Sem jogos";
    if (hasNotifications) {
      var gameWord = gamesOnTarget.length === 1 ? 
        (pluginApi?.tr("steam-price-watcher.game") || "jogo") : 
        (pluginApi?.tr("steam-price-watcher.games") || "jogos");
      var ofWord = pluginApi?.tr("steam-price-watcher.of") || "de";
      return `${gamesOnTarget.length} ${ofWord} ${watchlist.length} ${gameWord}`;
    }
    var gameWord = watchlist.length === 1 ? 
      (pluginApi?.tr("steam-price-watcher.game") || "jogo") : 
      (pluginApi?.tr("steam-price-watcher.games") || "jogos");
    return `${watchlist.length} ${gameWord}`;
  }

  readonly property string tooltipText: {
    if (hasNotifications) {
      var text = pluginApi?.tr("steam-price-watcher.tooltip.on-target") || "Jogos no preço-alvo:";
      for (var i = 0; i < gamesOnTarget.length; i++) {
        text += `\n• ${gamesOnTarget[i].name} - R$ ${gamesOnTarget[i].currentPrice.toFixed(2)}`;
      }
      return text + "\n\n" + (pluginApi?.tr("steam-price-watcher.tooltip.click") || "Clique para ver detalhes");
    }
    if (watchlist.length > 0) {
      var gameWord = watchlist.length === 1 ? 
        (pluginApi?.tr("steam-price-watcher.game") || "jogo") : 
        (pluginApi?.tr("steam-price-watcher.games") || "jogos");
      return (pluginApi?.tr("steam-price-watcher.tooltip.monitoring") || "Monitorando") + ` ${watchlist.length} ${gameWord}`;
    }
    return pluginApi?.tr("steam-price-watcher.tooltip.no-games") || "Nenhum jogo cadastrado";
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: isVertical ? 0 : Style.marginM
      anchors.rightMargin: isVertical ? 0 : 32
      anchors.topMargin: isVertical ? Style.marginS : 0
      anchors.bottomMargin: isVertical ? Style.marginS : 0
      spacing: Style.marginS
      visible: !isVertical

      Item {
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: iconSize
        Layout.alignment: Qt.AlignVCenter

        readonly property int iconSize: Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.5) : 16

        NIcon {
          anchors.fill: parent
          icon: loading ? "loader" : "package"
          color: hasNotifications ? Color.mPrimary : Color.mOnSurface
          pointSize: parent.iconSize

          RotationAnimator on rotation {
            running: loading
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }

        // Notification indicator
        Rectangle {
          visible: hasNotifications && !loading
          width: 8
          height: 8
          radius: 4
          color: Color.mError
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.rightMargin: -2
          anchors.topMargin: -2
          border.color: visualCapsule.color
          border.width: 1
        }
      }

      NText {
        id: gamesText
        text: displayText
        color: hasNotifications ? Color.mPrimary : Color.mOnSurface
        pointSize: Style.barFontSize
        applyUiScale: false
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: {
      // Open plugin panel near this widget
      pluginApi.openPanel(root.screen, root)
    }
    onEntered: {
      if (tooltipText) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection());
      }
    }

    onExited: {
      TooltipService.hide();
    }
  }
}
