import Domain
import Foundation
import Observation

/// Der Zustand der Schülerliste einer Klasse.
///
/// Haelt keine Geschaeftslogik — die liegt in `Domain` — und keinen
/// `ModelContext`. Bekannt sind nur die Repository-Protokolle.
@MainActor
@Observable
public final class SchuelerModell {
    public enum Zustand: Equatable {
        case laedt
        case leer
        case gefuellt
        case fehler(String)
    }

    public private(set) var zustand: Zustand = .laedt
    public private(set) var schueler: [Schueler] = []
    public private(set) var sitzregeln: [Sitzregel] = []
    public var meldung: Meldung?

    public struct Meldung: Identifiable, Equatable {
        public let id = UUID()
        public let text: String
        public let vorschlag: String?

        init(_ fehler: Domaenenfehler) {
            text = fehler.beschreibung
            vorschlag = fehler.vorschlag
        }
    }

    public let klasseId: UUID
    private let schuelerRepo: any SchuelerRepository
    private let sitzregelRepo: any SitzregelRepository

    public init(
        klasseId: UUID,
        schuelerRepo: any SchuelerRepository,
        sitzregelRepo: any SitzregelRepository
    ) {
        self.klasseId = klasseId
        self.schuelerRepo = schuelerRepo
        self.sitzregelRepo = sitzregelRepo
    }

    public func laden() async {
        do {
            let geladen = try await schuelerRepo.derKlasse(klasseId)
            let regeln = try await sitzregelRepo.derKlasse(klasseId)
            schueler = geladen
            sitzregeln = regeln
            zustand = geladen.isEmpty ? .leer : .gefuellt
        } catch {
            zustand = .fehler(error.beschreibung)
            meldung = Meldung(error)
        }
    }

    public func anlegen(
        vorname: String,
        nachname: String,
        farbIndex: Int,
        merkmale: [Merkmal],
        notiz: String?
    ) async -> Bool {
        let jetzt = Date()
        let neu = Schueler(
            klasseId: klasseId,
            vorname: vorname,
            nachname: nachname,
            farbIndex: farbIndex,
            merkmale: merkmale,
            notiz: notiz.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 },
            erstelltAm: jetzt,
            geaendertAm: jetzt
        )
        do {
            try await schuelerRepo.anlegen(neu)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func aktualisieren(_ schueler: Schueler) async -> Bool {
        var geaendert = schueler
        geaendert.geaendertAm = Date()
        do {
            try await schuelerRepo.aktualisieren(geaendert)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func loeschen(_ schueler: Schueler) async {
        do {
            try await schuelerRepo.loeschen(id: schueler.id)
            await laden()
        } catch {
            meldung = Meldung(error)
        }
    }

    public func regelAnlegen(
        schuelerA: UUID,
        schuelerB: UUID,
        art: Regelart
    ) async -> Bool {
        let jetzt = Date()
        let regel = Sitzregel(
            klasseId: klasseId,
            schuelerA: schuelerA,
            schuelerB: schuelerB,
            art: art,
            erstelltAm: jetzt,
            geaendertAm: jetzt
        )
        do {
            try await sitzregelRepo.anlegen(regel)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func regelLoeschen(_ regel: Sitzregel) async {
        do {
            try await sitzregelRepo.loeschen(id: regel.id)
            await laden()
        } catch {
            meldung = Meldung(error)
        }
    }

    /// Name eines Schülers für die Anzeige in Sitzregeln.
    public func name(fuer id: UUID) -> String {
        schueler.first(where: { $0.id == id })?.vollerName ?? "Unbekannt"
    }
}
