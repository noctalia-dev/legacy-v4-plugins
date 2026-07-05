import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // 读取配置
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property var watchList: cfg.watchList ?? defaults.watchList ?? ["btc", "eth", "bnb", "sol", "xrp"]
  property string barCoin: cfg.barCoin ?? defaults.barCoin ?? "btc"
  property bool redRises: cfg.redRises ?? defaults.redRises ?? false
  property int refreshInterval: Math.max(1, Math.min(60, cfg.refreshInterval ?? defaults.refreshInterval ?? 5))
  property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "text"  // "text" or "compact"
  property string dataSource: cfg.dataSource ?? defaults.dataSource ?? "huobi"
  property string marketType: cfg.marketType ?? defaults.marketType ?? "spot"
  property string proxyUrl: cfg.proxyUrl ?? defaults.proxyUrl ?? ""
  property string language: cfg.language ?? defaults.language ?? "en"
  readonly property var marketTypes: ["spot", "perpetual"]
  readonly property string configPath: Quickshell.env("HOME") + "/Downloads/crypto-market-config.json"
  property var translations: ({
    "en": {
      "barWidget": {
        "openPanel": "Open market panel",
        "switchCompact": "Switch to compact mode",
        "switchFull": "Switch to full mode"
      },
      "dataSource": {
        "binance": "Binance",
        "coingecko": "CoinGecko",
        "huobi": "Huobi",
        "okx": "OKX"
      },
      "marketType": {
        "perpetual": "Perpetual futures",
        "spot": "Spot"
      },
      "panel": {
        "change": "Change",
        "close": "Close",
        "coin": "Asset",
        "dataFrom": "Data source",
        "error": "Error",
        "high": "High",
        "loading": "Loading...",
        "low": "Low",
        "noData": "No data",
        "price": "Price",
        "refresh": "Refresh",
        "refreshNow": "Refresh now",
        "settings": "Settings",
        "title": "Market Watch"
      },
      "settings": {
        "barCoin": "Status bar asset",
        "barCoinDesc": "Select the asset to display in the status bar",
        "colorScheme": "Color scheme",
        "colorSchemeDesc": "Select the color scheme for price changes",
        "configExported": "Configuration exported to ~/Downloads/crypto-market-config.json",
        "configImportFailed": "Failed to import configuration",
        "configImportMissing": "Configuration file was not found or is empty",
        "configImported": "Configuration imported from ~/Downloads/crypto-market-config.json",
        "configMgmt": "Configuration",
        "configPath": "Config file path: ~/Downloads/crypto-market-config.json",
        "dataSource": "Data source",
        "dataSourceDesc": "Select the market data source",
        "displayMode": "Status bar display mode",
        "displayModeCompact": "Compact mode (45,230)",
        "displayModeDesc": "Select full or compact mode",
        "displayModeFull": "Full mode (BTC 45,230)",
        "export": "Export config",
        "greenRises": "Green rises",
        "import": "Import config",
        "language": "Interface language",
        "languageDesc": "Select the language used by this plugin",
        "marketType": "Market type",
        "marketTypeDesc": "Spot supports crypto pairs. Perpetual futures can display supported metals and stock contracts from exchanges.",
        "proxy": "Proxy URL (optional)",
        "proxyPlaceholder": "http://127.0.0.1:7890",
        "proxyTip": "Leave empty to disable proxy. Format: http://host:port or socks5://host:port",
        "redRises": "Red rises",
        "refreshInterval": "Refresh interval",
        "refreshIntervalDesc": "Data update interval (1-60 seconds)",
        "search": "Search assets",
        "searchPlaceholder": "Enter an asset symbol to search (for example: btc, xau, aapl)",
        "searchResults": "Search results",
        "seconds": "seconds",
        "watchList": "Watch list",
        "watchListTip": "Click an asset to add or remove it, and use arrows to reorder"
      }
    },
    "zh-CN": {
      "barWidget": {
        "openPanel": "打开行情面板",
        "switchCompact": "切换到简洁模式",
        "switchFull": "切换到完整模式"
      },
      "dataSource": {
        "binance": "币安",
        "coingecko": "CoinGecko",
        "huobi": "火币",
        "okx": "OKX"
      },
      "marketType": {
        "perpetual": "永续合约",
        "spot": "现货"
      },
      "panel": {
        "change": "涨跌幅",
        "close": "关闭",
        "coin": "资产",
        "dataFrom": "数据来源",
        "error": "错误",
        "high": "最高",
        "loading": "加载中...",
        "low": "最低",
        "noData": "无数据",
        "price": "最新价",
        "refresh": "刷新",
        "refreshNow": "立即刷新",
        "settings": "设置",
        "title": "市场行情"
      },
      "settings": {
        "barCoin": "状态栏显示资产",
        "barCoinDesc": "选择在状态栏显示的资产",
        "colorScheme": "涨跌配色",
        "colorSchemeDesc": "选择涨跌颜色方案",
        "configExported": "配置已导出到 ~/Downloads/crypto-market-config.json",
        "configImportFailed": "导入配置失败",
        "configImportMissing": "配置文件不存在或内容为空",
        "configImported": "已从 ~/Downloads/crypto-market-config.json 导入配置",
        "configMgmt": "配置管理",
        "configPath": "配置文件路径: ~/Downloads/crypto-market-config.json",
        "dataSource": "数据源",
        "dataSourceDesc": "选择行情数据来源",
        "displayMode": "状态栏显示模式",
        "displayModeCompact": "简洁模式 (45,230)",
        "displayModeDesc": "选择完整或简洁模式",
        "displayModeFull": "完整模式 (BTC 45,230)",
        "export": "导出配置",
        "greenRises": "绿涨红跌",
        "import": "导入配置",
        "language": "界面语言",
        "languageDesc": "选择此插件使用的显示语言",
        "marketType": "市场类型",
        "marketTypeDesc": "现货支持加密货币交易对。永续合约可显示交易所支持的金属和美股合约。",
        "proxy": "代理地址（可选）",
        "proxyPlaceholder": "http://127.0.0.1:7890",
        "proxyTip": "留空则不使用代理。格式: http://host:port 或 socks5://host:port",
        "redRises": "红涨绿跌",
        "refreshInterval": "刷新频率",
        "refreshIntervalDesc": "数据更新间隔（1-60 秒）",
        "search": "搜索添加资产",
        "searchPlaceholder": "输入资产代码搜索（例如：btc, xau, aapl）",
        "searchResults": "搜索结果",
        "seconds": "秒",
        "watchList": "自选资产列表",
        "watchListTip": "点击资产名称添加或移除，使用箭头调整顺序"
      }
    }
  })
  property bool importOk: false
  property string importMessage: ""
  property int importNonce: 0

  // 币种列表
  property var allCoinsList: []

  // Logo 管理
  property string logoDir: Quickshell.env("HOME") + "/.cache/noctalia/crypto-market/logos"
  property var logoCache: ({})
  property var logoFailures: ({})
  property bool logosReady: false
  readonly property int logoRetryCooldownMs: 60000

  readonly property var commonCoinSymbols: [
    "btc", "eth", "bnb", "sol", "xrp", "ada", "dot", "doge", "matic", "avax",
    "link", "ltc", "bch", "xlm", "trx", "atom", "uni", "etc", "vet", "fil",
    "theta", "icp", "xmr", "algo", "eos", "aave", "ftm", "axs", "sand", "mana",
    "grt", "cake", "crv", "snx", "comp", "mkr", "ksm", "near", "hbar", "flow",
    "egld", "xtz", "btt", "zec", "waves", "dash", "zil", "neo", "chz", "bat",
    "enj", "lrc", "1inch", "sushi", "yfi", "bal", "ren", "omg", "uma", "kava",
    "xau", "xag", "aapl", "msft", "nvda", "tsla", "amzn", "googl", "meta", "nflx",
    "coin", "mstr", "qqq", "spy"
  ]

  readonly property var coinNames: ({
    "btc": "Bitcoin",
    "eth": "Ethereum",
    "bnb": "Binance Coin",
    "sol": "Solana",
    "xrp": "Ripple",
    "ada": "Cardano",
    "dot": "Polkadot",
    "doge": "Dogecoin",
    "matic": "Polygon",
    "avax": "Avalanche",
    "link": "Chainlink",
    "ltc": "Litecoin",
    "bch": "Bitcoin Cash",
    "xlm": "Stellar",
    "trx": "TRON",
    "atom": "Cosmos",
    "uni": "Uniswap",
    "etc": "Ethereum Classic",
    "vet": "VeChain",
    "fil": "Filecoin",
    "theta": "Theta Network",
    "icp": "Internet Computer",
    "xmr": "Monero",
    "algo": "Algorand",
    "eos": "EOS",
    "aave": "Aave",
    "ftm": "Fantom",
    "axs": "Axie Infinity",
    "sand": "The Sandbox",
    "mana": "Decentraland",
    "grt": "The Graph",
    "cake": "PancakeSwap",
    "crv": "Curve DAO",
    "snx": "Synthetix",
    "comp": "Compound",
    "mkr": "Maker",
    "ksm": "Kusama",
    "near": "NEAR Protocol",
    "hbar": "Hedera",
    "flow": "Flow",
    "egld": "MultiversX",
    "xtz": "Tezos",
    "btt": "BitTorrent",
    "zec": "Zcash",
    "waves": "Waves",
    "dash": "Dash",
    "zil": "Zilliqa",
    "neo": "NEO",
    "chz": "Chiliz",
    "bat": "Basic Attention Token",
    "enj": "Enjin Coin",
    "lrc": "Loopring",
    "1inch": "1inch",
    "sushi": "SushiSwap",
    "yfi": "yearn.finance",
    "bal": "Balancer",
    "ren": "Ren",
    "omg": "OMG Network",
    "uma": "UMA",
    "kava": "Kava",
    "xau": "Gold",
    "xag": "Silver",
    "aapl": "Apple",
    "msft": "Microsoft",
    "nvda": "NVIDIA",
    "tsla": "Tesla",
    "amzn": "Amazon",
    "googl": "Alphabet",
    "meta": "Meta",
    "nflx": "Netflix",
    "coin": "Coinbase",
    "mstr": "MicroStrategy",
    "qqq": "Nasdaq 100 ETF",
    "spy": "S&P 500 ETF"
  })

  // CoinGecko 币种 ID 映射
  readonly property var coinGeckoIds: ({
    "btc": "bitcoin",
    "eth": "ethereum",
    "bnb": "binancecoin",
    "sol": "solana",
    "xrp": "ripple",
    "ada": "cardano",
    "dot": "polkadot",
    "doge": "dogecoin",
    "matic": "polygon-pos",
    "avax": "avalanche-2"
  })

  // 备用 Logo URLs (CoinGecko CDN)
  readonly property var fallbackLogoUrls: ({
    "btc": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
    "eth": "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
    "bnb": "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
    "sol": "https://assets.coingecko.com/coins/images/4128/large/solana.png",
    "xrp": "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
    "ada": "https://assets.coingecko.com/coins/images/975/large/cardano.png",
    "dot": "https://assets.coingecko.com/coins/images/12171/large/polkadot.png",
    "doge": "https://assets.coingecko.com/coins/images/5/large/dogecoin.png",
    "matic": "https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png",
    "avax": "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png"
  })

  // 币种图标映射（Emoji 作为备用）
  readonly property var coinIcons: ({
    "btc": "🪙",
    "eth": "💎",
    "bnb": "🔶",
    "sol": "🌞",
    "xrp": "💧",
    "ada": "🔷",
    "dot": "⚪",
    "doge": "🐕",
    "matic": "🟣",
    "avax": "🔺",
    "xau": "Au",
    "xag": "Ag",
    "aapl": "A",
    "msft": "M",
    "nvda": "N",
    "tsla": "T",
    "amzn": "A",
    "googl": "G",
    "meta": "M",
    "nflx": "N",
    "coin": "C",
    "mstr": "M",
    "qqq": "Q",
    "spy": "S"
  })

  // 数据源适配器
  readonly property var dataSourceAdapters: ({
    "huobi": {
      name: "火币",
      getUrl: function(coin) {
        if (root.marketType === "perpetual") {
          return `https://api.hbdm.com/linear-swap-ex/market/history/kline?period=1day&size=1&contract_code=${root.formatExchangeSymbol(coin, "huobi", "perpetual")}`;
        }
        return `https://api.huobi.pro/market/history/kline?period=1day&size=1&symbol=${root.formatExchangeSymbol(coin, "huobi", "spot")}`;
      },
      parseResponse: function(response, coin) {
        if (response.status === "ok" && response.data && response.data.length > 0) {
          const kline = response.data[0];
          return {
            open: kline.open,
            close: kline.close,
            high: kline.high,
            low: kline.low,
            volume: kline.vol
          };
        }
        return null;
      }
    },
    "binance": {
      name: "币安",
      getUrl: function(coin) {
        if (root.marketType === "perpetual") {
          return `https://fapi.binance.com/fapi/v1/klines?symbol=${root.formatExchangeSymbol(coin, "binance", "perpetual")}&interval=1d&limit=1`;
        }
        return `https://api.binance.com/api/v3/klines?symbol=${root.formatExchangeSymbol(coin, "binance", "spot")}&interval=1d&limit=1`;
      },
      parseResponse: function(response, coin) {
        if (response && response.length > 0) {
          const kline = response[0];
          return {
            open: parseFloat(kline[1]),
            close: parseFloat(kline[4]),
            high: parseFloat(kline[2]),
            low: parseFloat(kline[3]),
            volume: parseFloat(kline[5])
          };
        }
        return null;
      }
    },
    "okx": {
      name: "OKX",
      getUrl: function(coin) {
        if (root.marketType === "perpetual") {
          return `https://www.okx.com/api/v5/market/candles?instId=${root.formatExchangeSymbol(coin, "okx", "perpetual")}&bar=1D&limit=1`;
        }
        return `https://www.okx.com/api/v5/market/candles?instId=${root.formatExchangeSymbol(coin, "okx", "spot")}&bar=1D&limit=1`;
      },
      parseResponse: function(response, coin) {
        if (response.code === "0" && response.data && response.data.length > 0) {
          const kline = response.data[0];
          return {
            open: parseFloat(kline[1]),
            close: parseFloat(kline[4]),
            high: parseFloat(kline[2]),
            low: parseFloat(kline[3]),
            volume: parseFloat(kline[5])
          };
        }
        return null;
      }
    },
    "coingecko": {
      name: "CoinGecko",
      getUrl: function(coin) {
        const key = root.normalizeAssetKey(coin);
        const id = root.coinGeckoIds[key] || key;
        return `https://api.coingecko.com/api/v3/simple/price?ids=${id}&vs_currencies=usd&include_24hr_change=true&include_24hr_vol=true&include_24hr_high_low=true`;
      },
      parseResponse: function(response, coin) {
        const key = root.normalizeAssetKey(coin);
        const id = root.coinGeckoIds[key] || key;
        const data = response[id];
        if (data && data.usd) {
          const currentPrice = data.usd;
          const change = data.usd_24h_change || 0;
          const openPrice = currentPrice / (1 + change / 100);
          return {
            open: openPrice,
            close: currentPrice,
            high: data.usd_24h_high || currentPrice,
            low: data.usd_24h_low || currentPrice,
            volume: data.usd_24h_vol || 0
          };
        }
        return null;
      }
    }
  })

  // 数据状态
  property var marketData: ({})
  property bool isLoading: true
  property string errorMessage: ""
  property int refreshNonce: 0
  property bool coinsListRefetchPending: false

  Component.onCompleted: {
    watchList = normalizeAssetList(watchList);
    barCoin = normalizeAssetKey(barCoin);
    if (!watchList.includes(barCoin)) {
      barCoin = watchList.length > 0 ? watchList[0] : "btc";
    }
    if (!marketTypes.includes(marketType)) {
      marketType = "spot";
    }
    loadTranslations();
    initLogoCache();
    fetchCoinsList();
  }

  FileView {
    id: enTranslationFile
    path: pluginApi?.pluginDir ? pluginApi.pluginDir + "/i18n/en.json" : ""
    watchChanges: false
    printErrors: false

    onLoaded: root.storeTranslation("en", text)
    onTextChanged: root.storeTranslation("en", text)
  }

  FileView {
    id: zhTranslationFile
    path: pluginApi?.pluginDir ? pluginApi.pluginDir + "/i18n/zh-CN.json" : ""
    watchChanges: false
    printErrors: false

    onLoaded: root.storeTranslation("zh-CN", text)
    onTextChanged: root.storeTranslation("zh-CN", text)
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: false
    printErrors: false
  }

  Process {
    id: importConfigProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => root.finishImportConfig(exitCode, String(stdout.text), String(stderr.text))
  }

  function loadTranslations() {
    if (enTranslationFile.path !== "") enTranslationFile.reload();
    if (zhTranslationFile.path !== "") zhTranslationFile.reload();
  }

  function storeTranslation(lang, text) {
    if (!text || text.length === 0) return;
    try {
      const next = Object.assign({}, root.translations);
      next[lang] = JSON.parse(text);
      root.translations = next;
      root.refreshNonce++;
    } catch (e) {
      Logger.w("CryptoMarket", "Failed to parse translation file for " + lang + ": " + e);
    }
  }

  function tr(path) {
    const lang = root.language === "zh" ? "zh-CN" : root.language;
    const selected = lookupTranslation(root.translations[lang], path);
    if (selected !== undefined) return selected;
    const fallback = lookupTranslation(root.translations["en"], path);
    return fallback !== undefined ? fallback : path;
  }

  function lookupTranslation(source, path) {
    if (!source) return undefined;
    const parts = path.split(".");
    let current = source;
    for (let i = 0; i < parts.length; i++) {
      if (current && current[parts[i]] !== undefined) {
        current = current[parts[i]];
      } else {
        return undefined;
      }
    }
    return current;
  }

  function normalizeAssetKey(asset) {
    let text = String(asset || "").trim().toLowerCase();
    if (text === "") return "";

    text = text
      .replace(/_/g, "-")
      .replace(/\.perp$/i, "")
      .replace(/-swap$/i, "")
      .replace(/-usdt$/i, "")
      .replace(/\/usdt$/i, "")
      .replace(/usdt$/i, "")
      .replace(/-+$/g, "");

    return text;
  }

  function normalizeAssetList(assets) {
    const result = [];
    const seen = {};
    if (!Array.isArray(assets)) return result;

    for (let i = 0; i < assets.length; i++) {
      const symbol = normalizeAssetKey(assets[i]);
      if (symbol !== "" && !seen[symbol]) {
        seen[symbol] = true;
        result.push(symbol);
      }
    }

    return result;
  }

  function formatExchangeSymbol(asset, source, type) {
    const symbol = normalizeAssetKey(asset).toUpperCase();
    const selectedType = type || root.marketType;

    if (symbol.indexOf("-") !== -1 || symbol.indexOf("/") !== -1) {
      return source === "binance" ? symbol.replace(/[-/]/g, "") : symbol.replace("/", "-");
    }

    if (source === "okx") {
      return selectedType === "perpetual" ? symbol + "-USDT-SWAP" : symbol + "-USDT";
    }

    if (source === "huobi") {
      return selectedType === "perpetual" ? symbol + "-USDT" : symbol.toLowerCase() + "usdt";
    }

    return symbol + "USDT";
  }

  // 创建缓存目录的 Process
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.logoDir]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.logosReady = true;
      } else {
        Logger.w("CryptoMarket", "Failed to create logo cache directory: " + String(stderr.text));
      }
    }
  }

  // 检查本地 logo 文件
  Process {
    id: checkLogoProc
    command: ["sh", "-c", "ls " + root.logoDir + "/*.png 2>/dev/null | wc -l"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      const count = parseInt(String(stdout.text).trim());
      const totalCoins = Object.keys(root.coinGeckoIds).length;

      if (count >= totalCoins) {
        for (let coin in root.coinGeckoIds) {
          root.logoCache[coin] = root.logoDir + "/" + coin + ".png";
        }
        root.logosReady = true;
      } else {
        downloadAllLogos();
      }
    }
  }

  // 初始化 logo 缓存
  function initLogoCache() {
    mkdirProc.running = true;
  }

  // 检查本地是否已有 logo
  function checkLocalLogos() {
    checkLogoProc.running = true;
  }

  // 下载所有 logo
  function downloadAllLogos() {
    let downloaded = 0;
    const totalCoins = Object.keys(coinGeckoIds).length;

    for (let coin in coinGeckoIds) {
      downloadLogo(coin, fallbackLogoUrls[coin], function(success) {
        downloaded++;
        if (success) {
          root.logoCache[coin] = root.logoDir + "/" + coin + ".png";
        }
        if (downloaded === totalCoins) {
          root.logosReady = true;
          root.refreshNonce++;
        }
      });
    }
  }

  // 下载单个 logo
  function downloadLogo(coin, url, callback) {
    const outputPath = logoDir + "/" + coin + ".png";

    // 检查文件是否已存在
    const checkProc = downloadProcComponent.createObject(root, {
      "command": ["test", "-f", outputPath]
    });

    checkProc.exited.connect(function(exitCode) {
      if (exitCode === 0) {
        callback(true);
        checkProc.destroy();
        return;
      }

      const proc = downloadProcComponent.createObject(root, {
        "command": proxyUrl ? ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", "-x", proxyUrl, "-o", outputPath, url] : ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", "-o", outputPath, url]
      });

      proc.exited.connect(function(exitCode) {
        if (exitCode === 0) {
          callback(true);
        } else {
          Logger.w("CryptoMarket", "Failed to download logo for " + coin + ": " + String(proc.stderr.text));
          callback(false);
        }
        proc.destroy();
      });

      proc.running = true;
      checkProc.destroy();
    });

    checkProc.running = true;
  }

  // 动态下载币种 Logo
  function requestLogo(coin) {
    const key = normalizeAssetKey(coin);
    if (key === "") return;
    if (logoCache[key]) return;
    if (!canRetryLogo(key)) return;

    // 标记为正在下载，避免重复
    const nextCache = Object.assign({}, logoCache);
    nextCache[key] = "downloading";
    root.logoCache = nextCache;

    // 已知币种直接使用静态图片 URL，避免频繁请求 CoinGecko metadata API 触发限流。
    const logoUrl = fallbackLogoUrls[key];
    if (logoUrl) {
      downloadLogo(key, logoUrl, function(success) {
        if (success) {
          setLogoPath(key, logoDir + "/" + key + ".png");
        } else {
          markLogoFailed(key);
        }
      });
    } else {
      // 未知币种，通过搜索 API 查找
      const searchUrl = `https://api.coingecko.com/api/v3/search?query=${key}`;
      const searchProc = curlProcComponent.createObject(root, {
        "command": proxyUrl ? ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", "-x", proxyUrl, searchUrl] : ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", searchUrl]
      });

      searchProc.exited.connect(function(exitCode) {
        if (exitCode === 0) {
          try {
            const response = JSON.parse(String(searchProc.stdout.text));
            if (response.coins && response.coins.length > 0) {
              const foundCoin = response.coins[0];
              const logoUrl = foundCoin.large || foundCoin.thumb;
              if (logoUrl) {
                downloadLogo(key, logoUrl, function(success) {
                  if (success) {
                    setLogoPath(key, logoDir + "/" + key + ".png");
                  } else {
                    markLogoFailed(key);
                  }
                });
              } else {
                markLogoFailed(key);
              }
            } else {
              markLogoFailed(key);
            }
          } catch (e) {
            Logger.w("CryptoMarket", "Failed to parse logo search response for " + key + ": " + e);
            markLogoFailed(key);
          }
        } else {
          Logger.w("CryptoMarket", "Failed to search logo for " + key + ": " + String(searchProc.stderr.text));
          markLogoFailed(key);
        }
        searchProc.destroy();
      });

      searchProc.running = true;
    }
  }

  function setLogoPath(coin, path) {
    const key = normalizeAssetKey(coin);
    const nextCache = Object.assign({}, root.logoCache);
    nextCache[key] = path;
    root.logoCache = nextCache;

    const nextFailures = Object.assign({}, root.logoFailures);
    delete nextFailures[key];
    root.logoFailures = nextFailures;

    root.refreshNonce++;
  }

  function markLogoFailed(coin) {
    const key = normalizeAssetKey(coin);
    const nextCache = Object.assign({}, root.logoCache);
    delete nextCache[key];
    root.logoCache = nextCache;

    const nextFailures = Object.assign({}, root.logoFailures);
    nextFailures[key] = Date.now();
    root.logoFailures = nextFailures;
    root.refreshNonce++;
  }

  function canRetryLogo(coin) {
    const key = normalizeAssetKey(coin);
    const failedAt = root.logoFailures[key];
    if (!failedAt) return true;

    if ((Date.now() - failedAt) < root.logoRetryCooldownMs) {
      return false;
    }

    const nextFailures = Object.assign({}, root.logoFailures);
    delete nextFailures[key];
    root.logoFailures = nextFailures;
    return true;
  }

  Timer {
    interval: root.logoRetryCooldownMs
    repeat: true
    running: Object.keys(root.logoFailures).length > 0
    onTriggered: {
      const failedCoins = Object.keys(root.logoFailures);
      for (let i = 0; i < failedCoins.length; i++) {
        root.requestLogo(failedCoins[i]);
      }
    }
  }

  Component {
    id: downloadProcComponent
    Process {
      stdout: StdioCollector {}
      stderr: StdioCollector {}
    }
  }

  Component {
    id: curlProcComponent
    Process {
      stdout: StdioCollector {}
      stderr: StdioCollector {}
    }
  }

  // 获取 logo 路径
  function getLogoPath(coin) {
    const key = normalizeAssetKey(coin);
    // 如果缓存中有记录，直接返回
    if (logoCache[key] && logoCache[key] !== "downloading") {
      return "file://" + logoCache[key];
    }

    // 如果正在下载，返回空
    if (logoCache[key] === "downloading") {
      return "";
    }

    if (logoFailures[key]) {
      return "";
    }

    return "";
  }

  // 定时器
  Timer {
    interval: Math.max(root.refreshInterval * 1000, root.dataSource === "coingecko" ? 10000 : 1000)
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.watchList.forEach(function(coin) {
        root.fetchMarketData(coin);
      });
    }
  }

  // 获取市场数据
  function fetchMarketData(coin) {
    const adapter = dataSourceAdapters[dataSource];
    if (!adapter) return;

    if (dataSource === "coingecko" && marketType !== "spot") {
      Logger.w("CryptoMarket", "CoinGecko only supports spot crypto asset IDs in this plugin");
    }

    const key = normalizeAssetKey(coin);
    const url = adapter.getUrl(coin);

    const proc = curlProcComponent.createObject(root, {
      "command": proxyUrl ? ["curl", "-fsSL", "--connect-timeout", "8", "--max-time", "20", "-x", proxyUrl, url] : ["curl", "-fsSL", "--connect-timeout", "8", "--max-time", "20", url]
    });

    proc.exited.connect(function(exitCode) {
      if (exitCode === 0) {
        try {
          const response = JSON.parse(String(proc.stdout.text));
          const parsed = adapter.parseResponse(response, key);

          if (parsed && parsed.open > 0 && parsed.close > 0) {
            const change = ((parsed.close - parsed.open) / parsed.open * 100);

            const nextMarketData = Object.assign({}, marketData);
            nextMarketData[key] = {
              open: parsed.open,
              close: parsed.close,
              high: parsed.high,
              low: parsed.low,
              volume: parsed.volume,
              change: change,
              isRising: parsed.close >= parsed.open
            };
            marketData = nextMarketData;

            refreshNonce++;
            root.isLoading = false;
            root.errorMessage = "";
          }
        } catch (e) {
          Logger.w("CryptoMarket", "Failed to parse market data for " + coin + ": " + e);
        }
      } else {
        Logger.w("CryptoMarket", "Failed to fetch market data for " + coin + ": " + String(proc.stderr.text));
      }
      proc.destroy();
    });

    proc.running = true;
  }

  // 格式化价格
  function formatPrice(price) {
    if (!price || price <= 0) return "--";
    if (price >= 1000) {
      return price.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }
    if (price >= 1) return price.toFixed(2);
    if (price >= 0.01) return price.toFixed(4);
    // 小于 0.01 使用科学计数法
    if (price < 0.000001) {
      return price.toExponential(2);
    }
    return price.toFixed(6);
  }

  // 格式化涨跌幅
  function formatChange(change) {
    if (change === undefined || change === null) return "--";
    const sign = change >= 0 ? "+" : "";
    return `${sign}${change.toFixed(2)}%`;
  }

  // 获取价格颜色
  function getPriceColor(coin) {
    const data = marketData[normalizeAssetKey(coin)];
    if (!data) return "#888888";

    const isRising = data.isRising;
    // 红涨模式: 涨=红 跌=绿
    // 绿涨模式: 涨=绿 跌=红
    if (redRises) {
      return isRising ? "#ff704b" : "#39c38c";
    } else {
      return isRising ? "#39c38c" : "#ff704b";
    }
  }

  // 获取币种图标
  function getCoinIcon(coin) {
    const key = normalizeAssetKey(coin);
    return coinIcons[key] || key.slice(0, 2).toUpperCase();
  }

  function getCoinName(coin) {
    const symbol = normalizeAssetKey(coin);
    const name = coinNames[symbol];
    return name ? symbol.toUpperCase() + " (" + name + ")" : symbol.toUpperCase();
  }

  function searchCoinSymbols(query) {
    const text = normalizeAssetKey(query);
    if (text === "") return [];

    const coins = [];
    const seen = {};
    const appendCoin = function(coin) {
      const symbol = normalizeAssetKey(coin);
      if (symbol !== "" && !seen[symbol]) {
        seen[symbol] = true;
        coins.push(symbol);
      }
    };

    appendCoin(text);
    root.commonCoinSymbols.forEach(appendCoin);
    root.allCoinsList.forEach(appendCoin);

    const filtered = coins.filter(function(coin) {
      const name = root.coinNames[coin] || "";
      return coin.indexOf(text) === 0 || name.toLowerCase().indexOf(text) !== -1;
    });

    filtered.sort(function(a, b) {
      const aSymbolMatch = a.indexOf(text) === 0 ? 0 : 1;
      const bSymbolMatch = b.indexOf(text) === 0 ? 0 : 1;
      if (aSymbolMatch !== bSymbolMatch) return aSymbolMatch - bSymbolMatch;
      return a.localeCompare(b);
    });

    return filtered.slice(0, 10);
  }

  // 导出配置
  function exportConfig() {
    const config = {
      watchList: root.watchList,
      barCoin: root.barCoin,
      displayMode: root.displayMode,
      redRises: root.redRises,
      refreshInterval: root.refreshInterval,
      dataSource: root.dataSource,
      marketType: root.marketType,
      proxyUrl: root.proxyUrl,
      language: root.language
    };
    configFile.setText(JSON.stringify(config, null, 2));
  }

  function importConfig() {
    if (importConfigProc.running) return;
    importConfigProc.command = ["cat", root.configPath];
    importConfigProc.running = true;
  }

  function finishImportConfig(exitCode, stdoutText, stderrText) {
    if (exitCode !== 0) {
      root.importOk = false;
      root.importMessage = tr("settings.configImportMissing");
      root.importNonce++;
      return;
    }

    const text = String(stdoutText || "").trim();
    if (text === "") {
      root.importOk = false;
      root.importMessage = tr("settings.configImportMissing");
      root.importNonce++;
      return;
    }

    try {
      const imported = JSON.parse(text);
      const normalized = normalizeImportedConfig(imported);
      applyConfig(normalized, true);
      root.importOk = true;
      root.importMessage = tr("settings.configImported");
    } catch (e) {
      root.importOk = false;
      root.importMessage = tr("settings.configImportFailed") + ": " + e;
    }
    root.importNonce++;
  }

  function normalizeImportedConfig(config) {
    const validSources = ["huobi", "binance", "okx", "coingecko"];
    const validModes = ["text", "compact"];
    const validLanguages = ["en", "zh-CN", "zh"];
    const validMarketTypes = root.marketTypes;
    const next = {
      watchList: root.watchList,
      barCoin: root.barCoin,
      displayMode: root.displayMode,
      redRises: root.redRises,
      refreshInterval: root.refreshInterval,
      dataSource: root.dataSource,
      marketType: root.marketType,
      proxyUrl: root.proxyUrl,
      language: root.language
    };

    if (Array.isArray(config.watchList)) {
      const coins = normalizeAssetList(config.watchList);
      if (coins.length > 0) next.watchList = coins;
    }
    if (typeof config.barCoin === "string" && config.barCoin.trim() !== "") next.barCoin = normalizeAssetKey(config.barCoin);
    if (validModes.includes(config.displayMode)) next.displayMode = config.displayMode;
    if (typeof config.redRises === "boolean") next.redRises = config.redRises;
    if (typeof config.refreshInterval === "number") next.refreshInterval = Math.max(1, Math.min(60, Math.round(config.refreshInterval)));
    if (validSources.includes(config.dataSource)) next.dataSource = config.dataSource;
    if (validMarketTypes.includes(config.marketType)) next.marketType = config.marketType;
    if (typeof config.proxyUrl === "string") next.proxyUrl = config.proxyUrl;
    if (validLanguages.includes(config.language)) next.language = config.language === "zh" ? "zh-CN" : config.language;

    if (!next.watchList.includes(next.barCoin)) {
      next.barCoin = next.watchList[0];
    }

    return next;
  }

  function applyConfig(config, persist) {
    const previousProxyUrl = root.proxyUrl;
    const previousDataSource = root.dataSource;
    const previousMarketType = root.marketType;
    const nextWatchList = normalizeAssetList(config.watchList);
    root.watchList = nextWatchList.length > 0 ? nextWatchList : root.watchList;
    root.barCoin = normalizeAssetKey(config.barCoin);
    if (!root.watchList.includes(root.barCoin)) {
      root.barCoin = root.watchList[0];
    }
    root.displayMode = config.displayMode;
    root.redRises = config.redRises;
    root.refreshInterval = Math.max(1, Math.min(60, config.refreshInterval));
    root.dataSource = config.dataSource;
    root.marketType = root.dataSource === "coingecko" ? "spot" : (root.marketTypes.includes(config.marketType) ? config.marketType : "spot");
    root.proxyUrl = config.proxyUrl;
    root.language = config.language;
    root.marketData = ({});
    root.isLoading = true;
    root.errorMessage = "";
    root.refreshNonce++;

    if (previousProxyUrl !== root.proxyUrl || previousDataSource !== root.dataSource || previousMarketType !== root.marketType) {
      root.logoFailures = ({});
      root.fetchCoinsList(true);
    }

    if (persist && pluginApi) {
      pluginApi.pluginSettings.watchList = root.watchList;
      pluginApi.pluginSettings.barCoin = root.barCoin;
      pluginApi.pluginSettings.displayMode = root.displayMode;
      pluginApi.pluginSettings.redRises = root.redRises;
      pluginApi.pluginSettings.refreshInterval = root.refreshInterval;
      pluginApi.pluginSettings.dataSource = root.dataSource;
      pluginApi.pluginSettings.marketType = root.marketType;
      pluginApi.pluginSettings.proxyUrl = root.proxyUrl;
      pluginApi.pluginSettings.language = root.language;
      pluginApi.saveSettings();
    }

    for (let i = 0; i < root.watchList.length; i++) {
      root.fetchMarketData(root.watchList[i]);
    }
  }

  // 获取币种列表
  function fetchCoinsList(force) {
    if (coinsListProc.running) {
      if (force) root.coinsListRefetchPending = true;
      return;
    }
    root.coinsListRefetchPending = false;
    const url = getSymbolsUrl();
    if (url === "") {
      root.allCoinsList = root.commonCoinSymbols;
      return;
    }
    coinsListProc.command = proxyUrl ? ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", "-x", proxyUrl, url] : ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30", url];
    coinsListProc.running = true;
  }

  function getSymbolsUrl() {
    if (root.dataSource === "coingecko") return "";
    if (root.dataSource === "binance") {
      return root.marketType === "perpetual"
        ? "https://fapi.binance.com/fapi/v1/exchangeInfo"
        : "https://api.binance.com/api/v3/exchangeInfo";
    }
    if (root.dataSource === "okx") {
      return root.marketType === "perpetual"
        ? "https://www.okx.com/api/v5/public/instruments?instType=SWAP"
        : "https://www.okx.com/api/v5/public/instruments?instType=SPOT";
    }
    if (root.marketType === "perpetual") {
      return "https://api.hbdm.com/linear-swap-api/v1/swap_contract_info";
    }
    return "https://api.huobi.pro/v1/common/symbols";
  }

  function parseSymbolsResponse(response) {
    const symbols = [];
    const append = function(symbol) {
      const key = normalizeAssetKey(symbol);
      if (key !== "") symbols.push(key);
    };

    if (root.dataSource === "binance" && Array.isArray(response.symbols)) {
      response.symbols
        .filter(symbol => symbol.quoteAsset === "USDT" && symbol.status === "TRADING")
        .forEach(symbol => append(symbol.baseAsset));
    } else if (root.dataSource === "okx" && response.code === "0" && Array.isArray(response.data)) {
      response.data
        .filter(symbol => symbol.quoteCcy === "USDT" || symbol.settleCcy === "USDT" || String(symbol.instId || "").indexOf("-USDT") !== -1)
        .forEach(symbol => append(symbol.baseCcy || symbol.instId));
    } else if (root.dataSource === "huobi" && root.marketType === "perpetual" && response.status === "ok" && Array.isArray(response.data)) {
      response.data
        .filter(symbol => symbol.contract_status === 1 || symbol.contract_status === "1" || symbol.contract_status === undefined)
        .forEach(symbol => append(symbol.symbol || symbol.contract_code));
    } else if (response.status === "ok" && Array.isArray(response.data)) {
      response.data
        .filter(symbol => symbol["quote-currency"] === "usdt" && symbol.state === "online")
        .forEach(symbol => append(symbol["base-currency"]));
    }

    return normalizeAssetList(symbols);
  }

  Process {
    id: coinsListProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0) {
        try {
          const text = String(stdout.text);
          const response = JSON.parse(text);
          const symbols = parseSymbolsResponse(response);
          root.allCoinsList = symbols.length > 0 ? symbols : root.commonCoinSymbols;
        } catch (e) {
          Logger.w("CryptoMarket", "Failed to parse coin list: " + e);
        }
      } else {
        Logger.w("CryptoMarket", "Failed to fetch coin list: " + String(stderr.text));
      }
      if (root.coinsListRefetchPending) {
        root.fetchCoinsList(false);
      }
    }
  }
}
