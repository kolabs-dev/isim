// Credential provider extensions (adapted): a password manager's extension (NSExtensionPointIdentifier
// com.apple.authentication-services-credential-provider-ui) offers its passwords, passkeys and one-time codes to other
// apps. The provider app saves credential identities in ASCredentialIdentityStore, kept per extension in the device data
// (Library/isim/CredentialProviders/<extension>.json). Settings > Passwords > Password Options turns a provider on
// ("AutoFillProviders" in the global preferences; `isim autofill enable` too); until then the store reports it
// disabled. Then UIKit's QuickType bar (UITextServices.m) lists its identities for the app's site and a pick runs the
// extension through isim_as_provide_credential, and ASAuthorizationController's chooser lists its passkeys. Like
// isim's share and keyboard extensions, the extension runs in the app's process: its principal class (an
// ASCredentialProviderViewController) is made, asked to provideCredentialWithoutUserInteraction(for:), and presented
// as a sheet after prepareInterfaceToProvideCredential(for:) when it needs the user (ASExtensionError
// .userInteractionRequired).
import Foundation
import UIKit
import CryptoKit

// MARK: - identifiers and identities

@objc(ASCredentialServiceIdentifier) open class ASCredentialServiceIdentifier: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc(ASCredentialServiceIdentifierType) public enum IdentifierType: Int, @unchecked Sendable {
        case domain = 0
        case URL = 1
        /// iOS 26: an app's bundle identifier
        case app = 2
    }
    @objc open var identifier: String
    @objc open var type: IdentifierType
    /// iOS 26
    @objc open var displayName: String?
    @objc(initWithIdentifier:type:) public init(identifier: String, type: IdentifierType) { self.identifier = identifier; self.type = type }
    @objc(initWithIdentifier:type:displayName:) public init(identifier: String, type: IdentifierType, displayName: String) { self.identifier = identifier; self.type = type; self.displayName = displayName }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(identifier, forKey: "identifier"); coder.encode(type.rawValue, forKey: "type"); coder.encode(displayName, forKey: "displayName")
    }
    public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: NSString.self, forKey: "identifier") as String? else { return nil }
        identifier = i; type = IdentifierType(rawValue: coder.decodeInteger(forKey: "type")) ?? .domain
        displayName = coder.decodeObject(of: NSString.self, forKey: "displayName") as String?
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = ASCredentialServiceIdentifier(identifier: identifier, type: type); c.displayName = displayName; return c
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? ASCredentialServiceIdentifier else { return false }
        return o.identifier == identifier && o.type == type
    }
    open override var hash: Int { identifier.hashValue ^ type.rawValue }
    /// the host name the identifier names (a domain, or a URL's host)
    var host: String {
        switch type {
        case .URL: return (Foundation.URL(string: identifier)?.host ?? identifier).lowercased()
        default: return identifier.lowercased()
        }
    }
}

@objc(ASCredentialIdentity) public protocol ASCredentialIdentity: NSObjectProtocol {
    var serviceIdentifier: ASCredentialServiceIdentifier { get }
    var user: String { get }
    var recordIdentifier: String? { get }
    var rank: Int { get set }
}

@objc(ASPasswordCredentialIdentity) open class ASPasswordCredentialIdentity: NSObject, ASCredentialIdentity, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let serviceIdentifier: ASCredentialServiceIdentifier
    public let user: String
    public let recordIdentifier: String?
    open var rank = 0
    @objc(initWithServiceIdentifier:user:recordIdentifier:) public init(serviceIdentifier: ASCredentialServiceIdentifier, user: String, recordIdentifier: String?) {
        self.serviceIdentifier = serviceIdentifier; self.user = user; self.recordIdentifier = recordIdentifier
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(serviceIdentifier, forKey: "service"); coder.encode(user, forKey: "user"); coder.encode(recordIdentifier, forKey: "record"); coder.encode(rank, forKey: "rank")
    }
    public required init?(coder: NSCoder) {
        guard let s = coder.decodeObject(of: ASCredentialServiceIdentifier.self, forKey: "service"), let u = coder.decodeObject(of: NSString.self, forKey: "user") as String? else { return nil }
        serviceIdentifier = s; user = u; recordIdentifier = coder.decodeObject(of: NSString.self, forKey: "record") as String?; rank = coder.decodeInteger(forKey: "rank")
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = ASPasswordCredentialIdentity(serviceIdentifier: serviceIdentifier, user: user, recordIdentifier: recordIdentifier); c.rank = rank; return c
    }
}

@objc(ASPasskeyCredentialIdentity) open class ASPasskeyCredentialIdentity: NSObject, ASCredentialIdentity, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let relyingPartyIdentifier: String
    @objc public let userName: String
    @objc public let credentialID: Data
    @objc public let userHandle: Data
    public let recordIdentifier: String?
    open var rank = 0
    public var serviceIdentifier: ASCredentialServiceIdentifier { ASCredentialServiceIdentifier(identifier: relyingPartyIdentifier, type: .domain) }
    public var user: String { userName }
    @objc(initWithRelyingPartyIdentifier:userName:credentialID:userHandle:recordIdentifier:)
    public init(relyingPartyIdentifier: String, userName: String, credentialID: Data, userHandle: Data, recordIdentifier: String?) {
        self.relyingPartyIdentifier = relyingPartyIdentifier; self.userName = userName; self.credentialID = credentialID
        self.userHandle = userHandle; self.recordIdentifier = recordIdentifier
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(relyingPartyIdentifier, forKey: "rp"); coder.encode(userName, forKey: "user"); coder.encode(credentialID, forKey: "id")
        coder.encode(userHandle, forKey: "handle"); coder.encode(recordIdentifier, forKey: "record"); coder.encode(rank, forKey: "rank")
    }
    public required init?(coder: NSCoder) {
        guard let rp = coder.decodeObject(of: NSString.self, forKey: "rp") as String?, let u = coder.decodeObject(of: NSString.self, forKey: "user") as String?,
              let id = coder.decodeObject(of: NSData.self, forKey: "id") as Data?, let h = coder.decodeObject(of: NSData.self, forKey: "handle") as Data? else { return nil }
        relyingPartyIdentifier = rp; userName = u; credentialID = id; userHandle = h
        recordIdentifier = coder.decodeObject(of: NSString.self, forKey: "record") as String?; rank = coder.decodeInteger(forKey: "rank")
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = ASPasskeyCredentialIdentity(relyingPartyIdentifier: relyingPartyIdentifier, userName: userName, credentialID: credentialID,
                                            userHandle: userHandle, recordIdentifier: recordIdentifier)
        c.rank = rank; return c
    }
}

