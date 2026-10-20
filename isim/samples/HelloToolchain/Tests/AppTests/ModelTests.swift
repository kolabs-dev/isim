import XCTest
@testable import HelloToolchain
import Units
import notify

/// Hosted unit tests (TEST_HOST = the app): @testable access to the app module and everything it links.
final class ModelTests: XCTestCase {
    static var events: [String] = []
    var fixture: Int = 0

    override class func setUp() { events.append("class setUp") }
    override func setUp() { fixture = 10; ModelTests.events.append("setUp") }
    override func tearDown() { ModelTests.events.append("tearDown") }

    func testIncrement() {
        var m = Model()
        m.increment(); m.increment()
        XCTAssertEqual(m.count, 2)
        XCTAssertEqual(fixture, 10)
    }

    func testLinkedLibraries() {
        XCTAssertEqual(Model.mathKitSum(), 5, "static library")
        XCTAssertEqual(Model.xcframeworkSum(), 7, "XCFramework")
        XCTAssertEqual(Model.units(), 20_000, "package -> package -> C target")
        XCTAssertEqual(Model.greeting("tests"), "«Hello, tests»", "framework with a resource")
        XCTAssertEqual(Model.legacy(), "objc score 42", "ObjC <-> Swift in the app target")
    }

    func testBuildSettings() {
        XCTAssertEqual(Model.buildFlavor, "debug+xcconfig")
        XCTAssertEqual(Model.greetingWord, "Howdy")
        XCTAssertTrue(Bundle.main.bundlePath.hasSuffix("HelloToolchain.app"), "hosted in the app")
        XCTAssertTrue(Bundle(for: ModelTests.self).bundlePath.hasSuffix("AppTests.xctest"))
    }

    func testPackageResources() throws {
        let table = try XCTUnwrap(Units.table())
        XCTAssertEqual(table.name, "kilo")
        XCTAssertGreaterThan(table.factor, 999)
    }

    func testThrowingPasses() throws {
        let data = try JSONSerialization.data(withJSONObject: ["a": 1])
        XCTAssertFalse(data.isEmpty)
        XCTAssertNil(Optional<Int>.none)
        XCTAssertNotNil(Optional(1))
        XCTAssertEqual(0.1 + 0.2, 0.3, accuracy: 0.0001)
        XCTAssertThrowsError(try JSONSerialization.jsonObject(with: Data("{".utf8)))
    }

    func testExpectation() {
        let e = expectation(description: "timer fires")
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in e.fulfill() }
        let main = expectation(description: "main queue")
        DispatchQueue.global().async { DispatchQueue.main.async { main.fulfill() } }
        waitForExpectations(timeout: 2)
    }

    func testInvertedExpectation() {
        let e = expectation(description: "never")
        e.isInverted = true
        wait(for: [e], timeout: 0.1)
    }

    func testAsync() async throws {
        let v = await Task.detached { 6 * 7 }.value
        XCTAssertEqual(v, 42)
    }

    @MainActor
    func testAsyncFulfillment() async {
        let e = XCTestExpectation(description: "async work")
        Task { try? await Task.sleep(nanoseconds: 20_000_000); e.fulfill() }
        await fulfillment(of: [e], timeout: 2)
    }

    func testSkipped() throws {
        throw XCTSkip("not on isim today")
    }

    func testMeasure() {
        measure { _ = (0..<1000).reduce(0, +) }
    }

    /// prints what a test plan configured (Unit.xctestplan: its environment, arguments and language)
    func testPlanOptions() {
        let env = ProcessInfo.processInfo.environment
        print("plan options: \(env["PLAN_NAME"] ?? "none") / \(env["PLAN_CONFIGURATION"] ?? "none") argument \(CommandLine.arguments.contains("-planArgument")) language \(Locale.preferredLanguages.first ?? "?")")
    }

    func testZLifecycleOrder() {
        // runs last (alphabetical order): every earlier test had setUp and tearDown around it
        XCTAssertEqual(ModelTests.events.first, "class setUp")
        XCTAssertEqual(ModelTests.events.filter { $0 == "setUp" }.count, ModelTests.events.filter { $0 == "tearDown" }.count + 1)
    }
}

