import Domain
import Foundation
import SwiftData
import Testing

@testable import Speicher

/// Das fachliche Dokument liegt als `Codable`-Wert am Model. Diese Suite
/// belegt, dass es die Rundreise durch SwiftData unveraendert uebersteht — sonst
/// waere die ganze Konstruktion aus ADR-0002 hinfaellig.
@Suite("Dokumente im Speicher")
struct DokumentRundreiseTests {

    @Test("Ein RaumDokument uebersteht Speichern und Laden unveraendert")
    @MainActor
    func raumDokument() throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let kontext = container.mainContext

        let dokument = RaumDokument(
            objekte: [
                Raumobjekt(id: "t1", typ: .doppeltisch, xCm: 100, yCm: 200, drehung: .neunzig),
                Raumobjekt(id: "t2", typ: .einzeltisch, xCm: 300, yCm: 200),
            ],
            sitzplaetze: Moebeltyp.doppeltisch.sitzplaetze(objektId: "t1")
                + Moebeltyp.einzeltisch.sitzplaetze(objektId: "t2")
        )

        let eintrag = RaumEintrag(
            name: "B204",
            breiteCm: 720,
            laengeCm: 520,
            rasterCm: 25,
            dokument: dokument,
            erstelltAm: Date(),
            geaendertAm: Date()
        )
        kontext.insert(eintrag)
        try kontext.save()

        let id = eintrag.id
        let geladen = try kontext.fetch(
            FetchDescriptor<RaumEintrag>(predicate: #Predicate { $0.id == id })
        )
        let zurueck = try #require(geladen.first)

        #expect(zurueck.dokument == dokument)
        #expect(zurueck.dokument.objekte.count == 2)
        #expect(zurueck.dokument.sitzplaetze.count == 3)
        #expect(zurueck.dokument.objekte.first?.drehung == .neunzig)
        #expect(zurueck.alsDomaene().dokument == dokument)
    }

    @Test("Ein PlanDokument behaelt die Reihenfolge seiner Zuordnungen")
    @MainActor
    func planDokumentReihenfolge() throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let kontext = container.mainContext

        // Zwei Zuordnungen auf denselben Platz. Die Reihenfolge entscheidet,
        // wer gewinnt — wenn SwiftData sie verlieren wuerde, waere das Ergebnis
        // beim naechsten Laden ein anderes.
        let dokument = PlanDokument(
            quelle: Planquelle(klasseId: "k1", raumId: "r1"),
            raumGeometrie: Raumgeometrie(breiteCm: 720, laengeCm: 520, rasterCm: 25),
            zuordnungen: [
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: "erster"),
                Zuordnung(sitzplatzId: "t1__sitz_1", schuelerId: "zweiter"),
                Zuordnung(sitzplatzId: "t1__sitz_2", schuelerId: "dritter"),
            ]
        )

        let eintrag = SitzplanEintrag(
            klasseId: UUID(),
            raumId: UUID(),
            name: "Deutsch 7a",
            status: .aktiv,
            dokument: dokument,
            erstelltAm: Date(),
            geaendertAm: Date()
        )
        kontext.insert(eintrag)
        try kontext.save()

        let id = eintrag.id
        let geladen = try kontext.fetch(
            FetchDescriptor<SitzplanEintrag>(predicate: #Predicate { $0.id == id })
        )
        let zurueck = try #require(geladen.first)

        #expect(zurueck.dokument.zuordnungen.map(\.schuelerId) == ["erster", "zweiter", "dritter"])
        #expect(zurueck.dokument.zuordnungenAlsWoerterbuch()["t1__sitz_1"] == "zweiter",
                "Der letzte gewinnt — und dafuer muss die Reihenfolge erhalten bleiben")
    }

    @Test("Ein leeres Dokument ist der Vorgabewert")
    @MainActor
    func vorgabewert() throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let kontext = container.mainContext

        let eintrag = RaumEintrag(
            name: "leer",
            breiteCm: 720,
            laengeCm: 520,
            rasterCm: 25,
            erstelltAm: Date(),
            geaendertAm: Date()
        )
        kontext.insert(eintrag)
        try kontext.save()

        #expect(eintrag.dokument.objekte.isEmpty)
        #expect(eintrag.dokument.sitzplaetze.isEmpty)
        #expect(eintrag.dokumentVersion == RaumDokument.version)
        #expect(eintrag.dokumentVersion == 3)
    }

    @Test("Unbekannte Merkmale gehen beim Lesen nicht verloren")
    @MainActor
    func unbekannteMerkmale() throws {
        let container = try Speicher.containerImArbeitsspeicher()
        let kontext = container.mainContext

        let klasse = KlassenEintrag(name: "7a", erstelltAm: Date(), geaendertAm: Date())
        kontext.insert(klasse)

        let schueler = SchuelerEintrag(
            vorname: "Alva",
            nachname: "Birkner",
            initialen: "AB",
            farbIndex: 0,
            merkmaleRoh: ["adhs", "aus_einer_spaeteren_version"],
            erstelltAm: Date(),
            geaendertAm: Date(),
            klasse: klasse
        )
        kontext.insert(schueler)
        try kontext.save()

        // In der Domaene taucht nur das Bekannte auf …
        #expect(schueler.alsDomaene().merkmale == [.adhs])
        // … im Speicher bleibt aber beides stehen.
        #expect(schueler.merkmaleRoh.count == 2)
    }

    @Test("Der farbIndex bleibt im vertraglichen Bereich")
    func farbIndex() {
        let jetzt = Date()
        let zuGross = Schueler(klasseId: UUID(), vorname: "A", nachname: "B",
                               farbIndex: 99, erstelltAm: jetzt, geaendertAm: jetzt)
        let zuKlein = Schueler(klasseId: UUID(), vorname: "A", nachname: "B",
                               farbIndex: -3, erstelltAm: jetzt, geaendertAm: jetzt)
        #expect(zuGross.farbIndex == 7)
        #expect(zuKlein.farbIndex == 0)
    }

    @Test("Initialen werden aus dem Namen abgeleitet, wenn keine angegeben sind")
    func initialen() {
        let jetzt = Date()
        let s = Schueler(klasseId: UUID(), vorname: "Alva", nachname: "Birkner",
                         erstelltAm: jetzt, geaendertAm: jetzt)
        #expect(s.initialen == "AB")
        #expect(s.vollerName == "Alva Birkner")
    }
}
