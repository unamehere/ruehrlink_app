# Freikoch App

Die App zur **Freikoch Brücke**: Rezepte mit Fotos, geführtes Kochen, Multi-Programme
und Live-Waage für die *Kenwood Cooking Chef XL* – komplett lokal im Heim-WLAN.

**Eine Codebasis für Android und iOS** (Flutter). Getrennte Repos pro Plattform sind nicht nötig;
der Ordner `android/` bzw. `ios/` im Projekt enthält nur die plattformspezifische Hülle.

> Freikoch ist ein unabhängiges Projekt und steht in keiner Verbindung zu Kenwood oder De'Longhi.

## Grundsätze

- **Lokal:** keine Cloud, kein Konto, keine Tracker. Daten liegen auf dem Handy und auf der Brücke.
- **Einfach:** große Schrift, eine Aufgabe pro Bildschirm, alles mit einer Hand bedienbar.
- **Kein Zugriff nach außen:** Die App spricht nur mit der Brücke im Heim-WLAN.
- **Firmware an Bord:** Jedes App-Release enthält die passende Brücken-Firmware (gleiche Versionsnummer)
  und spielt sie per OTA auf – siehe [`freikoch_esp/docs/updates.md`](../freikoch_esp/docs/updates.md).
- **Robust:** die App ist nur Fernbedienung und Anzeige – Programme laufen auf der Brücke weiter,
  auch wenn das Handy schläft.

## Schnittstelle

Die App spricht ausschließlich die lokale API der Brücke:
[`freikoch_esp/docs/api.md`](../freikoch_esp/docs/api.md).

## Entwicklung

Flutter 3.50 (stable). Unter Windows liegt das SDK in `C:\git\flutter`; ohne `PATH`-Eintrag
`C:\git\flutter\bin\flutter.bat` statt `flutter` verwenden.

```sh
flutter pub get        # Pakete holen, erzeugt auch die Texte aus lib/l10n/app_de.arb
flutter analyze        # muss sauber sein
flutter test           # wenige gezielte Tests
flutter run            # auf Gerät/Emulator starten
```

- **Android-Builds** brauchen Android Studio bzw. das Android-SDK (noch nicht eingerichtet).
- **iOS-Builds** brauchen einen Mac mit Xcode oder einen Cloud-Build-Dienst (z. B. Codemagic,
  GitHub Actions mit macOS-Runner).

### Demo-Modus (ohne Hardware)

Ohne gespeicherte Brücke spricht die App mit einer **simulierten Brücke** (`FakeBridgeApi`): Sie meldet ein
Demo-Gerät mit typischen Grenzen, bestätigt gesendete Werte, „drückt“ nach 3 s selbst den Startknopf, zählt die
Restzeit herunter und heizt die Schüssel langsam auf. Auch die Einrichtung läuft gegen einen Fake
(`FakeBridgeProvisioning`) – PIN `0000` und WLAN-Passwort `falsch` zeigen die Fehlermeldungen.

Umschalten auf eine echte Brücke: **Mehr → Verbindung zur Brücke** → im WLAN gefundene Brücke (mDNS
`_freikoch._tcp`) oder IP-Adresse eingeben → Anfrage auf einem schon gekoppelten Handy
bestätigen (Firmware im Entwicklermodus: auch BOOT-Taste). Zurück mit „Demo-Modus verwenden“.
„Einrichtung neu starten“ zeigt den Einrichtungsablauf erneut.

### Aufbau

Siehe [`docs/architektur.md`](docs/architektur.md) (Ordner, Datenfluss, Layout für Tablet/Querformat,
Pakete, Entscheidungen) und [`docs/screens.md`](docs/screens.md) (MVP-Bildschirme).

## Lizenz

Noch offen (Vorschlag: GPLv3).
