import Foundation
import Testing

@testable import Domain

@Suite("Moebeltyp-Beschriftung")
struct MoebelTests {

    @Test("Jeder Moebeltyp hat eine deutsche Beschriftung fuer die Oberflaeche")
    func beschriftungJeTyp() {
        #expect(Moebeltyp.einzeltisch.beschriftung == "Einzeltisch")
        #expect(Moebeltyp.doppeltisch.beschriftung == "Doppeltisch")
        #expect(Moebeltyp.pult.beschriftung == "Lehrerpult")
        #expect(Moebeltyp.tafel.beschriftung == "Tafel")
        #expect(Moebeltyp.tuer.beschriftung == "Tür")
        #expect(Moebeltyp.fenster.beschriftung == "Fenster")
    }

    @Test("Jeder Fall von Moebeltyp.allCases hat eine nicht-leere Beschriftung")
    func alleFaelleAbgedeckt() {
        for typ in Moebeltyp.allCases {
            #expect(!typ.beschriftung.isEmpty, "Beschriftung fuer \(typ) darf nicht leer sein")
        }
    }

    @Test("Die Beschriftungen sind untereinander eindeutig")
    func beschriftungenEindeutig() {
        let beschriftungen = Moebeltyp.allCases.map(\.beschriftung)
        #expect(Set(beschriftungen).count == beschriftungen.count,
                "Zwei Moebeltypen mit derselben Beschriftung waeren in der Oberflaeche nicht unterscheidbar")
    }

    @Test("Die Beschriftung haengt nicht vom Dokumentschluessel-Rundgang ab")
    func beschriftungNachTolerantemLesen() {
        // Ein unbekannter Dokumentschluessel wird zu .einzeltisch — die
        // Beschriftung muss dann konsequent "Einzeltisch" lauten.
        let unbekannt = Moebeltyp(dokumentSchluessel: "irgendwas_unbekanntes")
        #expect(unbekannt == .einzeltisch)
        #expect(unbekannt.beschriftung == "Einzeltisch")
    }
}