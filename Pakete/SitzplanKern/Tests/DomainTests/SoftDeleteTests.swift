import Fixtures
import Foundation
import Testing

@testable import Domain

@Suite("Soft-Delete")
struct SoftDeleteTests {

    /// Die Fixture arbeitet mit „k1“, „s1“ statt mit UUIDs.
    private struct Kennungen {
        private var tabelle: [String: UUID] = [:]
        mutating func uuid(_ name: String) -> UUID {
            if let vorhanden = tabelle[name] { return vorhanden }
            let neu = UUID()
            tabelle[name] = neu
            return neu
        }
    }

    /// `ISO8601DateFormatter` ist nicht `Sendable` und taugt deshalb im
    /// Swift-6-Sprachmodus nicht als geteilte statische Eigenschaft. Hier je
    /// Aufruf neu — in einer Testsuite ist das billig genug.
    private static func datum(_ text: Any?) -> Date? {
        guard let text = text as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }

    @Test("Eine aktive Klasse traegt nur ungeloeschte Schueler")
    func aktiveKlasse() throws {
        let fall = try Self.fall(mitNamensteil: "aktive Klasse")
        var k = Kennungen()

        let klasseRoh = try #require(fall["klasse"] as? [String: Any])
        let klasse = Klasse(
            id: k.uuid(try #require(klasseRoh["id"] as? String)),
            name: try #require(klasseRoh["name"] as? String),
            erstelltAm: .distantPast,
            geaendertAm: .distantPast,
            geloeschtAm: Self.datum(klasseRoh["deleted_at"])
        )

        let schueler = try Self.schueler(aus: fall, klasseId: klasse.id, kennungen: &k)
        let getragen = SoftDelete.schuelerDerKlasse(klasse, schueler: schueler)

        let erwartet = try #require((fall["erwartet"] as? [String: Any])?["schuelerInKlasse"] as? [String])
        #expect(getragen.count == erwartet.count)
        #expect(getragen.allSatisfy { !$0.istGeloescht })
    }

    @Test("Eine geloeschte Klasse nimmt ihre Schueler mit — gleicher Zeitstempel")
    func geloeschteKlasseNimmtMit() throws {
        let fall = try Self.fall(mitNamensteil: "nimmt ihre Schueler mit")
        var k = Kennungen()

        let klasseRoh = try #require(fall["klasse"] as? [String: Any])
        let geloeschtAm = try #require(Self.datum(klasseRoh["deleted_at"]))
        let klasse = Klasse(
            id: k.uuid(try #require(klasseRoh["id"] as? String)),
            name: try #require(klasseRoh["name"] as? String),
            erstelltAm: .distantPast,
            geaendertAm: .distantPast,
            geloeschtAm: geloeschtAm
        )

        let schueler = try Self.schueler(aus: fall, klasseId: klasse.id, kennungen: &k)
        let getragen = SoftDelete.schuelerDerKlasse(klasse, schueler: schueler)

        let erwartet = try #require(
            (fall["erwartet"] as? [String: Any])?["schuelerInPapierkorbNutzlast"] as? [String]
        )
        #expect(getragen.count == erwartet.count,
                "Wer hier stur nach geloescht filtert, holt eine leere Klasse aus dem Papierkorb")
        #expect(getragen.allSatisfy { $0.geloeschtAm == geloeschtAm })
    }

    @Test("Ein vorher einzeln geloeschter Schueler bleibt geloescht")
    func einzelnGeloeschterBleibtGeloescht() throws {
        let fall = try Self.fall(mitNamensteil: "bleibt geloescht")
        var k = Kennungen()

        let klasseRoh = try #require(fall["klasse"] as? [String: Any])
        let geloeschtAm = try #require(Self.datum(klasseRoh["deleted_at"]))
        let klasse = Klasse(
            id: k.uuid(try #require(klasseRoh["id"] as? String)),
            name: try #require(klasseRoh["name"] as? String),
            erstelltAm: .distantPast,
            geaendertAm: .distantPast,
            geloeschtAm: geloeschtAm
        )

        let schueler = try Self.schueler(aus: fall, klasseId: klasse.id, kennungen: &k)
        let getragen = SoftDelete.schuelerDerKlasse(klasse, schueler: schueler)

        let erwartet = try #require(
            (fall["erwartet"] as? [String: Any])?["schuelerInPapierkorbNutzlast"] as? [String]
        )
        #expect(getragen.count == erwartet.count)
        #expect(getragen.count == 1)
        // Der mit dem aelteren Zeitstempel ging nicht mit der Klasse.
        #expect(!getragen.contains { $0.geloeschtAm != geloeschtAm })
    }

