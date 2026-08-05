# Sitzplan Studio für macOS

Native macOS-Anwendung für Lehrkräfte, in Swift und SwiftUI. Alle Daten bleiben
auf dem Rechner: kein Konto, keine Anmeldung, kein Server.

> **Stand: M0.** Es gibt noch keinen Produktcode und kein Xcode-Projekt. Dieses
> Repository enthält derzeit die Architektur- und Vertragsunterlagen, auf denen
> M1 aufsetzt.

## Das Produkt

Lehrkräfte verwalten Klassen und Schüler, zeichnen Räume maßstäblich mit echtem
Mobiliar und verteilen Schüler auf Sitzplätze. Sitzregeln beschreiben Wünsche
und Konflikte; die Anwendung prüft sie und macht Verstöße sichtbar. Ergebnis ist
ein druckbarer Sitzplan.

Optional schlägt Gemini eine Verteilung vor. Dafür hinterlegt die Lehrkraft
ihren eigenen Schlüssel in der Keychain. Ohne Schlüssel funktioniert alles
andere unverändert.

## Zwei unabhängige Produkte

Es gibt Sitzplan Studio zweimal: als Web-Anwendung und als Mac-Anwendung. Beide
tun dasselbe, teilen aber **keine Daten**.

| | Web | macOS |
| --- | --- | --- |
| Repository | `sitzplan_app` | `sitzplan_macos` (dieses) |
| Sprache | TypeScript | Swift |
| Daten | Supabase, Konto je Lehrkraft | lokal, SwiftData, kein Konto |
| KI-Schlüssel | zentral, Edge Function | eigener Schlüssel je Lehrkraft |

Kein gemeinsames Konto, kein gemeinsames Schema, kein Import, keine
Synchronisation. Wer beide benutzt, führt zwei getrennte Datenbestände. Warum
das so entschieden wurde und was es kostet:
[ADR-0002](docs/decisions/0002-lokaler-einzelplatz.md).

Gemeinsam sind allein die **Dokumentformate** — `RaumDokument`, `PlanDokument`,
die Sitzplatzkennung, die Rasterrechnung. Nicht, weil ein Server sie erzwingt,
sondern weil sie erprobt sind. Sie sind hier
[Verhaltensspezifikation](contracts/README.md), keine Kopie.

## Unterlagen

| Frage | Quelle |
| --- | --- |
| Warum lokal, warum kein Backend? | [ADR-0002](docs/decisions/0002-lokaler-einzelplatz.md) |
| Warum überhaupt nativ statt Browser? | [ADR-0001](docs/decisions/0001-nativer-macos-client.md) (abgelöst, in Teilen gültig) |
| Wo gehört welcher Code hin? | [docs/architektur.md](docs/architektur.md) |
| Wie lese und schreibe ich die Daten richtig? | [docs/datenvertrag.md](docs/datenvertrag.md) |
| Was wird wie geprüft? | [docs/teststrategie.md](docs/teststrategie.md) |
| Was kommt wann? | [docs/roadmap.md](docs/roadmap.md) |
| Welche Fälle sind verbindlich? | [contracts/README.md](contracts/README.md) |

**[docs/datenvertrag.md](docs/datenvertrag.md) ist Pflichtlektüre**, bevor
irgendetwas Daten liest oder schreibt. Dort stehen die Toleranzen, die
Sitzplatzkennung und die Fallstricke, an denen eine Portierung nach Swift
schiefgeht.

## Plattform

| Punkt | Festlegung |
| --- | --- |
| Deployment Target | macOS 15 |
| Sprache | Swift 6, Swift-6-Sprachmodus, strict concurrency `complete` |
| Oberfläche | SwiftUI, `@Observable`, `async/await` |
| Speicher | SwiftData, lokal |
| Unit-Tests | Swift Testing |
| UI-Tests | XCUITest |
| Verbindliche Toolchain | CI: `ubuntu-latest` für den Kern, `macos-26` für die App |

macOS 15, weil `#Index` und `#Unique` erst dort verfügbar sind und der Speicher
der Kern dieser Anwendung ist. Wer einen älteren Mac hat, benutzt weiterhin die
Web-Anwendung.

Auf dem Entwicklungsrechner liegt derzeit nur Xcode 27 Beta auf macOS 27 Beta.
Das ist Werkzeug, nicht Grundlage: Verbindlich grün ist der CI-Lauf, nicht der
lokale Build.

## Gate

Sobald Pakete und Xcode-Projekt existieren (M1):

```bash
swift test --package-path Pakete/SitzplanKern

xcodebuild \
  -project SitzplanStudio.xcodeproj \
  -scheme SitzplanStudio \
  -destination 'platform=macOS' \
  clean build test
```

Der erste Befehl braucht keinen Mac und deckt Dokumentformate, Toleranzen,
Sitzplatzkennung, Rasterrundung und Sitzregeln ab. Der zweite prüft Speicher
und Oberfläche.

## Konfiguration

Keine Geheimnisse im Repository, und nichts einzurichten, um loszulegen: Die
Anwendung startet ohne jede Konfiguration und legt ihre Datenbank unter
`~/Library/Application Support/SitzplanStudio/` an.

Wer die KI-Funktion nutzen will, hinterlegt in den Einstellungen einen eigenen
Google-Schlüssel. Er wird in der Keychain abgelegt, nicht in einer Datei.

## Regeln

Verbindlich für alle Beiträge, auch für Agenten: [AGENTS.md](AGENTS.md).
Kurzfassung — kein Backend und kein Netzaufruf außer dem zu Gemini, weich
löschen statt hart, Sitzplatzkennung `<objektId>__sitz_<n>` ist unantastbar,
keine personenbezogenen Schülerdaten in Logs, Fixtures oder Commit-Nachrichten,
in `sitzplan_app` wird nichts geändert.
