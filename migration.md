
# Migrationsplan: Räume, 2D-Editor, 3D-Ansicht

Stand: 2026-08-07
Quelle: `/Volumes/T7/Projekte/sitzplan_app` (nur Lesequelle, keine Änderungen dort)

---

## Ziel

Räume anlegen, Möbel im 2D-Canvas platzieren, Raum in 3D betrachten —
komplett lokal, kein Netz, kein Konto.

---

## Was bereits da ist (muss nicht gebaut werden)

| Schicht                                                          | Vorhanden                                |
| ---------------------------------------------------------------- | ---------------------------------------- |
| Domain:`Raum`, `Raumobjekt`, `Sitzplatz`, `RaumDokument` | ✅`Modelle.swift`, `Dokumente.swift` |
| Domain:`Moebeltyp`, `Moebelmasse`, `Drehung`               | ✅`Moebel.swift`                       |
| Domain:`Raster.runden()` (JS-Semantik)                         | ✅`Raster.swift`                       |
| Domain:`Sitzplatzkennung.bauen/zerlegen`                       | ✅`Sitzplatzkennung.swift`             |
| Domain:`RaumRepository`-Protokoll                              | ✅`Repositories.swift`                 |
| Domain:`Raum.pruefeMasse()`                                    | ✅`Fehler.swift`                       |
| SwiftData-Modell:`RaumEintrag`                                 | ✅`Modelle.swift` (Speicher)           |
| Abbildung`RaumEintrag → Raum`                                 | ✅`Abbildung.swift`                    |
| Schema V1 enthält`RaumEintrag`                                | ✅`Schemaversionen.swift`              |

---

## Was fehlt (Reihenfolge ist Abhängigkeitsreihenfolge)

### Schritt 1 — `Moebeltyp.beschriftung` (SitzplanKern)

**Datei:** `SitzplanKern/Sources/Domain/Moebel.swift`
**Änderung:** `beschriftung: String` zur bestehenden Extension hinzufügen.

```
case .einzeltisch: "Einzeltisch"
case .doppeltisch: "Doppeltisch"
case .pult:        "Lehrerpult"
case .tafel:       "Tafel"
case .tuer:        "Tür"
case .fenster:     "Fenster"
```

Kein Breaking Change, kein Test nötig (Reinwert, keine Logik).

---

### Schritt 2 — `RaumSpeicher` (SitzplanSpeicher)

**Datei:** `SitzplanSpeicher/Sources/Speicher/RaumSpeicher.swift` (neu)
**Muster:** identisch zu `KlassenSpeicher`, nur für `RaumEintrag`.

Methoden laut `RaumRepository`-Protokoll:

- `aktive()` — `geloeschtAm == nil`, sortiert nach `name`
- `raum(id:)` — auch gelöschte
- `anlegen(_:)` — fügt `RaumEintrag` ein, speichert
- `aktualisieren(_:)` — updated Felder + `geaendertAm`, speichert
- `loeschen(id:)` — setzt `geloeschtAm = Date()`
- `wiederherstellen(id:)` — löscht `geloeschtAm`

Validierung: `Raum.pruefeMasse()` vor `anlegen` aufrufen.

---

### Schritt 3 — `AppEnvironment` erweitern

**Datei:** `SitzplanStudio/SitzplanStudio/App/AppEnvironment.swift`

```swift
public let raeume: any RaumRepository
```

Init-Parameter ergänzen.

---

### Schritt 4 — `SitzplanStudioApp` anpassen

**Datei:** `SitzplanStudio/SitzplanStudio/App/SitzplanStudioApp.swift`

- `RaumSpeicher(modelContainer: container)` zu `AppEnvironment` reichen
- Mindestbreite von 720 → 900 (Raum-Editor braucht mehr Platz)
- Wurzelansicht von `KlassenListe` → `HauptAnsicht`

---

### Schritt 5 — `HauptAnsicht` (Navigation)

**Datei:** `SitzplanStudio/SitzplanStudio/App/HauptAnsicht.swift` (neu)

Äußerer `NavigationSplitView` (schmale Seitenleiste, ~170 px):

```
Seitenleiste          Detail
─────────────         ──────────────────────────────
▶ Klassen        →    KlassenListe (eigener 2-Spalter)
  Räume          →    RaeumeUebersicht (eigener 2-Spalter)
```

Zustand: `@State private var abschnitt: Abschnitt? = .klassen`

`AppCommands` bleibt unberührt (Notification `.neueKlasse` funktioniert weiter).

---

### Schritt 6 — `RaumModell` (ViewModel)

**Datei:** `SitzplanStudio/SitzplanStudio/Features/Raeume/RaumModell.swift` (neu)
**Muster:** identisch zu `KlassenModell`.

Methoden:

- `laden()` → `repository.aktive()`
- `anlegen(name:breiteCm:laengeCm:) -> Raum?`
- `aktualisieren(_:) -> Bool`
- `loeschen(_:)`

Kein Papierkorb in dieser Iteration (Räume sind selten, kein Soft-Delete-UI nötig).

---

### Schritt 7 — `RaumBearbeiten` (Sheet)

**Datei:** `SitzplanStudio/SitzplanStudio/Features/Raeume/RaumBearbeiten.swift` (neu)

Sheet für:

- Name (TextField, max 80 Zeichen)
- Breite in cm (Double, Schritte 25, min 100)
- Länge in cm (Double, Schritte 25, min 100)
- Raster in cm (25 vorausgefüllt, selten geändert)

Validierung beim Absenden: `Raum.pruefeMasse()` aufrufen, Fehler inline zeigen.

---

### Schritt 8 — `RaeumeUebersicht` (Liste + Editor)

**Datei:** `SitzplanStudio/SitzplanStudio/Features/Raeume/RaeumeUebersicht.swift` (neu)

`NavigationSplitView`:

- Seitenleiste: Liste der Räume, Kontextmenü (Bearbeiten…, Löschen), ⌘N-Button
- Detail: `RaumEditor` für den gewählten Raum (`.id(raum.id)` erzwingt Reset)

Leerzustand: LeerHinweis mit „Neuen Raum anlegen"-Aktion.

---

### Schritt 9 — `RaumEditor` (2D Canvas)

**Datei:** `SitzplanStudio/SitzplanStudio/Features/Raeume/RaumEditor.swift` (neu)

#### Koordinatensystem

```
Bildschirm-Ursprung: linke obere Ecke des Canvas
Raumursprung im Canvas: zentriert mit 20 px Polster
Maßstab: min((canvas.width-40)/breiteCm, (canvas.height-40)/laengeCm)
Einheit: Zentimeter → Pixel über Maßstab
```

#### Rendering (SwiftUI `Canvas`)

Reihenfolge (untere Ebene zuerst):

1. Hintergrund (grau)
2. Raumrechteck (weiß, grauer Rand)
3. Rasterlinien (hellgrau, jede `rasterCm * maßstab` px)
4. Möbelrechtecke (gedreht um Möbelmittelpunkt, Farbe je Typ)
5. Sitzkennzeichnung (kleines Quadrat, mittig je Sitzplatz)
6. Auswahlrahmen (blauer Rand, 2 px)

#### Interaktion

| Geste                     | Aktion                                                 |
| ------------------------- | ------------------------------------------------------ |
| Tipp auf Möbel           | Auswählen (`ausgewaehlt = objektId`)                |
| Tipp auf Leerfläche      | Auswahl aufheben                                       |
| Drag auf Möbel           | Verschieben + Raster-Snap, Autosave beim Ende          |
| Toolbar: Möbel-Menü     | Möbel in Raummitte einfügen + Sitzplätze generieren |
| Toolbar: Drehen           | Drehung +90° (zyklisch), Autosave                     |
| Toolbar: Entfernen        | Möbel + zugehörige Sitzplätze löschen, Autosave    |
| Toolbar: 2D/3D-Umschalter | Wechsel zu`RaumEditor3D`                             |

#### Möbel einfügen

```swift
let objektId = UUID().uuidString
let xCm = Raster.runden(raum.breiteCm / 2 - typ.breiteCm / 2, raster: raum.rasterCm)
let yCm = Raster.runden(raum.laengeCm / 2 - typ.tiefeCm / 2, raster: raum.rasterCm)
let objekt = Raumobjekt(id: objektId, typ: typ, xCm: xCm, yCm: yCm)
let sitzplaetze = typ.sitzplaetze(objektId: objektId)
raum.dokument.objekte.append(objekt)
raum.dokument.sitzplaetze.append(contentsOf: sitzplaetze)
```

#### Farben je Moebeltyp

| Typ                       | Farbe                    |
| ------------------------- | ------------------------ |
| einzeltisch / doppeltisch | Holzbeige`#C8A96E`     |
| pult                      | Dunkelholz`#8B6914`    |
| tafel                     | Schiefergrün`#2D5A3D` |
| tuer                      | Beige`#D4C5A9`         |
| fenster                   | Hellblau`#87CEEB`      |

#### Hit-Test bei Rotation

Tippunkt in lokales Koordinatensystem des Möbels transformieren:

```swift
let θ = -objekt.drehung.gradAlsDouble * .pi / 180
let dx = tap.x - mittelpunkt.x
let dy = tap.y - mittelpunkt.y
let lokalX = dx * cos(θ) - dy * sin(θ)
let lokalY = dx * sin(θ) + dy * cos(θ)
return abs(lokalX) <= breite/2 && abs(lokalY) <= tiefe/2
```

