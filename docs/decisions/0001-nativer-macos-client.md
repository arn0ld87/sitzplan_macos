# ADR-0001: Nativer macOS-Client als zweiter Client desselben Produkts

- Status: **Superseded by [ADR-0002](0002-lokaler-einzelplatz.md)**
- Datum: 2026-08-01
- Abgelöst am: 2026-08-05
- Betrifft: dieses Repository, `sitzplan_app` (Web-Client), das gemeinsame
  Supabase-Projekt
- Entspricht im Web-Repo: `docs/decisions/0006-native-macos-client.md`

> **Nicht mehr gültig.** Die Grundlage dieses ADR — ein gemeinsames Backend für
> zwei Clients — ist mit [ADR-0002](0002-lokaler-einzelplatz.md) entfallen. Die
> macOS-App speichert lokal, ohne Konto und ohne Server. Was hier über Druck,
> Tastatur, Undo, den Ausschluss von WebView und Catalyst, die Schichtengrenzen
> und den Ausschluss von Dark Mode steht, gilt unverändert weiter; alles zu
> Supabase, RLS, Anmeldung, Publishable Key, Offline-Zuständen und
> Fixture-Abgleich gegen das Web-Repo ist historisch. Das Dokument bleibt
> stehen, weil die Begründung lesbar bleiben soll.

## Kontext

Sitzplan Studio ist eine Web-App für Lehrkräfte: Klassen verwalten, Räume
maßstäblich zeichnen, Schüler auf Sitzplätze verteilen, Konflikte prüfen,
drucken. Der Kern der Arbeit ist ein Zeicheneditor — Objekte auswählen,
schieben, drehen, einrasten, rückgängig machen — und eine Druckausgabe.

Genau diese beiden Dinge sind im Browser am teuersten: Zeigerpräzision,
Tastaturbedienung, Undo-Stapel und Druckausgabe muss eine Web-App nachbauen,
während macOS sie mitbringt. Lehrkräfte arbeiten zudem häufig am selben Gerät im
selben Klassenraum; ein Fenster, das sich wie eine Mac-Anwendung verhält und
einen Druckdialog kennt, den sie schon kennen, ist dort mehr wert als eine
weitere Registerkarte.

Die Daten liegen bereits vollständig in Supabase: sechs Tabellen, jede mit
`user_id`, vollständigem RLS-Policy-Satz und `deleted_at`. Geometrie liegt als
versioniertes JSONB-Dokument (ADR-0002 im Web-Repo). Ein zweiter Client braucht
davon nichts zu ändern.

## Entscheidung

Ein nativer macOS-Client in Swift und SwiftUI, als **zusätzlicher Client
desselben Produkts** — nicht als eigenständige Anwendung mit eigenem Backend.

### Ein Backend, zwei Clients

Web-Client und macOS-Client teilen sich Supabase-Projekt, PostgreSQL-Schema,
Migrationen, RLS-Policies, Benutzerkonten und die JSONB-Dokumentverträge. Es
entsteht kein zweites Backend und kein zweites Schema.

Der macOS-Client verwendet den Publishable Key. Ein Service-Role-Key gehört nie
in einen Client, direkte PostgreSQL-Verbindungen gibt es nicht, und RLS bleibt
die einzige Autorisierungsgrenze. Der Client filtert `deleted_at IS NULL`, weil
es fachlich richtig ist — nicht, weil es ihn schützt.

### SwiftUI, kein eingebetteter Browser

Kein WebView, kein Electron, kein Catalyst. Eine eingebettete Weboberfläche
würde den einen Grund erledigen, aus dem dieser Client existiert: dass er sich
wie eine Mac-Anwendung anfühlt und deren Druck-, Fokus- und Undo-Infrastruktur
erbt.

AppKit wird punktuell zugelassen, wo SwiftUI eine fachlich nötige Fähigkeit
nicht zuverlässig trägt — Druckausgabe über `NSPrintOperation`, PDF-Erzeugung,
besonderes Hit-Testing, anspruchsvolles Drag-and-drop. Punktuell heißt: eine
gekapselte Komponente hinter einem Protokoll, kein zweiter vollständiger
UI-Stapel.

### Getrennte Repositories

