# Ective SSI 15: Fernbedienung RC4 nachmessen

Ziel: herausfinden, was über das RJ12-Kabel zwischen Wechselrichter und
Fernbedienung RC4 läuft. Davon hängt ab, ob Camper Control den
Wechselrichter **schalten** und seine Werte (Ladestand, Verbrauch, Solar)
**anzeigen** kann. Ective dokumentiert die Belegung nicht.

Die RC4 zeigt Ladestand, Momentanverbrauch, Batteriebetrieb und Fehler an.
Über das Kabel laufen also Daten. Offen ist, ob Ein/Aus ein eigener Kontakt
ist oder ein Befehl im Datenstrom.

> **Sicherheit:** Den Wechselrichter nicht öffnen (230 V, Garantie). Gemessen
> wird nur am RJ12-Kabel, das im Betrieb gesteckt bleibt. **Nichts davon an
> GPIO-Pins des Pi anschließen**, bevor die Spannungen bekannt sind. Auf
> dem Kabel können 12 V liegen, der Pi verträgt 3,3 V.

## Was du brauchst

| Teil | Wofür | ca. € |
|---|---|---|
| RJ12-Doppelkupplung / Verteiler 1 → 2 (6P6C) | RC4 bleibt angeschlossen, der zweite Ausgang geht zum Messen | 5 |
| RJ12-Buchse auf Schraubklemmen (6P6C-Breakout) | Adern einzeln abgreifen | 5 |
| kurzes RJ12-Kabel 6-adrig (6P6C, nicht 6P4C!) | Verteiler → Breakout | 3 |
| Multimeter | Spannungen | vorhanden |
| Logikanalysator 8 Kanäle, 24 MHz (USB) | Datenleitungen aufzeichnen, Software: PulseView (kostenlos, läuft auf dem Mac) | 12 |

## Schritt 1 – Masse finden

1. Aufbau: SSI → Kabel → **Verteiler** → (a) RC4, (b) Breakout.
2. Wechselrichter mit dem Schalter am Gerät **einschalten**, RC4 zeigt an.
3. Multimeter auf Gleichspannung. **Schwarze Messspitze an Batterie-Minus**
   (Lastseite des Shunts), rote nacheinander an Klemme 1 bis 6 des Breakouts.
4. Eintragen:

| Klemme | Spannung SSI an | Spannung SSI aus (RC4) | schwankt? |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |

Zu erwarten: eine Klemme ≈ 0 V (Masse), eine mit fester Spannung (Versorgung
der RC4, z. B. 5 V oder 12 V) und eine oder zwei, deren Wert „zittert“ oder
zwischen 0 und 3–5 V liegt (Daten).

## Schritt 2 – Ist Ein/Aus ein einfacher Kontakt?

1. Multimeter nacheinander an die Klemmen, die **nicht** Masse oder
   Versorgung sind.
2. Ein/Aus-Knopf der RC4 **gedrückt halten** und beobachten.
3. Springt eine Klemme beim Drücken fest auf 0 V (oder auf die
   Versorgungsspannung) und beim Loslassen zurück, ist das ein **eigener
   Schaltkontakt**. → Notieren, welche Klemme und in welche Richtung.

## Schritt 3 – Daten aufzeichnen

Nur nötig, wenn Schritt 2 keinen eindeutigen Kontakt zeigt, oder wenn die
Werte der RC4 in die App sollen.

1. Logikanalysator: **GND an die Masseklemme**, Kanäle an die
   „zitternden“ Klemmen. Vorher prüfen, dass dort höchstens 5 V liegen
   (die günstigen Analysatoren vertragen 5 V).
2. In PulseView mit 1 MHz je etwa 10 Sekunden aufnehmen, dabei:
   - a) nichts tun,
   - b) Ein/Aus an der RC4 drücken,
   - c) einen Verbraucher an der 230-V-Steckdose ein- und ausschalten
     (z. B. Wasserkocher kurz),
   - d) bei Sonne: PV-Trennschalter aus und wieder ein.
3. Jede Aufnahme als `.sr`-Datei speichern und mit einer Notiz, was
   passiert ist, ins Repo oder an Claude geben. Daraus lassen sich
   Baudrate, Rahmen und die Bedeutung der Bytes ablesen.

## Schritt 4 – Lädt der Solarregler bei ausgeschaltetem Wechselrichter?

Wichtig, bevor der Wechselrichter automatisch abgeschaltet wird:

1. Bei Sonne die App öffnen (Energie-Seite, Batteriestrom).
2. Wechselrichter über die RC4 ausschalten.
3. Bleibt der Batteriestrom positiv (lädt), arbeitet der MPPT weiter, und
   Abschalten spart die 0,65 A Leerlauf ohne Nachteil. Fällt er auf den
   Ruhestrom, lädt die PV nur bei eingeschaltetem Gerät, dann darf die
   Software den Wechselrichter **nicht** automatisch abschalten.

## Was danach möglich ist

| Ergebnis | Anbindung an Camper Control |
|---|---|
| Ein/Aus ist ein eigener Kontakt | Freier Kanal K4 des Waveshare parallel zum Knopf, als kurzer Impuls. Ein Taster am Bedienfeld kann dasselbe. Der Zustand (an/aus) wäre dann noch über eine Datenleitung oder den Leerlaufstrom zu erkennen. |
| Alles läuft als Daten | USB-UART-Adapter (galvanisch getrennt, passende Pegel) am Pi: Werte der RC4 mitlesen und, wenn das Protokoll es hergibt, Ein/Aus als Befehl senden. |
| Weder noch | Wechselrichter weiter von Hand schalten. Nicht die 140-A-Zuleitung mit einem Relais trennen: Das würde auch den Solarladeregler abschalten, und beim Wiedereinschalten fließt ein hoher Einschaltstrom in die Kondensatoren. |
