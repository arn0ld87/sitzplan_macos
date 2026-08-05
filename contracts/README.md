# Contracts — die Verhaltensspezifikation dieser Anwendung

Diese Dateien beschreiben, wie Sitzplan Studio für macOS Dokumente liest und
schreibt. Sie sind kein Beiwerk der Tests, sondern deren Grundlage: Was hier
steht, ist das vereinbarte Verhalten; was der Code tut, hat sich danach zu
richten.

Die Fälle stammen ursprünglich aus dem Web-Client `sitzplan_app`, wo dieselben
Dokumentformate seit Längerem in Gebrauch sind und ihr Verhalten in TypeScript
geprüft ist. Sie sind hier **keine Kopie mehr**. Mit
[ADR-0002](../docs/decisions/0002-lokaler-einzelplatz.md) sind beide
Anwendungen unabhängige Produkte ohne gemeinsames Backend; diese Dateien
gehören ab jetzt diesem Repository, werden hier gepflegt und mit nichts mehr
abgeglichen. Der früher geplante CI-Vergleich gegen das Web-Repo entfällt.

Warum sie trotzdem bleiben: Die Formate sind durchdacht, im Betrieb erprobt und
in jedem Randfall festgelegt — bis hin zu der Frage, was ein `rotation_deg` von
45 Grad bedeutet und welcher Eintrag bei doppelter Sitzplatzzuordnung gewinnt.
Dieses Wissen noch einmal zu erfinden, wäre teuer und schlechter. Es liegt
deshalb weiter in ausführbarer Form vor, statt nur in Prosa.

## Was hier liegt

```text
contracts/
├── README.md          dieses Dokument
└── fixtures/          plattformneutrale JSON-Fälle, gelesen von den Swift-Tests
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

Die Fälle zu Soft-Delete und Sitzregeln beschreiben fachliches Verhalten und
gelten unverändert, obwohl es keine Datenbankzeilen mehr gibt, aus denen sie
einst stammten. Weich gelöscht wird lokal genauso wie vorher am Server, nur
heißt das Feld anders.

### Feldnamen in den Fixtures

Die Fixtures tragen die Schreibweisen aus der Zeit des gemeinsamen Backends. Sie
werden **nicht** umbenannt — eine Fixture zu ändern hieße, den Vertrag zu
ändern. Verbindlich ist deshalb diese Zuordnung:

| in der Fixture | im Swift-Modell | wo |
| --- | --- | --- |
| `deleted_at` | `geloeschtAm` | Klassen und Schüler in `soft-delete-faelle.json` |
| `deletedAt` | `geloeschtAm` | Papierkorb-Einträge in `soft-delete-faelle.json` |
| `klasse_id` | `klasse` (Beziehung) bzw. `klasseId` | Schüler und Sitzregeln |
| `vorname`, `nachname` | gleich | Schüler |
| `art` (`nicht_neben`, `muss_neben`) | `Regelart` | Sitzregeln |

Dass dieselbe Sache in derselben Datei zweimal verschieden geschrieben ist
(`deleted_at` gegen `deletedAt`), ist gewachsen und keine Absicht. Wer die
Fixtures liest, muss beide Formen bedienen; wer Swift schreibt, kennt nur
`geloeschtAm`.

## Quelle der Wahrheit

**Dieses Repository.** Weicht der Swift-Code von einer Fixture ab, ist der Code
falsch, bis das Gegenteil entschieden ist.

Eine Fixture zu ändern heißt, das Verhalten der Anwendung zu ändern. Das
geschieht bewusst, mit eigenem Pull Request und einem Satz zur Begründung —
nicht nebenbei, um einen roten Test grün zu bekommen.

Der Web-Client bleibt eine nützliche **Lesequelle**: Wo dieses Dokument, die
Fixtures und `docs/datenvertrag.md` eine Frage offenlassen, zeigt
`../sitzplan_app/src/data/`, wie dieselben Dokumente dort behandelt werden.
Verbindlich ist er nicht mehr. Geändert wird dort nichts.

## Regeln

1. **Keine echten Personendaten.** Ausschließlich erfundene Namen. Diese
   Dateien liegen in einem Git-Verlauf und sind nicht wieder
   herauszubekommen.
2. **Feste Kennungen.** Keine zufälligen UUIDs, keine Zeitstempel aus der
   aktuellen Uhrzeit. Ein Test, der beim zweiten Lauf etwas anderes prüft,
   prüft nichts.
3. **Erwartungswerte beschreiben, was gilt — nicht, was schön wäre.**
   Überraschendes Verhalten wird als Issue festgehalten und dann entschieden,
   nicht in der Fixture stillschweigend geglättet.
4. **Kein JSON Schema, solange es nichts trägt.** Die Formate sind über
   `docs/datenvertrag.md` und diese Fälle beschrieben. Ein Schema, das den
   Vertrag nur halb ausdrückt, ist schlechter als keines.

## Verwendung

Swift (Swift Testing): Die Fixtures liegen als Ressourcen im Testtarget von
`Pakete/SitzplanKern` und werden ohne SwiftData und ohne Oberfläche gelesen —
sie laufen damit im Linux-Job der CI. Der genaue Weg wird mit dem Paket
festgelegt.

## Weiterführend

- Vertragsdetails, Toleranzen und bekannte Widersprüche:
  [`docs/datenvertrag.md`](../docs/datenvertrag.md)
- Warum diese Anwendung lokal speichert:
  [ADR-0002](../docs/decisions/0002-lokaler-einzelplatz.md)
