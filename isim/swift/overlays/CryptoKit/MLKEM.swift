// isim CryptoKit: key encapsulation (iOS 26): the KEM protocols, ML-KEM-768 and ML-KEM-1024 (FIPS 203). Implemented
// here in Swift (adapted: no host library needed) on isim's SHA-3 / SHAKE; same API as Apple's MLKEM768 / MLKEM1024.
// A private key's seedRepresentation is the 64-byte seed d ‖ z of FIPS 203's ML-KEM.KeyGen_internal; its
// integrityCheckedRepresentation is the seed followed by SHA3-256 of the public key, checked when it is read back.
import Foundation

// MARK: - KEM protocols

public enum KEM {
    public struct EncapsulationResult: Sendable {
        public let sharedSecret: SymmetricKey
        public let encapsulated: Data
        public init(sharedSecret: SymmetricKey, encapsulated: Data) { self.sharedSecret = sharedSecret; self.encapsulated = encapsulated }
    }
    public enum Errors: Error, Equatable {
        case invalidSeed
        case publicKeyMismatchDuringInitialization
    }
}
public protocol KEMPublicKey {
    func encapsulate() throws -> KEM.EncapsulationResult
}
/// a key that decapsulates once (iOS 27): a second decapsulate throws
@available(iOS 27.0, *)
public protocol KEMOneTimePrivateKey {
    associatedtype PublicKey: KEMPublicKey
    static func generate() throws -> Self
    func decapsulate(_ encapsulated: Data) throws -> SymmetricKey
    var publicKey: PublicKey { get }
}
/// a one-time key's state: whether it has decapsulated
final class _OneTimeUse: @unchecked Sendable {
    let lock = NSLock()
    var used = false
    func take() throws {
        lock.lock(); defer { lock.unlock() }
        guard !used else { throw CryptoKitError.invalidParameter }
        used = true
    }
}
public protocol KEMPrivateKey {
    associatedtype PublicKey: KEMPublicKey
    static func generate() throws -> Self
    func decapsulate(_ encapsulated: Data) throws -> SymmetricKey
    var publicKey: PublicKey { get }
}

// MARK: - ML-KEM internals (FIPS 203)

struct _MLKEM {
    static let q = 3329
    let k: Int, du: Int, dv: Int
    let eta1 = 2, eta2 = 2
    static let p768 = _MLKEM(k: 3, du: 10, dv: 4)
    static let p1024 = _MLKEM(k: 4, du: 11, dv: 5)
    var publicKeySize: Int { 384 * k + 32 }
    var ciphertextSize: Int { 32 * (du * k + dv) }

    typealias Poly = [Int]
    static func bitrev7(_ i: Int) -> Int { var r = 0; for b in 0..<7 where i & (1 << b) != 0 { r |= 1 << (6 - b) }; return r }
    static func pow(_ b: Int, _ e: Int) -> Int { var r = 1, x = b % q, e = e; while e > 0 { if e & 1 == 1 { r = r * x % q }; x = x * x % q; e >>= 1 }; return r }
    static let zetas: [Int] = (0..<128).map { pow(17, bitrev7($0)) }
    static let gammas: [Int] = (0..<128).map { pow(17, 2 * bitrev7($0) + 1) }

    static func ntt(_ f: Poly) -> Poly {
        var f = f, i = 1, len = 128
        while len >= 2 {
            for start in stride(from: 0, to: 256, by: 2 * len) {
                let z = zetas[i]; i += 1
                for j in start..<(start + len) {
                    let t = z * f[j + len] % q
                    f[j + len] = (f[j] - t + q) % q
                    f[j] = (f[j] + t) % q
                }
            }
            len >>= 1
        }
        return f
    }
    static func invNTT(_ f: Poly) -> Poly {
        var f = f, i = 127, len = 2
        while len <= 128 {
            for start in stride(from: 0, to: 256, by: 2 * len) {
                let z = zetas[i]; i -= 1
                for j in start..<(start + len) {
                    let t = f[j]
                    f[j] = (t + f[j + len]) % q
                    f[j + len] = z * ((f[j + len] - t + q) % q) % q
                }
            }
            len <<= 1
        }
        return f.map { $0 * 3303 % q }
    }
    static func mul(_ a: Poly, _ b: Poly) -> Poly {
        var h = Poly(repeating: 0, count: 256)
        for i in 0..<128 {
            let a0 = a[2 * i], a1 = a[2 * i + 1], b0 = b[2 * i], b1 = b[2 * i + 1]
            h[2 * i] = (a0 * b0 + a1 * b1 % q * gammas[i]) % q
            h[2 * i + 1] = (a0 * b1 + a1 * b0) % q
        }
        return h
    }
    static func add(_ a: Poly, _ b: Poly) -> Poly { (0..<256).map { (a[$0] + b[$0]) % q } }
    static func sub(_ a: Poly, _ b: Poly) -> Poly { (0..<256).map { (a[$0] - b[$0] + q) % q } }

