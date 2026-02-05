# Pomodoro Plugin

A Pomodoro timer plugin for Noctalia for productivity. Happy Coding :)

***Note:*** The only translation available right now is english, more translations will be added in the future.

## Features

- **Sessions**: There are configurable sessions for the pomodoro plugin based on the standard format (work - short break - long break), all of them can be configured in the settings.
- **Cycles**: Cycles are also configurable such that the user can set the number of cycles before a long break.
- **Session Tracking**: Tracks completed sessions in a cycle.
- **Auto-start**: Optionally auto-start breaks and/or work sessions.
- **Compact Mode**: Shorter and more minimal panel view without the progress ring.
- **Bar Widget**: Shows current mode based on the icon and remaining time with respect to the session.
- **Notifications**: Sound and toast notification when sessions finish.

## Work in Progress
- **Custom Presets**: Presets that user can create and store locally and select them while starting a pomodoro session.
- **Custom Sounds**: Custom sounds that user can select or add themselves that will be used to notify when a work/break session ends.

## IPC Commands

You can control the pomodoro plugin via the command line using the Noctalia IPC interface.

### General Usage
```bash
qs -c noctalia-shell ipc call plugin:pomodoro <command>
```

### Available Commands

| Command | Description | Example |
|---|---|---|
| `toggle` | Opens or closes the pomodoro panel on the current screen | `qs -c noctalia-shell ipc call plugin:pomodoro toggle` |
| `start` | Starts/resumes the pomodoro timer | `qs -c noctalia-shell ipc call plugin:pomodoro start` |
| `pause` | Pauses the running timer | `qs -c noctalia-shell ipc call plugin:pomodoro pause` |
| `reset` | Resets the current session | `qs -c noctalia-shell ipc call plugin:pomodoro reset` |
| `resetAll` | Resets all sessions and returns to work mode | `qs -c noctalia-shell ipc call plugin:pomodoro resetAll` |
| `skip` | Skips to the next phase (work → break or break → work) | `qs -c noctalia-shell ipc call plugin:pomodoro skip` |
| `stopAlarm` | Stops the alarm sound when ringing | `qs -c noctalia-shell ipc call plugin:pomodoro stopAlarm` |

### Examples

**Start a pomodoro session:**
```bash
qs -c noctalia-shell ipc call plugin:pomodoro start
```

**Skip to break after finishing work early:**
```bash
qs -c noctalia-shell ipc call plugin:pomodoro skip
```

**Reset everything and start fresh:**
```bash
qs -c noctalia-shell ipc call plugin:pomodoro resetAll
```

## Settings

***Note:*** These settings are stored in the settings.json file and can be changed by opening the widget settings.

| Setting | Default | Description |
|---|---|---|
| `workDuration` | 25 min | Duration of each work session |
| `shortBreakDuration` | 5 min | Duration of short breaks |
| `longBreakDuration` | 15 min | Duration of long breaks |
| `sessionsBeforeLongBreak` | 4 | Number of work sessions before a long break |
| `autoStartBreaks` | false | Automatically start break timer after work |
| `autoStartWork` | false | Automatically start work timer after break |
| `compactMode` | false | Hide the circular progress bar |

## Credits

- **Alarm Sound**: `alarm.mp3` - Sourced from [Pixabay](https://pixabay.com/) (Royalty-free, [Pixabay Content License](https://pixabay.com/service/license-summary/))
