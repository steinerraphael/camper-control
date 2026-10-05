# Camper Control – Arbeitsnotizen für Claude Code

Raspberry-Pi-Steuerung für einen VW T5 Camper. Python 3.11+ (Pi OS Bookworm
hat 3.11), FastAPI, kein Build-Schritt für die Weboberfläche. Die Doku ist
deutsch, Code und Kommentare englisch.

## Aufbau

```
camper/config.py       YAML → Pydantic; prüft doppelte IDs/Pins und Hysterese
camper/hardware/       Output/Sensor-ABCs, mock.py (überall), pi.py (nur Pi)
camper/controller.py   einziger Besitzer von Zustand, Polling, Unterspannungsschutz
camper/api.py          dünn: REST, WebSocket, statische UI
camper/web/            index.html (Vanilla JS), Manifest
deploy/                install.sh, systemd-Unit
```

## Befehle

```bash
make install && make test && make lint
make dev                     # Mock-Hardware auf :8080
```

## Konventionen

- **Nur `controller.py` fasst Hardware an.** API und UI rufen den Controller.
- **Pi-Pakete (gpiozero, smbus2) werden lazy importiert**, damit Tests und
  Entwicklung auf jedem Rechner laufen. Neue Treiber: ABC in `base.py`, Mock in
  `mock.py`, echte Variante in `pi.py`, Auswahl nur in `hardware/__init__.py`.
- **Sicherer Zustand ist „aus“.** Ausgänge starten aus. Ein fehlender oder
  fehlerhafter Messwert ist kein Beweis für eine leere Batterie, der Schutz
  hält dann seinen Zustand. Nach Erholung wird freigegeben, nie automatisch
  eingeschaltet.
- Verkabelung gehört in die YAML, nicht in den Code.
- Tests prüfen Verhalten, das man im Camper bemerken würde (Licht geht aus,
  Pumpe bleibt gesperrt), mit `FakeClock` statt echter Wartezeit.

## Stand

Stufe 1 fertig und am Rechner getestet (Mock). **Auf echter Hardware noch
nicht gelaufen**: `pi.py` (INA226-Register, 1-Wire-Parser, gpiozero) ist nach
Datenblatt geschrieben, nicht gemessen. Beim ersten Pi-Lauf zuerst dort
nachsehen. Ausbaustufen siehe README.
