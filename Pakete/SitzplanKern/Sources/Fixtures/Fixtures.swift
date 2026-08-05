import Foundation

/// Zugriff auf die Vertragsfixtures unter `contracts/fixtures/`.
///
/// Die Dateien liegen im Wurzelverzeichnis des Repositories, nicht in diesem
/// Paket. Das ist Absicht: Sie sind die Verhaltensspezifikation der ganzen
/// Anwendung und gehoeren keinem einzelnen Target. Eine Kopie im Paket waere
/// die zuverlaessigste Art, zwei auseinanderlaufende Wahrheiten zu erzeugen.
///
/// Gefunden werden sie ueber den Quellpfad dieser Datei — das funktioniert bei
/// `swift test` auf macOS wie auf Linux, weil die Quellen dabei am Ort liegen.
public enum Fixtures {
    /// Sucht vom Quellpfad aus aufwaerts nach `contracts/fixtures`.
    ///
    /// Aufwaerts gesucht statt fest verdrahtet, damit ein verschobenes Paket
    /// nicht stillschweigend die falschen Dateien liest oder gar keine.
    public static func verzeichnis(ab quellpfad: String = #filePath) -> URL? {
        var ordner = URL(fileURLWithPath: quellpfad).deletingLastPathComponent()

        for _ in 0..<10 {
            let kandidat = ordner
                .appendingPathComponent("contracts", isDirectory: true)
                .appendingPathComponent("fixtures", isDirectory: true)
            if FileManager.default.fileExists(atPath: kandidat.path) {
                return kandidat
            }
            let hoeher = ordner.deletingLastPathComponent()
            if hoeher.path == ordner.path { break }
            ordner = hoeher
        }
        return nil
    }

    public enum Datei: String, CaseIterable {
        case raumDokumentV3 = "raum-dokument-v3"
        case planDokumentV1 = "plan-dokument-v1"
        case planDokumentAltUnvollstaendig = "plan-dokument-alt-unvollstaendig"
        case sitzregelnKonflikte = "sitzregeln-konflikte"
        case softDeleteFaelle = "soft-delete-faelle"

        public var dateiname: String { "\(rawValue).json" }
    }

    public struct NichtGefunden: Error, CustomStringConvertible {
        public let dateiname: String
        public var description: String {
            """
            Fixture '\(dateiname)' nicht gefunden. Erwartet unter \
            contracts/fixtures/ im Wurzelverzeichnis des Repositories.
            """
        }
    }

    public static func daten(_ datei: Datei) throws -> Data {
        guard let ordner = verzeichnis() else { throw NichtGefunden(dateiname: datei.dateiname) }
        let pfad = ordner.appendingPathComponent(datei.dateiname)
        guard let daten = FileManager.default.contents(atPath: pfad.path) else {
            throw NichtGefunden(dateiname: datei.dateiname)
        }
        return daten
    }

    /// Die Fixture als JSON-Objekt.
    public static func json(_ datei: Datei) throws -> [String: Any] {
        let roh = try JSONSerialization.jsonObject(with: try daten(datei))
        return roh as? [String: Any] ?? [:]
    }

    /// Der Rohtext der Fixture.
    ///
    /// Wird gebraucht, wo die **Reihenfolge** von JSON-Objektschluesseln zaehlt:
    /// `JSONSerialization` liefert ein `NSDictionary` und wirft sie weg, aber
    /// genau an ihr haengt die Regel „der letzte gewinnt“.
    /// Siehe ``schluesselInDokumentreihenfolge(_:aus:)``.
    public static func text(_ datei: Datei) throws -> String {
        String(decoding: try daten(datei), as: UTF8.self)
    }

    /// Bringt Schluessel eines JSON-Objekts in ihre Dokumentreihenfolge zurueck.
    ///
    /// Notwendig, weil `JSONSerialization` Objekte in ein `Dictionary` legt und
    /// die Reihenfolge dabei verliert. Ausgerechnet die Faelle „doppelte
    /// Zuordnung“ und „Schueler doppelt gesetzt“ haengen aber daran — und das
    /// ist derselbe Fallstrick, den der Datenvertrag fuer den Produktcode
    /// beschreibt.
    ///
    /// Ermittelt wird die Reihenfolge ueber die Position des Schluessels im
    /// Rohtext, gesucht ab einem Abschnittsanker.
    public static func schluesselInDokumentreihenfolge(
        _ schluessel: [String],
        aus rohtext: String,
        abAnker anker: String? = nil
    ) -> [String] {
        let start: String.Index
        if let anker, let bereich = rohtext.range(of: anker) {
            start = bereich.upperBound
        } else {
            start = rohtext.startIndex
        }
        let abschnitt = rohtext[start...]

        return schluessel
            .compactMap { s -> (String, Int)? in
                guard let bereich = abschnitt.range(of: "\"\(s)\"") else { return nil }
                return (s, abschnitt.distance(from: abschnitt.startIndex, to: bereich.lowerBound))
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
