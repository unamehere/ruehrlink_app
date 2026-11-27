# Arbeitsweise mit Git

Gilt für alle Repos des Projekts (`ruehrlink_esp`, `ruehrlink_app`, `ruehrlink_hardware`). Stand 13.11.2026.

## Branches

| Branch | Zweck | entsteht aus | geht zurück in |
|---|---|---|---|
| `main` (Hardware: `master`) | getesteter Stand – das, was auf Beta-Geräten läuft | – | – |
| `develop` | Integration: alles Fertige, noch nicht an der Maschine getestet | `main` | `main` (Release) |
| `feature/<kurz>` | neue Funktion, z. B. `feature/sequencer` | `develop` | `develop` |
| `fix/<kurz>` | Fehler aus der Entwicklung, z. B. `fix/schuessel-status` | `develop` | `develop` |
| `hotfix/<kurz>` | dringender Fehler im ausgelieferten Stand | `main` | `main` **und** `develop` |

- Zusammenführen immer mit `git merge --no-ff`, damit der Branch in der Historie sichtbar bleibt.
- Kleine reine Doku-Änderungen dürfen direkt auf `develop`.

## Commit-Nachrichten

[Conventional Commits](https://www.conventionalcommits.org/de/), Text auf Deutsch:

```
<typ>(<bereich>): <was, im Imperativ oder als Ergebnis>

<warum, Befund, Bezug auf die Fehlerliste (F2) oder den Testplan>
```

Typen: `feat` (Funktion) · `fix` (Fehler) · `docs` · `style` (Formatierung) · `refactor` · `test` ·
`build` (Bauen, Fertigungsdaten) · `chore` (Sonstiges).

## Changelog

Jede Änderung, die man beim Benutzen merkt, bekommt im selben Commit einen Eintrag in `CHANGELOG.md`
unter **Unveröffentlicht** (Neu / Geändert / Behoben, in Nutzersprache). Reine Umbauten, Tests und Doku nicht.

## Release

1. Testplan an der echten Maschine durchlaufen (`ruehrlink_esp/docs/testplan.md`), Ergebnis eintragen.
2. `develop` → `main` mergen, Tag `vX.Y.Z` (App) bzw. `fw-vX.Y.Z` (Firmware) setzen. App und Firmware haben **dieselbe Mittelzahl** (App 0.6.x ↔ Firmware 0.6.y): Der Patch zählt je Repo unabhängig, die Mittelzahl geht gemeinsam hoch, wenn beide betroffen sind (Funktion/API). Die App bringt immer eine Firmware mit gleicher Mittelzahl mit (`FIRMWARE_VERSION`), das prüfen `ci.yml` und `release.yml`. Technisch abgesichert bleibt es über `api`, `features` und `minApp` (siehe ruehrlink_esp/docs/updates.md).
3. Im `CHANGELOG.md` die Einträge unter „Unveröffentlicht“ in die neue Version verschieben (Datum dazu).
4. Fehler aus Tests kommen in die Fehlerliste (`Ruehrlink/user_feedback/fehlerliste.md`, lokal, nicht im Repo).

### Entwicklungsbuilds

Jeder Push auf `test/beta` baut automatisch eine signierte APK `<version>-dev.<lauf>` (z. B. `0.6.2-dev.57`):
GitHub → Actions → Lauf „Release“ → Artifacts. Nichts wird veröffentlicht, der Download hält 14 Tage. Die
Build-Nummer aller Builds sind die Minuten seit 1.1.2026, so lässt sich jede neuere APK über eine ältere
installieren – egal ob Entwicklungsbuild, Testversion oder Release. Firmware-Entwicklungsbuilds werden **nie**
auf GitHub signiert (Schlüssel nur lokal): per USB flashen oder lokal packen mit
`~/.platformio/penv/Scripts/python.exe tools/firmware_sign.py pack --min-app 0.4.0 --channel beta --out ~/Downloads`.
RC oder Release gibt es erst, wenn Niklas es sagt.

### Testversionen (Release Candidates)

Bevor eine Version fertig ist, gibt es Testversionen mit Zusatz: `0.6.1-rc.1`, `0.6.1-rc.2` … Gebaut und
veröffentlicht werden sie wie jede Version über die Pipeline (Tag `v0.6.1-rc.1` bzw. `fw-v0.6.1-rc.1`), aber immer
als Pre-Release mit „Testversion“ im Titel. Gefundene Fehler kommen in die nächste `-rc`. Ist eine Testversion an
der Maschine bestanden, wird **derselbe Stand** ohne Zusatz als `0.6.1` getaggt (Changelog: die `-rc`-Abschnitte zu
`## 0.6.1 – Datum` zusammenfassen). Die App hält `0.6.1-rc.2` für älter als `0.6.1`; Android-Build-Nummer
(`+33`) zählt immer weiter.

Keine Zugangsdaten (WLAN, Tokens, Passwörter) in Dateien im Repo – auch nicht in ignorierten.
