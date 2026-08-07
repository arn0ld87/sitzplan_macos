import Domain
import Foundation
import SwiftData
import Testing

@testable import Speicher

/// Repository-Rundreise gegen einen Speicher im Arbeitsspeicher.
///
/// Nie gegen die Datenbank der Benutzerin — deshalb ausschliesslich
/// ``Speicher/containerImArbeitsspeicher()``.
@Suite("Raum-Repository", .serialized)
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

    @Test("Wiederherstellen einer unbekannten Kennung ergibt denselben typisierten Fehler")
    func unbekannteKennungWiederherstellen() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.nichtGefunden(art: "Der Raum")) {
            try await s.wiederherstellen(id: UUID())
        }
    }

    @Test("Ein Raster von genau 5 cm ist die untere Grenze und wird angenommen")
    func rasterUntereGrenze() async throws {
        let s = try speicher()
        let angelegt = try await s.anlegen(raum(raster: 5))
        #expect(angelegt.rasterCm == 5)
    }

    @Test("Negative Breite und Laenge werden ebenso abgelehnt wie 0")
    func negativeMasse() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.self) {
            try await s.anlegen(raum(breite: -100, laenge: 600))
        }
        await #expect(throws: Domaenenfehler.self) {
            try await s.anlegen(raum(breite: 800, laenge: -1))
        }
        #expect(try await s.aktive().isEmpty)
    }

    @Test("Das Raumdokument mit Moebeln und Sitzplaetzen ueberlebt Anlegen und Lesen")
    func dokumentRundreiseBeimAnlegen() async throws {
        let s = try speicher()
        let objekt = Raumobjekt(id: "obj-1", typ: .doppeltisch, xCm: 100, yCm: 50, drehung: .neunzig)
        let sitzplatz = Sitzplatz(id: "obj-1__sitz_1", objektId: "obj-1", lokalXCm: 10, lokalYCm: 20, bezeichnung: "1")
        var raumMitDokument = raum()
        raumMitDokument.dokument = RaumDokument(objekte: [objekt], sitzplaetze: [sitzplatz])

        let angelegt = try await s.anlegen(raumMitDokument)
        #expect(angelegt.dokument.objekte == [objekt])
        #expect(angelegt.dokument.sitzplaetze == [sitzplatz])

        let geladen = try await s.raum(id: angelegt.id)
        #expect(geladen?.dokument.objekte == [objekt])
        #expect(geladen?.dokument.sitzplaetze == [sitzplatz])
    }

    @Test("Das Raumdokument wird beim Aktualisieren ersetzt, nicht zusammengefuehrt")
    func dokumentWirdBeimAktualisierenErsetzt() async throws {
        let s = try speicher()
        var angelegt = try await s.anlegen(raum())
        angelegt.dokument = RaumDokument(
            objekte: [Raumobjekt(id: "obj-1", typ: .einzeltisch, xCm: 0, yCm: 0)]
        )
        let ersteVersion = try await s.aktualisieren(angelegt)
        #expect(ersteVersion.dokument.objekte.count == 1)

        var zweiteAenderung = ersteVersion
        zweiteAenderung.dokument = RaumDokument(
            objekte: [Raumobjekt(id: "obj-2", typ: .pult, xCm: 10, yCm: 10)]
        )
        let zweiteVersion = try await s.aktualisieren(zweiteAenderung)

        #expect(zweiteVersion.dokument.objekte.map(\.id) == ["obj-2"],
                "Das neue Dokument ersetzt das alte vollstaendig")
    }

    @Test("Aktualisieren setzt geaendertAm neu, laesst erstelltAm aber unangetastet")
    func geaendertAmWirdAktualisiertErstelltAmNicht() async throws {
        let s = try speicher()
        let angelegt = try await s.anlegen(raum())

        try await Task.sleep(for: .milliseconds(20))

        var geaendert = angelegt
        geaendert.name = "Neuer Name"
        let aktualisiert = try await s.aktualisieren(geaendert)

        #expect(aktualisiert.erstelltAm == angelegt.erstelltAm,
                "erstelltAm ist unveraenderlich")
        #expect(aktualisiert.geaendertAm > angelegt.geaendertAm,
                "geaendertAm muss beim Aktualisieren fortschreiten")
    }

    @Test("Loeschen ruehrt den Bestand anderer aktiver Raeume nicht an")
    func loeschenBetrifftNurDenEinenRaum() async throws {
        let s = try speicher()
        let a = try await s.anlegen(raum(name: "Raum A"))
        let b = try await s.anlegen(raum(name: "Raum B"))

        try await s.loeschen(id: a.id)

        let aktive = try await s.aktive()
        #expect(aktive.map(\.name) == ["Raum B"])
        #expect(try await s.raum(id: b.id)?.geloeschtAm == nil)
    }

    @Test("dokumentVersion wird unveraendert durchgereicht")
    func dokumentVersionBleibtErhalten() async throws {
        let s = try speicher()
        var raumMitVersion = raum()
        raumMitVersion.dokumentVersion = RaumDokument.version
        let angelegt = try await s.anlegen(raumMitVersion)
        #expect(angelegt.dokumentVersion == RaumDokument.version)
        #expect(try await s.raum(id: angelegt.id)?.dokumentVersion == RaumDokument.version)
    }
}