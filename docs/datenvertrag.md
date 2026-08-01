# Datenvertrag — was beide Clients gleich verstehen müssen

Stand: 2026-08-01. Tatsachenquelle ist der Code des Web-Clients
(`sitzplan_app`), nicht dieses Dokument. Wo beides auseinanderläuft, gewinnt der
Code — und dieses Dokument wird korrigiert.

Maßgeblich im Web-Repo:

| Was | Datei |
| --- | --- |
| Domänentypen, Geometrie, `seatId` | `src/data/types.ts` |
| Zeilen ↔ Domäne, Dokumentformate | `src/data/mapping.ts` |
| Zeilen zu Anwendungsdaten, Papierkorb | `src/data/laden.ts` |
| Soft-Delete-Filter | `src/data/papierkorb.ts` |
| Regelprüfung | `src/data/sitzregeln.ts` |
| Rasterrechnung | `src/lib/raster.ts` |
| Schema und RLS | `supabase/migrations/*.sql` |

## Grundsätze

1. **Zentimeter sind die fachliche Einheit.** Bildschirmkoordinaten sind eine
   Projektion. Zoom und Fenstergröße verändern nie gespeicherte Geometrie.
2. **Lesen ist tolerant, Schreiben ist streng.** Alte und unvollständige
   Dokumente dürfen nie zum Absturz führen; geschrieben wird nur Vollständiges
   und Kanonisches.
3. **Unbekannte Felder sind kein Fehler.** Sie werden beim Lesen übergangen.
4. **`deleted_at IS NULL` in jeder Leseabfrage auf Nutzdaten.** Papierkorb-
   Abfragen sind ausdrücklich eigene Methoden, keine Variante mit Schalter.
5. **RLS ist die Autorisierungsgrenze.** Der Client filtert zusätzlich, weil es
   fachlich richtig ist, nicht weil es ihn schützt.

## Tabellen

Sechs Tabellen. Jede hat `id uuid`, `user_id uuid NOT NULL REFERENCES
auth.users ON DELETE CASCADE`, `created_at`, `updated_at`, `deleted_at
timestamptz NULL`, den Trigger `set_updated_at` und vier RLS-Policies gegen
`auth.uid()`.

| Tabelle | Fachspalten |
| --- | --- |
| `klassen` | `name text`, `notizen text NULL` |
| `schueler` | `klasse_id`, `vorname`, `nachname`, `initialen`, `farb_index int CHECK 0..7` |
| `sitzregeln` | `klasse_id`, `schueler_a`, `schueler_b`, `art CHECK IN ('nicht_neben','muss_neben')` |
| `raeume` | `name`, `breite_cm numeric CHECK > 0`, `laenge_cm numeric CHECK > 0`, `raster_cm numeric CHECK >= 5`, `canvas_document jsonb`, `dokument_version int DEFAULT 3` |
| `sitzplaene` | `klasse_id`, `raum_id`, `name`, `status CHECK IN ('entwurf','aktiv','archiv')`, `canvas_document jsonb NOT NULL`, `revision int DEFAULT 1`, `dokument_version int DEFAULT 1` |
| `sitzplan_versionen` | `sitzplan_id`, `name`, `canvas_document jsonb` |

`schueler`, `sitzregeln` und `sitzplaene` haben zusätzlich eine RLS-Bedingung
über die zugehörige Klasse: Es genügt nicht, dass `user_id` stimmt — die Klasse
muss ebenfalls dem Konto gehören. Der macOS-Client muss dazu nichts tun, aber
er muss wissen, dass ein Schreibvorgang mit fremder `klasse_id` scheitert,
statt still nichts zu tun.

Numerische Maße kommen als `numeric` aus PostgreSQL. PostgREST liefert sie je
nach Wert als Zahl oder als Zeichenkette; der Web-Client wickelt sie deshalb in
`Number(...)`. Swift muss dasselbe tun und beide Formen dekodieren.

## Dokumentformate

Geometrie liegt nicht relational, sondern als JSONB in `canvas_document`.

### RaumDokument (`raeume.canvas_document`, Version 3)

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

Der Vorgabewert der Spalte ist `{"objekte": [], "sitzplaetze": []}`.

### PlanDokument (`sitzplaene.canvas_document`, Version 1)

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

```
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

```
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

> **Fallstrick für Swift.** „Der letzte gewinnt" setzt eine Reihenfolge voraus.
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

```
RASTER_STANDARD = 25
rasterWeite(r)  = r ?? 25, und auch bei 0 → 25
aufRasterRunden(wert, raster) = round(wert / raster) * raster
```

Die Rundung ist die von JavaScript: Halbe Schritte gehen zur **größeren** Zahl.
Swifts `rounded()` rundet halbe Werte vom Nullpunkt weg — bei negativen Werten
weicht das ab. Swift muss `(wert / raster).rounded(.toNearestOrAwayFromZero)`
also **nicht** verwenden, sondern `floor(x + 0.5)`.

> **Widerspruch im Bestand.** `RASTER_STANDARD` ist 25, der Rückfallwert in
> `ausPlanDokument` ist aber 10, und die Datenbank verlangt nur `>= 5`. Ein Plan
> ohne `rasterCm` bekommt damit 10, ein Raum ohne Rasterangabe 25. Der
> macOS-Client übernimmt beide Werte unverändert, damit er dieselben Dokumente
> gleich liest. Aufgelöst gehört das im Web-Repo, nicht hier — als eigenes Issue.

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

## Konflikterkennung beim Speichern

Der Bestand gibt Folgendes her:

- **`updated_at` existiert auf allen sechs Tabellen** und wird per Trigger
  gepflegt. Damit ist optimistisches Sperren ohne Migration möglich: beim Laden
  merken, beim Schreiben als Bedingung mitgeben, bei null betroffenen Zeilen
  liegt ein Serverkonflikt vor.
- **`sitzplaene.revision` ist dafür unbrauchbar.** Die Spalte existiert, aber
  `planZuRow` schreibt sie hart auf `1`; sie wird nie hochgezählt.
- Die TypeScript-Zeilentypen führen `updated_at` nur bei `PlanRow` und dort
  optional. Der macOS-Client nimmt es überall mit auf — das ist eine Ergänzung
  am Client, keine Schemaänderung.

Verbindlich: **keine undokumentierte Last-Write-Wins-Strategie.** Ein
Speicherfehler darf Benutzeränderungen nie still verwerfen. Die Zustände sind
in `docs/architektur.md` festgelegt.

## Bekannte Lücken im Bestand

Festgestellt bei der Analyse am 2026-08-01, nicht im Rahmen von M0 verändert:

1. Rasterrückfall 10 gegen `RASTER_STANDARD` 25 (siehe oben).
2. `sitzplaene.revision` wird nie erhöht.
3. `sitzplan_versionen` hat eine Tabelle samt RLS, aber keine Entsprechung in
   `mapping.ts` — der Web-Client schreibt und liest sie derzeit nicht.
4. `SchuelerRow` und `SitzregelRow` führen kein `created_at`, obwohl die
   Datenbank es hat.
5. `rowZuPlan` setzt `updated` notfalls auf die **aktuelle Uhrzeit**, wenn weder
   `updated_at` noch `deleted_at` vorliegen. Das erzeugt bei jedem Laden einen
   anderen Wert und taugt nicht als Vergleichsgrundlage.

Punkte 1, 2 und 5 berühren die Konfliktstrategie und gehören vor M4 geklärt.
