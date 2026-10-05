#!/usr/bin/env bash
# Installiert Camper Control auf einem Raspberry Pi (Raspberry Pi OS Bookworm oder neuer).
# Aufruf aus dem geklonten Repo:  sudo deploy/install.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }

SRC="$(cd "$(dirname "$0")/.." && pwd)"
APP=/opt/camper-control
ETC=/etc/camper-control

echo "==> Pakete"
apt-get update -q
apt-get install -y -q python3-venv python3-dev i2c-tools

echo "==> I2C und 1-Wire aktivieren (wirkt nach Neustart)"
raspi-config nonint do_i2c 0
raspi-config nonint do_onewire 0

echo "==> Dienstnutzer"
id camper &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin camper
usermod -aG gpio,i2c camper

echo "==> Programm nach $APP"
mkdir -p "$APP"
cp -r "$SRC/camper" "$SRC/pyproject.toml" "$APP/"
python3 -m venv "$APP/.venv"
"$APP/.venv/bin/pip" install -q --upgrade pip
"$APP/.venv/bin/pip" install -q "$APP[pi]"

echo "==> Konfiguration"
mkdir -p "$ETC"
if [[ ! -f "$ETC/config.yaml" ]]; then
  sed 's/^driver: mock/driver: pi/' "$SRC/config/config.example.yaml" > "$ETC/config.yaml"
  echo "    $ETC/config.yaml angelegt – Pins und Sensor-IDs jetzt anpassen!"
else
  echo "    $ETC/config.yaml existiert, bleibt unverändert."
fi

echo "==> systemd"
cp "$SRC/deploy/camper-control.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable camper-control

echo
echo "Fertig. Nach dem Anpassen der Konfiguration:"
echo "  sudo systemctl restart camper-control"
echo "  journalctl -u camper-control -f"
echo "Weboberfläche: http://$(hostname).local:8080"
