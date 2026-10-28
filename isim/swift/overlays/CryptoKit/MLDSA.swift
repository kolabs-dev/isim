// isim CryptoKit: ML-DSA-65 and ML-DSA-87 signatures (FIPS 204; iOS 26). Implemented here in Swift (adapted: no host
// library needed) on isim's SHAKE; same API as Apple's MLDSA65 / MLDSA87. Signing is hedged (fresh randomness per
// signature, FIPS 204's default) and takes FIPS 204's context string (up to 255 bytes, empty by default). A private
// key's seedRepresentation is the 32-byte seed ξ of ML-DSA.KeyGen_internal; its integrityCheckedRepresentation is the
// seed followed by SHA3-256 of the public key.
import Foundation

struct _MLDSA {
    static let q = 8380417, d = 13
    let k: Int, l: Int, eta: Int, tau: Int, beta: Int, gamma1: Int, gamma2: Int, omega: Int, lambda: Int
    static let p65 = _MLDSA(k: 6, l: 5, eta: 4, tau: 49, beta: 196, gamma1: 1 << 19, gamma2: (q - 1) / 32, omega: 55, lambda: 192)
    static let p87 = _MLDSA(k: 8, l: 7, eta: 2, tau: 60, beta: 120, gamma1: 1 << 19, gamma2: (q - 1) / 32, omega: 75, lambda: 256)
    var publicKeySize: Int { 32 + 320 * k }
    var signatureSize: Int { lambda / 4 + l * 32 * 20 + omega + k }
    var etaBits: Int { eta == 2 ? 3 : 4 }

    typealias Poly = [Int]
    static func mod(_ a: Int) -> Int { let r = a % q; return r < 0 ? r + q : r }
    /// r mod± a: in (-a/2, a/2]
    static func modpm(_ r: Int, _ a: Int) -> Int { var x = r % a; if x < 0 { x += a }; if x > a / 2 { x -= a }; return x }
    static func pow(_ b: Int, _ e: Int) -> Int { var r = 1, x = b % q, e = e; while e > 0 { if e & 1 == 1 { r = r * x % q }; x = x * x % q; e >>= 1 }; return r }
    static func bitrev8(_ i: Int) -> Int { var r = 0; for b in 0..<8 where i & (1 << b) != 0 { r |= 1 << (7 - b) }; return r }
    static let zetas: [Int] = (0..<256).map { pow(1753, bitrev8($0)) }

    static func ntt(_ f: Poly) -> Poly {
        var w = f.map(mod), m = 0, len = 128
        while len >= 1 {
            for start in stride(from: 0, to: 256, by: 2 * len) {
                m += 1
                let z = zetas[m]
                for j in start..<(start + len) {
                    let t = z * w[j + len] % q
                    w[j + len] = mod(w[j] - t)
                    w[j] = (w[j] + t) % q
                }
            }
            len >>= 1
        }
        return w
    }
    static func invNTT(_ f: Poly) -> Poly {
        var w = f, m = 256, len = 1
        while len < 256 {
            for start in stride(from: 0, to: 256, by: 2 * len) {
                m -= 1
                let z = q - zetas[m]
                for j in start..<(start + len) {
                    let t = w[j]
                    w[j] = (t + w[j + len]) % q
                    w[j + len] = z * mod(t - w[j + len]) % q
                }
            }
            len <<= 1
        }
        return w.map { $0 * 8347681 % q }
    }
    static func mul(_ a: Poly, _ b: Poly) -> Poly { (0..<256).map { a[$0] * b[$0] % q } }
    static func add(_ a: Poly, _ b: Poly) -> Poly { (0..<256).map { mod(a[$0] + b[$0]) } }
    static func sub(_ a: Poly, _ b: Poly) -> Poly { (0..<256).map { mod(a[$0] - b[$0]) } }
    static let zero = Poly(repeating: 0, count: 256)

