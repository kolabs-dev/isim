// isim AuthenticationServices: Sign in with Apple, passkeys and saved-password sign-in, as a LOCAL SIMULATION.
// Nothing talks to Apple's servers:
//   - Sign in with Apple uses a fake Apple Account kept in the device data ($ISIM_DATA/Library/isim/AppleAccount/
//     account.json; default "Taylor Appleseed" <taylor@example.com>). The iOS-style sheet asks for name/email
//     sharing (Share My Email / Hide My Email); the credential's identityToken is an UNSIGNED JWT (header
//     {"alg":"none"}, issuer "isim-local-simulation") and authorizationCode is a random local string — a server
//     that verifies Apple's signatures rejects both, by design. Credential states (authorized / revoked / notFound)
//     are kept per app in AppleAccount/SignInWithApple.json; `isim appleid <app> revoke` is Settings > Apple Account
//     > Sign in with Apple > Stop Using (running apps get credentialRevokedNotification).
//   - Passkeys (ASAuthorizationPlatformPublicKeyCredentialProvider) are real WebAuthn data: an ECDSA P-256 key pair
//     (CryptoKit), attestation format "none" (AAGUID zero), CBOR attestation object with a COSE key, and assertion
//     signatures over authenticatorData || SHA-256(clientDataJSON) that verify with the registered public key. The
//     keys live in the device data (AppleAccount/Passkeys/<relying party>.json, unencrypted; not synced to iCloud
//     Keychain), so a server that accepts "none" attestation can verify the whole flow.
//   - Password requests offer the app's internet passwords from isim's keychain (kSecClassInternetPassword).
// ASWebAuthenticationSession is not part of this module.
import Foundation
import UIKit

public typealias ASPresentationAnchor = UIWindow

// MARK: - Errors

public let ASAuthorizationErrorDomain = "com.apple.AuthenticationServices.AuthorizationError"
public struct ASAuthorizationError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 1000, canceled = 1001, invalidResponse = 1002, notHandled = 1003, failed = 1004, notInteractive = 1005
        case matchedExcludedCredential = 1006
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { ASAuthorizationErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (\(ASAuthorizationErrorDomain) error \(code.rawValue).)"] }
    public static var unknown: Code { .unknown }
    public static var canceled: Code { .canceled }
    public static var invalidResponse: Code { .invalidResponse }
    public static var notHandled: Code { .notHandled }
    public static var failed: Code { .failed }
    public static var notInteractive: Code { .notInteractive }
}
public func ~= (code: ASAuthorizationError.Code, error: Error) -> Bool {
    (error as? ASAuthorizationError)?.code == code
}

// MARK: - Base types

@objc public protocol ASAuthorizationProvider: NSObjectProtocol {}
@objc public protocol ASAuthorizationCredential: NSObjectProtocol {}

open class ASAuthorizationRequest: NSObject {
    public let provider: ASAuthorizationProvider
    init(provider: ASAuthorizationProvider) { self.provider = provider }
}

open class ASAuthorization: NSObject {
    public let provider: ASAuthorizationProvider
    public let credential: ASAuthorizationCredential
    init(provider: ASAuthorizationProvider, credential: ASAuthorizationCredential) { self.provider = provider; self.credential = credential }

    public struct Scope: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let fullName = Scope(rawValue: "full_name")
        public static let email = Scope(rawValue: "email")
    }
    public struct OpenIDOperation: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let operationImplicit = OpenIDOperation(rawValue: "")
        public static let operationLogin = OpenIDOperation(rawValue: "login")
        public static let operationRefresh = OpenIDOperation(rawValue: "refresh")
        public static let operationLogout = OpenIDOperation(rawValue: "logout")
    }
}

public enum ASUserDetectionStatus: Int, Sendable { case unsupported = 0, unknown = 1, likelyReal = 2 }

@objc public protocol ASAuthorizationControllerDelegate: NSObjectProtocol {
    @objc(authorizationController:didCompleteWithAuthorization:) optional func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization)
    @objc(authorizationController:didCompleteWithError:) optional func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error)
}

@objc public protocol ASAuthorizationControllerPresentationContextProviding: NSObjectProtocol {
    @MainActor func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
}

// MARK: - Controller

open class ASAuthorizationController: NSObject {
    public let authorizationRequests: [ASAuthorizationRequest]
    weak open var delegate: ASAuthorizationControllerDelegate?
    weak open var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?
    open var customAuthorizationMethods: [Any] = []
    /// keeps the controller alive while its sheet is up (apps often don't hold on to it)
    nonisolated(unsafe) static var active: Set<ASAuthorizationController> = []
    weak var sheet: UIViewController?
    var finished = false

    public init(authorizationRequests: [ASAuthorizationRequest]) { self.authorizationRequests = authorizationRequests }

