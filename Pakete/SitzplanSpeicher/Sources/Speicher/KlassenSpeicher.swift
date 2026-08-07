import Domain
import Foundation
import SwiftData

/// Das Klassen-Repository gegen SwiftData.
///
/// `@ModelActor` isoliert den `ModelContext` — damit ist der Zugriff im
/// Swift-6-Sprachmodus nebenlaeufig sicher, ohne dass die Oberflaeche etwas
/// davon wissen muss.
@ModelActor
public actor KlassenSpeicher: KlassenRepository {

    // MARK: - Lesen

    public func aktive() throws(Domaenenfehler) -> [Klasse] {
        // `geloeschtAm == nil` gehoert in **jede** Leseabfrage auf Nutzdaten.
        // Es steht hier im Prädikat und nicht in einem Filter danach, damit
        // niemand es beim Umbauen versehentlich verliert.
        let abfrage = FetchDescriptor<KlassenEintrag>(
            predicate: #Predicate { $0.geloeschtAm == nil },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try holen(abfrage).map { $0.alsDomaene() }
    }

    public func klasse(id: UUID) throws(Domaenenfehler) -> Klasse? {
        try eintrag(id: id)?.alsDomaene()
    }

    /// Nur geloeschte Klassen — eine **eigene** Methode, kein Schalter an
    /// ``aktive()``.
    public func geloeschte() throws(Domaenenfehler) -> [Papierkorbeintrag] {
        let abfrage = FetchDescriptor<KlassenEintrag>(
            predicate: #Predicate { $0.geloeschtAm != nil }
        )
        let eintraege = try holen(abfrage)

        return eintraege.compactMap { eintrag -> Papierkorbeintrag? in
            guard let geloeschtAm = eintrag.geloeschtAm else { return nil }
            let mitgegangene = SoftDelete.schuelerDerKlasse(
                eintrag.alsDomaene(),
                schueler: (eintrag.schueler ?? []).map { $0.alsDomaene() }
            )
            return Papierkorbeintrag(
                id: eintrag.id,
                art: .klasse,
                bezeichnung: eintrag.name,
                geloeschtAm: geloeschtAm,
                mitgeloeschteAnzahl: mitgegangene.count
            )
        }
        .inPapierkorbreihenfolge()
    }

    // MARK: - Schreiben

    @discardableResult
    public func anlegen(name: String, notizen: String?) throws(Domaenenfehler) -> Klasse {
        let geprueft = try Klasse.pruefeName(name)
        let jetzt = Date()

        let eintrag = KlassenEintrag(
            name: geprueft,
            notizen: notizen,
            erstelltAm: jetzt,
            geaendertAm: jetzt
        )
        modelContext.insert(eintrag)
        try sichern()
        return eintrag.alsDomaene()
    }

    @discardableResult
    public func umbenennen(id: UUID, auf name: String) throws(Domaenenfehler) -> Klasse {
        let geprueft = try Klasse.pruefeName(name)
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Die Klasse")
        }
        eintrag.name = geprueft
        eintrag.geaendertAm = Date()
        try sichern()
        return eintrag.alsDomaene()
    }

    /// Weich loeschen.
    ///
    /// - Important: Die Schueler gehen mit **demselben** Zeitstempel mit. Genau
    ///   daran erkennt das Wiederherstellen sie spaeter wieder. Wer hier je
    ///   Schueler einen eigenen `Date()` nimmt, macht den Papierkorb kaputt —
    ///   die Klasse kaeme leer zurueck.
    ///
    ///   Ein bereits geloeschter Schueler behaelt seinen aelteren Zeitstempel
    ///   und bleibt damit geloescht.
    public func loeschen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Die Klasse")
        }

        let jetzt = Date()
        let zeitpunkt = SoftDelete.loeschzeitpunkt(bisher: eintrag.geloeschtAm, jetzt: jetzt)

        eintrag.geloeschtAm = zeitpunkt
        eintrag.geaendertAm = jetzt

        for schueler in eintrag.schueler ?? [] where schueler.geloeschtAm == nil {
            schueler.geloeschtAm = zeitpunkt
            schueler.geaendertAm = jetzt
        }
        for regel in eintrag.sitzregeln ?? [] where regel.geloeschtAm == nil {
            regel.geloeschtAm = zeitpunkt
            regel.geaendertAm = jetzt
        }

        try sichern()
    }

    /// Wiederherstellen.
    ///
    /// Zurueck kommen nur die Schueler, die mit **dieser** Loeschung gegangen
    /// sind — erkennbar am identischen Zeitstempel. Wer vorher einzeln geloescht
    /// wurde, traegt einen aelteren und bleibt geloescht.
    public func wiederherstellen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Die Klasse")
        }
        guard let zeitpunkt = eintrag.geloeschtAm else { return }

        let jetzt = Date()
        eintrag.geloeschtAm = nil
        eintrag.geaendertAm = jetzt

        for schueler in eintrag.schueler ?? [] where schueler.geloeschtAm == zeitpunkt {
            schueler.geloeschtAm = nil
            schueler.geaendertAm = jetzt
        }
        for regel in eintrag.sitzregeln ?? [] where regel.geloeschtAm == zeitpunkt {
            regel.geloeschtAm = nil
            regel.geaendertAm = jetzt
        }

        try sichern()
    }

    /// Endgueltig entfernen. Der einzige Ort, an dem `delete(_:)` erlaubt ist.
    public func endgueltigEntfernen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Die Klasse")
        }
        guard eintrag.geloeschtAm != nil else {
            throw .ungueltigeEingabe(
                feld: "Klasse",
                grund: "Nur etwas, das im Papierkorb liegt, kann endgültig entfernt werden."
            )
        }
        modelContext.delete(eintrag)
        try sichern()
    }

    // MARK: - Innen

    private func eintrag(id: UUID) throws(Domaenenfehler) -> KlassenEintrag? {
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
