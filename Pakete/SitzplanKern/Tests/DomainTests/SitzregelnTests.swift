import Fixtures
import Foundation
import Testing

@testable import Domain

@Suite("Sitzregeln")
struct SitzregelnTests {

    /// Die Fixture bezeichnet Regeln mit „r1“, „r8“ — keine UUIDs. Hier wird
    /// jeder Bezeichner stabil auf eine UUID abgebildet, damit der Rueckweg zum
    /// Vergleich mit `erwartet.regelIds` moeglich bleibt.
    private struct Regelnamen {
        private var zuUuid: [String: UUID] = [:]
        private var zuName: [UUID: String] = [:]

        mutating func uuid(fuer name: String) -> UUID {
            if let vorhanden = zuUuid[name] { return vorhanden }
            let neu = UUID()
            zuUuid[name] = neu
            zuName[neu] = name
            return neu
        }

        func name(fuer uuid: UUID) -> String? { zuName[uuid] }
    }

    @Test("Alle Konfliktfaelle der Fixture stimmen")
    func konflikteAusFixture() throws {
        let json = try Fixtures.json(.sitzregelnKonflikte)
        let rohtext = try Fixtures.text(.sitzregelnKonflikte)
        let grundlage = try #require(json["_grundlage"] as? [String: Any])
        let klasseIdText = try #require(grundlage["klasseId"] as? String)
        let klasseId = try #require(UUID(uuidString: klasseIdText))
        let faelle = try #require(json["faelle"] as? [[String: Any]])

        #expect(faelle.count >= 9, "Die Fixture soll alle Grenzfaelle abdecken")

        for fall in faelle {
            let name = try #require(fall["name"] as? String)
            var namen = Regelnamen()

            // Die Zuordnungen stehen als JSON-Objekt in der Fixture. Ihre
            // Reihenfolge entscheidet beim Fall „Schueler doppelt gesetzt“ —
            // JSONSerialization wirft sie weg, deshalb der Umweg ueber den
            // Rohtext.
            let zuordnungenRoh = try #require(fall["zuordnungen"] as? [String: String])
            let reihenfolge = Fixtures.schluesselInDokumentreihenfolge(
                Array(zuordnungenRoh.keys),
                aus: rohtext,
                abAnker: name
            )
            #expect(reihenfolge.count == zuordnungenRoh.count,
                    "Reihenfolge unvollstaendig ermittelt in: \(name)")

            let zuordnungen = reihenfolge.map {
                Zuordnung(sitzplatzId: $0, schuelerId: zuordnungenRoh[$0] ?? "")
            }

            let regelnRoh = try #require(fall["regeln"] as? [[String: Any]])
            let regeln: [Sitzregel] = try regelnRoh.map { r in
                let jetzt = Date(timeIntervalSince1970: 0)
                let regelname = try #require(r["id"] as? String)
                let klasseText = try #require(r["klasseId"] as? String)
                let aText = try #require(r["a"] as? String)
                let bText = try #require(r["b"] as? String)
                let artText = try #require(r["art"] as? String)

                let regelKlasse = try #require(UUID(uuidString: klasseText))
                let a = try #require(UUID(uuidString: aText))
                let b = try #require(UUID(uuidString: bText))
                let art = try #require(Regelart(rawValue: artText))

                return Sitzregel(
                    id: namen.uuid(fuer: regelname),
                    klasseId: regelKlasse,
                    schuelerA: a,
                    schuelerB: b,
                    art: art,
                    erstelltAm: jetzt,
                    geaendertAm: jetzt
                )
            }

            let erwartet = try #require(fall["erwartet"] as? [String: Any])
            let erwarteteAnzahl = try #require(erwartet["anzahlKonflikte"] as? Int)

            let konflikte = Sitzregelpruefung.pruefen(
                zuordnungen: zuordnungen,
                regeln: regeln,
                klasseId: klasseId
            )

            #expect(konflikte.count == erwarteteAnzahl, "Anzahl Konflikte in: \(name)")

            if let erwarteteIds = erwartet["regelIds"] as? [String] {
                let tatsaechlich = konflikte.compactMap { namen.name(fuer: $0.regelId) }
                #expect(tatsaechlich == erwarteteIds, "Verletzte Regeln in: \(name)")
            }
        }
    }

    @Test("Nachbarn sind ausschliesslich Plaetze desselben Moebelstuecks")
    func nachbarschaft() {
        #expect(Sitzregelpruefung.sindNachbarn("t1__sitz_1", "t1__sitz_2"))
        #expect(!Sitzregelpruefung.sindNachbarn("t1__sitz_1", "t2__sitz_1"))
        #expect(!Sitzregelpruefung.sindNachbarn("t1__sitz_1", "t1__sitz_1"),
                "Ein Platz ist nicht sein eigener Nachbar")
        #expect(!Sitzregelpruefung.sindNachbarn("kaputt", "t1__sitz_1"))
    }

    @Test("Ein Einzeltisch hat keine Nachbarn — mussNeben ist dort immer verletzt")
    func einzeltischOhneNachbarn() {
        let jetzt = Date(timeIntervalSince1970: 0)
        let klasse = UUID(), a = UUID(), b = UUID()

        let konflikte = Sitzregelpruefung.pruefen(
            zuordnungen: [
                Zuordnung(sitzplatzId: "einzel__sitz_1", schuelerId: a.uuidString),
                Zuordnung(sitzplatzId: "doppel__sitz_1", schuelerId: b.uuidString),
            ],
            regeln: [Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .mussNeben,
                               erstelltAm: jetzt, geaendertAm: jetzt)],
            klasseId: klasse
        )
        #expect(konflikte.count == 1)
    }

    @Test("Ein Schueler ohne Platz macht die Regel unbewertbar, nicht verletzt")
    func ohnePlatz() {
        let jetzt = Date(timeIntervalSince1970: 0)
        let klasse = UUID(), a = UUID(), b = UUID()

        let konflikte = Sitzregelpruefung.pruefen(
            zuordnungen: [Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: a.uuidString)],
            regeln: [
                Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .nichtNeben,
                          erstelltAm: jetzt, geaendertAm: jetzt),
                Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .mussNeben,
                          erstelltAm: jetzt, geaendertAm: jetzt),
            ],
            klasseId: klasse
        )
        #expect(konflikte.isEmpty, "Nicht gesetzt heisst nicht bewertbar")
    }

    @Test("Eine Regel fremder Klasse bleibt unberuecksichtigt")
    func fremdeKlasse() {
        let jetzt = Date(timeIntervalSince1970: 0)
        let klasse = UUID(), fremde = UUID(), a = UUID(), b = UUID()

        let konflikte = Sitzregelpruefung.pruefen(
            zuordnungen: [
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: a.uuidString),
                Zuordnung(sitzplatzId: "t1__sitz_2", schuelerId: b.uuidString),
            ],
            regeln: [Sitzregel(klasseId: fremde, schuelerA: a, schuelerB: b, art: .nichtNeben,
                               erstelltAm: jetzt, geaendertAm: jetzt)],
            klasseId: klasse
        )
        #expect(konflikte.isEmpty)
    }

    @Test("Bei doppelt gesetztem Schueler zaehlt der zuletzt eingetragene Platz")
    func doppeltGesetzt() {
        let jetzt = Date(timeIntervalSince1970: 0)
        let klasse = UUID(), a = UUID(), b = UUID()
        let regel = Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .nichtNeben,
                              erstelltAm: jetzt, geaendertAm: jetzt)

        // a sitzt zuerst neben b, dann woanders. Der zweite Eintrag gewinnt.
        let entschaerft = Sitzregelpruefung.pruefen(
            zuordnungen: [
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: a.uuidString),
                Zuordnung(sitzplatzId: "t1__sitz_2", schuelerId: b.uuidString),
                Zuordnung(sitzplatzId: "t9__sitz_1", schuelerId: a.uuidString),
            ],
            regeln: [regel],
            klasseId: klasse
        )
        #expect(entschaerft.isEmpty)

        // Dieselben Eintraege in anderer Reihenfolge — jetzt sitzt a am Ende
        // doch neben b. Wer hier ein Dictionary verwendet, bekommt Zufall.
        let verletzt = Sitzregelpruefung.pruefen(
            zuordnungen: [
                Zuordnung(sitzplatzId: "t9__sitz_1", schuelerId: a.uuidString),
                Zuordnung(sitzplatzId: "t1__sitz_2", schuelerId: b.uuidString),
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: a.uuidString),
            ],
            regeln: [regel],
            klasseId: klasse
        )
        #expect(verletzt.count == 1)
    }

    @Test("Widersprechende Regeln werden einzeln bewertet, nicht aufgeloest")
    func widerspruch() {
        let jetzt = Date(timeIntervalSince1970: 0)
        let klasse = UUID(), a = UUID(), b = UUID()

        let konflikte = Sitzregelpruefung.pruefen(
            zuordnungen: [
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: a.uuidString),
                Zuordnung(sitzplatzId: "t1__sitz_2", schuelerId: b.uuidString),
            ],
            regeln: [
                Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .nichtNeben,
                          erstelltAm: jetzt, geaendertAm: jetzt),
                Sitzregel(klasseId: klasse, schuelerA: a, schuelerB: b, art: .mussNeben,
                          erstelltAm: jetzt, geaendertAm: jetzt),
            ],
            klasseId: klasse
        )
        #expect(konflikte.count == 1, "Genau eine der beiden ist verletzt")
        #expect(konflikte.first?.art == .nichtNeben)
    }
}
