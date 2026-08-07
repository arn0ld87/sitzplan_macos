import Domain
import Foundation
import SwiftData
import Testing

@testable import Speicher

/// Repository-Rundreise gegen einen Speicher im Arbeitsspeicher.
///
/// Nie gegen die Datenbank der Benutzerin — deshalb ausschliesslich
/// ``Speicher/containerImArbeitsspeicher()``.
@Suite("Klassen-Repository")
struct KlassenSpeicherTests {

    private func speicher() throws -> KlassenSpeicher {
        KlassenSpeicher(modelContainer: try Speicher.containerImArbeitsspeicher())
    }

    @Test("Anlegen, lesen, umbenennen")
    func rundreise() async throws {
        let s = try speicher()

        #expect(try await s.aktive().isEmpty)

        let angelegt = try await s.anlegen(name: "7a", notizen: nil)
        #expect(angelegt.name == "7a")

        let geladen = try await s.aktive()
        #expect(geladen.count == 1)
        #expect(geladen.first?.id == angelegt.id)

        let umbenannt = try await s.umbenennen(id: angelegt.id, auf: "7b")
        #expect(umbenannt.name == "7b")
        #expect(try await s.aktive().first?.name == "7b")
    }

    @Test("Klassen kommen alphabetisch")
    func alphabetisch() async throws {
        let s = try speicher()
        for name in ["9c", "5b", "7a"] {
            try await s.anlegen(name: name, notizen: nil)
        }
        #expect(try await s.aktive().map(\.name) == ["5b", "7a", "9c"])
    }

