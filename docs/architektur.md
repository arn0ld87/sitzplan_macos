# Architektur — Sitzplan Studio für macOS

Stand: 2026-08-05. Noch kein Produktcode — dieses Dokument legt fest, wohin er
gehört, bevor er entsteht. Grundlage ist
[ADR-0002](decisions/0002-lokaler-einzelplatz.md): ein eigenständiges Produkt
mit lokalem Speicher, ohne Konto und ohne Server.

## Projektschnitt

```
sitzplan_macos/
├─ SitzplanStudio.xcodeproj          App-Target + XCUITest
├─ SitzplanStudio/
│  ├─ App/                           SitzplanStudioApp, AppEnvironment, AppCommands
│  ├─ Features/                      Klassen, Schueler, Raeume, Sitzplaene, Papierkorb, Einstellungen
│  └─ Resources/
├─ Pakete/SitzplanKern/              plattformneutral, KEIN Apple-Framework
│  └─ Sources/
│     ├─ Domain/                     Modelle, Dokumente, Regeln, Fehler, Protokolle
│     ├─ Datenvertrag/               Mapping Dokument ↔ Domäne, Toleranzen
│     └─ Core/                       Konfiguration, Logging
└─ Pakete/SitzplanSpeicher/          macOS-only
   └─ Sources/Speicher/              @Model-Typen, ModelContainer, Repository-Impl.
```

Zwei Pakete, nicht eines mit vier Targets: `swift test` baut immer das ganze
Paket, und ein Target, das SwiftData importiert, ist auf Linux nicht baubar.
Der billige Linux-Job für Dokumentformate, Toleranzen, Sitzplatzkennung,
Rasterrundung und Sitzregeln entfiele damit.

Der Ordner unter `SitzplanStudio/` wird als filesystem-synchronized group
eingebunden, damit eine neue Datei keine Änderung an `project.pbxproj`
erzwingt.

## Grenzen

```
Domain        ──kennt──▶  nichts
Datenvertrag  ──kennt──▶  Domain
Core          ──kennt──▶  nichts
Speicher      ──kennt──▶  Domain, Datenvertrag, SwiftData
Features      ──kennt──▶  Domain, Core
App           ──kennt──▶  alles
```

Geprüft wird diese Grenze im Linux-Job, nicht vom Paketschnitt. SwiftData ist
ein System-Framework: `import SwiftData` in `Domain` übersetzt auf einem Mac
anstandslos, gleich in welchem Paket der Quelltext liegt. Erst
`swift test --package-path Pakete/SitzplanKern` auf `ubuntu-latest` bricht ab,
weil es das Framework dort nicht gibt. Wer diesen Job abschaltet oder
nicht-blockierend macht, schafft die Schichtengrenze ab, ohne eine Zeile
Architektur zu ändern.

- `Domain` kennt weder SwiftUI noch SwiftData. Reiner Swift-Code, nur Sprache
  und Foundation — nichts, was eine Oberfläche, eine Datenbank oder ein Netz
  voraussetzt.
- `Speicher` implementiert die Repository-Protokolle, die `Domain` definiert.
- `Features` benutzen Domänenmodelle und Protokolle, nie einen `@Model`-Typ.
- Eine View greift nie direkt auf einen `ModelContext` zu. Kein
  `@Query` in einer Feature-View, in keinem Fall — die Abfrage gehört hinter
  ein Repository, sonst ist sie nicht ohne Datenbank prüfbar.
- Die `@Model`-Typen sind dünn und tragen das fachliche Dokument als
  `Codable`-Wert; die Übersetzung liegt an genau einer Stelle und ist durch
  Vertragstests gedeckt.
- Fehler erreichen die Oberfläche als typisierte Domänenfehler, nicht als
  durchgereichter `SwiftDataError`.
- Zustandsänderungen der Oberfläche laufen auf `@MainActor`. Mapping- und
  Speicherarbeit tut das nicht.

