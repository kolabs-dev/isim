// isim DeviceCheck (adapted: local, no Apple servers). Like a device, isSupported is true (ISIM_APP_ATTEST=0 makes
// it false, like the Simulator).
//
// DCDevice tokens: an opaque, signed token for this simulated device and app (an HMAC with the device data's
// DeviceCheck key). Apple's DeviceCheck server is played by `isim devicecheck query|update|validate TOKEN`, which keeps
// the two bits per device and app in the device data.
//
// App Attest, in Apple's formats:
//   - generateKey: a P-256 key in isim's simulated Secure Enclave; the key id is base64(SHA-256(public key)).
//   - attestKey: a CBOR attestation object {fmt: "apple-appattest", attStmt: {x5c: [credCert, intermediate], receipt},
//     authData}. authData = SHA-256(TEAMID.bundleID) ‖ flags ‖ counter 0 ‖ AAGUID ("appattestdevelop", or
//     "appattest" + 7 zero bytes for the production environment entitlement) ‖ credential id (the key id's bytes) ‖ the
//     COSE public key. credCert certifies the key and carries the nonce SHA-256(authData ‖ clientDataHash) in extension
//     1.2.840.113635.100.8.2, like Apple's. The chain ends at this device data's "isim App Attest Root CA" (not Apple's
//     root: a server checking Apple's root rejects it; for testing, trust `isim appattest root`). The receipt is an
//     opaque local value (Apple's receipt is for its fraud-metric server).
//   - generateAssertion: CBOR {signature, authenticatorData}: authenticatorData = SHA-256(app id) ‖ flags ‖ the key's
//     counter (incremented), signature = ECDSA P-256 (DER) over SHA-256(nonce), nonce = SHA-256(authenticatorData ‖
//     clientDataHash) — what a server verifies with the attested key.
import Foundation
import CryptoKit
@_spi(isim) import Security

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
    public var errorDescription: String? {
        switch code {
        case .featureUnsupported: return "DeviceCheck and App Attest are not supported (ISIM_APP_ATTEST=0)."
        case .invalidKey: return "The key is not valid."
        case .invalidInput: return "The input is not valid."
        default: return "DeviceCheck error \(code.rawValue)."
        }
    }
    public static var unknownSystemFailure: Code { .unknownSystemFailure }
    public static var featureUnsupported: Code { .featureUnsupported }
    public static var invalidInput: Code { .invalidInput }
    public static var invalidKey: Code { .invalidKey }
    public static var serverUnavailable: Code { .serverUnavailable }
}
public func ~= (code: DCError.Code, error: Error) -> Bool { (error as? DCError)?.code == code }

// MARK: - Device data

enum _DC {
    static var supported: Bool { ProcessInfo.processInfo.environment["ISIM_APP_ATTEST"] != "0" }
    static var dir: URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        let d = URL(fileURLWithPath: data).appendingPathComponent("Library/isim/DeviceCheck", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "unknown" }
    static var entitlements: [String: Any] {
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        guard let d = FileManager.default.contents(atPath: path),
              let p = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any] else { return [:] }
        return p
    }
    /// TEAMID.bundleID: the application-identifier entitlement, else the team identifier entitlement and the bundle id
    static var appID: String {
        let e = entitlements
        if let a = e["application-identifier"] as? String, a.contains(".") { return a }
        let team = (e["com.apple.developer.team-identifier"] as? String) ?? "ISIMTEAM00"
        return "\(team).\(bundleID)"
    }
    static var production: Bool { (entitlements["com.apple.developer.devicecheck.appattest-environment"] as? String) == "production" }
    /// a random secret made on first use, kept in the device data (0600)
    static func secret(_ name: String, _ n: Int = 32) -> [UInt8] {
        let url = dir.appendingPathComponent(name)
        if let d = try? Data(contentsOf: url), d.count == n { return [UInt8](d) }
        var k = [UInt8](repeating: 0, count: n); arc4random_buf(&k, n)
        FileManager.default.createFile(atPath: url.path, contents: Data(k), attributes: [.posixPermissions: 0o600])
        return k
    }
    static func json(_ name: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent(name)))) as? [String: Any] ?? [:]
    }
    static func save(_ name: String, _ obj: [String: Any]) {
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) { try? d.write(to: dir.appendingPathComponent(name), options: .atomic) }
    }
}

