# Camper Control – Arbeitsnotizen für Claude Code

Raspberry-Pi-Steuerung für einen VW T5 Camper. Python 3.11+ (Pi OS Bookworm
hat 3.11), FastAPI; die Oberfläche ist eine Flutter-App unter `app/`
(Riverpod, Web-Build). Die Doku ist deutsch, Code und Kommentare englisch.

## Aufbau

```
camper/config.py       YAML → Pydantic; prüft doppelte IDs/Pins und Hysterese
camper/hardware/       Output/Sensor-ABCs, mock.py (überall), pi.py (nur Pi)
camper/controller.py   einziger Besitzer von Zustand, Polling, Unterspannungsschutz
camper/api.py          dünn: REST, WebSocket, statische UI
camper/web/            einfache Ersatzseite, wenn keine gebaute App da ist
app/lib/src/api/       CamperApi: HttpCamperApi (Pi) und DemoCamperApi (Simulation)
app/lib/src/ui/        AppShell (Menü), pages/, Kacheln, Batterie-Ring
deploy/                install.sh, systemd-Unit
.github/workflows/     ci.yml (Backend + App), pages.yml (Demo auf GitHub Pages)
```

## App

- **Demo-Modus** (`--dart-define=DEMO=true`) für GitHub Pages: Eine https-Seite
  darf den Pi per http nicht aufrufen, und der Pi ist nur im Camper-WLAN.
  `DemoCamperApi` bildet den Unterspannungsschutz mit 5 s statt 30 s nach;
  ändert sich die Regel im Controller, muss die Demo mitziehen.
- **Live**: vom Pi ausgeliefert, gleiche Adresse für App und API, daher kein
  CORS. Das Backend liefert `app/build/web` bzw. `CAMPER_WEB_DIR` aus, sonst
  die einfache Seite.
- **Vertrag Pi ↔ App**: `tests/test_contract.py` prüft die Form des Snapshots
  gegen `app/test/fixtures/state.json`, das die App-Tests parsen. Neu erzeugen
  mit `UPDATE_FIXTURE=1 pytest tests/test_contract.py`.
- JSON-Parsing fällt bei falschen Typen auf Standardwerte zurück, statt zu werfen.
- Kacheln haben feste Höhen und wachsen mit der Systemschriftgröße
  (`textGrow`); die Widget-Tests prüfen jede Seite auf 320 px und mit 140 %
  Schrift. Endlos-Animationen nur im Live-Modus, sonst hängt `pumpAndSettle`.
- Design: dunkel; kräftige Farbe nur auf der Statuskarte (Nutzerwunsch: die
  Startseite soll nicht zu bunt sein).
- Hinter einem Proxy ohne Zugang zu pub.dev: `flutter analyze --no-pub` / `flutter test --no-pub`.

## Befehle

```bash
make install && make test && make lint
make dev                     # Mock-Hardware auf :8080
make app-test                # flutter analyze + test
make app-demo                # Demo-App auf :8091
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
