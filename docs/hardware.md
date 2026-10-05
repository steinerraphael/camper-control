# Hardware und Verkabelung

> **Sicherheit zuerst.** Eine Aufbaubatterie liefert im Kurzschluss mehrere
> hundert Ampere. Jede Leitung wird **an der Quelle** abgesichert, der
> Querschnitt passt zur Sicherung, nicht zum Verbraucher. Arbeiten am
> Fahrzeugbordnetz nur mit abgeklemmter Batterie.

## Überblick

```
 Aufbaubatterie ──[Sicherung]──┬── Shunt (INA226) ── Minus-Sammelpunkt
   (12 V)                      │
                               ├──[2 A]── DC/DC 12→5 V ── Raspberry Pi
                               │
                               └──[je Kreis]── Relais/MOSFET ── Verbraucher
                                                   ▲
                                      GPIO ────────┘ (3,3 V Steuersignal)
```

## Stromversorgung des Pi

- **DC/DC-Wandler 12 → 5,1 V**, Eingangsbereich mindestens 8–32 V. Das
  Bordnetz liegt beim Laden bei 14,4 V und mehr, beim Motorstart gibt es
  kurze Einbrüche und Spitzen. Billige USB-Kfz-Adapter sind dafür nicht gebaut.
- **Pi 5:** 5 V / 5 A. **Pi 4:** 5 V / 3 A. Wird der Pi über die GPIO-5-V-Pins
  versorgt statt über USB-C, fehlt die Schutzschaltung des USB-Eingangs.
- **Ruhestrom bedenken:** Ein Pi 5 im Leerlauf zieht ca. 3 W, also rund
  0,25 A bei 12 V, das sind **etwa 6 Ah pro Tag**. Für lange Standzeiten
  lohnt ein Pi 4 oder ein Hauptschalter für die gesamte Steuerung.
- **Stromausfall und SD-Karte:** Hartes Abschalten kann das Dateisystem
  beschädigen. Gegenmittel: Overlay-Dateisystem (`raspi-config` →
  Performance → Overlay File System), eine SSD statt SD-Karte, oder eine
  kleine USV-Platine mit sauberem Herunterfahren.

## Schalten von Verbrauchern

| Variante | Geeignet für | Hinweis |
|---|---|---|
| Relaisplatine 5 V (optokoppler) | Licht, Pumpe, USB, Lüfter bis ~10 A | Meist **active low**. Jede Relaisspule zieht ~70 mA, solange sie angezogen ist. |
| Kfz-Relais, angesteuert über Platinenrelais | Kühlbox, Wechselrichter, > 10 A | Relaiskontakte der Platine schalten nur die Spule. |
| Logic-Level-MOSFET (Low-Side) | Dauerverbraucher, LED dimmen (PWM) | Kein Spulenstrom. Freilaufdiode bei induktiven Lasten (Pumpe, Lüfter). |

- **Niemals 12 V an einen GPIO.** Eingänge (z. B. D+, Türkontakt) über
  Optokoppler oder Spannungsteiler auf 3,3 V bringen.
- Alle Massen haben einen gemeinsamen Bezugspunkt (Minus-Sammelpunkt nach dem Shunt).
- Nach einem Neustart sind **alle Kanäle aus**. Das ist Absicht: Eine Pumpe,
  die nach einem Spannungseinbruch unbemerkt wieder anläuft, ist schlimmer als
  Licht, das man neu einschalten muss.

### Alternative: Relaismodul über RS485 (empfohlen)

Statt der einfachen Relaisplatine an den GPIO-Pins: **Waveshare Modbus RTU
Relay (D)**, die Variante mit **„(D)“ und 7–36 V**. Die gleichnamige
Variante ohne „(D)“ braucht 5 V und hat keine Eingänge.

- Versorgung direkt aus 12 V (eigene Sicherung, 1 A), Hutschiene,
  Schraubklemmen, Überspannungsschutz. Die eingebauten Freilaufdioden
  schützen nur die eigenen Relaisspulen; Pumpe, Kühlbox und Lüfter brauchen
  trotzdem je eine Freilaufdiode (z. B. 1N5408) direkt am Gerät.