// MARK: - DER (X.509) and CBOR

enum _DER {
    static func tlv(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] {
        var len: [UInt8]
        if body.count < 0x80 { len = [UInt8(body.count)] }
        else { var n = body.count; var b: [UInt8] = []; while n > 0 { b.insert(UInt8(n & 0xff), at: 0); n >>= 8 }; len = [0x80 | UInt8(b.count)] + b }
        return [tag] + len + body
    }
    static func seq(_ parts: [[UInt8]]) -> [UInt8] { tlv(0x30, parts.flatMap { $0 }) }
    static func set(_ parts: [[UInt8]]) -> [UInt8] { tlv(0x31, parts.flatMap { $0 }) }
    static func int(_ bytes: [UInt8]) -> [UInt8] {
        var b = Array(bytes.drop { $0 == 0 }); if b.isEmpty { b = [0] }
        if b[0] & 0x80 != 0 { b.insert(0, at: 0) }
        return tlv(0x02, b)
    }
    static func oid(_ s: String) -> [UInt8] {
        let n = s.split(separator: ".").map { UInt64($0)! }
        var out: [UInt8] = [UInt8(n[0] * 40 + n[1])]
        for v in n.dropFirst(2) {
            var chunk: [UInt8] = [UInt8(v & 0x7f)], x = v >> 7
            while x > 0 { chunk.insert(UInt8(x & 0x7f) | 0x80, at: 0); x >>= 7 }
            out += chunk
        }
        return tlv(0x06, out)
    }
    static func utf8(_ s: String) -> [UInt8] { tlv(0x0c, Array(s.utf8)) }
    static func octets(_ b: [UInt8]) -> [UInt8] { tlv(0x04, b) }
    static func bits(_ b: [UInt8]) -> [UInt8] { tlv(0x03, [0] + b) }
    static func explicit(_ n: UInt8, _ b: [UInt8]) -> [UInt8] { tlv(0xa0 | n, b) }
    static func bool(_ v: Bool) -> [UInt8] { tlv(0x01, [v ? 0xff : 0]) }
    static func time(_ d: Date) -> [UInt8] {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmmss'Z'"
        return tlv(0x18, Array(f.string(from: d).utf8))                                // GeneralizedTime
    }
    static func name(_ cn: String, _ org: String) -> [UInt8] {
        seq([set([seq([oid("2.5.4.3"), utf8(cn)])]), set([seq([oid("2.5.4.10"), utf8(org)])])])
    }
    static let ecdsaSHA256 = seq([oid("1.2.840.10045.4.3.2")])
    /// an X.509 v3 certificate signed with `signer` (ECDSA P-256 with SHA-256)
    static func certificate(serial: [UInt8], issuer: [UInt8], subject: [UInt8], key: P256.Signing.PublicKey, extensions: [[UInt8]],
                            notBefore: Date, notAfter: Date, signer: P256.Signing.PrivateKey) throws -> [UInt8] {
        let tbs = seq([explicit(0, int([2])), int(serial), ecdsaSHA256, issuer, seq([time(notBefore), time(notAfter)]), subject,
                       Array(key.derRepresentation), explicit(3, seq(extensions))])
        let sig = try signer.signature(for: Data(tbs))
        return seq([tbs, ecdsaSHA256, bits(Array(sig.derRepresentation))])
    }
    static func ext(_ id: String, critical: Bool = false, _ value: [UInt8]) -> [UInt8] {
        seq([oid(id)] + (critical ? [bool(true)] : []) + [octets(value)])
    }
}