/// iOS 18: a one-time verification code a provider can fill.
@objc(ASOneTimeCodeCredentialIdentity) open class ASOneTimeCodeCredentialIdentity: NSObject, ASCredentialIdentity, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let serviceIdentifier: ASCredentialServiceIdentifier
    @objc public let label: String
    public let recordIdentifier: String?
    open var rank = 0
    public var user: String { label }
    @objc(initWithServiceIdentifier:label:recordIdentifier:) public init(serviceIdentifier: ASCredentialServiceIdentifier, label: String, recordIdentifier: String?) {
        self.serviceIdentifier = serviceIdentifier; self.label = label; self.recordIdentifier = recordIdentifier
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(serviceIdentifier, forKey: "service"); coder.encode(label, forKey: "label"); coder.encode(recordIdentifier, forKey: "record"); coder.encode(rank, forKey: "rank")
    }
    public required init?(coder: NSCoder) {
        guard let s = coder.decodeObject(of: ASCredentialServiceIdentifier.self, forKey: "service"), let l = coder.decodeObject(of: NSString.self, forKey: "label") as String? else { return nil }
        serviceIdentifier = s; label = l; recordIdentifier = coder.decodeObject(of: NSString.self, forKey: "record") as String?; rank = coder.decodeInteger(forKey: "rank")
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = ASOneTimeCodeCredentialIdentity(serviceIdentifier: serviceIdentifier, label: label, recordIdentifier: recordIdentifier); c.rank = rank; return c
    }
}

// MARK: - requests and credentials

@objc(ASCredentialRequestType) public enum ASCredentialRequestType: UInt, @unchecked Sendable {
    case password = 0, passkeyAssertion = 1, passkeyRegistration = 2
    /// iOS 18
    case oneTimeCode = 3
}

@objc(ASCredentialRequest) public protocol ASCredentialRequest: NSObjectProtocol, NSCopying, NSSecureCoding {
    var type: ASCredentialRequestType { get }
    var credentialIdentity: ASCredentialIdentity { get }
}

@objc(ASPasswordCredentialRequest) open class ASPasswordCredentialRequest: NSObject, ASCredentialRequest, @unchecked Sendable {
    public let credentialIdentity: ASCredentialIdentity
    public var type: ASCredentialRequestType { .password }
    @objc(initWithCredentialIdentity:) public init(credentialIdentity: ASPasswordCredentialIdentity) { self.credentialIdentity = credentialIdentity }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(credentialIdentity, forKey: "identity") }
    public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: ASPasswordCredentialIdentity.self, forKey: "identity") else { return nil }
        credentialIdentity = i
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

/// iOS 18
@objc(ASOneTimeCodeCredentialRequest) open class ASOneTimeCodeCredentialRequest: NSObject, ASCredentialRequest, @unchecked Sendable {
    public let credentialIdentity: ASCredentialIdentity
    public var type: ASCredentialRequestType { .oneTimeCode }
    @objc(initWithCredentialIdentity:) public init(credentialIdentity: ASOneTimeCodeCredentialIdentity) { self.credentialIdentity = credentialIdentity }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(credentialIdentity, forKey: "identity") }
    public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: ASOneTimeCodeCredentialIdentity.self, forKey: "identity") else { return nil }
        credentialIdentity = i
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

@objc(ASPasskeyCredentialRequest) open class ASPasskeyCredentialRequest: NSObject, ASCredentialRequest, @unchecked Sendable {
    public let credentialIdentity: ASCredentialIdentity
    @objc public let clientDataHash: Data
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    public let supportedAlgorithms: [ASCOSEAlgorithmIdentifier]
    @objc(userVerificationPreference) var _objc_userVerificationPreference: String { userVerificationPreference.rawValue }
    @objc(supportedAlgorithms) var _objc_supportedAlgorithms: [NSNumber] { supportedAlgorithms.map { NSNumber(value: $0.rawValue) } }
    /// iOS 18: the credentials the relying party already has (registration)
    public let excludedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor]?
    let requestType: ASCredentialRequestType
    public var type: ASCredentialRequestType { requestType }
    public init(credentialIdentity: ASPasskeyCredentialIdentity, clientDataHash: Data, userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference,
                supportedAlgorithms: [ASCOSEAlgorithmIdentifier]) {
        self.credentialIdentity = credentialIdentity; self.clientDataHash = clientDataHash; self.userVerificationPreference = userVerificationPreference
        self.supportedAlgorithms = supportedAlgorithms; excludedCredentials = nil; requestType = .passkeyAssertion
    }
    init(_ identity: ASPasskeyCredentialIdentity, hash: Data, uv: ASAuthorizationPublicKeyCredentialUserVerificationPreference, registration: Bool,
         excluded: [ASAuthorizationPlatformPublicKeyCredentialDescriptor]?) {
        credentialIdentity = identity; clientDataHash = hash; userVerificationPreference = uv; supportedAlgorithms = [.ES256]
        excludedCredentials = excluded; requestType = registration ? .passkeyRegistration : .passkeyAssertion
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(credentialIdentity, forKey: "identity"); coder.encode(clientDataHash, forKey: "hash")
        coder.encode(userVerificationPreference.rawValue, forKey: "uv"); coder.encode(Int(requestType.rawValue), forKey: "type")
    }
    public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: ASPasskeyCredentialIdentity.self, forKey: "identity"), let h = coder.decodeObject(of: NSData.self, forKey: "hash") as Data? else { return nil }
        credentialIdentity = i; clientDataHash = h
        userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: (coder.decodeObject(of: NSString.self, forKey: "uv") as String?) ?? "preferred")
        supportedAlgorithms = [.ES256]; excludedCredentials = nil
        requestType = ASCredentialRequestType(rawValue: UInt(coder.decodeInteger(forKey: "type"))) ?? .passkeyAssertion
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