Der macOS-Client bekommt ein eigenes Repository, statt in `sitzplan_app` unter
`macos/` zu wohnen.

Ausschlaggebend ist Lovable: Es synchronisiert `main` des Web-Repos in beide
Richtungen. Ein Xcode-Projekt in diesem Repo stünde dauerhaft unter dem Zugriff
eines Werkzeugs, das TypeScript erwartet und `.pbxproj`-Dateien nicht kennt.
Dazu kommen getrennte Werkzeugketten (Bun gegen Xcode), getrennte CI-Läufe und
ein getrennter Freigabezyklus.

Der Preis ist real und wird unten mit den Contract-Fixtures beantwortet: Zwei
Repositories können auseinanderlaufen, ohne dass es jemandem auffällt.

### Was plattformübergreifend verbindlich ist

Verbindlich für beide Clients, weil sonst Daten falsch gelesen werden:

- Datenbankschema, Migrationen und RLS-Policies
- die Dokumentformate `RaumDokument` und `PlanDokument`
- die Dokumentversionen `RAUM_DOKUMENT_VERSION` (3) und
  `PLAN_DOKUMENT_VERSION` (1)
- die Sitzplatzkennung `<objektId>__sitz_<n>`
- die eingefrorene Raumkopie im Sitzplan (ADR-0003 im Web-Repo)
- `deleted_at` als einziger Löschmechanismus
- die Möbelmaße aus `FURNITURE_SPECS` und die Rasterrechnung in Zentimetern
- tolerantes Lesen alter Dokumente, strenges Schreiben aktueller

Getrennt implementiert, weil plattformeigen:

- Oberfläche, Navigation, Fenster- und Menüstruktur
- Zustandsverwaltung, Undo/Redo, Zeichenschicht
- Druckausgabe und PDF-Erzeugung
- Sitzungsspeicherung und Netzwerkschicht

### Wie Drift verhindert wird

Drei Mittel, in dieser Reihenfolge:

1. **Gemeinsame Contract-Fixtures.** Plattformneutrale JSON-Dateien unter
   `contracts/fixtures/`. Quelle der Wahrheit ist das Web-Repo, weil dort
   Schema, Migrationen und die Referenzimplementierung in TypeScript liegen.
   Dieses Repo hält eine Kopie; die CI vergleicht sie und wird rot, wenn sie
   abweicht. Beide Testsuiten lesen dieselben Dateien.
2. **Beide Seiten prüfen dieselben Fälle.** Was in TypeScript getestet ist —
   tolerantes Lesen, `seatId`, Rasterrundung, Soft-Delete-Filter — ist auch in
   Swift getestet, gegen dieselbe Fixture.
3. **Schemaänderungen laufen über Migrationen im Web-Repo.** Der macOS-Client
   folgt, er führt nicht. Eine Migration, die beide Clients betrifft, wird in
   beiden Repos in derselben Woche nachgezogen.

### Plattformbasis

| Punkt | Festlegung |
| --- | --- |
| Deployment Target | macOS 14 |
| Sprache | Swift 6, Swift-6-Sprachmodus, strict concurrency |
| Oberfläche | SwiftUI, `@Observable`, `async/await`, Actors |
| Unit-Tests | Swift Testing |
| UI-Tests | XCUITest |
| Lokale Toolchain | Xcode 27 Beta — **nur Werkzeug**, nicht Grundlage |
| Verbindliche Toolchain | CI auf stabilem Runner mit Xcode 26 |

Zur letzten Zeile: Auf dem Entwicklungsrechner liegt derzeit ausschließlich
Xcode 27 (Build 27A5194q) auf macOS 27, beides Beta. Beta-SDKs sind als
Projektgrundlage ausgeschlossen. Aufgelöst wird das über das Deployment Target
und die CI: Gebaut wird gegen macOS 14, und verbindlich grün ist der Lauf auf
dem stabilen CI-Runner, nicht der lokale Build. Weicht der lokale Build ab,
gewinnt die CI.

macOS 14 ist bewusst konservativ. Die Zielgruppe sind Schulrechner, nicht
Entwicklungsmaschinen. APIs, die mehr verlangen, werden über `@available`
abgesichert oder nicht verwendet.

### Offline