    // packing: SimpleBitPack (0...b) and BitPack (-a...b, stored as b - w)
    static func pack(_ f: Poly, bits: Int, offset: Int?) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 32 * bits), bit = 0
        for c in f {
            let v = offset.map { $0 - c } ?? c
            for b in 0..<bits { if (v >> b) & 1 == 1 { out[bit >> 3] |= 1 << (bit & 7) }; bit += 1 }
        }
        return out
    }
    static func unpack(_ bytes: ArraySlice<UInt8>, bits: Int, offset: Int?) -> Poly {
        let base = bytes.startIndex
        var f = Poly(repeating: 0, count: 256), bit = 0
        for i in 0..<256 {
            var v = 0
            for b in 0..<bits { v |= Int((bytes[base + (bit >> 3)] >> (bit & 7)) & 1) << b; bit += 1 }
            f[i] = offset.map { $0 - v } ?? v
        }
        return f
    }

    static func rejNTTPoly(_ seed: [UInt8]) -> Poly {
        var xof = _Keccak.shake128(); xof.update(seed)
        var a = Poly(), buf = [UInt8](), p = 0
        a.reserveCapacity(256)
        while a.count < 256 {
            if p + 3 > buf.count { buf = xof.squeeze(168); p = 0 }
            let v = Int(buf[p]) | Int(buf[p + 1]) << 8 | (Int(buf[p + 2]) & 0x7f) << 16
            p += 3
            if v < q { a.append(v) }
        }
        return a
    }
    func rejBoundedPoly(_ seed: [UInt8]) -> Poly {
        var xof = _Keccak.shake256(); xof.update(seed)
        var a = Poly(), buf = [UInt8](), p = 0
        func coeff(_ b: Int) -> Int? {
            if eta == 2 { return b < 15 ? 2 - b % 5 : nil }
            return b < 9 ? 4 - b : nil
        }
        while a.count < 256 {
            if p >= buf.count { buf = xof.squeeze(136); p = 0 }
            let z = Int(buf[p]); p += 1
            if let c = coeff(z & 15) { a.append(c) }
            if a.count < 256, let c = coeff(z >> 4) { a.append(c) }
        }
        return a
    }
    func expandA(_ rho: [UInt8]) -> [[Poly]] {
        (0..<k).map { r in (0..<l).map { s in _MLDSA.rejNTTPoly(rho + [UInt8(s), UInt8(r)]) } }
    }
    func expandMask(_ rho: [UInt8], _ kappa: Int) -> [Poly] {
        (0..<l).map { r in
            let n = kappa + r
            return _MLDSA.unpack(_Keccak.shake256(rho + [UInt8(n & 0xff), UInt8(n >> 8)], 32 * 20)[...], bits: 20, offset: gamma1)
        }
    }
    func sampleInBall(_ rho: [UInt8]) -> Poly {
        var xof = _Keccak.shake256(); xof.update(rho)
        let s = xof.squeeze(8)
        var h: UInt64 = 0
        for i in 0..<8 { h |= UInt64(s[i]) << (8 * UInt64(i)) }
        var c = _MLDSA.zero
        for i in (256 - tau)..<256 {
            var j = Int(xof.squeeze(1)[0])
            while j > i { j = Int(xof.squeeze(1)[0]) }
            c[i] = c[j]
            c[j] = (h >> UInt64(i + tau - 256)) & 1 == 1 ? _MLDSA.q - 1 : 1
        }
        return c
    }
    func decompose(_ r: Int) -> (Int, Int) {
        let rp = _MLDSA.mod(r)
        var r0 = _MLDSA.modpm(rp, 2 * gamma2)
        if rp - r0 == _MLDSA.q - 1 { r0 -= 1; return (0, r0) }
        return ((rp - r0) / (2 * gamma2), r0)
    }
    func useHint(_ h: Int, _ r: Int) -> Int {
        let m = (_MLDSA.q - 1) / (2 * gamma2)
        let (r1, r0) = decompose(r)
        if h == 1 { return r0 > 0 ? (r1 + 1) % m : (r1 - 1 + m) % m }
        return r1
    }
    static func infNorm(_ f: Poly) -> Int { f.reduce(0) { Swift.max($0, abs(modpm($1, q))) } }
    func w1Encode(_ w1: [Poly]) -> [UInt8] { w1.flatMap { _MLDSA.pack($0, bits: 4, offset: nil) } }

    /// the expanded private key
    struct Key {
        let rho: [UInt8], key: [UInt8], tr: [UInt8]
        let s1: [_MLDSA.Poly], s2: [_MLDSA.Poly], t0: [_MLDSA.Poly]
        let pk: [UInt8]
    }
    func keyGen(_ xi: [UInt8]) -> Key {
        let h = _Keccak.shake256(xi + [UInt8(k), UInt8(l)], 128)
        let rho = Array(h[0..<32]), rhoP = Array(h[32..<96]), key = Array(h[96..<128])
        let a = expandA(rho)
        let s1 = (0..<l).map { rejBoundedPoly(rhoP + [UInt8($0), 0]) }
        let s2 = (0..<k).map { rejBoundedPoly(rhoP + [UInt8($0 + l), 0]) }
        let s1h = s1.map(_MLDSA.ntt)
        var pk = rho, t0 = [Poly]()
        for i in 0..<k {
            var acc = _MLDSA.zero
            for j in 0..<l { acc = _MLDSA.add(acc, _MLDSA.mul(a[i][j], s1h[j])) }
            let t = _MLDSA.add(_MLDSA.invNTT(acc), s2[i])
            var hi = Poly(repeating: 0, count: 256), lo = Poly(repeating: 0, count: 256)
            for c in 0..<256 {
                let r0 = _MLDSA.modpm(t[c], 1 << _MLDSA.d)
                lo[c] = r0; hi[c] = (t[c] - r0) >> _MLDSA.d
            }
            pk += _MLDSA.pack(hi, bits: 10, offset: nil)
            t0.append(lo)
        }
        return Key(rho: rho, key: key, tr: _Keccak.shake256(pk, 64), s1: s1, s2: s2, t0: t0, pk: pk)
    }
    /// ML-DSA.Sign_internal on M' (already prefixed with the context), with the 32-byte rnd
    func sign(_ sk: Key, _ mPrime: [UInt8], rnd: [UInt8]) -> [UInt8] {
        let a = expandA(sk.rho)
        let s1h = sk.s1.map { _MLDSA.ntt($0.map(_MLDSA.mod)) }, s2h = sk.s2.map { _MLDSA.ntt($0.map(_MLDSA.mod)) }
        let t0h = sk.t0.map { _MLDSA.ntt($0.map(_MLDSA.mod)) }
        let mu = _Keccak.shake256(sk.tr + mPrime, 64)
        let rhoPP = _Keccak.shake256(sk.key + rnd + mu, 64)
        var kappa = 0
        while true {
            let y = expandMask(rhoPP, kappa)
            kappa += l
            let yh = y.map { _MLDSA.ntt($0) }
            let w = (0..<k).map { i in
                _MLDSA.invNTT((0..<l).reduce(_MLDSA.zero) { _MLDSA.add($0, _MLDSA.mul(a[i][$1], yh[$1])) })
            }
            let w1 = w.map { $0.map { decompose($0).0 } }
            let cTilde = _Keccak.shake256(mu + w1Encode(w1), lambda / 4)
            let ch = _MLDSA.ntt(sampleInBall(cTilde))
            let z = (0..<l).map { _MLDSA.add(y[$0], _MLDSA.invNTT(_MLDSA.mul(ch, s1h[$0]))) }
            let wcs2 = (0..<k).map { _MLDSA.sub(w[$0], _MLDSA.invNTT(_MLDSA.mul(ch, s2h[$0]))) }
            if z.contains(where: { _MLDSA.infNorm($0) >= gamma1 - beta }) { continue }
            if wcs2.contains(where: { $0.contains { abs(decompose($0).1) >= gamma2 - beta } }) { continue }
            let ct0 = (0..<k).map { _MLDSA.invNTT(_MLDSA.mul(ch, t0h[$0])) }
            if ct0.contains(where: { _MLDSA.infNorm($0) >= gamma2 }) { continue }
            var hints = [[Int]](), count = 0
            for i in 0..<k {
                // MakeHint(-ct0, w - cs2 + ct0): does adding -ct0 change the high bits of w - cs2 + ct0
                var row = [Int]()
                for c in 0..<256 {
                    let r = _MLDSA.mod(wcs2[i][c] + ct0[i][c])
                    if decompose(r).0 != decompose(wcs2[i][c]).0 { row.append(c) }
                }
                count += row.count; hints.append(row)
            }
            if count > omega { continue }
            var sig = cTilde
            for p in z { sig += _MLDSA.pack(p.map { _MLDSA.modpm($0, _MLDSA.q) }, bits: 20, offset: gamma1) }
            var hb = [UInt8](repeating: 0, count: omega + k), idx = 0
            for i in 0..<k { for c in hints[i] { hb[idx] = UInt8(c); idx += 1 }; hb[omega + i] = UInt8(idx) }
            return sig + hb
        }
    }
    func verify(_ pk: [UInt8], _ mPrime: [UInt8], _ sig: [UInt8]) -> Bool {
        guard pk.count == publicKeySize, sig.count == signatureSize else { return false }
        let rho = Array(pk[0..<32])
        let t1 = (0..<k).map { _MLDSA.unpack(pk[(32 + 320 * $0)..<(32 + 320 * $0 + 320)], bits: 10, offset: nil) }
        let ct = lambda / 4
        let cTilde = Array(sig[0..<ct])
        let z = (0..<l).map { _MLDSA.unpack(sig[(ct + 640 * $0)..<(ct + 640 * $0 + 640)], bits: 20, offset: gamma1) }
        // HintBitUnpack, rejecting malformed hints
        let hb = Array(sig[(ct + 640 * l)...])
        var h = [Poly](repeating: _MLDSA.zero, count: k), idx = 0
        for i in 0..<k {
            let end = Int(hb[omega + i])
            guard end >= idx, end <= omega else { return false }
            let first = idx
            while idx < end {
                if idx > first && hb[idx - 1] >= hb[idx] { return false }
                h[i][Int(hb[idx])] = 1; idx += 1
            }
        }
        for i in idx..<omega where hb[i] != 0 { return false }
        if z.contains(where: { _MLDSA.infNorm($0) >= gamma1 - beta }) { return false }
        let a = expandA(rho)
        let mu = _Keccak.shake256(_Keccak.shake256(pk, 64) + mPrime, 64)
        let ch = _MLDSA.ntt(sampleInBall(cTilde))
        let zh = z.map { _MLDSA.ntt($0) }
        var w1 = [Poly]()
        for i in 0..<k {
            let az = (0..<l).reduce(_MLDSA.zero) { _MLDSA.add($0, _MLDSA.mul(a[i][$1], zh[$1])) }
            let ct1 = _MLDSA.mul(ch, _MLDSA.ntt(t1[i].map { $0 << _MLDSA.d }))
            let wApprox = _MLDSA.invNTT(_MLDSA.sub(az, ct1))
            w1.append((0..<256).map { useHint(h[i][$0], wApprox[$0]) })
        }
        return _safeEqual(cTilde, _Keccak.shake256(mu + w1Encode(w1), ct))
    }
    /// M' = 0 ‖ |ctx| ‖ ctx ‖ M (pure ML-DSA)
    static func message(_ m: [UInt8], context: [UInt8]) throws -> [UInt8] {
        guard context.count <= 255 else { throw CryptoKitError.incorrectParameterSize }
        return [0, UInt8(context.count)] + context + m
    }
}