    static func encode(_ f: Poly, _ d: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 32 * d), bit = 0
        for c in f { for b in 0..<d { if (c >> b) & 1 == 1 { out[bit >> 3] |= 1 << (bit & 7) }; bit += 1 } }
        return out
    }
    static func decode(_ bytes: ArraySlice<UInt8>, _ d: Int) -> Poly {
        let base = bytes.startIndex
        var f = Poly(repeating: 0, count: 256), bit = 0
        for i in 0..<256 {
            var c = 0
            for b in 0..<d { c |= Int((bytes[base + (bit >> 3)] >> (bit & 7)) & 1) << b; bit += 1 }
            f[i] = d == 12 ? c % q : c
        }
        return f
    }
    static func compress(_ x: Int, _ d: Int) -> Int { ((x << d) + q / 2) / q & ((1 << d) - 1) }
    static func decompress(_ y: Int, _ d: Int) -> Int { (y * q + (1 << (d - 1))) >> d }

    static func sampleNTT(_ rho: [UInt8], _ j: UInt8, _ i: UInt8) -> Poly {
        var xof = _Keccak.shake128(); xof.update(rho + [j, i])
        var a = Poly(), buf = [UInt8](), p = 0
        a.reserveCapacity(256)
        while a.count < 256 {
            if p + 3 > buf.count { buf = xof.squeeze(168); p = 0 }
            let d1 = Int(buf[p]) | (Int(buf[p + 1]) & 15) << 8, d2 = Int(buf[p + 1]) >> 4 | Int(buf[p + 2]) << 4
            p += 3
            if d1 < q { a.append(d1) }
            if d2 < q && a.count < 256 { a.append(d2) }
        }
        return a
    }
    static func cbd(_ b: [UInt8], _ eta: Int) -> Poly {
        func bit(_ i: Int) -> Int { Int((b[i >> 3] >> (i & 7)) & 1) }
        return (0..<256).map { i in
            var x = 0, y = 0
            for j in 0..<eta { x += bit(2 * i * eta + j); y += bit(2 * i * eta + eta + j) }
            return (x - y + q) % q
        }
    }
    static func prf(_ s: [UInt8], _ n: UInt8, _ eta: Int) -> [UInt8] { _Keccak.shake256(s + [n], 64 * eta) }

    func matrix(_ rho: [UInt8]) -> [[Poly]] {
        (0..<k).map { i in (0..<k).map { j in _MLKEM.sampleNTT(rho, UInt8(j), UInt8(i)) } }
    }
    /// K-PKE.KeyGen: (ek, dk_PKE)
    func pkeKeyGen(_ d: [UInt8]) -> ([UInt8], [UInt8]) {
        let g = _Keccak.sha3_512(d + [UInt8(k)])
        let rho = Array(g[0..<32]), sigma = Array(g[32..<64])
        let a = matrix(rho)
        var n: UInt8 = 0
        var s = [Poly](), e = [Poly]()
        for _ in 0..<k { s.append(_MLKEM.ntt(_MLKEM.cbd(_MLKEM.prf(sigma, n, eta1), eta1))); n += 1 }
        for _ in 0..<k { e.append(_MLKEM.ntt(_MLKEM.cbd(_MLKEM.prf(sigma, n, eta1), eta1))); n += 1 }
        var ek = [UInt8](), dk = [UInt8]()
        for i in 0..<k {
            var t = e[i]
            for j in 0..<k { t = _MLKEM.add(t, _MLKEM.mul(a[i][j], s[j])) }
            ek += _MLKEM.encode(t, 12)
            dk += _MLKEM.encode(s[i], 12)
        }
        return (ek + rho, dk)
    }
    func pkeEncrypt(_ ek: [UInt8], _ m: [UInt8], _ r: [UInt8]) -> [UInt8] {
        let t = (0..<k).map { _MLKEM.decode(ek[(384 * $0)..<(384 * $0 + 384)], 12) }
        let rho = Array(ek[(384 * k)...])
        let a = matrix(rho)
        var n: UInt8 = 0
        var y = [Poly](), e1 = [Poly]()
        for _ in 0..<k { y.append(_MLKEM.ntt(_MLKEM.cbd(_MLKEM.prf(r, n, eta1), eta1))); n += 1 }
        for _ in 0..<k { e1.append(_MLKEM.cbd(_MLKEM.prf(r, n, eta2), eta2)); n += 1 }
        let e2 = _MLKEM.cbd(_MLKEM.prf(r, n, eta2), eta2)
        var c = [UInt8]()
        for i in 0..<k {
            var acc = Poly(repeating: 0, count: 256)
            for j in 0..<k { acc = _MLKEM.add(acc, _MLKEM.mul(a[j][i], y[j])) }
            let u = _MLKEM.add(_MLKEM.invNTT(acc), e1[i])
            c += _MLKEM.encode(u.map { _MLKEM.compress($0, du) }, du)
        }
        var acc = Poly(repeating: 0, count: 256)
        for j in 0..<k { acc = _MLKEM.add(acc, _MLKEM.mul(t[j], y[j])) }
        let mu = _MLKEM.decode(m[...], 1).map { _MLKEM.decompress($0, 1) }
        let v = _MLKEM.add(_MLKEM.add(_MLKEM.invNTT(acc), e2), mu)
        return c + _MLKEM.encode(v.map { _MLKEM.compress($0, dv) }, dv)
    }
    func pkeDecrypt(_ dk: [UInt8], _ c: [UInt8]) -> [UInt8] {
        let ub = 32 * du
        var acc = Poly(repeating: 0, count: 256)
        for i in 0..<k {
            let u = _MLKEM.decode(c[(ub * i)..<(ub * i + ub)], du).map { _MLKEM.decompress($0, du) }
            let s = _MLKEM.decode(dk[(384 * i)..<(384 * i + 384)], 12)
            acc = _MLKEM.add(acc, _MLKEM.mul(s, _MLKEM.ntt(u)))
        }
        let v = _MLKEM.decode(c[(ub * k)...], dv).map { _MLKEM.decompress($0, dv) }
        let w = _MLKEM.sub(v, _MLKEM.invNTT(acc))
        return _MLKEM.encode(w.map { _MLKEM.compress($0, 1) }, 1)
    }

    /// ML-KEM.KeyGen_internal(d, z): (ek, dk)
    func keyGen(_ seed: [UInt8]) -> ([UInt8], [UInt8]) {
        let (ek, dkPKE) = pkeKeyGen(Array(seed[0..<32]))
        return (ek, dkPKE + ek + _Keccak.sha3_256(ek) + Array(seed[32..<64]))
    }
    func encaps(_ ek: [UInt8], m: [UInt8]) -> (key: [UInt8], ct: [UInt8]) {
        let g = _Keccak.sha3_512(m + _Keccak.sha3_256(ek))
        return (Array(g[0..<32]), pkeEncrypt(ek, m, Array(g[32..<64])))
    }
    func decaps(_ dk: [UInt8], _ c: [UInt8]) -> [UInt8] {
        let n = 384 * k
        let dkPKE = Array(dk[0..<n]), ek = Array(dk[n..<(2 * n + 32)])
        let h = Array(dk[(2 * n + 32)..<(2 * n + 64)]), z = Array(dk[(2 * n + 64)...])
        let m = pkeDecrypt(dkPKE, c)
        let g = _Keccak.sha3_512(m + h)
        let reject = _Keccak.shake256(z + c, 32)
        let ok = _safeEqual(pkeEncrypt(ek, m, Array(g[32..<64])), c)
        let mask: UInt8 = ok ? 0xff : 0
        return (0..<32).map { (g[$0] & mask) | (reject[$0] & ~mask) }
    }
    /// FIPS 203's encapsulation key check: the right length, every coefficient below q
    func checkPublicKey(_ ek: [UInt8]) -> Bool {
        guard ek.count == publicKeySize else { return false }
        for i in 0..<k where _MLKEM.encode(_MLKEM.decode(ek[(384 * i)..<(384 * i + 384)], 12), 12) != Array(ek[(384 * i)..<(384 * i + 384)]) { return false }
        return true
    }
}

