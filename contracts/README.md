# Contracts — gemeinsame Verträge zweier Clients

Sitzplan Studio hat zwei Clients auf einem Backend:

| Client | Repository | Sprache |
| --- | --- | --- |
| Web | `sitzplan_app` (dieses) | TypeScript |
| macOS | `sitzplan_macos` | Swift |

Beide lesen dieselben Supabase-Tabellen und dieselben JSONB-Dokumente. Der
teuerste denkbare Fehler ist deshalb nicht ein Absturz, sondern ein stiller:
dass beide dasselbe Dokument **unterschiedlich verstehen** und niemand es
merkt, bis eine Lehrkraft einen falschen Sitzplan ausdruckt.

Dagegen helfen diese Dateien.

## Was hier liegt

```
contracts/
├── README.md          dieses Dokument
└── fixtures/          plattformneutrale JSON-Fälle, von beiden Suiten gelesen
```

| Datei | Deckt ab |
| --- | --- |
| `raum-dokument-v3.json` | kanonisches `RaumDokument`, Version 3 |
| `plan-dokument-v1.json` | kanonisches `PlanDokument` mit eingefrorener Raumkopie |
| `plan-dokument-alt-unvollstaendig.json` | Altfälle, Sitzplatzkennungen, Rasterrundung |
| `sitzregeln-konflikte.json` | Regelprüfung einschließlich Grenzfällen |
| `soft-delete-faelle.json` | Soft-Delete, Klassen-Papierkorb, Sortierung |

Jede Datei trägt ihre Erwartungswerte unter `_erwartet` beziehungsweise
`erwartet` bei sich. Sie sind damit lesbar, ohne den Testcode zu kennen.
Schlüssel mit führendem Unterstrich sind Beiwerk und nicht Teil des
Dokumentformats.

## Quelle der Wahrheit

**Dieses Repository.** Hier liegen Schema, Migrationen und die
Referenzimplementierung in `src/data/`. Das macOS-Repository hält eine Kopie
unter `contracts/fixtures/` und vergleicht sie in seiner CI. Weicht sie ab,
wird der Lauf rot.

Wer eine Fixture ändert, ändert sie **zuerst hier** und zieht sie danach drüben
nach. Der umgekehrte Weg erzeugt genau die Drift, die verhindert werden soll.

## Regeln

1. **Keine echten Personendaten.** Ausschließlich erfundene Namen — dieselben
   wie in `docs/designsystem.md`. Diese Dateien liegen in einem Git-Verlauf und
   sind nicht wieder herauszubekommen.
2. **Feste Kennungen.** Keine zufälligen UUIDs, keine Zeitstempel aus `now()`.
   Ein Test, der beim zweiten Lauf etwas anderes prüft, prüft nichts.
3. **Erwartungswerte kommen aus dem Code, nicht aus der Absicht.** Was
   `mapping.ts` tatsächlich tut, ist der Vertrag — auch dort, wo es
   überraschend ist. Fehlerhaft erscheinendes Verhalten wird als Issue
   festgehalten, nicht in der Fixture stillschweigend korrigiert.
4. **Kein JSON Schema, solange es nichts trägt.** Die Formate sind über
   `mapping.ts` und diese Fälle beschrieben. Ein Schema, das den Vertrag nur
   halb ausdrückt, ist schlechter als keines. Ein `schema/`-Verzeichnis
   entsteht, wenn es einen belegten Nutzen hat.

## Verwendung

TypeScript (Vitest):

```ts
import doc from "../../contracts/fixtures/raum-dokument-v3.json";
```

Swift (Swift Testing): Die Fixtures liegen als Ressourcen im Testtarget. Der
genaue Weg wird mit dem Xcode-Projekt in M1 festgelegt.

## Weiterführend

- Vertragsdetails und bekannte Lücken: `sitzplan_macos/docs/datenvertrag.md`
- Warum es zwei Clients gibt: `docs/decisions/0006-native-macos-client.md`
