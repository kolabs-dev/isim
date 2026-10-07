// isim CryptoKit: HPKE (RFC 9180; base, PSK, auth and auth-PSK modes) with DHKEM over P-256/P-384/P-521 and X25519,
// HKDF-SHA256/384/512 and AES-GCM-128/256, ChaCha20-Poly1305 or export-only; AES Key Wrap (RFC 3394).
// Self-authored on isim's CryptoKit primitives (host OpenSSL). Same API shape as Apple's CryptoKit (iOS 17);
// byte arguments are ContiguousBytes (isim's Foundation has no DataProtocol).
import Foundation
internal import CommonCrypto

// MARK: - AES Key Wrap

extension AES {
    public enum KeyWrap {
        static let iv: [UInt8] = [0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6]
        static func block(_ kek: [UInt8], _ input: [UInt8], encrypt: Bool) throws -> [UInt8] {
            var out = [UInt8](repeating: 0, count: 16), moved = 0
            let st = kek.withUnsafeBytes { k in input.withUnsafeBytes { i in out.withUnsafeMutableBytes { o in
                CCCrypt(CCOperation(encrypt ? kCCEncrypt : kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                        k.baseAddress, k.count, nil, i.baseAddress, 16, o.baseAddress, 16, &moved) } } }
            guard st == CCCryptorStatus(kCCSuccess), moved == 16 else { throw CryptoKitError.underlyingCoreCryptoError(error: Int32(st)) }
            return out
        }
        public static func wrap(_ keyToWrap: SymmetricKey, using kek: SymmetricKey) throws -> Data {
            let k = _bytes(kek), p = _bytes(keyToWrap)
            guard [16, 24, 32].contains(k.count) else { throw CryptoKitError.incorrectKeySize }
            guard p.count >= 16, p.count % 8 == 0 else { throw CryptoKitError.incorrectParameterSize }
            let n = p.count / 8
            var a = iv, r = (0..<n).map { Array(p[($0 * 8)..<($0 * 8 + 8)]) }
            for j in 0..<6 {
                for i in 0..<n {
                    let b = try block(k, a + r[i], encrypt: true)
                    var t = UInt64(n * j + i + 1)
                    a = Array(b[0..<8])
                    for x in stride(from: 7, through: 0, by: -1) { a[x] ^= UInt8(t & 0xff); t >>= 8 }
                    r[i] = Array(b[8..<16])
                }
            }
            return Data(a + r.flatMap { $0 })
        }
        public static func unwrap<WrappedKey: ContiguousBytes>(_ wrappedKey: WrappedKey, using kek: SymmetricKey) throws -> SymmetricKey {
            let k = _bytes(kek), c = _bytes(wrappedKey)
            guard [16, 24, 32].contains(k.count) else { throw CryptoKitError.incorrectKeySize }
            guard c.count >= 24, c.count % 8 == 0 else { throw CryptoKitError.incorrectParameterSize }
            let n = c.count / 8 - 1
            var a = Array(c[0..<8]), r = (0..<n).map { Array(c[(8 + $0 * 8)..<(16 + $0 * 8)]) }
            for j in stride(from: 5, through: 0, by: -1) {
                for i in stride(from: n - 1, through: 0, by: -1) {
                    var t = UInt64(n * j + i + 1)
                    for x in stride(from: 7, through: 0, by: -1) { a[x] ^= UInt8(t & 0xff); t >>= 8 }
                    let b = try block(k, a + r[i], encrypt: false)
                    a = Array(b[0..<8]); r[i] = Array(b[8..<16])
                }
            }
            guard _safeEqual(a, iv) else { throw CryptoKitError.authenticationFailure }
            return SymmetricKey(data: r.flatMap { $0 })
        }
    }
}

// MARK: - HPKE

public protocol HPKEDiffieHellmanPublicKey: Sendable {
    associatedtype EphemeralPrivateKey: HPKEDiffieHellmanPrivateKeyGeneration where EphemeralPrivateKey.PublicKey == Self
    func _hpkeRepresentation(kem: HPKE.KEM) throws -> [UInt8]
    init(_hpkeRepresentation: [UInt8], kem: HPKE.KEM) throws
}
public protocol HPKEDiffieHellmanPrivateKey: Sendable {
    associatedtype PublicKey: HPKEDiffieHellmanPublicKey
    var publicKey: PublicKey { get }
    func _hpkeDH(with: PublicKey) throws -> [UInt8]
}
public protocol HPKEDiffieHellmanPrivateKeyGeneration: HPKEDiffieHellmanPrivateKey {
    init()
}

extension P256.KeyAgreement.PublicKey: HPKEDiffieHellmanPublicKey {
    public typealias EphemeralPrivateKey = P256.KeyAgreement.PrivateKey
    public func _hpkeRepresentation(kem: HPKE.KEM) throws -> [UInt8] { guard kem == .P256_HKDF_SHA256 else { throw HPKE.Errors.inconsistentParameters }; return _bytes(x963Representation) }
    public init(_hpkeRepresentation b: [UInt8], kem: HPKE.KEM) throws { guard kem == .P256_HKDF_SHA256 else { throw HPKE.Errors.inconsistentParameters }; try self.init(x963Representation: b) }
}
extension P256.KeyAgreement.PrivateKey: HPKEDiffieHellmanPrivateKeyGeneration {
    public init() { self.init(compactRepresentable: false) }
    public func _hpkeDH(with pk: P256.KeyAgreement.PublicKey) throws -> [UInt8] { _bytes(try sharedSecretFromKeyAgreement(with: pk)) }
}
extension P384.KeyAgreement.PublicKey: HPKEDiffieHellmanPublicKey {
    public typealias EphemeralPrivateKey = P384.KeyAgreement.PrivateKey
    public func _hpkeRepresentation(kem: HPKE.KEM) throws -> [UInt8] { guard kem == .P384_HKDF_SHA384 else { throw HPKE.Errors.inconsistentParameters }; return _bytes(x963Representation) }
    public init(_hpkeRepresentation b: [UInt8], kem: HPKE.KEM) throws { guard kem == .P384_HKDF_SHA384 else { throw HPKE.Errors.inconsistentParameters }; try self.init(x963Representation: b) }
}
extension P384.KeyAgreement.PrivateKey: HPKEDiffieHellmanPrivateKeyGeneration {
    public init() { self.init(compactRepresentable: false) }
    public func _hpkeDH(with pk: P384.KeyAgreement.PublicKey) throws -> [UInt8] { _bytes(try sharedSecretFromKeyAgreement(with: pk)) }
}
extension P521.KeyAgreement.PublicKey: HPKEDiffieHellmanPublicKey {
    public typealias EphemeralPrivateKey = P521.KeyAgreement.PrivateKey
    public func _hpkeRepresentation(kem: HPKE.KEM) throws -> [UInt8] { guard kem == .P521_HKDF_SHA512 else { throw HPKE.Errors.inconsistentParameters }; return _bytes(x963Representation) }
    public init(_hpkeRepresentation b: [UInt8], kem: HPKE.KEM) throws { guard kem == .P521_HKDF_SHA512 else { throw HPKE.Errors.inconsistentParameters }; try self.init(x963Representation: b) }
}
extension P521.KeyAgreement.PrivateKey: HPKEDiffieHellmanPrivateKeyGeneration {
    public init() { self.init(compactRepresentable: false) }
    public func _hpkeDH(with pk: P521.KeyAgreement.PublicKey) throws -> [UInt8] { _bytes(try sharedSecretFromKeyAgreement(with: pk)) }
}
extension Curve25519.KeyAgreement.PublicKey: HPKEDiffieHellmanPublicKey {
    public typealias EphemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey
    public func _hpkeRepresentation(kem: HPKE.KEM) throws -> [UInt8] { guard kem == .Curve25519_HKDF_SHA256 else { throw HPKE.Errors.inconsistentParameters }; return _bytes(rawRepresentation) }
    public init(_hpkeRepresentation b: [UInt8], kem: HPKE.KEM) throws { guard kem == .Curve25519_HKDF_SHA256 else { throw HPKE.Errors.inconsistentParameters }; try self.init(rawRepresentation: b) }
}
extension Curve25519.KeyAgreement.PrivateKey: HPKEDiffieHellmanPrivateKeyGeneration {
    public func _hpkeDH(with pk: Curve25519.KeyAgreement.PublicKey) throws -> [UInt8] { _bytes(try sharedSecretFromKeyAgreement(with: pk)) }
}

public enum HPKE {
    public enum Errors: Error, Equatable {
        case inconsistentParameters, inconsistentCiphersuiteAndKey, exportOnlyMode, inconsistentPSKInputs, expectedPSK, unexpectedPSK,
             outOfRangeSequenceNumber, ciphertextTooShort
    }
    public enum KEM: Hashable, Sendable {
        case P256_HKDF_SHA256, P384_HKDF_SHA384, P521_HKDF_SHA512, Curve25519_HKDF_SHA256
        var id: UInt16 {
            switch self { case .P256_HKDF_SHA256: return 0x10; case .P384_HKDF_SHA384: return 0x11; case .P521_HKDF_SHA512: return 0x12; case .Curve25519_HKDF_SHA256: return 0x20 }
        }
        var kdf: KDF {
            switch self { case .P256_HKDF_SHA256, .Curve25519_HKDF_SHA256: return .HKDF_SHA256; case .P384_HKDF_SHA384: return .HKDF_SHA384; case .P521_HKDF_SHA512: return .HKDF_SHA512 }
        }
        var secretSize: Int { kdf.hashSize }
    }
    public enum KDF: Hashable, Sendable {
        case HKDF_SHA256, HKDF_SHA384, HKDF_SHA512
        var id: UInt16 { switch self { case .HKDF_SHA256: return 1; case .HKDF_SHA384: return 2; case .HKDF_SHA512: return 3 } }
        var hashSize: Int { switch self { case .HKDF_SHA256: return 32; case .HKDF_SHA384: return 48; case .HKDF_SHA512: return 64 } }
        func hmac(_ key: [UInt8], _ data: [UInt8]) -> [UInt8] {
            let k = SymmetricKey(data: key)
            switch self {
            case .HKDF_SHA256: return _bytes(HMAC<SHA256>.authenticationCode(for: data, using: k))
            case .HKDF_SHA384: return _bytes(HMAC<SHA384>.authenticationCode(for: data, using: k))
            case .HKDF_SHA512: return _bytes(HMAC<SHA512>.authenticationCode(for: data, using: k))
            }
        }
        func extract(salt: [UInt8], ikm: [UInt8]) -> [UInt8] { hmac(salt.isEmpty ? [UInt8](repeating: 0, count: hashSize) : salt, ikm) }
        func expand(prk: [UInt8], info: [UInt8], length: Int) -> [UInt8] {
            var out: [UInt8] = [], t: [UInt8] = [], i: UInt8 = 1
            while out.count < length { t = hmac(prk, t + info + [i]); out += t; i += 1 }
            return Array(out.prefix(length))
        }
    }
    public enum AEAD: Hashable, Sendable {
        case AES_GCM_128, AES_GCM_256, chaChaPoly, exportOnly
        var id: UInt16 { switch self { case .AES_GCM_128: return 1; case .AES_GCM_256: return 2; case .chaChaPoly: return 3; case .exportOnly: return 0xffff } }
        var keySize: Int { switch self { case .AES_GCM_128: return 16; case .AES_GCM_256, .chaChaPoly: return 32; case .exportOnly: return 0 } }
        var nonceSize: Int { self == .exportOnly ? 0 : 12 }
    }
    public struct Ciphersuite: Hashable, Sendable {
        public let kem: KEM
        public let kdf: KDF
        public let aead: AEAD
        public init(kem: KEM, kdf: KDF, aead: AEAD) { self.kem = kem; self.kdf = kdf; self.aead = aead }
        public static let P256_SHA256_AES_GCM_256 = Ciphersuite(kem: .P256_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .AES_GCM_256)
        public static let P384_SHA384_AES_GCM_256 = Ciphersuite(kem: .P384_HKDF_SHA384, kdf: .HKDF_SHA384, aead: .AES_GCM_256)
        public static let P521_SHA512_AES_GCM_256 = Ciphersuite(kem: .P521_HKDF_SHA512, kdf: .HKDF_SHA512, aead: .AES_GCM_256)
        public static let Curve25519_SHA256_ChachaPoly = Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)
        var suiteID: [UInt8] { Array("HPKE".utf8) + _i2osp(kem.id) + _i2osp(kdf.id) + _i2osp(aead.id) }
    }

