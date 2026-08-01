# Claude Code — Sitzplan Studio für macOS

Ergänzt [`AGENTS.md`](AGENTS.md). Bei Widerspruch gewinnt diese Datei für
Claude Code. Antworten auf Deutsch, technische Bezeichner im Original.

## Zuerst lesen

[`docs/datenvertrag.md`](docs/datenvertrag.md) — vor jeder Änderung, die Daten
liest oder schreibt. Die Toleranzen beim Lesen, die Sitzplatzkennung und die
Rasterrundung sind Vertrag, nicht Implementierungsdetail.

Bei Zweifeln über tatsächliches Verhalten gewinnt der Web-Client:
`../sitzplan_app/src/data/`. Die Dokumentation kann veralten, der Code nicht.

## Zwei Repositories

| | |
| --- | --- |
| dieses | `sitzplan_macos` — Swift, SwiftUI |
| Web-Client | `../sitzplan_app` — TypeScript |
| gemeinsam | ein Supabase-Projekt, ein Schema, ein Satz RLS-Policies |

Änderungen an gemeinsamen Verträgen brauchen eine Gegenprobe drüben. Das
Web-Gate lautet dort `bun run typecheck && bun run lint && bun run test &&
bun run build`.

## Häufige Fallen

| Falle | Richtig |
| --- | --- |
| `zuordnungen` direkt in ein `Dictionary` | Geordnete Liste behalten — „der letzte gewinnt" braucht die Reihenfolge |
| `rounded()` für die Rasterrundung | `floor(x + 0.5)` — JavaScript rundet halbe Werte anders |
| Maße aus dem Dokument übernehmen | Aus der Möbeltabelle setzen, das Dokument kann falsch sein |
| Dokumentschlüssel per Konvertierungsstrategie | Explizite `CodingKeys` — `x_cm` und `breiteCm` stehen nebeneinander |
| `numeric` als `Double` erwarten | PostgREST liefert je nach Wert Zahl **oder** Zeichenkette |
| Klassen-Papierkorb stur nach `deleted_at` filtern | Gelöschte Klasse trägt Schüler mit identischem Zeitstempel |
| Supabase in einer View | Repository-Protokoll aus `Domain` |
| Dark Mode dem System überlassen | Ausschluss aktiv setzen, das Designsystem verbietet ihn |

## Toolchain

Lokal liegt nur Xcode 27 Beta auf macOS 27 Beta. Das ist Werkzeug, nicht
Grundlage: Deployment Target ist macOS 14, verbindlich grün ist der CI-Lauf auf
stabilem Xcode 26. Weicht der lokale Build ab, gewinnt die CI.

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
