import Domain
import Fixtures
import Foundation
import Testing

@testable import Datenvertrag

/// Tolerantes Lesen. Diese Rueckfallwerte sind Vertrag, nicht Zufall.
///
/// Jeder Fall stammt aus `plan-dokument-alt-unvollstaendig.json` und ist dort
/// mit Erwartungswerten hinterlegt.
@Suite("Toleranzen beim Lesen")
struct ToleranzTests {

    private static func fall(_ teil: String) throws -> [String: Any] {
        let json = try Fixtures.json(.planDokumentAltUnvollstaendig)
        let faelle = try #require(json["faelle"] as? [[String: Any]])
        return try #require(
            faelle.first { ($0["name"] as? String)?.contains(teil) == true },
            "Fixture-Fall mit '\(teil)' fehlt"
        )
    }

    private static func gelesen(_ fall: [String: Any]) throws -> PlanDokument {
        let eingabe = fall["eingabe"]
        // `null` und ein fehlender Schluessel muessen beide zum leeren Dokument
        // fuehren — nicht zu einem Fehler.
        guard let eingabe, !(eingabe is NSNull) else {
            return Dokumentlesen.planDokument(aus: Data("null".utf8))
        }
        return Dokumentlesen.planDokument(aus: try JSONSerialization.data(withJSONObject: eingabe))
    }

    @Test("Ein leeres Objekt ergibt die Rueckfallgeometrie")
    func leeresObjekt() throws {
        let fall = try Self.fall("leeres Objekt")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        #expect(dokument.raumGeometrie.breiteCm == (erwartet["breiteCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.laengeCm == (erwartet["laengeCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.rasterCm == (erwartet["rasterCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.objekte.count == (erwartet["anzahlObjekte"] as? Int))
        #expect(dokument.zuordnungen.count == (erwartet["anzahlZuordnungen"] as? Int))
    }

    @Test("null ergibt dieselbe Rueckfallgeometrie wie ein leeres Objekt")
    func nullEingabe() throws {
        let fall = try Self.fall("null")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        #expect(dokument.raumGeometrie.breiteCm == (erwartet["breiteCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.rasterCm == (erwartet["rasterCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.zuordnungen.isEmpty)
    }

    @Test("Fehlt die Raumgeometrie, bleiben die Zuordnungen trotzdem erhalten")
    func geometrieFehltZuordnungenBleiben() throws {
        let fall = try Self.fall("raumGeometrie fehlt")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        #expect(dokument.raumGeometrie.breiteCm == 800)
        #expect(dokument.raumGeometrie.rasterCm == 10)
        #expect(dokument.zuordnungen.count == (erwartet["anzahlZuordnungen"] as? Int))
        #expect(dokument.zuordnungen.count == 1,
                "Eine Zuordnung ins Leere bleibt stehen — sie wegzuwerfen waere Datenverlust")
        #expect(dokument.belegteSitzplatzIds.isEmpty,
                "Gezaehlt wird sie aber nicht, denn den Platz gibt es nicht")
    }

    @Test("Ein unbekannter Moebeltyp wird zum Einzeltisch")
    func unbekannterTyp() throws {
        let fall = try Self.fall("unbekannter Moebeltyp")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        let objekt = try #require(dokument.raumGeometrie.objekte.first)
        #expect(objekt.typ == .einzeltisch)
        #expect(String(describing: objekt.typ) == (erwartet["kind"] as? String))
        #expect(objekt.breiteCm == (erwartet["breiteBeimSchreiben"] as? NSNumber)?.doubleValue)
        #expect(objekt.tiefeCm == (erwartet["tiefeBeimSchreiben"] as? NSNumber)?.doubleValue)
        #expect(objekt.breiteCm == 60, "999 aus dem Dokument darf nicht ueberleben")
    }

    @Test("Eine ungueltige Drehung wird 0")
    func ungueltigeDrehung() throws {
        let fall = try Self.fall("ungueltige Drehung")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        let objekt = try #require(dokument.raumGeometrie.objekte.first)
        #expect(objekt.drehung.grad == (erwartet["rotation"] as? Int))
        #expect(objekt.drehung == .null)

        for gueltig in [0, 90, 180, 270] {
            #expect(Drehung(grad: gueltig).grad == gueltig)
        }
        for ungueltig in [45, -90, 360, 1] {
            #expect(Drehung(grad: ungueltig) == .null)
        }
    }

    @Test("Fehlende Koordinaten werden 0")
    func fehlendeKoordinaten() throws {
        let fall = try Self.fall("fehlende Koordinaten")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        let objekt = try #require(dokument.raumGeometrie.objekte.first)
        #expect(objekt.xCm == (erwartet["x"] as? NSNumber)?.doubleValue)
        #expect(objekt.yCm == (erwartet["y"] as? NSNumber)?.doubleValue)
    }

    @Test("Masse 0 bleiben 0, ein fehlendes Raster wird 10")
    func masseNull() throws {
        let fall = try Self.fall("Masse null")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        // Wichtig: Hier gilt 0, nicht die Rueckfallgeometrie 800 × 600. Der
        // Unterschied ist, ob `raumGeometrie` ganz fehlt oder nur ein Feld darin.
        #expect(dokument.raumGeometrie.breiteCm == (erwartet["breiteCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.breiteCm == 0)
        #expect(dokument.raumGeometrie.laengeCm == 0)
        #expect(dokument.raumGeometrie.rasterCm == (erwartet["rasterCm"] as? NSNumber)?.doubleValue)
        #expect(dokument.raumGeometrie.rasterCm == 10)
    }

    @Test("Steht statt eines Arrays etwas anderes, ist die Liste leer")
    func keinArray() throws {
        let fall = try Self.fall("kein Array")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        #expect(dokument.raumGeometrie.objekte.count == (erwartet["anzahlObjekte"] as? Int))
        #expect(dokument.raumGeometrie.objekte.isEmpty)
        #expect(dokument.raumGeometrie.sitzplaetze.isEmpty, "null muss ebenfalls leer ergeben")
    }

    @Test("Bei doppelter Zuordnung gewinnt der letzte Eintrag")
    func doppelteZuordnung() throws {
        let fall = try Self.fall("doppelte Zuordnung")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        // Die Liste behaelt beide Eintraege — das Woerterbuch wird daraus
        // abgeleitet, nicht umgekehrt.
        #expect(dokument.zuordnungen.count == 2, "Die geordnete Liste behaelt beide")

        let woerterbuch = dokument.zuordnungenAlsWoerterbuch()
        #expect(woerterbuch.count == (erwartet["anzahlZuordnungen"] as? Int))
        #expect(woerterbuch.values.first == (erwartet["gewinner"] as? String))
    }

    @Test("Unbekannte Zusatzfelder werden uebergangen, nicht bemaengelt")
    func unbekannteFelder() throws {
        let fall = try Self.fall("unbekannte Zusatzfelder")
        let dokument = try Self.gelesen(fall)
        let erwartet = try #require(fall["erwartet"] as? [String: Any])

        #expect(dokument.raumGeometrie.objekte.count == (erwartet["anzahlObjekte"] as? Int))
        let objekt = try #require(dokument.raumGeometrie.objekte.first)
        #expect(objekt.xCm == 5)
        #expect(objekt.typ == .einzeltisch)
    }

    @Test("Voelliger Unsinn ergibt das leere Dokument statt eines Absturzes")
    func unsinn() {
        for eingabe in ["", "[]", "\"text\"", "42", "{", "null", "{\"objekte\":42}"] {
            let raum = Dokumentlesen.raumDokument(aus: Data(eingabe.utf8))
            #expect(raum.objekte.isEmpty, "RaumDokument aus: \(eingabe)")

            let plan = Dokumentlesen.planDokument(aus: Data(eingabe.utf8))
            #expect(plan.zuordnungen.isEmpty, "PlanDokument aus: \(eingabe)")
        }
    }

    @Test("Ein einzelnes kaputtes Listenelement kippt nicht die ganze Liste")
    func kaputtesElement() {
        let roh = """
        {"objekte":[
          {"id":"t1","typ":"table_single","x_cm":1,"y_cm":2,"rotation_deg":0},
          "kaputt",
          {"id":"t2","typ":"table_double","x_cm":3,"y_cm":4,"rotation_deg":90}
        ],"sitzplaetze":[]}
        """
        let dokument = Dokumentlesen.raumDokument(aus: Data(roh.utf8))
        #expect(dokument.objekte.count == 2, "Die beiden lesbaren Objekte bleiben erhalten")
        #expect(dokument.objekte.map(\.id) == ["t1", "t2"])
    }
}
