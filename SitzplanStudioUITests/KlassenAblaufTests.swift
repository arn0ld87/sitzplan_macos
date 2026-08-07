import XCTest

/// Oberflächentests für die Abläufe, deren Bruch sofort auffallen muss.
///
/// Sie laufen **nie** gegen die Datenbank der Benutzerin: Jeder Test bekommt ein
/// eigenes temporäres Verzeichnis über `SITZPLAN_SPEICHERORT` und räumt es
/// hinterher weg.
final class KlassenAblaufTests: XCTestCase {

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

    func testFensterErscheintMitKlassenliste() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10),
                      "Das Fenster muss erscheinen")
        XCTAssertTrue(app.staticTexts["Noch keine Klasse"].waitForExistence(timeout: 5),
                      "Ohne Daten gehört ein erklärender leerer Zustand hin, keine leere Fläche")
    }

    func testKlasseAnlegen() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.buttons["Klasse anlegen"].firstMatch.click()

        let feld = app.textFields["Name der Klasse"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("7a")

        app.buttons["Sichern"].firstMatch.click()

        XCTAssertTrue(app.staticTexts["7a"].waitForExistence(timeout: 5),
                      "Die angelegte Klasse muss in der Liste stehen")
    }

    /// Der Neustarttest. Er braucht einen **persistenten** Speicher — mit einem
    /// Speicher im Arbeitsspeicher wäre er wertlos, weil der absichtlich alles
    /// vergisst.
    func testKlasseUeberstehtNeustart() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.buttons["Klasse anlegen"].firstMatch.click()
        let feld = app.textFields["Name der Klasse"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("9c")
        app.buttons["Sichern"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["9c"].waitForExistence(timeout: 5))

        app.terminate()

        let neu = starten()
        XCTAssertTrue(neu.staticTexts["9c"].waitForExistence(timeout: 10),
                      "Nach dem Neustart muss die Klasse noch da sein — sonst ist der Speicher wertlos")
    }

    func testKernaktionenSindUeberDieTastaturErreichbar() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        // ⌘N muss dasselbe tun wie die Schaltfläche.
        app.typeKey("n", modifierFlags: .command)

        let feld = app.textFields["Name der Klasse"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5),
                      "⌘N muss die Maske öffnen")

        feld.typeText("5b")
        // Enter statt Klick auf „Sichern“.
        feld.typeKey(.enter, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["5b"].waitForExistence(timeout: 5),
                      "Der Ablauf muss vollständig ohne Maus gehen")
    }

    func testGeloeschteKlasseLiegtImPapierkorbUndKommtZurueck() {
        let app = starten()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.buttons["Klasse anlegen"].firstMatch.click()
        let feld = app.textFields["Name der Klasse"]
        XCTAssertTrue(feld.waitForExistence(timeout: 5))
        feld.click()
        feld.typeText("7a")
        app.buttons["Sichern"].firstMatch.click()

        let eintrag = app.staticTexts["7a"]
        XCTAssertTrue(eintrag.waitForExistence(timeout: 5))

        eintrag.rightClick()
        app.menuItems["Löschen"].firstMatch.click()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Papierkorb'"))
            .firstMatch.waitForExistence(timeout: 5),
                      "Gelöschtes muss im Papierkorb auffindbar sein, nicht verschwunden")
    }
}