Der erste Meilenstein behauptet keine Offline-Fähigkeit. Supabase ist die
Quelle der Wahrheit; ohne Netz ist die Anwendung lesend auf das beschränkt, was
geladen ist, und schreibend blockiert.

Was stattdessen gebaut wird, sind ehrliche Zustände: geladen, lokale Änderungen,
speichert, gespeichert, Netzwerkfehler, Serverkonflikt, erneut versuchbar. Eine
Änderung darf nie still verworfen werden.

Später ergänzbar ist ein lokaler Zwischenspeicher, der die geladenen Dokumente
hält und Schreibvorgänge in eine Warteschlange legt. Voraussetzung dafür ist
eine geklärte Konfliktstrategie, und die braucht ein eigenes ADR. Bis dahin gilt
optimistisches Sperren über `updated_at` (siehe `docs/datenvertrag.md`).

## Folgen

**Gut.** Druck, Tastatur, Fokus und Undo kommen vom Betriebssystem statt aus
nachgebautem Browserverhalten. Genau die Stellen, an denen der Web-Client am
meisten Aufwand trägt.

**Gut.** Das Schema bleibt unangetastet. Der neue Client ist additiv; fällt er
weg, ändert sich für den Web-Client nichts.

**Gut.** Getrennte Repositories halten Lovable von Xcode-Dateien fern und
erlauben getrennte Freigabezyklen.

**Teuer.** Zwei Implementierungen derselben Fachlogik. Rasterrundung,
`seatId`-Bau und -Zerlegung, tolerantes Dokumentlesen und die Regelprüfung
existieren künftig zweimal. Die Contract-Fixtures machen daraus einen prüfbaren
Zustand, aber sie beseitigen die Doppelung nicht.

**Teuer.** Zwei Repositories können auseinanderlaufen. Ein Schemawechsel, der
nur im Web-Repo nachgezogen wird, fällt erst auf, wenn ein Mac-Nutzer etwas
Falsches sieht. Die Fixture-Prüfung in der CI ist die einzige Sicherung, und sie
greift nur, wenn sie eingerichtet bleibt.

**Teuer.** Der Zeicheneditor ist der Kern des Produkts und wird zweimal gebaut.
Er ist deshalb in Schichten zerlegt (Dokument, Geometrie, Hit-Testing, Auswahl,
Drag, Snapping, Undo, Rendering, Persistenz, Konfliktprüfung), von denen die
unteren ohne Oberfläche testbar sind.

**Überraschend.** Das Designsystem des Web-Clients schließt Dark Mode
ausdrücklich aus. Auf macOS ist das ungewohnt und muss in der App bewusst
gesetzt werden, sonst erbt sie das Systemverhalten. Bis das Designsystem etwas
anderes sagt, gilt der Ausschluss auch hier.

**Offen.** Signierung, Notarisierung und Auslieferung sind nicht entschieden.
Der erste Meilenstein liefert einen reproduzierbaren Entwicklungsbuild, sonst
nichts. Alles Weitere braucht ein eigenes ADR.

## Verworfen

*WebView um die bestehende App.* In einer Woche fertig und erledigt genau den
Grund, aus dem der Client existiert. Druck, Undo und Tastatur blieben nachgebaut.

*Mac Catalyst.* Setzt eine iPad-App voraus, die es nicht gibt, und liefert auf
dem Mac erkennbar fremde Bedienmuster.

*Eigenes Backend für den Mac-Client.* Zweites Schema, zweite Autorisierung,
zweite Wahrheit. Der sicherste Weg, Schülerdaten auseinanderlaufen zu lassen.

*Gemeinsames Monorepo mit `apps/web` und `apps/macos`.* Löst das Drift-Problem
am elegantesten, kollidiert aber mit dem bidirektionalen Lovable-Sync auf `main`
und verlangt eine Umstrukturierung des laufenden Web-Repos. Bleibt möglich, wenn
Lovable wegfällt — dann mit eigenem ADR, eigenem Issue und eigenem Pull Request.

*Code-Sharing über eine gemeinsame Sprache.* Weder ein TypeScript-Kern in einer
JavaScript-Laufzeit noch ein Swift-Kern für den Browser trägt den Aufwand für
die Menge an Fachlogik, um die es hier geht. Gemeinsam sind die Verträge, nicht
der Code.
