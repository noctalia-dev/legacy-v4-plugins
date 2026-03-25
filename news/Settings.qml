import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi: null
  
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Local state
  property string apiKeyValue: cfg.apiKey ?? defaults.apiKey ?? "YOUR_API_KEY_HERE"
  property string countryValue: cfg.country ?? defaults.country ?? "us"
  property string languageValue: cfg.language ?? defaults.language ?? "en"
  property string categoryValue: cfg.category ?? defaults.category ?? "general"
  property int refreshIntervalValue: cfg.refreshInterval ?? defaults.refreshInterval ?? 30
  property int maxHeadlinesValue: cfg.maxHeadlines ?? defaults.maxHeadlines ?? 10
  property int widgetWidthValue: cfg.widgetWidth ?? defaults.widgetWidth ?? 300
  property int rollingSpeedValue: cfg.rollingSpeed ?? defaults.rollingSpeed ?? 50

  function saveSettings() {
    if (!pluginApi) return;
    
    pluginApi.pluginSettings.apiKey = apiKeyValue;
    pluginApi.pluginSettings.country = countryValue;
    pluginApi.pluginSettings.language = languageValue;
    pluginApi.pluginSettings.category = categoryValue;
    pluginApi.pluginSettings.refreshInterval = refreshIntervalValue;
    pluginApi.pluginSettings.maxHeadlines = maxHeadlinesValue;
    pluginApi.pluginSettings.widgetWidth = widgetWidthValue;
    pluginApi.pluginSettings.rollingSpeed = rollingSpeedValue;
    
    pluginApi.saveSettings();
  }

  NTextInput {
    label: "API Key"
    description: "Get your free API key from newsapi.org/register"
    text: apiKeyValue
    onTextChanged: {
      apiKeyValue = text
      saveSettings()
    }
  }

  NButton {
    text: "Get API Key"
    icon: "external-link"
    onClicked: Qt.openUrlExternally("https://newsapi.org/register")
  }

  NComboBox {
    label: "Country/Region"
    description: "Note: NewsAPI free tier only supports US for country-specific top headlines. Other regions use language-based filtering instead."
    minimumWidth: 200
    model: [
      { "key": "us", "name": "United States (English)" },
      { "key": "gb", "name": "United Kingdom (English)" },
      { "key": "ca", "name": "Canada (English)" },
      { "key": "au", "name": "Australia (English)" },
      { "key": "de", "name": "Germany (German)" },
      { "key": "fr", "name": "France (French)" },
      { "key": "it", "name": "Italy (Italian)" },
      { "key": "es", "name": "Spain (Spanish)" },
      { "key": "mx", "name": "Mexico (Spanish)" },
      { "key": "br", "name": "Brazil (Portuguese)" },
      { "key": "jp", "name": "Japan (Japanese)" },
      { "key": "kr", "name": "South Korea (Korean)" },
      { "key": "nl", "name": "Netherlands (Dutch)" },
      { "key": "se", "name": "Sweden (Swedish)" },
      { "key": "no", "name": "Norway (Norwegian)" },
      { "key": "in", "name": "India (English)" }
    ]
    currentKey: countryValue
    onSelected: key => {
      countryValue = key;
      saveSettings();
    }
  }

  NComboBox {
    label: "Language Override"
    description: "Manually override language (auto-detected from country by default)"
    minimumWidth: 200
    model: [
      { "key": "en", "name": "English" },
      { "key": "de", "name": "German" },
      { "key": "fr", "name": "French" },
      { "key": "it", "name": "Italian" },
      { "key": "es", "name": "Spanish" },
      { "key": "pt", "name": "Portuguese" },
      { "key": "nl", "name": "Dutch" },
      { "key": "no", "name": "Norwegian" },
      { "key": "sv", "name": "Swedish" },
      { "key": "ja", "name": "Japanese" },
      { "key": "ko", "name": "Korean" },
      { "key": "ar", "name": "Arabic" },
      { "key": "ru", "name": "Russian" },
      { "key": "zh", "name": "Chinese" }
    ]
    currentKey: languageValue
    onSelected: key => {
      languageValue = key;
      saveSettings();
    }
  }

  NComboBox {
    label: "Category"
    description: "Filter news by category"
    minimumWidth: 200
    model: [
      { "key": "general", "name": "General" },
      { "key": "business", "name": "Business" },
      { "key": "entertainment", "name": "Entertainment" },
      { "key": "health", "name": "Health" },
      { "key": "science", "name": "Science" },
      { "key": "sports", "name": "Sports" },
      { "key": "technology", "name": "Technology" }
    ]
    currentKey: categoryValue
    onSelected: key => {
      categoryValue = key;
      saveSettings();
    }
  }

  NSpinBox {
    label: "Refresh Interval"
    description: "Check for new headlines every " + refreshIntervalValue + " minutes"
    from: 5
    to: 1440
    stepSize: 5
    value: refreshIntervalValue
    onValueChanged: {
      refreshIntervalValue = value;
      saveSettings();
    }
  }

  NSpinBox {
    label: "Max Headlines"
    description: "Maximum number of headlines to display"
    from: 1
    to: 100
    value: maxHeadlinesValue
    onValueChanged: {
      maxHeadlinesValue = value;
      saveSettings();
    }
  }

  NSpinBox {
    label: "Widget Width"
    description: "Widget width in pixels: " + widgetWidthValue + "px"
    from: 100
    to: 1000
    stepSize: 10
    value: widgetWidthValue
    onValueChanged: {
      widgetWidthValue = value;
      saveSettings();
    }
  }

  NSpinBox {
    label: "Scroll Speed"
    description: "Time in ms per pixel (lower = faster): " + rollingSpeedValue + "ms"
    from: 10
    to: 200
    stepSize: 10
    value: rollingSpeedValue
    onValueChanged: {
      rollingSpeedValue = value;
      saveSettings();
    }
  }
}
