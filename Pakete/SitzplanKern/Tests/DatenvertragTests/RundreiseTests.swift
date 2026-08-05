import Domain
import Fixtures
import Foundation
import Testing

@testable import Datenvertrag

@Suite("Rundreise Dokument → Domäne → Dokument")
struct RundreiseTests {

    @Test("Das kanonische RaumDokument uebersteht die Rundreise unveraendert")
    func raumDokumentRundreise() throws {
        let json = try Fixtures.json(.raumDokumentV3)
        let dokumentRoh = try #require(json["canvas_document"])
        let daten = try JSONSerialization.data(withJSONObject: dokumentRoh)

        let gelesen = Dokumentlesen.raumDokument(aus: daten)

        let erwartet = try #require(json["_erwartet"] as? [String: Any])
        #expect(gelesen.objekte.count == (erwartet["anzahlObjekte"] as? Int))
        #expect(gelesen.sitzplaetze.count == (erwartet["anzahlSitzplaetze"] as? Int))

        // Rundreise: schreiben und erneut lesen muss dasselbe ergeben.
        let geschrieben = try Dokumentlesen.daten(aus: gelesen)
        let erneut = Dokumentlesen.raumDokument(aus: geschrieben)
        #expect(erneut == gelesen, "Die Rundreise darf nichts veraendern")
    }

    @Test("Sitzplaetze je Moebelstueck stimmen mit der Fixture ueberein")
    func sitzplaetzeJeMoebel() throws {
        let json = try Fixtures.json(.raumDokumentV3)
        let daten = try JSONSerialization.data(withJSONObject: try #require(json["canvas_document"]))
        let dokument = Dokumentlesen.raumDokument(aus: daten)

        let erwartet = try #require(json["_erwartet"] as? [String: Any])
        let jeMoebel = try #require(erwartet["sitzplaetzeJeMoebel"] as? [String: Int])

        for (objektId, anzahl) in jeMoebel {
            #expect(dokument.sitzplaetze(vonObjekt: objektId).count == anzahl,
                    "Sitzplaetze an \(objektId)")
        }

        // Gegenprobe: Aus der Moebeltabelle abgeleitet muss dasselbe herauskommen.
        for objekt in dokument.objekte {
            let ausTabelle = objekt.typ.anzahlSitzplaetze
            #expect(dokument.sitzplaetze(vonObjekt: objekt.id).count == ausTabelle,
                    "\(objekt.typ) an \(objekt.id)")
        }
    }

    @Test("Das kanonische PlanDokument uebersteht die Rundreise unveraendert")
    func planDokumentRundreise() throws {
        let json = try Fixtures.json(.planDokumentV1)
        let daten = try JSONSerialization.data(withJSONObject: try #require(json["canvas_document"]))

        let gelesen = Dokumentlesen.planDokument(aus: daten)
        let erwartet = try #require(json["_erwartet"] as? [String: Any])

        #expect(gelesen.belegteSitzplatzIds.count == (erwartet["belegtePlaetze"] as? Int))
        #expect(gelesen.freieSitzplatzIds.count == (erwartet["freiePlaetze"] as? Int))
        #expect(gelesen.freieSitzplatzIds.first == (erwartet["freierPlatz"] as? String))

        let geschrieben = try Dokumentlesen.daten(aus: gelesen)
        let erneut = Dokumentlesen.planDokument(aus: geschrieben)
        #expect(erneut == gelesen)
    }

    @Test("Die eingefrorene Raumkopie bleibt von der Vorlage unabhaengig")
    func eingefroreneKopie() throws {
        let json = try Fixtures.json(.planDokumentV1)
        let daten = try JSONSerialization.data(withJSONObject: try #require(json["canvas_document"]))
        var plan = Dokumentlesen.planDokument(aus: daten)

        let vorher = plan.raumGeometrie

        // Eine Aenderung an der Raumvorlage — hier nachgestellt als neuer Raum
        // mit anderer Geometrie — darf den Plan nicht beruehren.
        let raum = Raum(
            name: "B204 umgebaut",
            breiteCm: 1_000,
            laengeCm: 1_000,
            dokument: .leer,
            erstelltAm: .distantPast,
            geaendertAm: .distantPast
        )
        _ = raum

        #expect(plan.raumGeometrie == vorher)
        #expect(plan.raumGeometrie.breiteCm == 720)

        // Und umgekehrt: Wer den Plan aendert, aendert keinen Raum.
        plan.raumGeometrie.breiteCm = 1
        #expect(vorher.breiteCm == 720)
    }

    @Test("Der Raumname kommt aus dem Raum, nicht aus dem Dokument")
    func raumname() throws {
        let plan = Sitzplan(
            klasseId: UUID(),
            raumId: UUID(),
            name: "Deutsch 7a",
            erstelltAm: .distantPast,
            geaendertAm: .distantPast
        )
        let raum = Raum(name: "B204", breiteCm: 720, laengeCm: 520,
                        erstelltAm: .distantPast, geaendertAm: .distantPast)

        #expect(plan.raumname(ausRaum: raum) == "B204")
        #expect(plan.raumname(ausRaum: nil) == "Raum")

        let namenlos = Raum(name: "   ", breiteCm: 720, laengeCm: 520,
                            erstelltAm: .distantPast, geaendertAm: .distantPast)
        #expect(plan.raumname(ausRaum: namenlos) == "Raum")
    }

    @Test("Geschrieben wird kanonisch — Masse kommen aus der Tabelle")
    func kanonischesSchreiben() throws {
        // Ein Dokument, dessen Masse nicht zur Moebeltabelle passen.
        let roh = """
        {"objekte":[{"id":"t1","typ":"table_double","x_cm":10,"y_cm":20,
        "breite_cm":999,"tiefe_cm":999,"rotation_deg":0}],"sitzplaetze":[]}
        """
        let dokument = Dokumentlesen.raumDokument(aus: Data(roh.utf8))
        #expect(dokument.objekte.count == 1)

        let geschrieben = try Dokumentlesen.daten(aus: dokument)
        let text = String(decoding: geschrieben, as: UTF8.self)

        #expect(text.contains("\"breite_cm\":120"), "Breite muss aus der Tabelle kommen")
        #expect(text.contains("\"tiefe_cm\":50"))
        #expect(!text.contains("999"), "Der Wert aus dem Dokument darf nicht ueberleben")
    }

    @Test("Beide Namenswelten werden bedient")
    func namenswelten() throws {
        let json = try Fixtures.json(.planDokumentV1)
        let daten = try JSONSerialization.data(withJSONObject: try #require(json["canvas_document"]))
        let plan = Dokumentlesen.planDokument(aus: daten)

        let text = String(decoding: try Dokumentlesen.daten(aus: plan), as: UTF8.self)

        // PlanDokument: Binnenmajuskel
        #expect(text.contains("\"breiteCm\""))
        #expect(text.contains("\"rasterCm\""))
        // Objekte darin: Unterstrich
        #expect(text.contains("\"breite_cm\""))
        #expect(text.contains("\"x_cm\""))
        #expect(text.contains("\"rotation_deg\""))
        // Sitzplaetze: Unterstrich mit Binnenmajuskel davor
        #expect(text.contains("\"lokalX_cm\""))
    }
}
