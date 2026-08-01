# Teststrategie

Der Zweck ist eng: verhindern, dass TypeScript und Swift dieselben Daten
unterschiedlich verstehen. Alles andere ist nachrangig.

## Werkzeuge

| Zweck | Werkzeug |
| --- | --- |
| Unit- und Vertragstests | Swift Testing (`@Test`, `#expect`) |
| Oberflächenabläufe | XCUITest |
| Web-Gegenprobe | Vitest im Repo `sitzplan_app` |

## Was geprüft wird

Vertragstests, gegen die gemeinsamen Fixtures:

- DTO → Domäne und Domäne → DTO, in beide Richtungen
- tolerantes Lesen alter und unvollständiger Dokumente
- strenges, kanonisches Schreiben
- Dokumentversionen
- `seatId` und die Zerlegung einer Sitzplatzkennung, samt der ungültigen Fälle
  (`__sitz_007`, `__sitz_1e3`, fehlender Trenner)
- Rasterrundung, einschließlich negativer Werte und halber Schritte
- Möbelmaße aus der Tabelle statt aus dem Dokument
- Konfliktprüfung der Sitzregeln
- Soft-Delete-Filter, einschließlich des Klassenfalls mit identischem
  Zeitstempel
- eingefrorene Raumkopie
- Speicherkonflikte über `updated_at`
- Abbildung von Server- und Netzfehlern auf Domänenfehler

## Gemeinsame Fixtures

Plattformneutrale JSON-Dateien unter `contracts/fixtures/`. Beide Testsuiten
lesen dieselben Dateien.

Quelle der Wahrheit ist das Web-Repo `sitzplan_app`, weil dort Schema,
Migrationen und die Referenzimplementierung liegen. Dieses Repo hält eine Kopie;
die CI vergleicht beide und wird rot, wenn sie abweichen. Wer eine Fixture
ändert, ändert sie zuerst dort.

Fixtures enthalten ausschließlich erfundene Namen — dieselben wie im
Designsystem. Echte Schülerdaten gehören unter keinen Umständen hinein.

## Oberflächentests

XCUITest nur für Abläufe, deren Bruch sofort auffallen muss:

- Anmeldemaske erscheint
- Klassenansicht öffnet
- Klasse lässt sich anlegen — gegen ein Test-Repository
- Raumeditor öffnet
- Kernaktionen sind über die Tastatur erreichbar
- Druckansicht lässt sich erzeugen

Diese Tests hängen **nie** an einem produktiven Supabase-Projekt. Sie laufen
gegen einspeisbare Fake-Repositories, feste Fixtures und eine klar getrennte
Testkonfiguration.

## Gates

macOS, verbindlich in der CI:

```bash
xcodebuild \
  -project SitzplanStudio.xcodeproj \
  -scheme SitzplanStudio \
  -destination 'platform=macOS' \
  clean build test
```

Der genaue Befehl wird mit dem Xcode-Projekt in M1 festgelegt und in
`README.md` dokumentiert. Lokal läuft er gegen Xcode 27 Beta, verbindlich grün
ist der Lauf auf dem stabilen CI-Runner.

Web, unverändert, sobald gemeinsame Verträge berührt sind:

```bash
bun run typecheck
bun run lint
bun run test
bun run build
```

## Was nicht getestet wird

Layout und Aussehen werden nicht automatisiert geprüft. Dafür gibt es das
Designsystem und einen Blick. Snapshot-Tests der Oberfläche kosten mehr
Pflege, als sie hier einbringen.
