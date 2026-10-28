// isim CryptoKit: SHA-3 (FIPS 202; iOS 26) and the SHAKE extendable-output functions ML-KEM, ML-DSA and X-Wing are
// built on. Keccak-f[1600] is implemented here in Swift (adapted: no host library needed), with the same API as
// Apple's SHA3_256 / SHA3_384 / SHA3_512.
import Foundation

/// the Keccak sponge: rate in bytes, domain-separation suffix (0x06 SHA-3, 0x1f SHAKE)
struct _Keccak: Hashable, Sendable {
    var s = [UInt64](repeating: 0, count: 25)
    var buf = [UInt8](), squeezed = [UInt8]()
    let rate: Int, suffix: UInt8
    var finished = false
    init(rate: Int, suffix: UInt8) { self.rate = rate; self.suffix = suffix; buf.reserveCapacity(rate) }
    static func shake128() -> _Keccak { _Keccak(rate: 168, suffix: 0x1f) }
    static func shake256() -> _Keccak { _Keccak(rate: 136, suffix: 0x1f) }

    static let rc: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
        0x8000000080008081, 0x8000000000008009, 0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
        0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
        0x000000000000800a, 0x800000008000000a, 0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008]
    static let rotc: [UInt64] = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44]
    static let piln = [10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1]

    static func permute(_ a: inout [UInt64]) {
        a.withUnsafeMutableBufferPointer { st in
            var bc = (UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0))
            for round in 0..<24 {
                bc.0 = st[0] ^ st[5] ^ st[10] ^ st[15] ^ st[20]
                bc.1 = st[1] ^ st[6] ^ st[11] ^ st[16] ^ st[21]
                bc.2 = st[2] ^ st[7] ^ st[12] ^ st[17] ^ st[22]
                bc.3 = st[3] ^ st[8] ^ st[13] ^ st[18] ^ st[23]
                bc.4 = st[4] ^ st[9] ^ st[14] ^ st[19] ^ st[24]
                let d0 = bc.4 ^ (bc.1 << 1 | bc.1 >> 63), d1 = bc.0 ^ (bc.2 << 1 | bc.2 >> 63), d2 = bc.1 ^ (bc.3 << 1 | bc.3 >> 63)
                let d3 = bc.2 ^ (bc.4 << 1 | bc.4 >> 63), d4 = bc.3 ^ (bc.0 << 1 | bc.0 >> 63)
                for j in stride(from: 0, to: 25, by: 5) { st[j] ^= d0; st[j + 1] ^= d1; st[j + 2] ^= d2; st[j + 3] ^= d3; st[j + 4] ^= d4 }
                var t = st[1]
                for i in 0..<24 {
                    let j = piln[i], r = rotc[i], tmp = st[j]
                    st[j] = t << r | t >> (64 - r)
                    t = tmp
                }
                for j in stride(from: 0, to: 25, by: 5) {
                    let a0 = st[j], a1 = st[j + 1], a2 = st[j + 2], a3 = st[j + 3], a4 = st[j + 4]
                    st[j] = a0 ^ (~a1 & a2); st[j + 1] = a1 ^ (~a2 & a3); st[j + 2] = a2 ^ (~a3 & a4)
                    st[j + 3] = a3 ^ (~a4 & a0); st[j + 4] = a4 ^ (~a0 & a1)
                }
                st[0] ^= rc[round]
            }
        }
    }
    mutating func absorbBlock(_ p: UnsafeRawBufferPointer) {
        for i in 0..<(rate / 8) {
            var w: UInt64 = 0
            for k in 0..<8 { w |= UInt64(p[i * 8 + k]) << (8 * UInt64(k)) }
            s[i] ^= w
        }
        _Keccak.permute(&s)
    }
    mutating func update(_ p: UnsafeRawBufferPointer) {
        precondition(!finished, "Keccak: update after squeezing")
        var off = 0
        if !buf.isEmpty {
            let n = min(rate - buf.count, p.count)
            buf += p[0..<n]; off = n
            if buf.count == rate { let b = buf; b.withUnsafeBytes { absorbBlock($0) }; buf.removeAll(keepingCapacity: true) }
        }
        while p.count - off >= rate { absorbBlock(UnsafeRawBufferPointer(rebasing: p[off..<(off + rate)])); off += rate }
        if off < p.count { buf += p[off...] }
    }
    mutating func update(_ b: [UInt8]) { b.withUnsafeBytes { update($0) } }
    mutating func pad() {
        var block = buf + [UInt8](repeating: 0, count: rate - buf.count)
        block[buf.count] ^= suffix
        block[rate - 1] ^= 0x80
        block.withUnsafeBytes { absorbBlock($0) }
        buf.removeAll()
        finished = true
    }
    /// squeezes `n` more bytes (SHAKE may be read incrementally)
    mutating func squeeze(_ n: Int) -> [UInt8] {
        if !finished { pad(); squeezed = stateBytes() }
        var out = [UInt8](); out.reserveCapacity(n)
        while out.count < n {
            if squeezed.isEmpty { _Keccak.permute(&s); squeezed = stateBytes() }
            let k = min(n - out.count, squeezed.count)
            out += squeezed[0..<k]; squeezed.removeFirst(k)
        }
        return out
    }
    func stateBytes() -> [UInt8] {
        var o = [UInt8](repeating: 0, count: rate)
        for i in 0..<rate { o[i] = UInt8(truncatingIfNeeded: s[i / 8] >> (8 * UInt64(i % 8))) }
        return o
    }
    func digest(_ n: Int) -> [UInt8] { var c = self; return c.squeeze(n) }

    static func shake256(_ input: [UInt8], _ n: Int) -> [UInt8] { var k = shake256(); k.update(input); return k.squeeze(n) }
    static func shake128(_ input: [UInt8], _ n: Int) -> [UInt8] { var k = shake128(); k.update(input); return k.squeeze(n) }
    static func sha3_256(_ input: [UInt8]) -> [UInt8] { var k = _Keccak(rate: 136, suffix: 0x06); k.update(input); return k.squeeze(32) }
    static func sha3_512(_ input: [UInt8]) -> [UInt8] { var k = _Keccak(rate: 72, suffix: 0x06); k.update(input); return k.squeeze(64) }
}

