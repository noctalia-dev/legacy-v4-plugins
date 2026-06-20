# NixOS / Home Manager example

`keep-awake-plus.nix` is a self-contained Home Manager module that complements
the plugin with two things:

1. **Runtime dependencies on PATH** — `jq`, `glib` (for `gdbus`), and
   `libnotify` (for `notify-send`). The plugin's shipped
   [`scripts/system-awake`](../scripts/system-awake) is portable and falls back
   gracefully when `gdbus` / `notify-send` aren't available, so this is the
   only wiring you need to make on a stock NixOS setup with `programs.noctalia-shell`.

2. **Optional thermal watchdog** — `system-awake-thermal-guard` is a systemd
   user service that polls `/sys/class/thermal/thermal_zone*/temp` while a
   keep-awake session is active and force-suspends the laptop if it overheats.
   Two trip conditions:

   - **Critical (98 °C × 20 s)** — unconditional suspend. Last-resort
     protection against thermal damage.
   - **Bag (85 °C × 60 s + lid closed + no external monitor)** — suspends when
     the laptop is likely tucked into a bag with full inhibits engaged. Skipped
     when docked so long renders / builds aren't interrupted.

   The plugin's `system-awake` script starts and stops this unit imperatively
   as sessions toggle, so it only burns power while you actually need it.

## Usage

```nix
{
  imports = [ ./keep-awake-plus.nix ];

  programs.keep-awake-plus = {
    enable = true;
    thermalGuard = {
      enable = true;
      # Defaults shown — tune per machine.
      bagThresholdCelsius = 85;
      bagSustainTicks = 6;            # 6 × 10 s polls = 60 s
      criticalThresholdCelsius = 98;
      criticalSustainTicks = 2;       # 2 × 10 s polls = 20 s
    };
  };
}
```

The watchdog logs to `/tmp/system-awake-thermal-guard.log`. Tail it while
testing to confirm thresholds make sense for your hardware before relying on
the bag-mode trip.

## Notes

- This module assumes Noctalia and the plugin are already installed via
  `programs.noctalia-shell.plugins` — it does not declare the plugin itself.
- The watchdog has no `[Install]` section. Don't `systemctl --user enable` it
  manually; the `system-awake` script handles its lifecycle.
- The bag-mode trip uses `/sys/class/drm/card*/status` to detect external
  monitors. If your dock exposes connectors with unusual names you may need to
  tweak `has_external_monitors` in the script.
