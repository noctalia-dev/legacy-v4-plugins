# Example Home Manager module for Keep Awake+ on NixOS.
#
# The plugin's shipped `scripts/system-awake` is portable and self-contained
# (it uses `command -v` fallbacks), so this module only handles two things:
#
#   programs.keep-awake-plus.enable           -> puts runtime tools on PATH
#   programs.keep-awake-plus.thermalGuard.*   -> optional thermal watchdog
#                                                that force-suspends if the
#                                                laptop overheats while a
#                                                keep-awake session is active
#
# Usage:
#
#   imports = [ ./keep-awake-plus.nix ];
#
#   programs.keep-awake-plus = {
#     enable = true;
#     thermalGuard.enable = true;
#   };
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.keep-awake-plus;

  thermal-guard = pkgs.writeShellScriptBin "system-awake-thermal-guard" ''
    #!/usr/bin/env bash
    set -uo pipefail

    TAG="noctalia-keep-awake"
    LOG="/tmp/system-awake-thermal-guard.log"
    POLL_INTERVAL=10
    BAG_THRESHOLD=${toString (cfg.thermalGuard.bagThresholdCelsius * 1000)}
    BAG_SUSTAIN_TICKS=${toString cfg.thermalGuard.bagSustainTicks}
    CRITICAL_THRESHOLD=${toString (cfg.thermalGuard.criticalThresholdCelsius * 1000)}
    CRITICAL_SUSTAIN_TICKS=${toString cfg.thermalGuard.criticalSustainTicks}

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG" >&2
    }

    max_temp_mC() {
      local max=0 t
      for f in /sys/class/thermal/thermal_zone*/temp; do
        [[ -r "$f" ]] || continue
        t=$(cat "$f" 2>/dev/null || echo 0)
        (( t > max )) && max=$t
      done
      echo "$max"
    }

    is_lid_closed() {
      ${pkgs.glib}/bin/gdbus call --system \
        --dest org.freedesktop.UPower \
        --object-path /org/freedesktop/UPower \
        --method org.freedesktop.DBus.Properties.Get \
        org.freedesktop.UPower LidIsClosed 2>/dev/null | grep -q 'true'
    }

    has_external_monitors() {
      local status connector name
      for status in /sys/class/drm/card*/status; do
        [[ -f "$status" ]] || continue
        connector=$(basename "$(dirname "$status")")
        name=''${connector#card?-}
        if [[ "$(cat "$status")" == "connected" && \
              "$name" != "eDP-1" && \
              "$name" != "Writeback-1" ]]; then
          return 0
        fi
      done
      return 1
    }

    emergency_suspend() {
      local reason="$1" temp_c="$2"
      log "EMERGENCY: $reason (max=''${temp_c}°C) — forcing suspend"
      ${pkgs.libnotify}/bin/notify-send -u critical -i dialog-warning \
        "Thermal Protection" \
        "System too hot (''${temp_c}°C) — suspending to protect hardware" \
        -t 5000 || true

      # Drop the plugin's sleep inhibitors so `systemctl suspend` is not blocked.
      pkill -f "systemd-inhibit.*$TAG" 2>/dev/null || true
      sleep 0.3

      ${pkgs.systemd}/bin/loginctl lock-session || true
      sleep 0.5
      ${pkgs.systemd}/bin/systemctl suspend
    }

    log "Thermal guard started (poll=''${POLL_INTERVAL}s, bag=''${BAG_THRESHOLD}mC/$((BAG_SUSTAIN_TICKS * POLL_INTERVAL))s, critical=''${CRITICAL_THRESHOLD}mC/$((CRITICAL_SUSTAIN_TICKS * POLL_INTERVAL))s)"

    bag_sustained=0
    crit_sustained=0
    while true; do
      temp=$(max_temp_mC)
      temp_c=$(( temp / 1000 ))

      if (( temp >= CRITICAL_THRESHOLD )); then
        crit_sustained=$(( crit_sustained + 1 ))
        log "Critical temp: ''${temp_c}°C (tick $crit_sustained/$CRITICAL_SUSTAIN_TICKS)"
        if (( crit_sustained >= CRITICAL_SUSTAIN_TICKS )); then
          emergency_suspend "sustained critical temperature" "$temp_c"
          exit 0
        fi
      else
        (( crit_sustained > 0 )) && log "Critical recovered (''${temp_c}°C) — resetting counter"
        crit_sustained=0
      fi

      if (( temp >= BAG_THRESHOLD )) && is_lid_closed && ! has_external_monitors; then
        bag_sustained=$(( bag_sustained + 1 ))
        log "Hot + lid-closed + undocked: ''${temp_c}°C (tick $bag_sustained/$BAG_SUSTAIN_TICKS)"
        if (( bag_sustained >= BAG_SUSTAIN_TICKS )); then
          emergency_suspend "sustained high temp while undocked+lid-closed" "$temp_c"
          exit 0
        fi
      else
        (( bag_sustained > 0 )) && log "Recovered (''${temp_c}°C) — resetting bag counter"
        bag_sustained=0
      fi

      sleep "$POLL_INTERVAL"
    done
  '';
in {
  options.programs.keep-awake-plus = {
    enable = lib.mkEnableOption "Keep Awake+ runtime dependencies on PATH";

    thermalGuard = {
      enable = lib.mkEnableOption ''
        the system-awake-thermal-guard systemd user service.

        The plugin's `system-awake` script starts/stops this unit
        imperatively as keep-awake sessions toggle on and off
      '';

      bagThresholdCelsius = lib.mkOption {
        type = lib.types.ints.positive;
        default = 85;
        description = ''
          Temperature (°C) that triggers suspend when sustained for
          bagSustainTicks polls AND the lid is closed AND no external monitor
          is connected (i.e. the laptop is probably in a bag).
        '';
      };

      bagSustainTicks = lib.mkOption {
        type = lib.types.ints.positive;
        default = 6;
        description = "How many 10-second polls the bag-temp condition must hold before triggering suspend.";
      };

      criticalThresholdCelsius = lib.mkOption {
        type = lib.types.ints.positive;
        default = 98;
        description = ''
          Temperature (°C) that triggers unconditional suspend when sustained
          for criticalSustainTicks polls. Fires regardless of lid/monitor state.
        '';
      };

      criticalSustainTicks = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "How many 10-second polls the critical-temp condition must hold before triggering suspend. Kept low to tolerate only brief spikes.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # The plugin's script auto-detects these via `command -v`; on NixOS the
      # core ones (bash, coreutils, systemd-inhibit, pgrep, setsid) are
      # already in the user session, so we only add the genuinely optional ones.
      home.packages = with pkgs; [
        jq # required
        glib # optional: gdbus for UPower lid checks (falls back to /proc/acpi)
        libnotify # optional: notify-send for toasts
      ];
    })

    (lib.mkIf cfg.thermalGuard.enable {
      home.packages = [thermal-guard];

      systemd.user.services.system-awake-thermal-guard = {
        Unit.Description = "Thermal watchdog for Keep Awake+ (force suspend if overheating)";
        Service = {
          Type = "simple";
          ExecStart = "${thermal-guard}/bin/system-awake-thermal-guard";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        # Intentionally no [Install] — started/stopped imperatively by the
        # plugin's system-awake script as sessions begin/end.
      };
    })
  ];
}
