# Aufbau Schritt für Schritt

Sechs Phasen, in dieser Reihenfolge: erst am Schreibtisch und auf dem Tisch, dann im Bus. Jede Phase endet mit einer Prüfung. Bauteil-Kennzeichen (F2, K1, R1 …) wie im Schaltplan; Verkabelung und Sicherungen auch in [hardware.md](hardware.md).

## 1 · Einkaufen

*Tag 0*

1. Einkaufsliste abarbeiten (Bauteile siehe [hardware.md](hardware.md)). Beim Relaismodul auf **„(D)“ und 7–36 V** achten.
2. Prüfen, was am Ective SSI 15 schon verbaut ist: eigene Sicherung direkt an der Batterie (sollte 125 A sein) und PV-Trennschalter. Vorhandenes von der Liste streichen.
3. Für den Tischtest zusätzlich: 12-V-Netzteil und ein LED-Streifen.

## 2 · Pi einrichten

*am Mac, ca. 1 h*

1. **Raspberry Pi Imager**: „Raspberry Pi OS Lite (64-bit)“ auf die microSD. In den Einstellungen: Hostname `camper`, dein WLAN, SSH an, Benutzer und Passwort.
2. Karte in den Pi, Pi am normalen USB-C-Netzteil starten, nach 2 Minuten am Mac: `ssh deinname@camper.local`
3. Am Mac die App bauen: `cd ~/Downloads/camper-control && make app-build`
4. Projekt auf den Pi kopieren: `rsync -a --exclude .venv --exclude app/.dart_tool ~/Downloads/camper-control deinname@camper.local:~/`
5. Auf dem Pi installieren: `cd ~/camper-control && sudo deploy/install.sh`.
6. Für den ersten Test ohne Hardware in `/etc/camper-control/config.yaml` die erste Zeile auf `driver: mock` setzen, dann `sudo reboot` (schaltet auch I²C und 1-Wire ein).

**Prüfung:** Am Handy im selben WLAN `http://camper.local:8080` öffnen. Die App zeigt „Verbunden“ mit simulierten Werten und schaltet alles – nur eben nichts Echtes.

## 3 · Tischaufbau

*Netzteil statt Batterie, ca. 2 h*

1. Alles auf ein Brett oder schon auf die Hutschiene im Gehäuse: DC/DC-Wandler U1, Relaismodul A2, USB-RS485-Adapter U4, Pi U2.
2. **12-V-Netzteil** an einen kleinen Verteiler (oder Lüsterklemme): Plus über eine 1-A-Sicherung an `V+` von A2, über eine 3-A-Sicherung an den Eingang von U1. Minus gemeinsam.
3. U1 per USB-C an den Pi. U4 in einen USB-Port des Pi.
4. **RS485:** zwei verdrillte Adern von U4 zu A2 – `A+` an `A+`, `B−` an `B−`.
5. **Taster** S1–S3 jeweils zwischen `DI1`/`DI2`/`DI3` und `DGND` von A2. `COM` bleibt frei.
6. **Testverbraucher:** 12 V über eine Sicherung an `COM` von Relais 1, `NO` an den LED-Streifen (+), dessen Minus an Netzteil-Minus.
7. Auf dem Pi die Konfiguration aus dem Abschnitt „Konfiguration auf dem Pi“ übernehmen (`sudo nano /etc/camper-control/config.yaml`), mit `driver: pi` und vorerst **ohne** `sensors` und `protection`. Dann `sudo systemctl restart camper-control`.

**Prüfung:** `ls /dev/ttyUSB*` zeigt den Adapter. In der App „Licht Bett“ antippen → Relais 1 klickt, LED leuchtet. Taster S1 drücken → LED geht aus, die App zeigt nach 1–2 s „Aus“. Ist die App nicht erreichbar, zeigt `journalctl -u camper-control -n 30` den Grund. Steht dort „relay module did not answer“: Versorgung von A2 prüfen (LED an?), dann `A+` und `B−` tauschen.

