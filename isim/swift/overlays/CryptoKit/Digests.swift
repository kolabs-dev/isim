// isim CryptoKit: hash functions, HMAC, HKDF and SymmetricKey (self-authored, same API as Apple's CryptoKit).
// Digests run on isim's CommonCrypto (libSystem); HMAC and HKDF are built on them here, so they work for any
// HashFunction. Byte inputs are taken as ContiguousBytes (Data, [UInt8], keys and digests).
import Foundation
internal import CommonCrypto

public enum CryptoKitError: Error, Equatable {
    case incorrectKeySize
    case incorrectParameterSize
    case authenticationFailure
    case underlyingCoreCryptoError(error: Int32)
    case wrapFailure
    case unwrapFailure
    case invalidParameter
}

@inline(__always) func _bytes<D: ContiguousBytes>(_ d: D) -> [UInt8] { d.withUnsafeBytes { Array($0) } }
func _hex<S: Sequence>(_ s: S) -> String where S.Element == UInt8 {
    let digits = Array("0123456789abcdef".utf8)
    var out = [UInt8](); out.reserveCapacity(64)
    for b in s { out.append(digits[Int(b >> 4)]); out.append(digits[Int(b & 15)]) }
    return String(decoding: out, as: UTF8.self)
}
/// constant-time comparison
func _safeEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    guard a.count == b.count else { return false }
    var d: UInt8 = 0
    for i in 0..<a.count { d |= a[i] ^ b[i] }
    return d == 0
}

// MARK: - Protocols

public protocol Digest: Hashable, ContiguousBytes, CustomStringConvertible, Sequence where Element == UInt8 {
    static var byteCount: Int { get }
}
extension Digest {
    public static func == <D: ContiguousBytes>(lhs: Self, rhs: D) -> Bool { _safeEqual(_bytes(lhs), _bytes(rhs)) }
}

public protocol HashFunction {
    associatedtype Digest: CryptoKit.Digest
    static var blockByteCount: Int { get }
    init()
    mutating func update(bufferPointer: UnsafeRawBufferPointer)
    func finalize() -> Digest
}
extension HashFunction {
    public static var byteCount: Int { Digest.byteCount }
    public mutating func update<D: ContiguousBytes>(data: D) { data.withUnsafeBytes { update(bufferPointer: $0) } }
    public static func hash<D: ContiguousBytes>(data: D) -> Digest { var h = Self(); h.update(data: data); return h.finalize() }
    public static func hash(bufferPointer: UnsafeRawBufferPointer) -> Digest { var h = Self(); h.update(bufferPointer: bufferPointer); return h.finalize() }
}

public protocol MessageAuthenticationCode: Hashable, ContiguousBytes, CustomStringConvertible, Sequence where Element == UInt8 {
    var byteCount: Int { get }
}

// MARK: - CommonCrypto-backed contexts (stored in a byte array, so hashers are values like on iOS)

enum _Alg { case md5, sha1, sha256, sha384, sha512 }
struct _CCContext: Hashable {
    let alg: _Alg
    var ctx: [UInt8]
    init(_ alg: _Alg) {
        self.alg = alg
        ctx = [UInt8](repeating: 0, count: 208)
        ctx.withUnsafeMutableBytes { p in
            switch alg {
            case .md5: _ = CC_MD5_Init(p.baseAddress!.assumingMemoryBound(to: CC_MD5_CTX.self))
            case .sha1: _ = CC_SHA1_Init(p.baseAddress!.assumingMemoryBound(to: CC_SHA1_CTX.self))
            case .sha256: _ = CC_SHA256_Init(p.baseAddress!.assumingMemoryBound(to: CC_SHA256_CTX.self))
            case .sha384: _ = CC_SHA384_Init(p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self))
            case .sha512: _ = CC_SHA512_Init(p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self))
            }
        }
    }
    mutating func update(_ buf: UnsafeRawBufferPointer) {
        guard var base = buf.baseAddress, buf.count > 0 else { return }
        var left = buf.count
        let alg = self.alg
        ctx.withUnsafeMutableBytes { p in
            while left > 0 {
                let n = CC_LONG(min(left, 1 << 30))
                switch alg {
                case .md5: _ = CC_MD5_Update(p.baseAddress!.assumingMemoryBound(to: CC_MD5_CTX.self), base, n)
                case .sha1: _ = CC_SHA1_Update(p.baseAddress!.assumingMemoryBound(to: CC_SHA1_CTX.self), base, n)
                case .sha256: _ = CC_SHA256_Update(p.baseAddress!.assumingMemoryBound(to: CC_SHA256_CTX.self), base, n)
                case .sha384: _ = CC_SHA384_Update(p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self), base, n)
                case .sha512: _ = CC_SHA512_Update(p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self), base, n)
                }
                base += Int(n); left -= Int(n)
            }
        }
    }
    func finalize(_ count: Int) -> [UInt8] {
        var copy = ctx
        var out = [UInt8](repeating: 0, count: count)
        let alg = self.alg
        copy.withUnsafeMutableBytes { p in
            out.withUnsafeMutableBufferPointer { o in
                switch alg {
                case .md5: _ = CC_MD5_Final(o.baseAddress!, p.baseAddress!.assumingMemoryBound(to: CC_MD5_CTX.self))
                case .sha1: _ = CC_SHA1_Final(o.baseAddress!, p.baseAddress!.assumingMemoryBound(to: CC_SHA1_CTX.self))
                case .sha256: _ = CC_SHA256_Final(o.baseAddress!, p.baseAddress!.assumingMemoryBound(to: CC_SHA256_CTX.self))
                case .sha384: _ = CC_SHA384_Final(o.baseAddress!, p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self))
                case .sha512: _ = CC_SHA512_Final(o.baseAddress!, p.baseAddress!.assumingMemoryBound(to: CC_SHA512_CTX.self))
                }
            }
        }
        return out
    }
}

