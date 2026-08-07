import Foundation

/// Protokollierung mit einer festen Grenze: **niemals personenbezogene
/// Schuelerdaten.**
///
/// Kein Name, keine Initialen, kein Merkmal, keine Notiz, keine Klassen-
/// bezeichnung. Was ins Log darf, sind Kennungen, Anzahlen und Fehlerarten.
///
/// Auf Apple-Plattformen liegt darunter `os.Logger` mit Privacy-Markierungen.
/// Dieses Paket muss aber auf Linux bauen, deshalb die duenne eigene Huelle
/// statt eines direkten `import os`.
public struct Protokoll: Sendable {
    public enum Stufe: Int, Sendable, Comparable {
        case debug = 0, hinweis = 1, warnung = 2, fehler = 3

        public static func < (links: Stufe, rechts: Stufe) -> Bool {
            links.rawValue < rechts.rawValue
        }
    }

    public let bereich: String
    private let mindeststufe: Stufe
    private let ausgabe: @Sendable (Stufe, String) -> Void

    public init(
        bereich: String,
        mindeststufe: Stufe = .hinweis,
        ausgabe: @escaping @Sendable (Stufe, String) -> Void = Protokoll.standardausgabe
    ) {
        self.bereich = bereich
        self.mindeststufe = mindeststufe
        self.ausgabe = ausgabe
    }

    public static let standardausgabe: @Sendable (Stufe, String) -> Void = { stufe, text in
        FileHandle.standardError.write(Data("[\(stufe)] \(text)\n".utf8))
    }

    public func debug(_ text: @autoclosure () -> String) { schreiben(.debug, text()) }
    public func hinweis(_ text: @autoclosure () -> String) { schreiben(.hinweis, text()) }
    public func warnung(_ text: @autoclosure () -> String) { schreiben(.warnung, text()) }
    public func fehler(_ text: @autoclosure () -> String) { schreiben(.fehler, text()) }

    private func schreiben(_ stufe: Stufe, _ text: String) {
        guard stufe >= mindeststufe else { return }
        ausgabe(stufe, "\(bereich): \(text)")
    }
}

/// Wo die Anwendung ihre Daten ablegt.
public enum Ablage {
    public static let ordnername = "SitzplanStudio"
    public static let datenbankname = "Sitzplan.store"

    /// `~/Library/Application Support/SitzplanStudio/`
    ///
    /// Auf Linux — also im Testlauf der CI — gibt es dieses Verzeichnis nicht.
    /// Der Kern braucht es auch nicht: Er kennt keinen Speicher. Der Pfad steht
    /// hier, weil er zur Konfiguration gehoert, und wird von
    /// `SitzplanSpeicher` verwendet.
    public static func verzeichnis(
        basis: URL? = nil
    ) -> URL? {
        let ordner = basis ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        return ordner?.appendingPathComponent(ordnername, isDirectory: true)
    }
}
