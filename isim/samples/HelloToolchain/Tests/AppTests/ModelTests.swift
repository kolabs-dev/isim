import XCTest
@testable import HelloToolchain
import Units

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

    func testZLifecycleOrder() {
        // runs last (alphabetical order): every earlier test had setUp and tearDown around it
        XCTAssertEqual(ModelTests.events.first, "class setUp")
        XCTAssertEqual(ModelTests.events.filter { $0 == "setUp" }.count, ModelTests.events.filter { $0 == "tearDown" }.count + 1)
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

    func testUnfulfilledExpectation() {
        let e = expectation(description: "never fulfilled")
        wait(for: [e], timeout: 0.2)
    }
}
