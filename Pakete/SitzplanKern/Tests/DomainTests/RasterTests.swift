import Fixtures
import Foundation
import Testing

@testable import Domain

@Suite("Rasterrechnung")
struct RasterTests {

    @Test("Alle Rundungsfaelle der Fixture stimmen")
    func rundungAusFixture() throws {
        let json = try Fixtures.json(.planDokumentAltUnvollstaendig)
        let faelle = try #require(json["_rasterrundung"] as? [[String: Any]])

        #expect(!faelle.isEmpty)
        var geprueft = 0

        for fall in faelle {
            let wert = try #require((fall["wert"] as? NSNumber)?.doubleValue)
            let raster = try #require((fall["raster"] as? NSNumber)?.doubleValue)

            // Der letzte Fall hat `erwartet: null` — die Rundung wird nie mit
            // Raster 0 aufgerufen, `weite(_:)` faengt das vorher ab.
            guard let erwartet = (fall["erwartet"] as? NSNumber)?.doubleValue else {
                #expect(Raster.weite(raster) == Raster.standard,
                        "Raster 0 muss auf \(Raster.standard) zurueckfallen")
                continue
            }

            let ergebnis = Raster.runden(wert, raster: raster)
            #expect(ergebnis == erwartet, "runden(\(wert), raster: \(raster))")
            geprueft += 1
        }

        #expect(geprueft >= 7, "Es muessen alle Rundungsfaelle geprueft worden sein")
    }

    @Test("Halbe Schritte gehen zur groesseren Zahl — auch im Negativen")
    func halbeSchritte() {
        // Genau hier laufen JavaScript und Swift auseinander:
        // Math.round(-0.5) ist -0, (-0.5).rounded() ist -1.
        #expect(Raster.runden(12.5, raster: 25) == 25)
        #expect(Raster.runden(-12.5, raster: 25) == 0)
        #expect(Raster.runden(37.5, raster: 25) == 50)
        #expect(Raster.runden(-37.5, raster: 25) == -25)
        #expect(Raster.runden(-62.5, raster: 25) == -50)
    }

    @Test("rounded() waere hier falsch — der Unterschied ist nachweisbar")
    func rundedWaereFalsch() {
        let wert = -12.5, raster = 25.0
        let richtig = Raster.runden(wert, raster: raster)
        let falsch = (wert / raster).rounded(.toNearestOrAwayFromZero) * raster

        #expect(richtig == 0)
        #expect(falsch == -25)
        #expect(richtig != falsch, "Wenn das gleich waere, prueft dieser Test nichts")
    }

    @Test("Die Rasterweite faellt bei fehlender und bei 0-Angabe zurueck")
    func rasterweite() {
        #expect(Raster.weite(nil) == 25)
        #expect(Raster.weite(0) == 25)
        #expect(Raster.weite(10) == 10)
        #expect(Raster.weite(25) == 25)
        #expect(Raster.weite(50) == 50)
    }

    @Test("Rundung mit Raster 0 gibt den Wert unveraendert zurueck statt zu stuerzen")
    func rasterNull() {
        #expect(Raster.runden(100, raster: 0) == 100)
        #expect(Raster.runden(-3.7, raster: 0) == -3.7)
    }

    @Test("Punkte werden auf beiden Achsen gerundet")
    func punktRunden() {
        let p = Raster.runden(x: 12.5, y: -12.5, raster: 25)
        #expect(p.x == 25)
        #expect(p.y == 0)
    }
}