- Pi ↔ Modul: **USB-RS485-Adapter (galvanisch getrennt)** und zwei Adern
  A/B, am besten verdrillt. Keine GPIO-Leitungen, kein 3,3-V-Problem.
- Werkseinstellung: Adresse 1, 9600 Baud, 8N1. Relais 1–8 = `channel: 1`–`8`.
- Lastseite wie gehabt: 12 V über Sicherung an COM, Verbraucher an NO.
- **Taster:** Mit `button: true` an einem Schalter stellt die Software den
  Eingang gleicher Nummer (DI1 für Relais 1 …) auf Toggle-Modus. Ein
  Druck schaltet um, direkt im Modul, also auch wenn der Pi aus ist. Die
  App liest die Relais alle paar Sekunden zurück und zeigt den echten Zustand.
  Taster potenzialfrei zwischen DIx und DGND, COM frei lassen.
- Hat der Unterspannungsschutz einen Verbraucher gesperrt, schaltet ihn die
  Software nach einem Tastendruck beim nächsten Abgleich wieder aus.
- **D+** nicht direkt an einen Eingang: Es ist ein 12-V-Signal und verträgt
  sich nicht mit den potenzialfreien Tastern an derselben COM-Klemme. Ein
  kleines Kfz-Relais (Spule an D+) macht daraus einen potenzialfreien Kontakt
  für DI7. Die Software liest D+ noch nicht.
- Startet der Pi neu, schaltet er zunächst alle Relais aus.

Prüfen nach dem Anschließen: `ls /dev/ttyUSB*` zeigt den Adapter.
Antwortet das Modul nicht, meldet die App „Das Relaismodul antwortet nicht“,
und der Schalter bleibt im alten Zustand.

## Sensoren

### Batterie: INA226 (I2C)

- Misst Spannung und, über einen **externen Shunt im Minuspfad**, den Strom.
  Die kleinen Module haben einen 0,1-Ω-Shunt für nur ca. 0,8 A, der muss
  durch einen Kfz-Shunt ersetzt werden. Mit dem Wechselrichter 200 A / 75 mV
  (0,375 mΩ), ohne ihn reichen 100 A / 75 mV (0,75 mΩ).
- Bus-Spannungseingang (VBUS) bis 36 V, passt also zum 12-V-Bordnetz.
- Adresse 0x40 (A0/A1 auf GND). Prüfen mit `i2cdetect -y 1`.
- Wer schon einen Victron SmartShunt oder BMV hat: VE.Direct-Anbindung ist
  geplant (siehe README) und spart den INA226.

### Temperatur: DS18B20 (1-Wire)

- Datenleitung an GPIO 4 mit 4,7 kΩ Pull-up gegen 3,3 V. Mehrere Fühler
  hängen parallel an derselben Leitung.
- Die Fühler-IDs zeigt `ls /sys/bus/w1/devices/` (beginnen mit `28-`).
- Wasserdichte Ausführung für Kühlbox und Außentemperatur.

## Netzwerk

Zwei sinnvolle Varianten:

1. **Vorhandener Camper-Router (LTE)**: Der Pi verbindet sich per WLAN oder LAN,
   das Handy ist im selben Netz. Erreichbar unter `http://<hostname>.local:8080`.
2. **Pi als eigener Access Point**: ohne Router. Mit NetworkManager (ab
   Bookworm): `nmcli dev wifi hotspot ifname wlan0 ssid Camper password <…>`.

Die Weboberfläche hat **noch keine Anmeldung**. Wer im WLAN ist, kann schalten.
Das WLAN-Passwort ist daher die Zugangskontrolle; kein Port-Forwarding ins Internet.

## VW-T5-spezifisch

- **Zweitbatterie und Trennrelais/Ladebooster**: Die Steuerung hängt an der
  Aufbaubatterie, nie an der Starterbatterie. Einbauort von Batterie und
  Trennrelais je nach Baujahr und Ausbau prüfen.