/// a private key's seed, checked against an expected public key, or against the hash in an integrity-checked blob
func _kemSeed(_ seed: [UInt8], count: Int, derived: [UInt8], publicKey: [UInt8]?) throws {
    guard seed.count == count else { throw KEM.Errors.invalidSeed }
    if let publicKey, !_safeEqual(publicKey, derived) { throw KEM.Errors.publicKeyMismatchDuringInitialization }
}
func _integrityChecked(_ blob: [UInt8], seedCount: Int) throws -> [UInt8] {
    guard blob.count == seedCount + 32 else { throw CryptoKitError.incorrectParameterSize }
    return Array(blob[0..<seedCount])
}

// MARK: - MLKEM768 / MLKEM1024

@available(iOS 26.0, *)
public enum MLKEM768 {
    static let p = _MLKEM.p768
    public struct PublicKey: KEMPublicKey, Sendable {
        let raw: [UInt8]
        init(raw: [UInt8]) { self.raw = raw }
        public init<D: ContiguousBytes>(rawRepresentation: D) throws {
            raw = _bytes(rawRepresentation)
            guard MLKEM768.p.checkPublicKey(raw) else { throw CryptoKitError.incorrectKeySize }
        }
        public var rawRepresentation: Data { Data(raw) }
        public func encapsulate() throws -> KEM.EncapsulationResult { try _encapsulate(m: _randomBytes(32)) }
        @_spi(isim) public func _encapsulate(m: [UInt8]) throws -> KEM.EncapsulationResult {
            let (key, ct) = MLKEM768.p.encaps(raw, m: m)
            return KEM.EncapsulationResult(sharedSecret: SymmetricKey(data: key), encapsulated: Data(ct))
        }
    }
    public struct PrivateKey: KEMPrivateKey, Sendable {
        let seed: [UInt8], dk: [UInt8]
        public let publicKey: PublicKey
        public init() throws { try self.init(seed: _randomBytes(64), publicKey: nil) }
        public static func generate() throws -> PrivateKey { try PrivateKey() }
        init(seed: [UInt8], publicKey pk: [UInt8]?) throws {
            guard seed.count == 64 else { throw KEM.Errors.invalidSeed }
            let (ek, dk) = MLKEM768.p.keyGen(seed)
            try _kemSeed(seed, count: 64, derived: ek, publicKey: pk)
            self.seed = seed; self.dk = dk; publicKey = PublicKey(raw: ek)
        }
        public init<D: ContiguousBytes>(seedRepresentation: D, publicKey: PublicKey?) throws {
            try self.init(seed: _bytes(seedRepresentation), publicKey: publicKey?.raw)
        }
        public var seedRepresentation: Data { Data(seed) }
        public init<D: ContiguousBytes>(integrityCheckedRepresentation: D) throws {
            let blob = _bytes(integrityCheckedRepresentation)
            let s = try _integrityChecked(blob, seedCount: 64)
            try self.init(seed: s, publicKey: nil)
            guard _safeEqual(_Keccak.sha3_256(publicKey.raw), Array(blob[64...])) else { throw KEM.Errors.publicKeyMismatchDuringInitialization }
        }
        public var integrityCheckedRepresentation: Data { Data(seed + _Keccak.sha3_256(publicKey.raw)) }
        public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
            let c = _bytes(encapsulated)
            guard c.count == MLKEM768.p.ciphertextSize else { throw CryptoKitError.incorrectParameterSize }
            return SymmetricKey(data: MLKEM768.p.decaps(dk, c))
        }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey { try decapsulate([UInt8](encapsulated)) }
    }    /// a key for one decapsulation (iOS 27)
    @available(iOS 27.0, *)
    public struct OneTimePrivateKey: KEMOneTimePrivateKey, Sendable {
        let key: PrivateKey
        let state = _OneTimeUse()
        public var publicKey: PublicKey { key.publicKey }
        public init() throws { key = try PrivateKey() }
        public static func generate() throws -> OneTimePrivateKey { try OneTimePrivateKey() }
        public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
            try state.take()
            return try key.decapsulate(encapsulated)
        }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey { try decapsulate([UInt8](encapsulated)) }
    }
}

