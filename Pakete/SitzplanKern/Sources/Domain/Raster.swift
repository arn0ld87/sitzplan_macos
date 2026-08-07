import Foundation

/// Rasterrechnung in Zentimetern.
///
/// Zentimeter sind die fachliche Einheit. Bildschirmkoordinaten sind eine
/// Projektion; Zoom und Fenstergroesse veraendern nie gespeicherte Geometrie.
public enum Raster {
    /// Rasterweite, wenn keine angegeben ist.
    ///
    /// - Note: Es gibt im Bestand einen zweiten, abweichenden Rueckfallwert: Ein
    ///   `PlanDokument` ohne `rasterCm` faellt auf 10 zurueck, nicht auf 25
    ///   (siehe `Toleranz.rasterCm`). Das ist bekannt, in den Fixtures
    ///   festgehalten und Gegenstand eines eigenen Issues. Bis dahin gilt beides
    ///   unveraendert, damit dieselben Dokumente gleich gelesen werden.
    public static let standard: Double = 25

    /// Normalisiert eine Rasterangabe. Fehlt sie oder ist sie 0, gilt `standard`.
    public static func weite(_ angabe: Double?) -> Double {
        guard let angabe, angabe != 0 else { return standard }
        return angabe
    }

    /// Rundet einen Wert auf die Rasterweite.
    ///
    /// - Important: Die Rundung ist die von JavaScript, **nicht** die von Swift.
    ///   `Foundation.rounded()` rundet halbe Werte vom Nullpunkt weg: −0,5 wird
    ///   zu −1. JavaScripts `Math.round` rundet halbe Werte immer zur groesseren
    ///   Zahl: −0,5 wird zu −0. Bei negativen Koordinaten laufen beide
    ///   auseinander, und ein Moebelstueck landet einen Rasterschritt daneben.
    ///
    ///   Deshalb `floor(x + 0.5)` und nicht `rounded()`. Die Fixture
    ///   `plan-dokument-alt-unvollstaendig.json` prueft genau diesen Unterschied
    ///   mit −12,5 und −37,5.
    public static func runden(_ wert: Double, raster: Double) -> Double {
        // Die Rundung wird nie mit 0 aufgerufen — `weite(_:)` faengt das vorher
        // ab. Falls doch, ist der unveraenderte Wert die einzige Antwort, die
        // keine Division durch null erzeugt.
        guard raster != 0 else { return wert }
        return (wert / raster + 0.5).rounded(.down) * raster
    }

    /// Rundet einen Punkt auf die Rasterweite.
    public static func runden(x: Double, y: Double, raster: Double) -> (x: Double, y: Double) {
        (runden(x, raster: raster), runden(y, raster: raster))
    }
}