/// Issues: record(_:), expected failures (XCTExpectFailure), activities (XCTContext), and the key-path and Darwin
/// notification expectations.
final class IssueTests: XCTestCase {
    var recorded: [XCTIssue] = []

    override func record(_ issue: XCTIssue) {
        recorded.append(issue)
        super.record(issue)
    }

    func testActivities() {
        let sum = XCTContext.runActivity(named: "Add numbers") { _ -> Int in
            XCTContext.runActivity(named: "Attach the operands") { activity in
                let a = XCTAttachment(string: "20 + 22")
                a.name = "operands"
                a.lifetime = .keepAlways
                activity.add(a)
            }
            return 20 + 22
        }
        XCTAssertEqual(sum, 42)
    }

    final class Observer: NSObject, XCTestObservation {
        var reasons: [String] = []
        func testCase(_ testCase: XCTestCase, didRecord expectedFailure: XCTExpectedFailure) {
            reasons.append(expectedFailure.failureReason ?? "")
        }
    }

    func testExpectedFailures() {
        let observer = Observer()
        XCTestObservationCenter.shared.addTestObserver(observer)
        defer { XCTestObservationCenter.shared.removeTestObserver(observer) }
        XCTExpectFailure("addition is off by one") {
            XCTAssertEqual(1 + 1, 3)
        }
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.type == .assertionFailure && $0.compactDescription.contains("bug 42") }
        XCTExpectFailure("known bug 42", options: options)      // until the end of the test
        XCTFail("bug 42")
        XCTExpectFailure("not strict", strict: false) {}
        XCTExpectFailure("disabled", enabled: false)
        XCTAssertEqual(recorded.count, 2, "record(_:) sees every issue")
        XCTAssertEqual(observer.reasons, ["addition is off by one", "known bug 42"])
    }

    func testRecordIssue() {
        let line = #line
        var issue = XCTIssue(type: .system, compactDescription: "custom issue",
                             sourceCodeContext: XCTSourceCodeContext(location: XCTSourceCodeLocation(filePath: #filePath, lineNumber: line)))
        issue.add(XCTAttachment(string: "detail"))
        XCTExpectFailure("a recorded issue", failingBlock: { record(issue) }, issueMatcher: { $0.compactDescription == "custom issue" })
        XCTAssertEqual(recorded.last?.type, .system)
        XCTAssertEqual(recorded.last?.attachments.count, 1)
        XCTAssertEqual(recorded.last?.sourceCodeContext.location?.lineNumber, line)
        XCTAssertFalse(recorded.last?.sourceCodeContext.callStack.isEmpty ?? true, "the call stack")
    }

    final class Job: NSObject {
        @objc dynamic var state = "idle"
    }

    func testKeyPathExpectation() {
        let job = Job()
        let done = XCTKeyPathExpectation(keyPath: "state", observedObject: job, expectedValue: "done")
        let running = keyValueObservingExpectation(for: job, keyPath: "state") { _, change in
            change[NSKeyValueChangeKey.newKey.rawValue] as? String == "running"
        }
        DispatchQueue.main.async {
            job.state = "running"
            DispatchQueue.main.async { job.state = "done" }
        }
        wait(for: [running, done], timeout: 2)
    }

    func testDarwinNotification() {
        let name = "dev.isim.samples.toolchain.ready"
        let posted = XCTDarwinNotificationExpectation(notificationName: name)
        DispatchQueue.global().async { notify_post(name) }
        wait(for: [posted], timeout: 2)
    }
}

/// Deliberately failing tests: skipped by the scheme, run explicitly with -only-testing to prove failures are reported.
final class ExpectedFailureTests: XCTestCase {
    func testEqualFails() {
        XCTAssertEqual(Model.mathKitSum(), 6, "deliberate")
    }

    func testThrownError() throws {
        struct Boom: Error {}
        throw Boom()
    }

    func testStopsAfterFirstFailure() {
        continueAfterFailure = false
        XCTFail("first failure")
        XCTFail("never reached")
    }

    func testUnmatchedExpectedFailure() {
        XCTExpectFailure("a bug that is fixed")
    }

    func testUnfulfilledExpectation() {
        let e = expectation(description: "never fulfilled")
        wait(for: [e], timeout: 0.2)
    }
}