/// What a provider gets for its passkey list (prepareCredentialList(for:requestParameters:)).
@objc(ASPasskeyCredentialRequestParameters) open class ASPasskeyCredentialRequestParameters: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let relyingPartyIdentifier: String
    @objc public let clientDataHash: Data
    public let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    @objc public let allowedCredentials: [Data]
    init(rp: String, hash: Data, uv: ASAuthorizationPublicKeyCredentialUserVerificationPreference, allowed: [Data]) {
        relyingPartyIdentifier = rp; clientDataHash = hash; userVerificationPreference = uv; allowedCredentials = allowed
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(relyingPartyIdentifier, forKey: "rp"); coder.encode(clientDataHash, forKey: "hash"); coder.encode(userVerificationPreference.rawValue, forKey: "uv")
    }
    public required init?(coder: NSCoder) {
        guard let rp = coder.decodeObject(of: NSString.self, forKey: "rp") as String?, let h = coder.decodeObject(of: NSData.self, forKey: "hash") as Data? else { return nil }
        relyingPartyIdentifier = rp; clientDataHash = h
        userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: (coder.decodeObject(of: NSString.self, forKey: "uv") as String?) ?? "preferred")
        allowedCredentials = []
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

@objc(ASPasskeyAssertionCredential) open class ASPasskeyAssertionCredential: NSObject, ASAuthorizationCredential, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let userHandle: Data
    @objc public let relyingParty: String
    @objc public let signature: Data
    @objc public let clientDataHash: Data
    @objc public let authenticatorData: Data
    @objc public let credentialID: Data
    @objc(initWithUserHandle:relyingParty:signature:clientDataHash:authenticatorData:credentialID:)
    public init(userHandle: Data, relyingParty: String, signature: Data, clientDataHash: Data, authenticatorData: Data, credentialID: Data) {
        self.userHandle = userHandle; self.relyingParty = relyingParty; self.signature = signature; self.clientDataHash = clientDataHash
        self.authenticatorData = authenticatorData; self.credentialID = credentialID
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(userHandle, forKey: "handle"); coder.encode(relyingParty, forKey: "rp"); coder.encode(signature, forKey: "sig")
        coder.encode(clientDataHash, forKey: "hash"); coder.encode(authenticatorData, forKey: "auth"); coder.encode(credentialID, forKey: "id")
    }
    public required init?(coder: NSCoder) {
        guard let h = coder.decodeObject(of: NSData.self, forKey: "handle") as Data?, let rp = coder.decodeObject(of: NSString.self, forKey: "rp") as String?,
              let s = coder.decodeObject(of: NSData.self, forKey: "sig") as Data?, let c = coder.decodeObject(of: NSData.self, forKey: "hash") as Data?,
              let a = coder.decodeObject(of: NSData.self, forKey: "auth") as Data?, let i = coder.decodeObject(of: NSData.self, forKey: "id") as Data? else { return nil }
        userHandle = h; relyingParty = rp; signature = s; clientDataHash = c; authenticatorData = a; credentialID = i
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

@objc(ASPasskeyRegistrationCredential) open class ASPasskeyRegistrationCredential: NSObject, ASAuthorizationCredential, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let relyingParty: String
    @objc public let clientDataHash: Data
    @objc public let credentialID: Data
    @objc public let attestationObject: Data
    @objc(initWithRelyingParty:clientDataHash:credentialID:attestationObject:)
    public init(relyingParty: String, clientDataHash: Data, credentialID: Data, attestationObject: Data) {
        self.relyingParty = relyingParty; self.clientDataHash = clientDataHash; self.credentialID = credentialID; self.attestationObject = attestationObject
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(relyingParty, forKey: "rp"); coder.encode(clientDataHash, forKey: "hash"); coder.encode(credentialID, forKey: "id"); coder.encode(attestationObject, forKey: "att")
    }
    public required init?(coder: NSCoder) {
        guard let rp = coder.decodeObject(of: NSString.self, forKey: "rp") as String?, let c = coder.decodeObject(of: NSData.self, forKey: "hash") as Data?,
              let i = coder.decodeObject(of: NSData.self, forKey: "id") as Data?, let a = coder.decodeObject(of: NSData.self, forKey: "att") as Data? else { return nil }
        relyingParty = rp; clientDataHash = c; credentialID = i; attestationObject = a
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

/// iOS 18: a one-time code a provider fills.
@objc(ASOneTimeCodeCredential) open class ASOneTimeCodeCredential: NSObject, ASAuthorizationCredential, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let code: String
    @objc(initWithCode:) public init(code: String) { self.code = code }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(code, forKey: "code") }
    public required init?(coder: NSCoder) {
        guard let c = coder.decodeObject(of: NSString.self, forKey: "code") as String? else { return nil }
        code = c
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

public let ASExtensionErrorDomain = "ASExtensionErrorDomain"
public let ASExtensionLocalizedFailureReasonErrorKey = "ASExtensionLocalizedFailureReasonErrorKey"

public struct ASExtensionError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case failed = 0, userCanceled = 1, userInteractionRequired = 100, credentialIdentityNotFound = 101
        /// iOS 18
        case matchedExcludedCredential = 102
    }
    public let code: Code
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; info = userInfo }
    nonisolated(unsafe) let info: [String: Any]
    public static var errorDomain: String { ASExtensionErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { info }
    public static func == (a: ASExtensionError, b: ASExtensionError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var failed: Code { .failed }
    public static var userCanceled: Code { .userCanceled }
    public static var userInteractionRequired: Code { .userInteractionRequired }
    public static var credentialIdentityNotFound: Code { .credentialIdentityNotFound }
    public static var matchedExcludedCredential: Code { .matchedExcludedCredential }
}

// MARK: - the identity store

@objc(ASCredentialIdentityStoreState) open class ASCredentialIdentityStoreState: NSObject, @unchecked Sendable {
    @objc(isEnabled) public let isEnabled: Bool
    @objc public let supportsIncrementalUpdates: Bool
    init(enabled: Bool) { isEnabled = enabled; supportsIncrementalUpdates = true }
}

public let ASCredentialIdentityStoreErrorDomain = "ASCredentialIdentityStoreErrorDomain"

public struct ASCredentialIdentityStoreError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case internalError = 0, storeDisabled = 1, storeBusy = 2 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { ASCredentialIdentityStoreErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var internalError: Code { .internalError }
    public static var storeDisabled: Code { .storeDisabled }
    public static var storeBusy: Code { .storeBusy }
}

/// The identities a credential provider offers to AutoFill.
@objc(ASCredentialIdentityStore) open class ASCredentialIdentityStore: NSObject, @unchecked Sendable {
    public struct IdentityTypes: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let all = IdentityTypes([])
        public static let password = IdentityTypes(rawValue: 1)
        public static let oneTimeCode = IdentityTypes(rawValue: 2)
        public static let passkey = IdentityTypes(rawValue: 4)
    }
    static let _shared = ASCredentialIdentityStore()
    @objc(sharedStore) open class var shared: ASCredentialIdentityStore { _shared }

    /// the provider extension this store belongs to (the one running, else the app's embedded one)
    var provider: _ASProviderExtension? { _ASProviderHost.running ?? _ASProviderExtension.embedded() }

    @objc(getCredentialIdentityStoreStateWithCompletion:) open func getState(_ completion: @escaping (ASCredentialIdentityStoreState) -> Void) {
        let on = provider.map { _ASProviders.enabled($0.bundleID) } ?? false
        DispatchQueue.main.async { completion(ASCredentialIdentityStoreState(enabled: on)) }
    }
    open func state() async -> ASCredentialIdentityStoreState {
        await withCheckedContinuation { c in getState { c.resume(returning: $0) } }
    }

    func update(_ body: (inout [[String: Any]]) -> Void, _ completion: ((Bool, Error?) -> Void)?) {
        guard let p = provider else {
            NSLog("isim AuthenticationServices: ASCredentialIdentityStore: this app has no credential provider extension")
            DispatchQueue.main.async { completion?(false, ASCredentialIdentityStoreError(.internalError)) }; return
        }
        guard _ASProviders.enabled(p.bundleID) else {
            NSLog("isim AuthenticationServices: ASCredentialIdentityStore: %@ is not turned on in Settings > Passwords > Password Options", p.name)
            DispatchQueue.main.async { completion?(false, ASCredentialIdentityStoreError(.storeDisabled)) }; return
        }
        var list = _ASProviders.identities(p.bundleID)
        body(&list)
        _ASProviders.save(p, list)
        NSLog("isim AuthenticationServices: ASCredentialIdentityStore: %@ has %d credential identit%@", p.name, list.count, list.count == 1 ? "y" : "ies")
        DispatchQueue.main.async { completion?(true, nil) }
    }
    @objc(saveCredentialIdentityEntries:completion:) open func saveCredentialIdentities(_ credentialIdentities: [ASCredentialIdentity], completion: ((Bool, Error?) -> Void)? = nil) {
        let new = credentialIdentities.compactMap(_ASProviders.record)
        update({ list in
            for n in new {
                list.removeAll { _ASProviders.sameIdentity($0, n) }
                list.append(n)
            }
        }, completion)
    }
    @objc(removeCredentialIdentityEntries:completion:) open func removeCredentialIdentities(_ credentialIdentities: [ASCredentialIdentity], completion: ((Bool, Error?) -> Void)? = nil) {
        let gone = credentialIdentities.compactMap(_ASProviders.record)
        update({ list in list.removeAll { e in gone.contains { _ASProviders.sameIdentity(e, $0) } } }, completion)
    }
    @objc(removeAllCredentialIdentitiesWithCompletion:) open func removeAllCredentialIdentities(_ completion: ((Bool, Error?) -> Void)? = nil) { update({ $0 = [] }, completion) }
    @objc(replaceCredentialIdentityEntries:completion:) open func replaceCredentialIdentities(_ newCredentialIdentities: [ASCredentialIdentity], completion: ((Bool, Error?) -> Void)? = nil) {
        let new = newCredentialIdentities.compactMap(_ASProviders.record)
        update({ $0 = new }, completion)
    }
    /// before iOS 17: password identities only
    @objc(replaceCredentialIdentitiesWithIdentities:completion:) open func replaceCredentialIdentities(with newCredentialIdentities: [ASPasswordCredentialIdentity], completion: ((Bool, Error?) -> Void)? = nil) {
        replaceCredentialIdentities(newCredentialIdentities as [ASCredentialIdentity], completion: completion)
    }
    open func saveCredentialIdentities(_ credentialIdentities: [ASCredentialIdentity]) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            saveCredentialIdentities(credentialIdentities) { ok, e in ok ? c.resume() : c.resume(throwing: e ?? ASCredentialIdentityStoreError(.internalError)) }
        }
    }
    open func removeCredentialIdentities(_ credentialIdentities: [ASCredentialIdentity]) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            removeCredentialIdentities(credentialIdentities) { ok, e in ok ? c.resume() : c.resume(throwing: e ?? ASCredentialIdentityStoreError(.internalError)) }
        }
    }
    open func removeAllCredentialIdentities() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            removeAllCredentialIdentities { ok, e in ok ? c.resume() : c.resume(throwing: e ?? ASCredentialIdentityStoreError(.internalError)) }
        }
    }
    open func replaceCredentialIdentities(_ newCredentialIdentities: [ASCredentialIdentity]) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            replaceCredentialIdentities(newCredentialIdentities) { ok, e in ok ? c.resume() : c.resume(throwing: e ?? ASCredentialIdentityStoreError(.internalError)) }
        }
    }
    /// iOS 18: the identities this provider saved (for a service, of some types)
    open func credentialIdentities(forService serviceIdentifier: ASCredentialServiceIdentifier? = nil,
                                   credentialIdentityTypes: IdentityTypes = []) async -> [ASCredentialIdentity] {
        guard let p = provider else { return [] }
        return _ASProviders.identities(p.bundleID).compactMap(_ASProviders.identity).filter { i in
            if let s = serviceIdentifier, i.serviceIdentifier.host != s.host { return false }
            if credentialIdentityTypes.isEmpty { return true }
            if i is ASPasswordCredentialIdentity { return credentialIdentityTypes.contains(.password) }
            if i is ASPasskeyCredentialIdentity { return credentialIdentityTypes.contains(.passkey) }
            return credentialIdentityTypes.contains(.oneTimeCode)
        }
    }
}

