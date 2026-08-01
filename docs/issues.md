# Vorbereitete Issues

Dieses Repository hat noch kein GitHub-Gegenstück. Sobald es existiert, werden
die folgenden Texte als Issues angelegt — unverändert, damit die Planung
nachvollziehbar bleibt.

Labelvorschlag, angelehnt an das Web-Repo (`typ: …`, `bereich: …`, `prio: …`):

```
typ: feature · typ: architecture · typ: test · typ: chore · typ: fix
bereich: domain · bereich: data · bereich: ui · bereich: editor
bereich: auth · bereich: ci · bereich: security
prio: hoch · prio: mittel · prio: niedrig
```

---

## #1 — Native macOS-App: Architektur und schrittweise Funktionsparität

`typ: architecture` · `prio: hoch` · Sammel-Issue

**Problem.** Sitzplan Studio hat nur einen Web-Client. Zeicheneditor und
Druckausgabe sind dort am teuersten, weil der Browser Zeigerpräzision,
Undo-Stapel und Druckdialog nachbauen muss.

**Ziel.** Ein nativer macOS-Client, der schrittweise Funktionsparität erreicht
und dabei dasselbe Supabase-Backend, dieselben Konten und dieselben fachlichen
Regeln nutzt.

**Scope.** M0 bis M5 gemäß [roadmap.md](roadmap.md). Dieses Issue bündelt, es
wird nicht selbst bearbeitet.

**Nicht-Ziele.** Zweites Backend. Eigenes Schema. Offline-Betrieb vor dem MVP.
iOS oder iPadOS. Auslieferung über den App Store.

**Akzeptanzkriterien.** Alle Unter-Issues geschlossen; Paritätsmatrix zeigt für
M1–M5 „vorhanden"; Web-Gate und macOS-Gate grün.

**Abhängigkeiten.** Keine.

**Sicherheit.** RLS bleibt die Autorisierungsgrenze. Kein Service-Role-Key im
Client.

---

## #2 — M0: Architektur, Datenverträge und Contract-Fixtures

`typ: architecture` · `typ: docs` · `prio: hoch`

**Problem.** Ohne festgeschriebenen Datenvertrag lesen zwei Clients dasselbe
JSONB-Dokument unterschiedlich, ohne dass es auffällt.

**Ziel.** ADR, Architekturunterlagen, Datenvertrag, Paritätsmatrix,
Teststrategie, Roadmap und gemeinsame Fixtures — vor dem ersten Produktcode.

**Scope.** `docs/`, `contracts/fixtures/`, ADR-0006 im Web-Repo.

**Nicht-Ziele.** Xcode-Projekt. Produktcode. Änderungen am Web-Client.

**Akzeptanzkriterien.** Sechs Dokumente vorhanden; fünf Fixtures valides JSON
mit Erwartungswerten; ADR in beiden Repos; keine Platzhalter.

**Tests.** Web-Gate grün, da `contracts/` im Web-Repo hinzukommt.

**Abhängigkeiten.** Keine.

**Sicherheit.** Fixtures enthalten ausschließlich erfundene Namen.

---

## #3 — M1: Xcode-Projekt, Konfiguration und Anmeldung

`typ: feature` · `bereich: auth` · `prio: hoch`

**Problem.** Es gibt kein Projekt und keinen Weg, sich anzumelden.

**Ziel.** Lauffähige App-Shell mit Anmeldung, Sitzungswiederherstellung und
Abmeldung.

**Scope.** Xcode-Projekt (Deployment Target macOS 14, Swift 6, strict
concurrency), `AppEnvironment`, xcconfig-Konfiguration, Supabase-Client,
Anmeldemaske, Session-Handling, App-Shell mit `NavigationSplitView`, Unit-Tests,
CI-Build.

**Nicht-Ziele.** Klassen, Räume, Pläne. Registrierung neuer Konten, falls der
Web-Client sie bereits abdeckt. Signierung und Notarisierung.

**Akzeptanzkriterien.** Anmeldung mit bestehendem Konto gelingt; Sitzung
übersteht einen Neustart; Abmelden entfernt lokale Sitzungsdaten; fehlende
Konfiguration wird beim Start verständlich gemeldet, ohne sensible Angaben;
`xcodebuild … clean build test` läuft lokal und in der CI durch.

**Tests.** Konfigurationsprüfung; Fehlerabbildung Auth → Domänenfehler;
XCUITest: Anmeldemaske erscheint.

**Abhängigkeiten.** #2. **Vorher zu klären:** aktuelle Supabase-Swift-API —
keine Signatur aus dem Gedächtnis.

**Sicherheit.** Nur Publishable Key. `Config.local.xcconfig` ungetrackt.
Sitzung in der Keychain. Keine Tokens in Logs.

---

## #4 — M2: Klassen, Schüler und Sitzregeln

