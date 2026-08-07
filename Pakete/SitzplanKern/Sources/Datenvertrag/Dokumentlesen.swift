import Domain
import Foundation

/// Liest und schreibt die Dokumentformate.
///
/// Grundsatz: **Lesen ist tolerant, Schreiben ist streng.** Alte und
/// unvollstaendige Dokumente duerfen nie zum Absturz fuehren; geschrieben wird
/// nur Vollstaendiges und Kanonisches.
public enum Dokumentlesen {
    /// Ein Kodierer, der kanonisch schreibt.
    ///
    /// Sortierte Schluessel, damit zwei gleiche Dokumente auch byteweise gleich
    /// sind — sonst zeigt jeder Vergleich und jeder Diff Unterschiede, die
    /// keine sind.
    public static func kodierer() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    public static func dekodierer() -> JSONDecoder {
        JSONDecoder()
    }

    /// Liest ein `RaumDokument`. Unlesbares ergibt das leere Dokument, keinen
    /// Fehler — ein Raum ohne Moebel ist besser als ein Absturz.
    public static func raumDokument(aus daten: Data) -> RaumDokument {
        (try? dekodierer().decode(RaumDokument.self, from: daten)) ?? .leer
    }

    /// Liest ein `PlanDokument`. Unlesbares ergibt das leere Dokument.
    public static func planDokument(aus daten: Data) -> PlanDokument {
        (try? dekodierer().decode(PlanDokument.self, from: daten)) ?? .leer
    }

    public static func daten(aus dokument: RaumDokument) throws(Domaenenfehler) -> Data {
        do {
            return try kodierer().encode(dokument)
        } catch {
            throw .dokumentUnlesbar(grund: String(describing: error))
        }
    }

    public static func daten(aus dokument: PlanDokument) throws(Domaenenfehler) -> Data {
        do {
            return try kodierer().encode(dokument)
        } catch {
            throw .dokumentUnlesbar(grund: String(describing: error))
        }
    }
}

// MARK: - Abgeleitete Sichten

extension RaumDokument {
    /// Die Sitzplaetze eines Moebelstuecks, wie sie im Dokument stehen.
    public func sitzplaetze(vonObjekt objektId: String) -> [Sitzplatz] {
        sitzplaetze.filter { $0.objektId == objektId }
    }

    /// Baut die Sitzplaetze aus der Moebeltabelle neu auf.
    ///
    /// Streng und kanonisch: Sitzplaetze werden aus dem Moebelstueck
    /// **abgeleitet**, nicht frei vergeben. Wer ein Moebelstueck dreht oder
    /// verschiebt, aendert damit keine Kennung — die Lage ist lokal und gilt vor
    /// jeder Drehung.
    public func mitAbgeleitetenSitzplaetzen() -> RaumDokument {
        RaumDokument(
            objekte: objekte,
            sitzplaetze: objekte.flatMap { $0.typ.sitzplaetze(objektId: $0.id) }
        )
    }
}

extension PlanDokument {
    /// Alle Plaetze der eingefrorenen Raumkopie.
    public var alleSitzplatzIds: [String] {
        raumGeometrie.sitzplaetze.map(\.id)
    }

    /// Belegte Plaetze — nur solche, die es in der Raumkopie auch gibt.
    ///
    /// Eine Zuordnung auf einen Platz, den die Geometrie nicht kennt, bleibt im
    /// Dokument stehen und wird hier lediglich nicht mitgezaehlt. Sie
    /// wegzuwerfen waere Datenverlust: Der Platz kann wiederkommen.
    public var belegteSitzplatzIds: [String] {
        let vorhanden = Set(alleSitzplatzIds)
        return zuordnungen.map(\.sitzplatzId).filter { vorhanden.contains($0) }
    }

    public var freieSitzplatzIds: [String] {
        let belegt = Set(zuordnungenAlsWoerterbuch().keys)
        return alleSitzplatzIds.filter { !belegt.contains($0) }
    }
}

// MARK: - Raumname

extension Sitzplan {
    /// Der anzuzeigende Raumname.
    ///
    /// Er steht **nicht** im Dokument — die eingefrorene Raumkopie enthaelt
    /// Geometrie, keinen Namen. Beim Laden wird er aus dem Raum nachgereicht;
    /// fehlt der Raum, gilt `"Raum"`.
    public func raumname(ausRaum raum: Raum?) -> String {
        guard let name = raum?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return Sitzplan.raumnameRueckfall }
        return name
    }
}