/// CBOR (RFC 8949): what App Attest's objects need
indirect enum _CBOR {
    case uint(UInt64), negative(Int64), bytes([UInt8]), text(String), array([_CBOR]), map([(_CBOR, _CBOR)])
    var encoded: [UInt8] {
        func head(_ major: UInt8, _ n: UInt64) -> [UInt8] {
            switch n {
            case 0..<24: return [major << 5 | UInt8(n)]
            case 24..<256: return [major << 5 | 24, UInt8(n)]
            case 256..<65536: return [major << 5 | 25, UInt8(n >> 8), UInt8(n & 0xff)]
            default:
                let first: UInt8 = major << 5 | 26
                let b0 = UInt8((n >> 24) & 0xff), b1 = UInt8((n >> 16) & 0xff), b2 = UInt8((n >> 8) & 0xff), b3 = UInt8(n & 0xff)
                return [first, b0, b1, b2, b3]
            }
        }
        switch self {
        case .uint(let n): return head(0, n)
        case .negative(let n): return head(1, UInt64(-1 - n))
        case .bytes(let b): return head(2, UInt64(b.count)) + b
        case .text(let s): let b = Array(s.utf8); return head(3, UInt64(b.count)) + b
        case .array(let a): return head(4, UInt64(a.count)) + a.flatMap { $0.encoded }
        case .map(let m): return head(5, UInt64(m.count)) + m.flatMap { $0.0.encoded + $0.1.encoded }
        }
    }
}

// MARK: - App Attest's certificate authority (per device data)

enum _AppAttestCA {
    struct CA { let rootKey: P256.Signing.PrivateKey; let root: [UInt8]; let caKey: P256.Signing.PrivateKey; let ca: [UInt8] }
    /// the root and the intermediate, made on first use and kept in the device data (AppAttestCA.json; the root also as
    /// AppAttestRootCA.pem for servers)
    static func load() throws -> CA {
        let j = _DC.json("AppAttestCA.json")
        if let rk = j["rootKey"] as? String, let r = j["root"] as? String, let ck = j["caKey"] as? String, let c = j["ca"] as? String,
           let rkd = Data(base64Encoded: rk), let rd = Data(base64Encoded: r), let ckd = Data(base64Encoded: ck), let cd = Data(base64Encoded: c) {
            return CA(rootKey: try P256.Signing.PrivateKey(rawRepresentation: rkd), root: [UInt8](rd),
                      caKey: try P256.Signing.PrivateKey(rawRepresentation: ckd), ca: [UInt8](cd))
        }
        let rootKey = P256.Signing.PrivateKey(), caKey = P256.Signing.PrivateKey()
        let rootName = _DER.name("isim App Attest Root CA", "isim (local simulation, not Apple)")
        let caName = _DER.name("isim App Attest CA 1", "isim (local simulation, not Apple)")
        let now = Date(timeIntervalSinceNow: -86400), later = Date(timeIntervalSinceNow: 20 * 365 * 86400)
        let caExt = [_DER.ext("2.5.29.19", critical: true, _DER.seq([_DER.bool(true)])),
                     _DER.ext("2.5.29.15", critical: true, _DER.tlv(0x03, [0x01, 0x06]))]          // keyCertSign, cRLSign
        let root = try _DER.certificate(serial: [1], issuer: rootName, subject: rootName, key: rootKey.publicKey, extensions: caExt,
                                        notBefore: now, notAfter: later, signer: rootKey)
        let ca = try _DER.certificate(serial: [2], issuer: rootName, subject: caName, key: caKey.publicKey, extensions: caExt,
                                      notBefore: now, notAfter: later, signer: rootKey)
        _DC.save("AppAttestCA.json", ["rootKey": rootKey.rawRepresentation.base64EncodedString(), "root": Data(root).base64EncodedString(),
                                      "caKey": caKey.rawRepresentation.base64EncodedString(), "ca": Data(ca).base64EncodedString()])
        let b64 = Data(root).base64EncodedString(options: [.lineLength64Characters])
        try? "-----BEGIN CERTIFICATE-----\n\(b64)\n-----END CERTIFICATE-----\n".write(to: _DC.dir.appendingPathComponent("AppAttestRootCA.pem"), atomically: true, encoding: .utf8)
        return CA(rootKey: rootKey, root: root, caKey: caKey, ca: ca)
    }
}