    static func labeledExtract(_ kdf: KDF, suite: [UInt8], salt: [UInt8], label: String, ikm: [UInt8]) -> [UInt8] {
        kdf.extract(salt: salt, ikm: Array("HPKE-v1".utf8) + suite + Array(label.utf8) + ikm)
    }
    static func labeledExpand(_ kdf: KDF, suite: [UInt8], prk: [UInt8], label: String, info: [UInt8], length: Int) -> [UInt8] {
        kdf.expand(prk: prk, info: _i2osp(UInt16(length)) + Array("HPKE-v1".utf8) + suite + Array(label.utf8) + info, length: length)
    }
    /// DHKEM ExtractAndExpand
    static func kemSharedSecret(_ kem: KEM, dh: [UInt8], context: [UInt8]) -> [UInt8] {
        let suite = Array("KEM".utf8) + _i2osp(kem.id)
        let prk = labeledExtract(kem.kdf, suite: suite, salt: [], label: "eae_prk", ikm: dh)
        return labeledExpand(kem.kdf, suite: suite, prk: prk, label: "shared_secret", info: context, length: kem.secretSize)
    }

    /// the key schedule's output: AEAD key, base nonce, exporter secret
    struct Context {
        let suite: Ciphersuite
        let key: [UInt8], baseNonce: [UInt8], exporterSecret: [UInt8]
        var seq: UInt64 = 0
        init(suite: Ciphersuite, mode: UInt8, sharedSecret: [UInt8], info: [UInt8], psk: [UInt8], pskID: [UInt8]) throws {
            let hasPSK = !psk.isEmpty, hasID = !pskID.isEmpty
            guard hasPSK == hasID else { throw Errors.inconsistentPSKInputs }
            if (mode == 1 || mode == 3) && !hasPSK { throw Errors.expectedPSK }
            if (mode == 0 || mode == 2) && hasPSK { throw Errors.unexpectedPSK }
            self.suite = suite
            let s = suite.suiteID, kdf = suite.kdf
            let pskIDHash = labeledExtract(kdf, suite: s, salt: [], label: "psk_id_hash", ikm: pskID)
            let infoHash = labeledExtract(kdf, suite: s, salt: [], label: "info_hash", ikm: info)
            let ctx = [mode] + pskIDHash + infoHash
            let secret = labeledExtract(kdf, suite: s, salt: sharedSecret, label: "secret", ikm: psk)
            key = suite.aead == .exportOnly ? [] : labeledExpand(kdf, suite: s, prk: secret, label: "key", info: ctx, length: suite.aead.keySize)
            baseNonce = suite.aead == .exportOnly ? [] : labeledExpand(kdf, suite: s, prk: secret, label: "base_nonce", info: ctx, length: 12)
            exporterSecret = labeledExpand(kdf, suite: s, prk: secret, label: "exp", info: ctx, length: kdf.hashSize)
        }
        func nonce() -> [UInt8] {
            var n = baseNonce, s = seq
            for i in stride(from: n.count - 1, through: n.count - 8, by: -1) { n[i] ^= UInt8(s & 0xff); s >>= 8 }
            return n
        }
        mutating func seal(_ pt: [UInt8], aad: [UInt8]) throws -> [UInt8] {
            let n = nonce(), k = SymmetricKey(data: key)
            var out: [UInt8]
            switch suite.aead {
            case .exportOnly: throw Errors.exportOnlyMode
            case .chaChaPoly:
                let box = try ChaChaPoly.seal(pt, using: k, nonce: try ChaChaPoly.Nonce(data: n), authenticating: aad)
                out = _bytes(box.ciphertext) + _bytes(box.tag)
            default:
                let box = try AES.GCM.seal(pt, using: k, nonce: try AES.GCM.Nonce(data: n), authenticating: aad)
                out = _bytes(box.ciphertext) + _bytes(box.tag)
            }
            guard seq < UInt64.max else { throw Errors.outOfRangeSequenceNumber }
            seq += 1
            return out
        }
        mutating func open(_ ct: [UInt8], aad: [UInt8]) throws -> [UInt8] {
            guard ct.count >= 16 else { throw Errors.ciphertextTooShort }
            let n = nonce(), k = SymmetricKey(data: key)
            let body = Array(ct.dropLast(16)), tag = Array(ct.suffix(16))
            let out: Data
            switch suite.aead {
            case .exportOnly: throw Errors.exportOnlyMode
            case .chaChaPoly:
                out = try ChaChaPoly.open(try ChaChaPoly.SealedBox(nonce: try ChaChaPoly.Nonce(data: n), ciphertext: body, tag: tag), using: k, authenticating: aad)
            default:
                out = try AES.GCM.open(try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: n), ciphertext: body, tag: tag), using: k, authenticating: aad)
            }
            guard seq < UInt64.max else { throw Errors.outOfRangeSequenceNumber }
            seq += 1
            return _bytes(out)
        }
        func export(_ context: [UInt8], length: Int) -> SymmetricKey {
            SymmetricKey(data: labeledExpand(suite.kdf, suite: suite.suiteID, prk: exporterSecret, label: "sec", info: context, length: length))
        }
    }

    public struct Sender: Sendable {
        var context: Context
        public let encapsulatedKey: Data
        public let ciphersuite: Ciphersuite

        init<PK: HPKEDiffieHellmanPublicKey>(_ pkR: PK, _ suite: Ciphersuite, info: [UInt8], mode: UInt8, psk: [UInt8], pskID: [UInt8],
                                              skS: PK.EphemeralPrivateKey?, skE: PK.EphemeralPrivateKey? = nil) throws {
            let ephemeral = skE ?? PK.EphemeralPrivateKey()
            let enc = try ephemeral.publicKey._hpkeRepresentation(kem: suite.kem)
            let pkRm = try pkR._hpkeRepresentation(kem: suite.kem)
            var dh = try ephemeral._hpkeDH(with: pkR), kemContext = enc + pkRm
            if let skS {
                dh += try skS._hpkeDH(with: pkR)
                kemContext += try skS.publicKey._hpkeRepresentation(kem: suite.kem)
            }
            let shared = HPKE.kemSharedSecret(suite.kem, dh: dh, context: kemContext)
            context = try Context(suite: suite, mode: mode, sharedSecret: shared, info: info, psk: psk, pskID: pskID)
            encapsulatedKey = Data(enc); ciphersuite = suite
        }
        public init<PK: HPKEDiffieHellmanPublicKey, I: ContiguousBytes>(recipientKey: PK, ciphersuite: Ciphersuite, info: I) throws {
            try self.init(recipientKey, ciphersuite, info: _bytes(info), mode: 0, psk: [], pskID: [], skS: nil)
        }
        public init<PK: HPKEDiffieHellmanPublicKey, I: ContiguousBytes, ID: ContiguousBytes>(recipientKey: PK, ciphersuite: Ciphersuite, info: I,
                                                                                             presharedKey psk: SymmetricKey, presharedKeyIdentifier pskID: ID) throws {
            try self.init(recipientKey, ciphersuite, info: _bytes(info), mode: 1, psk: _bytes(psk), pskID: _bytes(pskID), skS: nil)
        }
        public init<PK: HPKEDiffieHellmanPublicKey, I: ContiguousBytes>(recipientKey: PK, ciphersuite: Ciphersuite, info: I,
                                                                       authenticatedBy authenticationKey: PK.EphemeralPrivateKey) throws {
            try self.init(recipientKey, ciphersuite, info: _bytes(info), mode: 2, psk: [], pskID: [], skS: authenticationKey)
        }
        public init<PK: HPKEDiffieHellmanPublicKey, I: ContiguousBytes, ID: ContiguousBytes>(recipientKey: PK, ciphersuite: Ciphersuite, info: I,
                                                                                             authenticatedBy authenticationKey: PK.EphemeralPrivateKey,
                                                                                             presharedKey psk: SymmetricKey, presharedKeyIdentifier pskID: ID) throws {
            try self.init(recipientKey, ciphersuite, info: _bytes(info), mode: 3, psk: _bytes(psk), pskID: _bytes(pskID), skS: authenticationKey)
        }
        public mutating func seal<M: ContiguousBytes>(_ msg: M) throws -> Data { Data(try context.seal(_bytes(msg), aad: [])) }
        public mutating func seal<M: ContiguousBytes, AD: ContiguousBytes>(_ msg: M, authenticating aad: AD) throws -> Data {
            Data(try context.seal(_bytes(msg), aad: _bytes(aad)))
        }
        public func exportSecret<C: ContiguousBytes>(context exporterContext: C, outputByteCount: Int) throws -> SymmetricKey {
            context.export(_bytes(exporterContext), length: outputByteCount)
        }
    }

    public struct Recipient: Sendable {
        var context: Context
        public let ciphersuite: Ciphersuite

        init<SK: HPKEDiffieHellmanPrivateKey>(_ skR: SK, _ suite: Ciphersuite, info: [UInt8], enc: [UInt8], mode: UInt8, psk: [UInt8], pskID: [UInt8],
                                              pkS: SK.PublicKey?) throws {
            let pkE = try SK.PublicKey(_hpkeRepresentation: enc, kem: suite.kem)
            var dh = try skR._hpkeDH(with: pkE), kemContext = enc + (try skR.publicKey._hpkeRepresentation(kem: suite.kem))
            if let pkS {
                dh += try skR._hpkeDH(with: pkS)
                kemContext += try pkS._hpkeRepresentation(kem: suite.kem)
            }
            let shared = HPKE.kemSharedSecret(suite.kem, dh: dh, context: kemContext)
            context = try Context(suite: suite, mode: mode, sharedSecret: shared, info: info, psk: psk, pskID: pskID)
            ciphersuite = suite
        }
        public init<SK: HPKEDiffieHellmanPrivateKey, I: ContiguousBytes, E: ContiguousBytes>(privateKey: SK, ciphersuite: Ciphersuite, info: I, encapsulatedKey: E) throws {
            try self.init(privateKey, ciphersuite, info: _bytes(info), enc: _bytes(encapsulatedKey), mode: 0, psk: [], pskID: [], pkS: nil)
        }
        public init<SK: HPKEDiffieHellmanPrivateKey, I: ContiguousBytes, E: ContiguousBytes, ID: ContiguousBytes>(privateKey: SK, ciphersuite: Ciphersuite, info: I,
                    encapsulatedKey: E, presharedKey psk: SymmetricKey, presharedKeyIdentifier pskID: ID) throws {
            try self.init(privateKey, ciphersuite, info: _bytes(info), enc: _bytes(encapsulatedKey), mode: 1, psk: _bytes(psk), pskID: _bytes(pskID), pkS: nil)
        }
        public init<SK: HPKEDiffieHellmanPrivateKey, I: ContiguousBytes, E: ContiguousBytes>(privateKey: SK, ciphersuite: Ciphersuite, info: I,
                    encapsulatedKey: E, authenticatedBy authenticationKey: SK.PublicKey) throws {
            try self.init(privateKey, ciphersuite, info: _bytes(info), enc: _bytes(encapsulatedKey), mode: 2, psk: [], pskID: [], pkS: authenticationKey)
        }
        public init<SK: HPKEDiffieHellmanPrivateKey, I: ContiguousBytes, E: ContiguousBytes, ID: ContiguousBytes>(privateKey: SK, ciphersuite: Ciphersuite, info: I,
                    encapsulatedKey: E, authenticatedBy authenticationKey: SK.PublicKey, presharedKey psk: SymmetricKey, presharedKeyIdentifier pskID: ID) throws {
            try self.init(privateKey, ciphersuite, info: _bytes(info), enc: _bytes(encapsulatedKey), mode: 3, psk: _bytes(psk), pskID: _bytes(pskID), pkS: authenticationKey)
        }
        public mutating func open<C: ContiguousBytes>(_ ciphertext: C) throws -> Data { Data(try context.open(_bytes(ciphertext), aad: [])) }
        public mutating func open<C: ContiguousBytes, AD: ContiguousBytes>(_ ciphertext: C, authenticating aad: AD) throws -> Data {
            Data(try context.open(_bytes(ciphertext), aad: _bytes(aad)))
        }
        public func exportSecret<C: ContiguousBytes>(context exporterContext: C, outputByteCount: Int) throws -> SymmetricKey {
            context.export(_bytes(exporterContext), length: outputByteCount)
        }
    }
}

@inline(__always) func _i2osp(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xff)] }

// MARK: - Secure Enclave (unavailable on isim, like the Simulator without a Secure Enclave)

public enum SecureEnclave {
    /// false: isim has no Secure Enclave
    public static var isAvailable: Bool { false }
    public enum P256 {
        public enum Signing {
            public struct PrivateKey: Sendable {
                public init(compactRepresentable: Bool = true) throws { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
                public init<D: ContiguousBytes>(dataRepresentation: D) throws { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
                public var publicKey: CryptoKit.P256.Signing.PublicKey { fatalError("no Secure Enclave on isim") }
                public var dataRepresentation: Data { Data() }
            }
        }
        public enum KeyAgreement {
            public struct PrivateKey: Sendable {
                public init(compactRepresentable: Bool = true) throws { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
                public init<D: ContiguousBytes>(dataRepresentation: D) throws { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
                public var publicKey: CryptoKit.P256.KeyAgreement.PublicKey { fatalError("no Secure Enclave on isim") }
                public var dataRepresentation: Data { Data() }
            }
        }
    }
}
