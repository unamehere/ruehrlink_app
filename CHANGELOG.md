# Änderungen – Rührlink App

Neueste Version oben. Für Nutzer geschrieben: was sich beim Benutzen ändert, nicht wie es gebaut ist.
Einträge kommen mit jeder Änderung unter **Unveröffentlicht** und wandern beim Versionssprung in die neue Version
(siehe [CONTRIBUTING.md](CONTRIBUTING.md)). Nummern wie F19 verweisen auf `user_feedback/fehlerliste.md`.
Die Firmware der Box hat ein eigenes Changelog (`ruehrlink_esp/CHANGELOG.md`).

## Unveröffentlicht

## 0.5.1 – 22.11.2026

### Neu
- Rezepte: Maschinenschritte können mehrere Phasen haben (z. B. 1 min Stufe min → 5 min Stufe 1), die mit einem
  Start an der Maschine durchlaufen; im Editor über „Phase anhängen“ (F24).
- Assistent als Rezept und Grundrezepte (Pizza, Brot, Hefezopf, Strudel, Pudding): Unterrühren und Kneten laufen
  als ein Schritt.

### Geändert
- Kochmodus: Der Hauptknopf führt durch alle Wiegezutaten eines Schritts („Nächste Zutat: …“, „Zutat 2 von 4“,
  Liste mit Haken), erst danach zum nächsten Schritt (F23).
- Kochmodus: Wischen zwischen Schritten bleibt frei; offene Zutaten in verlassenen Schritten werden oben dezent
  angezeigt.
- Die App holt den Programmstand nach dem Wiederverbinden und während eines Programms alle 5 s neu.
- Wird ein Start abgelehnt, nennt die App nur, was fehlt, z. B. „Kopf der Maschine schließen.“ (F25).

### Behoben
- Programm-Karte blieb bei „Knopf an der Maschine drücken“ stehen, obwohl die Maschine lief; Uhr und Nachstellen
  fehlten (F26). Der große Hinweis schließt sich, sobald es weitergeht.
- Rezept-Datei aus WhatsApp öffnen führte zu „no routes found“ (F22).

## 0.5.0 – 22.11.2026

### Neu
- Rezepte teilen: Rezeptseite → Teilen erzeugt eine `.rlrezept`-Datei (mit Fotos) für WhatsApp, Mail usw.
- Rezept-Dateien öffnen: „Öffnen mit Rührlink“ oder Rezeptliste → „Rezept-Datei öffnen“, mit Vorschau. Übernommen
  wird immer als neues Rezept, bei gleichem Titel mit „(2)“.
- 10 Grundrezepte (Pizzateig, Brot, Hefezopf, Marmorkuchen, Biskuit, Sahne, Baiser, Strudelteig, Béchamel,
  Vanillepudding) über „Grundrezepte hinzufügen“ in der Rezeptliste.
- Assistenten: Das Ergebnis lässt sich als normales Rezept speichern („Meine Pizza“ …) und danach im Editor ändern.
- Nachstellen: Nach einem Maschinenschritt „Noch nicht fertig?“ mit kurzen Verlängerungen (+30 s/+1 min,
  +1/+5 min, beim Gehen +5/+10 min) mit derselben Stufe und Temperatur.
- Kleine (?)-Knöpfe erklären an vielen Stellen kurz, was passiert: Einrichtung, Maschine, Waage, Programme,
  Kochmodus, Rezept-Editor, Update und Verbindung. Sie öffnen sich nur auf Tipp.
- Bildanleitung „So geht's an der Maschine“ mit sechs Fotos beim Koppeln der Maschine.
- Mehr → „Problem melden“: kurze Beschreibung, optional ein Bild, dazu ein Diagnosebericht, den du vor dem Senden
  komplett siehst. Versand über das Teilen-Menü oder per E-Mail; die App selbst sendet nichts.
- Mehr → „Maschine neu koppeln“ ohne Werksreset; Heim-WLAN, Handys und Rezepte bleiben (F18).
- Mehr → Verbindung zeigt den Speicher des Rührlink (SD-Karte oder intern, Belegung, Hinweis wenn fast voll).

### Geändert
- Die Testprogramme (Zwei Stufen, Ruhephase, Rampe) sind aus dem Kochen-Tab entfernt.
- Kochmodus: Nach einem fertigen Maschinenschritt bleibt die Seite stehen, damit man nachstellen kann; „Weiter“
  geht wie gewohnt weiter.
- Der Hinweis zum Koppeln nennt die Beschriftungen wie auf dem Display (Zahnrad → WiFi → Connect …).
- Die Rezepthilfe nennt beim Wiegen jetzt auch ml und l.

### Behoben
- Ein neu angelegtes Rezept konnte nach dem Abgleich verschwinden und ließ sich nicht wieder öffnen (F20).

## 0.4.0 – 22.11.2026

### Neu
- Rührlink-Update per Datei: „Update-Datei wählen“ spielt eine heruntergeladene Rührlink-Firmware (`.rlfw`)
  auf. Die App prüft sie vorher selbst und zeigt Version und Änderungen.
- Link „Neueste Version auf GitHub“ (öffnet den Browser). Die App selbst verbindet sich weiterhin nie mit
  dem Internet.

### Geändert
- Die App hat eine eigene Versionsnummer, unabhängig von der Firmware des Rührlink.
- Eine ältere Firmware wird nur nach Rückfrage installiert, während eines Programms gar nicht.
- Passen App und Rührlink nicht zusammen, zeigt die App weiter den Status und sagt, was aktualisiert werden
  muss. Fehlt dem Rührlink eine Funktion, kommt einmal ein dezenter Hinweis.
- Rezept-Editor: Die Einheit wählst du aus einer Liste (g, kg, ml, l, EL, TL, Prise, Msp., Pck., Stück, ohne)
  statt sie einzutippen.
- Kochmodus: Flüssigkeiten in ml oder l lassen sich jetzt auch abwiegen, z. B. „500 ml Milch (≈ 515 g)“.
  Vorher wurde bei ml-Zutaten keine Waage angezeigt.
- „Prise Salz“ und ähnliche Angaben ohne Menge zeigen die Einheit jetzt mit an.

## 0.3.9 – 15.11.2026

### Behoben
- Wird der Rührlink ausgesteckt oder ist das WLAN weg, zeigt die App nach wenigen Sekunden „nicht erreichbar“
  (vorher blieb der letzte Stand stehen). Ist er wieder da, verbindet sie sich von selbst.

### Geändert
- Kochen-Tab: Begrüßung kleiner, die zusätzliche Zeile „Waage“ ist weg (Waage über das Symbol oben rechts).

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
