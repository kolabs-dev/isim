// WebAuthn extensions for isim's passkeys and virtual security keys (local simulation, see Core.swift):
//   - PRF (hmac-secret): each credential gets a random 32-byte secret when it is created; an evaluation is
//     HMAC-SHA-256(secret, SHA-256("WebAuthn PRF" || 0x00 || salt)), as WebAuthn defines it, so the same credential
//     and salt always give the same key.
//   - largeBlob (passkeys only, as on iOS): a blob of up to 2 KiB kept with the passkey in the device data.
// Also the security key types (ASAuthorizationSecurityKeyPublicKeyCredential...), ASAuthorizationResult and SwiftUI's
// AuthorizationController.
import Foundation
import UIKit
import SwiftUI
import CryptoKit

// MARK: - PRF

public struct ASAuthorizationPublicKeyCredentialPRFAssertionInput: Sendable {
    public struct InputValues: Sendable {
        public var saltInput1: Data
        public var saltInput2: Data?
        public init(saltInput1: Data, saltInput2: Data?) { self.saltInput1 = saltInput1; self.saltInput2 = saltInput2 }
        public static func saltInput1(_ saltInput1: Data, saltInput2: Data?) -> InputValues { InputValues(saltInput1: saltInput1, saltInput2: saltInput2) }
    }
    public let inputValues: InputValues?
    public let perCredentialInputValues: [Data: InputValues]?
    init(_ v: InputValues?, _ per: [Data: InputValues]?) { inputValues = v; perCredentialInputValues = per }
    public static func inputValues(_ inputValues: InputValues, perCredentialInputValues: [Data: InputValues]? = nil) -> Self {
        Self(inputValues, perCredentialInputValues)
    }
    public static func perCredentialInputValues(_ perCredentialInputValues: [Data: InputValues]) -> Self { Self(nil, perCredentialInputValues) }
}

public struct ASAuthorizationPublicKeyCredentialPRFRegistrationInput: Sendable {
    public typealias InputValues = ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues
    public let shouldCheckForSupport: Bool
    public let inputValues: InputValues?
    init(_ check: Bool, _ v: InputValues?) { shouldCheckForSupport = check; inputValues = v }
    public static var checkForSupport: Self { Self(true, nil) }
    public static func inputValues(_ inputValues: InputValues) -> Self { Self(false, inputValues) }
}

public struct ASAuthorizationPublicKeyCredentialPRFRegistrationOutput: Sendable {
    public let isSupported: Bool
    public let first: SymmetricKey?
    public let second: SymmetricKey?
    init(_ supported: Bool, _ first: SymmetricKey?, _ second: SymmetricKey?) { isSupported = supported; self.first = first; self.second = second }
    public init(first: SymmetricKey, second: SymmetricKey?) { self.init(true, first, second) }
    public static var supported: Self { Self(true, nil, nil) }
    public static var unsupported: Self { Self(false, nil, nil) }
}

public struct ASAuthorizationPublicKeyCredentialPRFAssertionOutput: Sendable {
    public let first: SymmetricKey
    public let second: SymmetricKey?
    public init(first: SymmetricKey, second: SymmetricKey?) { self.first = first; self.second = second }
}

// MARK: - largeBlob

public struct ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput: Sendable {
    public enum SupportRequirement: Sendable, Hashable { case required, preferred }
    public var supportRequirement: SupportRequirement
    init(_ r: SupportRequirement) { supportRequirement = r }
    public static var supportRequired: Self { Self(.required) }
    public static var supportPreferred: Self { Self(.preferred) }
}

public struct ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput: Sendable {
    public var isSupported: Bool
    init(_ s: Bool) { isSupported = s }
    public static var supported: Self { Self(true) }
    public static var unsupported: Self { Self(false) }
}

public struct ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput: Sendable {
    public enum Operation: Sendable, Hashable { case read, write(Data) }
    public var operation: Operation
    init(_ o: Operation) { operation = o }
    public static var read: Self { Self(.read) }
    public static func write(_ data: Data) -> Self { Self(.write(data)) }
}

