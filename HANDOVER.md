# Handover — PR 2 (lokaler Speicher und Klassen)

Stand: 2026-08-05, Ende der Sitzung.
Branch: `feat/lokaler-speicher-und-klassen`, rebased auf `main`, **nicht
gepusht**, **kein Pull Request offen**.

## Wo wir stehen

**PR 1 ist gemergt.** Die Unterlagen beschreiben den lokalen Einzelplatz,
ADR-0002 gilt, ADR-0001 steht auf `Superseded`. Alle elf Review-Findings von
CodeRabbit und Codex sind eingearbeitet und beantwortet.

**PR 2 ist gebaut, aber nicht abgeschlossen.** Ein Commit (`fb63a8b`), 43
Dateien. Was fehlt, steht unten unter „Was noch offen ist“ — der wichtigste
Punkt ist, dass die Oberflächentests noch nie gelaufen sind.

## Was fertig ist

| Bereich | Zustand |
| --- | --- |
| `Pakete/SitzplanKern` | vollständig, **48 Tests grün** |
| `Pakete/SitzplanSpeicher` | Klassen-Repository vollständig, **18 Tests grün** |
| `SitzplanStudio.xcodeproj` | erzeugt aus `project.yml`, baut |
| App-Shell und Klassenliste | gebaut, `build` und `build-for-testing` grün |
| `.github/workflows/gate.yml` | geschrieben, **nie gelaufen** |

### Verifiziert

```bash
swift test --package-path Pakete/SitzplanKern        # 48 Tests, grün
swift test --package-path Pakete/SitzplanSpeicher    # 18 Tests, grün
xcodebuild -project SitzplanStudio.xcodeproj -scheme SitzplanStudio \
  -destination 'platform=macOS' build-for-testing    # grün
```

### Nicht verifiziert

- **`xcodebuild … test` lief nie.** Die fünf XCUITests in
  `SitzplanStudioUITests/KlassenAblaufTests.swift` kompilieren, aber es ist
  offen, ob sie durchlaufen. Erfahrungsgemäß sind die Element-Abfragen
  (`app.buttons["Klasse anlegen"]`, `rightClick()` auf einen Listeneintrag) der
  Teil, der beim ersten Lauf nachjustiert werden muss.
- **Der CI-Workflow lief nie**, weder der Linux- noch der macOS-Job. Der
  Linux-Job ist besonders zu beobachten: Er ist die einzige Stelle, an der die
  Schichtengrenze zu SwiftData wirklich geprüft wird, und er lief bisher nur
  lokal auf einem Mac — wo `import SwiftData` in `Domain` eben nicht auffällt.
- **Die App wurde nie von Hand bedient.** Der Durchlauf aus dem Plan (Klasse
  anlegen, umbenennen, löschen, im Papierkorb wiederfinden, wiederherstellen,
  beenden, neu starten) steht aus, ebenso der Durchlauf mit Tastatur allein und
  der mit VoiceOver.

## Zwei Befunde aus dem Bauen, die im Plan nicht standen

**1. SwiftData kann die Dokumente nicht als Codable-Attribut ablegen.**
`RaumDokument` und `PlanDokument` liegen als `Data` am Model, nicht als Wert.
Grund: SwiftData legt einen `Codable`-Wert als „composite attribute“ ab und
benutzt dafür einen Coder, der ausschließlich keyed container beherrscht. Unser
tolerantes Lesen muss aber auch `null`, `"text"` und Unsinn verkraften — der
Coder quittiert das mit `fatalError: Composite Coder only supports Keyed
Container`, nicht mit einem auffangbaren Fehler. Als `Data` bleibt die Kodierung
in unserer Hand, mit allen Toleranzen aus dem Datenvertrag. Der Zugriff läuft
über eine `@Transient`-Eigenschaft `dokument`, die Schnittstelle ist also
unverändert. Begründet im Code an `RaumEintrag.dokumentDaten`.

**2. `UUID.uuidString` liefert Großbuchstaben, die Dokumente kleine.**
Die Sitzregelprüfung vergleicht eine `UUID` aus der Domäne mit einer
Zeichenkette aus dem Dokument. `C1C1C1C1-…` gegen `c1c1c1c1-…` findet nichts —
und zwar lautlos: kein Fehler, es passiert nur nichts. Keine Sitzregel wäre je
verletzt gewesen. Aufgefallen ist es ausschließlich an den Fixtures; die
handgeschriebenen Tests waren grün, weil Testcode und Produktivcode dieselbe
Großschreibung erzeugen. Gelöst in `Domain/Kennungsvergleich.swift`.

Beides ist genau die Sorte Sache, die man beim Bauen findet und nicht beim
Planen. Wer die Stellen anfasst, sollte die Kommentare dort lesen, bevor er sie
„aufräumt“.

## Was noch offen ist

Nach Wichtigkeit:

1. **`xcodebuild … test` laufen lassen** und die XCUITests nachziehen. Das ist
   der einzige Punkt, der zwischen „gebaut“ und „belegt“ steht.
2. **Den Handdurchlauf machen** — anlegen, umbenennen, löschen,
   wiederherstellen, neu starten. Einmal mit Tastatur allein, einmal mit
   VoiceOver. Das gehört laut Plan zur Abnahme.
3. **Pushen und Pull Request stellen** gegen `main`. Danach beantwortet
   CodeRabbit sich erfahrungsgemäß nicht von selbst.
4. Prüfen, ob `SitzplanStudio.xcodeproj` wirklich eingecheckt bleiben soll. Sie
   ist es derzeit, zusammen mit `project.yml`. Alternative: nur `project.yml`
   einchecken und die CI `xcodegen generate` laufen lassen — dann braucht der
   macOS-Job XcodeGen als Abhängigkeit.

## Was ausdrücklich nicht dazugehört

Schüler, Merkmale, Notizen, Sitzregeln-Oberfläche, Raumeditor, Sitzplaneditor,
Druck, Einstellungen, die Gemini-Funktion, Signierung, Notarisierung, jeder
Import aus dem Web-Client. Das sind M2 bis M6 und die Issues #4 bis #7, #11,
#13, #15.

Die Sitzregelprüfung und die Soft-Delete-Regeln **sind** trotzdem im Kern
enthalten und getestet — sie sind reine Fachlogik ohne Oberfläche, die
Fixtures decken sie ab, und die Teststrategie verlangt sie im Linux-Job. Die
Oberfläche dazu kommt in M2.

## Issues

Offen und einschlägig: [#12](https://github.com/arn0ld87/sitzplan_macos/issues/12)
(dieser PR), [#8](https://github.com/arn0ld87/sitzplan_macos/issues/8) (CI —
der Workflow liegt bei, das Issue kann mit dem Merge geschlossen werden).

## Wiedereinstieg

```bash
cd /Volumes/T7/Projekte/sitzplan_macos
git checkout feat/lokaler-speicher-und-klassen

swift test --package-path Pakete/SitzplanKern
swift test --package-path Pakete/SitzplanSpeicher
xcodebuild -project SitzplanStudio.xcodeproj -scheme SitzplanStudio \
  -destination 'platform=macOS' clean build test    # ← hier weitermachen
```

Der lokale Build läuft gegen Xcode 27 Beta auf macOS 27 Beta. Verbindlich grün
ist der CI-Lauf; weicht der lokale Build ab, gewinnt die CI.