- **D+ / Zündungsplus** als Eingang (über Optokoppler) verrät, ob der Motor
  läuft. Das ist nützlich für Regeln wie „Kühlbox bei laufendem Motor immer an“.
- **CAN-Bus**: Der T5 hat Komfort- und Antriebs-CAN. **Nur lesend** und nur mit
  galvanisch getrenntem Interface anschließen. Schreiben auf den Fahrzeugbus
  kann Steuergeräte stören. Nicht Teil der ersten Ausbaustufe.

## Belegung (Beispielkonfiguration)

| Anschluss | Funktion |
|---|---|
| Waveshare K1 / DI1 | Licht Bett / Taster S1 |
| Waveshare K2 / DI2 | USB-Dose Bett / Taster S2 |
| Waveshare K3 / DI3 | Pumpe Wasserhahn / Taster S3 |
| Waveshare K4–K8 | frei (die App zeigt sie als frei an) |
| Waveshare DI7 | D+ über Kfz-Relais (vorbereitet) |
| Pi GPIO 2 / 3 (Pin 3 / 5) | I2C SDA/SCL (INA226) |
| Pi GPIO 4 (Pin 7) | 1-Wire (DS18B20) |
| Pi USB | USB-RS485-Adapter |

Ohne Relaismodul (Relaisplatine an GPIO) siehe Kommentar in
`config/config.example.yaml`.

## Wechselrichter (Ective SSI 15)

Verbaut ist ein Ective SSI 15 (1500 W, 12 V): Wechselrichter, Ladegerät und
MPPT-Solarladeregler in einem Gerät (laut Anleitung: Solareingang 28–70 V,
max. 550 W, 20 A Ladestrom; Leerlauf ca. 0,65 A).

- **Eigene Zuleitung:** Plus über eine 125-A-Sicherung direkt an der
  Batterie, Querschnitt nach der Tabelle in der Ective-Anleitung (zwei
  Kabelsätze je Pol). Nie über den Sicherungsverteiler.
- **Minus direkt an die Lastseite des Shunts**, mit gleichem Querschnitt.
  Dann misst der Shunt den Wechselrichter mit, ohne dass bis zu 140 A über
  die Minusschiene laufen. Deshalb **200-A-Shunt** statt 100 A.
- **Keine Datenschnittstelle:** Der SSI 15 hat nur eine RJ12-Buchse für die
  Fernbedienung RC4, kein App-, Bluetooth- oder RS232-Protokoll. Was er tut,
  sieht die App nur am Batteriestrom. Für getrennte Werte (Solar/Landstrom
  rein, 230-V-Verbrauch raus) wäre ein zweiter Shunt mit INA226 in seiner
  Minusleitung nötig.
- **Leerlauf:** 0,65 A sind rund 15 Ah am Tag. Bei Nichtgebrauch ausschalten.
- **Fernbedienung RC4:** Wie man ihre Leitung nachmisst, um den
  Wechselrichter in die App zu holen: [ective-rc4-messen.md](ective-rc4-messen.md).
- **Batterie:** Ective empfiehlt ab 250 Ah (Blei); die 230-Ah-AGM liegt knapp
  darunter.

## Solar (PV Dach)

Die PV-Anlage wird **nicht** über ein Relais des Verteilers geschaltet:

- Die Leerlaufspannung der Module (ein 12-V-Modul ≈ 22 V, zwei in Reihe
  ≈ 45 V) liegt an oder über den 30 V DC, für die die Relaiskontakte
  ausgelegt sind. Gleichstrom aus den Modulen zieht beim Öffnen einen
  Lichtbogen, den ein kleines Relais nicht sicher löscht.
- Wird der Akku vom Laderegler getrennt, während die Module liefern, kann
  der Regler beschädigt werden.

Richtig ist: Module → **DC-tauglicher PV-Trennschalter** → Solareingang des
**Ective SSI 15** (28–70 V, also zwei 12-V-Module in Reihe oder ein Modul mit
entsprechender Spannung). Der SSI lädt die Batterie selbst; die App sieht den
Ladestrom über den Shunt.