public struct ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput: Sendable {
    public enum OperationResult: Sendable, Hashable { case read(data: Data?), write(success: Bool) }
    public var result: OperationResult
    init(_ r: OperationResult) { result = r }
    public static func read(data: Data?) -> Self { Self(.read(data: data)) }
    public static func write(success: Bool) -> Self { Self(.write(success: success)) }
}

enum _ASExtensions {
    static let largeBlobLimit = 2048
    static func prf(_ secret: Data, _ salt: Data) -> SymmetricKey {
        var input = Data("WebAuthn PRF".utf8); input.append(0); input.append(salt)
        let s = Data(SHA256.hash(data: input))
        return SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: s, using: SymmetricKey(data: secret))))
    }
    static func prf(_ secret: Data?, _ v: ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues) -> (SymmetricKey, SymmetricKey?)? {
        guard let secret else { return nil }
        return (prf(secret, v.saltInput1), v.saltInput2.map { prf(secret, $0) })
    }
    static func registration(_ input: ASAuthorizationPublicKeyCredentialPRFRegistrationInput?, _ secret: Data) -> ASAuthorizationPublicKeyCredentialPRFRegistrationOutput? {
        guard let input else { return nil }
        guard let v = input.inputValues, let (a, b) = prf(secret, v) else { return .supported }
        return ASAuthorizationPublicKeyCredentialPRFRegistrationOutput(first: a, second: b)
    }
    static func assertion(_ input: ASAuthorizationPublicKeyCredentialPRFAssertionInput?, _ k: _ASPasskey) -> ASAuthorizationPublicKeyCredentialPRFAssertionOutput? {
        guard let input, let v = input.perCredentialInputValues?[k.credentialID] ?? input.inputValues, let (a, b) = prf(k.prfSecret, v) else { return nil }
        return ASAuthorizationPublicKeyCredentialPRFAssertionOutput(first: a, second: b)
    }
}

// MARK: - Security keys (a virtual USB key whose credentials are in the device data)

public struct ASCOSEAlgorithmIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ rawValue: Int) { self.rawValue = rawValue }
    public static var ES256: ASCOSEAlgorithmIdentifier { ASCOSEAlgorithmIdentifier(rawValue: -7) }
}

public struct ASAuthorizationPublicKeyCredentialResidentKeyPreference: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let discouraged = Self(rawValue: "discouraged")
    public static let preferred = Self(rawValue: "preferred")
    public static let required = Self(rawValue: "required")
}

@objc(ASAuthorizationPublicKeyCredentialParameters) open class ASAuthorizationPublicKeyCredentialParameters: NSObject, @unchecked Sendable {
    public let algorithm: ASCOSEAlgorithmIdentifier
    public init(algorithm: ASCOSEAlgorithmIdentifier) { self.algorithm = algorithm }
    public required init?(coder: NSCoder) { algorithm = .ES256 }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor) open class ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor: NSObject, @unchecked Sendable {
    public struct Transport: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let usb = Transport(rawValue: "usb")
        public static let nfc = Transport(rawValue: "nfc")
        public static let bluetooth = Transport(rawValue: "ble")
        public static var allSupported: [Transport] { [.usb, .nfc, .bluetooth] }
    }
    open var credentialID: Data
    open var transports: [Transport]
    public init(credentialID: Data, transports: [Transport]) { self.credentialID = credentialID; self.transports = transports }
    public required init?(coder: NSCoder) { credentialID = Data(); transports = [] }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialProvider) open class ASAuthorizationSecurityKeyPublicKeyCredentialProvider: NSObject, ASAuthorizationProvider {
    public let relyingPartyIdentifier: String
    public init(relyingPartyIdentifier: String) { self.relyingPartyIdentifier = relyingPartyIdentifier }
    open func createCredentialRegistrationRequest(challenge: Data, displayName: String, name: String, userID: Data) -> ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest {
        ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge,
                                                                          displayName: displayName, name: name, userID: userID)
    }
    open func createCredentialAssertionRequest(challenge: Data) -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {
        ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge)
    }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest)