`typ: feature` · `bereich: data` · `prio: hoch`

**Problem.** Ohne Stammdaten ist kein Sitzplan möglich.

**Ziel.** Klassen, Schüler und Sitzregeln lesen, anlegen, bearbeiten und weich
löschen.

**Scope.** Repository-Protokolle und Supabase-Implementierungen; DTO-Mapping;
Listen- und Detailansichten; Lade-, Leer- und Fehlerzustände; Soft-Delete.

**Nicht-Ziele.** Raumeditor. Papierkorb-Oberfläche (M5). CSV-Import.

**Akzeptanzkriterien.** Nur nicht gelöschte Daten erscheinen; eine gelöschte
Klasse nimmt ihre Schüler mit identischem Zeitstempel mit; ein vorher einzeln
gelöschter Schüler bleibt gelöscht; `farb_index` bleibt im Bereich 0–7.

**Tests.** Mapping in beide Richtungen gegen `soft-delete-faelle.json`;
Regelprüfung gegen `sitzregeln-konflikte.json`; Repository-Tests mit
Fake-Client.

**Abhängigkeiten.** #3.

**Sicherheit.** Keine Schülernamen in Logs. Schreibvorgänge mit fremder
`klasse_id` scheitern an RLS — der Fehler wird sichtbar gemacht, nicht
verschluckt.

---

## #5 — M3: Raumeditor

`typ: feature` · `bereich: editor` · `prio: hoch`

**Problem.** Das Kernstück des Produkts fehlt.

**Ziel.** Räume maßstäblich darstellen und bearbeiten.

**Scope.** Die zehn Schichten aus [architektur.md](architektur.md) —
Dokumentmodell, Geometrie, Hit-Testing, Auswahl, Drag, Snapping, Undo/Redo,
Rendering, Persistenz. Dazu Palette, Inspector, Raster, Zoom.

**Nicht-Ziele.** Schülerzuordnung (M4). 3D-Ansicht. Freie Möbelmaße.

**Akzeptanzkriterien.** Zentimeter bleiben die gespeicherte Einheit; Zoom und
Fenstergröße ändern keine Geometrie; Rasterrundung stimmt mit dem Web-Client
überein, auch bei negativen und halben Werten; Drehung nur in 90-Grad-Schritten;
Auswahl in Petrol, nicht in Rot; alle Aktionen auch über die Tastatur.

**Tests.** Geometrie, Hit-Testing, Snapping und Undo ohne Oberfläche;
Rundreise gegen `raum-dokument-v3.json`; Rasterfälle aus
`plan-dokument-alt-unvollstaendig.json`.

**Abhängigkeiten.** #4.

**Sicherheit.** Keine.

---

## #6 — M4: Sitzplaneditor und Konfliktprüfung

`typ: feature` · `bereich: editor` · `prio: hoch`

**Problem.** Ohne Zuordnung und Regelprüfung ist der Editor kein Sitzplan.

**Ziel.** Schüler auf Plätze setzen, tauschen, Konflikte sichtbar machen.

**Scope.** Eingefrorene Raumkopie; Zuordnung per Klick und per Drag-and-drop mit
gleichwertiger Tastaturbedienung; Tauschen; Konfliktprüfung; Speicherstatus in
sieben Zuständen; Konflikterkennung über `updated_at`.

**Nicht-Ziele.** Automatische Sitzplanvorschläge über einfache Tauschvorschläge
hinaus. Offline-Warteschlange.

**Akzeptanzkriterien.** Sitzplatzkennungen bleiben stabil; die Raumkopie im Plan
ändert sich nie durch eine Änderung der Vorlage; Konflikte werden über Form,
Symbol **und** Text angezeigt, nie allein über Farbe; ein Speicherfehler
verwirft keine Benutzeränderung; ein Serverkonflikt wird erkannt und angeboten,
nicht überschrieben.

**Tests.** Regelprüfung gegen die Fixture einschließlich Grenzfällen;
eingefrorene Kopie; Konfliktfall beim Speichern.

**Abhängigkeiten.** #5 und **#9** — die offenen Punkte zur Konflikterkennung
müssen entschieden sein.

**Sicherheit.** Keine Schülerdaten in Konflikt- oder Fehlermeldungen.

---

## #7 — M5: Drucken, PDF, Papierkorb und Qualitätsgate

`typ: feature` · `prio: mittel`

**Problem.** Das Ergebnis der Arbeit ist ein gedruckter Sitzplan.

**Ziel.** Native Druckausgabe, PDF-Export, Papierkorb mit Wiederherstellung.

**Scope.** Druckdialog, PDF, Papierkorb-Oberfläche, Einstellungen,
VoiceOver-Prüfung, Tastaturprüfung, UI-Rauchtests, Dokumentation.

**Nicht-Ziele.** Serienausdruck mehrerer Pläne. Export nach CSV oder Excel.

