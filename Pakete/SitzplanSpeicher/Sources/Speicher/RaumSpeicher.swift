import Domain
import Foundation
import SwiftData

/// Das Raum-Repository gegen SwiftData.
///
/// `@ModelActor` isoliert den `ModelContext` — damit ist der Zugriff im
/// Swift-6-Sprachmodus nebenlaeufig sicher, ohne dass die Oberflaeche etwas
/// davon wissen muss.
///
/// Räume haben keine Kinder: Ein Soft-Delete setzt nur den Zeitstempel, niemand
/// geht mit. Dennoch wird ``SoftDelete.loeschzeitpunkt(bisher:jetzt:)`` benutzt,
/// damit ein zweites Loeschen den Zeitstempel nicht verschiebt — die
/// Papierkorbreihenfolge bleibt stabil, falls spaeter ein Papierkorb dazukommt.
@ModelActor
public actor RaumSpeicher: RaumRepository {

    // MARK: - Lesen

    public func aktive() throws(Domaenenfehler) -> [Raum] {
        // `geloeschtAm == nil` gehoert in **jede** Leseabfrage auf Nutzdaten.
        // Es steht hier im Praedikat und nicht in einem Filter danach, damit
        // niemand es beim Umbauen versehentlich verliert.
        let abfrage = FetchDescriptor<RaumEintrag>(
            predicate: #Predicate { $0.geloeschtAm == nil },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try holen(abfrage).map { $0.alsDomaene() }
    }

    public func raum(id: UUID) throws(Domaenenfehler) -> Raum? {
        try eintrag(id: id)?.alsDomaene()
    }

    // MARK: - Schreiben

    @discardableResult
    public func anlegen(_ raum: Raum) throws(Domaenenfehler) -> Raum {
        // Masse und Raster sind Vertrag. Ohne Datenbank gibt es niemanden, der
        // eine `CHECK`-Bedingung erzwinge — also tut es die Speicherschicht,
        // als letzte Verteidigungslinie vor den Werten der Oberflaeche.
        try Raum.pruefeMasse(breiteCm: raum.breiteCm, laengeCm: raum.laengeCm, rasterCm: raum.rasterCm)

        let eintrag = RaumEintrag(
            id: raum.id,
            name: raum.name,
            breiteCm: raum.breiteCm,
            laengeCm: raum.laengeCm,
            rasterCm: raum.rasterCm,
            dokument: raum.dokument,
            dokumentVersion: raum.dokumentVersion,
            erstelltAm: raum.erstelltAm,
            geaendertAm: raum.geaendertAm,
            geloeschtAm: raum.geloeschtAm
        )
        modelContext.insert(eintrag)
        try sichern()
        return eintrag.alsDomaene()
    }

    @discardableResult
    public func aktualisieren(_ raum: Raum) throws(Domaenenfehler) -> Raum {
        try Raum.pruefeMasse(breiteCm: raum.breiteCm, laengeCm: raum.laengeCm, rasterCm: raum.rasterCm)

        guard let eintrag = try eintrag(id: raum.id) else {
            throw .nichtGefunden(art: "Der Raum")
        }
        eintrag.name = raum.name
        eintrag.breiteCm = raum.breiteCm
        eintrag.laengeCm = raum.laengeCm
        eintrag.rasterCm = raum.rasterCm
        eintrag.dokument = raum.dokument
        eintrag.dokumentVersion = raum.dokumentVersion
        eintrag.geaendertAm = Date()
        try sichern()
        return eintrag.alsDomaene()
    }

    public func loeschen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Der Raum")
        }
        let jetzt = Date()
        eintrag.geloeschtAm = SoftDelete.loeschzeitpunkt(bisher: eintrag.geloeschtAm, jetzt: jetzt)
        eintrag.geaendertAm = jetzt
        try sichern()
    }

    public func wiederherstellen(id: UUID) throws(Domaenenfehler) {
        guard let eintrag = try eintrag(id: id) else {
            throw .nichtGefunden(art: "Der Raum")
        }
        eintrag.geloeschtAm = nil
        eintrag.geaendertAm = Date()
        try sichern()
    }

    // MARK: - Innen

    private func eintrag(id: UUID) throws(Domaenenfehler) -> RaumEintrag? {
        var abfrage = FetchDescriptor<RaumEintrag>(predicate: #Predicate { $0.id == id })
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