open class ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var displayName: String?
    open var name: String
    open var userID: Data
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    open var attestationPreference: ASAuthorizationPublicKeyCredentialAttestationKind = .none
    open var credentialParameters: [ASAuthorizationPublicKeyCredentialParameters] = [ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)]
    open var excludedCredentials: [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor] = []
    open var residentKeyPreference: ASAuthorizationPublicKeyCredentialResidentKeyPreference = .preferred
    open var prf: ASAuthorizationPublicKeyCredentialPRFRegistrationInput?
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data, displayName: String, name: String, userID: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge; self.displayName = displayName; self.name = name; self.userID = userID
        super.init(provider: provider)
    }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest)
open class ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var allowedCredentials: [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor] = []
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    /// the FIDO U2F AppID of credentials registered before WebAuthn (the appid extension)
    open var appID: String?
    open var prf: ASAuthorizationPublicKeyCredentialPRFAssertionInput?
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge
        super.init(provider: provider)
    }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialRegistration)
open class ASAuthorizationSecurityKeyPublicKeyCredentialRegistration: NSObject, ASAuthorizationCredential, @unchecked Sendable {
    public let rawAttestationObject: Data?
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .crossPlatform
    public let transports: [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport]
    public let prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?
    init(attestation: Data, clientData: Data, id: Data, prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?) {
        rawAttestationObject = attestation; rawClientDataJSON = clientData; credentialID = id; transports = [.usb]; self.prf = prf
    }
    public required init?(coder: NSCoder) { return nil }
}

@objc(ASAuthorizationSecurityKeyPublicKeyCredentialAssertion)
open class ASAuthorizationSecurityKeyPublicKeyCredentialAssertion: NSObject, ASAuthorizationCredential, @unchecked Sendable {
    public let rawAuthenticatorData: Data
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let signature: Data
    public let userID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .crossPlatform
    /// the credential was found under the request's appID, not its relying party
    public let appID: Bool
    public let prf: ASAuthorizationPublicKeyCredentialPRFAssertionOutput?
    init(authData: Data, clientData: Data, id: Data, signature: Data, userID: Data, appID: Bool, prf: ASAuthorizationPublicKeyCredentialPRFAssertionOutput?) {
        rawAuthenticatorData = authData; rawClientDataJSON = clientData; credentialID = id; self.signature = signature; self.userID = userID
        self.appID = appID; self.prf = prf
    }
    public required init?(coder: NSCoder) { return nil }
}

// MARK: - ASAuthorizationResult, AuthorizationController (SwiftUI)

public struct ASAuthorizationCustomMethod: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let videoSubscriberAccount = ASAuthorizationCustomMethod(rawValue: "ASAuthorizationCustomMethodVideoSubscriberAccount")
    public static let restorePurchase = ASAuthorizationCustomMethod(rawValue: "ASAuthorizationCustomMethodRestorePurchase")
    public static let other = ASAuthorizationCustomMethod(rawValue: "ASAuthorizationCustomMethodOther")
}

public enum ASAuthorizationResult {
    case appleID(ASAuthorizationAppleIDCredential)
    case password(ASPasswordCredential)
    case passkeyAssertion(ASAuthorizationPlatformPublicKeyCredentialAssertion)
    case passkeyRegistration(ASAuthorizationPlatformPublicKeyCredentialRegistration)
    case securityKeyAssertion(ASAuthorizationSecurityKeyPublicKeyCredentialAssertion)
    case securityKeyRegistration(ASAuthorizationSecurityKeyPublicKeyCredentialRegistration)
    case customMethod(ASAuthorizationCustomMethod)
    /// iOS 26: an account created with a passkey (ASAuthorizationAccountCreationProvider)
    case passkeyAccountCreation(ASAuthorizationAccountCreationPlatformPublicKeyCredential)

