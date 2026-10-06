// isim CryptoKit: shared secrets and the helpers behind the NIST-curve and Curve25519 keys.
import Foundation
internal import isim_host

public struct SharedSecret: ContiguousBytes, CustomStringConvertible, Equatable, Sendable {
    let bytes: [UInt8]
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SharedSecret" }
    public static func == (a: SharedSecret, b: SharedSecret) -> Bool { _safeEqual(a.bytes, b.bytes) }
    public static func == <D: ContiguousBytes>(a: SharedSecret, b: D) -> Bool { _safeEqual(a.bytes, _bytes(b)) }

    public func hkdfDerivedSymmetricKey<H: HashFunction, Salt: ContiguousBytes, SI: ContiguousBytes>(using hashFunction: H.Type, salt: Salt, sharedInfo: SI, outputByteCount: Int) -> SymmetricKey {
        HKDF<H>.deriveKey(inputKeyMaterial: SymmetricKey(data: bytes), salt: salt, info: sharedInfo, outputByteCount: outputByteCount)
    }
    /// ANSI X9.63 KDF
    public func x963DerivedSymmetricKey<H: HashFunction, SI: ContiguousBytes>(using hashFunction: H.Type, sharedInfo: SI, outputByteCount: Int) -> SymmetricKey {
        let info = _bytes(sharedInfo)
        var out = [UInt8](), counter: UInt32 = 1
        while out.count < outputByteCount {
            var h = H()
            h.update(data: bytes)
            h.update(data: [UInt8(counter >> 24), UInt8((counter >> 16) & 0xff), UInt8((counter >> 8) & 0xff), UInt8(counter & 0xff)])
            h.update(data: info)
            out += Array(h.finalize()); counter += 1
        }
        return SymmetricKey(data: Array(out.prefix(outputByteCount)))
    }
}

// MARK: - NIST curve helpers (curve = 256, 384, 521)

enum _EC {
    static func size(_ curve: Int32) -> Int { curve == 256 ? 32 : curve == 384 ? 48 : 66 }
    static func generate(_ curve: Int32) -> [UInt8] {
        _requireCrypto()
        var d = [UInt8](repeating: 0, count: size(curve))
        guard d.withUnsafeMutableBufferPointer({ isim_crypto_ec_generate(curve, $0.baseAddress!) }) == 1 else { fatalError("isim CryptoKit: EC key generation failed") }
        return d
    }
    /// private scalar -> uncompressed X9.63 public key; throws for an invalid scalar
    static func publicKey(_ curve: Int32, _ d: [UInt8]) throws -> [UInt8] {
        _requireCrypto()
        guard d.count == size(curve) else { throw CryptoKitError.incorrectKeySize }
        var q = [UInt8](repeating: 0, count: 1 + 2 * size(curve))
        let ok = d.withUnsafeBufferPointer { dp in q.withUnsafeMutableBufferPointer { isim_crypto_ec_public(curve, dp.baseAddress!, $0.baseAddress!) } }
        guard ok == 1 else { throw CryptoKitError.invalidParameter }
        return q
    }
    /// any X9.63 encoding (uncompressed or compressed) -> validated uncompressed point
    static func importPublic(_ curve: Int32, _ bytes: [UInt8]) throws -> [UInt8] {
        _requireCrypto()
        guard !bytes.isEmpty else { throw CryptoKitError.incorrectKeySize }
        var q = [UInt8](repeating: 0, count: 1 + 2 * size(curve))
        let ok = bytes.withUnsafeBufferPointer { b in q.withUnsafeMutableBufferPointer { isim_crypto_ec_import_public(curve, b.baseAddress!, b.count, $0.baseAddress!) } }
        guard ok == 1 else { throw CryptoKitError.invalidParameter }
        return q
    }
    static func compressed(_ curve: Int32, _ q: [UInt8]) -> [UInt8] {
        var c = [UInt8](repeating: 0, count: 1 + size(curve))
        _ = q.withUnsafeBufferPointer { b in c.withUnsafeMutableBufferPointer { isim_crypto_ec_compress(curve, b.baseAddress!, b.count, $0.baseAddress!) } }
        return c
    }
    static func sign(_ curve: Int32, _ d: [UInt8], digest: [UInt8]) throws -> [UInt8] {
        _requireCrypto()
        var sig = [UInt8](repeating: 0, count: 2 * size(curve))
        let ok = d.withUnsafeBufferPointer { dp in digest.withUnsafeBufferPointer { h in sig.withUnsafeMutableBufferPointer {
            isim_crypto_ec_sign(curve, dp.baseAddress!, h.baseAddress!, h.count, $0.baseAddress!) } } }
        guard ok == 1 else { throw CryptoKitError.underlyingCoreCryptoError(error: -1) }
        return sig
    }
    static func verify(_ curve: Int32, _ q: [UInt8], digest: [UInt8], signature: [UInt8]) -> Bool {
        _requireCrypto()
        guard signature.count == 2 * size(curve) else { return false }
        return q.withUnsafeBufferPointer { qp in digest.withUnsafeBufferPointer { h in signature.withUnsafeBufferPointer {
            isim_crypto_ec_verify(curve, qp.baseAddress!, qp.count, h.baseAddress!, h.count, $0.baseAddress!) } } } == 1
    }
    static func ecdh(_ curve: Int32, _ d: [UInt8], _ q: [UInt8]) throws -> SharedSecret {
        _requireCrypto()
        var z = [UInt8](repeating: 0, count: size(curve))
        let ok = d.withUnsafeBufferPointer { dp in q.withUnsafeBufferPointer { qp in z.withUnsafeMutableBufferPointer {
            isim_crypto_ec_ecdh(curve, dp.baseAddress!, qp.baseAddress!, qp.count, $0.baseAddress!) } } }
        guard ok == 1 else { throw CryptoKitError.underlyingCoreCryptoError(error: -1) }
        return SharedSecret(bytes: z)
    }