**Akzeptanzkriterien.** Das Gedruckte entspricht dem Gespeicherten; der
Papierkorb stellt Klassen samt zugehöriger Schüler wieder her; alle Kernaktionen
sind per Tastatur erreichbar und mit VoiceOver benannt.

**Tests.** XCUITest für Druckansicht und Papierkorb; Wiederherstellung gegen
`soft-delete-faelle.json`.

**Abhängigkeiten.** #6.

**Sicherheit.** Keine Schülerdaten in Bildschirmfotos der Testläufe.

---

## #8 — CI für den macOS-Build

`typ: chore` · `bereich: ci` · `prio: hoch`

**Problem.** Lokal steht nur eine Beta-Toolchain zur Verfügung. Verbindlich
muss ein stabiler Build sein.

**Ziel.** Reproduzierbarer Entwicklungsbuild mit getrennt sichtbaren Schritten.

**Scope.** GitHub-Actions-Workflow auf stabilem macOS-Runner; dokumentierte
Toolchain-Auswahl; reproduzierbare Swift-Paketauflösung; Build und Tests
getrennt; Vergleich der Fixture-Kopie gegen das Web-Repo.

**Nicht-Ziele.** Signierung, Notarisierung, Veröffentlichung.

**Akzeptanzkriterien.** Minimale `permissions`; `persist-credentials: false`;
Actions auf Commit-SHAs gepinnt; keine Geheimnisse in Logs; keine automatische
Veröffentlichung; abweichende Fixture färbt den Lauf rot.

**Abhängigkeiten.** #3.

**Sicherheit.** Keine produktiven Schülerdaten in der CI.

---

## #9 — Konflikterkennung: offene Punkte im Bestand klären

`typ: fix` · `bereich: data` · `prio: hoch` · **betrifft auch das Web-Repo**

**Problem.** Drei Befunde aus der M0-Analyse stehen einer sauberen
Konflikterkennung im Weg:

1. `sitzplaene.revision` wird von `planZuRow` hart auf `1` geschrieben und nie
   erhöht.
2. `rowZuPlan` setzt `updated` notfalls auf die aktuelle Uhrzeit — bei jedem
   Laden ein anderer Wert, als Vergleichsgrundlage unbrauchbar.
3. Der Rasterrückfall ist an zwei Stellen verschieden: `RASTER_STANDARD` ist 25,
   der Rückfall in `ausPlanDokument` ist 10.

**Ziel.** Eine belastbare Grundlage für optimistisches Sperren, in beiden
Clients gleich.

**Scope.** Entscheidung, ob `updated_at` genügt oder `revision` tatsächlich
hochgezählt wird; Vereinheitlichung des Rasterrückfalls; Fixtures nachziehen.

**Nicht-Ziele.** Offline-Warteschlange. Mehrbenutzerbearbeitung.

**Akzeptanzkriterien.** Ein Serverkonflikt ist in beiden Clients erkennbar;
keine undokumentierte Last-Write-Wins-Strategie; falls eine Migration nötig
wird, mit vollständigem RLS-Satz und eigenem ADR.

**Tests.** Konfliktfall in beiden Suiten; Rasterfälle in beiden Suiten.

**Abhängigkeiten.** Muss vor #6 entschieden sein.

**Sicherheit.** Eine Migration ohne vollständige RLS-Policies ist ein
Sicherheitsvorfall.

---

## #10 — Offline und Synchronisation (nach dem MVP)

`typ: architecture` · `prio: niedrig`

**Problem.** Ohne Netz ist die App schreibend blockiert.

**Ziel.** Eine entschiedene, dokumentierte Konfliktstrategie — bevor
Offline-Fähigkeit behauptet wird.

**Scope.** Eigenes ADR: lokaler Zwischenspeicher, Schreib-Warteschlange,
Konfliktauflösung, Darstellung in der Oberfläche.

**Nicht-Ziele.** Umsetzung vor dem MVP.

**Akzeptanzkriterien.** ADR beschlossen; kein stiller Datenverlust in einem der
beschriebenen Fälle.

**Abhängigkeiten.** #7.

---

## #11 — Signierung, Notarisierung und Auslieferung

`typ: chore` · `bereich: security` · `prio: niedrig`

**Problem.** Ein unsignierter Build lässt sich nicht sinnvoll weitergeben.

**Ziel.** Entschiedener Weg zur Auslieferung.

**Scope.** Eigenes ADR: Developer ID gegen App Store, Notarisierung,
Aktualisierungsweg, Umgang mit Zertifikaten in der CI.

**Nicht-Ziele.** Umsetzung vor M5.

**Akzeptanzkriterien.** ADR beschlossen; keine Zertifikate oder Schlüssel im
Repository.

**Abhängigkeiten.** #7.

**Sicherheit.** Zertifikate gehören in einen Geheimnisspeicher, nicht in Git.