// MARK: - SHA-3

@available(iOS 26.0, *)
public struct SHA3_256Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 32 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA3-256 digest: \(_hex(bytes))" }
}
@available(iOS 26.0, *)
public struct SHA3_384Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 48 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA3-384 digest: \(_hex(bytes))" }
}
@available(iOS 26.0, *)
public struct SHA3_512Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 64 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA3-512 digest: \(_hex(bytes))" }
}

@available(iOS 26.0, *)
public struct SHA3_256: HashFunction, Sendable {
    public typealias Digest = SHA3_256Digest
    var k = _Keccak(rate: 136, suffix: 0x06)
    public static let blockByteCount = 136
    public static let byteCount = 32
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { k.update(bufferPointer) }
    public func finalize() -> SHA3_256Digest { SHA3_256Digest(bytes: k.digest(32)) }
}
@available(iOS 26.0, *)
public struct SHA3_384: HashFunction, Sendable {
    public typealias Digest = SHA3_384Digest
    var k = _Keccak(rate: 104, suffix: 0x06)
    public static let blockByteCount = 104
    public static let byteCount = 48
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { k.update(bufferPointer) }
    public func finalize() -> SHA3_384Digest { SHA3_384Digest(bytes: k.digest(48)) }
}
@available(iOS 26.0, *)
public struct SHA3_512: HashFunction, Sendable {
    public typealias Digest = SHA3_512Digest
    var k = _Keccak(rate: 72, suffix: 0x06)
    public static let blockByteCount = 72
    public static let byteCount = 64
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { k.update(bufferPointer) }
    public func finalize() -> SHA3_512Digest { SHA3_512Digest(bytes: k.digest(64)) }
}