    public struct RequestOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let preferImmediatelyAvailableCredentials = RequestOptions(rawValue: 1)
    }

    open func performRequests() { performRequests(options: []) }
    open func performRequests(options: RequestOptions) {
        ASAuthorizationController.active.insert(self)
        DispatchQueue.main.async { MainActor.assumeIsolated { self._perform(options) } }
    }
    /// AutoFill-assisted passkey requests: isim has no QuickType bar, so this behaves like performRequests
    /// with preferImmediatelyAvailableCredentials (the sheet appears only when there are saved credentials).
    open func performAutoFillAssistedRequests() { performRequests(options: .preferImmediatelyAvailableCredentials) }
    open func cancel() {
        DispatchQueue.main.async { MainActor.assumeIsolated {
            if let s = self.sheet { s.dismiss(animated: true, completion: nil) }
            self.fail(.canceled)
        } }
    }

    @MainActor func anchorController() -> UIViewController? {
        var vc: UIViewController?
        if let p = presentationContextProvider { vc = p.presentationAnchor(for: self).rootViewController }
        if vc == nil { vc = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController }
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    @MainActor func complete(_ provider: ASAuthorizationProvider, _ credential: ASAuthorizationCredential) {
        guard !finished else { return }
        finished = true
        ASAuthorizationController.active.remove(self)
        delegate?.authorizationController?(controller: self, didCompleteWithAuthorization: ASAuthorization(provider: provider, credential: credential))
    }
    @MainActor func fail(_ code: ASAuthorizationError.Code) {
        guard !finished else { return }
        finished = true
        ASAuthorizationController.active.remove(self)
        delegate?.authorizationController?(controller: self, didCompleteWithError: ASAuthorizationError(code))
    }

    @MainActor func _perform(_ options: RequestOptions) {
        let appleID = authorizationRequests.compactMap { $0 as? ASAuthorizationAppleIDRequest }
        let registrations = authorizationRequests.compactMap { $0 as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest }
        let assertions = authorizationRequests.compactMap { $0 as? ASAuthorizationPlatformPublicKeyCredentialAssertionRequest }
        let passwords = authorizationRequests.compactMap { $0 as? ASAuthorizationPasswordRequest }
        guard !authorizationRequests.isEmpty else { fail(.unknown); return }

        if let reg = registrations.first {
            if options.contains(.preferImmediatelyAvailableCredentials) { fail(.notInteractive); return }
            _ASSheets.presentPasskeyRegistration(self, reg); return
        }
        // saved credentials the user can pick: passkeys for the relying party, the app's saved passwords
        var choices: [_ASChoice] = []
        for a in assertions {
            for k in _ASPasskeys.load(a.relyingPartyIdentifier) where a.allowedCredentials.isEmpty || a.allowedCredentials.contains(where: { $0.credentialID == k.credentialID }) {
                choices.append(.passkey(a, k))
            }
        }
        if !passwords.isEmpty { choices += _ASPasswords.saved().map { _ASChoice.password(passwords[0], $0) } }
        if !choices.isEmpty { _ASSheets.presentChooser(self, choices, appleID: appleID.first); return }
        if options.contains(.preferImmediatelyAvailableCredentials) {
            NSLog("isim AuthenticationServices: no saved credentials for these requests (notInteractive)")
            fail(.notInteractive); return
        }
        if let a = appleID.first { _ASSheets.presentAppleID(self, a); return }
        if !assertions.isEmpty {
            NSLog("isim AuthenticationServices: no passkey saved for %@ (iOS would offer a passkey from a nearby device; isim cancels)", assertions[0].relyingPartyIdentifier)
            fail(.canceled); return
        }
        NSLog("isim AuthenticationServices: no saved passwords for this app (isim keychain internet passwords)")
        fail(.canceled)
    }
}

// MARK: - Device data

enum _ASData {
    static var dataDir: String {
        let env = ProcessInfo.processInfo.environment
        return env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    static func dir(_ sub: String) -> String {
        let p = (dataDir as NSString).appendingPathComponent("Library/isim/AppleAccount/" + sub)
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
        return p
    }
    static func readJSON(_ path: String) -> Any? {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONSerialization.jsonObject(with: d, options: [])
    }
    static func writeJSON(_ obj: Any, _ path: String) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return }
        let tmp = path + ".tmp\(getpid())"
        if FileManager.default.createFile(atPath: tmp, contents: d, attributes: nil) { chmod(tmp, 0o600); rename(tmp, path) }
    }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "unknown" }
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
    }
    /// iOS 18 renamed "Apple ID" to "Apple Account"
    static var accountWord: String {
        let v = ProcessInfo.processInfo.environment["ISIM_OS_VERSION"] ?? "18.0"
        return (Int(v.split(separator: ".").first ?? "18") ?? 18) >= 18 ? "Apple Account" : "Apple ID"
    }
    static func random(_ n: Int) -> [UInt8] { (0..<n).map { _ in UInt8.random(in: 0...255) } }
    static func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }
    static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
