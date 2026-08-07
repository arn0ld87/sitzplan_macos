import Domain
import Foundation
import Speicher
import SwiftData

/// Die Abhaengigkeiten der Anwendung, an einer Stelle gebuendelt.
///
/// Wird per Initialisierer gereicht — kein DI-Framework, keine globalen
/// veraenderlichen Singletons. Eine Ansicht bekommt, was sie braucht, und laesst
/// sich damit ohne Datenbank pruefen.
@MainActor
public final class AppEnvironment {
    public let klassen: any KlassenRepository
    public let schueler: any SchuelerRepository
    public let sitzregeln: any SitzregelRepository

    public init(
        klassen: any KlassenRepository,
        schueler: any SchuelerRepository,
        sitzregeln: any SitzregelRepository
    ) {
        self.klassen = klassen
        self.schueler = schueler
        self.sitzregeln = sitzregeln
    }
}
