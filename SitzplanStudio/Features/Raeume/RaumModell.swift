import Domain
import Foundation
import Observation

/// Der Zustand der Raumansicht.
///
/// Haelt keine Geschaeftslogik — die liegt in `Domain` — und keinen
/// `ModelContext`. Es kennt nur das Repository-Protokoll und laesst sich damit
/// ohne Datenbank pruefen.
///
/// Kein Papierkorb in dieser Iteration: Räume sind selten, ein Soft-Delete-UI
/// ist nicht nötig. Das Repository loescht dennoch weich, damit ein spaeterer
/// Papierkorb die Daten vorfindet.
@MainActor
@Observable
public final class RaumModell {
    public enum Zustand: Equatable {
        case laedt
        case leer
        case gefuellt
        case fehler(String)
    }

    public private(set) var zustand: Zustand = .laedt
    public private(set) var raeume: [Raum] = []

    /// Ein Fehler, den die Lehrkraft bestaetigen muss. Nie stillschweigend
    /// verworfen.
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

    private let repository: any RaumRepository

    public init(repository: any RaumRepository) {
        self.repository = repository
    }

    public func laden() async {
        do {
            let geladen = try await repository.aktive()
            raeume = geladen
            zustand = geladen.isEmpty ? .leer : .gefuellt
        } catch {
            zustand = .fehler(error.beschreibung)
            meldung = Meldung(error)
        }
    }

    /// Legt einen Raum an und gibt ihn zurück, damit die Übersicht ihn auswählen
    /// kann. Bei fachlichem Fehler `nil` — die Meldung steht in ``meldung``.
    @discardableResult
    public func anlegen(
        name: String,
        breiteCm: Double,
        laengeCm: Double,
        rasterCm: Double = Raster.standard
    ) async -> Raum? {
        let bereinigt = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let jetzt = Date()
            let raum = Raum(
                name: bereinigt,
                breiteCm: breiteCm,
                laengeCm: laengeCm,
                rasterCm: rasterCm,
                erstelltAm: jetzt,
                geaendertAm: jetzt
            )
            let angelegt = try await repository.anlegen(raum)
            await laden()
            return angelegt
        } catch {
            meldung = Meldung(error)
            return nil
        }
    }

    public func aktualisieren(_ raum: Raum) async -> Bool {
        do {
            try await repository.aktualisieren(raum)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func loeschen(_ raum: Raum) async {
        do {
            try await repository.loeschen(id: raum.id)
            await laden()
        } catch {
            meldung = Meldung(error)
        }
    }
}