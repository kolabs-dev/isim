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

open class ASAuthorizationPlatformPublicKeyCredentialDescriptor: NSObject {
    open var credentialID: Data
    public init(credentialID: Data) { self.credentialID = credentialID }
}

open class ASAuthorizationPlatformPublicKeyCredentialProvider: NSObject, ASAuthorizationProvider {
    public let relyingPartyIdentifier: String
    public init(relyingPartyIdentifier: String) { self.relyingPartyIdentifier = relyingPartyIdentifier }
    open func createCredentialRegistrationRequest(challenge: Data, name: String, userID: Data) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge, name: name, userID: userID)
    }
    open func createCredentialAssertionRequest(challenge: Data) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        ASAuthorizationPlatformPublicKeyCredentialAssertionRequest(provider: self, rp: relyingPartyIdentifier, challenge: challenge)
    }
}

open class ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var name: String
    open var displayName: String?
    open var userID: Data
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    open var attestationPreference: ASAuthorizationPublicKeyCredentialAttestationKind = .none
    open var excludedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data, name: String, userID: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge; self.name = name; self.userID = userID
        super.init(provider: provider)
    }
}

open class ASAuthorizationPlatformPublicKeyCredentialAssertionRequest: ASAuthorizationRequest {
    open var relyingPartyIdentifier: String
    open var challenge: Data
    open var allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
    open var userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .preferred
    init(provider: ASAuthorizationProvider, rp: String, challenge: Data) {
        relyingPartyIdentifier = rp; self.challenge = challenge
        super.init(provider: provider)
    }
}

open class ASAuthorizationPlatformPublicKeyCredentialRegistration: NSObject, ASAuthorizationCredential {
    public let rawAttestationObject: Data?
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .platform
    init(attestation: Data, clientData: Data, id: Data) { rawAttestationObject = attestation; rawClientDataJSON = clientData; credentialID = id }
}

open class ASAuthorizationPlatformPublicKeyCredentialAssertion: NSObject, ASAuthorizationCredential {
    public let rawAuthenticatorData: Data
    public let rawClientDataJSON: Data
    public let credentialID: Data
    public let signature: Data
    public let userID: Data
    public let attachment: ASAuthorizationPublicKeyCredentialAttachment = .platform
    init(authData: Data, clientData: Data, id: Data, signature: Data, userID: Data) {
        rawAuthenticatorData = authData; rawClientDataJSON = clientData; credentialID = id; self.signature = signature; self.userID = userID
    }
}

// MARK: - Store + WebAuthn encoding

struct _ASPasskey {
    var credentialID: Data, userID: Data, name: String, privateKey: Data, created: Double, rp: String
}

enum _ASPasskeys {
    static func path(_ rp: String) -> String {
        (_ASData.dir("Passkeys") as NSString).appendingPathComponent(rp.replacingOccurrences(of: "/", with: "_") + ".json")
    }
    static func load(_ rp: String) -> [_ASPasskey] {
        guard let arr = _ASData.readJSON(path(rp)) as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let id = (d["credentialID"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let u = (d["userID"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let k = (d["privateKey"] as? String).flatMap({ Data(base64Encoded: $0) }) else { return nil }
            return _ASPasskey(credentialID: id, userID: u, name: d["name"] as? String ?? "", privateKey: k, created: d["created"] as? Double ?? 0, rp: rp)
        }
    }
    static func store(_ keys: [_ASPasskey], _ rp: String) {
        _ASData.writeJSON(keys.map { ["credentialID": $0.credentialID.base64EncodedString(), "userID": $0.userID.base64EncodedString(), "name": $0.name,
                                      "privateKey": $0.privateKey.base64EncodedString(), "created": $0.created, "relyingParty": rp,
                                      "note": "isim local simulation: unencrypted P-256 key, not synced"] as [String: Any] }, path(rp))
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

    static func register(_ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        let key = P256.Signing.PrivateKey()
        let id = Data(_ASData.random(20))
        var keys = load(r.relyingPartyIdentifier).filter { $0.userID != r.userID }   // one passkey per account and site
        keys.append(_ASPasskey(credentialID: id, userID: r.userID, name: r.name, privateKey: key.rawRepresentation, created: Date().timeIntervalSince1970, rp: r.relyingPartyIdentifier))
        store(keys, r.relyingPartyIdentifier)
        let auth = authenticatorData(r.relyingPartyIdentifier, flags: 0x01 | 0x04 | 0x40, attested: (id, key.publicKey))   // UP, UV, AT
        let att = _CBOR.map([(_CBOR.text("fmt"), _CBOR.text("none")), (_CBOR.text("attStmt"), _CBOR.map([])), (_CBOR.text("authData"), _CBOR.bytes(auth))])
        NSLog("isim AuthenticationServices: passkey saved for %@ (%@) in the device data (local simulation, not synced)", r.name, r.relyingPartyIdentifier)
        return ASAuthorizationPlatformPublicKeyCredentialRegistration(attestation: att, clientData: clientData("webauthn.create", r.challenge, r.relyingPartyIdentifier), id: id)
    }
    static func assert(_ r: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest, _ k: _ASPasskey) throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        let key = try P256.Signing.PrivateKey(rawRepresentation: k.privateKey)
        let auth = authenticatorData(r.relyingPartyIdentifier, flags: 0x01 | 0x04, attested: nil)
        let cd = clientData("webauthn.get", r.challenge, r.relyingPartyIdentifier)
        var signed = auth; signed.append(Data(SHA256.hash(data: cd)))
        let sig = try key.signature(for: signed).derRepresentation
        return ASAuthorizationPlatformPublicKeyCredentialAssertion(authData: auth, clientData: cd, id: k.credentialID, signature: sig, userID: k.userID)
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
