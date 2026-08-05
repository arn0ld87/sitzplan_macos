import Domain
import Foundation
import Observation

/// Der Zustand der Klassenansicht.
///
/// Haelt keine Geschaeftslogik — die liegt in `Domain` — und keinen
/// `ModelContext`. Es kennt nur das Repository-Protokoll und laesst sich damit
/// ohne Datenbank pruefen.
@MainActor
@Observable
public final class KlassenModell {
    public enum Zustand: Equatable {
        case laedt
        case leer
        case gefuellt
        case fehler(String)
    }

    public private(set) var zustand: Zustand = .laedt
    public private(set) var klassen: [Klasse] = []
    public private(set) var papierkorb: [Papierkorbeintrag] = []

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

    private let repository: any KlassenRepository

    public init(repository: any KlassenRepository) {
        self.repository = repository
    }

    public func laden() async {
        do {
            let geladen = try await repository.aktive()
            let korb = try await repository.geloeschte()
            klassen = geladen
            papierkorb = korb
            zustand = geladen.isEmpty ? .leer : .gefuellt
        } catch {
            zustand = .fehler(error.beschreibung)
            meldung = Meldung(error)
        }
    }

    public func anlegen(name: String) async -> Bool {
        do {
            try await repository.anlegen(name: name, notizen: nil)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func umbenennen(_ klasse: Klasse, auf name: String) async -> Bool {
        do {
            try await repository.umbenennen(id: klasse.id, auf: name)
            await laden()
            return true
        } catch {
            meldung = Meldung(error)
            return false
        }
    }

    public func loeschen(_ klasse: Klasse) async {
        do {
            try await repository.loeschen(id: klasse.id)
            await laden()
        } catch {
            meldung = Meldung(error)
        }
    }

    public func wiederherstellen(_ eintrag: Papierkorbeintrag) async {
        do {
            try await repository.wiederherstellen(id: eintrag.id)
            await laden()
        } catch {
            meldung = Meldung(error)
        }
    }
}
