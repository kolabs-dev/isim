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

    func testTypeSemicolon() {
        let field = app.textFields["name"]
        field.tap()
        field.typeText("a;b\n")
        XCTAssertEqual(app.staticTexts["echo"].label, "echo: a;b", "';' is typed like any character")
    }

    func testKeyboardKeys() {
        XCTAssertEqual(app.keyboards.count, 0, "no keyboard before a field has focus")
        app.textFields["name"].tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 1)
        XCTAssertTrue(app.keys["space"].exists && app.keys["delete"].exists && app.keys["more"].exists)
        app.keys["H"].tap()                          // sentence capitalization: the first letter is a capital
        app.keys["i"].tap()
        XCTAssertEqual(app.textFields["name"].value as? String, "Hi")
        app.keys["delete"].tap()
        app.keys["o"].tap()
        app.keyboards.buttons["return"].tap()
        XCTAssertEqual(app.staticTexts["echo"].label, "echo: Ho")
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5), "return ends editing: the keyboard goes away")
    }

    func testSystemAlertOnSpringboard() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.buttons["notify"].tap()
        let allow = springboard.alerts.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        XCTAssertTrue(springboard.alerts.element.label.hasSuffix("Would Like to Send You Notifications"))
        XCTAssertEqual(app.alerts.count, 0, "a permission alert belongs to SpringBoard, not the app")
        allow.tap()
        XCTAssertTrue(springboard.alerts.element.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["permission"].label, "notifications: allowed")
    }

    func testInterruptionMonitor() {
        var handled = ""
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            handled = alert.label
            alert.buttons["Allow"].tap()
            return true
        }
        app.buttons["camera"].tap()
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.element.waitForExistence(timeout: 5))
        app.buttons["Add"].tap()                     // an interaction with the app: the monitor handles the alert first
        XCTAssertTrue(handled.hasSuffix("Would Like to Access the Camera"), handled)
        XCTAssertEqual(app.staticTexts["permission"].label, "camera: allowed")
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 6", "then the tap reaches the app")
    }

    func testHomeAndActivate() {
        app.buttons["Add"].tap()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(app.staticTexts["lifecycle"].label, "background: 1")
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 6", "the same process: its state is kept")
    }

    func testRotation() {
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
        let portrait = app.windows.firstMatch.frame
        XCTAssertGreaterThan(portrait.height, portrait.width)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft, "read back from the app's device")
        let landscape = app.windows.firstMatch.frame
        XCTAssertGreaterThan(landscape.width, landscape.height)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
    }

    func testGestures() {
        app.buttons["gestures"].tap()
        XCTAssertTrue(app.navigationBars["Gestures"].waitForExistence(timeout: 5))
        let status = app.staticTexts["status"]
        let area = app.otherElements["swipeArea"]
        area.swipeLeft()
        XCTAssertEqual(status.label, "swipe left")
        area.swipeRight()
        XCTAssertEqual(status.label, "swipe right")
        area.swipeUp()
        XCTAssertEqual(status.label, "swipe up")
        area.swipeDown()
        XCTAssertEqual(status.label, "swipe down")

        app.buttons["hold"].press(forDuration: 1.0)
        XCTAssertEqual(status.label, "long press")

        let slider = app.sliders["slider"]
        XCTAssertEqual(slider.value as? String, "50%")
        slider.adjust(toNormalizedSliderPosition: 0.9)
        let v = Int((slider.value as? String ?? "").dropLast()) ?? -1
        XCTAssertTrue((85...95).contains(v), "slider at \(v)%")

        let pad = app.otherElements["pad"]
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: 55, dy: 35)).tap()
        XCTAssertEqual(status.label, "tap 5 3")
        let start = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        start.press(forDuration: 0.3, thenDragTo: start.withOffset(CGVector(dx: 120, dy: 0)))
        let parts = status.label.split(separator: " ")
        XCTAssertEqual(parts.first, "drag", status.label)
        if parts.count == 3, let dx = Int(parts[1]), let dy = Int(parts[2]) {
            XCTAssertTrue((10...12).contains(dx) && dy == 0, status.label)
        }

        let list = app.tables["list"]
        XCTAssertTrue(list.cells.staticTexts["Row 0"].exists)
        list.swipeUp()
        XCTAssertNotEqual(app.staticTexts["topRow"].label, "top row: 0", "the table scrolled")
        list.swipeDown()
        list.swipeDown()
        XCTAssertTrue(app.staticTexts["top row: 0"].waitForExistence(timeout: 5), "back at the top")
    }
}