// MARK: - MLDSA65 / MLDSA87

@available(iOS 26.0, *)
public enum MLDSA65 {
    static let p = _MLDSA.p65
    public struct PublicKey: Sendable {
        let raw: [UInt8]
        init(raw: [UInt8]) { self.raw = raw }
        public init<D: ContiguousBytes>(rawRepresentation: D) throws {
            raw = _bytes(rawRepresentation)
            guard raw.count == MLDSA65.p.publicKeySize else { throw CryptoKitError.incorrectKeySize }
        }
        public var rawRepresentation: Data { Data(raw) }
        public func isValidSignature<S: ContiguousBytes, D: ContiguousBytes>(_ signature: S, for data: D) -> Bool {
            isValidSignature(signature, for: data, context: [UInt8]())
        }
        public func isValidSignature<S: ContiguousBytes, D: ContiguousBytes, C: ContiguousBytes>(_ signature: S, for data: D, context: C) -> Bool {
            guard let m = try? _MLDSA.message(_bytes(data), context: _bytes(context)) else { return false }
            return MLDSA65.p.verify(raw, m, _bytes(signature))
        }
    }
    public struct PrivateKey: Sendable {
        let seed: [UInt8]
        let key: _MLDSA.Key
        public init() throws { try self.init(seed: _randomBytes(32), publicKey: nil) }
        init(seed: [UInt8], publicKey pk: [UInt8]?) throws {
            guard seed.count == 32 else { throw CryptoKitError.incorrectKeySize }
            key = MLDSA65.p.keyGen(seed)
            if let pk, !_safeEqual(pk, key.pk) { throw KEM.Errors.publicKeyMismatchDuringInitialization }
            self.seed = seed
        }
        public init<D: ContiguousBytes>(seedRepresentation: D, publicKey: PublicKey?) throws {
            try self.init(seed: _bytes(seedRepresentation), publicKey: publicKey?.raw)
        }
        public var seedRepresentation: Data { Data(seed) }
        public init<D: ContiguousBytes>(integrityCheckedRepresentation: D) throws {
            let blob = _bytes(integrityCheckedRepresentation)
            try self.init(seed: try _integrityChecked(blob, seedCount: 32), publicKey: nil)
            guard _safeEqual(_Keccak.sha3_256(key.pk), Array(blob[32...])) else { throw KEM.Errors.publicKeyMismatchDuringInitialization }
        }
        public var integrityCheckedRepresentation: Data { Data(seed + _Keccak.sha3_256(key.pk)) }
        public var publicKey: PublicKey { PublicKey(raw: key.pk) }
        public func signature<D: ContiguousBytes>(for data: D) throws -> Data { try signature(for: data, context: [UInt8]()) }
        public func signature<D: ContiguousBytes, C: ContiguousBytes>(for data: D, context: C) throws -> Data {
            Data(MLDSA65.p.sign(key, try _MLDSA.message(_bytes(data), context: _bytes(context)), rnd: _randomBytes(32)))
        }
        /// FIPS 204's deterministic variant (rnd = 0), for known-answer tests
        @_spi(isim) public func _deterministicSignature(for data: [UInt8], context: [UInt8]) throws -> Data {
            Data(MLDSA65.p.sign(key, try _MLDSA.message(data, context: context), rnd: [UInt8](repeating: 0, count: 32)))
        }
    }
}

