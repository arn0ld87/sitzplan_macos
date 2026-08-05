import Foundation

/// Die Kennung eines Sitzplatzes: `<objektId>__sitz_<n>`, `n` beginnt bei 1.
///
/// Vertrag zwischen Dokument und Oberflaeche (`docs/datenvertrag.md`). Wer ihn
/// aendert, macht bestehende Zuordnungen unlesbar.
///
/// Drei Regeln, die leicht zu uebersehen sind und einzeln gepruefte Fixtures
/// haben:
///
/// 1. Getrennt wird am **letzten** Vorkommen des Trenners, damit Objektkennungen,
///    die selbst so aussehen, den Rueckweg ueberstehen:
///    `obj__sitz_1__sitz_2` zerfaellt in `obj__sitz_1` und 2.
/// 2. Der Rest muss **vollstaendig aus Ziffern** bestehen — `__sitz_1e3` ist
///    ungueltig, obwohl eine nachsichtige Zahlkonvertierung 1000 daraus machen
///    wuerde.
/// 3. Die Kennung muss **kanonisch** sein: Wer sie neu baut, muss dieselbe
///    Zeichenkette erhalten. `__sitz_007` ist damit ungueltig.
///
/// Ungueltige Kennungen ergeben `nil` — keinen Fehler und keinen Absturz.
public enum Sitzplatzkennung {
    /// Der Trenner. Bewusst eine Konstante: Er steht in jedem gespeicherten
    /// Dokument und ist nicht anpassbar.
    public static let trenner = "__sitz_"

    /// Baut eine Kennung. `nummer` beginnt bei 1.
    public static func bauen(objektId: String, nummer: Int) -> String {
        "\(objektId)\(trenner)\(nummer)"
    }

    /// Zerlegt eine Kennung. Gibt `nil` zurueck, wenn sie ungueltig oder nicht
    /// kanonisch ist.
    public static func zerlegen(_ kennung: String) -> (objektId: String, nummer: Int)? {
        guard let bereich = kennung.range(of: trenner, options: .backwards) else { return nil }

        let objektId = String(kennung[kennung.startIndex..<bereich.lowerBound])
        let nummernteil = String(kennung[bereich.upperBound...])

        guard !objektId.isEmpty, !nummernteil.isEmpty else { return nil }

        // Reine Ziffernfolge. Schliesst "-1", "1e3", "1 " und Unicode-Ziffern aus,
        // die `Int(_:)` sonst schlucken wuerde.
        guard nummernteil.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let nummer = Int(nummernteil), nummer >= 1 else { return nil }

        // Kanonisch: Der Rueckweg muss dieselbe Zeichenkette ergeben. Faengt
        // fuehrende Nullen ab ("007").
        guard String(nummer) == nummernteil else { return nil }

        return (objektId, nummer)
    }

    /// Ist die Kennung gueltig und kanonisch?
    public static func istGueltig(_ kennung: String) -> Bool {
        zerlegen(kennung) != nil
    }
}

extension Moebeltyp {
    /// Die Sitzplaetze eines Moebelstuecks, abgeleitet aus Typ und Tabelle —
    /// nicht frei vergeben.
    ///
    /// Die Lage ist in Zentimetern relativ zur linken oberen Ecke angegeben und
    /// gilt **vor** jeder Drehung:
    ///
    /// ```
    /// lokalX_cm = breite * (i + 0.5) / anzahl        i = 0 … anzahl-1
    /// lokalY_cm = tiefe / 2
    /// ```
    ///
    /// Fuer den Doppeltisch ergibt das 30 cm und 90 cm, fuer den Einzeltisch 30 cm.
    public func sitzplaetze(objektId: String) -> [Sitzplatz] {
        let anzahl = anzahlSitzplaetze
        guard anzahl > 0 else { return [] }

        return (0..<anzahl).map { i in
            Sitzplatz(
                id: Sitzplatzkennung.bauen(objektId: objektId, nummer: i + 1),
                objektId: objektId,
                lokalXCm: breiteCm * (Double(i) + 0.5) / Double(anzahl),
                lokalYCm: tiefeCm / 2,
                bezeichnung: "Platz \(i + 1)"
            )
        }
    }
}
