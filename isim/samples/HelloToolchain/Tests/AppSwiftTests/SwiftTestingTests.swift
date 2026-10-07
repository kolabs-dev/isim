import Testing
import Units
import Core

/// Swift Testing in a test bundle without a host app (runs in isim's xctest runner).
@Suite struct UnitsSuite {
    @Test func conversion() {
        #expect(Units.convert(3) == 30_000)
    }

    @Test("scaling by the C target", arguments: [1, 2, 5])
    func scaled(value: Int) {
        #expect(Core.scaled(value) == value * 10)
    }

    @Test func resourceBundle() throws {
        let table = try #require(Units.table())
        #expect(table.name == "kilo")
    }

    @Test func asyncWork() async {
        let v = await Task.detached { 21 * 2 }.value
        #expect(v == 42)
    }
}

/// Deliberately failing (skipped by the scheme; run with -only-testing:AppSwiftTests/FailingSuite).
@Suite struct FailingSuite {
    @Test func deliberateFailure() {
        #expect(Units.convert(1) == 1, "deliberate")
    }
}
