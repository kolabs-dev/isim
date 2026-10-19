import Testing
import Foundation
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

    @Test func posixHeaders() {
        #expect(Core.matches("^[a-z]+-[0-9]+$", "abc-42") && !Core.matches("^[a-z]+$", "abc-42"))
        #expect(Core.platformOK)
    }

    /// Attachments (saved by `isim test` under <bundle>.attachments/SwiftTesting): a String, Data and an Encodable value
    /// (the Foundation cross-import overlay encodes it as JSON), and a file.
    @Test func attachments() async throws {
        Attachment.record("kilo = 1000", named: "units.txt")
        Attachment.record(Data([0x49, 0x53, 0x49, 0x4d]), named: "magic.bin")
        Attachment.record(UnitInfo(name: "kilo", factor: 1000), named: "unit.json")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("table.csv")
        try "name,factor\nkilo,1000\n".write(to: file, atomically: true, encoding: .utf8)
        let attachment = try await Attachment(contentsOf: file)            // Attachment(contentsOf:): a file's contents
        #expect(attachment.preferredName == "table.csv")
        Attachment.record(attachment)
    }

    @Test func asyncWork() async {
        let v = await Task.detached { 21 * 2 }.value
        #expect(v == 42)
    }
}

struct UnitInfo: Codable, Attachable {
    let name: String
    let factor: Int
}

/// Deliberately failing (skipped by the scheme; run with -only-testing:AppSwiftTests/FailingSuite).
@Suite struct FailingSuite {
    @Test func deliberateFailure() {
        #expect(Units.convert(1) == 1, "deliberate")
    }
}
