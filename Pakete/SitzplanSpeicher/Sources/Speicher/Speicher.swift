import Core
import Domain
import Foundation
import SwiftData

/// Der lokale Speicher.
///
/// Ein `ModelContainer` unter `~/Library/Application Support/SitzplanStudio/`.
/// Kein Netz, kein Konto, keine Migration von irgendwo — die Daten gehoeren dem
/// Rechner, auf dem sie liegen.
public enum Speicher {
    /// Oeffnet den Speicher am vorgesehenen Ort.
    ///
    /// Schlaegt das fehl, ist das ein Fall fuer die Oberflaeche und nicht fuer
    /// einen stillen Rueckfall auf einen Speicher im Arbeitsspeicher: Eine
    /// Anwendung, die scheinbar arbeitet und beim Beenden alles vergisst, ist
    /// schlimmer als eine, die sich beschwert.
    public static func container() throws(Domaenenfehler) -> ModelContainer {
        guard let ordner = Ablage.verzeichnis() else {
            throw .speicherNichtVerfuegbar(grund: "Application Support nicht auffindbar")
        }

        do {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }

        let konfiguration = ModelConfiguration(
            url: ordner.appendingPathComponent(Ablage.datenbankname)
        )

        do {
            return try ModelContainer(
                for: SwiftData.Schema(Speicher.Schema.modelle),
                configurations: konfiguration
            )
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }
    }

    /// Ein Speicher im Arbeitsspeicher — fuer Tests und Vorschauen.
    ///
    /// Ausdruecklich getrennt benannt, damit er nie versehentlich im Produkt
    /// landet.
    public static func containerImArbeitsspeicher() throws(Domaenenfehler) -> ModelContainer {
        do {
            return try ModelContainer(
                for: SwiftData.Schema(Speicher.Schema.modelle),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }
    }
}

extension Speicher {
    /// Das Schema, getrennt vom Namensraum `SwiftData.Schema`.
    public enum Schema {
        public static let modelle: [any PersistentModel.Type] = [
            KlassenEintrag.self,
            SchuelerEintrag.self,
            SitzregelEintrag.self,
            RaumEintrag.self,
            SitzplanEintrag.self,
            SitzplanVersionEintrag.self,
        ]
    }
}
