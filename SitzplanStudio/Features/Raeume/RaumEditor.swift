import Domain
import SwiftUI

/// 2D-Grundriss-Editor — Möbel platzieren, drehen, verschieben.
///
/// Canvas-Ursprung: linke obere Ecke. Der Raum liegt zentriert mit 20 px Polster.
/// Maßstab: so, dass der Raum ins Canvas passt —
/// `min((breite-40)/raumbreite, (hoehe-40)/raumlaenge)`.
///
/// Möbelkoordinaten `xCm/yCm` sind die **linke obere Ecke** des Möbels;
/// Sitzplätze liegen in Möbel-Lokalkoordinaten (Ursprung ebenfalls linke obere Ecke).
/// Die Drehung erfolgt um den Möbelmittelpunkt; der Hit-Test transformiert den
/// Tippunkt ins lokale, ungedrehte System des Möbels (`docs/datenvertrag.md`).
struct RaumEditor: View {
    let raum: Raum
    let sichern: (Raum) async -> Bool
    let zeige3D: () -> Void

    @State private var arbeitsRaum: Raum
    @State private var ausgewaehlt: String?
    @State private var drag: DragZustand?
    @State private var hatBewegt = false
    @State private var speichert = false
    @State private var schmutzig = false

    init(
        raum: Raum,
        sichern: @escaping (Raum) async -> Bool,
        zeige3D: @escaping () -> Void
    ) {
        self.raum = raum
        self.sichern = sichern
        self.zeige3D = zeige3D
        _arbeitsRaum = State(initialValue: raum)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            GeometryReader { geo in
                let mas = massstab(in: geo.size)
                let off = offset(in: geo.size, massstab: mas)
                Canvas { context, _ in
                    zeichne(in: &context, groesse: geo.size, massstab: mas, offset: off)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { wert in
                            handelDrag(wert: wert, massstab: mas, offset: off)
                        }
                        .onEnded { _ in
                            beendeDrag()
                        }
                )
            }
        }
        .ohneDarkMode()
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(Moebeltyp.allCases, id: \.self) { typ in
                    Button(typ.beschriftung) { fuegeEin(typ: typ) }
                }
            } label: {
                Label("Möbel", systemImage: "plus.rectangle")
            }
            .disabled(speichert)

            Button { dreheAuswahl() } label: {
                Label("Drehen", systemImage: "rotate.clockwise")
            }
            .disabled(ausgewaehlt == nil || speichert)

            Button(role: .destructive) { entferneAuswahl() } label: {
                Label("Entfernen", systemImage: "trash")
            }
            .disabled(ausgewaehlt == nil || speichert)

            Spacer()

            Button { zeige3D() } label: {
                Label("3D-Ansicht", systemImage: "cube")
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    // MARK: Aktionen

    private func fuegeEin(typ: Moebeltyp) {
        let objektId = UUID().uuidString
        let xCm = Raster.runden(arbeitsRaum.breiteCm / 2 - typ.breiteCm / 2, raster: arbeitsRaum.rasterCm)
        let yCm = Raster.runden(arbeitsRaum.laengeCm / 2 - typ.tiefeCm / 2, raster: arbeitsRaum.rasterCm)
        let objekt = Raumobjekt(id: objektId, typ: typ, xCm: xCm, yCm: yCm)
        let sitzplaetze = typ.sitzplaetze(objektId: objektId)
        arbeitsRaum.dokument.objekte.append(objekt)
        arbeitsRaum.dokument.sitzplaetze.append(contentsOf: sitzplaetze)
        ausgewaehlt = objektId
        autosave()
    }

    private func dreheAuswahl() {
        guard let id = ausgewaehlt,
              let idx = arbeitsRaum.dokument.objekte.firstIndex(where: { $0.id == id }) else { return }
        arbeitsRaum.dokument.objekte[idx].drehung = Drehung(grad: (arbeitsRaum.dokument.objekte[idx].drehung.grad + 90) % 360)
        autosave()
    }

    private func entferneAuswahl() {
        guard let id = ausgewaehlt else { return }
        arbeitsRaum.dokument.objekte.removeAll { $0.id == id }
        arbeitsRaum.dokument.sitzplaetze.removeAll { $0.objektId == id }
        ausgewaehlt = nil
        autosave()
    }

    private func autosave() {
        // Kommt eine weitere Änderung während der Speicherläuft, wird sie nicht
        // verworfen, sondern nachgereicht: `schmutzig` markiert, dass der
        // aktuelle Stand noch ungesichert ist, und das Ende des laufenden Save
        // triggert einen weiteren. Sonst ginge die letzte Position verloren,
        // wenn zügig nacheinander Möbel bewegt werden.
        if speichert { schmutzig = true; return }
        speichert = true
        let zuSichern = arbeitsRaum
        Task {
            _ = await sichern(zuSichern)
            speichert = false
            if schmutzig { schmutzig = false; autosave() }
        }
    }

    // MARK: Drag

    private struct DragZustand {
        let objektId: String
        let dxCm: Double
        let dyCm: Double
    }

    private func handelDrag(wert: DragGesture.Value, massstab: CGFloat, offset: CGPoint) {
        if drag == nil {
            if let id = moebelBei(wert.startLocation, massstab: massstab, offset: offset),
               let objekt = arbeitsRaum.dokument.objekte.first(where: { $0.id == id }) {
                let startCm = canvasZuCm(wert.startLocation, massstab: massstab, offset: offset)
                let mittelpunktCmX = objekt.xCm + objekt.breiteCm / 2
                let mittelpunktCmY = objekt.yCm + objekt.tiefeCm / 2
                drag = DragZustand(
                    objektId: id,
                    dxCm: startCm.x - mittelpunktCmX,
                    dyCm: startCm.y - mittelpunktCmY
                )
                ausgewaehlt = id
            } else {
                // Leerfläche — drag bleibt nil; beim Ende wird die Auswahl aufgehoben.
                drag = nil
            }
        }
        guard let d = drag,
              let idx = arbeitsRaum.dokument.objekte.firstIndex(where: { $0.id == d.objektId }) else { return }
        let tapCm = canvasZuCm(wert.location, massstab: massstab, offset: offset)
        let objekt = arbeitsRaum.dokument.objekte[idx]
        let neuMittelpunktCmX = tapCm.x - d.dxCm
        let neuMittelpunktCmY = tapCm.y - d.dyCm
        let neuXCm = Raster.runden(neuMittelpunktCmX - objekt.breiteCm / 2, raster: arbeitsRaum.rasterCm)
        let neuYCm = Raster.runden(neuMittelpunktCmY - objekt.tiefeCm / 2, raster: arbeitsRaum.rasterCm)
        if arbeitsRaum.dokument.objekte[idx].xCm != neuXCm || arbeitsRaum.dokument.objekte[idx].yCm != neuYCm {
            arbeitsRaum.dokument.objekte[idx].xCm = neuXCm
            arbeitsRaum.dokument.objekte[idx].yCm = neuYCm
            hatBewegt = true
        }
    }

    private func beendeDrag() {
        if hatBewegt {
            autosave()
        } else if drag == nil {
            // Tipp auf Leerfläche → Auswahl aufheben.
            ausgewaehlt = nil
        }
        drag = nil
        hatBewegt = false
    }

    // MARK: Geometrie-Hilfen

    private func massstab(in groesse: CGSize) -> CGFloat {
        let b = max(arbeitsRaum.breiteCm, 1)
        let l = max(arbeitsRaum.laengeCm, 1)
        return min((groesse.width - 40) / b, (groesse.height - 40) / l)
    }

    private func offset(in groesse: CGSize, massstab: CGFloat) -> CGPoint {
        let raumBreitePx = arbeitsRaum.breiteCm * massstab
        let raumHoehePx = arbeitsRaum.laengeCm * massstab
        return CGPoint(
            x: (groesse.width - raumBreitePx) / 2,
            y: (groesse.height - raumHoehePx) / 2
        )
    }

    private func canvasZuCm(_ punkt: CGPoint, massstab: CGFloat, offset: CGPoint) -> CGPoint {
        CGPoint(
            x: (Double(punkt.x) - Double(offset.x)) / Double(massstab),
            y: (Double(punkt.y) - Double(offset.y)) / Double(massstab)
        )
    }

    private func mittelpunktPx(_ objekt: Raumobjekt, massstab: CGFloat, offset: CGPoint) -> CGPoint {
        CGPoint(
            x: offset.x + CGFloat(objekt.xCm + objekt.breiteCm / 2) * massstab,
            y: offset.y + CGFloat(objekt.yCm + objekt.tiefeCm / 2) * massstab
        )
    }

    /// Hit-Test: Tippunkt ins lokale, ungedrehte System des Möbels transformieren.
    /// Oberstes Möbel zuerst (rückwärts über die Objektliste).
    private func moebelBei(_ punkt: CGPoint, massstab: CGFloat, offset: CGPoint) -> String? {
        for objekt in arbeitsRaum.dokument.objekte.reversed() {
            let m = mittelpunktPx(objekt, massstab: massstab, offset: offset)
            let theta = -Double(objekt.drehung.grad) * .pi / 180
            let dx = Double(punkt.x - m.x)
            let dy = Double(punkt.y - m.y)
            let lokalX = dx * cos(theta) - dy * sin(theta)
            let lokalY = dx * sin(theta) + dy * cos(theta)
            let breiteHalbe = Double(objekt.breiteCm) * Double(massstab) / 2
            let tiefeHalbe = Double(objekt.tiefeCm) * Double(massstab) / 2
            if abs(lokalX) <= breiteHalbe && abs(lokalY) <= tiefeHalbe {
                return objekt.id
            }
        }
        return nil
    }

    // MARK: Zeichnung

    private func zeichne(in context: inout GraphicsContext, groesse: CGSize, massstab: CGFloat, offset: CGPoint) {
        // 1. Hintergrund grau.
        context.fill(Path(CGRect(origin: .zero, size: groesse)), with: .color(.gray.opacity(0.12)))

        let raumBreitePx = arbeitsRaum.breiteCm * massstab
        let raumHoehePx = arbeitsRaum.laengeCm * massstab
        let raumRechteck = CGRect(x: offset.x, y: offset.y, width: raumBreitePx, height: raumHoehePx)

        // 2. Raumrechteck: weiß mit grauem Rand.
        context.fill(Path(raumRechteck), with: .color(.white))
        context.stroke(Path(raumRechteck), with: .color(.gray.opacity(0.6)), lineWidth: 1)

        // 3. Rasterlinien.
        let raster = arbeitsRaum.rasterCm
        var cmX = raster
        while cmX < arbeitsRaum.breiteCm {
            let x = offset.x + cmX * massstab
            context.stroke(
                Path(CGRect(x: x, y: offset.y, width: 0, height: raumHoehePx)),
                with: .color(.gray.opacity(0.25)),
                lineWidth: 0.5
            )
            cmX += raster
        }
        var cmY = raster
        while cmY < arbeitsRaum.laengeCm {
            let y = offset.y + cmY * massstab
            context.stroke(
                Path(CGRect(x: offset.x, y: y, width: raumBreitePx, height: 0)),
                with: .color(.gray.opacity(0.25)),
                lineWidth: 0.5
            )
            cmY += raster
        }

        // 4–6. Möbel.
        for objekt in arbeitsRaum.dokument.objekte {
            zeichneMoebel(objekt, in: &context, massstab: massstab, offset: offset)
        }
    }

    private func zeichneMoebel(_ objekt: Raumobjekt, in context: inout GraphicsContext, massstab: CGFloat, offset: CGPoint) {
        let m = mittelpunktPx(objekt, massstab: massstab, offset: offset)
        let breitePx = CGFloat(objekt.breiteCm) * massstab
        let tiefePx = CGFloat(objekt.tiefeCm) * massstab
        let rotation = CGAffineTransform(rotationAngle: -Double(objekt.drehung.grad) * .pi / 180)
        let translation = CGAffineTransform(translationX: m.x, y: m.y)

        // Möbelrechteck um den Ursprung (lokal), dann rotieren + verschieben.
        let rechteck = Path(CGRect(x: -breitePx / 2, y: -tiefePx / 2, width: breitePx, height: tiefePx))
            .applying(rotation)
            .applying(translation)
        context.fill(rechteck, with: .color(Farbe.fuerMoebeltyp(objekt.typ)))
        context.stroke(rechteck, with: .color(.black.opacity(0.25)), lineWidth: 1)

        // 5. Sitzkennzeichnung — kleine Kreise an den Sitzplätzen.
        let sitze = arbeitsRaum.dokument.sitzplaetze.filter { $0.objektId == objekt.id }
        let sitzRadius: CGFloat = max(2, min(breitePx, tiefePx) * 0.08)
        for sitz in sitze {
            let lokalX = CGFloat(sitz.lokalXCm) * massstab - breitePx / 2
            let lokalY = CGFloat(sitz.lokalYCm) * massstab - tiefePx / 2
            let sitzKreis = Path(ellipseIn: CGRect(
                x: lokalX - sitzRadius,
                y: lokalY - sitzRadius,
                width: sitzRadius * 2,
                height: sitzRadius * 2
            ))
            .applying(rotation)
            .applying(translation)
            context.fill(sitzKreis, with: .color(.white.opacity(0.85)))
            context.stroke(sitzKreis, with: .color(.black.opacity(0.4)), lineWidth: 0.8)
        }

        // 6. Auswahlrahmen — blau, 2 px.
        if ausgewaehlt == objekt.id {
            context.stroke(rechteck, with: .color(Farbe.auswahl), lineWidth: 2)
        }
    }
}