---

### Schritt 10 — `RaumEditor3D` (SceneKit)

**Datei:** `SitzplanStudio/SitzplanStudio/Features/Raeume/RaumEditor3D.swift` (neu)

#### Koordinatenabbildung 2D → 3D

```
SceneKit-X = xCm + breiteMoebel/2 - raumBreite/2   (Raumbreite-Achse)
SceneKit-Y = höheMoebel / 2                          (hoch)
SceneKit-Z = yCm + tiefeMoebel/2 - raumLaenge/2     (Raumtiefe-Achse)
Einheit: Zentimeter (keine Konvertierung, SceneKit ist einheitenfrei)
```

Drehung: `SCNNode.eulerAngles.y = -drehungGrad * .pi / 180`

#### Szenenaufbau

```
SCNScene
├── Beleuchtung: 1× ambient (Intensität 400) + 1× directional (Intensität 800)
├── Boden: SCNBox(w=breite, h=2, l=laenge), y=-1, Material hellgrau
├── 4 Wände: SCNBox(Stärke 10), halbdurchsichtig weiß (opacity 0.6)
│            Höhe: 300 cm (Raumhöhe fest)
└── Möbelknoten (je Raumobjekt):
    ├── Tisch/Doppeltisch: SCNBox(breite, 75, tiefe), y=37.5, Holzfarbe
    ├── Pult: SCNBox(160, 90, 80), y=45, Dunkelholz
    ├── Tafel: SCNBox(400, 120, 15), y=150 (Mitte 90+60), Schiefergrün
    ├── Tür: SCNBox(90, 205, 20), y=102.5, Beige
    └── Fenster: SCNBox(15, 120, 180), y=150, Hellblau transparent
```

#### Kamera

`SceneView(scene:, options: [.allowsCameraControl, .autoenablesDefaultLighting])`

Startposition:

```swift
let kamera = SCNCamera()
kamera.fieldOfView = 50
kameraKnoten.position = SCNVector3(0, Float(raum.laengeCm * 0.8), Float(raum.laengeCm * 1.0))
kameraKnoten.look(at: SCNVector3(0, 0, 0))
```

#### Studentenfiguren (Phase 2, nicht in dieser Iteration)

Einfache Geometrie (analog web app, Three.js → SceneKit):

- Rumpf: `SCNBox(18, 35, 12)`, Farbe = `schuelerFarben[farbIndex]`
- Kopf: `SCNSphere(r=6)`
- Beine: `SCNCylinder(r=3, h=16)` × 2

Werden nur gezeichnet, wenn `Sitzplan.zuordnungen` vorliegen.
**Noch nicht gebaut** — Sitzplan-Feature kommt nach den Räumen.

---

### Schritt 11 — Möbelfarben als `Color`-Extension

**Datei:** `SitzplanStudio/SitzplanStudio/Gestaltung/Farben.swift`
**Änderung:** `static func fuerMoebeltyp(_ typ: Moebeltyp) -> Color` hinzufügen.

---

## Nicht in diesem Plan

- Sitzplan-Editor (kommt nach Räumen)
- Studentenfiguren in 3D (Phase 2, s. Schritt 10)
- Papierkorb für Räume
- PDF-/Druckexport
- KI-Integration

---

## Reihenfolge der Implementierung

```
1. Moebeltyp.beschriftung          (SitzplanKern)
2. RaumSpeicher                    (SitzplanSpeicher)
3. AppEnvironment + App            (SitzplanStudio/App)
4. HauptAnsicht                    (SitzplanStudio/App)
5. RaumModell                      (Features/Raeume)
6. RaumBearbeiten                  (Features/Raeume)
7. Farben erweitern                (Gestaltung)
8. RaumEditor (2D)                 (Features/Raeume)
9. RaumEditor3D (SceneKit)        (Features/Raeume)
10. RaeumeUebersicht               (Features/Raeume)
```

Build-Check nach jedem Schritt mit `XcodeRefreshCodeIssuesInFile`.
Vollbuild am Ende mit `BuildProject`.

---

## Offene Fragen / Risiken

| Frage                                                                      | Einschätzung                                                                      |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Nested NavigationSplitView (HauptAnsicht → KlassenListe/RaeumeUebersicht) | Funktioniert auf macOS — jede innere Split-View expandiert in ihren Detailbereich |
| SceneKit vs. RealityKit                                                    | SceneKit gewählt: stabiler, kein AR-Overhead,`SceneView` direkt in SwiftUI      |
| Canvas-Performance bei vielen Möbeln                                      | Unkritisch — Klassenzimmer haben max. 35 Tische                                   |
| Drehung beim Verschieben: Boundary-Clamp                                   | Zunächst kein Clamp (wie Web-App), kann nachgerüstet werden                      |