// MARK: - DCDevice

open class DCDevice: NSObject, @unchecked Sendable {
    public static let current = DCDevice()
    open var isSupported: Bool { _DC.supported }
    /// an opaque token for this device and app: base64 of {"v":1,"device","bundle","issued"} JSON, "." and its HMAC-SHA256
    /// with the device data's DeviceCheck key (what `isim devicecheck` validates)
    func makeToken() throws -> Data {
        guard _DC.supported else { throw DCError(.featureUnsupported) }
        let device = Data(_DC.secret("device-id", 16)).map { String(format: "%02x", $0) }.joined()
        let payload: [String: Any] = ["v": 1, "device": device, "bundle": _DC.bundleID, "issued": Int(Date().timeIntervalSince1970)]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let mac = HMAC<SHA256>.authenticationCode(for: body, using: SymmetricKey(data: _DC.secret("token.key")))
        return Data((body.base64EncodedString() + "." + Data(mac).base64EncodedString()).utf8)
    }
    open func generateToken(completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async {
            do { completionHandler(try self.makeToken(), nil) } catch { completionHandler(nil, error) }
        }
    }
    open func generateToken() async throws -> Data { try makeToken() }
}

// MARK: - DCAppAttestService

open class DCAppAttestService: NSObject, @unchecked Sendable {
    public static let shared = DCAppAttestService()
    open var isSupported: Bool { _DC.supported }
    private let lock = NSLock()

    /// this app's keys: key id -> {key: Secure Enclave data representation, counter, attested}
    private var keysFile: String { "AppAttest-\(_DC.bundleID).json" }