/// Multi-touch gestures, velocities, element snapshots, accessibility audits, privacy resets and the device appearance.
final class AppMultitouchUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        app.terminate()
    }

    private func openMultitouch() -> XCUIElement {
        app.buttons["multitouch"].tap()
        XCTAssertTrue(app.navigationBars["Multitouch"].waitForExistence(timeout: 5))
        return app.staticTexts["status"]
    }

    func testPinchRotateAndTaps() {
        let status = openMultitouch()
        let canvas = app.otherElements["canvas"]
        canvas.pinch(withScale: 2, velocity: 2)
        XCTAssertEqual(status.label, "pinch 2.0")
        canvas.pinch(withScale: 0.5, velocity: -1)
        XCTAssertEqual(status.label, "pinch 0.5")
        canvas.rotate(.pi / 2, withVelocity: .pi)
        XCTAssertEqual(status.label, "rotate 90")
        canvas.twoFingerTap()
        XCTAssertEqual(status.label, "two-finger tap")
        canvas.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        XCTAssertEqual(status.label, "triple tap")
    }

    func testDragToElement() {
        let status = openMultitouch()
        app.staticTexts["chip"].press(forDuration: 0.2, thenDragTo: app.staticTexts["target"])
        XCTAssertEqual(status.label, "dropped on target")
        app.staticTexts["chip"].press(forDuration: 0.2, thenDragTo: app.staticTexts["target"], withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertEqual(status.label, "dropped on target")
    }

    func testSwipeVelocities() {
        app.buttons["gestures"].tap()
        XCTAssertTrue(app.navigationBars["Gestures"].waitForExistence(timeout: 5))
        let area = app.otherElements["swipeArea"]
        area.swipeLeft(velocity: .fast)
        XCTAssertEqual(app.staticTexts["status"].label, "swipe left")
        area.swipeUp(velocity: .default)
        XCTAssertEqual(app.staticTexts["status"].label, "swipe up")
        area.swipeRight(velocity: XCUIGestureVelocity(1500))
        XCTAssertEqual(app.staticTexts["status"].label, "swipe right")
    }

    func testSnapshot() throws {
        _ = openMultitouch()
        func all(_ s: XCUIElementSnapshot) -> [XCUIElementSnapshot] { [s] + s.children.flatMap(all) }
        let root = try app.snapshot()
        XCTAssertTrue(all(root).contains { $0.identifier == "canvas" && $0.frame.height == 260 }, "the app's tree")
        let canvas = try app.otherElements["canvas"].snapshot()
        XCTAssertEqual(canvas.elementType, .other)
        XCTAssertEqual(canvas.dictionaryRepresentation[.identifier] as? String, "canvas")
        XCTAssertThrowsError(try app.buttons["Does not exist"].snapshot())
    }

    func testAccessibilityAudit() throws {
        _ = openMultitouch()
        var found: [String] = []
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion]) { issue in
            if issue.element?.identifier == "tiny" { found.append(issue.compactDescription) }
            return true                                     // handled: the test does not fail
        }
        XCTAssertEqual(found.sorted(), ["Element has no description", "Hit area is too small"])
        try app.performAccessibilityAudit(for: .contrast)   // not checked by isim: no issues
    }

    func testResetAuthorizationStatus() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        defer { app.resetAuthorizationStatus(for: .camera) }      // the other tests are asked again too
        app.resetAuthorizationStatus(for: .camera)
        XCTAssertEqual(app.state, .notRunning, "like iOS, resetting terminates the app")
        app.launch()
        app.buttons["camera"].tap()
        XCTAssertTrue(springboard.alerts.buttons["Allow"].waitForExistence(timeout: 5), "asked after the reset")
        springboard.alerts.buttons["Allow"].tap()
        XCTAssertEqual(app.staticTexts["permission"].label, "camera: allowed")
        app.launch()
        app.buttons["camera"].tap()
        XCTAssertEqual(app.staticTexts["permission"].label, "camera: allowed", "the answer is kept")
        XCTAssertFalse(springboard.alerts.element.exists)
        app.resetAuthorizationStatus(for: .camera)
        app.launch()
        app.buttons["camera"].tap()
        XCTAssertTrue(springboard.alerts.buttons["Allow"].waitForExistence(timeout: 5), "asked again")
        springboard.alerts.buttons["Allow"].tap()
    }

    func testAppearance() {
        _ = openMultitouch()
        XCTAssertEqual(app.staticTexts["appearance"].label, "appearance: light")
        XCUIDevice.shared.appearance = .dark
        XCTAssertEqual(XCUIDevice.shared.appearance, .dark)
        XCTAssertTrue(app.staticTexts["appearance: dark"].waitForExistence(timeout: 5))
        XCUIDevice.shared.appearance = .light
        XCTAssertTrue(app.staticTexts["appearance: light"].waitForExistence(timeout: 5))
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
