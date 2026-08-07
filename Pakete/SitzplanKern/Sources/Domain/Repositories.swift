import Foundation

// Repository-Protokolle. Sie gehoeren in die Domaene, ihre Umsetzung nach
// `SitzplanSpeicher`. Die Oberflaeche kennt nur diese Protokolle — deshalb
// laesst sie sich ohne Datenbank testen.
//
// Papierkorb-Abfragen sind ausdruecklich **eigene Methoden**, keine Variante
// mit Schalter. Ein `laden(inklusiveGeloeschter: Bool)` sieht sparsam aus und
// ist die zuverlaessigste Art, versehentlich geloeschte Datensaetze in einer
// Liste anzuzeigen.

public protocol KlassenRepository: Sendable {
    /// Alle aktiven Klassen, alphabetisch.
    func aktive() async throws(Domaenenfehler) -> [Klasse]

    /// Eine Klasse, auch eine geloeschte.
    func klasse(id: UUID) async throws(Domaenenfehler) -> Klasse?

    @discardableResult
    func anlegen(name: String, notizen: String?) async throws(Domaenenfehler) -> Klasse

    @discardableResult
    func umbenennen(id: UUID, auf name: String) async throws(Domaenenfehler) -> Klasse

    /// Weich loeschen. Nimmt die Schueler der Klasse mit demselben Zeitstempel
    /// mit.
    func loeschen(id: UUID) async throws(Domaenenfehler)

    /// Wiederherstellen. Bringt die Schueler zurueck, die mit derselben
    /// Loeschung gegangen sind — nicht die vorher einzeln geloeschten.
    func wiederherstellen(id: UUID) async throws(Domaenenfehler)

    /// Nur geloeschte Klassen, fuer den Papierkorb.
    func geloeschte() async throws(Domaenenfehler) -> [Papierkorbeintrag]
}

public protocol SchuelerRepository: Sendable {
    /// Die Schueler einer Klasse. Bei einer aktiven Klasse die ungeloeschten,
    /// bei einer geloeschten die mit identischem Zeitstempel.
    func derKlasse(_ klasseId: UUID) async throws(Domaenenfehler) -> [Schueler]

    @discardableResult
    func anlegen(_ schueler: Schueler) async throws(Domaenenfehler) -> Schueler

    @discardableResult
    func aktualisieren(_ schueler: Schueler) async throws(Domaenenfehler) -> Schueler

    func loeschen(id: UUID) async throws(Domaenenfehler)
    func wiederherstellen(id: UUID) async throws(Domaenenfehler)
}

public protocol RaumRepository: Sendable {
    func aktive() async throws(Domaenenfehler) -> [Raum]
    func raum(id: UUID) async throws(Domaenenfehler) -> Raum?

    @discardableResult
    func anlegen(_ raum: Raum) async throws(Domaenenfehler) -> Raum

    @discardableResult
    func aktualisieren(_ raum: Raum) async throws(Domaenenfehler) -> Raum

    func loeschen(id: UUID) async throws(Domaenenfehler)
    func wiederherstellen(id: UUID) async throws(Domaenenfehler)
}

public protocol SitzplanRepository: Sendable {
    func aktive() async throws(Domaenenfehler) -> [Sitzplan]
    func derKlasse(_ klasseId: UUID) async throws(Domaenenfehler) -> [Sitzplan]
    func sitzplan(id: UUID) async throws(Domaenenfehler) -> Sitzplan?

    @discardableResult
    func anlegen(_ plan: Sitzplan) async throws(Domaenenfehler) -> Sitzplan

    @discardableResult
    func aktualisieren(_ plan: Sitzplan) async throws(Domaenenfehler) -> Sitzplan

    func loeschen(id: UUID) async throws(Domaenenfehler)
    func wiederherstellen(id: UUID) async throws(Domaenenfehler)
}

public protocol SitzregelRepository: Sendable {
    func derKlasse(_ klasseId: UUID) async throws(Domaenenfehler) -> [Sitzregel]

    @discardableResult
    func anlegen(_ regel: Sitzregel) async throws(Domaenenfehler) -> Sitzregel

    func loeschen(id: UUID) async throws(Domaenenfehler)
}
