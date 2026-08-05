import Foundation

// Die Dokumentformate. Geometrie liegt nicht in Einzelfeldern, sondern als
// Dokument am Modell — ein Codable-Wert, kein Objektgraph.
//
// Zwei Namenswelten, beide verbindlich: Das RaumDokument benutzt
// `x_cm`/`breite_cm` mit Unterstrich, das PlanDokument `breiteCm`/`rasterCm` in
// Binnenmajuskel. Innerhalb von `raumGeometrie.objekte` gilt wieder die
// Unterstrich-Form. Das ist gewachsen und wird nicht angeglichen — eine
// Aenderung braeche jedes bestehende Dokument.
//
// Deshalb ueberall explizite `CodingKeys` und **keine** globale
// `keyEncodingStrategy`. Eine Konvertierungsstrategie kann nur eine der beiden
// Welten treffen.

// MARK: - Bausteine

/// Ein Moebelstueck im Raum. Koordinaten sind Zentimeter, Ursprung links oben.
public struct Raumobjekt: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var typ: Moebeltyp
    public var xCm: Double
    public var yCm: Double
    public var drehung: Drehung

    public init(id: String, typ: Moebeltyp, xCm: Double, yCm: Double, drehung: Drehung = .null) {
        self.id = id
        self.typ = typ
        self.xCm = xCm
        self.yCm = yCm
        self.drehung = drehung
    }

    /// Breite aus der Moebeltabelle — nicht aus dem Dokument.
    public var breiteCm: Double { typ.breiteCm }
    /// Tiefe aus der Moebeltabelle — nicht aus dem Dokument.
    public var tiefeCm: Double { typ.tiefeCm }

    private enum CodingKeys: String, CodingKey {
        case id
        case typ
        case xCm = "x_cm"
        case yCm = "y_cm"
        case breiteCm = "breite_cm"
        case tiefeCm = "tiefe_cm"
        case rotationDeg = "rotation_deg"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        typ = Moebeltyp(dokumentSchluessel: try? c.decode(String.self, forKey: .typ))
        xCm = (try? c.decode(Double.self, forKey: .xCm)) ?? 0
        yCm = (try? c.decode(Double.self, forKey: .yCm)) ?? 0
        drehung = Drehung(grad: try? c.decode(Int.self, forKey: .rotationDeg))
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(typ.dokumentSchluessel, forKey: .typ)
        try c.encode(xCm, forKey: .xCm)
        try c.encode(yCm, forKey: .yCm)
        // Streng und kanonisch geschrieben: Die Masse kommen aus der Tabelle,
        // nicht aus dem gelesenen Dokument. Ein Dokument mit abweichendem
        // `breite_cm` wird hier zurechtgerueckt.
        try c.encode(typ.breiteCm, forKey: .breiteCm)
        try c.encode(typ.tiefeCm, forKey: .tiefeCm)
        try c.encode(drehung.grad, forKey: .rotationDeg)
    }
}

/// Ein Sitzplatz an einem Moebelstueck.
public struct Sitzplatz: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var objektId: String
    public var lokalXCm: Double
    public var lokalYCm: Double
    public var bezeichnung: String

    public init(id: String, objektId: String, lokalXCm: Double, lokalYCm: Double, bezeichnung: String) {
        self.id = id
        self.objektId = objektId
        self.lokalXCm = lokalXCm
        self.lokalYCm = lokalYCm
        self.bezeichnung = bezeichnung
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case objektId
        case lokalXCm = "lokalX_cm"
        case lokalYCm = "lokalY_cm"
        case bezeichnung
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        objektId = (try? c.decode(String.self, forKey: .objektId)) ?? ""
        lokalXCm = (try? c.decode(Double.self, forKey: .lokalXCm)) ?? 0
        lokalYCm = (try? c.decode(Double.self, forKey: .lokalYCm)) ?? 0
        bezeichnung = (try? c.decode(String.self, forKey: .bezeichnung)) ?? ""
    }
}

