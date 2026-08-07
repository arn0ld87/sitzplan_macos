# Handover — PR 3 (Schüler und Sitzregeln, M2)

Stand: 2026-08-07.
Branch: `feat/lokaler-speicher-und-klassen` (noch nicht umbenannt), nicht gepusht,
kein Pull Request offen.

## Wo wir stehen

**PR 2 (M1) war fertig gebaut, aber nie gepusht.** Dieser Stand setzt direkt
darauf auf — M2 ist ebenfalls gebaut, aber nicht abgeschlossen.

**M2 ist gebaut, aber nicht manuell getestet.**

| Bereich | Zustand |
| --- | --- |
| `Pakete/SitzplanKern` | unverändert, **19 Tests grün** |
| `Pakete/SitzplanSpeicher` | SchuelerSpeicher + SitzregelSpeicher neu, **27 Tests grün** |
| `SitzplanStudio.xcodeproj` | `xcodebuild … build`: **BUILD SUCCEEDED** |
| Schülerliste, Bearbeiten-Sheet, Sitzregeln | gebaut, nie gelaufen |

### Verifiziert

```bash
swift test --package-path Pakete/SitzplanKern     # 19 Tests, grün
swift test --package-path Pakete/SitzplanSpeicher  # 27 Tests, grün
xcodebuild -project SitzplanStudio.xcodeproj -scheme SitzplanStudio \
  -destination 'platform=macOS' build              # BUILD SUCCEEDED
```

### Nicht verifiziert

- **`xcodebuild … test` lief nie.** Die UI-Tests aus M1 sind weiterhin offen.
- **Die App wurde nie von Hand bedient.** Weder M1- noch M2-Durchlauf.
- **CI lief nie.**

## Was in M2 neu ist

### Speicher (`Pakete/SitzplanSpeicher/Sources/Speicher/`)

| Datei | Inhalt |
| --- | --- |
| `SchuelerSpeicher.swift` | `SchuelerRepository`-Umsetzung gegen SwiftData |
| `SitzregelSpeicher.swift` | `SitzregelRepository`-Umsetzung gegen SwiftData |

`SchuelerSpeicher.derKlasse` wendet die Soft-Delete-Regel korrekt an:
aktive Klasse → nur nicht gelöschte Schüler; gelöschte Klasse → nur die mit
identischem Zeitstempel (Datenvertrag, Abschnitt Papierkorb).

### App (`SitzplanStudio/`)

| Datei | Inhalt |
| --- | --- |
| `App/AppEnvironment.swift` | um `schueler` und `sitzregeln` erweitert |
| `App/SitzplanStudioApp.swift` | `SchuelerSpeicher` und `SitzregelSpeicher` eingehängt |
| `Gestaltung/Farben.swift` | `schuelerPalette` (8 Farben, identisch zu Web-Client) |
| `Features/Schueler/SchuelerModell.swift` | Observable ViewModel für Schüler + Sitzregeln |
| `Features/Schueler/SchuelerBearbeiten.swift` | Sheet: Anlegen und Bearbeiten |
| `Features/Schueler/SchuelerListe.swift` | Schülerliste + Sitzregeln-Abschnitt |
| `Features/Klassen/KlassenListe.swift` | `Klassendetail` lädt jetzt `SchuelerListe` |

`Klassendetail` bekommt `.id(gewaehlt.id)` — das stellt sicher, dass
`SchuelerModell` bei Klassenwechsel neu erzeugt wird und keine Reste aus der
vorherigen Klasse trägt.

### Tests (`Pakete/SitzplanSpeicher/Tests/SpeicherTests/`)

`SchuelerSpeicherTests.swift` — 9 Tests: Anlegen, Lesen, Alphabetreihenfolge,
Aktualisieren, Weich Löschen, Wiederherstellen, Initialen, Merkmale,
Klassen-Papierkorb-Zeitstempel (alle grün).

## Zwei Punkte, die beim Bauen aufgefallen sind

**1. `BuildProject`-MCP baut falschen Kontext.**
Das MCP-Tool baut `SitzplanStudioApp` aus dem `KlassenAblaufTests`-Projekt —
das ist der UITest-Kontext im xcfilescontainer, nicht das echte App-Target.
Es kompiliert nur eine einzige Datei und meldet dadurch fälschlich Fehler.
Verbindlich ist:
```bash
xcodebuild -project SitzplanStudio.xcodeproj -scheme SitzplanStudio \
  -destination 'platform=macOS' build
```

**2. `SchuelerSpeicher.aktualisieren` setzt `geaendertAm = Date()` im Speicher.**
Der `geaendertAm`-Wert aus dem Domain-Objekt wird ignoriert — der Zeitstempel
ist immer `Date()` des Schreibens. Das ist bewusstes Design: Die Speicherschicht
ist die einzige Stelle, die Schreibzeitpunkte setzt.

## Was noch offen ist

Nach Wichtigkeit:

1. **Handdurchlauf M1**: Klasse anlegen, umbenennen, löschen, Papierkorb,
   wiederherstellen, neu starten.
2. **Handdurchlauf M2**: Schüler anlegen (Vorname, Nachname, Farbe, Merkmale,
   Notiz), bearbeiten, löschen; Sitzregel anlegen und entfernen; Neustart
   überlebt alles.
3. **`xcodebuild … test` laufen lassen** und XCUITests nachziehen.
4. **Branch umbenennen** (z. B. `feat/schueler-und-sitzregeln`) und PR gegen
   `main` stellen.
5. **Pushen** — weder M1 noch M2 sind je gepusht worden.

## Was ausdrücklich nicht dazugehört

Raumeditor, Sitzplaneditor, Drucken, Gemini, Signierung — das ist M3 bis M6.

## Wiedereinstieg

```bash
cd /Volumes/T7/Projekte/sitzplan_macos

swift test --package-path Pakete/SitzplanKern
swift test --package-path Pakete/SitzplanSpeicher
xcodebuild -project SitzplanStudio.xcodeproj -scheme SitzplanStudio \
  -destination 'platform=macOS' build
# → dann App starten und Handdurchlauf M1 + M2 machen
```
