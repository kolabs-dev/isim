import Foundation
import Core

public struct UnitTable: Decodable {
    public let name: String
    public let factor: Int
}

public enum Units {
    /// Read from units.json in the package's resource bundle (Bundle.module).
    public static func table() -> UnitTable? {
        guard let url = Bundle.module.url(forResource: "units", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UnitTable.self, from: data)
    }

    /// Converts with the table's factor, scaled by the Core package (which calls its C target).
    public static func convert(_ value: Int) -> Int {
        Core.scaled(value) * (table()?.factor ?? 0)
    }
}
