// isim StoreKit signing, like Xcode's local StoreKit testing: each isim device has one P-256 key and a self-signed
// "isim StoreKit Testing" certificate (in the device data, $ISIM_DATA/Library/isim/StoreKit/). Transactions, renewal
// info and the app transaction are ES256 JWS values with that certificate in their x5c header, and the app receipt is a
// PKCS #7 SignedData container signed with it. Nothing here is signed by Apple: like Xcode's StoreKit Test certificate,
// `isim storekit certificate` exports the certificate so server code can validate isim's local values against it.
//
// The same directory holds the subscription offers key (offer-key.pem) that promotional offer signatures are checked
// against (`isim storekit offer-key` prints its key ID and private key for the server that signs offers).
import UIKit
internal import CryptoKit

// MARK: - DER

enum _SKDER {
    static func len(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        if n < 0x100 { return [0x81, UInt8(n)] }
        if n < 0x10000 { return [0x82, UInt8(n >> 8), UInt8(n & 0xff)] }
        return [0x83, UInt8(n >> 16), UInt8((n >> 8) & 0xff), UInt8(n & 0xff)]
    }
    static func tlv(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] { [tag] + len(body.count) + body }
    static func seq(_ items: [UInt8]...) -> [UInt8] { tlv(0x30, items.flatMap { $0 }) }
    static func seq(list items: [[UInt8]]) -> [UInt8] { tlv(0x30, items.flatMap { $0 }) }
    /// SET OF, in DER order (sorted encodings)
    static func set(_ items: [[UInt8]]) -> [UInt8] { tlv(0x31, items.sorted { $0.lexicographicallyPrecedes($1) }.flatMap { $0 }) }
    static func int(_ v: Int) -> [UInt8] {
        var b: [UInt8] = []
        var x = v
        repeat { b.insert(UInt8(truncatingIfNeeded: x), at: 0); x >>= 8 } while x != 0 && x != -1
        if v >= 0, b[0] & 0x80 != 0 { b.insert(0, at: 0) }
        if v < 0, b[0] & 0x80 == 0 { b.insert(0xff, at: 0) }
        return tlv(0x02, b)
    }
    /// a non-negative big-endian integer
    static func uint(_ bytes: [UInt8]) -> [UInt8] {
        var b = Array(bytes.drop { $0 == 0 })
        if b.isEmpty { b = [0] }
        if b[0] & 0x80 != 0 { b.insert(0, at: 0) }
        return tlv(0x02, b)
    }
    static func oid(_ s: String) -> [UInt8] {
        let parts = s.split(separator: ".").compactMap { UInt64($0) }
        var body: [UInt8] = [UInt8(parts[0] * 40 + parts[1])]
        for p in parts.dropFirst(2) {
            var chunk: [UInt8] = [UInt8(p & 0x7f)]
            var v = p >> 7
            while v > 0 { chunk.insert(UInt8(v & 0x7f) | 0x80, at: 0); v >>= 7 }
            body += chunk
        }
        return tlv(0x06, body)
    }
    static func utf8(_ s: String) -> [UInt8] { tlv(0x0c, Array(s.utf8)) }
    static func ia5(_ s: String) -> [UInt8] { tlv(0x16, Array(s.utf8)) }
    static func octet(_ b: [UInt8]) -> [UInt8] { tlv(0x04, b) }
    static func bits(_ b: [UInt8]) -> [UInt8] { tlv(0x03, [0] + b) }
    static func bool(_ v: Bool) -> [UInt8] { tlv(0x01, [v ? 0xff : 0]) }
    static func explicit(_ n: UInt8, _ body: [UInt8]) -> [UInt8] { tlv(0xa0 | n, body) }
    static func time(_ d: Date) -> [UInt8] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmmss'Z'"
        return tlv(0x18, Array(f.string(from: d).utf8))     // GeneralizedTime
    }

    /// reads the TLV at i: (tag, body range); advances i past it
    static func read(_ b: [UInt8], _ i: inout Int) -> (UInt8, Range<Int>)? {
        guard i + 2 <= b.count else { return nil }
        let tag = b[i]; var n = Int(b[i + 1]); i += 2
        if n & 0x80 != 0 {
            let k = n & 0x7f
            guard k >= 1, k <= 4, i + k <= b.count else { return nil }
            n = 0; for _ in 0..<k { n = n << 8 | Int(b[i]); i += 1 }
        }
        guard i + n <= b.count else { return nil }
        defer { i += n }
        return (tag, i..<(i + n))
    }
    /// the TLV at i, header included
    static func element(_ b: [UInt8], _ i: inout Int) -> [UInt8]? {
        let start = i
        guard read(b, &i) != nil else { return nil }
        return Array(b[start..<i])
    }
}

// MARK: - Base64 / dates

