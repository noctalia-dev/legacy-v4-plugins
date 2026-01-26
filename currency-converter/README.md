# Currency Converter

A Noctalia Shell plugin for real-time currency conversion with support for multiple currencies.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Noctalia](https://img.shields.io/badge/noctalia-3.6.0+-purple.svg)

## Features

- 💱 **Real-time Exchange Rates**: Automatic updates at configurable intervals
- 🌍 **Multiple Currencies**: Support for major world currencies
- 🔄 **Quick Swap**: Instantly swap between source and target currencies
- ⚙️ **Configurable Settings**:
  - Update interval (in minutes)
  - Display mode (icon + text, icon only, or text only)
  - Source and target currencies
- 🌎 **Internationalization**: Fully translated to 12 languages
- 🎨 **Clean UI**: Compact bar widget with detailed converter panel
- ⚡ **Efficient**: Smart caching and minimal network usage

## Supported Languages

- English (en)
- Portuguese (pt)
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Japanese (ja)
- Chinese Simplified (zh-CN)
- Russian (ru)
- Dutch (nl)
- Turkish (tr)
- Ukrainian (uk-UA)

## Installation

1. Open Noctalia Shell Settings
2. Go to Plugins section
3. Search for "Currency Converter"
4. Click Install

Or manually:
```bash
git clone https://github.com/noctalia-dev/noctalia-plugins.git
cd noctalia-plugins/currency-converter
# Copy to your Noctalia plugins directory
```

## Usage

1. **Add the widget**: Add Currency Converter to your bar from the widgets menu
2. **Configure currencies**: Click on the widget to open the converter panel
3. **Select currencies**: Choose source and target currencies from the dropdowns
4. **View exchange rates**: See real-time conversion rates in the bar widget
5. **Swap currencies**: Use the swap button to quickly reverse the conversion direction
6. **Adjust settings**: Configure update interval and display preferences

## Configuration

### Default Settings

```json
{
  "fromCurrency": "USD",
  "toCurrency": "BRL",
  "updateInterval": 30,
  "displayMode": "both"
}
```

### Display Modes

- `both` - Shows icon and exchange rate text (e.g., 💱 1 USD = 5.20 BRL)
- `icon` - Shows only the currency icon
- `text` - Shows only the exchange rate text

### Update Intervals

Configure how often the exchange rates are updated:
- Minimum: 1 minute
- Default: 30 minutes
- Recommended: 15-60 minutes (to minimize API calls)

## Supported Currencies

The plugin supports major world currencies including:

- **Americas**: USD, CAD, BRL, ARS, MXN, CLP
- **Europe**: EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON
- **Asia**: JPY, CNY, INR, KRW, SGD, HKD, THB, MYR, IDR, PHP
- **Oceania**: AUD, NZD
- **Middle East**: AED, SAR, ILS, TRY
- **Africa**: ZAR, EGP, NGN

And many more! Check the currency selector in the panel for the complete list.

## Technical Details

- **API**: Uses exchange rate API for real-time currency data
- **Translations**: Plugin-specific translations via standard i18n system
- **Storage**: Settings are automatically persisted across restarts
- **Performance**: Smart caching with configurable update intervals
- **Error Handling**: Graceful fallback for network errors

## Screenshots

### Bar Widget
The widget displays the current exchange rate in a compact format on your bar.

### Converter Panel
Full-featured panel with:
- Currency selection dropdowns
- Real-time exchange rate display
- Swap button for quick currency reversal
- Refresh button for manual updates
- Status indicators (loading, error, success)

## Development

### File Structure

```
currency-converter/
├── BarWidget.qml       # Bar widget component
├── Panel.qml           # Converter panel
├── Settings.qml        # Settings page component
├── manifest.json       # Plugin metadata
├── settings.json       # Default settings
├── README.md           # This file
└── i18n/               # Translation files
    ├── en.json
    ├── pt.json
    ├── es.json
    └── ...
```

### Translation Keys

The plugin uses standard Noctalia i18n format:

```json
{
  "currency-converter.title": "Currency Converter",
  "currency-converter.from": "From",
  "currency-converter.to": "To",
  "currency-converter.swap": "Swap currencies"
}
```

### API Integration

The plugin fetches exchange rates from a public API with the following features:
- Automatic retry on failure
- Rate limiting to respect API quotas
- Local caching for offline operation
- Graceful degradation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Adding New Currencies

1. Add currency code to the available currencies list
2. Test exchange rate fetching for the new currency
3. Update translations if currency names need localization

### Improving Exchange Rate APIs

If you know of better exchange rate APIs:
1. Document the API endpoints and requirements
2. Implement error handling for rate limits
3. Add configuration options for API selection

## Troubleshooting

### Exchange rates not updating
- Check your internet connection
- Verify the update interval is not set too high
- Use the refresh button to manually fetch new rates

### "No data available" message
- The plugin is waiting for the first API response
- Check if your firewall is blocking the API requests
- Try increasing the update interval

### Display issues
- Try different display modes (icon, text, both)
- Check if the widget has enough space on the bar
- Restart Noctalia Shell if the widget doesn't appear

## License

MIT License - see [LICENSE](../LICENSE) file for details

## Credits

- **Author**: Noctalia Community
- **Repository**: https://github.com/noctalia-dev/noctalia-plugins
- **Noctalia Shell**: https://noctalia.dev
- **Exchange Rate Data**: Powered by public exchange rate APIs

## Changelog

### v1.0.0 (2026-01-04)
- Initial release
- Support for major world currencies
- 12 language translations
- Configurable update intervals
- Multiple display modes
- Real-time exchange rates
- Clean and intuitive UI

## Future Enhancements

- [ ] Historical exchange rate charts
- [ ] Multiple currency pairs simultaneously
- [ ] Custom amount conversion in panel
- [ ] Notification on significant rate changes
- [ ] Favorite currency pairs
- [ ] Offline mode with last known rates
