import Domain
import Foundation
import SwiftData

/// Das Sitzregel-Repository gegen SwiftData.
@ModelActor
public actor SitzregelSpeicher: SitzregelRepository {

    // MARK: - Lesen

    /// Aktive Regeln der Klasse — weich gelöschte werden nicht zurückgegeben.
    public func derKlasse(_ klasseId: UUID) throws(Domaenenfehler) -> [Sitzregel] {
        guard let kl = try klasseneintrag(id: klasseId) else { return [] }
        return (kl.sitzregeln ?? [])
            .filter { $0.geloeschtAm == nil }
            .map { $0.alsDomaene() }
    }

    // MARK: - Schreiben

    @discardableResult
    public func anlegen(_ regel: Sitzregel) throws(Domaenenfehler) -> Sitzregel {
        guard let kl = try klasseneintrag(id: regel.klasseId) else {
            throw .nichtGefunden(art: "Die Klasse")
        }
        let eintrag = SitzregelEintrag(
            id: regel.id,
            schuelerA: regel.schuelerA,
            schuelerB: regel.schuelerB,
            art: regel.art,
            erstelltAm: regel.erstelltAm,
            geaendertAm: regel.geaendertAm,
            klasse: kl
        )
        modelContext.insert(eintrag)
        try sichern()
        return eintrag.alsDomaene()
    }

    public func loeschen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try regelEintrag(id: id) else {
            throw .nichtGefunden(art: "Die Sitzregel")
        }
        let jetzt = Date()
        eintrag.geloeschtAm = SoftDelete.loeschzeitpunkt(bisher: eintrag.geloeschtAm, jetzt: jetzt)
        eintrag.geaendertAm = jetzt
        try sichern()
    }

    // MARK: - Innen

    private func regelEintrag(id: UUID) throws(Domaenenfehler) -> SitzregelEintrag? {
        var abfrage = FetchDescriptor<SitzregelEintrag>(predicate: #Predicate { $0.id == id })
        abfrage.fetchLimit = 1
        return try holen(abfrage).first
    }

    private func klasseneintrag(id: UUID) throws(Domaenenfehler) -> KlassenEintrag? {
        var abfrage = FetchDescriptor<KlassenEintrag>(predicate: #Predicate { $0.id == id })
        abfrage.fetchLimit = 1
        return try holen(abfrage).first
    }

    private func holen<T: PersistentModel>(
        _ abfrage: FetchDescriptor<T>
    ) throws(Domaenenfehler) -> [T] {
        do {
            return try modelContext.fetch(abfrage)
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }
    }

    private func sichern() throws(Domaenenfehler) {
        do {
            try modelContext.save()
        } catch {
            throw .speichernGescheitert(grund: String(describing: error))
        }
    }
}
