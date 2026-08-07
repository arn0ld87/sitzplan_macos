import Domain
import Foundation
import SwiftData
import Testing

@testable import Speicher

@Suite("Schüler-Repository")
struct SchuelerSpeicherTests {

    private func container() throws -> ModelContainer {
        try Speicher.containerImArbeitsspeicher()
    }

    private func klasse(in container: ModelContainer) async throws -> Klasse {
        let ks = KlassenSpeicher(modelContainer: container)
        return try await ks.anlegen(name: "7a", notizen: nil)
    }

    // MARK: - Grundfunktionen

    @Test("Anlegen und lesen")
    func anlegen() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)

        #expect(try await s.derKlasse(k.id).isEmpty)

        let jetzt = Date()
        let neu = Schueler(klasseId: k.id, vorname: "Anna", nachname: "Muster",
                           erstelltAm: jetzt, geaendertAm: jetzt)
        let angelegt = try await s.anlegen(neu)

        #expect(angelegt.vorname == "Anna")
        #expect(angelegt.nachname == "Muster")
        #expect(angelegt.initialen == "AM")

        let liste = try await s.derKlasse(k.id)
        #expect(liste.count == 1)
        #expect(liste.first?.id == angelegt.id)
    }

    @Test("Schüler kommen alphabetisch nach Nachname dann Vorname")
    func alphabetisch() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        for (v, n) in [("Zora", "Bauer"), ("Anna", "Müller"), ("Karl", "Bauer")] {
            try await s.anlegen(
                Schueler(klasseId: k.id, vorname: v, nachname: n, erstelltAm: jetzt, geaendertAm: jetzt)
            )
        }

        let namen = try await s.derKlasse(k.id).map { "\($0.nachname) \($0.vorname)" }
        #expect(namen == ["Bauer Karl", "Bauer Zora", "Müller Anna"])
    }

    @Test("Aktualisieren")
    func aktualisieren() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        var angelegt = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Anna", nachname: "Muster", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        angelegt.vorname = "Annika"
        angelegt.farbIndex = 3

        let aktualisiert = try await s.aktualisieren(angelegt)
        #expect(aktualisiert.vorname == "Annika")
        #expect(aktualisiert.farbIndex == 3)
        #expect(try await s.derKlasse(k.id).first?.vorname == "Annika")
    }

    @Test("Weich löschen verschwindet aus der Liste")
    func weichLoeschen() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        let angelegt = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Anna", nachname: "Muster", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        try await s.loeschen(id: angelegt.id)

        #expect(try await s.derKlasse(k.id).isEmpty)
    }

    @Test("Wiederherstellen bringt den Schüler zurück")
    func wiederherstellen() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        let angelegt = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Anna", nachname: "Muster", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        try await s.loeschen(id: angelegt.id)
        try await s.wiederherstellen(id: angelegt.id)

        #expect(try await s.derKlasse(k.id).count == 1)
    }

    @Test("Initialen werden automatisch berechnet")
    func initialen() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        let angelegt = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Anna", nachname: "Bauer", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        #expect(angelegt.initialen == "AB")
    }

    @Test("Merkmale werden gespeichert und gelesen")
    func merkmale() async throws {
        let c = try container()
        let k = try await klasse(in: c)
        let s = SchuelerSpeicher(modelContainer: c)
        let jetzt = Date()

        let angelegt = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Anna", nachname: "Muster",
                     merkmale: [.adhs, .legasthenie], erstelltAm: jetzt, geaendertAm: jetzt)
        )
        let geladen = try await s.derKlasse(k.id).first
        #expect(geladen?.merkmale == [.adhs, .legasthenie])
        #expect(geladen?.id == angelegt.id)
    }

    @Test("Unbekannte Kennung ergibt einen typisierten Fehler")
    func unbekannteKennung() async throws {
        let c = try container()
        let s = SchuelerSpeicher(modelContainer: c)

        await #expect(throws: Domaenenfehler.self) {
            try await s.loeschen(id: UUID())
        }
    }

    // MARK: - Klassen-Papierkorb-Verhalten

    @Test("Gelöschte Klasse: nur die mit identischem Zeitstempel kommen zurück")
    func geloeschteKlasseZeitpunkt() async throws {
        let c = try container()
        let ks = KlassenSpeicher(modelContainer: c)
        let s = SchuelerSpeicher(modelContainer: c)

        let k = try await ks.anlegen(name: "7a", notizen: nil)
        let jetzt = Date()

        // Finn wird vorher einzeln gelöscht — mit älterem Zeitstempel.
        let finn = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Finn", nachname: "Muster", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        let alva = try await s.anlegen(
            Schueler(klasseId: k.id, vorname: "Alva", nachname: "Muster", erstelltAm: jetzt, geaendertAm: jetzt)
        )
        try await s.loeschen(id: finn.id)

        // Klasse löschen — Alva geht mit, Finn bleibt gelöscht.
        try await ks.loeschen(id: k.id)

        // Aus gelöschter Klasse: nur Alva (identischer Zeitstempel).
        let sichtbar = try await s.derKlasse(k.id)
        #expect(sichtbar.count == 1)
        #expect(sichtbar.first?.id == alva.id)
    }
}
