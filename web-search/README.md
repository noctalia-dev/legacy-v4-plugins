# Web Search

A launcher provider plugin that allows you to quickly search the internet directly from the Noctalia launcher, complete with live autocomplete suggestions.

## Features

- **Quick Web Searching**: Search the web instantly without opening a browser first
- **Live Autocomplete**: Get search suggestions from your preferred engine as you type
- **Multiple Search Engines**: Support for Google, DuckDuckGo, Bing, Brave, and Yandex
- **Smart Priorities**: Web search acts as a fallback when searching for apps, or takes absolute priority when using the explicit `>web` command

## Usage

1. Open the Noctalia launcher
2. Type `>web` to enter web search mode exclusively, OR just type your query directly into the launcher and scroll to the bottom to see web search fallbacks.
3. Your live suggestions will populate underneath the main result
4. Hit Enter to open the query in your default browser

### Examples

```bash
# Explicitly search for recipes, bypassing all local files/apps
>web chocolate cake recipe

# Search fallbacks (appears at bottom of launcher below matched applications)
discord
```

## Configuration

You can configure the plugin directly via Noctalia's Plugin API Settings:
- **Search Engine**: Choose between Google, DuckDuckGo, Bing, Brave, or Yandex
- **Show Search Suggestions**: Toggle whether to fetch real-time suggestions while typing
- **Maximum Results**: Control how many autocomplete suggestions appear in the launcher at once (1 to 10)

## Requirements

- Noctalia 3.9.0 or later
- Internet connection (for search suggestions)