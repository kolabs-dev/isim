// isim AdServices (iOS 14.3): Apple Ads attribution. Adapted: the attribution token comes from Apple's attribution
// server for an app installed from the App Store, which isim does not have; attributionToken() throws
// AAAttributionError.platformNotSupported ("the server is unable to provide a token because of an unsupported
// operating system") and logs why, so apps take their no-attribution path.
import Foundation

public let AAAttributionErrorDomain = "AAAttributionErrorDomain"
public struct AAAttributionError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable, Hashable { case networkError = 1, internalError = 2, platformNotSupported = 3 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { AAAttributionErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: "The server is unable to provide a token because of an unsupported operating system."]
    }
    public static let networkError = Code.networkError, internalError = Code.internalError, platformNotSupported = Code.platformNotSupported
}

open class AAAttribution: NSObject {
    open class func attributionToken() throws -> String {
        print("isim: AdServices: no Apple Ads attribution on isim (no App Store install): attributionToken() fails with platformNotSupported")
        throw AAAttributionError(.platformNotSupported)
    }
}
