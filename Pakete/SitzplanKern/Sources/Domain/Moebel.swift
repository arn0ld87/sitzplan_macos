import Foundation

/// Moebeltypen. Im Dokument stehen englische Bezeichner, in der Domaene deutsche.
///
/// Die Zuordnung ist Vertrag (`docs/datenvertrag.md`): Ein unbekannter Bezeichner
/// wird beim Lesen zum Einzeltisch statt zu einem Fehler.
public enum Moebeltyp: String, Codable, Sendable, CaseIterable, Equatable {
    case einzeltisch
    case doppeltisch
    case pult
    case tafel
    case tuer
    case fenster

    /// Bezeichner im Dokument. Wird beim Schreiben verwendet.
    public var dokumentSchluessel: String {
        switch self {
        case .einzeltisch: "table_single"
        case .doppeltisch: "table_double"
        case .pult: "teacher_desk"
        case .tafel: "board"
        case .tuer: "door"
        case .fenster: "window"
        }
    }

    /// Tolerantes Lesen: Unbekanntes wird zum Einzeltisch, nicht zum Fehler.
    public init(dokumentSchluessel: String?) {
        switch dokumentSchluessel {
        case "table_single": self = .einzeltisch
        case "table_double": self = .doppeltisch
        case "teacher_desk": self = .pult
        case "board": self = .tafel
        case "door": self = .tuer
        case "window": self = .fenster
        default: self = .einzeltisch
        }
    }
}

/// Feste Masse je Moebeltyp, in Zentimetern.
///
/// Entspricht `FURNITURE_SPECS` im Web-Client. Verbindlich ist diese Tabelle,
/// nicht das Dokument: Beim Schreiben werden die Masse **aus der Tabelle
/// gesetzt**. Ein Dokument mit abweichendem `breite_cm` wird beim naechsten
/// Schreiben auf den Tabellenwert zurueckgesetzt.
public struct Moebelmasse: Sendable, Equatable {
    public let breiteCm: Double
    public let tiefeCm: Double
    public let sitzplaetze: Int

    public init(breiteCm: Double, tiefeCm: Double, sitzplaetze: Int) {
        self.breiteCm = breiteCm
        self.tiefeCm = tiefeCm
        self.sitzplaetze = sitzplaetze
    }
}

extension Moebeltyp {
    public var masse: Moebelmasse {
        switch self {
        case .einzeltisch: Moebelmasse(breiteCm: 60, tiefeCm: 50, sitzplaetze: 1)
        case .doppeltisch: Moebelmasse(breiteCm: 120, tiefeCm: 50, sitzplaetze: 2)
        case .pult: Moebelmasse(breiteCm: 160, tiefeCm: 80, sitzplaetze: 0)
        case .tafel: Moebelmasse(breiteCm: 400, tiefeCm: 15, sitzplaetze: 0)
        case .tuer: Moebelmasse(breiteCm: 90, tiefeCm: 20, sitzplaetze: 0)
        case .fenster: Moebelmasse(breiteCm: 15, tiefeCm: 180, sitzplaetze: 0)
        }
    }

    public var breiteCm: Double { masse.breiteCm }
    public var tiefeCm: Double { masse.tiefeCm }
    public var anzahlSitzplaetze: Int { masse.sitzplaetze }
}

/// Erlaubte Drehungen. Alles andere wird beim Lesen zu 0.
public enum Drehung: Int, Codable, Sendable, CaseIterable, Equatable {
    case null = 0
    case neunzig = 90
    case einhundertachtzig = 180
    case zweihundertsiebzig = 270

    /// Tolerantes Lesen: Ein Wert ausserhalb der vier Stufen wird zu 0.
    public init(grad: Int?) {
        self = Drehung(rawValue: grad ?? 0) ?? .null
    }

    public var grad: Int { rawValue }
}