Abhängigkeiten werden über Initialisierer und Protokolle gereicht, gebündelt in
einem `AppEnvironment`. Kein DI-Framework, keine Singletons.

## Datenmodell

Das fachliche Dokument bleibt ein Wert, der Speicher hält nur die Hülle:

```swift
// Pakete/SitzplanSpeicher — kennt SwiftData
@Model final class RaumEintrag {
    var id: UUID
    var name: String
    var geloeschtAm: Date?
    var dokument: RaumDokument      // Wert, kein Objektgraph
}

// Pakete/SitzplanKern/Sources/Domain — kennt nichts
struct RaumDokument: Codable, Sendable, Equatable { … }
```

Damit gelten `docs/datenvertrag.md`, die fünf Fixtures und die
Rundreise-Tests unverändert, und sie laufen ohne SwiftData.

Der `ModelContainer` liegt unter
`~/Library/Application Support/SitzplanStudio/`. Weich gelöscht wird über
`geloeschtAm`; jede Leseabfrage auf Nutzdaten filtert es heraus,
Papierkorb-Abfragen sind eigene Repository-Methoden.

Ausdrücklich unerwünscht: eine große `ContentView.swift`, ein universelles
`AppViewModel`, Geschäftslogik in Views, globale veränderliche Singletons,
untypisierte Fehlerketten.

## Der Editor

Der Raum- und Sitzplaneditor ist der Kern des Produkts und die Stelle, an der
ein ungetrennter Block am teuersten wird. Getrennt werden mindestens:

| Schicht | Aufgabe | Ohne Oberfläche testbar |
| --- | --- | --- |
| Dokumentmodell | `RaumDokument`, `PlanDokument` | ja |
| Geometrie | Zentimeter, Drehung, Ausdehnung | ja |
| Hit-Testing | Punkt → Objekt | ja |
| Auswahl | was ist gewählt | ja |
| Drag | Verschiebung in Zentimetern | ja |
| Raster-Snapping | Rundung auf Rasterweite | ja |
| Undo/Redo | Änderungsstapel | ja |
| Rendering | SwiftUI-Zeichnung | nein |
| Persistenz | Laden, Speichern | teilweise |
| Konfliktprüfung | Sitzregeln | ja |

Nur zwei dieser zehn Schichten brauchen eine laufende Oberfläche. Der Rest wird
mit Swift Testing geprüft, und alles außer der Persistenz gehört nach
`SitzplanKern`.

Gerendert wird zunächst mit SwiftUI. Eine AppKit-Komponente kommt erst, wenn
eine Grenze nachgewiesen ist — gemessen, nicht vermutet, und dann gekapselt
hinter einem Protokoll.

## Speicherzustände

Ohne Server bleiben drei Zustände statt sieben:

| Zustand | Bedeutung |
| --- | --- |
| gespeichert | alles geschrieben |
| lokale Änderungen | ungespeichert, Speichern steht an |
| Speicherfehler | Schreiben scheiterte, Änderung liegt weiter im Speicher |

Netzwerkfehler, Serverkonflikt und „erneut versuchbar“ entfallen mit dem
Backend. Was bleibt, ist der seltene, aber echte Fall: Platte voll, Datei nicht
schreibbar, Datenbank beschädigt.

Die Regel dahinter gilt unverändert: **Ein Speicherfehler verwirft nie eine
Benutzeränderung.** Er wird gemeldet, mit Symbol und Text, nie allein über
Farbe, und die Änderung bleibt bearbeitbar.

## Native Bedienung

Die App darf nicht wie eine Webseite in einem Fenster wirken. Verwendet werden,
wo fachlich sinnvoll: `NavigationSplitView`, Toolbars, Menübefehle mit
Tastaturkürzeln, Kontextmenüs, `UndoManager`, Drag-and-drop mit gleichwertiger
Tastaturalternative, Sheets, der Druckdialog, PDF-Ausgabe.

