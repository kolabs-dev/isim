import XCTest
import Testing
@testable import Units

// The package's tests, run by `isim test` in the package folder with isim's iOS XCTest and Swift Testing.
final class UnitsTests: XCTestCase {
    func testTableFromBundleModule() throws {
        let table = try XCTUnwrap(Units.table())
        XCTAssertEqual(table.name, "kilo")
        XCTAssertEqual(table.factor, 1000)
    }

    func testConvertThroughCore() {
        XCTAssertEqual(Units.convert(2), 20000)
    }

    func testInternalSymbol() {
        XCTAssertEqual(Units.tableResource, "units")         // @testable import
    }

    /// Apple's XCTestCase is an NSObject with init() (swift-corelibs-xctest only has init(name:testClosure:))
    func testMakesAnotherTestCase() {
        let helper = ConversionCheck()
        XCTAssertEqual(helper.converted(3), 30000)
    }

    /// fails only when asked (UNITS_FAIL=1): `isim test` then reports the failure and exits 65
    func testFailsOnRequest() {
        if ProcessInfo.processInfo.environment["UNITS_FAIL"] != nil {
            XCTFail("UNITS_FAIL is set")
        }
    }
}

final class ConversionCheck: XCTestCase {
    func converted(_ v: Int) -> Int { Units.convert(v) }
}

@Test func swiftTestingConvert() {
    #expect(Units.convert(1) == 10000)
}