/// Opens the system settings for credential providers.
@objc(ASSettingsHelper) open class ASSettingsHelper: NSObject {
    /// Settings > Passwords > Password Options
    @objc(openCredentialProviderAppSettingsWithCompletionHandler:) open class func openCredentialProviderAppSettings(completionHandler: ((Error?) -> Void)? = nil) {
        NSLog("isim AuthenticationServices: opening Settings > Passwords > Password Options")
        _ASProviders.openSettings()
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    /// Settings > Passwords > Password Options (verification codes)
    @objc(openVerificationCodeAppSettingsWithCompletionHandler:) open class func openVerificationCodeAppSettings(completionHandler: ((Error?) -> Void)? = nil) {
        openCredentialProviderAppSettings(completionHandler: completionHandler)
    }
    /// iOS 18: asks to turn on the app's credential provider (an alert); true when it is on
    @objc(requestToTurnOnCredentialProviderExtensionWithCompletionHandler:)
    @MainActor open class func requestToTurnOnCredentialProviderExtension(completionHandler: @escaping (Bool) -> Void) {
        guard let p = _ASProviderExtension.embedded() else { completionHandler(false); return }
        if _ASProviders.enabled(p.bundleID) { completionHandler(true); return }
        let answer = ProcessInfo.processInfo.environment["ISIM_AUTOFILL_PROVIDER_ANSWER"]
        if answer == "allow" || answer == "deny" {
            let on = answer == "allow"
            if on { _ASProviders.enable(p) }
            NSLog("isim AuthenticationServices: turn on %@ for AutoFill: %@ (ISIM_AUTOFILL_PROVIDER_ANSWER)", p.name, on ? "allowed" : "not now")
            completionHandler(on); return
        }
        let a = UIAlertController(title: "Turn On AutoFill?", message: "Allow “\(p.name)” to provide passwords and passkeys in other apps and websites.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            NSLog("isim AuthenticationServices: turn on %@ for AutoFill: not now", p.name); completionHandler(false)
        })
        a.addAction(UIAlertAction(title: "Turn On", style: .default) { _ in
            _ASProviders.enable(p)
            NSLog("isim AuthenticationServices: turn on %@ for AutoFill: turned on", p.name); completionHandler(true)
        })
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(a, animated: true)
    }
}

