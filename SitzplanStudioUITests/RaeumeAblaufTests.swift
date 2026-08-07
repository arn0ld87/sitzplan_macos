import XCTest

/// Oberflächentests für den Räume-Ablauf: Anlegen, Bearbeiten, Löschen,
/// Validierung, Umschalten zwischen 2D- und 3D-Ansicht.
///
/// Sie laufen **nie** gegen die Datenbank der Benutzerin: Jeder Test bekommt ein
/// eigenes temporäres Verzeichnis über `SITZPLAN_SPEICHERORT` und räumt es
/// hinterher weg — wie in `KlassenAblaufTests`.
final class RaeumeAblaufTests: XCTestCase {

    private var speicherort: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        speicherort = FileManager.default.temporaryDirectory
            .appendingPathComponent("SitzplanStudioUITest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: speicherort, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let speicherort, FileManager.default.fileExists(atPath: speicherort.path) {
            try FileManager.default.removeItem(at: speicherort)
        }
    }

    private func starten() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SITZPLAN_SPEICHERORT"] = speicherort.path
        app.launch()
        return app
    }

    /// Wechselt von der Standardansicht „Klassen“ zum Abschnitt „Räume“.
    private func wechsleZuRaeume(_ app: XCUIApplication) {
        // Der Abschnitt ist ein Button in der Seitenleiste — auf CI (Xcode 26)
        // wird der Button-Label-Text als `button["Räume"]` exponiert, nicht als
        // `staticText["Räume"]`. Der Button ist ohnehin der Interaktionspunkt.
        let eintrag = app.buttons["Räume"]
        XCTAssertTrue(eintrag.waitForExistence(timeout: 5), "Der Abschnitt „Räume“ muss in der Seitenleiste stehen")
        eintrag.click()
    }

    // MARK: - Grundzustand

    func testRaeumeAbschnittZeigtLeerenZustandOhneDaten() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        wechsleZuRaeume(app)

        XCTAssertTrue(app.staticTexts["Noch keine Räume"].waitForExistence(timeout: 5),
                      "Ohne Räume gehört ein erklärender leerer Zustand hin, keine leere Fläche")
    }

    // MARK: - Anlegen

    func testRaumAnlegen() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()

        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("Raum 101")

        app.buttons["Sichern"].firstMatch.click()

        XCTAssertTrue(app.staticTexts["Raum 101"].waitForExistence(timeout: 5),
                      "Der angelegte Raum muss in der Liste stehen")
    }

    func testNeuerRaumUeberTastenkombination() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        // ⌘⇧N ist der Räume-eigene Kurzbefehl — ⌘N bleibt „Neue Klasse“ vorbehalten.
        app.typeKey("n", modifierFlags: [.command, .shift])

        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5), "⌘⇧N muss die Maske öffnen")
        feld.typeText("Fachraum")
        feld.typeKey(.enter, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["Fachraum"].waitForExistence(timeout: 5),
                      "Der Ablauf muss vollständig ohne Maus gehen")
    }

    /// Der Neustarttest. Er braucht einen **persistenten** Speicher — mit einem
    /// Speicher im Arbeitsspeicher wäre er wertlos, weil der absichtlich alles
    /// vergisst.
    func testRaumUeberstehtNeustart() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()
        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("Raum 202")
        app.buttons["Sichern"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Raum 202"].waitForExistence(timeout: 5))

        app.terminate()

        let neu = starten()
        wechsleZuRaeume(neu)
        XCTAssertTrue(neu.staticTexts["Raum 202"].waitForExistence(timeout: 10),
                      "Nach dem Neustart muss der Raum noch da sein — sonst ist der Speicher wertlos")
    }

    // MARK: - Validierung

    func testUngueltigeBreiteZeigtFehlermeldungUndSchliesstNicht() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()
        let name = app.textFields["Name des Raums"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Ungültiger Raum")

        let breite = app.textFields["Breite"]
        XCTAssertTrue(breite.waitForExistence(timeout: 5))
        breite.click()
        breite.typeKey("a", modifierFlags: .command)
        breite.typeText("0")

        app.buttons["Sichern"].firstMatch.click()

        // Die Fehlermeldung ueberschreibt ihre Accessibility-Beschriftung mit
        // dem Praefix "Fehler: " (siehe RaumBearbeiten.swift) — die Abfrage muss
        // das Praefix mit abfragen, sonst greift sie ins Leere.
        XCTAssertTrue(app.staticTexts["Fehler: Breite: Muss größer als 0 sein."].waitForExistence(timeout: 5),
                      "Eine fachlich ungültige Breite muss inline gemeldet werden")
        XCTAssertFalse(app.staticTexts["Ungültiger Raum"].waitForExistence(timeout: 2),
                       "Bei einem Fehler darf der Raum nicht in der Liste auftauchen — die Maske bleibt offen")
    }

    // MARK: - Bearbeiten

    func testRaumBearbeiten() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()
        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("Raum Alt")
        app.buttons["Sichern"].firstMatch.click()

        let eintrag = app.staticTexts["Raum Alt"]
        XCTAssertTrue(eintrag.waitForExistence(timeout: 5))

        eintrag.rightClick()
        app.menuItems["Bearbeiten…"].firstMatch.click()

        let umbenennenFeld = app.textFields["Name des Raums"]
        XCTAssertTrue(umbenennenFeld.waitForExistence(timeout: 5))
        umbenennenFeld.click()
        umbenennenFeld.typeKey("a", modifierFlags: .command)
        umbenennenFeld.typeText("Raum Neu")
        app.buttons["Sichern"].firstMatch.click()

        XCTAssertTrue(app.staticTexts["Raum Neu"].waitForExistence(timeout: 5),
                      "Der umbenannte Raum muss unter dem neuen Namen auftauchen")
        XCTAssertFalse(app.staticTexts["Raum Alt"].waitForExistence(timeout: 2),
                       "Der alte Name darf nicht mehr auftauchen")
    }

    // MARK: - Löschen

    func testRaumLoeschenEntferntIhnAusDerListe() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()
        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("Raum Loeschbar")
        app.buttons["Sichern"].firstMatch.click()

        let eintrag = app.staticTexts["Raum Loeschbar"]
        XCTAssertTrue(eintrag.waitForExistence(timeout: 5))

        eintrag.rightClick()
        app.menuItems["Löschen…"].firstMatch.click()

        XCTAssertTrue(app.staticTexts["Raum löschen?"].waitForExistence(timeout: 5),
                      "Löschen muss erst bestätigt werden")
        app.buttons["Löschen"].firstMatch.click()

        XCTAssertFalse(app.staticTexts["Raum Loeschbar"].waitForExistence(timeout: 3),
                       "Nach dem Bestätigen muss der Raum aus der Liste verschwinden")
        XCTAssertTrue(app.staticTexts["Noch keine Räume"].waitForExistence(timeout: 5),
                      "Ohne verbleibende Räume gehört wieder der leere Zustand hin")
    }

    // MARK: - 2D/3D-Umschaltung

    func testUmschaltenZwischen2DUnd3DAnsicht() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        wechsleZuRaeume(app)

        app.buttons["Neuer Raum"].firstMatch.click()
        let feld = app.textFields["Name des Raums"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("Raum 3D")
        app.buttons["Sichern"].firstMatch.click()

        let eintrag = app.staticTexts["Raum 3D"]
        XCTAssertTrue(eintrag.waitForExistence(timeout: 5))
        eintrag.click()

        let dreiD = app.buttons["3D-Ansicht"]
        XCTAssertTrue(dreiD.waitForExistence(timeout: 5), "Der 2D-Editor muss einen Umschalter zur 3D-Ansicht bieten")
        dreiD.click()

        let zweiD = app.buttons["2D-Editor"]
        XCTAssertTrue(zweiD.waitForExistence(timeout: 5), "Aus der 3D-Ansicht muss man zurück zum 2D-Editor können")
        zweiD.click()

        XCTAssertTrue(app.buttons["3D-Ansicht"].waitForExistence(timeout: 5),
                      "Nach dem Zurückschalten muss wieder der 2D-Editor mit seinem Umschalter stehen")
    }
}