/// Eine Zuordnung Sitzplatz → Schueler.
public struct Zuordnung: Codable, Sendable, Equatable {
    public var sitzplatzId: String
    public var schuelerId: String

    public init(sitzplatzId: String, schuelerId: String) {
        self.sitzplatzId = sitzplatzId
        self.schuelerId = schuelerId
    }
}

/// Herkunft eines Sitzplans.
public struct Planquelle: Codable, Sendable, Equatable {
    public var klasseId: String
    public var raumId: String

    public init(klasseId: String, raumId: String) {
        self.klasseId = klasseId
        self.raumId = raumId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        klasseId = (try? c.decode(String.self, forKey: .klasseId)) ?? ""
        raumId = (try? c.decode(String.self, forKey: .raumId)) ?? ""
    }
}

// MARK: - RaumDokument

/// Der Inhalt von `RaumEintrag.dokument`, Dokumentversion 3.
public struct RaumDokument: Codable, Sendable, Equatable {
    public static let version = 3

    public var objekte: [Raumobjekt]
    public var sitzplaetze: [Sitzplatz]

    public init(objekte: [Raumobjekt] = [], sitzplaetze: [Sitzplatz] = []) {
        self.objekte = objekte
        self.sitzplaetze = sitzplaetze
    }

    /// Der Vorgabewert der Spalte: `{"objekte": [], "sitzplaetze": []}`.
    public static let leer = RaumDokument()

    private enum CodingKeys: String, CodingKey {
        case objekte, sitzplaetze
    }

    public init(from decoder: any Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .leer
            return
        }
        objekte = c.tolerantesArray(Raumobjekt.self, forKey: .objekte)
        sitzplaetze = c.tolerantesArray(Sitzplatz.self, forKey: .sitzplaetze)
    }
}

// MARK: - PlanDokument

/// Die eingefrorene Raumkopie im Sitzplan.
///
/// Sie ist von der Vorlage unabhaengig: Raumaenderungen wirken nicht auf
/// bestehende Plaene. Der Raumname steht **nicht** im Dokument — er wird beim
/// Laden aus dem Raum nachgereicht, mit `"Raum"` als Rueckfallwert.
public struct Raumgeometrie: Codable, Sendable, Equatable {
    public var breiteCm: Double
    public var laengeCm: Double
    public var rasterCm: Double
    public var objekte: [Raumobjekt]
    public var sitzplaetze: [Sitzplatz]

    public init(
        breiteCm: Double,
        laengeCm: Double,
        rasterCm: Double,
        objekte: [Raumobjekt] = [],
        sitzplaetze: [Sitzplatz] = []
    ) {
        self.breiteCm = breiteCm
        self.laengeCm = laengeCm
        self.rasterCm = rasterCm
        self.objekte = objekte
        self.sitzplaetze = sitzplaetze
    }

    /// Rueckfall, wenn `raumGeometrie` **ganz fehlt**: 800 × 600, Raster 10, leer.
    ///
    /// Nicht zu verwechseln mit dem Fall, dass die Geometrie da ist und nur ein
    /// Feld fehlt — dann gilt 0 fuer die Masse und 10 fuer das Raster.
    public static let rueckfall = Raumgeometrie(breiteCm: 800, laengeCm: 600, rasterCm: 10)

    private enum CodingKeys: String, CodingKey {
        case breiteCm, laengeCm, rasterCm, objekte, sitzplaetze
    }

    public init(from decoder: any Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .rueckfall
            return
        }
        breiteCm = (try? c.decode(Double.self, forKey: .breiteCm)) ?? 0
        laengeCm = (try? c.decode(Double.self, forKey: .laengeCm)) ?? 0
        // Achtung: Hier gilt 10, nicht `Raster.standard` (25). Das ist der
        // bekannte Widerspruch im Bestand — siehe `Raster.standard`.
        let gelesenesRaster = (try? c.decode(Double.self, forKey: .rasterCm)) ?? 0
        rasterCm = gelesenesRaster == 0 ? 10 : gelesenesRaster
        objekte = c.tolerantesArray(Raumobjekt.self, forKey: .objekte)
        sitzplaetze = c.tolerantesArray(Sitzplatz.self, forKey: .sitzplaetze)
    }
}

