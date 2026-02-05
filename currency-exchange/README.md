# Currency Exchange

Convert currencies from Noctalia launcher or bar widget.

## Features

- **Launcher integration** — Quick currency conversion via `>fx` command
- **Bar widget** — Click to open the converter panel
- **Exchange rate on bar** — Displays current rate for your configured currency pair directly on bar (optional)

## Launcher Usage

1. Open the Noctalia launcher
2. Type `>fx` to enter currency mode
3. Enter your conversion query

### Examples

| Command | Result |
|---------|--------|
| `>fx 100 USD EUR` | Convert 100 USD to EUR |
| `>fx 50 BRL` | Convert 50 BRL to USD |
| `>fx EUR GBP` | Show rate for 1 EUR to GBP |
| `>fx` | Show usage help |

## Widget Configuration

To display the exchange rate on the bar widget:

1. Open plugin settings
2. Set your preferred **Source Currency** and **Target Currency**
3. Change **Display Mode** to `full` or `compact`

> **Note:** Rate display is only available on horizontal bars.

## Supported Currencies

30 currencies supported via frankfurter.app:

AUD, BRL, CAD, CHF, CNY, CZK, DKK, EUR, GBP, HKD, HUF, IDR, ILS, INR, ISK, JPY, KRW, MXN, MYR, NOK, NZD, PHP, PLN, RON, SEK, SGD, THB, TRY, USD, ZAR

## IPC Commands

Toggle currency converter panel:

```bash
qs -c noctalia-shell ipc call plugin:currency-exchange togglePanel
```

## TODO / IDEAS

- Improve UX of settings page
- Adapt UX of settings page to longer versions of translations
- Make togglePanel ipc function optionally accept AMOUNT, FROM_CURR and TO_CURR

## Requirements

- Noctalia 4.0.0 or later
- `curl` (for API requests)
- `wl-copy` (for clipboard support)

## Data Source

Exchange rates provided by [frankfurter.app](https://www.frankfurter.app/) (free, no API key required).