// MARK: - the extension's side

@objc(ASCredentialProviderExtensionContext) open class ASCredentialProviderExtensionContext: NSExtensionContext, @unchecked Sendable {
    var onCredential: ((ASAuthorizationCredential) -> Void)?
    var onText: ((String) -> Void)?
    var onCancel: ((Error) -> Void)?
    var onConfiguration: (() -> Void)?
    var done = false
    private func finish(_ f: () -> Void) { guard !done else { return }; done = true; f() }

    @objc(completeRequestWithSelectedCredential:completionHandler:)
    open func completeRequest(withSelectedCredential credential: ASPasswordCredential, completionHandler: ((Bool) -> Void)? = nil) {
        finish { onCredential?(credential) }; completionHandler?(true)
    }
    @objc(completeAssertionRequestWithSelectedPasskeyCredential:completionHandler:)
    open func completeAssertionRequest(using credential: ASPasskeyAssertionCredential, completionHandler: ((Bool) -> Void)? = nil) {
        finish { onCredential?(credential) }; completionHandler?(true)
    }
    @objc(completeRegistrationRequestWithSelectedPasskeyCredential:completionHandler:)
    open func completeRegistrationRequest(using credential: ASPasskeyRegistrationCredential, completionHandler: ((Bool) -> Void)? = nil) {
        finish { onCredential?(credential) }; completionHandler?(true)
    }
    /// iOS 18
    @objc(completeOneTimeCodeRequestWithSelectedCredential:completionHandler:)
    open func completeOneTimeCodeRequest(using credential: ASOneTimeCodeCredential, completionHandler: ((Bool) -> Void)? = nil) {
        finish { onCredential?(credential) }; completionHandler?(true)
    }
    /// iOS 18: text the user chose in the provider (AutoFill > Passwords in the edit menu)
    @objc(completeRequestWithTextToInsert:completionHandler:)
    open func completeRequest(withTextToInsert text: String, completionHandler: ((Bool) -> Void)? = nil) {
        finish { onText?(text) }; completionHandler?(true)
    }
    @objc open func completeExtensionConfigurationRequest() { finish { onConfiguration?() } }
    /// iOS 26: the provider saved the password the user typed
    open func completeSavePasswordRequest(completionHandler: ((Bool) -> Void)? = nil) { finish { onConfiguration?() }; completionHandler?(true) }
    open override func cancelRequest(withError error: Error) { finish { onCancel?(error) } }
}

/// The view controller a credential provider extension subclasses.
@objc(ASCredentialProviderViewController) open class ASCredentialProviderViewController: UIViewController {
    var _context = ASCredentialProviderExtensionContext()
    open override var extensionContext: ASCredentialProviderExtensionContext { _context }

