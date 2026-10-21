// Passkeys (WebAuthn, platform authenticator) as a local simulation with real cryptography: see Core.swift.
import Foundation
import CryptoKit

public struct ASAuthorizationPublicKeyCredentialUserVerificationPreference: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let preferred = Self(rawValue: "preferred")
    public static let required = Self(rawValue: "required")
    public static let discouraged = Self(rawValue: "discouraged")
}
public struct ASAuthorizationPublicKeyCredentialAttestationKind: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let none = Self(rawValue: "none")
    public static let direct = Self(rawValue: "direct")
    public static let indirect = Self(rawValue: "indirect")
    public static let enterprise = Self(rawValue: "enterprise")
}
public enum ASAuthorizationPublicKeyCredentialAttachment: Int, Sendable { case platform = 0, crossPlatform = 1 }

@objc(ASAuthorizationPlatformPublicKeyCredentialDescriptor) open class ASAuthorizationPlatformPublicKeyCredentialDescriptor: NSObject {
    open var credentialID: Data
    public init(credentialID: Data) { self.credentialID = credentialID }
}

@objc(ASAuthorizationPlatformPublicKeyCredentialProvider) open class ASAuthorizationPlatformPublicKeyCredentialProvider: NSObject, ASAuthorizationProvider {
    public let relyingPartyIdentifier: String
    public init(relyingPartyIdentifier: String) { self.relyingPartyIdentifier = relyingPartyIdentifier }
    open func createCredentialRegistrationRequest(challenge: Data, name: String, userID: Data) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge, name: name, userID: userID)
    }
    open func createCredentialAssertionRequest(challenge: Data) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        ASAuthorizationPlatformPublicKeyCredentialAssertionRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge)
    }
    @available(iOS 18.0, *)
    open func createCredentialRegistrationRequest(challenge: Data, name: String, userID: Data,
                                                  requestStyle: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest.RequestStyle) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        let r = createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
        r.requestStyle = requestStyle
        return r
    }
}

@objc(ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) open class ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var name: String
    open var displayName: String?
    open var userID: Data
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    open var attestationPreference: ASAuthorizationPublicKeyCredentialAttestationKind = .none
    open var excludedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
    open var prf: ASAuthorizationPublicKeyCredentialPRFRegistrationInput?
    open var largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput?
    /// iOS 18: .conditional creates the passkey without a sheet when the user just signed in to the account with a saved password
    @available(iOS 18.0, *)
    @objc(ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyle) public enum RequestStyle: Int, Sendable {
        case standard = 0, conditional = 1
    }
    var _requestStyle = 0
    @available(iOS 18.0, *)
    open var requestStyle: RequestStyle {
        get { RequestStyle(rawValue: _requestStyle) ?? .standard } set { _requestStyle = newValue.rawValue }
    }
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data, name: String, userID: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge; self.name = name; self.userID = userID
        super.init(provider: provider)
    }
}

@objc(ASAuthorizationPlatformPublicKeyCredentialAssertionRequest) open class ASAuthorizationPlatformPublicKeyCredentialAssertionRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    open var prf: ASAuthorizationPublicKeyCredentialPRFAssertionInput?
    open var largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput?
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge
        super.init(provider: provider)
    }
}

@objc(ASAuthorizationPlatformPublicKeyCredentialRegistration) open class ASAuthorizationPlatformPublicKeyCredentialRegistration: NSObject, ASAuthorizationCredential {
    public let rawAttestationObject: Data?
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .platform
    public let prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?
    public let largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput?
    init(attestation: Data, clientData: Data, id: Data, prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput? = nil,
         largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput? = nil) {
        rawAttestationObject = attestation; rawClientDataJSON = clientData; credentialID = id; self.prf = prf; self.largeBlob = largeBlob
    }
}

