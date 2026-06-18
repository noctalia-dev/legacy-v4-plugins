# Battery Monitor Plus

Extended battery monitor for Noctalia Shell.

## Features

- Bar widget using Noctalia's original battery graphic, with optional current power draw and remaining time.
- Panel details for status, discharge or charging power, remaining or full-charge time, charge level, battery health, and current power profile.
- Settings for showing power draw and remaining time in the bar, plus display refresh interval.
- Power and time estimates are read directly from `/sys/class/power_supply` and related `hwmon` nodes when available, with UPower used only as a UI fallback.
- English and Simplified Chinese translations.

## Layout

Bar:

```text
battery graphic · 6.4W · 5h12m
```

Panel:

```text
Status: Discharging / Charging
Current power draw / Charging power: 6.4 W
Remaining time / Time until full: 5h12m
Battery level: 72%
Battery health: 91%
Current power profile: power-saver / balanced / performance
```

## Notes

Power draw and time estimates come from kernel `power_supply`/`hwmon` interfaces when possible. If the battery reports `0 W` while full or idle, the plugin also checks battery and online adapter hwmon nodes for a live hardware power value. Battery health still comes from Noctalia's `BatteryService`/UPower. Some systems or batteries may not report every field.
