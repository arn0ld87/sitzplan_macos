# Teststrategie

Der Zweck ist eng: verhindern, dass die Anwendung Dokumente anders liest oder
schreibt, als der Datenvertrag es festlegt. Alles andere ist nachrangig.

Der Schnitt folgt daraus, nicht umgekehrt: Was ohne Oberfläche und ohne
Datenbank prüfbar ist, liegt in `Pakete/SitzplanKern` und läuft auf Linux. Der
Mac-Runner ist zehnmal so teuer und bleibt dem vorbehalten, was ihn wirklich
braucht.

## Werkzeuge

| Zweck | Werkzeug |
| --- | --- |
| Unit- und Vertragstests | Swift Testing (`@Test`, `#expect`) |
| Speichertests | Swift Testing gegen einen In-Memory-`ModelContainer` |
| Oberflächenabläufe | XCUITest |

## Was im Linux-Job geprüft wird

Ohne Oberfläche, ohne Datenbank, gegen die Fixtures aus `contracts/fixtures/`:

| Prüft | Grundlage |
| --- | --- |
| Rundreise Dokument → Domäne → Dokument | `raum-dokument-v3.json`, `plan-dokument-v1.json` |
| Toleranzen beim Lesen, Altfälle | `plan-dokument-alt-unvollstaendig.json` |
| `seatId` bauen und zerlegen, kanonische Form | `datenvertrag.md` |
| Rasterrundung, auch negativ und halb | `datenvertrag.md`, Vorlage `raster.ts` |
| Reihenfolge bei doppelten Zuordnungen | geordnete Liste, nicht `Dictionary` |
| Sitzregeln und Regelverstöße | `sitzregeln-konflikte.json` |
| Soft-Delete-Filter und Wiederherstellen | `soft-delete-faelle.json` |

Dazu: strenges, kanonisches Schreiben; Dokumentversionen; Möbelmaße aus der
Tabelle statt aus dem Dokument; die ungültigen Sitzplatzkennungen
(`__sitz_007`, `__sitz_1e3`, fehlender Trenner); Abbildung von Speicher- und
Dekodierfehlern auf typisierte Domänenfehler.

## Was im macOS-Job geprüft wird

- Repository-Rundreise gegen einen In-Memory-`ModelContainer`: anlegen, lesen,
  ändern, weich löschen, wiederherstellen.
- Der Klassenfall aus dem Soft-Delete-Vertrag: Eine gelöschte Klasse trägt ihre
  Schüler mit identischem Zeitstempel, ein vorher einzeln gelöschter Schüler
  bleibt gelöscht.
- Dass das Dokument als Wert am Modell die Rundreise durch SwiftData übersteht.

## Fixtures

Plattformneutrale JSON-Dateien unter `contracts/fixtures/`, gelesen als
Ressourcen des Testtargets von `SitzplanKern`.

Sie sind die **Verhaltensspezifikation dieses Repositories**, keine Kopie und
kein Abgleichsgegenstand mehr; der früher geplante CI-Vergleich gegen
`sitzplan_app` entfällt mit
[ADR-0002](decisions/0002-lokaler-einzelplatz.md). Eine Fixture zu ändern heißt,
das Verhalten der Anwendung zu ändern — eigener Pull Request, eigene
Begründung.

Fixtures enthalten ausschließlich erfundene Namen. Echte Schülerdaten gehören
unter keinen Umständen hinein.

## Oberflächentests

XCUITest nur für Abläufe, deren Bruch sofort auffallen muss:

- Das Fenster erscheint und zeigt die Klassenliste
- Eine Klasse lässt sich anlegen und ist nach einem Neustart noch da
- Raumeditor öffnet
- Kernaktionen sind über die Tastatur erreichbar
- Druckansicht lässt sich erzeugen

Diese Tests laufen gegen einspeisbare Fake-Repositories oder einen
In-Memory-Speicher, nie gegen die Datenbank der Benutzerin.

## Gates

```bash
# Kern — ubuntu-latest, bei jedem Push
swift test --package-path Pakete/SitzplanKern

# App — macos-26, nur pull_request gegen main
xcodebuild \
  -project SitzplanStudio.xcodeproj \
  -scheme SitzplanStudio \
  -destination 'platform=macOS' \
  clean build test
```

Lokal läuft der zweite Befehl gegen Xcode 27 Beta auf macOS 27 Beta.
Verbindlich grün ist der Lauf in der CI; weicht der lokale Build ab, gewinnt
die CI.

## Was nicht getestet wird

Layout und Aussehen werden nicht automatisiert geprüft. Dafür gibt es das
Designsystem und einen Blick. Snapshot-Tests der Oberfläche kosten mehr
Pflege, als sie hier einbringen.

Der KI-Aufruf selbst wird nicht gegen Gemini getestet. Geprüft werden
Prompt-Bau, Pseudonymisierung und die Nachprüfung der Antwort — alles reine
Funktionen, alle ohne Netz, alle im Linux-Job.
