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

    public init(klassen: any KlassenRepository) {
        self.klassen = klassen
    }

    /// Die Umgebung fuer den laufenden Betrieb: echter Speicher unter
    /// Application Support.
    public static func echt() throws(Domaenenfehler) -> AppEnvironment {
        let container = try Speicher.container()
        return AppEnvironment(klassen: KlassenSpeicher(modelContainer: container))
    }

    /// Die Umgebung fuer Tests und Vorschauen: alles im Arbeitsspeicher.
    ///
    /// Ausdruecklich getrennt benannt, damit sie nie versehentlich im Produkt
    /// landet.
    public static func imArbeitsspeicher() throws(Domaenenfehler) -> AppEnvironment {
        let container = try Speicher.containerImArbeitsspeicher()
        return AppEnvironment(klassen: KlassenSpeicher(modelContainer: container))
    }
}
