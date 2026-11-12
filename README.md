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

Voraussetzungen (noch zu installieren):

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (stable)
- Android Studio (Android SDK + Emulator) – Android-Builds gehen unter Windows
- **iOS-Builds brauchen einen Mac mit Xcode** oder einen Cloud-Build-Dienst (z. B. Codemagic,
  GitHub Actions mit macOS-Runner)

Das Flutter-Projekt wird nach der Installation mit
`flutter create --org de.freikoch --project-name freikoch .` in diesem Ordner erzeugt.

Geplante Pakete: `multicast_dns` (Brücke finden), `web_socket_channel`, `sqflite` (lokale DB),
`flutter_esp_ble_prov` o. ä. (Einrichtung per Bluetooth), `share_plus` (Rezepte teilen),
`image` (Fotos verkleinern).

Siehe [`docs/screens.md`](docs/screens.md) für die MVP-Bildschirme.

## Lizenz

Noch offen (Vorschlag: GPLv3).
