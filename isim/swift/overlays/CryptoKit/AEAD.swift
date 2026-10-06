// isim CryptoKit: AES-GCM and ChaChaPoly authenticated encryption (host OpenSSL libcrypto via libisim_host).
import Foundation
internal import isim_host

func _requireCrypto() {
    if isim_crypto_available() == 0 {
        fatalError("isim CryptoKit: OpenSSL libcrypto (libcrypto.so.3) is not installed on this host; AES, ChaChaPoly and public-key operations need it")
    }
}

/// seal (encrypt) or open (decrypt + verify): alg 0 AES-GCM, 1 ChaCha20-Poly1305
func _aead(_ alg: Int32, encrypt: Bool, key: [UInt8], nonce: [UInt8], aad: [UInt8], input: [UInt8], tag: inout [UInt8]) throws -> [UInt8] {
    _requireCrypto()
    var out = [UInt8](repeating: 0, count: max(input.count, 1))
    let r = key.withUnsafeBytes { k in nonce.withUnsafeBytes { n in aad.withUnsafeBytes { a in input.withUnsafeBytes { i in
        out.withUnsafeMutableBytes { o in tag.withUnsafeMutableBytes { t in
            isim_crypto_aead(alg, encrypt ? 1 : 0, k.baseAddress!, k.count, n.baseAddress!, n.count, a.baseAddress, a.count,
                             i.baseAddress, i.count, o.baseAddress, t.baseAddress!)
        } }
    } } } }
    guard r == 1 else { throw encrypt ? CryptoKitError.underlyingCoreCryptoError(error: -1) : CryptoKitError.authenticationFailure }
    return Array(out.prefix(input.count))
}

public enum AES {
    public enum GCM {
        static let tagByteCount = 16
        public struct Nonce: ContiguousBytes, Sequence, Sendable {
            let bytes: [UInt8]
            public init() { bytes = _randomBytes(12) }
            public init<D: ContiguousBytes>(data: D) throws {
                let b = _bytes(data)
                guard b.count >= 12 else { throw CryptoKitError.incorrectParameterSize }
                bytes = b
            }
            public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        }
        public struct SealedBox: Sendable {
            public let nonce: Nonce
            public let ciphertext: Data
            public let tag: Data
            /// nonce || ciphertext || tag; nil when the nonce is not the standard 12 bytes
            public var combined: Data? { nonce.bytes.count == 12 ? Data(nonce.bytes + Array(ciphertext) + Array(tag)) : nil }
            public init<D: ContiguousBytes>(combined: D) throws {
                let b = _bytes(combined)
                guard b.count >= 12 + GCM.tagByteCount else { throw CryptoKitError.incorrectParameterSize }
                nonce = try Nonce(data: Array(b[0..<12]))
                ciphertext = Data(b[12..<(b.count - GCM.tagByteCount)])
                tag = Data(b[(b.count - GCM.tagByteCount)...])
            }
            public init<C: ContiguousBytes, T: ContiguousBytes>(nonce: Nonce, ciphertext: C, tag: T) throws {
                let t = _bytes(tag)
                guard t.count == GCM.tagByteCount else { throw CryptoKitError.incorrectParameterSize }
                self.nonce = nonce; self.ciphertext = Data(_bytes(ciphertext)); self.tag = Data(t)
            }
        }
        static func checkKey(_ key: SymmetricKey) throws {
            guard [128, 192, 256].contains(key.bitCount) else { throw CryptoKitError.incorrectKeySize }
        }
        public static func seal<P: ContiguousBytes, A: ContiguousBytes>(_ message: P, using key: SymmetricKey, nonce: Nonce? = nil, authenticating authenticatedData: A) throws -> SealedBox {
            try checkKey(key)
            let n = nonce ?? Nonce()
            var tag = [UInt8](repeating: 0, count: tagByteCount)
            let ct = try _aead(0, encrypt: true, key: key.bytes, nonce: n.bytes, aad: _bytes(authenticatedData), input: _bytes(message), tag: &tag)
            return try SealedBox(nonce: n, ciphertext: ct, tag: tag)
        }
        public static func seal<P: ContiguousBytes>(_ message: P, using key: SymmetricKey, nonce: Nonce? = nil) throws -> SealedBox {
            try seal(message, using: key, nonce: nonce, authenticating: [UInt8]())
        }
        public static func open<A: ContiguousBytes>(_ sealedBox: SealedBox, using key: SymmetricKey, authenticating authenticatedData: A) throws -> Data {
            try checkKey(key)
            var tag = Array(sealedBox.tag)
            return Data(try _aead(0, encrypt: false, key: key.bytes, nonce: sealedBox.nonce.bytes, aad: _bytes(authenticatedData), input: Array(sealedBox.ciphertext), tag: &tag))
        }
        public static func open(_ sealedBox: SealedBox, using key: SymmetricKey) throws -> Data {
            try open(sealedBox, using: key, authenticating: [UInt8]())
        }
    }
}

