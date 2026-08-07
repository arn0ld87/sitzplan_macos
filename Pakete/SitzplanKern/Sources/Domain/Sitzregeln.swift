import Foundation

/// Ein Verstoss gegen eine Sitzregel.
public struct Regelkonflikt: Sendable, Equatable, Identifiable {
    public var id: UUID { regelId }
    public var regelId: UUID
    public var art: Regelart
    public var schuelerA: UUID
    public var schuelerB: UUID

    public init(regelId: UUID, art: Regelart, schuelerA: UUID, schuelerB: UUID) {
        self.regelId = regelId
        self.art = art
        self.schuelerA = schuelerA
        self.schuelerB = schuelerB
    }
}

/// Prueft Sitzregeln gegen eine Sitzverteilung.
///
/// Nachbarschaft ist eng definiert: Zwei Schueler sitzen nebeneinander, wenn
/// ihre Plaetze zum **selben Moebelstueck** gehoeren. Ein Einzeltisch hat damit
/// keine Nachbarn, ein Doppeltisch genau einen. Die Zugehoerigkeit steckt in der
/// Sitzplatzkennung selbst — eine Moebelliste wird nicht gebraucht.
public enum Sitzregelpruefung {
    /// Gehoeren zwei Plaetze zum selben Moebelstueck?
    ///
    /// Derselbe Platz ist nicht sein eigener Nachbar.
    public static func sindNachbarn(_ platzA: String, _ platzB: String) -> Bool {
        guard platzA != platzB,
              let a = Sitzplatzkennung.zerlegen(platzA),
              let b = Sitzplatzkennung.zerlegen(platzB)
        else { return false }
        return a.objektId == b.objektId
    }

    /// Prueft alle Regeln einer Klasse gegen die Verteilung.
    ///
    /// - Parameters:
    ///   - zuordnungen: Die **geordnete** Liste aus dem Dokument. Die Reihenfolge
    ///     entscheidet: Sitzt ein Schueler auf mehreren Plaetzen, zaehlt der
    ///     zuletzt eingetragene.
    ///   - regeln: Regeln aller Klassen. Regeln fremder Klassen werden
    ///     uebersprungen.
    ///   - klasseId: Die Klasse, um die es geht.
    ///
    /// - Returns: Die verletzten Regeln, in der Reihenfolge der Regelliste.
    ///
    /// Was diese Pruefung **nicht** tut: Widersprueche aufloesen. Stehen zu
    /// einem Paar sowohl `nichtNeben` als auch `mussNeben`, wird jede Regel fuer
    /// sich bewertet — genau eine davon ist dann verletzt, und beide bleiben
    /// sichtbar. Ein Widerspruch ist eine Frage an die Lehrkraft, keine an den
    /// Rechner.
    public static func pruefen(
        zuordnungen: [Zuordnung],
        regeln: [Sitzregel],
        klasseId: UUID
    ) -> [Regelkonflikt] {
        // Schueler → Platz, in Dokumentreihenfolge. Spaetere Eintraege gewinnen.
        var platzJeSchueler: [String: String] = [:]
        for z in zuordnungen {
            platzJeSchueler[Kennungsvergleich.kanonisch(z.schuelerId)] = z.sitzplatzId
        }

        return regeln.compactMap { regel in
            guard regel.klasseId == klasseId, !regel.istGeloescht else { return nil }

            // Nicht gesetzt heisst nicht bewertbar — nicht „erfuellt“ und nicht
            // „verletzt“. Wer hier einen Konflikt meldet, beschwert sich ueber
            // einen Sitzplan, der noch gar nicht gestellt ist.
            guard let platzA = platzJeSchueler[Kennungsvergleich.kanonisch(regel.schuelerA)],
                  let platzB = platzJeSchueler[Kennungsvergleich.kanonisch(regel.schuelerB)]
            else { return nil }

            let nebeneinander = sindNachbarn(platzA, platzB)
            let verletzt = switch regel.art {
            case .nichtNeben: nebeneinander
            case .mussNeben: !nebeneinander
            }

            guard verletzt else { return nil }
            return Regelkonflikt(
                regelId: regel.id,
                art: regel.art,
                schuelerA: regel.schuelerA,
                schuelerB: regel.schuelerB
            )
        }
    }
}
