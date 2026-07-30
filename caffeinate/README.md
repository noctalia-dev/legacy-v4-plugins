# Caffeinate

Caffeinate is a prefix-only Noctalia v4 launcher provider for temporarily
pausing idle-triggered display, lock, and suspend actions.

## Usage

Open the launcher and use `>caffeinate`, or the configurable `>c` alias:

```text
>c 30m
>c 1h 30m
>c 1:30
>c ::30
>c forever
>c status
>c off
```

The optional bar widget remains available as a dimmed off-state by default.
During a finite session it always shows a rounded-to-minute countdown; hovering
reveals the exact countdown, including seconds, after Noctalia's normal delay.
Left-click opens a session menu for presets, cancellation, and launcher access;
right-click opens **Widget settings**.

Named-unit input supports seconds through weeks, flexible spacing and
separators, and dot or comma decimals. Clock forms interpret two fields as
hours and minutes, so `1:30` means 1 hour 30 minutes and `:30` means 30
minutes.

## Scope

Caffeinate changes Noctalia's shared **manual idle inhibitor**. It does not
override explicit power actions, lid behavior, critical-battery handling, or
administrative power policy. Sessions end when Noctalia stops or restarts.

## Configuration

The plugin settings provide:

- an optional launcher alias, defaulting to `c`;
- editable and reorderable duration presets;
- a switch for the **Until stopped** preset;
- a switch for hiding the bar widget between sessions;
- reset-to-defaults behavior.

## Source and documentation

The canonical source, installation guide, detailed syntax, AI-assistance
disclosure, and contribution guide are available at:

<https://github.com/josteinhanssen/caffeinate-provider>

Caffeinate is licensed under the MIT License.