    /// the provider's list of credentials for these services (its UI is shown)
    @objc(prepareCredentialListForServiceIdentifiers:) open func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {}
    /// iOS 17: also passkeys for a relying party
    @objc(prepareCredentialListForServiceIdentifiers:requestParameters:)
    open func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        prepareCredentialList(for: serviceIdentifiers)
    }
    /// iOS 18: one-time codes for these services
    @objc(prepareOneTimeCodeCredentialListForServiceIdentifiers:) open func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {}
    /// a credential without showing UI, or cancel with ASExtensionError.userInteractionRequired
    @objc(provideCredentialWithoutUserInteractionForRequest:) open func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        if let p = credentialRequest.credentialIdentity as? ASPasswordCredentialIdentity { provideCredentialWithoutUserInteraction(for: p); return }
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }
    /// before iOS 17
    @objc(provideCredentialWithoutUserInteractionForIdentity:) open func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }
    @objc(prepareInterfaceToProvideCredentialForRequest:) open func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        if let p = credentialRequest.credentialIdentity as? ASPasswordCredentialIdentity { prepareInterfaceToProvideCredential(for: p) }
    }
    /// before iOS 17
    @objc(prepareInterfaceToProvideCredentialForIdentity:) open func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {}
    @objc(prepareInterfaceForPasskeyRegistration:) open func prepareInterface(forPasskeyRegistration registrationRequest: ASCredentialRequest) {}
    /// iOS 26: register without UI if the provider can
    @objc(performPasskeyRegistrationWithoutUserInteractionIfPossible:)
    open func performWithoutUserInteractionIfPossible(passkeyRegistration registrationRequest: ASPasskeyCredentialRequest) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }
    /// shown when the user turns the provider on in Settings (ASCredentialProviderExtensionCapabilities ProvidesExtensionConfiguration)
    @objc open func prepareInterfaceForExtensionConfiguration() {}
    /// iOS 18
    @objc open func prepareInterfaceForUserChoosingTextToInsert() {}
    /// iOS 26: what the relying party reports about the provider's credentials (isim's relying parties report nothing)
    open func reportPublicKeyCredentialUpdate(forRelyingParty relyingParty: String, userHandle: Data, newName: String) {}
    open func reportUnknownPublicKeyCredential(forRelyingParty relyingParty: String, credentialID: Data) {}
    open func reportAllAcceptedPublicKeyCredentials(forRelyingParty relyingParty: String, userHandle: Data, acceptedCredentialIDs: [Data]) {}
    open func reportUnusedPasswordCredential(forDomain domain: String, userName: String) {}
}

// MARK: - isim: providers in the device data

/// A credential provider extension (an .appex in an app's PlugIns).
struct _ASProviderExtension {
    static let point = "com.apple.authentication-services-credential-provider-ui"
    let path: String, bundleID: String, executable: String, principal: String?, storyboard: String?, name: String, appPath: String
    var attributes: [String: Any]

