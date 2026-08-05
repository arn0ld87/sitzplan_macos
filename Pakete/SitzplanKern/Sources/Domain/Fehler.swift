import Foundation

/// Fehler, die die Oberflaeche erreichen duerfen.
///
/// Typisiert, nicht durchgereicht: Ein `DecodingError` oder ein
/// SwiftData-Fehler wird hier abgebildet, bevor er eine View erreicht. Was die
/// Lehrkraft liest, ist ``beschreibung`` — und darin steht nie ein Schuelername
/// und nie ein Dateipfad.
public enum Domaenenfehler: Error, Sendable, Equatable {
    /// Der Speicher konnte nicht geoeffnet werden.
    case speicherNichtVerfuegbar(grund: String)
    /// Das Schreiben ist gescheitert. Die Aenderung liegt weiter vor.
    case speichernGescheitert(grund: String)
    /// Ein angefragter Datensatz existiert nicht (mehr).
    case nichtGefunden(art: String)
    /// Eine fachliche Bedingung ist verletzt.
    case ungueltigeEingabe(feld: String, grund: String)
    /// Ein Dokument liess sich nicht lesen, auch nicht tolerant.
    case dokumentUnlesbar(grund: String)

    /// Text fuer die Oberflaeche. Vollstaendige Saetze, kein Fachjargon, keine
    /// personenbezogenen Daten.
    public var beschreibung: String {
        switch self {
        case .speicherNichtVerfuegbar:
            "Die Daten konnten nicht geöffnet werden."
        case .speichernGescheitert:
            "Die Änderung konnte nicht gespeichert werden. Sie ist noch da und kann erneut gespeichert werden."
        case .nichtGefunden(let art):
            "\(art) wurde nicht gefunden."
        case .ungueltigeEingabe(let feld, let grund):
            "\(feld): \(grund)"
        case .dokumentUnlesbar:
            "Der Inhalt konnte nicht gelesen werden."
        }
    }

    /// Was die Lehrkraft als Nächstes tun kann.
    public var vorschlag: String? {
        switch self {
        case .speicherNichtVerfuegbar:
            "Prüfen Sie, ob genügend Speicherplatz frei ist, und starten Sie die App neu."
        case .speichernGescheitert:
            "Versuchen Sie es erneut."
        case .nichtGefunden:
            nil
        case .ungueltigeEingabe:
            nil
        case .dokumentUnlesbar:
            nil
        }
    }

    /// Technischer Grund — fuer das Log, nicht fuer die Oberflaeche.
    public var technischerGrund: String? {
        switch self {
        case .speicherNichtVerfuegbar(let grund),
             .speichernGescheitert(let grund),
             .dokumentUnlesbar(let grund):
            grund
        case .nichtGefunden, .ungueltigeEingabe:
            nil
        }
    }
}

// MARK: - Fachliche Pruefungen

extension Klasse {
    /// Prueft einen Klassennamen. Leer ist kein Name.
    public static func pruefeName(_ name: String) throws(Domaenenfehler) -> String {
        let bereinigt = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bereinigt.isEmpty else {
            throw .ungueltigeEingabe(feld: "Name", grund: "Bitte einen Namen eingeben.")
        }
        guard bereinigt.count <= 80 else {
            throw .ungueltigeEingabe(feld: "Name", grund: "Höchstens 80 Zeichen.")
        }
        return bereinigt
    }
}

extension Raum {
    /// Masse und Raster sind Vertrag: Breite und Laenge groesser als 0, Raster
    /// mindestens 5. Frueher hat das eine `CHECK`-Bedingung erzwungen; ohne
    /// Datenbank gibt es niemanden, der es sonst tut.
    public static func pruefeMasse(breiteCm: Double, laengeCm: Double, rasterCm: Double) throws(Domaenenfehler) {
        guard breiteCm > 0 else {
            throw .ungueltigeEingabe(feld: "Breite", grund: "Muss größer als 0 sein.")
        }
        guard laengeCm > 0 else {
            throw .ungueltigeEingabe(feld: "Länge", grund: "Muss größer als 0 sein.")
        }
        guard rasterCm >= 5 else {
            throw .ungueltigeEingabe(feld: "Raster", grund: "Mindestens 5 cm.")
        }
    }
}
