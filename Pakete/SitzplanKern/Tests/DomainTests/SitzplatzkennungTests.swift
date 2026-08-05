import Fixtures
import Foundation
import Testing

@testable import Domain

@Suite("Sitzplatzkennung")
struct SitzplatzkennungTests {

    @Test("Gueltige Kennungen aus der Fixture zerfallen richtig")
    func gueltigeAusFixture() throws {
        let json = try Fixtures.json(.planDokumentAltUnvollstaendig)
        let block = try #require(json["_sitzplatzkennungen"] as? [String: Any])
        let faelle = try #require(block["gueltig"] as? [[String: Any]])

        #expect(!faelle.isEmpty, "Die Fixture muss gueltige Faelle enthalten")

        for fall in faelle {
            let id = try #require(fall["id"] as? String)
            let erwarteteObjektId = try #require(fall["objektId"] as? String)
            let erwarteteNummer = try #require(fall["n"] as? Int)

            let zerlegt = Sitzplatzkennung.zerlegen(id)
            #expect(zerlegt?.objektId == erwarteteObjektId, "objektId von \(id)")
            #expect(zerlegt?.nummer == erwarteteNummer, "Nummer von \(id)")
        }
    }

    @Test("Ungueltige Kennungen aus der Fixture ergeben nil, keinen Absturz")
    func ungueltigeAusFixture() throws {
        let json = try Fixtures.json(.planDokumentAltUnvollstaendig)
        let block = try #require(json["_sitzplatzkennungen"] as? [String: Any])
        let faelle = try #require(block["ungueltig"] as? [[String: Any]])

        #expect(!faelle.isEmpty)

        for fall in faelle {
            let id = try #require(fall["id"] as? String)
            let grund = fall["grund"] as? String ?? "ohne Grund"
            #expect(Sitzplatzkennung.zerlegen(id) == nil, "\(id) muesste ungueltig sein — \(grund)")
        }
    }

    @Test("Getrennt wird am letzten Vorkommen des Trenners")
    func letztesVorkommen() {
        let zerlegt = Sitzplatzkennung.zerlegen("obj__sitz_1__sitz_2")
        #expect(zerlegt?.objektId == "obj__sitz_1")
        #expect(zerlegt?.nummer == 2)
    }

    @Test("Die Kennung ist kanonisch — der Rueckweg ergibt dieselbe Zeichenkette")
    func kanonisch() {
        for nummer in 1...30 {
            let id = Sitzplatzkennung.bauen(objektId: "obj", nummer: nummer)
            let zerlegt = Sitzplatzkennung.zerlegen(id)
            #expect(zerlegt?.nummer == nummer)
            #expect(zerlegt.map { Sitzplatzkennung.bauen(objektId: $0.objektId, nummer: $0.nummer) } == id)
        }
    }

    @Test("Fuehrende Nullen und Exponentialschreibweise sind nicht kanonisch")
    func nichtKanonisch() {
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_007") == nil)
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_1e3") == nil)
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_01") == nil)
    }

    @Test("Nummern beginnen bei 1")
    func beginntBeiEins() {
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_0") == nil)
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_1")?.nummer == 1)
    }

    @Test("Eine leere Objektkennung ist ungueltig")
    func leereObjektkennung() {
        #expect(Sitzplatzkennung.zerlegen("__sitz_1") == nil)
    }

    @Test("Unicode-Ziffern zaehlen nicht als Ziffern")
    func unicodeZiffern() {
        // Int("١٢") liefert in Foundation 12 — die Kennung waere damit nicht
        // mehr eindeutig. Der ASCII-Test faengt das ab.
        #expect(Sitzplatzkennung.zerlegen("obj__sitz_١٢") == nil)
    }

    @Test("Sitzplaetze werden aus dem Moebelstueck abgeleitet")
    func abgeleiteteSitzplaetze() {
        let doppel = Moebeltyp.doppeltisch.sitzplaetze(objektId: "t1")
        #expect(doppel.count == 2)
        #expect(doppel.map(\.lokalXCm) == [30, 90])
        #expect(doppel.allSatisfy { $0.lokalYCm == 25 })
        #expect(doppel.map(\.bezeichnung) == ["Platz 1", "Platz 2"])
        #expect(doppel.map(\.id) == ["t1__sitz_1", "t1__sitz_2"])

        let einzel = Moebeltyp.einzeltisch.sitzplaetze(objektId: "t2")
        #expect(einzel.count == 1)
        #expect(einzel.first?.lokalXCm == 30)

        #expect(Moebeltyp.pult.sitzplaetze(objektId: "p1").isEmpty)
        #expect(Moebeltyp.tafel.sitzplaetze(objektId: "b1").isEmpty)
    }
}
