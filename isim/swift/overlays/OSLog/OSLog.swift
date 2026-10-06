// isim OSLog: re-exports isim's os module (Logger, OSLog, signposts). Reading the log store back (OSLogStore)
// is not available on isim: OSLogStore(scope:) throws.
@_exported import os
import Foundation

public final class OSLogStore: NSObject, @unchecked Sendable {
    public enum Scope: Int, Sendable { case system = 0, currentProcessIdentifier = 1 }
    public static func local() throws -> OSLogStore { throw NSError(domain: "OSLogErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "OSLogStore is not available on isim"]) }
    public convenience init(scope: Scope) throws { throw NSError(domain: "OSLogErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "OSLogStore is not available on isim"]) }
}
