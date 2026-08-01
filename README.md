# Sitzplan Studio für macOS

Nativer macOS-Client für Sitzplan Studio, in Swift und SwiftUI. Zweiter Client
desselben Produkts — dieselben Supabase-Daten, dieselben Konten, dieselben
fachlichen Regeln wie die Web-App.

> **Stand: M0.** Es gibt noch keinen Produktcode und kein Xcode-Projekt. Dieses
> Repository enthält derzeit die Architektur- und Vertragsunterlagen, auf denen
> M1 aufsetzt.

## Das Produkt

Lehrkräfte verwalten Klassen und Schüler, zeichnen Räume maßstäblich mit echtem
Mobiliar und verteilen Schüler auf Sitzplätze. Sitzregeln beschreiben Wünsche
und Konflikte; die Anwendung prüft sie und macht Verstöße sichtbar. Ergebnis ist
ein druckbarer Sitzplan.

## Verhältnis zum Web-Client

| | |
| --- | --- |
| Web-Client | `sitzplan_app`, TypeScript, TanStack Start |
| Backend | ein gemeinsames Supabase-Projekt, ein Schema, ein Satz RLS-Policies |
| Gemeinsam | Schema, Migrationen, RLS, Dokumentformate, Sitzplatzkennung, Fachregeln |
| Getrennt | Oberfläche, Zustandsverwaltung, Zeichenschicht, Druck, Netzwerkschicht |

Es gibt **kein** zweites Backend und **kein** zweites Schema. Warum getrennte
Repositories: [ADR-0001](docs/decisions/0001-nativer-macos-client.md).

## Unterlagen

| Frage | Quelle |
| --- | --- |
| Warum nativ, warum SwiftUI, warum getrennt? | [ADR-0001](docs/decisions/0001-nativer-macos-client.md) |
| Wo gehört welcher Code hin? | [docs/architektur.md](docs/architektur.md) |
| Wie lese ich die Daten richtig? | [docs/datenvertrag.md](docs/datenvertrag.md) |
| Was kann die App im Vergleich? | [docs/funktionsparitaet.md](docs/funktionsparitaet.md) |
| Was wird wie geprüft? | [docs/teststrategie.md](docs/teststrategie.md) |
| Was kommt wann? | [docs/roadmap.md](docs/roadmap.md) |
| Gemeinsame Vertragsfälle | [contracts/README.md](contracts/README.md) |

**[docs/datenvertrag.md](docs/datenvertrag.md) ist Pflichtlektüre**, bevor
irgendetwas Daten liest oder schreibt. Dort stehen die Toleranzen, die
Sitzplatzkennung und die Fallstricke, an denen die beiden Clients sonst
auseinanderlaufen.

## Plattform

| Punkt | Festlegung |
| --- | --- |
| Deployment Target | macOS 14 |
| Sprache | Swift 6, Swift-6-Sprachmodus, strict concurrency |
| Oberfläche | SwiftUI, `@Observable`, `async/await` |
| Unit-Tests | Swift Testing |
| UI-Tests | XCUITest |
| Verbindliche Toolchain | CI auf stabilem Runner mit Xcode 26 |

Auf dem Entwicklungsrechner liegt derzeit nur Xcode 27 Beta auf macOS 27 Beta.
Das ist Werkzeug, nicht Grundlage: Gebaut wird gegen macOS 14, und verbindlich
grün ist der CI-Lauf, nicht der lokale Build.

## Gate

Sobald das Xcode-Projekt existiert (M1):

```bash
xcodebuild \
  -project SitzplanStudio.xcodeproj \
  -scheme SitzplanStudio \
  -destination 'platform=macOS' \
  clean build test
```

Der genaue Befehl wird mit dem Projekt festgelegt und hier nachgetragen.

## Konfiguration

Keine Geheimnisse im Repository. Die Anwendung braucht Project URL und
Publishable Key des Supabase-Projekts:

```bash
cp Config.example.xcconfig Config.local.xcconfig
# Werte eintragen — Config.local.xcconfig ist in .gitignore
```

Ein Service-Role-Key gehört nie in einen Client.

## Regeln

Verbindlich für alle Beiträge, auch für Agenten: [AGENTS.md](AGENTS.md).
Kurzfassung — RLS an jeder Tabelle, `deleted_at IS NULL` in jeder Leseabfrage
auf Nutzdaten, Sitzplatzkennung `<objektId>__sitz_<n>` ist unantastbar, keine
personenbezogenen Schülerdaten in Logs, Fixtures oder Commit-Nachrichten.
