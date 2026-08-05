import Foundation

// Domaenenmodelle. Reine Werte, ohne Kenntnis von SwiftData, SwiftUI oder einer
// Datenbank. Die Speicherschicht bildet sie auf `@Model`-Typen ab; die
// Oberflaeche arbeitet ausschliesslich mit diesen hier.

/// Ein Datensatz, der weich geloescht werden kann.
public protocol WeichLoeschbar {
    var id: UUID { get }
    var geloeschtAm: Date? { get }
}

extension WeichLoeschbar {
    public var istGeloescht: Bool { geloeschtAm != nil }
}

// MARK: - Klasse

public struct Klasse: Sendable, Equatable, Identifiable, WeichLoeschbar {
    public var id: UUID
    public var name: String
    public var notizen: String?
    public var erstelltAm: Date
    public var geaendertAm: Date
    public var geloeschtAm: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        notizen: String? = nil,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.notizen = notizen
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

// MARK: - Schueler

/// Foerder- und Gesundheitsmerkmale.
///
/// Die sensibelsten Daten dieser Anwendung. Sie gehoeren nie in ein Log, nie in
/// eine Fehlermeldung und nie in ein Bildschirmfoto.
///
/// Der Katalog entspricht `MERKMALE` im Web-Client. Ein unbekannter Schluessel
/// wird beim Lesen behalten, statt verworfen zu werden — sonst verliert ein
/// aelteres Merkmal beim naechsten Speichern still seinen Wert.
public enum Merkmal: String, Codable, Sendable, CaseIterable, Equatable {
    case adhs
    case autismusSpektrum = "autismus_spektrum"
    case schwerhoerig
    case sehschwaeche
    case legasthenie
    case dyskalkulie
    case daz
    case nachteilsausgleich
    case motorisch
    case chronischKrank = "chronisch_krank"

    /// Beschriftung fuer die Oberflaeche.
    public var beschriftung: String {
        switch self {
        case .adhs: "ADHS"
        case .autismusSpektrum: "Autismus-Spektrum"
        case .schwerhoerig: "Schwerhörigkeit"
        case .sehschwaeche: "Sehschwäche"
        case .legasthenie: "Legasthenie"
        case .dyskalkulie: "Dyskalkulie"
        case .daz: "Deutsch als Zweitsprache"
        case .nachteilsausgleich: "Nachteilsausgleich"
        case .motorisch: "motorische Einschränkung"
        case .chronischKrank: "chronische Erkrankung"
        }
    }
}

public struct Schueler: Sendable, Equatable, Identifiable, WeichLoeschbar {
    /// Erlaubter Bereich fuer `farbIndex`. Geprueft in der Domaene, nicht im
    /// Speicher — eine lokale Datenbank hat keinen Server, der ungueltige Werte
    /// abweist.
    public static let farbIndexBereich = 0...7

    public var id: UUID
    public var klasseId: UUID
    public var vorname: String
    public var nachname: String
    public var initialen: String
    public var farbIndex: Int
    public var merkmale: [Merkmal]
    public var notiz: String?
    public var erstelltAm: Date
    public var geaendertAm: Date
    public var geloeschtAm: Date?

    public init(
        id: UUID = UUID(),
        klasseId: UUID,
        vorname: String,
        nachname: String,
        initialen: String? = nil,
        farbIndex: Int = 0,
        merkmale: [Merkmal] = [],
        notiz: String? = nil,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.klasseId = klasseId
        self.vorname = vorname
        self.nachname = nachname
        self.initialen = initialen ?? Schueler.initialenAus(vorname: vorname, nachname: nachname)
        self.farbIndex = farbIndex.clamped(to: Schueler.farbIndexBereich)
        self.merkmale = merkmale
        self.notiz = notiz
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }

    public static func initialenAus(vorname: String, nachname: String) -> String {
        let v = vorname.trimmingCharacters(in: .whitespacesAndNewlines).first
        let n = nachname.trimmingCharacters(in: .whitespacesAndNewlines).first
        return [v, n].compactMap { $0 }.map(String.init).joined().uppercased()
    }

    public var vollerName: String {
        "\(vorname) \(nachname)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Sitzregel

public enum Regelart: String, Codable, Sendable, CaseIterable, Equatable {
    case nichtNeben = "nicht_neben"
    case mussNeben = "muss_neben"
}

public struct Sitzregel: Sendable, Equatable, Identifiable, WeichLoeschbar {
    public var id: UUID
    public var klasseId: UUID
    public var schuelerA: UUID
    public var schuelerB: UUID
    public var art: Regelart
    public var erstelltAm: Date
    public var geaendertAm: Date
    public var geloeschtAm: Date?

    public init(
        id: UUID = UUID(),
        klasseId: UUID,
        schuelerA: UUID,
        schuelerB: UUID,
        art: Regelart,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.klasseId = klasseId
        self.schuelerA = schuelerA
        self.schuelerB = schuelerB
        self.art = art
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

// MARK: - Raum

public struct Raum: Sendable, Equatable, Identifiable, WeichLoeschbar {
    public var id: UUID
    public var name: String
    public var breiteCm: Double
    public var laengeCm: Double
    public var rasterCm: Double
    public var dokument: RaumDokument
    public var dokumentVersion: Int
    public var erstelltAm: Date
    public var geaendertAm: Date
    public var geloeschtAm: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        breiteCm: Double,
        laengeCm: Double,
        rasterCm: Double = Raster.standard,
        dokument: RaumDokument = .leer,
        dokumentVersion: Int = RaumDokument.version,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.breiteCm = breiteCm
        self.laengeCm = laengeCm
        self.rasterCm = rasterCm
        self.dokument = dokument
        self.dokumentVersion = dokumentVersion
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

// MARK: - Sitzplan

public enum Planstatus: String, Codable, Sendable, CaseIterable, Equatable {
    case entwurf
    case aktiv
    case archiv
}

public struct Sitzplan: Sendable, Equatable, Identifiable, WeichLoeschbar {
    /// Rueckfall fuer den Raumnamen. Er steht **nicht** im Dokument und wird
    /// beim Laden aus dem Raum nachgereicht.
    public static let raumnameRueckfall = "Raum"

    public var id: UUID
    public var klasseId: UUID
    public var raumId: UUID
    public var name: String
    public var status: Planstatus
    public var dokument: PlanDokument
    public var dokumentVersion: Int
    public var erstelltAm: Date
    public var geaendertAm: Date
    public var geloeschtAm: Date?

    public init(
        id: UUID = UUID(),
        klasseId: UUID,
        raumId: UUID,
        name: String,
        status: Planstatus = .entwurf,
        dokument: PlanDokument = .leer,
        dokumentVersion: Int = PlanDokument.version,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.klasseId = klasseId
        self.raumId = raumId
        self.name = name
        self.status = status
        self.dokument = dokument
        self.dokumentVersion = dokumentVersion
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

// MARK: - Hilfen

extension Comparable {
    func clamped(to bereich: ClosedRange<Self>) -> Self {
        min(max(self, bereich.lowerBound), bereich.upperBound)
    }
}