/// Der Inhalt von `SitzplanEintrag.dokument`, Dokumentversion 1.
public struct PlanDokument: Codable, Sendable, Equatable {
    public static let version = 1

    public var quelle: Planquelle?
    public var raumGeometrie: Raumgeometrie

    /// Bleibt eine **geordnete Liste**.
    ///
    /// - Important: „Der letzte gewinnt“ setzt eine Reihenfolge voraus. Ein
    ///   `[String: String]` an dieser Stelle macht das Ergebnis bei doppelten
    ///   Eintraegen zufaellig. Das Woerterbuch wird erst ueber
    ///   ``zuordnungenAlsWoerterbuch()`` abgeleitet, und zwar in
    ///   Dokumentreihenfolge.
    public var zuordnungen: [Zuordnung]

    public init(
        quelle: Planquelle? = nil,
        raumGeometrie: Raumgeometrie = .rueckfall,
        zuordnungen: [Zuordnung] = []
    ) {
        self.quelle = quelle
        self.raumGeometrie = raumGeometrie
        self.zuordnungen = zuordnungen
    }

    public static let leer = PlanDokument()

    private enum CodingKeys: String, CodingKey {
        case quelle, raumGeometrie, zuordnungen
    }

    public init(from decoder: any Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .leer
            return
        }
        quelle = try? c.decode(Planquelle.self, forKey: .quelle)
        raumGeometrie = (try? c.decode(Raumgeometrie.self, forKey: .raumGeometrie)) ?? .rueckfall
        zuordnungen = c.tolerantesArray(Zuordnung.self, forKey: .zuordnungen)
    }

    /// Leitet das Woerterbuch Sitzplatz → Schueler ab, in Dokumentreihenfolge.
    /// Spaetere Eintraege ueberschreiben fruehere — der letzte gewinnt.
    public func zuordnungenAlsWoerterbuch() -> [String: String] {
        var ergebnis: [String: String] = [:]
        for z in zuordnungen {
            ergebnis[z.sitzplatzId] = z.schuelerId
        }
        return ergebnis
    }

    /// Die Umkehrung Schueler → Platz, ebenfalls in Dokumentreihenfolge.
    /// Sitzt ein Schueler auf mehreren Plaetzen, gilt der zuletzt eingetragene.
    public func plaetzeJeSchueler() -> [String: String] {
        var ergebnis: [String: String] = [:]
        for z in zuordnungen {
            ergebnis[z.schuelerId] = z.sitzplatzId
        }
        return ergebnis
    }
}

// MARK: - Tolerantes Lesen von Listen

extension KeyedDecodingContainer {
    /// Liest ein Array tolerant: Fehlt der Schluessel, ist er `null` oder steht
    /// dort etwas anderes als ein Array, ergibt das ein leeres Array — keinen
    /// Fehler.
    ///
    /// Einzelne unlesbare Elemente werden uebersprungen, statt die ganze Liste
    /// zu verwerfen. Ein halb gelesenes Dokument ist besser als ein Absturz vor
    /// der Klassenliste.
    fileprivate func tolerantesArray<T: Decodable>(_ typ: T.Type, forKey key: Key) -> [T] {
        guard var liste = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var ergebnis: [T] = []
        while !liste.isAtEnd {
            if let element = try? liste.decode(T.self) {
                ergebnis.append(element)
            } else {
                // Element uebersprungen. Der Container muss trotzdem
                // weiterruecken, sonst dreht die Schleife durch.
                _ = try? liste.decode(LeererWert.self)
            }
        }
        return ergebnis
    }
}

/// Schluckt einen beliebigen JSON-Wert, um im Container weiterzuruecken.
private struct LeererWert: Decodable {
    init(from decoder: any Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
}
