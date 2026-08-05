import Datenvertrag
import Domain
import Foundation
import SwiftData

// Die `@Model`-Typen sind duenn. Das fachliche Dokument bleibt ein
// `Codable`-Wert aus `Domain` und liegt als Attribut am Model — kein
// Objektgraph, keine Geometrie in Einzelspalten.
//
// Kein `user_id`: Es gibt genau einen Datenbestand, und er gehoert der Person,
// die vor dem Rechner sitzt.
//
// `geloeschtAm` ist der einzige Loeschmechanismus. Wer `modelContext.delete(_:)`
// auf einem dieser Typen aufruft, umgeht den Papierkorb — das ist ausschliesslich
// beim endgueltigen Leeren erlaubt.

@Model
public final class KlassenEintrag {
    #Unique<KlassenEintrag>([\.id])
    #Index<KlassenEintrag>([\.geloeschtAm], [\.name])

    public var id: UUID = UUID()
    public var name: String = ""
    public var notizen: String?
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    @Relationship(deleteRule: .cascade, inverse: \SchuelerEintrag.klasse)
    public var schueler: [SchuelerEintrag]? = []

    @Relationship(deleteRule: .cascade, inverse: \SitzregelEintrag.klasse)
    public var sitzregeln: [SitzregelEintrag]? = []

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

@Model
public final class SchuelerEintrag {
    #Unique<SchuelerEintrag>([\.id])
    #Index<SchuelerEintrag>([\.geloeschtAm])

    public var id: UUID = UUID()
    public var vorname: String = ""
    public var nachname: String = ""
    public var initialen: String = ""
    public var farbIndex: Int = 0
    /// Rohwerte der Merkmale. Ein unbekannter Schluessel wird behalten, statt
    /// verworfen zu werden — sonst verliert ein aelteres Merkmal beim naechsten
    /// Speichern still seinen Wert.
    public var merkmaleRoh: [String] = []
    public var notiz: String?
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    public var klasse: KlassenEintrag?

    public init(
        id: UUID = UUID(),
        vorname: String,
        nachname: String,
        initialen: String,
        farbIndex: Int,
        merkmaleRoh: [String] = [],
        notiz: String? = nil,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil,
        klasse: KlassenEintrag? = nil
    ) {
        self.id = id
        self.vorname = vorname
        self.nachname = nachname
        self.initialen = initialen
        self.farbIndex = farbIndex
        self.merkmaleRoh = merkmaleRoh
        self.notiz = notiz
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
        self.klasse = klasse
    }
}

@Model
public final class SitzregelEintrag {
    #Unique<SitzregelEintrag>([\.id])

    public var id: UUID = UUID()
    public var schuelerA: UUID = UUID()
    public var schuelerB: UUID = UUID()
    public var artRoh: String = Regelart.nichtNeben.rawValue
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    public var klasse: KlassenEintrag?

    public init(
        id: UUID = UUID(),
        schuelerA: UUID,
        schuelerB: UUID,
        art: Regelart,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil,
        klasse: KlassenEintrag? = nil
    ) {
        self.id = id
        self.schuelerA = schuelerA
        self.schuelerB = schuelerB
        self.artRoh = art.rawValue
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
        self.klasse = klasse
    }
}

@Model
public final class RaumEintrag {
    #Unique<RaumEintrag>([\.id])
    #Index<RaumEintrag>([\.geloeschtAm], [\.name])

    public var id: UUID = UUID()
    public var name: String = ""
    public var breiteCm: Double = 0
    public var laengeCm: Double = 0
    public var rasterCm: Double = Raster.standard