func _skBase64URL(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
func _skFromBase64URL(_ s: String) -> Data? {
    var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while t.count % 4 != 0 { t += "=" }
    return Data(base64Encoded: t)
}
func _skISODate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    return f.string(from: d)
}
func _skUUIDBytes(_ u: UUID) -> [UInt8] { withUnsafeBytes(of: u.uuid) { Array($0) } }
/// a UUID derived from a string (stable nonces for stable signed values)
func _skStableUUID(_ s: String) -> UUID {
    var b = Array(SHA256.hash(data: Data(s.utf8))).prefix(16).map { $0 }
    b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

// MARK: - The device's StoreKit testing identity

enum _SKSigning {
    /// $ISIM_DATA/Library/isim/StoreKit (the device's data, shared by every app, like Xcode's per-Mac certificate)
    static var directory: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/isim/StoreKit")
    }
    static let subject = "isim StoreKit Testing"

    struct Identity {
        let key: P256.Signing.PrivateKey
        let certificate: [UInt8]
        let issuer: [UInt8]         // the certificate's issuer Name (DER)
        let serial: [UInt8]         // its serial number (DER INTEGER)
    }

    /// loaded from the device data, or made (and saved) the first time any app needs it
    static let identity: Identity = {
        let dir = directory
        let keyPath = (dir as NSString).appendingPathComponent("testing-key.pem")
        let certPath = (dir as NSString).appendingPathComponent("testing-cert.der")
        if let id = load(keyPath, certPath) { return id }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        let key = P256.Signing.PrivateKey()
        let cert = makeCertificate(key)
        try? Data(key.pemRepresentation.utf8).write(to: URL(fileURLWithPath: keyPath), options: .atomic)
        try? Data(cert).write(to: URL(fileURLWithPath: certPath), options: .atomic)
        NSLog("isim StoreKit: made the device's StoreKit testing certificate (%@)", certPath)
        // another process may have saved its own at the same time: use what is on disk
        return load(keyPath, certPath) ?? Identity(key: key, certificate: cert, issuer: name(subject), serial: _SKDER.int(1))
    }()

    static func load(_ keyPath: String, _ certPath: String) -> Identity? {
        guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8), let key = try? P256.Signing.PrivateKey(pemRepresentation: pem),
              let der = FileManager.default.contents(atPath: certPath) else { return nil }
        let cert = [UInt8](der)
        // Certificate ::= SEQUENCE { tbsCertificate SEQUENCE { [0] version, serial, signature, issuer, ... }, ... }
        var i = 0
        guard let (_, c) = _SKDER.read(cert, &i) else { return nil }
        var j = c.lowerBound
        guard let (_, tbs) = _SKDER.read(cert, &j) else { return nil }
        var k = tbs.lowerBound
        if cert[k] == 0xa0 { _ = _SKDER.read(cert, &k) }
        guard let serial = _SKDER.element(cert, &k), _SKDER.read(cert, &k) != nil, let issuer = _SKDER.element(cert, &k) else { return nil }
        return Identity(key: key, certificate: cert, issuer: issuer, serial: serial)
    }

    static func name(_ cn: String) -> [UInt8] {
        _SKDER.seq(_SKDER.set([_SKDER.seq(_SKDER.oid("2.5.4.10"), _SKDER.utf8("isim"))]),
                   _SKDER.set([_SKDER.seq(_SKDER.oid("2.5.4.3"), _SKDER.utf8(cn))]))
    }
    static let ecdsaSHA256 = _SKDER.seq(_SKDER.oid("1.2.840.10045.4.3.2"))

    /// a self-signed X.509 v3 CA certificate for the key (10 years)
    static func makeCertificate(_ key: P256.Signing.PrivateKey) -> [UInt8] {
        let now = Date()
        let spki = _SKDER.seq(_SKDER.seq(_SKDER.oid("1.2.840.10045.2.1"), _SKDER.oid("1.2.840.10045.3.1.7")),
                              _SKDER.bits([UInt8](key.publicKey.x963Representation)))
        let ski = Array(Insecure.SHA1.hash(data: key.publicKey.x963Representation))
        let exts = _SKDER.seq(
            _SKDER.seq(_SKDER.oid("2.5.29.19"), _SKDER.bool(true), _SKDER.octet(_SKDER.seq(_SKDER.bool(true)))),              // basicConstraints CA
            _SKDER.seq(_SKDER.oid("2.5.29.15"), _SKDER.bool(true), _SKDER.octet(_SKDER.tlv(0x03, [0x01, 0x86]))),             // digitalSignature, keyCertSign, cRLSign
            _SKDER.seq(_SKDER.oid("2.5.29.14"), _SKDER.octet(_SKDER.octet(ski))))                                             // subjectKeyIdentifier
        var serial = [UInt8](repeating: 0, count: 8)
        for i in 0..<8 { serial[i] = UInt8.random(in: 0...255) }
        serial[0] &= 0x7f
        let tbs = _SKDER.seq(_SKDER.explicit(0, _SKDER.int(2)), _SKDER.uint(serial), ecdsaSHA256, name(subject),
                             _SKDER.seq(_SKDER.time(now.addingTimeInterval(-86400)), _SKDER.time(now.addingTimeInterval(3650 * 86400))),
                             name(subject), spki, _SKDER.explicit(3, exts))
        let sig = (try? key.signature(for: Data(tbs)).derRepresentation).map { [UInt8]($0) } ?? []
        return _SKDER.seq(tbs, ecdsaSHA256, _SKDER.bits(sig))
    }

    // MARK: JWS

    nonisolated(unsafe) static var jwsCache: [Data: String] = [:]
    static let lock = NSLock()

    /// a compact ES256 JWS of the payload, signed with the device's StoreKit testing key (x5c: its certificate).
    /// The same payload gives the same JWS (ECDSA signatures are randomized, so the first one is kept).
    static func jws(_ payload: Data) -> String {
        lock.lock(); defer { lock.unlock() }
        if let s = jwsCache[payload] { return s }
        let id = identity
        let header = #"{"alg":"ES256","typ":"JWT","x5c":[""# + Data(id.certificate).base64EncodedString() + #""]}"#
        let input = _skBase64URL(Data(header.utf8)) + "." + _skBase64URL(payload)
        let sig = (try? id.key.signature(for: Data(input.utf8)).rawRepresentation) ?? Data()
        let s = input + "." + _skBase64URL(sig)
        jwsCache[payload] = s
        return s
    }
    /// checks an ES256 JWS against a P-256 public key; returns its payload
    static func verifyJWS(_ jws: String, key: P256.Signing.PublicKey) -> Data? {
        let parts = jws.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let sig = _skFromBase64URL(parts[2]), let s = try? P256.Signing.ECDSASignature(rawRepresentation: sig),
              key.isValidSignature(s, for: Data((parts[0] + "." + parts[1]).utf8)) else { return nil }
        return _skFromBase64URL(parts[1])
    }
    static func json(_ d: [String: Any]) -> Data { (try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys])) ?? Data() }

    // MARK: PKCS #7

    /// PKCS #7 SignedData (RFC 2315) with the content attached, signed (ECDSA with SHA-256, no signed attributes,
    /// like Apple's receipts) with the device's StoreKit testing key; the certificate is included
    static func pkcs7(_ content: [UInt8]) -> [UInt8] {
        let id = identity
        let sha256 = _SKDER.seq(_SKDER.oid("2.16.840.1.101.3.4.2.1"))
        let sig = (try? id.key.signature(for: Data(content)).derRepresentation).map { [UInt8]($0) } ?? []
        let signer = _SKDER.seq(_SKDER.int(1), _SKDER.seq(id.issuer, id.serial), sha256, ecdsaSHA256, _SKDER.octet(sig))
        let signed = _SKDER.seq(_SKDER.int(1), _SKDER.set([sha256]),
                                _SKDER.seq(_SKDER.oid("1.2.840.113549.1.7.1"), _SKDER.explicit(0, _SKDER.octet(content))),
                                _SKDER.explicit(0, id.certificate), _SKDER.set([signer]))
        return _SKDER.seq(_SKDER.oid("1.2.840.113549.1.7.2"), _SKDER.explicit(0, signed))
    }

    // MARK: Subscription offers key

    /// The device's subscription offers key (offer-key.pem, PKCS #8) and its key ID (offer-key.id). Promotional offer
    /// signatures are checked against it; nil until `isim storekit offer-key` (or an app) has made one.
    static func offerKey() -> (id: String, key: P256.Signing.PublicKey)? {
        let dir = directory
        guard let pem = try? String(contentsOfFile: (dir as NSString).appendingPathComponent("offer-key.pem"), encoding: .utf8),
              let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else { return nil }
        let id = (try? String(contentsOfFile: (dir as NSString).appendingPathComponent("offer-key.id"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (id, key.publicKey)
    }
}

// MARK: - Device verification

enum _SKDevice {
    /// AppStore.deviceVerificationID: the device's identifier for this app's vendor (UIDevice.identifierForVendor)
    static let verificationID: UUID = {
        if Thread.isMainThread, let u = MainActor.assumeIsolated({ UIDevice.current.identifierForVendor }) { return u }
        // off the main thread: the same per-vendor identifier UIDevice keeps in the device data
        let bid = Bundle.main.bundleIdentifier ?? "app"
        let vendor = bid.range(of: ".", options: .backwards).map { String(bid[..<$0.lowerBound]) } ?? bid
        let file = ((_SKSigning.directory as NSString).deletingLastPathComponent as NSString).appendingPathComponent("vendor-identifiers.plist")
        if let ids = NSDictionary(contentsOfFile: file), let s = ids[vendor] as? String, let u = UUID(uuidString: s) { return u }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { UIDevice.current.identifierForVendor } } ?? UUID()
    }()
    /// SHA-384 of the nonce followed by the device verification ID (lowercased UUID strings), as Apple documents it
    static func verification(nonce: UUID) -> Data {
        Data(SHA384.hash(data: Data((nonce.uuidString.lowercased() + verificationID.uuidString.lowercased()).utf8)))
    }
}
