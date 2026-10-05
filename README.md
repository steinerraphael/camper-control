# Camper Control

Zentrale Steuereinheit für einen VW T5 Camper auf einem Raspberry Pi:
Verbraucher schalten, Batterie und Temperaturen überwachen, alles vom Handy im
lokalen Netz. Versorgt aus dem 12-V-Bordnetz.

## Was es kann

- **Schalten** von Licht, Pumpe, Kühlbox, USB und Lüfter über Relais oder MOSFETs
- **Batterie**: Spannung, Strom und Leistung der Aufbaubatterie (INA226 mit Shunt)
- **Temperaturen**: Innenraum, Kühlbox und mehr (DS18B20)
- **Unterspannungsschutz**: Fällt die Batteriespannung länger als 30 s unter
  die Schwelle, werden Verbraucher nach Priorität abgeschaltet und gesperrt.
  Kurze Einbrüche (Kompressoranlauf) lösen nichts aus. Nach Erholung wird
  freigegeben, aber nichts automatisch wieder eingeschaltet.
- **Weboberfläche** fürs Handy (zum Homescreen hinzufügbar), Live-Updates per WebSocket
- **Konfiguration per YAML**: Neue Verbraucher brauchen keine Codeänderung

## Schnellstart am Rechner (ohne Pi)

```bash
make install
make dev            # http://localhost:8080, simulierte Hardware
make test
```

## Installation auf dem Pi

```bash
git clone <repo-url> && cd camper-control
sudo deploy/install.sh
sudo nano /etc/camper-control/config.yaml   # Pins und Sensor-IDs eintragen
sudo reboot                                 # aktiviert I2C und 1-Wire
```

Verkabelung, Stromversorgung und Sicherheit: **[docs/hardware.md](docs/hardware.md)**.

## API

| Methode | Pfad | |
|---|---|---|
| GET | `/api/state` | Schalter, Sensorwerte, Schutzstatus |
| PUT | `/api/switches/{id}` | `{"on": true}`, 404 unbekannt, 409 gesperrt |
| WS | `/api/ws` | Zustand bei jeder Änderung |
| GET | `/health` | Lebenszeichen |

Interaktive Doku unter `/docs`.

## Ausbaustufen

| Stufe | Inhalt | Status |
|---|---|---|
| 1 | Schalten, INA226, DS18B20, Unterspannungsschutz, Web-UI | **fertig** (am Rechner getestet, auf Hardware noch nicht) |
| 2 | Victron VE.Direct (MPPT-Solarregler, SmartShunt) | offen |
| 3 | Tankfüllstand (Widerstandsgeber über ADS1115), D+-Eingang | offen |
| 4 | Regeln/Zeitpläne (z. B. Kühlbox nur bei Motorlauf oder Solarüberschuss) | offen |
| 5 | MQTT und Home Assistant, Zugangsschutz, Verlauf/Diagramme | offen |