## 4 · Messung am Tisch ergänzen

*optional am Tisch, sonst in Phase 5*

1. **Temperaturfühler** B1, B2: rot an Pi Pin 1 (3,3 V), gelb an Pin 7 (GPIO 4), schwarz an Pin 9 (GND). Widerstand R2 4,7 kΩ zwischen Pin 1 und Pin 7. Mit `ls /sys/bus/w1/devices/` die IDs (`28-…`) ablesen und in die Konfiguration eintragen.
2. **INA226** U3: VCC an Pin 1, GND an Pin 6, SDA an Pin 3, SCL an Pin 5. `i2cdetect -y 1` muss `40` zeigen. Prüfen, ob das Modul einen eigenen `VBUS`-Anschluss hat (bei manchen ist er auf der Platine mit IN− verbunden – dann diese Brücke trennen). Der kleine Messwiderstand auf dem Modul (R100) wird nicht gebraucht und sollte ausgelötet werden.

**Prüfung:** In der App erscheinen beide Temperaturen. Der INA226 wird erst im Bus mit dem Shunt sinnvoll.

## 5 · Einbau im Bus

*Batterie abgeklemmt, ca. 1 Tag*

> **Vorher:** Wechselrichter am Gerät aus, PV-Trennschalter aus, Landstrom ab. **Batterie-Minus zuerst abklemmen**, zuletzt wieder anklemmen. Alle Sicherungen aus dem Verteiler ziehen, bis Phase 6.

1. **Gehäuse** mit Hutschiene in Batterienähe montieren (kurze Wege, gut erreichbar, trocken). Darin: Sicherungsverteiler X1/X2, Relaismodul A2, U1, Pi, U4, INA226.
2. **Shunt R1** (200 A) nahe der Batterie montieren. **Batterie-Minus nur an R1** (Batterieseite, W2, 6 mm²). Alles andere kommt an die **Lastseite**.
3. **Wechselrichter umklemmen:** das Minus des Ective SSI 15 vom Batteriepol lösen und mit gleichem Querschnitt an die **Lastseite von R1** (W18). Plus bleibt über seine 125-A-Sicherung F7 an der Batterie. Ladebooster-Minus ebenfalls an die Lastseite bzw. an X2.
4. **Hauptleitung:** Batterie-Plus → F0 (40 A, ≤ 30 cm) → Hauptschalter S0 → X1, alles in 6 mm² rot (W1). R1-Lastseite → X2 in 6 mm² schwarz (W3).
5. **Verteiler belegen:** F1 3 A → U1 · F2 3 A → K1 · F3 5 A → K2 · F4 7,5 A → K3 · F5 1 A → VBUS des INA226 · F6 1 A → V+ von A2. Minus von U1, A2 und allen Verbrauchern an X2.
6. **Verbraucher:** K1 `NO` → Licht Bett, K2 `NO` → USB-Dose Bett, K3 `NO` → Pumpe Wasserhahn. Freilaufdiode V1 direkt an der Pumpe (Ring/Strich = Kathode an +).
7. **Messleitungen:** verdrilltes Paar von R1 zum INA226 – **IN+ an die Batterieseite**, IN− an die Lastseite.
8. **Taster** S1–S3 ins Bedienfeld, Leitungen zu DI1–DI3 und DGND.
9. **PV** nicht anfassen, außer der Trennschalter Q1 fehlt: dann Module → Q1 → Solareingang des SSI.
10. Leitungen alle 20–30 cm fixieren, Scheuerschutz an Kanten, Aderendhülsen an allen Klemmen.

## 6 · Inbetriebnahme

*ca. 1 h*

