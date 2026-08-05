# Datenvertrag — wie diese Anwendung Daten liest und schreibt

Stand: 2026-08-05. Verbindlich sind dieses Dokument und die Fixtures unter
`contracts/fixtures/`. Weicht der Swift-Code ab, ist der Code falsch, bis das
Gegenteil entschieden ist.

Die Formate stammen aus dem Web-Client, wo sie seit Längerem in Gebrauch und in
TypeScript geprüft sind. Seit [ADR-0002](decisions/0002-lokaler-einzelplatz.md)
teilen die beiden Anwendungen keine Daten mehr; die Formate bleiben trotzdem,
weil sie erprobt und in jedem Randfall festgelegt sind. Was hier steht, gilt
deshalb nicht länger, weil ein Server es erzwingt, sondern weil es entschieden
ist.

Der Web-Client bleibt eine **Lesequelle** für Fragen, die dieses Dokument
offenlässt. Geändert wird dort nichts:

| Was | Datei in `sitzplan_app` |
| --- | --- |
| Domänentypen, Geometrie, `seatId` | `src/data/types.ts` |
| Dokumentformate, Mapping | `src/data/mapping.ts` |
| Papierkorb, Soft-Delete-Filter | `src/data/laden.ts`, `src/data/papierkorb.ts` |
| Regelprüfung | `src/data/sitzregeln.ts` |
| Rasterrechnung | `src/lib/raster.ts` |

## Grundsätze

1. **Zentimeter sind die fachliche Einheit.** Bildschirmkoordinaten sind eine
   Projektion. Zoom und Fenstergröße verändern nie gespeicherte Geometrie.
2. **Lesen ist tolerant, Schreiben ist streng.** Alte und unvollständige
   Dokumente dürfen nie zum Absturz führen; geschrieben wird nur Vollständiges
   und Kanonisches.
3. **Unbekannte Felder sind kein Fehler.** Sie werden beim Lesen übergangen.
4. **Weich gelöschtes bleibt draußen.** `geloeschtAm` gesetzt heißt: nicht in
   der Liste. Papierkorb-Abfragen sind ausdrücklich eigene Methoden, keine
   Variante mit Schalter.
5. **Das Dokument ist ein Wert.** Es wird als Ganzes gelesen und als Ganzes
   geschrieben, nie teilweise fortgeschrieben. Wer ein einzelnes Feld ändern
   will, liest, ändert und schreibt zurück.

## Modelle

Sechs `@Model`-Typen in `Pakete/SitzplanSpeicher`. Jeder hat `id: UUID`,
`erstelltAm: Date`, `geaendertAm: Date` und `geloeschtAm: Date?`. Kein
`user_id`: Es gibt genau einen Datenbestand, der der Person gehört, die vor dem
Rechner sitzt.

| Modell | Fachliche Felder |
| --- | --- |
| `KlassenEintrag` | `name: String`, `notizen: String?` |
| `SchuelerEintrag` | `klasse`, `vorname`, `nachname`, `initialen`, `farbIndex: Int` (0…7) |
| `SitzregelEintrag` | `klasse`, `schuelerA`, `schuelerB`, `art: Regelart` |
| `RaumEintrag` | `name`, `breiteCm: Double`, `laengeCm: Double`, `rasterCm: Double`, `dokument: RaumDokument`, `dokumentVersion: Int` (3) |
| `SitzplanEintrag` | `klasse`, `raum`, `name`, `status: Planstatus`, `dokument: PlanDokument`, `dokumentVersion: Int` (1) |
| `SitzplanVersionEintrag` | `sitzplan`, `name`, `dokument: PlanDokument` |

Was in PostgreSQL ein `CHECK` war, ist in Swift ein Aufzählungstyp:
`Regelart` mit `nichtNeben` und `mussNeben`, `Planstatus` mit `entwurf`,
`aktiv` und `archiv`. Was dort ein Fremdschlüssel war, ist hier eine
SwiftData-Beziehung. Beides prüft der Compiler, nicht die Datenbank.

