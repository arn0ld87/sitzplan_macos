# Roadmap

Ein Meilenstein endet mit einem Pull Request. Der nächste beginnt erst, wenn der
vorherige überprüfbar, dokumentiert, getestet und grün ist.

Grundlage ist [ADR-0002](decisions/0002-lokaler-einzelplatz.md): ein
eigenständiges Produkt mit lokalem Speicher, ohne Konto und ohne Server.

## M0 — Architektur und Verträge ✅

Kein Produktcode. Ergebnis: ADR-0001 und ADR-0002, Architekturunterlagen,
Datenvertrag, Teststrategie, Fixtures, Issue-Struktur.

## M1 — Xcode-Projekt, lokaler Speicher und Klassen

Xcode-Projekt mit App- und XCUITest-Target, die beiden Pakete `SitzplanKern`
und `SitzplanSpeicher`, `ModelContainer` unter Application Support,
`AppEnvironment`, App-Shell mit `NavigationSplitView`, Klassenliste mit
Anlegen, Umbenennen, weich Löschen und Wiederherstellen, zweistufige CI.

Der erste Meilenstein liefert damit etwas Benutzbares statt eines
Anmeldebildschirms — das ist der sichtbarste Unterschied zur alten Planung.

## M2 — Schüler und Sitzregeln

Schülerlisten je Klasse, Anlegen und Bearbeiten, Initialen und Farbindex,
Sitzregeln, Lade-, Leer- und Fehlerzustände.

Der Klassen-Papierkorb-Fall aus dem Datenvertrag gehört hier geprüft, nicht
später: Eine gelöschte Klasse nimmt ihre Schüler mit identischem Zeitstempel
mit, ein vorher einzeln gelöschter Schüler bleibt gelöscht.

## M3 — Raumeditor

Raum laden und anlegen, maßstäbliche Darstellung, Möbel platzieren und
bearbeiten, Raster, Zoom, Auswahl, Inspector, Undo/Redo, Geometrie-Tests.

Die zehn Schichten aus [`architektur.md`](architektur.md) werden hier angelegt.
Wer sie zusammenzieht, zahlt es in M4.

## M4 — Sitzplaneditor

Eingefrorene Raumkopie, Schülerzuordnung, stabile Sitzplatzkennungen,
Konfliktprüfung, Tauschen, Speicherzustände.

Vorbedingung: Der Rasterrückfall-Widerspruch aus
[`datenvertrag.md`](datenvertrag.md) ist entschieden.

## M5 — Drucken, Papierkorb und Qualitätsgate

Native Druckansicht, PDF-Export, Papierkorb, Wiederherstellung,
VoiceOver-Prüfung, Tastaturprüfung, UI-Rauchtests, vollständige Dokumentation.

## M6 — Gemini mit eigenem Schlüssel

Schlüsselverwaltung in der Keychain, Pseudonymisierung, Prompt-Bau,
Nachprüfung des Vorschlags, Oberfläche für Annahme und Ablehnung.

Vorbedingung: Der Umgang mit Freitext-Notizen im Prompt ist entschieden.

## Danach

- **Sicherung und Export** — eigenes Issue, hohe Priorität. Ohne Server gibt es
  keine zweite Kopie; ein Gerätewechsel ist ohne Export nicht zumutbar. Der
  Punkt steht bewusst nicht am Ende dieser Liste, sondern wird vorgezogen,
  sobald es echte Daten gibt.
- Signierung, Notarisierung, Auslieferung — eigenes ADR
- Sitzplan-Versionen, falls sie ein Merkmal werden
