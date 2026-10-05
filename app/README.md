# Camper Control – App

Flutter-App für Smartphones. Läuft im Browser (auch als App auf dem
Homescreen) und hat zwei Betriebsarten:

- **Steuereinheit**: verbindet sich mit dem Pi. Vom Pi ausgeliefert
  (`http://camper.local:8080`) braucht sie keine Adresse, App und Steuerung
  teilen sich eine Adresse.
- **Demo**: ein simuliertes Fahrzeug mit denselben Schaltern und demselben
  Unterspannungsschutz. Unter *Einstellungen → Szenario* lassen sich
  „Akku leer“ und „Laden“ durchspielen. So läuft die Version auf GitHub Pages.

```bash
flutter pub get
flutter run -d chrome --dart-define=DEMO=true    # Demo
flutter build web --release                       # für den Pi
flutter analyze && flutter test
```

Ein GitHub-Pages-Build (`https://…`) kann den Pi nicht erreichen: Der
Browser blockiert http-Aufrufe aus einer https-Seite, und der Pi ist nur im
Camper-WLAN. Deshalb startet dieser Build im Demo-Modus.

`test/fixtures/state.json` wird vom Backend-Test `tests/test_contract.py`
erzeugt. Ändert sich, was der Pi sendet, schlägt dort ein Test fehl, und die
App-Tests prüfen das neue Format.