    func newKey() throws -> String {
        guard _DC.supported else { throw DCError(.featureUnsupported) }
        let key = try SecureEnclave.P256.Signing.PrivateKey()
        let id = Data(SHA256.hash(data: key.publicKey.x963Representation)).base64EncodedString()
        lock.lock(); defer { lock.unlock() }
        var keys = _DC.json(keysFile)
        keys[id] = ["key": key.dataRepresentation.base64EncodedString(), "counter": 0, "attested": false]
        _DC.save(keysFile, keys)
        return id
    }
    private func key(_ id: String) throws -> (SecureEnclave.P256.Signing.PrivateKey, [String: Any]) {
        guard _DC.supported else { throw DCError(.featureUnsupported) }
        guard let entry = _DC.json(keysFile)[id] as? [String: Any], let b = entry["key"] as? String, let d = Data(base64Encoded: b),
              let k = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: d) else { throw DCError(.invalidKey) }
        return (k, entry)
    }
    private func update(_ id: String, _ change: (inout [String: Any]) -> Void) {
        var keys = _DC.json(keysFile)
        if var e = keys[id] as? [String: Any] { change(&e); keys[id] = e; _DC.save(keysFile, keys) }
    }
    static func authData(counter: UInt32, credential: (id: [UInt8], key: P256.Signing.PublicKey)?) -> [UInt8] {
        var a = Array(SHA256.hash(data: Data(_DC.appID.utf8)))
        a.append(credential == nil ? 0x00 : 0x40)                                         // AT: attested credential data
        a += [UInt8(counter >> 24), UInt8(counter >> 16 & 0xff), UInt8(counter >> 8 & 0xff), UInt8(counter & 0xff)]
        if let c = credential {
            a += _DC.production ? Array("appattest".utf8) + [UInt8](repeating: 0, count: 7) : Array("appattestdevelop".utf8)
            a += [UInt8(c.id.count >> 8), UInt8(c.id.count & 0xff)] + c.id
            let raw = Array(c.key.rawRepresentation)
            a += _CBOR.map([(.uint(1), .uint(2)), (.uint(3), .negative(-7)), (.negative(-1), .uint(1)),
                            (.negative(-2), .bytes(Array(raw.prefix(32)))), (.negative(-3), .bytes(Array(raw.suffix(32))))]).encoded
        }
        return a
    }
    func attest(_ id: String, _ clientDataHash: Data) throws -> Data {
        guard clientDataHash.count == 32 else { throw DCError(.invalidInput) }
        lock.lock(); defer { lock.unlock() }
        let (key, entry) = try key(id)
        if entry["attested"] as? Bool == true { throw DCError(.invalidKey) }          // a key is attested once
        guard let keyID = Data(base64Encoded: id) else { throw DCError(.invalidKey) }
        let ca = try _AppAttestCA.load()
        let auth = Self.authData(counter: 0, credential: ([UInt8](keyID), key.publicKey))
        let nonce = Array(SHA256.hash(data: Data(auth) + clientDataHash))
        let nonceExt = _DER.seq([_DER.explicit(1, _DER.octets(nonce))])
        let leafExt = [_DER.ext("2.5.29.19", critical: true, _DER.seq([])), _DER.ext("2.5.29.15", critical: true, _DER.tlv(0x03, [0x07, 0x80])),
                       _DER.ext("1.2.840.113635.100.8.2", nonceExt)]
        var serial = [UInt8](repeating: 0, count: 8); arc4random_buf(&serial, 8); serial[0] &= 0x7f
        let leaf = try _DER.certificate(serial: serial, issuer: _DER.name("isim App Attest CA 1", "isim (local simulation, not Apple)"),
                                        subject: _DER.name(keyID.map { String(format: "%02x", $0) }.joined(), "isim App Attest"),
                                        key: key.publicKey, extensions: leafExt, notBefore: Date(timeIntervalSinceNow: -60),
                                        notAfter: Date(timeIntervalSinceNow: 90 * 86400), signer: ca.caKey)
        let receipt = Array("isim-local-appattest-receipt:\(_DC.appID):\(id)".utf8)
        let obj = _CBOR.map([(.text("fmt"), .text("apple-appattest")),
                             (.text("attStmt"), .map([(.text("x5c"), .array([.bytes(leaf), .bytes(ca.ca)])), (.text("receipt"), .bytes(receipt))])),
                             (.text("authData"), .bytes(auth))])
        update(id) { $0["attested"] = true }
        return Data(obj.encoded)
    }
    func assert(_ id: String, _ clientDataHash: Data) throws -> Data {
        guard clientDataHash.count == 32 else { throw DCError(.invalidInput) }
        lock.lock(); defer { lock.unlock() }
        let (key, entry) = try key(id)
        guard entry["attested"] as? Bool == true else { throw DCError(.invalidKey) }   // attest first
        let counter = UInt32((entry["counter"] as? Int) ?? 0) + 1
        let auth = Self.authData(counter: counter, credential: nil)
        let nonce = SHA256.hash(data: Data(auth) + clientDataHash)
        let sig = try key.signature(for: SHA256.hash(data: Data(nonce)))
        update(id) { $0["counter"] = Int(counter) }
        return Data(_CBOR.map([(.text("signature"), .bytes(Array(sig.derRepresentation))), (.text("authenticatorData"), .bytes(auth))]).encoded)
    }

    open func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void) {
        DispatchQueue.global().async { do { completionHandler(try self.newKey(), nil) } catch { completionHandler(nil, error) } }
    }
    open func generateKey() async throws -> String { try newKey() }
    open func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async { do { completionHandler(try self.attest(keyId, clientDataHash), nil) } catch { completionHandler(nil, error) } }
    }
    open func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data { try attest(keyId, clientDataHash) }
    open func generateAssertion(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        DispatchQueue.global().async { do { completionHandler(try self.assert(keyId, clientDataHash), nil) } catch { completionHandler(nil, error) } }
    }
    open func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data { try assert(keyId, clientDataHash) }
}
