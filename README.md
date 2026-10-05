# Camper Control

Zentrale Steuereinheit für einen VW T5 Camper auf einem Raspberry Pi:
Verbraucher schalten, Batterie und Temperaturen überwachen, alles vom Handy im
lokalen Netz. Versorgt aus dem 12-V-Bordnetz.

**Demo zum Ausprobieren (simuliertes Fahrzeug):**
https://steinerraphael.github.io/camper-control/

## Was es kann

- **Schalten** von Licht, Pumpe, Kühlbox, USB und Lüfter über Relais oder MOSFETs
- **Batterie**: Spannung, Strom und Leistung der Aufbaubatterie (INA226 mit Shunt)
- **Temperaturen**: Innenraum, Kühlbox und mehr (DS18B20)
- **Unterspannungsschutz**: Fällt die Batteriespannung länger als 30 s unter
  die Schwelle, werden Verbraucher nach Priorität abgeschaltet und gesperrt.
  Kurze Einbrüche (Kompressoranlauf) lösen nichts aus. Nach Erholung wird
  freigegeben, aber nichts automatisch wieder eingeschaltet.
- **Smartphone-App** (Flutter, im Browser oder auf dem Homescreen): Startseite mit
  Verbindungsstatus, Menü mit Schalter, Energie, Klima und Einstellungen,
  Live-Updates per WebSocket. Mit Demo-Modus zum Ausprobieren ohne Pi.
- **Konfiguration per YAML**: Neue Verbraucher brauchen keine Codeänderung

## Schnellstart am Rechner (ohne Pi)

```bash
make install
make dev            # http://localhost:8080, simulierte Hardware
make test
```

Die App: siehe [app/README.md](app/README.md).

```bash
make app-demo       # App mit simuliertem Fahrzeug, http://localhost:8091
make app-build      # App für den Pi; danach liefert `make dev` sie aus
```

## Installation auf dem Pi

Flutter läuft nicht auf dem Pi. Die App wird am Rechner gebaut und von
`install.sh` mitkopiert:

```bash
make app-build                              # am Rechner
# Repo inkl. app/build/web auf den Pi kopieren, dann dort:
sudo deploy/install.sh
sudo nano /etc/camper-control/config.yaml   # Pins und Sensor-IDs eintragen
sudo reboot                                 # aktiviert I2C und 1-Wire
```

**Alles auf einen Blick als PDF** (Gesamtsetup, Handy verbinden, Bauanleitung, Einkaufsliste, Schaltplan, Leitungsliste): **[docs/camper-control-gesamtsetup.pdf](docs/camper-control-gesamtsetup.pdf)**.

**Schritt-für-Schritt-Aufbau** (Einrichten, Tischtest, Einbau, Inbetriebnahme): **[docs/aufbau.md](docs/aufbau.md)**.

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
| 1b | Flutter-App mit Startseite, Menü und Demo-Modus | **fertig** |
| 2 | Victron VE.Direct (MPPT-Solarregler, SmartShunt) | offen |
| 3 | Tankfüllstand (Widerstandsgeber über ADS1115), D+-Eingang | offen |
| 4 | Regeln/Zeitpläne (z. B. Kühlbox nur bei Motorlauf oder Solarüberschuss) | offen |
| 5 | MQTT und Home Assistant, Zugangsschutz, Verlauf/Diagramme | offen |

## Lizenz und Haftung

MIT, siehe [LICENSE](LICENSE). Arbeiten am Fahrzeugbordnetz geschehen auf
eigene Verantwortung; lies vorher [docs/hardware.md](docs/hardware.md).
