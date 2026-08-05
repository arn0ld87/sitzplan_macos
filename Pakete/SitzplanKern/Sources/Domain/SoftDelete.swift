import Foundation

/// Die Regeln des weichen Loeschens.
///
/// Loeschen setzt ein Datumsfeld, es entfernt keinen Datensatz. Daraus folgt
/// mehr als ein Filter — und wer die Folgen uebersieht, baut Datenverlust ein.
public enum SoftDelete {
    /// Loescht weich. Ein bereits geloeschter Datensatz behaelt seinen
    /// **urspruenglichen** Zeitstempel.
    ///
    /// Warum: Sonst wandert der Eintrag beim zweiten Loeschen an die Spitze des
    /// Papierkorbs, obwohl sich nichts geaendert hat — und die Klassenzuordnung
    /// ueber gleiche Zeitstempel (siehe ``schuelerDerKlasse(_:schueler:)``)
    /// bricht.
    public static func loeschzeitpunkt(bisher: Date?, jetzt: Date) -> Date {
        bisher ?? jetzt
    }

    /// Welche Schueler traegt diese Klasse?
    ///
    /// - Bei einer **aktiven** Klasse: alle nicht geloeschten.
    /// - Bei einer **geloeschten** Klasse: die mit **identischem** Zeitstempel.
    ///   Wer vorher einzeln geloescht wurde, traegt einen aelteren und bleibt
    ///   geloescht — auch nach dem Wiederherstellen der Klasse.
    ///
    /// - Important: Das ist der Grund, warum ein Klassen-Papierkorb ueberhaupt
    ///   Schueler enthaelt. Wer hier stur nach „nicht geloescht“ filtert, holt
    ///   eine leere Klasse aus dem Papierkorb.
    public static func schuelerDerKlasse(_ klasse: Klasse, schueler: [Schueler]) -> [Schueler] {
        let ausDieserKlasse = schueler.filter { $0.klasseId == klasse.id }

        guard let geloeschtAm = klasse.geloeschtAm else {
            return ausDieserKlasse.filter { !$0.istGeloescht }
        }
        return ausDieserKlasse.filter { $0.geloeschtAm == geloeschtAm }
    }

    /// Blendet Zuweisungen geloeschter Schueler aus.
    ///
    /// Die Zuweisung bleibt im Dokument stehen und wird nur nicht angezeigt. Ein
    /// wiederhergestellter Schueler bekommt damit seinen Platz zurueck.
    public static func sichtbareZuordnungen(
        _ zuordnungen: [Zuordnung],
        aktiveSchuelerIds: Set<String>
    ) -> [Zuordnung] {
        zuordnungen.filter { aktiveSchuelerIds.contains($0.schuelerId) }
    }
}

/// Ein Eintrag im Papierkorb.
public struct Papierkorbeintrag: Sendable, Equatable, Identifiable {
    public enum Art: String, Sendable, CaseIterable, Equatable {
        case klasse, schueler, raum, sitzplan, sitzregel
    }

    public var id: UUID
    public var art: Art
    public var bezeichnung: String
    public var geloeschtAm: Date
    /// Wie viele Datensaetze mit diesem Eintrag zurueckkommen — bei einer Klasse
    /// ihre Schueler.
    public var mitgeloeschteAnzahl: Int

    public init(
        id: UUID,
        art: Art,
        bezeichnung: String,
        geloeschtAm: Date,
        mitgeloeschteAnzahl: Int = 0
    ) {
        self.id = id
        self.art = art
        self.bezeichnung = bezeichnung
        self.geloeschtAm = geloeschtAm
        self.mitgeloeschteAnzahl = mitgeloeschteAnzahl
    }
}

extension Array where Element == Papierkorbeintrag {
    /// Papierkorbreihenfolge: zuletzt Geloeschtes zuerst.
    ///
    /// Bei gleichem Zeitstempel entscheidet die Bezeichnung, damit die
    /// Reihenfolge zwischen zwei Aufrufen stabil bleibt. Eine Liste, die bei
    /// jedem Oeffnen anders aussieht, ist unbrauchbar.
    public func inPapierkorbreihenfolge() -> [Papierkorbeintrag] {
        sorted { links, rechts in
            if links.geloeschtAm != rechts.geloeschtAm {
                return links.geloeschtAm > rechts.geloeschtAm
            }
            return links.bezeichnung.localizedStandardCompare(rechts.bezeichnung) == .orderedAscending
        }
    }
}
