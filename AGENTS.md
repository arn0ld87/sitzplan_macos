# AGENTS.md

Arbeitsanweisungen für KI-Agenten in diesem Repository. Gilt für alle Agenten.
Antworten auf Deutsch, technische Bezeichner im Original.

Dies ist **Sitzplan Studio für macOS** — ein eigenständiges Produkt, das alle
Daten lokal auf dem Rechner der Lehrkraft speichert. Kein Konto, keine
Anmeldung, kein Server. Der Web-Client in `sitzplan_app` ist ein davon
unabhängiges Produkt; er teilt mit diesem Repository keine Daten. Warum:
[ADR-0002](docs/decisions/0002-lokaler-einzelplatz.md).

## Hartanker — nicht verhandelbar

1. **Kein Backend.** SwiftData, lokal. Kein Supabase-SDK, kein Konto, keine
   Anmeldung, keine RLS, keine Servermigrationen, kein Import aus dem
   Web-Client und keine Synchronisation. Wer eines davon einführt, braucht ein
   eigenes ADR.

   Nicht gemeint sind **lokale Schema-Migrationen**: Eine Änderung an einem
   `@Model`-Typ braucht ein `VersionedSchema` und einen `SchemaMigrationPlan`.
   Ohne das zerreißt die Datenbank der Lehrkraft, und es gibt keinen Server, von
   dem sie sich neu laden ließe.
2. **Kein Netzaufruf außer dem KI-Aufruf.** Genau ein ausgehender Aufruf ist
   erlaubt: der an Gemini, ausdrücklich von der Lehrkraft ausgelöst. Kein
   Telemetrie-Ping, keine Aktualisierungsprüfung, kein Schriftart- oder
   Symbolnachladen, kein Absturzbericht. Ohne hinterlegten Schlüssel ist die
   Anwendung vollständig benutzbar und schweigt im Netz.
3. **Der KI-Schlüssel gehört der Lehrkraft.** Er liegt in der Keychain — nie in
   einer Einstellungsdatei, nie in einem xcconfig, nie im Repository, nie in
   einem Log. Kein Schlüssel wird mitgeliefert. Schülernamen gehen
   pseudonymisiert als `s1`, `s2` in den Prompt; die Rückabbildung bleibt auf
   dem Rechner.
4. **Weich löschen, nie hart.** Löschen setzt ein Datumsfeld, es entfernt keinen
   Datensatz. Im Swift-Modell heißt es **`geloeschtAm`**; in den Fixtures steht
   dafür `deleted_at` beziehungsweise `deletedAt` (Zuordnungstabelle in
   [`contracts/README.md`](contracts/README.md)).
   Jede Leseabfrage auf Nutzdaten filtert es heraus.
   Papierkorb-Abfragen sind eigene Repository-Methoden, keine Variante mit
   Schalter.
5. **Ein Sitzplatz heißt `<objektId>__sitz_<n>`.** Vertrag zwischen
   `RaumDokument` und Oberfläche. Wer ihn ändert, macht bestehende
   Zuordnungen unlesbar.
6. **Keine personenbezogenen Schülerdaten** in Logs, Absturzausgaben, Fixtures,
   Bildschirmfotos, Issues oder Commit-Nachrichten. `Logger` mit
   Privacy-Markierungen statt `print`.
7. **Kein WebView, kein Electron, kein Catalyst.** AppKit nur punktuell und
   gekapselt, wo SwiftUI eine fachlich nötige Fähigkeit nicht trägt.

## Vor dem Ändern

1. [`docs/datenvertrag.md`](docs/datenvertrag.md) lesen. Dort stehen die
   Toleranzen beim Lesen, die Rasterrundung und die Fallstricke, an denen eine
   Portierung nach Swift schiefgeht.
2. Verbindlich ist dieses Repository: `docs/datenvertrag.md` und die Fixtures
   unter `contracts/fixtures/`. Sie sind die Verhaltensspezifikation, keine
   Kopie mehr.
3. Der Web-Client in `sitzplan_app/src/data/` bleibt eine **Lesequelle** für
   Fragen, die Vertrag und Fixtures offenlassen — dort ist dasselbe
   Dokumentformat seit Längerem in Gebrauch. Er ist nicht mehr verbindlich, und
   in `sitzplan_app` wird **nichts** geändert.

## Schichtengrenzen

Zwei lokale Pakete, damit die Grenze geprüft wird statt begutachtet:

```text
Pakete/SitzplanKern      plattformneutral, nur Sprache und Foundation
├── Domain               Modelle, Dokumente, Regeln, Fehler, Protokolle
├── Datenvertrag         Mapping Dokument ↔ Domäne, Toleranzen
└── Core                 Konfiguration, Logging

Pakete/SitzplanSpeicher  macOS-only
└── Speicher             @Model-Typen, ModelContainer, Repository-Implementierungen
```

- `Domain` kennt weder SwiftUI noch SwiftData — nur Sprache und Foundation.
  Achtung: Der Paketschnitt allein hält das **nicht** auf. SwiftData ist ein
  System-Framework und lässt sich auf einem Mac aus jedem Target importieren.
  Rot wird ein solcher Import erst im Linux-Job, wo es das Framework nicht
  gibt. Dieser Job ist die Prüfstelle der Schichtengrenze, nicht bloß der
  billige Lauf.
- `Speicher` implementiert die Repository-Protokolle aus `Domain`.
- `Features` benutzen Domänenmodelle und Protokolle.
- Eine View greift **nie** direkt auf einen `ModelContext` oder einen
  `@Model`-Typ zu.
- Zustandsänderungen der Oberfläche auf `@MainActor`; Mapping- und
  Speicherarbeit nicht.

Unerwünscht: große `ContentView.swift`, universelles `AppViewModel`,
Geschäftslogik in Views, globale veränderliche Singletons, untypisierte
Fehlerketten.

## Gestaltung

`sitzplan_app/docs/designsystem.md` bleibt die gestalterische Quelle der
Wahrheit — die Datentrennung ändert daran nichts. Übertragen wird
**semantisch**, nicht pixelgenau. Wo eine Web-Vorgabe gegen eine
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
WCAG 2.2 AA.

## Tests

Swift Testing für Unit- und Vertragstests, XCUITest nur für kritische Abläufe.

Was ohne Oberfläche und ohne Datenbank prüfbar ist, gehört nach
`Pakete/SitzplanKern` — dort läuft es im billigen Linux-Job. Der Mac-Runner ist
für Speicher und Oberfläche da, nicht für Fachlogik.

Die Fixtures unter `contracts/fixtures/` sind die Verhaltensspezifikation
dieses Repositories. Eine Fixture zu ändern heißt, das Verhalten der Anwendung
zu ändern — eigener Pull Request, eigene Begründung, nicht nebenbei, um einen
roten Test grün zu bekommen.

## Verboten

- `git push --force`, Rebase oder Amend auf bereits gepushten Commits.
- `--no-verify` oder `--no-gpg-sign` ohne ausdrückliche Anweisung.
- Geheimnisse im Repository. Der KI-Schlüssel gehört in die Keychain.
- Beta-SDKs als Projektgrundlage. Lokal ist Xcode 27 Beta Werkzeug; verbindlich
  ist der CI-Lauf gegen macOS 15.
- Analytik oder Telemetrie ohne eigenes ADR — siehe Hartanker 2.
- Änderungen in `sitzplan_app`. Dieses Repository schreibt dort nicht.

## Widerspruch ist erwünscht

Anforderungen, die dem Designsystem, dem Datenschutz oder dem Datenvertrag
widersprechen: erst benennen, dann Alternative vorschlagen, dann auf
Entscheidung warten.