    @Test("Ein leerer Name wird abgelehnt")
    func leererName() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.self) {
            try await s.anlegen(name: "   ", notizen: nil)
        }
        #expect(try await s.aktive().isEmpty)
    }

    @Test("Namen werden beim Anlegen bereinigt")
    func nameBereinigt() async throws {
        let s = try speicher()
        let k = try await s.anlegen(name: "  7a  ", notizen: nil)
        #expect(k.name == "7a")
    }

    @Test("Weich Geloeschtes verschwindet aus der Liste und liegt im Papierkorb")
    func weichLoeschen() async throws {
        let s = try speicher()
        let k = try await s.anlegen(name: "7a", notizen: nil)

        try await s.loeschen(id: k.id)

        #expect(try await s.aktive().isEmpty, "Geloeschtes gehoert nicht in die Liste")
        let papierkorb = try await s.geloeschte()
        #expect(papierkorb.count == 1)
        #expect(papierkorb.first?.bezeichnung == "7a")

        // Der Datensatz existiert weiter — geloescht heisst nicht entfernt.
        #expect(try await s.klasse(id: k.id)?.geloeschtAm != nil)
    }

    @Test("Wiederherstellen bringt die Klasse zurueck")
    func wiederherstellen() async throws {
        let s = try speicher()
        let k = try await s.anlegen(name: "7a", notizen: nil)

        try await s.loeschen(id: k.id)
        try await s.wiederherstellen(id: k.id)

        #expect(try await s.aktive().count == 1)
        #expect(try await s.geloeschte().isEmpty)
        #expect(try await s.klasse(id: k.id)?.geloeschtAm == nil)
    }

    @Test("Zweites Loeschen aendert den Zeitstempel nicht")
    func zweitesLoeschen() async throws {
        let s = try speicher()
        let k = try await s.anlegen(name: "7a", notizen: nil)

        try await s.loeschen(id: k.id)
        let ersterZeitpunkt = try await s.klasse(id: k.id)?.geloeschtAm

        try await Task.sleep(for: .milliseconds(20))
        try await s.loeschen(id: k.id)
        let zweiterZeitpunkt = try await s.klasse(id: k.id)?.geloeschtAm

        #expect(ersterZeitpunkt == zweiterZeitpunkt,
                "Sonst verschiebt sich die Reihenfolge im Papierkorb")
    }

    @Test("Eine geloeschte Klasse nimmt ihre Schueler mit demselben Zeitstempel mit")
    func schuelerGehenMit() async throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let s = KlassenSpeicher(modelContainer: container)
        let k = try await s.anlegen(name: "7a", notizen: nil)

        try await Self.schuelerAnlegen(["Alva", "Bo"], klasseId: k.id, container: container)
        try await s.loeschen(id: k.id)

        let papierkorb = try await s.geloeschte()
        #expect(papierkorb.first?.mitgeloeschteAnzahl == 2,
                "Wer hier stur filtert, holt eine leere Klasse aus dem Papierkorb")

        let zeitpunkte = try await Self.schuelerZeitpunkte(container: container)
        #expect(Set(zeitpunkte.compactMap { $0 }).count == 1, "Genau ein Zeitstempel")
        #expect(zeitpunkte.allSatisfy { $0 != nil })
    }

    @Test("Ein vorher einzeln geloeschter Schueler bleibt nach dem Wiederherstellen geloescht")
    func einzelnGeloeschterBleibtGeloescht() async throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let s = KlassenSpeicher(modelContainer: container)
        let k = try await s.anlegen(name: "7a", notizen: nil)

        try await Self.schuelerAnlegen(["Alva", "Finn"], klasseId: k.id, container: container)
        // Finn wird vorher einzeln geloescht — mit einem aelteren Zeitstempel.
        try await Self.schuelerLoeschen(vorname: "Finn", am: Date(timeIntervalSince1970: 1_000), container: container)

        try await s.loeschen(id: k.id)

        let papierkorb = try await s.geloeschte()
        #expect(papierkorb.first?.mitgeloeschteAnzahl == 1, "Nur Alva geht mit der Klasse")

        try await s.wiederherstellen(id: k.id)

        let zeitpunkte = try await Self.schuelerZeitpunkteJeName(container: container)
        #expect(zeitpunkte["Alva"] ?? nil == nil, "Alva kommt zurueck")
        #expect(zeitpunkte["Finn"] ?? nil != nil, "Finn bleibt geloescht")
    }

    @Test("Der Papierkorb ist nach Loeschzeitpunkt absteigend sortiert")
    func papierkorbreihenfolge() async throws {
        let s = try speicher()
        let a = try await s.anlegen(name: "zuerst", notizen: nil)
        try await s.loeschen(id: a.id)
        try await Task.sleep(for: .milliseconds(20))
        let b = try await s.anlegen(name: "danach", notizen: nil)
        try await s.loeschen(id: b.id)

        #expect(try await s.geloeschte().map(\.bezeichnung) == ["danach", "zuerst"])
    }

    @Test("Endgueltig entfernen geht nur aus dem Papierkorb")
    func endgueltigEntfernen() async throws {
        let s = try speicher()
        let k = try await s.anlegen(name: "7a", notizen: nil)

        await #expect(throws: Domaenenfehler.self) {
            try await s.endgueltigEntfernen(id: k.id)
        }

        try await s.loeschen(id: k.id)
        try await s.endgueltigEntfernen(id: k.id)
        #expect(try await s.klasse(id: k.id) == nil)
    }

    @Test("Eine unbekannte Kennung ergibt einen typisierten Fehler, keinen Absturz")
    func unbekannteKennung() async throws {
        let s = try speicher()
        await #expect(throws: Domaenenfehler.nichtGefunden(art: "Die Klasse")) {
            try await s.umbenennen(id: UUID(), auf: "x")
        }
        #expect(try await s.klasse(id: UUID()) == nil)
    }

    // MARK: - Hilfen

    @MainActor
    private static func schuelerAnlegen(
        _ vornamen: [String],
        klasseId: UUID,
        container: ModelContainer
    ) throws {
        let kontext = container.mainContext
        let klassen = try kontext.fetch(
            FetchDescriptor<KlassenEintrag>(predicate: #Predicate { $0.id == klasseId })
        )
        let klasse = try #require(klassen.first)

        for vorname in vornamen {
            let s = SchuelerEintrag(
                vorname: vorname,
                nachname: "Muster",
                initialen: "\(vorname.prefix(1))M",
                farbIndex: 0,
                erstelltAm: Date(),
                geaendertAm: Date(),
                klasse: klasse
            )
            kontext.insert(s)
        }
        try kontext.save()
    }

    @MainActor
    private static func schuelerLoeschen(
        vorname: String,
        am zeitpunkt: Date,
        container: ModelContainer
    ) throws {
        let kontext = container.mainContext
        let treffer = try kontext.fetch(
            FetchDescriptor<SchuelerEintrag>(predicate: #Predicate { $0.vorname == vorname })
        )
        for s in treffer {
            s.geloeschtAm = zeitpunkt
        }
        try kontext.save()
    }

    @MainActor
    private static func schuelerZeitpunkte(container: ModelContainer) throws -> [Date?] {
        try container.mainContext
            .fetch(FetchDescriptor<SchuelerEintrag>())
            .map(\.geloeschtAm)
    }

    @MainActor
    private static func schuelerZeitpunkteJeName(
        container: ModelContainer
    ) throws -> [String: Date?] {
        var ergebnis: [String: Date?] = [:]
        for s in try container.mainContext.fetch(FetchDescriptor<SchuelerEintrag>()) {
            ergebnis[s.vorname] = s.geloeschtAm
        }
        return ergebnis
    }
}
