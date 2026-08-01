# Architektur — Sitzplan Studio für macOS

Stand: 2026-08-01. Noch kein Produktcode — dieses Dokument legt fest, wohin er
gehört, bevor er entsteht.

## Grenzen

```
Domain  ──kennt──▶  nichts
Data    ──kennt──▶  Domain
Features──kennt──▶  Domain
App     ──kennt──▶  alles
```

- `Domain` kennt weder SwiftUI noch Supabase. Reiner Swift-Code, ohne Import
  eines Frameworks, das eine Oberfläche oder ein Netz voraussetzt.
- `Data` implementiert die Repository-Protokolle, die `Domain` definiert.
- `Features` benutzen Domänenmodelle und Protokolle, nie einen Supabase-Typ.
- Eine View greift nie direkt auf Supabase zu. Kein `SupabaseClient` in einer
  `View`, in keinem Fall.
- DTOs entsprechen Datenbankzeilen, Domänenmodelle fachlichen Objekten. Die
  Übersetzung liegt an genau einer Stelle und ist durch Contract-Tests gedeckt.
- Fehler erreichen die Oberfläche als typisierte Domänenfehler, nicht als
  durchgereichter `URLError`.
- Zustandsänderungen der Oberfläche laufen auf `@MainActor`. Netz- und
  Mapping-Arbeit tut das nicht.

Abhängigkeiten werden über Initialisierer und Protokolle gereicht, gebündelt in
einem `AppEnvironment`. Kein DI-Framework.

## Verzeichnisse

```
SitzplanStudio/
├── App/          SitzplanStudioApp, AppEnvironment, AppState, AppCommands
├── Core/         Configuration, Networking, Persistence, Security, Logging, UI
├── Domain/       Models, Documents, Rules, Repositories (Protokolle), Errors
├── Data/         Supabase, DTOs, Mapping, Repositories (Implementierungen)
├── Features/     Authentication, Klassen, Raeume, Sitzplaene, Papierkorb, Einstellungen
└── Resources/
```

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
| Persistenz | Laden, Speichern, Konflikt | teilweise |
| Konfliktprüfung | Sitzregeln | ja |

Nur zwei dieser zehn Schichten brauchen eine laufende Oberfläche. Der Rest wird
mit Swift Testing geprüft.

Gerendert wird zunächst mit SwiftUI. Eine AppKit-Komponente kommt erst, wenn
eine Grenze nachgewiesen ist — gemessen, nicht vermutet, und dann gekapselt
hinter einem Protokoll.

## Speicherzustände

Sieben Zustände, jeder mit Symbol **und** Text, nie allein über Farbe
unterschieden. Sie entsprechen dem `SaveStatus` des Web-Clients:

| Zustand | Bedeutung |
| --- | --- |
| geladen | Serverstand, keine lokalen Änderungen |
| lokale Änderungen | ungespeichert, Speichern steht an |
| speichert | Schreibvorgang läuft |
| gespeichert | bestätigt |
| Netzwerkfehler | nicht erreicht, Änderungen liegen weiter lokal |
| Serverkonflikt | fremder Stand ist neuer |
| erneut versuchbar | Wiederholung angeboten |

Ein Speicherfehler verwirft nie eine Benutzeränderung. Erkannt wird ein
Konflikt über `updated_at` (siehe `docs/datenvertrag.md`), nicht über
`revision`.

## Native Bedienung

Die App darf nicht wie eine Webseite in einem Fenster wirken. Verwendet werden,
wo fachlich sinnvoll: `NavigationSplitView`, Toolbars, Menübefehle mit
Tastaturkürzeln, Kontextmenüs, `UndoManager`, Drag-and-drop mit gleichwertiger
Tastaturalternative, Sheets, der Druckdialog, PDF-Ausgabe.

Barrierefreiheit ist Teil der Definition of Done, nicht ein Nachtrag: VoiceOver-
Beschriftungen, vollständige Tastaturbedienbarkeit, sichtbarer Fokus,
`prefers-reduced-motion` respektieren. Ziel ist WCAG 2.2 AA wie im Web-Client.

## Designsystem auf macOS

`docs/designsystem.md` im Web-Repo bleibt die Quelle der Wahrheit für Farbrollen,
Typografie, Abstände, Radien, Schatten, Statusdarstellung und die Frage, was
Primär- und was Sekundäraktion ist. Übertragen wird **semantisch**, nicht
pixelgenau: Wo eine Web-Vorgabe gegen eine macOS-Konvention steht, gewinnt die
Konvention — die Bedeutung bleibt.

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

- Nur Project URL und Publishable Key. Kein Service-Role-Key, keine direkte
  PostgreSQL-Verbindung.
- Keine Geheimnisse im Repository. `Config.example.xcconfig` ist eingecheckt,
  `Config.local.xcconfig` steht in `.gitignore`.
- Beim Start wird fehlende Konfiguration geprüft und verständlich gemeldet,
  ohne sensible Einzelheiten.
- Sitzungsspeicherung über die Keychain, sofern die Supabase-Swift-API das
  trägt. Abmelden entfernt lokale Sitzungsdaten zuverlässig.
- Keine personenbezogenen Schülerdaten in Logs, Absturzausgaben, Fixtures,
  Bildschirmfotos, Issues oder Commit-Nachrichten.
- `Logger` mit Privacy-Markierungen statt `print`.
- Keine Analytik und keine Telemetrie ohne eigenes ADR.

## Offene Punkte

- Die genaue Supabase-Swift-API ist noch nicht gegen die aktuelle Fassung
  geprüft. Vor M1 nachzuholen; Signaturen dieses Dokuments sind bewusst
  keine genannt.
- Signierung, Notarisierung und Auslieferung: eigenes ADR, nach M5.
- Offline-Betrieb: eigenes ADR, nach dem MVP.