    @Test("Zweites Loeschen aendert den Zeitstempel nicht")
    func zweitesLoeschen() throws {
        let fall = try Self.fall(mitNamensteil: "zweites Loeschen")
        let eingabe = try #require(fall["eingabe"] as? [String: Any])
        let bisher = try #require(Self.datum(eingabe["deleted_at"]))
        let jetzt = try #require(Self.datum(fall["loeschenMit"]))
        let erwartet = try #require(Self.datum((fall["erwartet"] as? [String: Any])?["deleted_at"]))

        #expect(SoftDelete.loeschzeitpunkt(bisher: bisher, jetzt: jetzt) == erwartet)
        #expect(SoftDelete.loeschzeitpunkt(bisher: nil, jetzt: jetzt) == jetzt)
    }

    @Test("Zuweisungen geloeschter Schueler werden ausgeblendet, nicht entfernt")
    func zuweisungenBleiben() throws {
        let fall = try Self.fall(mitNamensteil: "ausgeblendet")
        let zuweisungen = try #require(fall["zuweisungen"] as? [String: String])
        let aktive = Set(try #require(fall["aktiveSchueler"] as? [String]))

        let alle = zuweisungen.map { Zuordnung(sitzplatzId: $0.key, schuelerId: $0.value) }
        let sichtbar = SoftDelete.sichtbareZuordnungen(alle, aktiveSchuelerIds: aktive)

        let erwartet = try #require(fall["erwartet"] as? [String: Any])
        let erwarteteSichtbare = try #require(erwartet["sichtbareZuweisungen"] as? [String: String])
        let imDokument = try #require(erwartet["imDokumentWeiterhin"] as? Int)

        #expect(sichtbar.count == erwarteteSichtbare.count)
        #expect(alle.count == imDokument, "Die Zuweisung bleibt im Dokument stehen")
    }

    @Test("Der Papierkorb ist nach Loeschzeitpunkt absteigend sortiert")
    func papierkorbreihenfolge() throws {
        let fall = try Self.fall(mitNamensteil: "absteigend sortiert")
        let eintraegeRoh = try #require(fall["eintraege"] as? [[String: Any]])
        var k = Kennungen()

        var namen: [UUID: String] = [:]
        let eintraege: [Papierkorbeintrag] = try eintraegeRoh.map { e in
            let name = try #require(e["id"] as? String)
            let artText = try #require(e["kind"] as? String)
            let art = try #require(Papierkorbeintrag.Art(rawValue: artText))
            let geloeschtAm = try #require(Self.datum(e["deletedAt"]))

            let id = k.uuid(name)
            namen[id] = name
            return Papierkorbeintrag(id: id, art: art, bezeichnung: name, geloeschtAm: geloeschtAm)
        }

        let erwartet = try #require((fall["erwartet"] as? [String: Any])?["reihenfolge"] as? [String])
        let tatsaechlich = eintraege.inPapierkorbreihenfolge().compactMap { namen[$0.id] }
        #expect(tatsaechlich == erwartet)
    }

    @Test("Gleiche Zeitstempel ergeben eine stabile Reihenfolge")
    func stabileReihenfolge() {
        let zeit = Date(timeIntervalSince1970: 1_000)
        let eintraege = [
            Papierkorbeintrag(id: UUID(), art: .klasse, bezeichnung: "9c", geloeschtAm: zeit),
            Papierkorbeintrag(id: UUID(), art: .klasse, bezeichnung: "5b", geloeschtAm: zeit),
            Papierkorbeintrag(id: UUID(), art: .klasse, bezeichnung: "7a", geloeschtAm: zeit),
        ]
        let einmal = eintraege.inPapierkorbreihenfolge().map(\.bezeichnung)
        let nochmal = eintraege.shuffled().inPapierkorbreihenfolge().map(\.bezeichnung)
        #expect(einmal == ["5b", "7a", "9c"])
        #expect(einmal == nochmal, "Eine Liste, die bei jedem Oeffnen anders aussieht, ist unbrauchbar")
    }

    // MARK: - Hilfen

    private static func fall(mitNamensteil teil: String) throws -> [String: Any] {
        let json = try Fixtures.json(.softDeleteFaelle)
        let faelle = try #require(json["faelle"] as? [[String: Any]])
        let treffer = faelle.first { ($0["name"] as? String)?.contains(teil) == true }
        return try #require(treffer, "Fixture-Fall mit '\(teil)' fehlt")
    }

    private static func schueler(
        aus fall: [String: Any],
        klasseId: UUID,
        kennungen k: inout Kennungen
    ) throws -> [Schueler] {
        let roh = try #require(fall["schueler"] as? [[String: Any]])
        return try roh.map { s in
            Schueler(
                id: k.uuid(try #require(s["id"] as? String)),
                klasseId: klasseId,
                vorname: try #require(s["vorname"] as? String),
                nachname: try #require(s["nachname"] as? String),
                erstelltAm: .distantPast,
                geaendertAm: .distantPast,
                geloeschtAm: datum(s["deleted_at"])
            )
        }
    }
}