    init?(path: String, app: String) {
        guard let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
              let ext = info["NSExtension"] as? [String: Any], ext["NSExtensionPointIdentifier"] as? String == _ASProviderExtension.point else { return nil }
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        self.path = path; appPath = app
        bundleID = info["CFBundleIdentifier"] as? String ?? base
        executable = (path as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? base)
        principal = ext["NSExtensionPrincipalClass"] as? String
        storyboard = ext["NSExtensionMainStoryboard"] as? String
        let appInfo = NSDictionary(contentsOfFile: (app as NSString).appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
        name = appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? info["CFBundleDisplayName"] as? String ?? base
        attributes = ext["NSExtensionAttributes"] as? [String: Any] ?? [:]
    }
    /// the provider extension embedded in this app (or this extension itself)
    static func embedded() -> _ASProviderExtension? {
        let main = Bundle.main.bundlePath
        if main.hasSuffix(".appex") {
            return _ASProviderExtension(path: main, app: ((main as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)
        }
        let plugins = (main as NSString).appendingPathComponent("PlugIns")
        for n in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where n.hasSuffix(".appex") {
            if let x = _ASProviderExtension(path: (plugins as NSString).appendingPathComponent(n), app: main) { return x }
        }
        return nil
    }
    var capabilities: [String: Any] { attributes["ASCredentialProviderExtensionCapabilities"] as? [String: Any] ?? [:] }
    var supportsPasskeys: Bool { capabilities["ProvidesPasskeys"] as? Bool ?? false }
}

enum _ASProviders {
    static var dir: String {
        let p = (_ASData.dataDir as NSString).appendingPathComponent("Library/isim/CredentialProviders")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
        return p
    }
    static func file(_ bundleID: String) -> String { (dir as NSString).appendingPathComponent(bundleID + ".json") }
    static var prefs: UserDefaults? { UserDefaults(suiteName: ".GlobalPreferences") }
    static func enabled(_ bundleID: String) -> Bool { (prefs?.array(forKey: "AutoFillProviders") as? [String] ?? []).contains(bundleID) }
    static func setEnabled(_ bundleID: String, _ on: Bool) {
        var l = prefs?.array(forKey: "AutoFillProviders") as? [String] ?? []
        l.removeAll { $0 == bundleID }
        if on { l.append(bundleID) }
        prefs?.set(l, forKey: "AutoFillProviders")
        prefs?.synchronize()
    }
    /// turns a provider on, with its store file (which says where the extension is)
    static func enable(_ p: _ASProviderExtension) {
        setEnabled(p.bundleID, true)
        save(p, identities(p.bundleID))
    }
    static func identities(_ bundleID: String) -> [[String: Any]] { (_ASData.readJSON(file(bundleID)) as? [String: Any])?["identities"] as? [[String: Any]] ?? [] }
    /// written with where the extension is, so UIKit's AutoFill can find and run it
    static func save(_ p: _ASProviderExtension, _ list: [[String: Any]]) {
        _ASData.writeJSON(["bundleID": p.bundleID, "name": p.name, "extension": p.path, "executable": p.executable, "identities": list], file(p.bundleID))
    }
    static func record(_ i: ASCredentialIdentity) -> [String: Any]? {
        var r: [String: Any] = ["rank": i.rank, "record": i.recordIdentifier ?? NSNull()]
        switch i {
        case let p as ASPasswordCredentialIdentity:
            r["kind"] = "password"; r["service"] = p.serviceIdentifier.identifier; r["serviceType"] = p.serviceIdentifier.type.rawValue; r["user"] = p.user
        case let k as ASPasskeyCredentialIdentity:
            r["kind"] = "passkey"; r["service"] = k.relyingPartyIdentifier; r["serviceType"] = 0; r["user"] = k.userName
            r["credentialID"] = k.credentialID.base64EncodedString(); r["userHandle"] = k.userHandle.base64EncodedString()
        case let o as ASOneTimeCodeCredentialIdentity:
            r["kind"] = "oneTimeCode"; r["service"] = o.serviceIdentifier.identifier; r["serviceType"] = o.serviceIdentifier.type.rawValue; r["user"] = o.label
        default: return nil
        }
        return r
    }
    static func identity(_ r: [String: Any]) -> ASCredentialIdentity? {
        guard let service = r["service"] as? String, let user = r["user"] as? String else { return nil }
        let sid = ASCredentialServiceIdentifier(identifier: service, type: .init(rawValue: r["serviceType"] as? Int ?? 0) ?? .domain)
        let record = r["record"] as? String
        let out: ASCredentialIdentity
        switch r["kind"] as? String {
        case "passkey":
            guard let id = (r["credentialID"] as? String).flatMap({ Data(base64Encoded: $0) }), let h = (r["userHandle"] as? String).flatMap({ Data(base64Encoded: $0) }) else { return nil }
            out = ASPasskeyCredentialIdentity(relyingPartyIdentifier: service, userName: user, credentialID: id, userHandle: h, recordIdentifier: record)
        case "oneTimeCode": out = ASOneTimeCodeCredentialIdentity(serviceIdentifier: sid, label: user, recordIdentifier: record)
        default: out = ASPasswordCredentialIdentity(serviceIdentifier: sid, user: user, recordIdentifier: record)
        }
        out.rank = r["rank"] as? Int ?? 0
        return out
    }
    static func sameIdentity(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        if let ra = a["record"] as? String, let rb = b["record"] as? String { return ra == rb && a["kind"] as? String == b["kind"] as? String }
        return a["kind"] as? String == b["kind"] as? String && a["service"] as? String == b["service"] as? String && a["user"] as? String == b["user"] as? String
            && a["credentialID"] as? String == b["credentialID"] as? String
    }
    /// every installed provider with identities, enabled ones only
    static func enabledStores() -> [(store: [String: Any], identities: [[String: Any]])] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted().compactMap { f in
            guard f.hasSuffix(".json"), let s = _ASData.readJSON((dir as NSString).appendingPathComponent(f)) as? [String: Any],
                  let id = s["bundleID"] as? String, enabled(id) else { return nil }
            return (s, s["identities"] as? [[String: Any]] ?? [])
        }
    }
    /// the provider passkeys for a relying party (ASAuthorizationController's chooser)
    static func passkeys(_ rp: String) -> [(store: [String: Any], identity: ASPasskeyCredentialIdentity)] {
        enabledStores().flatMap { s in
            s.identities.compactMap { r -> (store: [String: Any], identity: ASPasskeyCredentialIdentity)? in
                guard r["kind"] as? String == "passkey", (r["service"] as? String)?.lowercased() == rp.lowercased(),
                      let k = identity(r) as? ASPasskeyCredentialIdentity else { return nil }
                return (s.store, k)
            }
        }
    }
    static func openSettings() {
        if let u = URL(string: "app-settings:passwordoptions") { DispatchQueue.main.async { UIApplication.shared.open(u) } }
    }
}

// MARK: - isim: running a provider extension in this process

@MainActor enum _ASProviderHost {
    /// the extension being run (ASCredentialIdentityStore.shared inside it belongs to it)
    nonisolated(unsafe) static var running: _ASProviderExtension?
    static var hosted: ASCredentialProviderViewController?

    static func load(_ x: _ASProviderExtension) -> ASCredentialProviderViewController? {
        guard dlopen(x.executable, RTLD_NOW) != nil else {
            NSLog("isim AuthenticationServices: cannot load the credential provider %@: %s", x.bundleID, dlerror().map { String(cString: $0) } ?? "?"); return nil
        }
        _isimRegisterExtensionBundle(x.path as NSString)
        var vc: UIViewController?
        if let p = x.principal, let cls = NSClassFromString(p) as? UIViewController.Type { vc = (cls as NSObject.Type).init() as? UIViewController }
        else if let s = x.storyboard { vc = UIStoryboard(name: s, bundle: Bundle(path: x.path)).instantiateInitialViewController() }
        guard let provider = vc as? ASCredentialProviderViewController else {
            NSLog("isim AuthenticationServices: the credential provider %@ has no ASCredentialProviderViewController (NSExtensionPrincipalClass %@)", x.bundleID, x.principal ?? "-")
            return nil
        }
        return provider
    }
    static func top() -> UIViewController? {
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }

    /// runs the provider for a request: without UI first, then (if it asks) its UI; done gets the credential, or the
    /// error it cancelled with
    static func run(_ x: _ASProviderExtension, _ request: ASCredentialRequest, done: @escaping (Result<ASAuthorizationCredential, Error>) -> Void) {
        guard let vc = load(x) else { done(.failure(ASExtensionError(.failed))); return }
        running = x; hosted = vc
        var presented = false
        func finish(_ r: Result<ASAuthorizationCredential, Error>) {
            running = nil; hosted = nil
            if presented, vc.presentingViewController != nil { vc.dismiss(animated: true) { done(r) } } else { done(r) }
        }
        let ctx = vc._context
        ctx.onCredential = { c in
            NSLog("isim AuthenticationServices: %@ provided a credential (%@)", x.name, presented ? "after its UI" : "without UI")
            finish(.success(c))
        }
        ctx.onCancel = { e in
            if !presented, let ae = e as? ASExtensionError, ae.code == .userInteractionRequired {
                NSLog("isim AuthenticationServices: %@ needs the user: showing its UI", x.name)
                ctx.done = false; presented = true
                vc.loadViewIfNeeded()
                if request.type == .passkeyRegistration { vc.prepareInterface(forPasskeyRegistration: request) }
                else { vc.prepareInterfaceToProvideCredential(for: request) }
                vc.modalPresentationStyle = .pageSheet
                top()?.present(vc, animated: true)
                return
            }
            NSLog("isim AuthenticationServices: %@ cancelled the request: %@", x.name, String(describing: e))
            finish(.failure(e))
        }
        NSLog("isim AuthenticationServices: running the credential provider %@ (%@) in the app process", x.name, x.bundleID)
        if request.type == .passkeyRegistration, let r = request as? ASPasskeyCredentialRequest {
            if #available(iOS 26.0, *) {
                vc.performWithoutUserInteractionIfPossible(passkeyRegistration: r)
            } else {
                ctx.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            }
        } else {
            vc.provideCredentialWithoutUserInteraction(for: request)
        }
    }

    /// the provider's own list (prepareCredentialList), presented as a sheet
    static func list(_ x: _ASProviderExtension, services: [ASCredentialServiceIdentifier], oneTimeCodes: Bool,
                     done: @escaping (Result<ASAuthorizationCredential, Error>) -> Void) {
        guard let vc = load(x) else { done(.failure(ASExtensionError(.failed))); return }
        running = x; hosted = vc
        func finish(_ r: Result<ASAuthorizationCredential, Error>) {
            running = nil; hosted = nil
            if vc.presentingViewController != nil { vc.dismiss(animated: true) { done(r) } } else { done(r) }
        }
        vc._context.onCredential = { finish(.success($0)) }
        vc._context.onCancel = { finish(.failure($0)) }
        vc.loadViewIfNeeded()
        if oneTimeCodes { vc.prepareOneTimeCodeCredentialList(for: services) } else { vc.prepareCredentialList(for: services) }
        vc.modalPresentationStyle = .pageSheet
        top()?.present(vc, animated: true)
    }

    nonisolated static func provider(_ store: [String: Any]) -> _ASProviderExtension? {
        guard let path = store["extension"] as? String else { return nil }
        return _ASProviderExtension(path: path, app: ((path as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)
    }
}

@_silgen_name("isim_bundle_register_extension") func _isimRegisterExtensionBundle(_ path: NSString)

/// UIKit's AutoFill (UITextServices.m) runs a provider for a picked identity: kind password / oneTimeCode / list;
/// done gets {user, password} or {code}, or nil (cancelled or failed).
@_cdecl("isim_as_provide_credential")
public func _isimProvideCredential(_ store: NSDictionary, _ identity: NSDictionary, _ done: @escaping @convention(block) (NSDictionary?) -> Void) {
    MainActor.assumeIsolated {
        guard let s = store as? [String: Any], let x = _ASProviderHost.provider(s) else { done(nil); return }
        let result: (Result<ASAuthorizationCredential, Error>) -> Void = { r in
            switch r {
            case .success(let c as ASPasswordCredential): done(["user": c.user, "password": c.password] as NSDictionary)
            case .success(let c as ASOneTimeCodeCredential): done(["code": c.code] as NSDictionary)
            default: done(nil)
            }
        }
        let r = identity as? [String: Any] ?? [:]
        if r["kind"] as? String == "list" {
            let services = (r["services"] as? [String] ?? []).map { ASCredentialServiceIdentifier(identifier: $0, type: .domain) }
            _ASProviderHost.list(x, services: services, oneTimeCodes: r["oneTimeCodes"] as? Bool ?? false, done: result)
            return
        }
        switch _ASProviders.identity(r) {
        case let p as ASPasswordCredentialIdentity: _ASProviderHost.run(x, ASPasswordCredentialRequest(credentialIdentity: p), done: result)
        case let o as ASOneTimeCodeCredentialIdentity: _ASProviderHost.run(x, ASOneTimeCodeCredentialRequest(credentialIdentity: o), done: result)
        default: done(nil)
        }
    }
}

/// a provider passkey's assertion, as the app gets it: isim makes the client data, the provider signs its hash
extension _ASPasskeys {
    @MainActor static func providerAssertion(_ c: ASAuthorizationController, _ r: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest,
                                             _ store: [String: Any], _ k: ASPasskeyCredentialIdentity, done: @escaping () -> Void) {
        guard let x = _ASProviderHost.provider(store) else { done(); c.fail(.failed); return }
        let cd = clientData("webauthn.get", r.challenge, r.relyingPartyIdentifier)
        let request = ASPasskeyCredentialRequest(k, hash: Data(SHA256.hash(data: cd)), uv: r.userVerificationPreference, registration: false, excluded: nil)
        _ASProviderHost.run(x, request) { result in
            done()
            guard case .success(let cred as ASPasskeyAssertionCredential) = result else { c.fail(.canceled); return }
            c.complete(r.provider, ASAuthorizationPlatformPublicKeyCredentialAssertion(authData: cred.authenticatorData, clientData: cd, id: cred.credentialID,
                                                                                         signature: cred.signature, userID: cred.userHandle))
        }
    }
    @MainActor static func providerRegistration(_ c: ASAuthorizationController, _ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest,
                                                _ x: _ASProviderExtension, done: @escaping () -> Void) {
        let cd = clientData("webauthn.create", r.challenge, r.relyingPartyIdentifier)
        let identity = ASPasskeyCredentialIdentity(relyingPartyIdentifier: r.relyingPartyIdentifier, userName: r.name, credentialID: Data(), userHandle: r.userID, recordIdentifier: nil)
        let request = ASPasskeyCredentialRequest(identity, hash: Data(SHA256.hash(data: cd)), uv: r.userVerificationPreference, registration: true,
                                                 excluded: r.excludedCredentials.isEmpty ? nil : r.excludedCredentials)
        _ASProviderHost.run(x, request) { result in
            done()
            switch result {
            case .success(let cred as ASPasskeyRegistrationCredential):
                c.complete(r.provider, ASAuthorizationPlatformPublicKeyCredentialRegistration(attestation: cred.attestationObject, clientData: cd, id: cred.credentialID))
            case .failure(let e as ASExtensionError) where e.code == .matchedExcludedCredential: c.fail(.matchedExcludedCredential)
            default: c.fail(.canceled)
            }
        }
    }
    /// enabled providers that take passkeys (the registration sheet offers to save to them)
    static func passkeyProviders() -> [_ASProviderExtension] {
        _ASProviders.enabledStores().compactMap { _ASProviderHost.provider($0.store) }.filter(\.supportsPasskeys)
    }
}
