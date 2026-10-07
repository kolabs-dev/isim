import XCTest

/// UI tests: the app runs as its own simulator process, driven like XCUITest does.
final class AppUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-startCount", "5"]
        app.launchEnvironment = ["UITEST_MODE": "ui-test"]
        app.launch()
    }

    override func tearDown() { app.terminate() }

    func testLaunchShowsLibraries() {
        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["greeting"].label, "«Hello, isim»")
        XCTAssertEqual(app.staticTexts["sums"].label, "MathKit 5 · XCFramework 7 · Units 20000")
        XCTAssertTrue(app.navigationBars["Toolchain"].exists)
        XCTAssertEqual(app.staticTexts["mode"].label, "mode: ui-test", "launchEnvironment")
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 5", "launchArguments")
    }

    func testTapIncrements() {
        let add = app.buttons["Add"]
        XCTAssertTrue(add.exists)
        XCTAssertTrue(add.isHittable)
        add.tap()
        add.tap()
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 7")
        XCTAssertEqual(app.buttons["increment"].label, "Add", "identifier and label both match")
    }

    func testTypeText() {
        let field = app.textFields["name"]
        XCTAssertEqual(field.placeholderValue, "Name")
        field.tap()
        XCTAssertTrue(field.hasFocus)
        field.typeText("Ada\n")
        XCTAssertEqual(app.staticTexts["echo"].label, "echo: Ada")
        XCTAssertEqual(app.textFields.element.value as? String, "Ada")
    }

    func testSwitchAndQueries() {
        let toggle = app.switches["toggle"]
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertGreaterThanOrEqual(app.staticTexts.count, 6)
        XCTAssertFalse(app.buttons["Nope"].exists)
        XCTAssertTrue(app.descendants(matching: .button).matching(identifier: "increment").firstMatch.exists)
    }

    func testRelaunchResetsState() {
        app.buttons["Add"].tap()
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 6")
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launchArguments = []
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 0")
    }
}

/// Deliberately failing UI test (skipped by the scheme; run with -only-testing to prove failures are reported).
final class ExpectedUIFailureTests: XCTestCase {
    func testMissingButton() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Does not exist"].tap()
        app.terminate()
    }
}