public enum ChaChaPoly {
    public struct Nonce: ContiguousBytes, Sequence, Sendable {
        let bytes: [UInt8]
        public init() { bytes = _randomBytes(12) }
        public init<D: ContiguousBytes>(data: D) throws {
            let b = _bytes(data)
            guard b.count == 12 else { throw CryptoKitError.incorrectParameterSize }
            bytes = b
        }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    }
    public struct SealedBox: Sendable {
        public let nonce: Nonce
        public let ciphertext: Data
        public let tag: Data
        public var combined: Data { Data(nonce.bytes + Array(ciphertext) + Array(tag)) }
        public init<D: ContiguousBytes>(combined: D) throws {
            let b = _bytes(combined)
            guard b.count >= 28 else { throw CryptoKitError.incorrectParameterSize }
            nonce = try Nonce(data: Array(b[0..<12]))
            ciphertext = Data(b[12..<(b.count - 16)])
            tag = Data(b[(b.count - 16)...])
        }
        public init<C: ContiguousBytes, T: ContiguousBytes>(nonce: Nonce, ciphertext: C, tag: T) throws {
            let t = _bytes(tag)
            guard t.count == 16 else { throw CryptoKitError.incorrectParameterSize }
            self.nonce = nonce; self.ciphertext = Data(_bytes(ciphertext)); self.tag = Data(t)
        }
    }
    public static func seal<P: ContiguousBytes, A: ContiguousBytes>(_ message: P, using key: SymmetricKey, nonce: Nonce? = nil, authenticating authenticatedData: A) throws -> SealedBox {
        guard key.bitCount == 256 else { throw CryptoKitError.incorrectKeySize }
        let n = nonce ?? Nonce()
        var tag = [UInt8](repeating: 0, count: 16)
        let ct = try _aead(1, encrypt: true, key: key.bytes, nonce: n.bytes, aad: _bytes(authenticatedData), input: _bytes(message), tag: &tag)
        return try SealedBox(nonce: n, ciphertext: ct, tag: tag)
    }
    public static func seal<P: ContiguousBytes>(_ message: P, using key: SymmetricKey, nonce: Nonce? = nil) throws -> SealedBox {
        try seal(message, using: key, nonce: nonce, authenticating: [UInt8]())
    }
    public static func open<A: ContiguousBytes>(_ sealedBox: SealedBox, using key: SymmetricKey, authenticating authenticatedData: A) throws -> Data {
        guard key.bitCount == 256 else { throw CryptoKitError.incorrectKeySize }
        var tag = Array(sealedBox.tag)
        return Data(try _aead(1, encrypt: false, key: key.bytes, nonce: sealedBox.nonce.bytes, aad: _bytes(authenticatedData), input: Array(sealedBox.ciphertext), tag: &tag))
    }
    public static func open(_ sealedBox: SealedBox, using key: SymmetricKey) throws -> Data {
        try open(sealedBox, using: key, authenticating: [UInt8]())
    }
}
