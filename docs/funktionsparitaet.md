# Funktionsparität Web ↔ macOS

Stand: 2026-08-01, Ende M0. **Bei jedem Pull Request mit Funktionsbezug
aktualisieren.**

| Bereich | Web | macOS | Gemeinsamer Vertrag | Ziel |
| --- | ---: | ---: | --- | --- |
| Anmeldung | vorhanden | geplant | Supabase Auth | M1 |
| Klassen | vorhanden | geplant | Tabellen und RLS | M2 |
| Schüler | vorhanden | geplant | Tabellen und Mapping | M2 |
| Sitzregeln | vorhanden | geplant | Fachregeln | M2 |
| Raumeditor | vorhanden | geplant | `RaumDokument` | M3 |
| Sitzplaneditor | vorhanden | geplant | `PlanDokument` und `seatId` | M4 |
| Konfliktprüfung | vorhanden | geplant | identische Fachregeln | M4 |
| Drucken und PDF | vorhanden | geplant | fachliche Darstellung | M5 |
| Papierkorb | vorhanden | geplant | `deleted_at` | M5 |
| Offline | teilweise angekündigt | später | Konfliktstrategie | nach MVP |

## Ergänzungen aus der Ist-Analyse

Nicht in der Vorlage, aber im Bestand vorhanden und deshalb hier geführt:

| Bereich | Web | macOS | Anmerkung |
| --- | ---: | ---: | --- |
| 3D-Ansicht des Raums | vorhanden (PR #20) | nicht geplant | Kein Paritätsziel. Die SVG-Ansicht ist die fachliche Darstellung; die 3D-Ansicht ist eine Zugabe. |
| Sitzplan-Versionen | Tabelle vorhanden, ungenutzt | nicht geplant | `sitzplan_versionen` hat Schema und RLS, aber keine Entsprechung in `mapping.ts`. |
| Einstellungen und Konto | vorhanden | geplant | M5, nicht vor der Kernfunktion. |
| CSV-Import Schüler | im Designsystem vorgesehen | offen | Im Web-Client noch zu prüfen. |

## Lesart

- **vorhanden** — im Produkt benutzbar.
- **geplant** — Meilenstein zugewiesen, nicht begonnen.
- **offen** — noch nicht entschieden, ob es Paritätsziel wird.
- **nicht geplant** — bewusst kein Paritätsziel.

Parität heißt nicht gleiche Oberfläche. Sie heißt: dieselben Daten, dieselben
fachlichen Regeln, dasselbe Ergebnis auf dem Papier. Wie eine Ansicht aussieht,
entscheidet die Plattform.