Die Wertebereiche bleiben Vertrag und werden im `Domain`-Modul geprüft, nicht
im Speicher: `breiteCm` und `laengeCm` größer als 0, `rasterCm` mindestens 5,
`farbIndex` zwischen 0 und 7. Eine lokale Datenbank hat keinen Server, der
ungültige Werte abweist — die Prüfung ist damit nicht weniger nötig, sondern
nur woanders.

> **Historisch.** Bis ADR-0002 lagen dieselben Daten in sechs Supabase-Tabellen
> mit `user_id`, `deleted_at`, `set_updated_at`-Trigger und vier RLS-Policies je
> Tabelle; numerische Maße kamen als `numeric` und mussten je nach Wert als Zahl
> **oder** Zeichenkette dekodiert werden. Beides entfällt. Wer die alten
> Fixtures liest, trifft die Feldnamen dort weiterhin an.

## Dokumentformate

Geometrie liegt nicht in Einzelfeldern, sondern als Dokument am Modell.

### RaumDokument (`RaumEintrag.dokument`, Version 3)

```json
{
  "objekte": [
    { "id": "…", "typ": "table_double", "x_cm": 100, "y_cm": 200,
      "breite_cm": 120, "tiefe_cm": 50, "rotation_deg": 90 }
  ],
  "sitzplaetze": [
    { "id": "…__sitz_1", "objektId": "…", "lokalX_cm": 30,
      "lokalY_cm": 25, "bezeichnung": "Platz 1" }
  ]
}
```

Der Vorgabewert ist `{"objekte": [], "sitzplaetze": []}`.

### PlanDokument (`SitzplanEintrag.dokument`, Version 1)

```json
{
  "quelle": { "klasseId": "…", "raumId": "…" },
  "raumGeometrie": {
    "breiteCm": 720, "laengeCm": 520, "rasterCm": 25,
    "objekte": [ … ], "sitzplaetze": [ … ]
  },
  "zuordnungen": [ { "sitzplatzId": "…__sitz_1", "schuelerId": "…" } ]
}
```

Zwei Namenswelten, beide verbindlich: Das RaumDokument benutzt
`x_cm`/`breite_cm` mit Unterstrich, das PlanDokument `breiteCm`/`rasterCm` in
Binnenmajuskel. Innerhalb von `raumGeometrie.objekte` gilt wieder die
Unterstrich-Form. Das ist gewachsen und wird nicht angeglichen — eine Änderung
bräche jedes bestehende Dokument. Swift bildet das über explizite
`CodingKeys` ab, nicht über eine globale Konvertierungsstrategie.

`raumGeometrie` ist die **eingefrorene Kopie** des Raums zum Zeitpunkt der
Erstellung. Sie ist von der Vorlage unabhängig; Raumänderungen wirken nicht auf
bestehende Pläne. Der Raumname steht **nicht** im Dokument — er wird beim Laden
aus der Raumzeile nachgereicht, mit `"Raum"` als Rückfallwert.

### Möbeltypen

Im Dokument stehen englische Bezeichner, in der Domäne deutsche:

| Dokument | Domäne | Breite × Tiefe (cm) | Sitzplätze |
| --- | --- | --- | --- |
| `table_single` | `einzeltisch` | 60 × 50 | 1 |
| `table_double` | `doppeltisch` | 120 × 50 | 2 |
| `teacher_desk` | `pult` | 160 × 80 | 0 |
| `board` | `tafel` | 400 × 15 | 0 |
| `door` | `tuer` | 90 × 20 | 0 |
| `window` | `fenster` | 15 × 180 | 0 |

Die Maße stammen aus `FURNITURE_SPECS` und werden beim Schreiben **aus der
Tabelle gesetzt**, nicht aus dem Dokument übernommen. Ein Dokument mit
abweichendem `breite_cm` wird beim nächsten Schreiben auf den Tabellenwert
zurückgesetzt. Unbekannte `typ`-Werte werden beim Lesen zu `einzeltisch`.

