import Core
import Domain
import Foundation
import SwiftData

/// Der lokale Speicher.
///
/// Ein `ModelContainer` unter `~/Library/Application Support/SitzplanStudio/`.
/// Kein Netz, kein Konto, keine Synchronisation — die Daten gehoeren dem
/// Rechner, auf dem sie liegen.
public enum Speicher {

    /// Wo der Speicher liegt.
    public enum Ort: Sendable {
        /// Der vorgesehene Ort: `~/Library/Application Support/SitzplanStudio/`.
        case anwendungsordner

        /// Ein bestimmtes Verzeichnis.
        ///
        /// Gebraucht fuer den Neustarttest, der einen **persistenten**, aber
        /// isolierten Speicher braucht: Ein Speicher im Arbeitsspeicher kann
        /// nicht belegen, dass etwas einen Neustart uebersteht — er vergisst
        /// absichtlich alles.
        case verzeichnis(URL)

        /// Nur im Arbeitsspeicher — fuer Unit-Tests und Vorschauen.
        case arbeitsspeicher
    }

    /// Oeffnet den Speicher.
    ///
    /// Schlaegt das fehl, ist das ein Fall fuer die Oberflaeche und nicht fuer
    /// einen stillen Rueckfall auf den Arbeitsspeicher: Eine Anwendung, die
    /// scheinbar arbeitet und beim Beenden alles vergisst, ist schlimmer als
    /// eine, die sich beschwert.
    public static func container(
        _ ort: Ort = .anwendungsordner
    ) throws(Domaenenfehler) -> ModelContainer {
        let konfiguration: ModelConfiguration

        switch ort {
        case .arbeitsspeicher:
            konfiguration = ModelConfiguration(isStoredInMemoryOnly: true)

        case .verzeichnis(let ordner):
            try ordnerAnlegen(ordner)
            konfiguration = ModelConfiguration(
                url: ordner.appendingPathComponent(Ablage.datenbankname)
            )

        case .anwendungsordner:
            guard let ordner = Ablage.verzeichnis() else {
                throw .speicherNichtVerfuegbar(grund: "Application Support nicht auffindbar")
            }
            try ordnerAnlegen(ordner)
            konfiguration = ModelConfiguration(
                url: ordner.appendingPathComponent(Ablage.datenbankname)
            )
        }

        do {
            // Ueber das versionierte Schema und den Migrationsplan, nicht ueber
            // eine lose Modelliste: Ohne Server ist diese Datei die einzige
            // Kopie der Daten. Siehe `Schemaversionen.swift`.
            return try ModelContainer(
                for: SwiftData.Schema(versionedSchema: SchemaV1.self),
                migrationPlan: Migrationsplan.self,
                configurations: konfiguration
            )
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }
    }

    /// Ein Speicher im Arbeitsspeicher — fuer Unit-Tests und Vorschauen.
    ///
    /// Ausdruecklich getrennt benannt, damit er nie versehentlich im Produkt
    /// landet.
    public static func containerImArbeitsspeicher() throws(Domaenenfehler) -> ModelContainer {
        try container(.arbeitsspeicher)
    }

    private static func ordnerAnlegen(_ ordner: URL) throws(Domaenenfehler) {
        do {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        } catch {
            throw .speicherNichtVerfuegbar(grund: String(describing: error))
        }
    }
}