Barrierefreiheit ist Teil der Definition of Done, nicht ein Nachtrag: VoiceOver-
Beschriftungen, vollständige Tastaturbedienbarkeit, sichtbarer Fokus, Reduced
Motion respektieren. Ziel ist WCAG 2.2 AA.

## Designsystem auf macOS

`docs/designsystem.md` im Web-Repo bleibt die Quelle der Wahrheit für
Farbrollen, Typografie, Abstände, Radien, Schatten, Statusdarstellung und die
Frage, was Primär- und was Sekundäraktion ist. Dass die beiden Anwendungen
keine Daten mehr teilen, ändert daran nichts — sie sollen weiterhin dasselbe
Produkt sein. Übertragen wird **semantisch**, nicht pixelgenau: Wo eine
Web-Vorgabe gegen eine macOS-Konvention steht, gewinnt die Konvention, die
Bedeutung bleibt.

Unverändert verboten: Dark Mode, Farbverläufe, Glassmorphism, Violett und
Indigo, Rot für Fokus oder Auswahl, mehr als eine Primäraktion je Ansicht,
Zustände allein über Farbe, Emojis als Icons.

| Rolle | Wert |
| --- | --- |
| Primäraktion (Terrakotta) | `#A8501F`, Hover `#8E4218` |
| Auswahl und Fokus (Petrol) | `#2F5D73`, weich `#E1ECF1` |
| Löschen und Fehler | `#A32E24` — und nur dafür |

Statt Lucide werden SF Symbols verwendet; Bedeutung und Statussemantik bleiben
erhalten.

Dark Mode ist der eine Punkt, an dem der Ausschluss auf macOS aktiv gesetzt
werden muss, weil das System sonst umschaltet.

## Sicherheit

Die Angriffsfläche ist klein, weil die Anwendung im Regelfall schweigt: keine
Anmeldung, kein Server, kein Konto, kein Netz.

- **Genau ein ausgehender Aufruf** ist erlaubt: der an Gemini, von der
  Lehrkraft ausgelöst. Keine Telemetrie, keine Aktualisierungsprüfung, kein
  Absturzbericht, kein Nachladen von Ressourcen.
- **Der KI-Schlüssel liegt in der Keychain.** Nicht in `UserDefaults`, nicht in
  einer xcconfig, nicht im Repository. Kein Schlüssel wird mitgeliefert.
- **Schülernamen gehen pseudonymisiert in den Prompt** (`s1`, `s2`); die
  Rückabbildung bleibt auf dem Rechner. Was das nicht leistet, steht in
  [ADR-0002](decisions/0002-lokaler-einzelplatz.md) — Merkmale gehen weiterhin
  hinaus, und Freitext-Notizen sind noch ungeklärt.
- **Die Datenbank ist unverschlüsselt**, wie jede Anwendungsdatei im
  Benutzerordner. Sie ist durch die Dateirechte des Kontos geschützt und durch
  FileVault, wenn es aktiviert ist. Wer mehr braucht, braucht ein eigenes ADR.
- Keine personenbezogenen Schülerdaten in Logs, Absturzausgaben, Fixtures,
  Bildschirmfotos, Issues oder Commit-Nachrichten.
- `Logger` mit Privacy-Markierungen statt `print`.
- Keine Analytik und keine Telemetrie ohne eigenes ADR.

## Offene Punkte

- **Sicherung und Export.** Ohne Server gibt es keine zweite Kopie. Geht das
  Gerät verloren und läuft keine Time Machine, sind die Daten weg. Ein Export
  in Dateiform ist deshalb kein Komfortmerkmal — eigenes Issue, früh.
- **Freitext-Notizen im KI-Prompt.** Sie können Namen anderer Kinder
  enthalten, die keine Ersetzung von Bezeichnern mitzieht. Zu entscheiden,
  bevor die KI-Funktion gebaut wird.
- **Signierung, Notarisierung und Auslieferung.** Eigenes ADR, nach M5.
