#!/bin/sh

selected="${1:-__default__}"

read_file() {
  if [ -r "$1" ]; then
    tr -d '\n' < "$1"
  fi
}

is_number() {
  case "$1" in
    ''|*[!0-9.]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

is_positive() {
  is_number "$1" || return 1
  awk -v n="$1" 'BEGIN { exit !(n > 0) }'
}

add_float() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.9f", a + b }'
}

calc_hwmon_watts() {
  hwmon_dir="$1"

  # hwmon power inputs are reported in microwatts.
  for input in "$hwmon_dir"/power*_input; do
    [ -r "$input" ] || continue
    raw="$(read_file "$input")"
    if is_positive "$raw"; then
      awk -v p="$raw" 'BEGIN { printf "%.9f", p / 1000000 }'
      return
    fi
  done

  voltage_mv=""
  current_ma=""
  for input in "$hwmon_dir"/in*_input; do
    [ -r "$input" ] || continue
    raw="$(read_file "$input")"
    if is_positive "$raw"; then
      voltage_mv="$raw"
      break
    fi
  done

  for input in "$hwmon_dir"/curr*_input; do
    [ -r "$input" ] || continue
    raw="$(read_file "$input")"
    if is_positive "$raw"; then
      current_ma="$raw"
      break
    fi
  done

  if is_positive "$voltage_mv" && is_positive "$current_ma"; then
    awk -v v="$voltage_mv" -v c="$current_ma" 'BEGIN { printf "%.9f", (v * c) / 1000000 }'
    return
  fi

  printf '%s' "-1"
}

calc_supply_hwmon_watts() {
  dir="$1"

  # Some drivers expose the live value only through the power_supply hwmon node.
  for hwmon_dir in "$dir"/hwmon* "$dir"/device/hwmon/hwmon*; do
    [ -d "$hwmon_dir" ] || continue
    hwmon_w="$(calc_hwmon_watts "$hwmon_dir")"
    if is_positive "$hwmon_w"; then
      printf '%s' "$hwmon_w"
      return
    fi
  done

  printf '%s' "-1"
}

calc_power_watts() {
  dir="$1"
  had_reading=0

  power_now="$(read_file "$dir/power_now")"
  if is_number "$power_now"; then
    had_reading=1
    if is_positive "$power_now"; then
      awk -v p="$power_now" 'BEGIN { printf "%.9f", p / 1000000 }'
      return
    fi
  fi

  current_now="$(read_file "$dir/current_now")"
  voltage_now="$(read_file "$dir/voltage_now")"
  if is_number "$current_now" && is_number "$voltage_now"; then
    had_reading=1
    watts="$(awk -v c="$current_now" -v v="$voltage_now" 'BEGIN { printf "%.9f", (c * v) / 1000000000000 }')"
    if is_positive "$watts"; then
      printf '%s' "$watts"
      return
    fi
  fi

  hwmon_w="$(calc_supply_hwmon_watts "$dir")"
  if is_positive "$hwmon_w"; then
    printf '%s' "$hwmon_w"
    return
  fi

  if [ "$had_reading" -eq 1 ]; then
    printf '%s' "0"
    return
  fi

  printf '%s' "-1"
}