@available(iOS 26.0, *)
public enum MLDSA87 {
    static let p = _MLDSA.p87
    public struct PublicKey: Sendable {
        let raw: [UInt8]
        init(raw: [UInt8]) { self.raw = raw }
        public init<D: ContiguousBytes>(rawRepresentation: D) throws {
            raw = _bytes(rawRepresentation)
            guard raw.count == MLDSA87.p.publicKeySize else { throw CryptoKitError.incorrectKeySize }
        }
        public var rawRepresentation: Data { Data(raw) }
        public func isValidSignature<S: ContiguousBytes, D: ContiguousBytes>(_ signature: S, for data: D) -> Bool {
            isValidSignature(signature, for: data, context: [UInt8]())
        }
        public func isValidSignature<S: ContiguousBytes, D: ContiguousBytes, C: ContiguousBytes>(_ signature: S, for data: D, context: C) -> Bool {
            guard let m = try? _MLDSA.message(_bytes(data), context: _bytes(context)) else { return false }
            return MLDSA87.p.verify(raw, m, _bytes(signature))
        }
    }
    public struct PrivateKey: Sendable {
        let seed: [UInt8]
        let key: _MLDSA.Key
        public init() throws { try self.init(seed: _randomBytes(32), publicKey: nil) }
        init(seed: [UInt8], publicKey pk: [UInt8]?) throws {
            guard seed.count == 32 else { throw CryptoKitError.incorrectKeySize }
            key = MLDSA87.p.keyGen(seed)
            if let pk, !_safeEqual(pk, key.pk) { throw KEM.Errors.publicKeyMismatchDuringInitialization }
            self.seed = seed
        }
        public init<D: ContiguousBytes>(seedRepresentation: D, publicKey: PublicKey?) throws {
            try self.init(seed: _bytes(seedRepresentation), publicKey: publicKey?.raw)
        }
        public var seedRepresentation: Data { Data(seed) }
        public init<D: ContiguousBytes>(integrityCheckedRepresentation: D) throws {
            let blob = _bytes(integrityCheckedRepresentation)
            try self.init(seed: try _integrityChecked(blob, seedCount: 32), publicKey: nil)
            guard _safeEqual(_Keccak.sha3_256(key.pk), Array(blob[32...])) else { throw KEM.Errors.publicKeyMismatchDuringInitialization }
        }
        public var integrityCheckedRepresentation: Data { Data(seed + _Keccak.sha3_256(key.pk)) }
        public var publicKey: PublicKey { PublicKey(raw: key.pk) }
        public func signature<D: ContiguousBytes>(for data: D) throws -> Data { try signature(for: data, context: [UInt8]()) }
        public func signature<D: ContiguousBytes, C: ContiguousBytes>(for data: D, context: C) throws -> Data {
            Data(MLDSA87.p.sign(key, try _MLDSA.message(_bytes(data), context: _bytes(context)), rnd: _randomBytes(32)))
        }
        /// FIPS 204's deterministic variant (rnd = 0), for known-answer tests
        @_spi(isim) public func _deterministicSignature(for data: [UInt8], context: [UInt8]) throws -> Data {
            Data(MLDSA87.p.sign(key, try _MLDSA.message(data, context: context), rnd: [UInt8](repeating: 0, count: 32)))
        }
    }
}
