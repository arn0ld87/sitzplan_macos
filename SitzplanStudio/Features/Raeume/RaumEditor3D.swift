import AppKit
import Domain
import SceneKit
import SwiftUI

/// 3D-Ansicht des Raums — SceneKit, einheitenfrei (Zentimeter).
///
/// Koordinatenabbildung (Ursprung Raummitte, Fußboden y = 0):
///   X = xCm + breiteMoebel/2 - raumBreite/2   (nach rechts)
///   Y = höheMoebel / 2                          (nach oben)
///   Z = yCm + tiefeMoebel/2 - raumLaenge/2     (nach hinten)
/// Drehung um die Y-Achse, negiert — SVG dreht im Uhrzeigersinn, SceneKit-Y gegen
/// den Uhrzeigersinn (siehe Web-Client `room3d/geometrie.ts`).
struct RaumEditor3D: View {
    let raum: Raum
    let zeige2D: () -> Void

    @State private var szeneCache: SCNScene?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let szeneCache {
                SceneView(
                    scene: szeneCache,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .accessibilityLabel("3D-Ansicht von \(raum.name), \(raum.dokument.objekte.count) Möbel")
                .accessibilityHint("Mit der Maus drehen und zoomen.")
            } else {
                ProgressView().accessibilityLabel("3D-Ansicht wird aufgebaut")
            }
        }
        // Szene einmal bauen und cachen — body kann mehrfach aufgerufen werden,
        // ein erneuter Szenenaufbau bei jedem Redraw ist unnütz. `raum` ist
        // unveränderlich; bei Raumwechsel wird die View per `.id` neu erzeugt.
        .task {
            if szeneCache == nil { szeneCache = szene() }
        }
        .ohneDarkMode()
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Spacer()
            Button { zeige2D() } label: {
                Label("2D-Editor", systemImage: "rectangle.group")
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    // MARK: Szene

    private func szene() -> SCNScene {
        let szene = SCNScene()
        szene.background.contents = NSColor.windowBackgroundColor

        // Beleuchtung: ambient + directional.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        szene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 800
        szene.rootNode.addChildNode(directional)

        // Boden.
        let boden = SCNBox(
            width: CGFloat(raum.breiteCm),
            height: 2,
            length: CGFloat(raum.laengeCm),
            chamferRadius: 0
        )
        boden.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.85, alpha: 1)
        let bodenKnoten = SCNNode(geometry: boden)
        bodenKnoten.position = SCNVector3(0, -1, 0)
        szene.rootNode.addChildNode(bodenKnoten)

        // Wände (halbdurchsichtig).
        fuegeWaenderHinzu(in: szene)

        // Möbel.
        for objekt in raum.dokument.objekte {
            szene.rootNode.addChildNode(moebelKnoten(objekt))
        }

        // Kamera.
        let kamera = SCNCamera()
        kamera.fieldOfView = 50
        let kameraKnoten = SCNNode()
        kameraKnoten.camera = kamera
        kameraKnoten.position = SCNVector3(0, Float(raum.laengeCm) * 0.8, Float(raum.laengeCm) * 1.0)
        kameraKnoten.look(at: SCNVector3(0, 0, 0))
        szene.rootNode.addChildNode(kameraKnoten)

        return szene
    }

    private func fuegeWaenderHinzu(in szene: SCNScene) {
        let hoehe: CGFloat = 300
        let staerke: CGFloat = 10
        let breite = CGFloat(raum.breiteCm)
        let laenge = CGFloat(raum.laengeCm)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white.withAlphaComponent(0.6)
        material.transparency = 0.6

        func wand(_ box: SCNBox, _ position: SCNVector3) {
            box.materials = [material]
            let knoten = SCNNode(geometry: box)
            knoten.position = position
            szene.rootNode.addChildNode(knoten)
        }

        // Nordwand (hinten, -Z).
        wand(
            SCNBox(width: breite, height: hoehe, length: staerke, chamferRadius: 0),
            SCNVector3(0, Float(hoehe / 2), Float(-laenge / 2 - staerke / 2))
        )
        // Südwand (vorne, +Z).
        wand(
            SCNBox(width: breite, height: hoehe, length: staerke, chamferRadius: 0),
            SCNVector3(0, Float(hoehe / 2), Float(laenge / 2 + staerke / 2))
        )
        // Westwand (links, -X).
        wand(
            SCNBox(width: staerke, height: hoehe, length: laenge, chamferRadius: 0),
            SCNVector3(Float(-breite / 2 - staerke / 2), Float(hoehe / 2), 0)
        )
        // Ostwand (rechts, +X).
        wand(
            SCNBox(width: staerke, height: hoehe, length: laenge, chamferRadius: 0),
            SCNVector3(Float(breite / 2 + staerke / 2), Float(hoehe / 2), 0)
        )
    }

    // MARK: Möbel

    /// Aufbauhöhe je Möbelart in cm (Kommt aus migration.md, nicht aus der
    /// Möbeltabelle — die kennt nur Breite und Tiefe).
    private func hoeheFuer(_ typ: Moebeltyp) -> CGFloat {
        switch typ {
        case .einzeltisch, .doppeltisch: 75
        case .pult: 90
        case .tafel: 120
        case .tuer: 205
        case .fenster: 120
        }
    }

    /// Y-Position des Möbelmittelpunkts. Bodenstehende Möbel stehen auf dem
    /// Boden (Mitte = Höhe/2), Tafel und Fenster sind wandmontiert (Mitte bei
    /// 150 cm) — sie stehen nicht auf dem Boden.
    private func yPositionFuer(_ typ: Moebeltyp) -> CGFloat {
        switch typ {
        case .tafel, .fenster:
            // Wandmontage — unabhängig von der Möbelhöhe.
            150
        default:
            hoeheFuer(typ) / 2
        }
    }

    private func materialFuer(_ typ: Moebeltyp) -> SCNMaterial {
        let material = SCNMaterial()
        var farbe = NSColor(Farbe.fuerMoebeltyp(typ))
        if typ == .fenster {
            farbe = farbe.withAlphaComponent(0.5)
            material.transparency = 0.5
        }
        material.diffuse.contents = farbe
        return material
    }

    private func moebelKnoten(_ objekt: Raumobjekt) -> SCNNode {
        let box = SCNBox(
            width: CGFloat(objekt.breiteCm),
            height: hoeheFuer(objekt.typ),
            length: CGFloat(objekt.tiefeCm),
            chamferRadius: 0
        )
        box.materials = [materialFuer(objekt.typ)]
        let knoten = SCNNode(geometry: box)
        let x = Float(objekt.xCm + objekt.breiteCm / 2 - raum.breiteCm / 2)
        let y = Float(yPositionFuer(objekt.typ))
        let z = Float(objekt.yCm + objekt.tiefeCm / 2 - raum.laengeCm / 2)
        knoten.position = SCNVector3(x, y, z)
        knoten.eulerAngles.y = -CGFloat(objekt.drehung.grad) * .pi / 180
        return knoten
    }
}