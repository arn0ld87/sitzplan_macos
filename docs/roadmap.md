# Roadmap

Ein Meilenstein endet mit einem Pull Request. Der nächste beginnt erst, wenn der
vorherige überprüfbar, dokumentiert, getestet und grün ist.

## M0 — Architektur und Verträge ✅

Kein Produktcode. Ergebnis: ADR, Architekturunterlagen, Datenvertrag,
Paritätsmatrix, Teststrategie, Contract-Fixtures, Issue-Struktur.

## M1 — Native Grundlage und Anmeldung

Xcode-Projekt, `AppEnvironment`, Konfiguration über xcconfig, Supabase-Client,
Anmeldung, Wiederherstellung der Sitzung, Abmeldung, App-Shell, Unit-Tests,
CI-Build.

Zuerst zu klären: die aktuelle Supabase-Swift-API. Keine Signatur aus dem
Gedächtnis.

## M2 — Klassen, Schüler und Sitzregeln

Listen- und Detailansichten, Anlegen und Bearbeiten, Soft-Delete, Sitzregeln,
Lade-, Leer- und Fehlerzustände, Repository- und Mapping-Tests.

Erster Meilenstein mit echten Daten. Der Klassen-Papierkorb-Fall aus dem
Datenvertrag gehört hier geprüft, nicht später.

## M3 — Raumeditor

Raum laden und anlegen, maßstäbliche Darstellung, Möbel platzieren und
bearbeiten, Raster, Zoom, Auswahl, Inspector, Undo/Redo,
Geometrie-Contract-Tests.

Die zehn Schichten aus `docs/architektur.md` werden hier angelegt. Wer sie
zusammenzieht, zahlt es in M4.

## M4 — Sitzplaneditor

Eingefrorene Raumkopie, Schülerzuordnung, stabile Sitzplatzkennungen,
Konfliktprüfung, Tauschen, Vorschläge, Speicherstatus, Konfliktzustände.

Vorbedingung: Die drei offenen Punkte zur Konflikterkennung aus
`docs/datenvertrag.md` sind entschieden.

## M5 — Drucken, Papierkorb und Qualitätsgate

Native Druckansicht, PDF-Export, Papierkorb, Wiederherstellung,
VoiceOver-Prüfung, Tastaturprüfung, UI-Rauchtests, vollständige Dokumentation.

## Danach

- Offline-Betrieb und Synchronisation — eigenes ADR
- Signierung, Notarisierung, Auslieferung — eigenes ADR
- Sitzplan-Versionen, falls der Web-Client sie in Gebrauch nimmt