`rotation_deg` kennt nur 0, 90, 180, 270. Alles andere wird beim Lesen zu 0.

## Sitzplatzkennung

```text
<objektId>__sitz_<n>        n beginnt bei 1
```

Bau und Zerlegung müssen in Swift bitgenau dem TypeScript entsprechen:

- Getrennt wird am **letzten** Vorkommen von `__sitz_`, damit Objektkennungen,
  die selbst so aussehen, den Rückweg überstehen.
- Der Rest muss vollständig aus Ziffern bestehen.
- Die Kennung muss **kanonisch** sein: Wer sie neu baut, muss dieselbe
  Zeichenkette erhalten. `…__sitz_007` und `…__sitz_1e3` sind damit ungültig.
- Ungültige Kennungen ergeben `nil`, keinen Fehler und keinen Absturz.

Sitzplätze werden aus dem Möbelstück abgeleitet, nicht frei vergeben. Die Lage
auf dem Möbelstück, in Zentimetern relativ zur linken oberen Ecke, **vor** jeder
Drehung:

```text
lokalX_cm = breite * (i + 0.5) / anzahl        i = 0 … anzahl-1
lokalY_cm = tiefe / 2
bezeichnung = "Platz \(i + 1)"
```

Für den Doppeltisch ergibt das 30 cm und 90 cm, für den Einzeltisch 30 cm.

## Toleranzen beim Lesen

Diese Rückfallwerte sind Vertrag, nicht Zufall. Swift muss sie exakt spiegeln:

| Stelle | Fehlt / ungültig | Ergebnis |
| --- | --- | --- |
| `objekte`, `sitzplaetze` | kein Array | leeres Array |
| `typ` | unbekannt | `einzeltisch` |
| `rotation_deg` | nicht 0/90/180/270 | `0` |
| `x_cm`, `y_cm` | fehlt oder unlesbar | `0` |
| `raumGeometrie` | fehlt ganz | 800 × 600, Raster 10, leer |
| `breiteCm`, `laengeCm` | fehlt oder 0 | `0` |
| `rasterCm` | fehlt oder 0 | `10` |
| Raumname im Plan | nicht im Dokument | aus der Raumzeile, sonst `"Raum"` |
| `zuordnungen` | fehlt | leere Zuordnung |

Mehrfache Zuordnungen auf denselben Sitzplatz: Der **letzte** Eintrag gewinnt,
weil die Liste in ein Wörterbuch überführt wird. Steht ein Schüler auf mehreren
Plätzen, gewinnt bei der Regelprüfung ebenfalls der zuletzt eingetragene Platz.

> **Fallstrick für Swift.** „Der letzte gewinnt“ setzt eine Reihenfolge voraus.
> JavaScript-Objekte mit Zeichenkettenschlüsseln behalten die Einfügereihenfolge,
> ein Swift-`Dictionary` nicht. Wird `zuordnungen` in Swift direkt in ein
> `[String: String]` überführt, ist das Ergebnis bei doppelten Einträgen
> zufällig.
>
> Verbindlich: `zuordnungen` bleibt in Swift die **geordnete Liste** aus dem
> Dokument. Ein Wörterbuch wird erst daraus abgeleitet, und zwar in
> Dokumentreihenfolge, sodass spätere Einträge frühere überschreiben. Dasselbe
> gilt für die Umkehrung Schüler → Platz in der Regelprüfung.

## Rasterrechnung

```text
RASTER_STANDARD = 25
rasterWeite(r)  = r ?? 25, und auch bei 0 → 25
aufRasterRunden(wert, raster) = round(wert / raster) * raster
```

Die Rundung ist die von JavaScript: Halbe Schritte gehen zur **größeren** Zahl.
Swifts `rounded()` rundet halbe Werte vom Nullpunkt weg — bei negativen Werten
weicht das ab. Swift muss `(wert / raster).rounded(.toNearestOrAwayFromZero)`
also **nicht** verwenden, sondern `floor(x + 0.5)`.