    // SubjectPublicKeyInfo DER prefixes for uncompressed points (RFC 5480)
    static func spkiPrefix(_ curve: Int32) -> [UInt8] {
        switch curve {
        case 256: return _unhex("3059301306072a8648ce3d020106082a8648ce3d030107034200")
        case 384: return _unhex("3076301006072a8648ce3d020106052b81040022036200")
        default: return _unhex("30819b301006072a8648ce3d020106052b8104002303818600")
        }
    }
    static func der(_ curve: Int32, _ q: [UInt8]) -> [UInt8] { spkiPrefix(curve) + q }
    static func fromDER(_ curve: Int32, _ der: [UInt8]) throws -> [UInt8] {
        let p = spkiPrefix(curve)
        guard der.count == p.count + 1 + 2 * size(curve), Array(der.prefix(p.count)) == p else { throw CryptoKitError.invalidParameter }
        return try importPublic(curve, Array(der.dropFirst(p.count)))
    }

    // ECDSA signature DER: SEQUENCE { INTEGER r, INTEGER s }
    static func sigToDER(_ raw: [UInt8]) -> [UInt8] {
        func int(_ b: ArraySlice<UInt8>) -> [UInt8] {
            var v = Array(b.drop(while: { $0 == 0 })); if v.isEmpty { v = [0] }
            if v[0] & 0x80 != 0 { v.insert(0, at: 0) }
            return [0x02] + _derLen(v.count) + v
        }
        let half = raw.count / 2
        let body = int(raw[0..<half]) + int(raw[half...])
        return [0x30] + _derLen(body.count) + body
    }
    static func sigFromDER(_ der: [UInt8], size n: Int) throws -> [UInt8] {
        var i = 0
        func byte() throws -> UInt8 { guard i < der.count else { throw CryptoKitError.invalidParameter }; defer { i += 1 }; return der[i] }
        func len() throws -> Int {
            let b = try byte()
            if b < 0x80 { return Int(b) }
            var l = 0
            for _ in 0..<Int(b & 0x7f) { l = l << 8 | Int(try byte()) }
            return l
        }
        guard try byte() == 0x30 else { throw CryptoKitError.invalidParameter }
        _ = try len()
        var out = [UInt8]()
        for _ in 0..<2 {
            guard try byte() == 0x02 else { throw CryptoKitError.invalidParameter }
            let l = try len()
            guard i + l <= der.count else { throw CryptoKitError.invalidParameter }
            var v = Array(der[i..<(i + l)].drop(while: { $0 == 0 })); i += l
            guard v.count <= n else { throw CryptoKitError.invalidParameter }
            v = [UInt8](repeating: 0, count: n - v.count) + v
            out += v
        }
        return out
    }
}

func _derLen(_ n: Int) -> [UInt8] { n < 0x80 ? [UInt8(n)] : n < 0x100 ? [0x81, UInt8(n)] : [0x82, UInt8(n >> 8), UInt8(n & 0xff)] }
func _unhex(_ s: String) -> [UInt8] {
    var out = [UInt8](), hi: UInt8? = nil
    for c in s.utf8 {
        let v: UInt8 = c >= 97 ? c - 87 : c >= 65 ? c - 55 : c - 48
        if let h = hi { out.append(h << 4 | v); hi = nil } else { hi = v }
    }
    return out
}
func _pem(_ der: [UInt8], _ label: String) -> String {
    let b64 = Data(der).base64EncodedString()
    var lines = [String](), s = Substring(b64)
    while !s.isEmpty { lines.append(String(s.prefix(64))); s = s.dropFirst(64) }
    return "-----BEGIN \(label)-----\n" + lines.joined(separator: "\n") + "\n-----END \(label)-----"
}
func _fromPEM(_ pem: String, _ label: String) throws -> [UInt8] {
    guard pem.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).contains(where: { $0.hasPrefix("-----BEGIN \(label)-----") }) else { throw CryptoKitError.invalidParameter }
    let body = String(pem.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).filter { !$0.hasPrefix("-----") }.joined().filter { !$0.isWhitespace })
    guard let d = Data(base64Encoded: body) else { throw CryptoKitError.invalidParameter }
    return Array(d)
}

