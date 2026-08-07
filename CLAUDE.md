# Claude Code — Sitzplan Studio für macOS

Ergänzt [`AGENTS.md`](AGENTS.md). Bei Widerspruch gewinnt diese Datei für
Claude Code. Antworten auf Deutsch, technische Bezeichner im Original.

## Zuerst lesen

[`docs/datenvertrag.md`](docs/datenvertrag.md) — vor jeder Änderung, die Daten
liest oder schreibt. Die Toleranzen beim Lesen, die Sitzplatzkennung und die
Rasterrundung sind Vertrag, nicht Implementierungsdetail.

Verbindlich sind dieses Dokument, `docs/datenvertrag.md` und die Fixtures unter
`contracts/fixtures/`. Weicht der Swift-Code ab, ist der Code falsch.

## Zwei unabhängige Produkte

| | |
| --- | --- |
| dieses | `sitzplan_macos` — Swift, SwiftUI, lokal, kein Konto |
| Web-Client | `../sitzplan_app` — TypeScript, Supabase |
| gemeinsam | nichts — zwei unabhängige Produkte ([ADR-0002](docs/decisions/0002-lokaler-einzelplatz.md)) |

`../sitzplan_app` ist **ausschließlich Lesequelle** für Fragen, die der
Datenvertrag offenlässt — dort ist dasselbe Dokumentformat länger in Gebrauch.
Dort wird nichts geändert, und es gibt kein Web-Gate mehr, das hier etwas
absichert.

## Häufige Fallen

| Falle | Richtig |
| --- | --- |
| `zuordnungen` direkt in ein `Dictionary` | Geordnete Liste behalten — „der letzte gewinnt“ braucht die Reihenfolge |
| `rounded()` für die Rasterrundung | `floor(x + 0.5)` — JavaScript rundet halbe Werte anders |
| Maße aus dem Dokument übernehmen | Aus der Möbeltabelle setzen, das Dokument kann falsch sein |
| Dokumentschlüssel per Konvertierungsstrategie | Explizite `CodingKeys` — `x_cm` und `breiteCm` stehen nebeneinander |
| Klassen-Papierkorb stur nach `geloeschtAm` filtern | Gelöschte Klasse trägt Schüler mit identischem Zeitstempel |
| `ModelContext` oder `@Query` in einer View | Repository-Protokoll aus `Domain` |
| `import SwiftData` in `Domain` für harmlos halten | Übersetzt auf dem Mac anstandslos — erst der Linux-Job merkt es |
| Netzaufruf einbauen | Nur der KI-Aufruf ist erlaubt, sonst keiner |
| Dark Mode dem System überlassen | Ausschluss aktiv setzen, das Designsystem verbietet ihn |

## Toolchain

Lokal liegt nur Xcode 27 Beta auf macOS 27 Beta. Das ist Werkzeug, nicht
Grundlage: Deployment Target ist macOS 15, verbindlich grün ist der CI-Lauf —
`ubuntu-latest` für `Pakete/SitzplanKern`, `macos-26` für die App. Weicht der
lokale Build ab, gewinnt die CI.

## Token Efficiency

- Keine Datei erneut lesen, die gerade geschrieben wurde.
- Kein Nacherzählen von Diffs, keine Zusammenfassung, wenn das Ergebnis
  selbsterklärend ist.
- Unabhängige Tool-Calls in einer Message bündeln.
- Zusammengehörige Edits in einem Rutsch.
- Subagenten mit dem günstigen Modell starten.

## Stil

- Knapp. 2–4 Sätze als Standardreport.
- Datei-Referenzen als Markdown-Link.
- Keine Emojis, keine Entschuldigungen, keine Meta-Kommentare.
- Widerworte sind erwünscht: unsinnige oder riskante Anforderungen erst
  benennen, dann Gegenvorschlag, dann auf Entscheidung warten.

## Agent skills

### Issue tracker

Issues werden in GitHub Issues dieses Repositories verwaltet. Siehe
`docs/agents/issue-tracker.md`.

### Triage labels

Die fünf Standard-Triage-Labels werden unverändert verwendet
(`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`,
`wontfix`). Siehe `docs/agents/triage-labels.md`.

### Domain docs

Single-context Layout: Domain-Begriffe in `CONTEXT.md` (falls vorhanden),
Architekturentscheidungen unter `docs/decisions/`. Siehe
`docs/agents/domain.md`.