> **Widerspruch im Bestand.** `RASTER_STANDARD` ist 25, der Rückfallwert in
> `ausPlanDokument` ist aber 10. Ein Plan ohne `rasterCm` bekommt damit 10, ein
> Raum ohne Rasterangabe 25. Beide Werte gelten hier unverändert weiter, damit
> dieselben Dokumente gleich gelesen werden — die Fixtures halten sie fest.
>
> Aufgelöst wird das **in diesem Repository** (siehe „Bekannte Widersprüche“
> unten), nicht im Web-Repo: Seit ADR-0002 ist `sitzplan_app` ein unabhängiges
> Produkt und nur noch Lesequelle. Dass dieselbe Unstimmigkeit dort weiterlebt,
> ist nicht mehr unsere Sache.

## Soft-Delete

Löschen setzt `deleted_at`, es entfernt keine Zeile. Daraus folgt mehr als ein
Filter:

- Ein bereits gelöschter Datensatz behält beim erneuten Löschen seinen
  **ursprünglichen** Zeitstempel. Sonst verschiebt sich die Reihenfolge im
  Papierkorb.
- Wird eine Klasse gelöscht, werden **alle ihre Schüler** mit demselben
  Zeitstempel fortgeschrieben. Beim Lesen entscheidet der Zustand der Klasse,
  welche Schüler sie trägt:
  - aktive Klasse → nur Schüler ohne `deleted_at`
  - gelöschte Klasse → die Schüler mit **identischem** Zeitstempel; wer vorher
    einzeln gelöscht wurde, trägt einen älteren und bleibt gelöscht
- Sitzzuweisungen gelöschter Schüler bleiben im Dokument bestehen und werden
  beim Lesen nur ausgeblendet. Ein wiederhergestellter Schüler bekommt seinen
  Platz zurück.

Diese Regel ist der Grund, warum ein Klassen-Papierkorb überhaupt Schüler
enthält. Wer sie beim Portieren übersieht, baut Datenverlust ein.

## Speichern

Es gibt keinen Serverkonflikt mehr. Ein Datenbestand, ein Prozess, ein Nutzer —
niemand schreibt gleichzeitig von woanders. Optimistisches Sperren über
`updated_at`, das `revision`-Feld und die Frage, wessen Stand neuer ist,
entfallen mit dem Backend.

Was bleibt:

- **Ein Speicherfehler verwirft nie eine Benutzeränderung.** Schlägt das
  Schreiben fehl — Platte voll, Datei nicht schreibbar, Datenbank beschädigt —,
  wird das gemeldet und die Änderung bleibt bearbeitbar. Die Zustände stehen in
  [`architektur.md`](architektur.md).
- **`geaendertAm` wird beim Schreiben gesetzt**, nicht von einem Trigger. Es
  dient der Anzeige und der Sortierung, nicht der Konflikterkennung.
- **Zwei Fenster auf demselben Bestand** sind der einzig verbliebene
  Gleichzeitigkeitsfall. Er wird über einen gemeinsamen `ModelContext` gelöst,
  nicht über Versionsvergleiche.

## Bekannte Widersprüche

1. **Rasterrückfall 10 gegen `RASTER_STANDARD` 25** (siehe oben). Der einzige
   Punkt der alten Liste, der weiterlebt: Er steckt nicht im Schema, sondern im
   Dokumentformat, und die Fixtures halten ihn fest. Zu entscheiden, bevor der
   Sitzplaneditor entsteht — eigenes Issue.
2. **`SitzplanVersionEintrag` ist vorgesehen, aber ungenutzt.** Das Modell
   steht im Vertrag, weil das Dokumentformat es hergibt; gebaut wird es erst,
   wenn Plan-Versionen ein Merkmal werden.

Erledigt mit ADR-0002: `sitzplaene.revision`, das nie erhöht wurde; fehlende
`created_at`-Felder in den Zeilentypen; `rowZuPlan`, das `updated` notfalls auf
die aktuelle Uhrzeit setzte. Alle drei betrafen das Zusammenspiel mit dem
Server und haben ohne ihn keinen Gegenstand mehr.
