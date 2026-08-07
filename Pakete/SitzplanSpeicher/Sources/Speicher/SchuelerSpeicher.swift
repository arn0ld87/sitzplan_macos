import Domain
import Foundation
import SwiftData

/// Das Schüler-Repository gegen SwiftData.
///
/// `@ModelActor` isoliert den `ModelContext` — nebenlaeufig sicher, die
/// Oberflaeche kennt nur das Repository-Protokoll.
@ModelActor
public actor SchuelerSpeicher: SchuelerRepository {

    // MARK: - Lesen

    /// Schüler der Klasse, gefiltert nach Soft-Delete-Regel:
    /// aktive Klasse → nur nicht gelöschte; gelöschte Klasse → nur die mit
    /// identischem Zeitstempel (Begruendung in `SoftDelete.schuelerDerKlasse`).
    public func derKlasse(_ klasseId: UUID) throws(Domaenenfehler) -> [Schueler] {
        guard let klasseneintrag = try klasseneintrag(id: klasseId) else { return [] }
        let klasse = klasseneintrag.alsDomaene()
        let alle = (klasseneintrag.schueler ?? []).map { $0.alsDomaene() }
        return SoftDelete.schuelerDerKlasse(klasse, schueler: alle)
            .sorted { ($0.nachname, $0.vorname) < ($1.nachname, $1.vorname) }
    }

    // MARK: - Schreiben

    @discardableResult
    public func anlegen(_ schueler: Schueler) throws(Domaenenfehler) -> Schueler {
        guard let kl = try klasseneintrag(id: schueler.klasseId) else {
            throw .nichtGefunden(art: "Die Klasse")
        }
        let eintrag = SchuelerEintrag(
            id: schueler.id,
            vorname: schueler.vorname,
            nachname: schueler.nachname,
            initialen: schueler.initialen,
            farbIndex: schueler.farbIndex,
            merkmaleRoh: schueler.merkmale.map(\.rawValue),
            notiz: schueler.notiz,
            erstelltAm: schueler.erstelltAm,
            geaendertAm: schueler.geaendertAm,
            klasse: kl
        )
        modelContext.insert(eintrag)
        try sichern()
        return eintrag.alsDomaene()
    }

    @discardableResult
    public func aktualisieren(_ schueler: Schueler) throws(Domaenenfehler) -> Schueler {
        guard let eintrag = try schuelerEintrag(id: schueler.id) else {
            throw .nichtGefunden(art: "Der Schüler")
        }
        eintrag.vorname = schueler.vorname
        eintrag.nachname = schueler.nachname
        eintrag.initialen = schueler.initialen
        eintrag.farbIndex = schueler.farbIndex
        eintrag.merkmaleRoh = schueler.merkmale.map(\.rawValue)
        eintrag.notiz = schueler.notiz
        eintrag.geaendertAm = Date()
        try sichern()
        return eintrag.alsDomaene()
    }

    public func loeschen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try schuelerEintrag(id: id) else {
            throw .nichtGefunden(art: "Der Schüler")
        }
        let jetzt = Date()
        eintrag.geloeschtAm = SoftDelete.loeschzeitpunkt(bisher: eintrag.geloeschtAm, jetzt: jetzt)
        eintrag.geaendertAm = jetzt
        try sichern()
    }

    public func wiederherstellen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try schuelerEintrag(id: id) else {
            throw .nichtGefunden(art: "Der Schüler")
        }
        eintrag.geloeschtAm = nil
        eintrag.geaendertAm = Date()
        try sichern()
    }

    // MARK: - Innen

    private func schuelerEintrag(id: UUID) throws(Domaenenfehler) -> SchuelerEintrag? {
        var abfrage = FetchDescriptor<SchuelerEintrag>(predicate: #Predicate { $0.id == id })
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