    /// Das fachliche Dokument, als JSON abgelegt.
    ///
    /// - Important: Bewusst `Data` und **nicht** `RaumDokument` direkt.
    ///   SwiftData legt einen `Codable`-Wert als „composite attribute“ ab und
    ///   benutzt dafuer einen eigenen Coder, der ausschliesslich keyed
    ///   container beherrscht. Unser tolerantes Lesen muss aber auch mit `null`,
    ///   einer Zeichenkette oder Unsinn umgehen koennen — genau das laesst
    ///   dieser Coder nicht zu, und zwar mit einem `fatalError`, nicht mit einem
    ///   auffangbaren Fehler.
    ///
    ///   Als `Data` bleibt die Kodierung in unserer Hand: dieselbe, die auch
    ///   ein spaeterer Export schreiben wuerde, und mit allen Toleranzen aus
    ///   `docs/datenvertrag.md`.
    public var dokumentDaten: Data = Data()

    public var dokumentVersion: Int = RaumDokument.version
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    /// Das Dokument als Wert. Lesen ist tolerant, Schreiben streng.
    @Transient
    public var dokument: RaumDokument {
        get { Dokumentlesen.raumDokument(aus: dokumentDaten) }
        set { dokumentDaten = (try? Dokumentlesen.daten(aus: newValue)) ?? Data() }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        breiteCm: Double,
        laengeCm: Double,
        rasterCm: Double,
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
        self.dokumentDaten = (try? Dokumentlesen.daten(aus: dokument)) ?? Data()
        self.dokumentVersion = dokumentVersion
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

@Model
public final class SitzplanEintrag {
    #Unique<SitzplanEintrag>([\.id])
    #Index<SitzplanEintrag>([\.geloeschtAm])

    public var id: UUID = UUID()
    public var klasseId: UUID = UUID()
    public var raumId: UUID = UUID()
    public var name: String = ""
    public var statusRoh: String = Planstatus.entwurf.rawValue

    /// Enthaelt die **eingefrorene** Raumkopie. Sie ist von der Vorlage
    /// unabhaengig; Raumaenderungen wirken nicht auf bestehende Plaene.
    ///
    /// Als `Data` abgelegt — Begruendung siehe `RaumEintrag.dokumentDaten`.
    public var dokumentDaten: Data = Data()

    public var dokumentVersion: Int = PlanDokument.version
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    @Transient
    public var dokument: PlanDokument {
        get { Dokumentlesen.planDokument(aus: dokumentDaten) }
        set { dokumentDaten = (try? Dokumentlesen.daten(aus: newValue)) ?? Data() }
    }

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
        self.statusRoh = status.rawValue
        self.dokumentDaten = (try? Dokumentlesen.daten(aus: dokument)) ?? Data()
        self.dokumentVersion = dokumentVersion
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

@Model
public final class SitzplanVersionEintrag {
    #Unique<SitzplanVersionEintrag>([\.id])

    public var id: UUID = UUID()
    public var sitzplanId: UUID = UUID()
    public var name: String = ""
    public var dokumentDaten: Data = Data()
    public var erstelltAm: Date = Date.distantPast
    public var geaendertAm: Date = Date.distantPast
    public var geloeschtAm: Date?

    @Transient
    public var dokument: PlanDokument {
        get { Dokumentlesen.planDokument(aus: dokumentDaten) }
        set { dokumentDaten = (try? Dokumentlesen.daten(aus: newValue)) ?? Data() }
    }

    public init(
        id: UUID = UUID(),
        sitzplanId: UUID,
        name: String,
        dokument: PlanDokument = .leer,
        erstelltAm: Date,
        geaendertAm: Date,
        geloeschtAm: Date? = nil
    ) {
        self.id = id
        self.sitzplanId = sitzplanId
        self.name = name
        self.dokumentDaten = (try? Dokumentlesen.daten(aus: dokument)) ?? Data()
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.geloeschtAm = geloeschtAm
    }
}

// Die Liste aller `@Model`-Typen steht in `Speicher.Schema` (siehe
// `Speicher.swift`). Auch die noch ungenutzten gehoeren hinein: Der Datenvertrag
// fuehrt sie, und ein spaeter nachgereichter Typ waere eine Migration.
