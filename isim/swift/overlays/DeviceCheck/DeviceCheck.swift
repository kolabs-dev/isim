// isim DeviceCheck: honest stand-ins. DeviceCheck tokens and App Attest need Apple's servers and the Secure
// Enclave, which isim does not have — like Apple's Simulator, `isSupported` is false and every call fails with
// DCError.featureUnsupported.
import Foundation

public let DCErrorDomain = "com.apple.devicecheck.error"

public struct DCError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case unknownSystemFailure = 0
        case featureUnsupported = 1
        case invalidInput = 2
        case invalidKey = 3
        case serverUnavailable = 4
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { DCErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorDescription: String? { code == .featureUnsupported ? "DeviceCheck and App Attest are not supported on isim." : "DeviceCheck error \(code.rawValue)." }
    public static var unknownSystemFailure: Code { .unknownSystemFailure }
    public static var featureUnsupported: Code { .featureUnsupported }
    public static var invalidInput: Code { .invalidInput }
    public static var invalidKey: Code { .invalidKey }
    public static var serverUnavailable: Code { .serverUnavailable }
}
public func ~= (code: DCError.Code, error: Error) -> Bool { (error as? DCError)?.code == code }

open class DCDevice: NSObject, @unchecked Sendable {
    public static let current = DCDevice()
    open var isSupported: Bool { false }
    open func generateToken(completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async { completionHandler(nil, DCError(.featureUnsupported)) }
    }
    open func generateToken() async throws -> Data { throw DCError(.featureUnsupported) }
}

open class DCAppAttestService: NSObject, @unchecked Sendable {
    public static let shared = DCAppAttestService()
    open var isSupported: Bool { false }
    open func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void) {
        DispatchQueue.global().async { completionHandler(nil, DCError(.featureUnsupported)) }
    }
    open func generateKey() async throws -> String { throw DCError(.featureUnsupported) }
    open func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async { completionHandler(nil, DCError(.featureUnsupported)) }
    }
    open func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data { throw DCError(.featureUnsupported) }
    open func generateAssertion(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async { completionHandler(nil, DCError(.featureUnsupported)) }
    }
    open func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data { throw DCError(.featureUnsupported) }
}
