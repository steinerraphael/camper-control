#!/usr/bin/env bash
# Macht den Pi zum WLAN-Zugangspunkt, damit das Handy ohne Router verbinden
# kann. Bleibt nach jedem Neustart aktiv.
#
#   sudo deploy/hotspot.sh                 # WLAN "Camper", fragt nach dem Passwort
#   sudo deploy/hotspot.sh MeinBus         # anderer WLAN-Name
#   sudo deploy/hotspot.sh off             # zurück: Pi meldet sich wieder in bekannten WLANs an
#
# Danach im Handy mit dem WLAN verbinden und http://camper.local:8080
# öffnen (oder http://10.42.0.1:8080, falls .local nicht klappt).
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }
command -v nmcli >/dev/null || { echo "NetworkManager fehlt (ab Raspberry Pi OS Bookworm Standard)."; exit 1; }

CON=camper-hotspot

if [[ "${1:-}" == "off" ]]; then
  nmcli connection modify "$CON" connection.autoconnect no 2>/dev/null || true
  nmcli connection down "$CON" 2>/dev/null || true
  echo "Hotspot aus. Der Pi verbindet sich wieder mit bekannten WLANs."
  exit 0
fi

SSID="${1:-Camper}"
read -rsp "Passwort für das WLAN \"$SSID\" (mind. 8 Zeichen): " PASS; echo
[[ ${#PASS} -ge 8 ]] || { echo "Passwort zu kurz."; exit 1; }

# Ohne Ländereinstellung bleibt das WLAN-Modul gesperrt.
raspi-config nonint do_wifi_country DE

nmcli connection delete "$CON" >/dev/null 2>&1 || true
nmcli connection add type wifi ifname wlan0 con-name "$CON" ssid "$SSID" \
  802-11-wireless.mode ap 802-11-wireless.band bg \
  ipv4.method shared ipv4.addresses 10.42.0.1/24 \
  wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn \
  wifi-sec.pairwise ccmp wifi-sec.group ccmp wifi-sec.psk "$PASS" \
  connection.autoconnect yes connection.autoconnect-priority 100 >/dev/null

echo
echo "Der Hotspot startet jetzt. Eine SSH-Verbindung über WLAN bricht dabei ab –"
echo "danach mit dem WLAN \"$SSID\" verbinden und neu einloggen:"
echo "  ssh $(logname 2>/dev/null || echo pi)@10.42.0.1"
echo
echo "Dashboard: http://camper.local:8080  oder  http://10.42.0.1:8080"
sleep 2
nmcli connection up "$CON" >/dev/null