calc_external_supply_watts() {
  total=0
  known=0

  for dir in /sys/class/power_supply/*; do
    [ -d "$dir" ] || continue
    type="$(read_file "$dir/type")"
    [ "$type" = "Battery" ] && continue

    online="$(read_file "$dir/online")"
    [ "$online" = "0" ] && continue

    power_w="$(calc_power_watts "$dir")"
    if is_positive "$power_w"; then
      total="$(add_float "$total" "$power_w")"
      known=1
    fi
  done

  if [ "$known" -eq 1 ]; then
    printf '%s' "$total"
    return
  fi

  printf '%s' "-1"
}

calc_energy_now_wh() {
  dir="$1"
  energy_now="$(read_file "$dir/energy_now")"
  if is_number "$energy_now"; then
    awk -v e="$energy_now" 'BEGIN { printf "%.9f", e / 1000000 }'
    return
  fi

  charge_now="$(read_file "$dir/charge_now")"
  voltage_now="$(read_file "$dir/voltage_now")"
  if is_number "$charge_now" && is_number "$voltage_now"; then
    awk -v c="$charge_now" -v v="$voltage_now" 'BEGIN { printf "%.9f", (c * v) / 1000000000000 }'
    return
  fi

  printf '%s' "0"
}

calc_energy_full_wh() {
  dir="$1"
  energy_full="$(read_file "$dir/energy_full")"
  if is_number "$energy_full"; then
    awk -v e="$energy_full" 'BEGIN { printf "%.9f", e / 1000000 }'
    return
  fi

  charge_full="$(read_file "$dir/charge_full")"
  voltage_now="$(read_file "$dir/voltage_now")"
  if is_number "$charge_full" && is_number "$voltage_now"; then
    awk -v c="$charge_full" -v v="$voltage_now" 'BEGIN { printf "%.9f", (c * v) / 1000000000000 }'
    return
  fi

  printf '%s' "0"
}

matches_selected() {
  name="$1"
  case "$selected" in
    ""|"__default__"|"DisplayDevice")
      return 0
      ;;
    "$name"|*"$name"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

count=0
power_known=0
total_power=0
total_energy_now=0
total_energy_missing=0
capacity_sum=0
capacity_count=0
any_charging=0
any_discharging=0
all_full=1
source_names=""

for dir in /sys/class/power_supply/*; do
  [ -d "$dir" ] || continue
  type="$(read_file "$dir/type")"
  [ "$type" = "Battery" ] || continue

  name="$(basename "$dir")"
  matches_selected "$name" || continue

  status="$(read_file "$dir/status")"
  capacity="$(read_file "$dir/capacity")"
  power_w="$(calc_power_watts "$dir")"
  energy_now_wh="$(calc_energy_now_wh "$dir")"
  energy_full_wh="$(calc_energy_full_wh "$dir")"
  energy_missing_wh="$(awk -v f="$energy_full_wh" -v n="$energy_now_wh" 'BEGIN { d = f - n; if (d > 0) printf "%.9f", d; else printf "%.9f", 0 }')"

  count=$((count + 1))
  source_names="${source_names}${source_names:+,}${name}"

  if is_number "$power_w" && awk -v p="$power_w" 'BEGIN { exit !(p >= 0) }'; then
    total_power="$(add_float "$total_power" "$power_w")"
    power_known=1
  fi

  total_energy_now="$(add_float "$total_energy_now" "$energy_now_wh")"
  total_energy_missing="$(add_float "$total_energy_missing" "$energy_missing_wh")"

  if is_number "$capacity"; then
    capacity_sum=$((capacity_sum + capacity))
    capacity_count=$((capacity_count + 1))
  fi

  case "$status" in
    Charging)
      any_charging=1
      all_full=0
      ;;
    Discharging)
      any_discharging=1
      all_full=0
      ;;
    Full)
      ;;
    *)
      all_full=0
      ;;
  esac
done

if [ "$count" -eq 0 ]; then
  printf '{"ok":false,"error":"no battery found","powerWatts":-1,"timeToEmpty":0,"timeToFull":0,"capacity":-1,"status":"","source":""}\n'
  exit 0
fi

if [ "$power_known" -eq 0 ] || ! is_positive "$total_power"; then
  external_power="$(calc_external_supply_watts)"
  if is_positive "$external_power"; then
    total_power="$external_power"
    power_known=1
  fi
fi

if [ "$power_known" -eq 0 ]; then
  total_power="-1"
fi

if [ "$any_charging" -eq 1 ]; then
  status_json="Charging"
elif [ "$any_discharging" -eq 1 ]; then
  status_json="Discharging"
elif [ "$all_full" -eq 1 ]; then
  status_json="Full"
else
  status_json="Not charging"
fi

time_to_empty=0
time_to_full=0
if awk -v p="$total_power" 'BEGIN { exit !(p > 0) }'; then
  if [ "$status_json" = "Charging" ]; then
    time_to_full="$(awk -v e="$total_energy_missing" -v p="$total_power" 'BEGIN { printf "%d", (e / p) * 3600 }')"
  elif [ "$status_json" = "Discharging" ]; then
    time_to_empty="$(awk -v e="$total_energy_now" -v p="$total_power" 'BEGIN { printf "%d", (e / p) * 3600 }')"
  fi
fi

capacity_avg=-1
if [ "$capacity_count" -gt 0 ]; then
  capacity_avg=$((capacity_sum / capacity_count))
fi

printf '{"ok":true,"status":"%s","powerWatts":%.6f,"timeToEmpty":%s,"timeToFull":%s,"capacity":%s,"source":"%s"}\n' \
  "$status_json" "$total_power" "$time_to_empty" "$time_to_full" "$capacity_avg" "$source_names"