@objc(ASAuthorizationPlatformPublicKeyCredentialAssertion) open class ASAuthorizationPlatformPublicKeyCredentialAssertion: NSObject, ASAuthorizationCredential {
    public let rawAuthenticatorData: Data
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let signature: Data
    public let userID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .platform
    public let prf: ASAuthorizationPublicKeyCredentialPRFAssertionOutput?
    public let largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput?
    init(authData: Data, clientData: Data, id: Data, signature: Data, userID: Data, prf: ASAuthorizationPublicKeyCredentialPRFAssertionOutput? = nil,
         largeBlob: ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput? = nil) {
        rawAuthenticatorData = authData; rawClientDataJSON = clientData; credentialID = id; self.signature = signature; self.userID = userID
        self.prf = prf; self.largeBlob = largeBlob
    }
}

// MARK: - Store + WebAuthn encoding

struct _ASPasskey {
    var credentialID: Data, userID: Data, name: String, privateKey: Data, created: Double, rp: String
    /// the PRF (hmac-secret) secret and the largeBlob, see Extensions.swift; security keys: discoverable or not
    var prfSecret: Data? = nil, largeBlob: Data? = nil, discoverable = true
}

enum _ASPasskeys {
    /// passkeys are in AppleAccount/Passkeys; the virtual security key's credentials in Library/isim/SecurityKey
    static func path(_ rp: String, securityKey: Bool = false) -> String {
        let dir = securityKey ? _ASData.securityKeyDir : _ASData.dir("Passkeys")
        return (dir as NSString).appendingPathComponent(rp.replacingOccurrences(of: "/", with: "_") + ".json")
    }
    static func load(_ rp: String, securityKey: Bool = false) -> [_ASPasskey] {
        guard let arr = _ASData.readJSON(path(rp, securityKey: securityKey)) as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let id = (d["credentialID"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let u = (d["userID"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let k = (d["privateKey"] as? String).flatMap({ Data(base64Encoded: $0) }) else { return nil }
            return _ASPasskey(credentialID: id, userID: u, name: d["name"] as? String ?? "", privateKey: k, created: d["created"] as? Double ?? 0, rp: rp,
                              prfSecret: (d["prfSecret"] as? String).flatMap { Data(base64Encoded: $0) },
                              largeBlob: (d["largeBlob"] as? String).flatMap { Data(base64Encoded: $0) }, discoverable: d["discoverable"] as? Bool ?? true)
        }
    }
    static func store(_ keys: [_ASPasskey], _ rp: String, securityKey: Bool = false) {
        _ASData.writeJSON(keys.map { k in
            var d: [String: Any] = ["credentialID": k.credentialID.base64EncodedString(), "userID": k.userID.base64EncodedString(), "name": k.name,
                                    "privateKey": k.privateKey.base64EncodedString(), "created": k.created, "relyingParty": rp,
                                    "note": securityKey ? "isim local simulation: a virtual security key's credential (unencrypted P-256 key)"
                                                        : "isim local simulation: unencrypted P-256 key, not synced"]
            if let p = k.prfSecret { d["prfSecret"] = p.base64EncodedString() }
            if let b = k.largeBlob { d["largeBlob"] = b.base64EncodedString() }
            if securityKey { d["discoverable"] = k.discoverable }
            return d
        }, path(rp, securityKey: securityKey))
    }

    static func clientData(_ type: String, _ challenge: Data, _ rp: String) -> Data {
        // field order like browsers/iOS emit it; servers parse it as JSON
        Data("{\"type\":\"\(type)\",\"challenge\":\"\(_ASData.base64url(challenge))\",\"origin\":\"https://\(rp)\"}".utf8)
    }
    static func authenticatorData(_ rp: String, flags: UInt8, attested: (Data, P256.Signing.PublicKey)?) -> Data {
        var d = Data(SHA256.hash(data: Data(rp.utf8)))
        d.append(flags)
        d.append(contentsOf: [0, 0, 0, 0])                       // signCount 0, like iCloud Keychain passkeys
        if let (id, pub) = attested {
            d.append(Data(count: 16))                              // AAGUID: all zero
            d.append(contentsOf: [UInt8(id.count >> 8), UInt8(id.count & 0xff)])
            d.append(id)
            d.append(coseKey(pub))
        }
        return d
    }
    /// COSE_Key {1: 2 (EC2), 3: -7 (ES256), -1: 1 (P-256), -2: x, -3: y}
    static func coseKey(_ pub: P256.Signing.PublicKey) -> Data {
        let raw = pub.rawRepresentation
        return _CBOR.map([(_CBOR.int(1), _CBOR.int(2)), (_CBOR.int(3), _CBOR.int(-7)), (_CBOR.int(-1), _CBOR.int(1)),
                          (_CBOR.int(-2), _CBOR.bytes(raw.prefix(32))), (_CBOR.int(-3), _CBOR.bytes(raw.suffix(32)))])
    }

    /// a new credential and its attestation object (format "none")
    static func create(_ rp: String, userID: Data, name: String, challenge: Data, securityKey: Bool = false, discoverable: Bool = true)
        -> (key: _ASPasskey, attestation: Data, clientData: Data) {
        let key = P256.Signing.PrivateKey()
        let id = Data(_ASData.random(securityKey ? 32 : 20))
        let k = _ASPasskey(credentialID: id, userID: userID, name: name, privateKey: key.rawRepresentation, created: Date().timeIntervalSince1970, rp: rp,
                           prfSecret: Data(_ASData.random(32)), discoverable: discoverable)
        var keys = load(rp, securityKey: securityKey).filter { $0.userID != userID }   // one credential per account and site
        keys.append(k)
        store(keys, rp, securityKey: securityKey)
        let auth = authenticatorData(rp, flags: 0x01 | 0x04 | 0x40, attested: (id, key.publicKey))   // UP, UV, AT
        let att = _CBOR.map([(_CBOR.text("fmt"), _CBOR.text("none")), (_CBOR.text("attStmt"), _CBOR.map([])), (_CBOR.text("authData"), _CBOR.bytes(auth))])
        return (k, att, clientData("webauthn.create", challenge, rp))
    }
    /// a signature over authData || SHA-256(clientDataJSON); rpIDHash is the hash of `hashedRP` (an AppID for the appid extension)
    static func sign(_ k: _ASPasskey, challenge: Data, rp: String, hashedRP: String) throws -> (authData: Data, clientData: Data, signature: Data) {
        let key = try P256.Signing.PrivateKey(rawRepresentation: k.privateKey)
        let auth = authenticatorData(hashedRP, flags: 0x01 | 0x04, attested: nil)
        let cd = clientData("webauthn.get", challenge, rp)
        var signed = auth; signed.append(Data(SHA256.hash(data: cd)))
        return (auth, cd, try key.signature(for: signed).derRepresentation)
    }
    static func excluded(_ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) -> Bool {
        let saved = Set(load(r.relyingPartyIdentifier).map(\.credentialID))
        return r.excludedCredentials.contains { saved.contains($0.credentialID) }
    }

    static func register(_ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        let (k, att, cd) = create(r.relyingPartyIdentifier, userID: r.userID, name: r.name, challenge: r.challenge)
        NSLog("isim AuthenticationServices: passkey saved for %@ (%@) in the device data (local simulation, not synced)", r.name, r.relyingPartyIdentifier)
        return ASAuthorizationPlatformPublicKeyCredentialRegistration(attestation: att, clientData: cd, id: k.credentialID,
                                                                      prf: _ASExtensions.registration(r.prf, k.prfSecret ?? Data()),
                                                                      largeBlob: r.largeBlob == nil ? nil : .supported)
    }
    static func assert(_ r: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest, _ k: _ASPasskey) throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        let (auth, cd, sig) = try sign(k, challenge: r.challenge, rp: r.relyingPartyIdentifier, hashedRP: r.relyingPartyIdentifier)
        var blob: ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput?
        switch r.largeBlob?.operation {
        case .read?: blob = .read(data: k.largeBlob)
        case .write(let d)?:
            let ok = d.count <= _ASExtensions.largeBlobLimit
            if ok {
                var keys = load(r.relyingPartyIdentifier)
                if let i = keys.firstIndex(where: { $0.credentialID == k.credentialID }) { keys[i].largeBlob = d; store(keys, r.relyingPartyIdentifier) }
            }
            blob = .write(success: ok)
        case nil: break
        }
        return ASAuthorizationPlatformPublicKeyCredentialAssertion(authData: auth, clientData: cd, id: k.credentialID, signature: sig, userID: k.userID,
                                                                   prf: _ASExtensions.assertion(r.prf, k), largeBlob: blob)
    }

    // MARK: security keys
    static func excluded(_ r: ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest) -> Bool {
        let saved = Set(load(r.relyingPartyIdentifier, securityKey: true).map(\.credentialID))
        return r.excludedCredentials.contains { saved.contains($0.credentialID) }
    }
    static func register(_ r: ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest) -> ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
        let (k, att, cd) = create(r.relyingPartyIdentifier, userID: r.userID, name: r.name, challenge: r.challenge, securityKey: true,
                                  discoverable: r.residentKeyPreference != .discouraged)
        NSLog("isim AuthenticationServices: security key credential for %@ (%@) on the virtual security key (local simulation)", r.name, r.relyingPartyIdentifier)
        return ASAuthorizationSecurityKeyPublicKeyCredentialRegistration(attestation: att, clientData: cd, id: k.credentialID,
                                                                         prf: _ASExtensions.registration(r.prf, k.prfSecret ?? Data()))
    }
    /// the credentials the request can use: the allowed ones (under the relying party or its AppID), else the discoverable ones
    static func securityKeyCredentials(_ r: ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest) -> [(_ASPasskey, appID: Bool)] {
        let own = load(r.relyingPartyIdentifier, securityKey: true).map { ($0, appID: false) }
        let legacy = r.appID.map { load($0, securityKey: true).map { ($0, appID: true) } } ?? []
        if r.allowedCredentials.isEmpty { return own.filter { $0.0.discoverable } }
        let allowed = Set(r.allowedCredentials.map(\.credentialID))
        return (own + legacy).filter { allowed.contains($0.0.credentialID) }
    }
    static func assert(_ r: ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest, _ k: _ASPasskey, appID: Bool) throws -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
        let (auth, cd, sig) = try sign(k, challenge: r.challenge, rp: r.relyingPartyIdentifier, hashedRP: appID ? (r.appID ?? r.relyingPartyIdentifier) : r.relyingPartyIdentifier)
        return ASAuthorizationSecurityKeyPublicKeyCredentialAssertion(authData: auth, clientData: cd, id: k.credentialID, signature: sig, userID: k.userID,
                                                                      appID: appID, prf: _ASExtensions.assertion(r.prf, k))
    }
}

/// the CBOR subset WebAuthn needs (canonical lengths)
enum _CBOR {
    static func head(_ major: UInt8, _ n: UInt64) -> Data {
        let m = major << 5
        switch n {
        case 0..<24: return Data([m | UInt8(n)])
        case 24..<256: return Data([m | 24, UInt8(n)])
        case 256..<65536: return Data([m | 25, UInt8(n >> 8), UInt8(n & 0xff)])
        default: return Data([m | 26] + (0..<4).reversed().map { UInt8((n >> (8 * UInt64($0))) & 0xff) })
        }
    }
    static func int(_ v: Int) -> Data { v >= 0 ? head(0, UInt64(v)) : head(1, UInt64(-1 - v)) }
    static func bytes(_ d: Data) -> Data { head(2, UInt64(d.count)) + d }
    static func text(_ s: String) -> Data { let u = Data(s.utf8); return head(3, UInt64(u.count)) + u }
    static func map(_ pairs: [(Data, Data)]) -> Data {
        var d = head(5, UInt64(pairs.count))
        for (k, v) in pairs { d.append(k); d.append(v) }
        return d
    }
}