// MARK: - SHA-2

public struct SHA256Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 32 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA256 digest: \(_hex(bytes))" }
}
public struct SHA384Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 48 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA384 digest: \(_hex(bytes))" }
}
public struct SHA512Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 64 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA512 digest: \(_hex(bytes))" }
}

public struct SHA256: HashFunction {
    public typealias Digest = SHA256Digest
    var ctx = _CCContext(.sha256)
    public static var blockByteCount: Int { 64 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { ctx.update(bufferPointer) }
    public func finalize() -> SHA256Digest { SHA256Digest(bytes: ctx.finalize(32)) }
}
public struct SHA384: HashFunction {
    public typealias Digest = SHA384Digest
    var ctx = _CCContext(.sha384)
    public static var blockByteCount: Int { 128 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { ctx.update(bufferPointer) }
    public func finalize() -> SHA384Digest { SHA384Digest(bytes: ctx.finalize(48)) }
}
public struct SHA512: HashFunction {
    public typealias Digest = SHA512Digest
    var ctx = _CCContext(.sha512)
    public static var blockByteCount: Int { 128 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) { ctx.update(bufferPointer) }
    public func finalize() -> SHA512Digest { SHA512Digest(bytes: ctx.finalize(64)) }
}

// MARK: - Insecure (MD5, SHA-1: for compatibility only)

public enum Insecure {
    public struct MD5Digest: CryptoKit.Digest {
        let bytes: [UInt8]
        public static var byteCount: Int { 16 }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        public var description: String { "MD5 digest: \(_hex(bytes))" }
    }
    public struct SHA1Digest: CryptoKit.Digest {
        let bytes: [UInt8]
        public static var byteCount: Int { 20 }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        public var description: String { "SHA1 digest: \(_hex(bytes))" }
    }
    public struct MD5: HashFunction {
        public typealias Digest = MD5Digest
        var ctx = _CCContext(.md5)
        public static var blockByteCount: Int { 64 }
        public init() {}
        public mutating func update(bufferPointer: UnsafeRawBufferPointer) { ctx.update(bufferPointer) }
        public func finalize() -> MD5Digest { MD5Digest(bytes: ctx.finalize(16)) }
    }
    public struct SHA1: HashFunction {
        public typealias Digest = SHA1Digest
        var ctx = _CCContext(.sha1)
        public static var blockByteCount: Int { 64 }
        public init() {}
        public mutating func update(bufferPointer: UnsafeRawBufferPointer) { ctx.update(bufferPointer) }
        public func finalize() -> SHA1Digest { SHA1Digest(bytes: ctx.finalize(20)) }
    }
}

// MARK: - SymmetricKey

public struct SymmetricKeySize: Sendable {
    public let bitCount: Int
    public init(bitCount: Int) { precondition(bitCount > 0 && bitCount % 8 == 0); self.bitCount = bitCount }
    public static var bits128: SymmetricKeySize { SymmetricKeySize(bitCount: 128) }
    public static var bits192: SymmetricKeySize { SymmetricKeySize(bitCount: 192) }
    public static var bits256: SymmetricKeySize { SymmetricKeySize(bitCount: 256) }
}

func _randomBytes(_ n: Int) -> [UInt8] {
    var b = [UInt8](repeating: 0, count: n)
    if n > 0 { b.withUnsafeMutableBytes { _ = CCRandomGenerateBytes($0.baseAddress!, n) } }
    return b
}

public struct SymmetricKey: ContiguousBytes, Equatable, Sendable {
    let bytes: [UInt8]
    public init<D: ContiguousBytes>(data: D) { bytes = _bytes(data) }
    public init(size: SymmetricKeySize) { bytes = _randomBytes(size.bitCount / 8) }
    public var bitCount: Int { bytes.count * 8 }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public static func == (a: SymmetricKey, b: SymmetricKey) -> Bool { _safeEqual(a.bytes, b.bytes) }
}

// MARK: - HMAC

public struct HashedAuthenticationCode<H: HashFunction>: MessageAuthenticationCode {
    let bytes: [UInt8]
    public var byteCount: Int { bytes.count }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "HMAC with \(H.self): \(_hex(bytes))" }
    public static func == (a: Self, b: Self) -> Bool { _safeEqual(a.bytes, b.bytes) }
    public static func == <D: ContiguousBytes>(lhs: Self, rhs: D) -> Bool { _safeEqual(lhs.bytes, _bytes(rhs)) }
    public func hash(into h: inout Hasher) { h.combine(bytes) }
}

public struct HMAC<H: HashFunction> {
    public typealias Key = SymmetricKey
    public typealias MAC = HashedAuthenticationCode<H>
    var inner = H(), outer = H()
    public init(key: SymmetricKey) {
        var k = key.bytes
        if k.count > H.blockByteCount { k = Array(H.hash(data: k)) }
        k += [UInt8](repeating: 0, count: H.blockByteCount - k.count)
        inner.update(data: k.map { $0 ^ 0x36 })
        outer.update(data: k.map { $0 ^ 0x5c })
    }
    public mutating func update<D: ContiguousBytes>(data: D) { inner.update(data: data) }
    public func finalize() -> HashedAuthenticationCode<H> {
        var o = outer
        o.update(data: Array(inner.finalize()))
        return HashedAuthenticationCode(bytes: Array(o.finalize()))
    }
    public static func authenticationCode<D: ContiguousBytes>(for data: D, using key: SymmetricKey) -> HashedAuthenticationCode<H> {
        var h = HMAC(key: key); h.update(data: data); return h.finalize()
    }
    public static func isValidAuthenticationCode<C: ContiguousBytes, D: ContiguousBytes>(_ mac: C, authenticating data: D, using key: SymmetricKey) -> Bool {
        _safeEqual(authenticationCode(for: data, using: key).bytes, _bytes(mac))
    }
    public static func isValidAuthenticationCode<D: ContiguousBytes>(_ code: HashedAuthenticationCode<H>, authenticating data: D, using key: SymmetricKey) -> Bool {
        _safeEqual(authenticationCode(for: data, using: key).bytes, code.bytes)
    }
}

// MARK: - HKDF (RFC 5869)

public struct HKDF<H: HashFunction> {
    public static func extract<Salt: ContiguousBytes>(inputKeyMaterial: SymmetricKey, salt: Salt?) -> HashedAuthenticationCode<H> {
        let s = salt.map { _bytes($0) } ?? []
        return HMAC<H>.authenticationCode(for: inputKeyMaterial.bytes, using: SymmetricKey(data: s.isEmpty ? [UInt8](repeating: 0, count: H.byteCount) : s))
    }
    public static func expand<PRK: ContiguousBytes, Info: ContiguousBytes>(pseudoRandomKey prk: PRK, info: Info?, outputByteCount: Int) -> SymmetricKey {
        let key = SymmetricKey(data: prk), inf = info.map { _bytes($0) } ?? []
        precondition(outputByteCount <= 255 * H.byteCount, "HKDF output too long")
        var out = [UInt8](), t = [UInt8](), counter: UInt8 = 1
        while out.count < outputByteCount {
            var h = HMAC<H>(key: key)
            h.update(data: t); h.update(data: inf); h.update(data: [counter])
            t = Array(h.finalize())
            out += t; counter &+= 1
        }
        return SymmetricKey(data: Array(out.prefix(outputByteCount)))
    }
    public static func deriveKey<Salt: ContiguousBytes, Info: ContiguousBytes>(inputKeyMaterial: SymmetricKey, salt: Salt, info: Info, outputByteCount: Int) -> SymmetricKey {
        expand(pseudoRandomKey: extract(inputKeyMaterial: inputKeyMaterial, salt: salt), info: info, outputByteCount: outputByteCount)
    }
    public static func deriveKey<Info: ContiguousBytes>(inputKeyMaterial: SymmetricKey, info: Info, outputByteCount: Int) -> SymmetricKey {
        deriveKey(inputKeyMaterial: inputKeyMaterial, salt: [UInt8](), info: info, outputByteCount: outputByteCount)
    }
    public static func deriveKey(inputKeyMaterial: SymmetricKey, outputByteCount: Int) -> SymmetricKey {
        deriveKey(inputKeyMaterial: inputKeyMaterial, salt: [UInt8](), info: [UInt8](), outputByteCount: outputByteCount)
    }
}
