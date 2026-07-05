# 市场行情插件

Noctalia Shell 的实时行情监控插件，支持多个交易所的加密货币现货价格和已上线的 USDT 永续合约价格。

![版本](https://img.shields.io/badge/版本-1.0.0-blue)
![许可证](https://img.shields.io/badge/许可证-MIT-green)

## 功能特性

- **多交易所支持**：火币、币安、OKX、CoinGecko
- **现货和永续市场**：支持加密货币现货交易对，以及交易所已上线的金属、美股等 USDT 永续合约
- **状态栏小部件**：显示单个资产价格及涨跌趋势
- **行情面板**：详细显示多个资产及 24 小时最高/最低价
- **显示模式**：文字模式（带资产符号）或简洁模式（仅价格）
- **配色方案**：红涨绿跌或绿涨红跌
- **自动 Logo 管理**：从 CoinGecko CDN 下载并缓存币种 Logo
- **语言切换**：在英文和简体中文之间切换插件界面
- **代理支持**：可选的 HTTP/SOCKS5 代理配置
- **配置导入导出**：通过 JSON 文件导出和恢复设置

## 安装

1. 复制插件到 Noctalia 插件目录：
```bash
cp -r crypto-market ~/.config/noctalia/plugins/
```

2. 重启 Noctalia Shell 或重新加载配置。

## 使用方法

### 状态栏小部件
- **左键点击**：打开或关闭详细行情面板
- **右键点击**：打开上下文菜单，用于设置、刷新和切换显示模式

### 行情面板
- 查看多个币种的实时价格、24 小时涨跌幅、最高/最低价
- 点击**刷新**按钮手动更新数据
- 点击**设置**配置插件

### 设置
- **数据源**：在火币、币安、OKX、CoinGecko 之间选择
- **代理地址**：可选的 HTTP/SOCKS5 代理（格式：`http://host:port` 或 `socks5://host:port`）
- **市场类型**：为火币、币安、OKX 选择现货或永续合约
- **状态栏显示资产**：选择在状态栏显示哪个资产
- **显示模式**：完整模式（带符号）或简洁模式（仅价格）
- **自选资产列表**：点击添加/移除资产，使用箭头按钮调整顺序
- **涨跌配色**：红涨绿跌（中国风格）或绿涨红跌（西方风格）
- **刷新频率**：设置更新间隔，1 到 60 秒
- **界面语言**：在英文和简体中文之间切换插件界面
- **配置管理**：导出/导入设置到 `~/Downloads/crypto-market-config.json`

## 配置

`manifest.json` 中的默认设置：
```json
{
  "watchList": ["btc", "eth", "bnb", "sol", "xrp"],
  "barCoin": "btc",
  "displayMode": "text",
  "redRises": false,
  "refreshInterval": 5,
  "dataSource": "huobi",
  "marketType": "spot",
  "proxyUrl": "",
  "language": "en"
}
```

## 支持的资产

预配置带 Logo 的加密资产：
- **BTC** (比特币)
- **ETH** (以太坊)
- **BNB** (币安币)
- **SOL** (Solana)
- **XRP** (瑞波币)
- **ADA** (艾达币)
- **DOT** (波卡)
- **DOGE** (狗狗币)
- **MATIC** (Polygon)
- **AVAX** (雪崩)

您可以在设置面板中搜索添加更多资产。永续合约模式下，插件会尽量从所选交易所加载可交易列表。也可以直接输入代码，例如 `xau`、`xag`、`aapl`、`msft`、`nvda`；是否有数据取决于所选交易所是否上线该合约。

## 数据源

### 火币（默认）
- API：`https://api.huobi.pro/market/history/kline`
- 永续合约 API：`https://api.hbdm.com/linear-swap-ex/market/history/kline`
- 基础使用无速率限制
- 推荐刷新间隔：5 秒

### 币安
- API：`https://api.binance.com/api/v3/klines`
- 永续合约 API：`https://fapi.binance.com/fapi/v1/klines`
- 速率限制：每分钟 1200 次请求
- 推荐刷新间隔：3 秒

### OKX
- API：`https://www.okx.com/api/v5/market/candles`
- 永续合约使用 `-USDT-SWAP` 交易工具
- 速率限制：每 2 秒 20 次请求
- 推荐刷新间隔：5 秒

### CoinGecko
- API：`https://api.coingecko.com/api/v3/simple/price`
- 此插件中仅用于加密货币现货资产
- 速率限制：免费版每分钟 50 次调用
- **最小刷新间隔：10 秒**（插件强制执行）

## 故障排除

### 无数据显示
1. 检查网络连接
2. 测试 API 访问：`curl -s 'https://api.huobi.pro/market/history/kline?period=1day&size=1&symbol=btcusdt'`
3. 如果在防火墙后面，尝试在设置中启用代理
4. 切换到其他数据源

### Logo 不显示
- Logo 在首次启动时下载
- 检查缓存目录：`ls ~/.cache/noctalia/crypto-market/logos/`
- 如果在防火墙后面，在设置中配置代理地址

### 插件未加载
1. 验证 JSON 语法：`jq . manifest.json`
2. 检查插件是否启用：`cat ~/.config/noctalia/plugins.json | jq '.states["crypto-market"]'`
3. 检查 Noctalia 日志中的错误信息

### 速率限制错误
- 在设置中增加刷新间隔
- CoinGecko 免费版：使用最少 10 秒间隔
- 币安：多个币种推荐 3 秒以上

## 开发

### 项目结构
```
crypto-market/
├── Main.qml          # 核心数据管理器，API 轮询，Logo 缓存
├── BarWidget.qml     # 状态栏小部件组件
├── Panel.qml         # 行情面板及币种表格
├── Settings.qml      # 配置界面
├── i18n/             # 插件翻译
└── manifest.json     # 插件元数据和默认值
```

### 技术栈
- **QML/Qt Quick**：UI 框架
- **Quickshell API**：Noctalia 集成
- **Process**：执行 Shell 命令进行 API 调用和下载 Logo

### API 测试
```bash
# 测试火币 API
curl -s 'https://api.huobi.pro/market/history/kline?period=1day&size=1&symbol=btcusdt'

# 测试火币永续合约 API
curl -s 'https://api.hbdm.com/linear-swap-ex/market/history/kline?period=1day&size=1&contract_code=BTC-USDT'

# 测试币安 API
curl -s 'https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=1d&limit=1'

# 测试币安永续合约 API
curl -s 'https://fapi.binance.com/fapi/v1/klines?symbol=BTCUSDT&interval=1d&limit=1'

# 测试 OKX API
curl -s 'https://www.okx.com/api/v5/market/candles?instId=BTC-USDT&bar=1D&limit=1'

# 测试 OKX 永续合约 API
curl -s 'https://www.okx.com/api/v5/market/candles?instId=BTC-USDT-SWAP&bar=1D&limit=1'

# 测试 CoinGecko API
curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true'
```

## 许可证

MIT 许可证 - 详见 LICENSE 文件。

## 作者

chengongliang

## 版本

1.0.0 - 需要 Noctalia Shell >= 4.6.6
