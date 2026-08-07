import Domain
import Foundation
import SwiftData
import Testing

@testable import Speicher

/// Repository-Rundreise gegen einen Speicher im Arbeitsspeicher.
///
/// Nie gegen die Datenbank der Benutzerin — deshalb ausschliesslich
/// ``Speicher/containerImArbeitsspeicher()``.
@Suite("Raum-Repository")
struct RaumSpeicherTests {

    private func speicher() throws -> RaumSpeicher {
        RaumSpeicher(modelContainer: try Speicher.containerImArbeitsspeicher())
    }

    private func raum(
        name: String = "Raum 101",
        breite: Double = 800,
        laenge: Double = 600,
        raster: Double = 25
    ) -> Raum {
        Raum(
            name: name,
            breiteCm: breite,
            laengeCm: laenge,
            rasterCm: raster,
            erstelltAm: Date(),
            geaendertAm: Date()
        )
    }

    @Test("Anlegen, lesen, aktualisieren")
    func rundreise() async throws {
        let s = try speicher()

        #expect(try await s.aktive().isEmpty)

        let angelegt = try await s.anlegen(raum(name: "Raum 101"))
        #expect(angelegt.name == "Raum 101")

        let geladen = try await s.aktive()
        #expect(geladen.count == 1)
        #expect(geladen.first?.id == angelegt.id)

        var geaendert = angelegt
        geaendert.name = "Raum 102"
        geaendert.breiteCm = 900
        let aktualisiert = try await s.aktualisieren(geaendert)
        #expect(aktualisiert.name == "Raum 102")
        #expect(aktualisiert.breiteCm == 900)
        #expect(try await s.aktive().first?.name == "Raum 102")
    }

    @Test("Räume kommen alphabetisch")
    func alphabetisch() async throws {
        let s = try speicher()
        for name in ["Raum C", "Raum A", "Raum B"] {
            try await s.anlegen(raum(name: name))
        }
        #expect(try await s.aktive().map(\.name) == ["Raum A", "Raum B", "Raum C"])
    }

    @Test("Ungültige Masse werden beim Anlegen abgelehnt")
    func ungueltigeMasseAnlegen() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.self) {
            try await s.anlegen(raum(breite: 0, laenge: 600))
        }
        #expect(try await s.aktive().isEmpty)
    }

    @Test("Ungültige Masse werden beim Aktualisieren abgelehnt")
    func ungueltigeMasseAktualisieren() async throws {
        let s = try speicher()
        let angelegt = try await s.anlegen(raum())

        var geaendert = angelegt
        geaendert.laengeCm = -1
        await #expect(throws: Domaenenfehler.self) {
            try await s.aktualisieren(geaendert)
        }
        // Bestand bleibt unangetastet — die fehlerhafte Aenderung wurde nicht
        // gespeichert.
        #expect(try await s.raum(id: angelegt.id)?.laengeCm == 600)
    }

    @Test("Ein zu kleines Raster wird abgelehnt")
    func rasterZuKlein() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.self) {
            try await s.anlegen(raum(raster: 2))
        }
        #expect(try await s.aktive().isEmpty)
    }

    @Test("Weich Geloeschtes verschwindet aus der Liste")
    func weichLoeschen() async throws {
        let s = try speicher()
        let r = try await s.anlegen(raum())

        try await s.loeschen(id: r.id)

        #expect(try await s.aktive().isEmpty, "Geloeschtes gehoert nicht in die Liste")
        // Der Datensatz existiert weiter — geloescht heisst nicht entfernt.
        #expect(try await s.raum(id: r.id)?.geloeschtAm != nil)
    }

    @Test("Wiederherstellen bringt den Raum zurueck")
    func wiederherstellen() async throws {
        let s = try speicher()
        let r = try await s.anlegen(raum())

        try await s.loeschen(id: r.id)
        try await s.wiederherstellen(id: r.id)

        #expect(try await s.aktive().count == 1)
        #expect(try await s.raum(id: r.id)?.geloeschtAm == nil)
    }

    @Test("Zweites Loeschen aendert den Zeitstempel nicht")
    func zweitesLoeschen() async throws {
        let s = try speicher()
        let r = try await s.anlegen(raum())

        try await s.loeschen(id: r.id)
        let ersterZeitpunkt = try await s.raum(id: r.id)?.geloeschtAm

        try await Task.sleep(for: .milliseconds(20))
        try await s.loeschen(id: r.id)
        let zweiterZeitpunkt = try await s.raum(id: r.id)?.geloeschtAm

        #expect(ersterZeitpunkt == zweiterZeitpunkt,
                "Sonst verschiebt sich die Reihenfolge im Papierkorb")
    }

    @Test("Eine unbekannte Kennung ergibt einen typisierten Fehler, keinen Absturz")
    func unbekannteKennung() async throws {
        let s = try speicher()

        await #expect(throws: Domaenenfehler.nichtGefunden(art: "Der Raum")) {
            try await s.aktualisieren(raum())
        }
        await #expect(throws: Domaenenfehler.nichtGefunden(art: "Der Raum")) {
            try await s.loeschen(id: UUID())
        }
        #expect(try await s.raum(id: UUID()) == nil)
    }
}