#!/bin/bash
set -euo pipefail

interface=${1:-$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')}
[[ -n $interface ]] || { echo "No wifi interface found" >&2; exit 1; }

uuid=$(nmcli --get-values GENERAL.CON-UUID device show "$interface" | head -n1)
[[ -n $uuid && $uuid != "--" ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }

mapfile -t fields < <(nmcli --show-secrets --escape no --get-values \
  802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 \
  connection show uuid "$uuid")

ssid=${fields[0]:-}; key_management=${fields[1]:-}; password=${fields[2]:-}
hidden=${fields[3]:-no}; wep_key=${fields[4]:-}
[[ -n $ssid ]] || { echo "Could not read SSID" >&2; exit 1; }

# Emit the network name for QML to read
echo "SSID:$ssid"

escape_wifi_qr() {
  local v=$1
  v=${v//\\/\\\\}; v=${v//;/\\;}; v=${v//,/\\,}; v=${v//:/\\:}
  printf '%s' "$v"
}

if [[ -n $key_management && $key_management != "none" ]]; then
  security=WPA
elif [[ -n $wep_key ]]; then
  password=$wep_key; security=WEP
else
  security=nopass
fi

payload="WIFI:T:$security;S:$(escape_wifi_qr "$ssid");P:$(escape_wifi_qr "$password");"
[[ $hidden == "yes" ]] && payload+="H:true;"
payload+=";"

ascii=$(printf '%s' "$payload" | qrencode --type ASCII --margin 4 --output -)
while IFS= read -r line; do
  row=
  for ((c = 0; c < ${#line}; c += 2)); do
    [[ ${line:c:2} == *#* ]] && row+=1 || row+=0
  done
  printf '%s\n' "$row"
done <<<"$ascii"
