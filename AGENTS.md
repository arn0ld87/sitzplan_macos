# AGENTS.md

Arbeitsanweisungen für KI-Agenten in diesem Repository. Gilt für alle Agenten.
Antworten auf Deutsch, technische Bezeichner im Original.

Dies ist der **macOS-Client** von Sitzplan Studio. Der Web-Client liegt in
`sitzplan_app` und teilt sich mit diesem Repository ein Supabase-Projekt.

## Hartanker — nicht verhandelbar

1. **Ein Backend.** Dasselbe Supabase-Projekt, dasselbe Schema, dieselben
   Migrationen, dieselben RLS-Policies wie der Web-Client. Kein zweites Backend,
   kein zweites Schema, kein eigenes Auth-System.
2. **Nur Publishable Key.** Kein Service-Role-Key im Client, keine direkte
   PostgreSQL-Verbindung, keine Umgehung von RLS.
3. **`deleted_at IS NULL`** in jeder Leseabfrage auf Nutzdaten.
   Papierkorb-Abfragen sind eigene Repository-Methoden, keine Variante mit
   Schalter.
4. **Ein Sitzplatz heißt `<objektId>__sitz_<n>`.** Vertrag zwischen
   `canvas_document` und Oberfläche. Wer ihn ändert, macht bestehende
   Zuordnungen unlesbar.
5. **Keine personenbezogenen Schülerdaten** in Logs, Absturzausgaben, Fixtures,
   Bildschirmfotos, Issues oder Commit-Nachrichten. `Logger` mit
   Privacy-Markierungen statt `print`.
6. **Kein WebView, kein Electron, kein Catalyst.** AppKit nur punktuell und
   gekapselt, wo SwiftUI eine fachlich nötige Fähigkeit nicht trägt.

## Vor dem Ändern

1. [`docs/datenvertrag.md`](docs/datenvertrag.md) lesen. Dort stehen die
   Toleranzen beim Lesen, die Rasterrundung und die Fallstricke, an denen die
   beiden Clients auseinanderlaufen.
2. Bei Zweifeln über das Verhalten gilt der Code des Web-Clients in
   `sitzplan_app/src/data/` als Tatsachenquelle — nicht die Dokumentation, auch
   nicht diese.
3. Schemafragen über die Migrationen in `sitzplan_app/supabase/migrations/`
   klären, nicht über generierte Typen.

## Schichtengrenzen

- `Domain` kennt weder SwiftUI noch Supabase.
- `Data` implementiert die Repository-Protokolle aus `Domain`.
- `Features` benutzen Domänenmodelle und Protokolle.
- Eine View greift **nie** direkt auf Supabase zu.
- Zustandsänderungen der Oberfläche auf `@MainActor`; Netz- und Mapping-Arbeit
  nicht.

Unerwünscht: große `ContentView.swift`, universelles `AppViewModel`,
Geschäftslogik in Views, globale veränderliche Singletons, untypisierte
Fehlerketten.

## Gestaltung

`sitzplan_app/docs/designsystem.md` ist die Quelle der Wahrheit und wird
**semantisch** übertragen, nicht pixelgenau. Wo eine Web-Vorgabe gegen eine
macOS-Konvention steht, gewinnt die Konvention; die Bedeutung bleibt.

Verboten: Dark Mode, Farbverläufe, Glassmorphism, Violett und Indigo, Rot für
Fokus oder Auswahl, mehr als eine Primäraktion je Ansicht, Zustände allein über
Farbe, Emojis als Icons.

| Rolle | Wert |
| --- | --- |
| Primäraktion | Terrakotta `#A8501F` |
| Auswahl und Fokus | Petrol `#2F5D73` |
| Löschen und Fehler | `#A32E24` — und nur dafür |

SF Symbols statt Lucide, Bedeutung und Statussemantik bleiben erhalten.

Barrierefreiheit gehört zur Definition of Done: VoiceOver-Beschriftungen,
vollständige Tastaturbedienbarkeit, sichtbarer Fokus, Reduced Motion. Ziel
WCAG 2.2 AA wie im Web-Client.

## Tests

Swift Testing für Unit- und Vertragstests, XCUITest nur für kritische Abläufe.
UI-Tests hängen nie an einem produktiven Supabase-Projekt — Fake-Repositories
und feste Fixtures.

Die Fixtures unter `contracts/fixtures/` sind eine **Kopie**. Quelle der
Wahrheit ist `sitzplan_app/contracts/fixtures/`. Wer eine ändert, ändert sie
zuerst dort.

## Verboten

- `git push --force`, Rebase oder Amend auf bereits gepushten Commits.
- `--no-verify` oder `--no-gpg-sign` ohne ausdrückliche Anweisung.
- Geheimnisse im Repository. `Config.local.xcconfig` bleibt ungetrackt.
- Beta-SDKs als Projektgrundlage. Lokal ist Xcode 27 Beta Werkzeug; verbindlich
  ist der CI-Lauf gegen macOS 14.
- Analytik oder Telemetrie ohne eigenes ADR.
- Änderungen an gemeinsamen Verträgen ohne Gegenprobe im Web-Repo.

## Widerspruch ist erwünscht

Anforderungen, die dem Designsystem, dem Datenschutz, der RLS oder dem
Datenvertrag widersprechen: erst benennen, dann Alternative vorschlagen, dann
auf Entscheidung warten.
