# Änderungen – Rührlink App

Neueste Version oben. Für Nutzer geschrieben: was sich beim Benutzen ändert, nicht wie es gebaut ist.
Einträge kommen mit jeder Änderung unter **Unveröffentlicht** und wandern beim Versionssprung in die neue Version
(siehe [CONTRIBUTING.md](CONTRIBUTING.md)). Nummern wie F19 verweisen auf `user_feedback/fehlerliste.md`.
Die Firmware der Box hat ein eigenes Changelog (`ruehrlink_esp/CHANGELOG.md`).

## Unveröffentlicht

## 0.3.8 – 15.11.2026

### Geändert
- Stufenregler: Statt des langen Worts „Rührintervall“ steht über den Rührstufen ein eigenes Rühr-Symbol
  (Schüssel mit Kochlöffel).
- Assistenten zeigen beim Werkzeug-Hinweis das passende Werkzeug-Symbol.

### Neu
- Waage auch im Kochen-Tab über das Symbol oben rechts (wie im Maschinen-Tab).
- Eigene Piktogramme für alle Rührelemente und den Dämpfeinsatz – im Kochmodus, auf der Rezeptseite, im Editor
  und in den Assistenten.
- Kochmodus: Muss das Werkzeug gewechselt werden, kommt dafür eine eigene Seite („Werkzeug wechseln“) mit großem
  Piktogramm und „Erledigt, weiter“.

## 0.3.7 – 15.11.2026

### Neu
- Temperatur-Vorschläge direkt im Temperatur-Regler: Knopf „Vorschläge“ öffnet ein Menü (Schmelzen 60 °C bis
  Anbraten 180 °C), der gerade eingestellte Wert ist abgehakt. Ersetzt die Chip-Reihe (F19).
- Rezepte zeigen, ob sie auf dem Rührlink gespeichert sind, gerade abgeglichen werden oder nur als Kopie
  vorliegen, weil der Rührlink nicht erreichbar ist (F21).
- Waage auch im Maschinen-Tab (Symbol oben rechts).

### Behoben
- Unter „Mehr“ stand eine veraltete App-Version.
- In der App enthaltene Firmware auf 0.3.3 aktualisiert (vorher 0.3.0).

## 0.3.6 – 15.11.2026

### Neu
- Kleine Hilfe zu Rezepten: „?“ in der Rezeptliste und im Editor.

### Geändert
- Waage ist sofort da: Solange die App offen ist und die Maschine an, hält die App die Waage verbunden. Im
  Hintergrund schaltet der Rührlink sie nach spätestens 30 s ab.

## 0.3.5 – 15.11.2026

### Geändert
- Tipp auf den aktiven Tab bringt zurück zu seiner Startseite, auch aus einem Assistenten heraus.

## 0.3.4 – 15.11.2026

### Neu
- Acht Schnellprogramme im Kochen-Tab: ein Tipp startet, ⓘ zeigt die Details. Programme stehen jetzt vor den
  Assistenten.

### Geändert
- Hinweis „Schüssel einsetzen“ / „Kopf schließen“ nennt nur, was wirklich fehlt.
- Assistenten lassen sich mit ✕ schließen.

## 0.3.3 – 15.11.2026

### Neu
- Rezepte: Zutaten und Rührelement pro Schritt. Die Zutatenliste oben rechnet die App selbst zusammen.
- Kochmodus: sagt nur Bescheid, wenn das Rührelement gewechselt werden muss, und wiegt die Zutaten eines
  Schritts nacheinander ab (Waage stellt sich jedes Mal auf null).

## 0.3.2 – 15.11.2026

### Neu
- Rezepte: Liste, Rezeptseite mit Portionen-Rechner, Editor mit Foto, Kochmodus Schritt für Schritt. Gespeichert
  auf dem Rührlink, für alle gekoppelten Handys gleich.
- Kochmodus wiegt mit der Waage der Maschine ab.
- Assistenten: Pizzateig, Brot-/Hefeteig, Eischnee, Sahne, Schokolade (Werte noch vorläufig).
- Temperatur-Schnellwahl im Maschinen-Tab.
- Sicherheitshinweise in drei Stufen einstellbar: Alle, Nur kritische, Aus.

## 0.3.1 – 15.11.2026

### Neu
- Waage im Kochen-Tab mit Tara. Öffnet sich auf Wunsch von selbst, wenn der Kopf hochgeklappt wird.

## 0.3.0 – 15.11.2026

### Geändert
- Die App heißt jetzt **Rührlink** (vorher Freikoch), die Box in allen Texten „Rührlink“ statt „Brücke“.

## 0.2.0 – 15.11.2026

### Neu
- Firmware-Update der Box direkt aus der App (signiert, bei Problemen automatisch zurück zur alten Version).

## 0.1.12 – 13.11.2026

### Neu
- Maschinenstatus im Kochen-Tab als einklappbare Zeile.
- Warmhalten wird angezeigt und lässt sich stoppen (F4).
- Hinweise „du wirst gebraucht“ einstellbar, nur noch wenn die Maschine wirklich wartet (F14).

### Geändert
- „An Maschine senden“ steht neben „Stopp“, unten fest (F15).
- Temperatur im Status kompakter: Ist groß, Ziel klein (F6).
- Offizielle Stufennamen, im Maschinen-Tab startet die Stufe auf „Aus“.

### Behoben
- Nach dem Entsperren des Handys kommt der Status sofort statt nach etlichen Sekunden (F5).

## 0.1.11 – 13.11.2026

### Behoben
- Restzeit zählt flüssig, der Fortschrittsring gleitet (F9, F13).

## 0.1.10 – 13.11.2026

### Neu
- Vibration, wenn an der Maschine etwas zu tun ist.

## 0.1.9 – 13.11.2026

### Neu
- Programme im Kochen-Tab, neues Design und App-Symbol.

## 0.1.7 – 12.11.2026

### Behoben
- WLAN-Liste bei der Einrichtung wird vollständig geladen (seitenweise).

## 0.1.6 – 12.11.2026

### Neu
- Einrichtung per Bluetooth, QR-Code-Scanner (lokal), Werksreset, Weg „Rührlink ist schon im WLAN“.
- Werte eintippen (Zeit, Temperatur), Stufen-Schieberegler wie am Drehknopf, weitere Handys koppeln per
  Bestätigung, Maschine koppeln.
- App-Version unter „Mehr“.

## 0.1.0 – 12.11.2026

- Erste Version: Maschine steuern (Temperatur, Zeit, Stufe), Einrichtung, Tablet-Layout.