@available(iOS 26.0, *)
public enum MLKEM1024 {
    static let p = _MLKEM.p1024
    public struct PublicKey: KEMPublicKey, Sendable {
        let raw: [UInt8]
        init(raw: [UInt8]) { self.raw = raw }
        public init<D: ContiguousBytes>(rawRepresentation: D) throws {
            raw = _bytes(rawRepresentation)
            guard MLKEM1024.p.checkPublicKey(raw) else { throw CryptoKitError.incorrectKeySize }
        }
        public var rawRepresentation: Data { Data(raw) }
        public func encapsulate() throws -> KEM.EncapsulationResult { try _encapsulate(m: _randomBytes(32)) }
        @_spi(isim) public func _encapsulate(m: [UInt8]) throws -> KEM.EncapsulationResult {
            let (key, ct) = MLKEM1024.p.encaps(raw, m: m)
            return KEM.EncapsulationResult(sharedSecret: SymmetricKey(data: key), encapsulated: Data(ct))
        }
    }
    public struct PrivateKey: KEMPrivateKey, Sendable {
        let seed: [UInt8], dk: [UInt8]
        public let publicKey: PublicKey
        public init() throws { try self.init(seed: _randomBytes(64), publicKey: nil) }
        public static func generate() throws -> PrivateKey { try PrivateKey() }
        init(seed: [UInt8], publicKey pk: [UInt8]?) throws {
            guard seed.count == 64 else { throw KEM.Errors.invalidSeed }
            let (ek, dk) = MLKEM1024.p.keyGen(seed)
            try _kemSeed(seed, count: 64, derived: ek, publicKey: pk)
            self.seed = seed; self.dk = dk; publicKey = PublicKey(raw: ek)
        }
        public init<D: ContiguousBytes>(seedRepresentation: D, publicKey: PublicKey?) throws {
            try self.init(seed: _bytes(seedRepresentation), publicKey: publicKey?.raw)
        }
        public var seedRepresentation: Data { Data(seed) }
        public init<D: ContiguousBytes>(integrityCheckedRepresentation: D) throws {
            let blob = _bytes(integrityCheckedRepresentation)
            let s = try _integrityChecked(blob, seedCount: 64)
            try self.init(seed: s, publicKey: nil)
            guard _safeEqual(_Keccak.sha3_256(publicKey.raw), Array(blob[64...])) else { throw KEM.Errors.publicKeyMismatchDuringInitialization }
        }
        public var integrityCheckedRepresentation: Data { Data(seed + _Keccak.sha3_256(publicKey.raw)) }
        public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
            let c = _bytes(encapsulated)
            guard c.count == MLKEM1024.p.ciphertextSize else { throw CryptoKitError.incorrectParameterSize }
            return SymmetricKey(data: MLKEM1024.p.decaps(dk, c))
        }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey { try decapsulate([UInt8](encapsulated)) }
    }    /// a key for one decapsulation (iOS 27)
    @available(iOS 27.0, *)
    public struct OneTimePrivateKey: KEMOneTimePrivateKey, Sendable {
        let key: PrivateKey
        let state = _OneTimeUse()
        public var publicKey: PublicKey { key.publicKey }
        public init() throws { key = try PrivateKey() }
        public static func generate() throws -> OneTimePrivateKey { try OneTimePrivateKey() }
        public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
            try state.take()
            return try key.decapsulate(encapsulated)
        }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey { try decapsulate([UInt8](encapsulated)) }
    }
}
