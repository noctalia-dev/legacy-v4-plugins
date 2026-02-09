# Weekly Calendar Plugin

A weekly calendar plugin that makes use of Noctalia's [CalendarService.qml](https://github.com/noctalia-dev/noctalia-shell/blob/main/Services/Location/CalendarService.qml) to display events.
## Features

- **Bar Widget**: Show a quick tooltip to see current and upcoming events on hover (updates occur on click);
- **Panel**: Complete weekly calendar interface supporting both all-day and normal events with a native-like interface;
- **Keyboard Navigation**: Use arrow keys to navigate through your events;
- **Settings**: Choose time format, first day of the week, grid line colour and opacity.

## Installation

This plugin is part of the [noctalia-plugins](https://github.com/noctalia-dev/noctalia-plugins) repository, installation can either be done by:
1. adding it as a source in the plugins section;
2. cloning this into `~/.config/noctalia/plugins`.

## Configuration

- **First day of week**: Choose which day starts the week in the weekly calendar (Monday, Sunday or Saturday).
- **Use 12-hour format**: Display time in 12-hour format (AM/PM) instead of 24-hour format.
- **Grid Lines**: Depending on your theming, choose the color and opacity used for the grid lines for better visibility.

## IPC Commands

Currently there is `1` IPC command:

```bash
# Toggle the panel
qs -c noctalia-shell ipc call plugin:weekly-calendar togglePanel
```

## Usage

As a result of relying on Noctalia's [CalendarService.qml](https://github.com/noctalia-dev/noctalia-shell/blob/main/Services/Location/CalendarService.qml), this plugin supports any calendar that works with `evolution-data-server`, covering all major calendar services (e.g. NextCloud, Google Calendar, and CalDAV / WebDAV servers).

The most straightforward ways to start is by either downloading `evolution` or `gnome-calendar` and set calendars through them. 

## Minimum Requirements

- **Noctalia Shell**: 4.2.3 or later.
- `evolution-data-server` (also needed for Noctalia's month calendar to display events)
- **Python packages**: EDataServer, ECal, and ICalGLib. (see [calendar-events.py](https://github.com/noctalia-dev/noctalia-shell/blob/main/Scripts/python/src/calendar/calendar-events.py))