// MARK: - Curve25519 helpers

enum _C25519 {
    static func publicKey(kind: Int32, _ priv: [UInt8]) throws -> [UInt8] {
        _requireCrypto()
        guard priv.count == 32 else { throw CryptoKitError.incorrectKeySize }
        var pub = [UInt8](repeating: 0, count: 32)
        let ok = priv.withUnsafeBufferPointer { p in pub.withUnsafeMutableBufferPointer { isim_crypto_25519_public(kind, p.baseAddress!, $0.baseAddress!) } }
        guard ok == 1 else { throw CryptoKitError.invalidParameter }
        return pub
    }
    static func checkPublic(kind: Int32, _ pub: [UInt8]) throws {
        _requireCrypto()
        guard pub.count == 32 else { throw CryptoKitError.incorrectKeySize }
        guard pub.withUnsafeBufferPointer({ isim_crypto_25519_check_public(kind, $0.baseAddress!) }) == 1 else { throw CryptoKitError.invalidParameter }
    }
}

public enum Curve25519 {
    public enum Signing {
        public struct PrivateKey: Sendable {
            let seed: [UInt8], pub: [UInt8]
            public init() { seed = _randomBytes(32); pub = try! _C25519.publicKey(kind: 1, seed) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { seed = _bytes(data); pub = try _C25519.publicKey(kind: 1, seed) }
            public var rawRepresentation: Data { Data(seed) }
            public var publicKey: PublicKey { PublicKey(bytes: pub) }
            public func signature<D: ContiguousBytes>(for data: D) throws -> Data {
                var sig = [UInt8](repeating: 0, count: 64)
                let msg = _bytes(data)
                let ok = seed.withUnsafeBufferPointer { s in msg.withUnsafeBytes { m in sig.withUnsafeMutableBufferPointer {
                    isim_crypto_ed25519_sign(s.baseAddress!, m.baseAddress, m.count, $0.baseAddress!) } } }
                guard ok == 1 else { throw CryptoKitError.underlyingCoreCryptoError(error: -1) }
                return Data(sig)
            }
        }
        public struct PublicKey: Sendable {
            let bytes: [UInt8]
            init(bytes: [UInt8]) { self.bytes = bytes }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { bytes = _bytes(data); try _C25519.checkPublic(kind: 1, bytes) }
            public var rawRepresentation: Data { Data(bytes) }
            public func isValidSignature<S: ContiguousBytes, D: ContiguousBytes>(_ signature: S, for data: D) -> Bool {
                let sig = _bytes(signature), msg = _bytes(data)
                guard sig.count == 64 else { return false }
                _requireCrypto()
                return bytes.withUnsafeBufferPointer { p in msg.withUnsafeBytes { m in sig.withUnsafeBufferPointer {
                    isim_crypto_ed25519_verify(p.baseAddress!, m.baseAddress, m.count, $0.baseAddress!) } } } == 1
            }
        }
    }
    public enum KeyAgreement {
        public struct PrivateKey: Sendable {
            let scalar: [UInt8], pub: [UInt8]
            public init() { scalar = _randomBytes(32); pub = try! _C25519.publicKey(kind: 0, scalar) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { scalar = _bytes(data); pub = try _C25519.publicKey(kind: 0, scalar) }
            public var rawRepresentation: Data { Data(scalar) }
            public var publicKey: PublicKey { PublicKey(bytes: pub) }
            public func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret {
                _requireCrypto()
                var z = [UInt8](repeating: 0, count: 32)
                let ok = scalar.withUnsafeBufferPointer { s in publicKeyShare.bytes.withUnsafeBufferPointer { p in z.withUnsafeMutableBufferPointer {
                    isim_crypto_x25519(s.baseAddress!, p.baseAddress!, $0.baseAddress!) } } }
                guard ok == 1 else { throw CryptoKitError.underlyingCoreCryptoError(error: -1) }
                return SharedSecret(bytes: z)
            }
        }
        public struct PublicKey: Sendable {
            let bytes: [UInt8]
            init(bytes: [UInt8]) { self.bytes = bytes }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { bytes = _bytes(data); try _C25519.checkPublic(kind: 0, bytes) }
            public var rawRepresentation: Data { Data(bytes) }
        }
    }
}
