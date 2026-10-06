// isim CryptoKit: ECDSA signing and ECDH key agreement on NIST P-256, P-384 and P-521 (host OpenSSL libcrypto).
// The three curves share one implementation (_EC); P384 and P521 are the P256 declarations with their curve
// and hash (SHA384/SHA512) substituted. Private keys: raw scalar and X9.63; public keys: raw, X9.63, compressed,
// DER/PEM SubjectPublicKeyInfo. Not implemented: compact representations, private-key DER/PEM.
import Foundation

public enum P256 {
    public enum Signing {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(256); q = try! _EC.publicKey(256, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(256, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(256)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(256, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func signature<D: Digest>(for digest: D) throws -> ECDSASignature { ECDSASignature(raw: try _EC.sign(256, d, digest: _bytes(digest))) }
            public func signature<D: ContiguousBytes>(for data: D) throws -> ECDSASignature { try signature(for: SHA256.hash(data: data)) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(256) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(256), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(256), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(256, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(256, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(256, q)) }
            public var derRepresentation: Data { Data(_EC.der(256, q)) }
            public var pemRepresentation: String { _pem(_EC.der(256, q), "PUBLIC KEY") }
            public func isValidSignature<D: Digest>(_ signature: ECDSASignature, for digest: D) -> Bool {
                _EC.verify(256, q, digest: _bytes(digest), signature: signature.raw)
            }
            public func isValidSignature<D: ContiguousBytes>(_ signature: ECDSASignature, for data: D) -> Bool {
                isValidSignature(signature, for: SHA256.hash(data: data))
            }
        }
        public struct ECDSASignature: ContiguousBytes, Sendable {
            let raw: [UInt8]
            init(raw: [UInt8]) { self.raw = raw }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(256) else { throw CryptoKitError.incorrectParameterSize }
                raw = b
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { raw = try _EC.sigFromDER(_bytes(data), size: _EC.size(256)) }
            public var rawRepresentation: Data { Data(raw) }
            public var derRepresentation: Data { Data(_EC.sigToDER(raw)) }
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try raw.withUnsafeBytes(body) }
        }
    }
    public enum KeyAgreement {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(256); q = try! _EC.publicKey(256, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(256, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(256)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(256, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret { try _EC.ecdh(256, d, publicKeyShare.q) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(256) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(256), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(256), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(256, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(256, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(256, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(256, q)) }
            public var derRepresentation: Data { Data(_EC.der(256, q)) }
            public var pemRepresentation: String { _pem(_EC.der(256, q), "PUBLIC KEY") }
        }
    }
}

public enum P384 {
    public enum Signing {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(384); q = try! _EC.publicKey(384, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(384, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(384)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(384, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func signature<D: Digest>(for digest: D) throws -> ECDSASignature { ECDSASignature(raw: try _EC.sign(384, d, digest: _bytes(digest))) }
            public func signature<D: ContiguousBytes>(for data: D) throws -> ECDSASignature { try signature(for: SHA384.hash(data: data)) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(384) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(384), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(384), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(384, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(384, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(384, q)) }
            public var derRepresentation: Data { Data(_EC.der(384, q)) }
            public var pemRepresentation: String { _pem(_EC.der(384, q), "PUBLIC KEY") }
            public func isValidSignature<D: Digest>(_ signature: ECDSASignature, for digest: D) -> Bool {
                _EC.verify(384, q, digest: _bytes(digest), signature: signature.raw)
            }
            public func isValidSignature<D: ContiguousBytes>(_ signature: ECDSASignature, for data: D) -> Bool {
                isValidSignature(signature, for: SHA384.hash(data: data))
            }
        }
        public struct ECDSASignature: ContiguousBytes, Sendable {
            let raw: [UInt8]
            init(raw: [UInt8]) { self.raw = raw }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(384) else { throw CryptoKitError.incorrectParameterSize }
                raw = b
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { raw = try _EC.sigFromDER(_bytes(data), size: _EC.size(384)) }
            public var rawRepresentation: Data { Data(raw) }
            public var derRepresentation: Data { Data(_EC.sigToDER(raw)) }
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try raw.withUnsafeBytes(body) }
        }
    }
    public enum KeyAgreement {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(384); q = try! _EC.publicKey(384, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(384, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(384)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(384, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret { try _EC.ecdh(384, d, publicKeyShare.q) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(384) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(384), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(384), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(384, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(384, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(384, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(384, q)) }
            public var derRepresentation: Data { Data(_EC.der(384, q)) }
            public var pemRepresentation: String { _pem(_EC.der(384, q), "PUBLIC KEY") }
        }
    }
}

public enum P521 {
    public enum Signing {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(521); q = try! _EC.publicKey(521, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(521, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(521)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(521, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func signature<D: Digest>(for digest: D) throws -> ECDSASignature { ECDSASignature(raw: try _EC.sign(521, d, digest: _bytes(digest))) }
            public func signature<D: ContiguousBytes>(for data: D) throws -> ECDSASignature { try signature(for: SHA512.hash(data: data)) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(521) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(521), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(521), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(521, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(521, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(521, q)) }
            public var derRepresentation: Data { Data(_EC.der(521, q)) }
            public var pemRepresentation: String { _pem(_EC.der(521, q), "PUBLIC KEY") }
            public func isValidSignature<D: Digest>(_ signature: ECDSASignature, for digest: D) -> Bool {
                _EC.verify(521, q, digest: _bytes(digest), signature: signature.raw)
            }
            public func isValidSignature<D: ContiguousBytes>(_ signature: ECDSASignature, for data: D) -> Bool {
                isValidSignature(signature, for: SHA512.hash(data: data))
            }
        }
        public struct ECDSASignature: ContiguousBytes, Sendable {
            let raw: [UInt8]
            init(raw: [UInt8]) { self.raw = raw }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(521) else { throw CryptoKitError.incorrectParameterSize }
                raw = b
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { raw = try _EC.sigFromDER(_bytes(data), size: _EC.size(521)) }
            public var rawRepresentation: Data { Data(raw) }
            public var derRepresentation: Data { Data(_EC.sigToDER(raw)) }
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try raw.withUnsafeBytes(body) }
        }
    }
    public enum KeyAgreement {
        public struct PrivateKey: Sendable {
            let d: [UInt8], q: [UInt8]
            public init(compactRepresentable: Bool = true) { d = _EC.generate(521); q = try! _EC.publicKey(521, d) }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws { d = _bytes(data); q = try _EC.publicKey(521, d) }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data), n = _EC.size(521)
                guard b.count == 1 + 3 * n else { throw CryptoKitError.incorrectKeySize }
                d = Array(b.suffix(n)); q = try _EC.publicKey(521, d)
                guard q == Array(b.prefix(1 + 2 * n)) else { throw CryptoKitError.invalidParameter }
            }
            public var rawRepresentation: Data { Data(d) }
            public var x963Representation: Data { Data(q + d) }
            public var publicKey: PublicKey { PublicKey(q: q) }
            public func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret { try _EC.ecdh(521, d, publicKeyShare.q) }
        }
        public struct PublicKey: Sendable {
            let q: [UInt8]
            init(q: [UInt8]) { self.q = q }
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 2 * _EC.size(521) else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, [4] + b)
            }
            public init<D: ContiguousBytes>(x963Representation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + 2 * _EC.size(521), b.first == 4 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, b)
            }
            public init<D: ContiguousBytes>(compressedRepresentation data: D) throws {
                let b = _bytes(data)
                guard b.count == 1 + _EC.size(521), b.first == 2 || b.first == 3 else { throw CryptoKitError.incorrectKeySize }
                q = try _EC.importPublic(521, b)
            }
            public init<D: ContiguousBytes>(derRepresentation data: D) throws { q = try _EC.fromDER(521, _bytes(data)) }
            public init(pemRepresentation pem: String) throws { q = try _EC.fromDER(521, try _fromPEM(pem, "PUBLIC KEY")) }
            public var rawRepresentation: Data { Data(q.dropFirst()) }
            public var x963Representation: Data { Data(q) }
            public var compressedRepresentation: Data { Data(_EC.compressed(521, q)) }
            public var derRepresentation: Data { Data(_EC.der(521, q)) }
            public var pemRepresentation: String { _pem(_EC.der(521, q), "PUBLIC KEY") }
        }
    }
}