1. **Sichtprüfung** gegen den Schaltplan, Leitung für Leitung. Mit dem Multimeter auf Durchgang prüfen, dass Plus und Minus nirgends verbunden sind.
2. Hauptschalter S0 aus. **Batterie anklemmen** (Plus zuerst, Minus zuletzt). Spannung an der Batterie messen und notieren.
3. S0 ein, dann Sicherungen **einzeln** setzen: zuerst F6 (Relaismodul) und F1 (Pi), Pi starten lassen; dann F5 (Messung), zuletzt F2–F4.
4. Konfiguration vervollständigen: `sensors` (INA226, Fühler-IDs) und `protection` wie im Abschnitt „Konfiguration auf dem Pi“ eintragen, `sudo systemctl restart camper-control`.
5. **Werte prüfen:** Spannung in der App = Multimeter (±0,05 V). Pumpe einschalten → Strom wird **negativ** („Entnahme“, ca. 4 A). Ist er positiv: IN+ und IN− am INA226 tauschen.
6. Jeden Verbraucher per App *und* per Taster schalten.
7. Wechselrichter wieder einschalten, PV-Trennschalter ein. Bei Sonne muss der Strom in der App positiv werden („lädt“).
8. Unterspannungsschutz verstehen: unter 12,0 V für 30 s werden USB-Dose und Wasserhahn gesperrt, Licht Bett bleibt.

## Handy verbinden (ohne Router)

1. Auf dem Pi einmal: `sudo deploy/hotspot.sh` – fragt nach einem WLAN-Passwort. Eine SSH-Verbindung über WLAN bricht dabei ab; das ist so gewollt, der Pi ist jetzt selbst das WLAN.
2. Handy mit dem WLAN **„Camper“** verbinden. Meldet das Handy „Kein Internetzugang“: **„Verbindung beibehalten“** wählen, sonst wechselt Android auf mobile Daten.
3. Im Browser **http://camper.local:8080** öffnen (falls das nicht lädt: **http://10.42.0.1:8080**).
4. Als App ablegen – iPhone (Safari): Teilen → „Zum Home-Bildschirm“, öffnet dann im Vollbild. Android (Chrome): Menü ⋮ → „Zum Startbildschirm hinzufügen“.
5. Später wieder ins Heim-WLAN (z. B. für Updates): `sudo deploy/hotspot.sh off`, oder per LAN-Kabel verbinden.

**Fertig**, wenn alle Werte plausibel sind und App und Taster alle drei Verbraucher schalten. Danach optional: Fernbedienung RC4 nachmessen ([ective-rc4-messen.md](ective-rc4-messen.md)), um den Wechselrichter in die App zu holen.

## Konfiguration auf dem Pi

*/etc/camper-control/config.yaml*

```yaml
driver: pi
poll_interval_s: 2

modbus:
  port: /dev/ttyUSB0
  channels: 8

switches:
  - { id: bed_light,  name: Licht Bett,    channel: 1, button: true, load_a: 0.5 }
  - { id: bed_usb,    name: USB-Dose Bett, channel: 2, button: true, load_a: 2.0, shed_priority: 2 }
  - { id: water_pump, name: Wasserhahn,    channel: 3, button: true, load_a: 4.0, shed_priority: 1 }

# ab Phase 4/6 ergänzen:
sensors:
  - { type: ina226,  id: house_battery, name: Aufbaubatterie, address: 0x40,
      shunt_ohms: 0.000375, capacity_ah: 230 }
  - { type: ds18b20, id: inside_temp, name: Innenraum,     device_id: 28-xxxxxxxxxxxx }
  - { type: ds18b20, id: fridge_temp, name: Kühlbox innen, device_id: 28-xxxxxxxxxxxx }

protection:            # nur zusammen mit dem INA226
  battery_sensor: house_battery
  cutoff_v: 12.0
  recover_v: 12.8
  cutoff_delay_s: 30
```

Solange der INA226 fehlt: den ganzen `sensors`-Eintrag für `ina226` *und* den `protection`-Block weglassen, sonst startet der Dienst nicht.