    init?(_ c: ASAuthorizationCredential) {
        switch c {
        case let c as ASAuthorizationAppleIDCredential: self = .appleID(c)
        case let c as ASPasswordCredential: self = .password(c)
        case let c as ASAuthorizationPlatformPublicKeyCredentialAssertion: self = .passkeyAssertion(c)
        case let c as ASAuthorizationPlatformPublicKeyCredentialRegistration: self = .passkeyRegistration(c)
        case let c as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion: self = .securityKeyAssertion(c)
        case let c as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration: self = .securityKeyRegistration(c)
        case let c as ASAuthorizationAccountCreationPlatformPublicKeyCredential: self = .passkeyAccountCreation(c)
        default: return nil
        }
    }
}

/// SwiftUI's async front end to ASAuthorizationController (EnvironmentValues.authorizationController); sheets are
/// presented from the key window.
public struct AuthorizationController: Sendable {
    @MainActor final class Runner: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        var continuation: CheckedContinuation<ASAuthorizationResult, Error>?
        var controller: ASAuthorizationController?
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first ?? UIWindow()
        }
        nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            MainActor.assumeIsolated {
                if let r = ASAuthorizationResult(authorization.credential) { finish(.success(r)) } else { finish(.failure(ASAuthorizationError(.invalidResponse))) }
            }
        }
        nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            MainActor.assumeIsolated { finish(.failure(error)) }
        }
        func finish(_ r: Result<ASAuthorizationResult, Error>) {
            let c = continuation
            continuation = nil
            controller = nil
            c?.resume(with: r)
        }
        func run(_ requests: [ASAuthorizationRequest], _ body: @escaping (ASAuthorizationController) -> Void) async throws -> ASAuthorizationResult {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<ASAuthorizationResult, Error>) in
                continuation = c
                let ac = ASAuthorizationController(authorizationRequests: requests)
                ac.delegate = self
                ac.presentationContextProvider = self
                controller = ac            // the runner and the controller keep each other until the result
                body(ac)
            }
        }
    }

    @MainActor func perform(_ requests: [ASAuthorizationRequest], _ body: @escaping (ASAuthorizationController) -> Void) async throws -> ASAuthorizationResult {
        try await Runner().run(requests, body)
    }

    @MainActor public func performRequest(_ request: ASAuthorizationRequest) async throws -> ASAuthorizationResult {
        try await performRequests([request])
    }
    @MainActor public func performRequests(_ requests: [ASAuthorizationRequest]) async throws -> ASAuthorizationResult {
        try await perform(requests) { $0.performRequests() }
    }
    @MainActor public func performRequest(_ request: ASAuthorizationRequest, options: ASAuthorizationController.RequestOptions) async throws -> ASAuthorizationResult {
        try await performRequests([request], options: options)
    }
    @MainActor public func performRequests(_ requests: [ASAuthorizationRequest], options: ASAuthorizationController.RequestOptions) async throws -> ASAuthorizationResult {
        try await perform(requests) { $0.performRequests(options: options) }
    }
    /// custom methods appear on tvOS only; on iOS, as on isim, they are not offered
    @MainActor public func performRequest(_ request: ASAuthorizationRequest, customMethods: [ASAuthorizationCustomMethod]) async throws -> ASAuthorizationResult {
        try await performRequests([request], customMethods: customMethods)
    }
    @MainActor public func performRequests(_ requests: [ASAuthorizationRequest], customMethods: [ASAuthorizationCustomMethod]) async throws -> ASAuthorizationResult {
        try await perform(requests) { $0.customAuthorizationMethods = customMethods; $0.performRequests() }
    }
    @MainActor public func performAutoFillAssistedRequest(_ request: ASAuthorizationRequest) async throws -> ASAuthorizationResult {
        try await performAutoFillAssistedRequests([request])
    }
    @MainActor public func performAutoFillAssistedRequests(_ requests: [ASAuthorizationRequest]) async throws -> ASAuthorizationResult {
        try await perform(requests) { $0.performAutoFillAssistedRequests() }
    }
}

struct _AuthorizationControllerKey: EnvironmentKey { static let defaultValue = AuthorizationController() }
extension EnvironmentValues {
    public var authorizationController: AuthorizationController { self[_AuthorizationControllerKey.self] }
}
