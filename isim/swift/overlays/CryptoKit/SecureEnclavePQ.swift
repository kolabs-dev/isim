// isim CryptoKit: the Secure Enclave's post-quantum keys (iOS 26; adapted, isim's simulated enclave in software, like
// SecureEnclave.P256): ML-KEM-768 / ML-KEM-1024 decapsulation keys and ML-DSA-65 / ML-DSA-87 signing keys. The key's
// seed leaves "the enclave" only in dataRepresentation, sealed with this simulated device's key and tagged with the
// key's type; its access control (Face ID / Touch ID / passcode) is enforced on each use.
import Foundation
import Security
import LocalAuthentication

@available(iOS 26.0, *)
extension SecureEnclave {
    public enum MLKEM768 {
        public struct PrivateKey: @unchecked Sendable {
            let key: CryptoKit.MLKEM768.PrivateKey, flags: UInt8
            let context: LAContext?
            public let dataRepresentation: Data
            public let publicKey: CryptoKit.MLKEM768.PublicKey
            public init(accessControl: SecAccessControl = SecureEnclave.defaultAccessControl, authenticationContext: LAContext? = nil) throws {
                let (seed, blob) = try SecureEnclave.makeSeed(0x10, 64, accessControl)
                key = try CryptoKit.MLKEM768.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = SecureEnclave.flags(accessControl); context = authenticationContext; dataRepresentation = blob; publicKey = key.publicKey
            }
            public init<D: ContiguousBytes>(dataRepresentation: D, authenticationContext: LAContext? = nil) throws {
                let blob = _bytes(dataRepresentation)
                let (seed, f) = try SecureEnclave.openSeed(0x10, 64, blob)
                key = try CryptoKit.MLKEM768.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = f; context = authenticationContext; self.dataRepresentation = Data(blob); publicKey = key.publicKey
            }
            public static func generate() throws -> PrivateKey { try PrivateKey() }
            public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
                try SecureEnclave.authorize(flags, context, "use a key to decapsulate a secret")
                return try key.decapsulate(encapsulated)
            }
        }
    }
}

@available(iOS 26.0, *)
extension SecureEnclave {
    public enum MLKEM1024 {
        public struct PrivateKey: @unchecked Sendable {
            let key: CryptoKit.MLKEM1024.PrivateKey, flags: UInt8
            let context: LAContext?
            public let dataRepresentation: Data
            public let publicKey: CryptoKit.MLKEM1024.PublicKey
            public init(accessControl: SecAccessControl = SecureEnclave.defaultAccessControl, authenticationContext: LAContext? = nil) throws {
                let (seed, blob) = try SecureEnclave.makeSeed(0x11, 64, accessControl)
                key = try CryptoKit.MLKEM1024.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = SecureEnclave.flags(accessControl); context = authenticationContext; dataRepresentation = blob; publicKey = key.publicKey
            }
            public init<D: ContiguousBytes>(dataRepresentation: D, authenticationContext: LAContext? = nil) throws {
                let blob = _bytes(dataRepresentation)
                let (seed, f) = try SecureEnclave.openSeed(0x11, 64, blob)
                key = try CryptoKit.MLKEM1024.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = f; context = authenticationContext; self.dataRepresentation = Data(blob); publicKey = key.publicKey
            }
            public static func generate() throws -> PrivateKey { try PrivateKey() }
            public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
                try SecureEnclave.authorize(flags, context, "use a key to decapsulate a secret")
                return try key.decapsulate(encapsulated)
            }
        }
    }
}

@available(iOS 26.0, *)
extension SecureEnclave {
    public enum MLDSA65 {
        public struct PrivateKey: @unchecked Sendable {
            let key: CryptoKit.MLDSA65.PrivateKey, flags: UInt8
            let context: LAContext?
            public let dataRepresentation: Data
            public let publicKey: CryptoKit.MLDSA65.PublicKey
            public init(accessControl: SecAccessControl = SecureEnclave.defaultAccessControl, authenticationContext: LAContext? = nil) throws {
                let (seed, blob) = try SecureEnclave.makeSeed(0x20, 32, accessControl)
                key = try CryptoKit.MLDSA65.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = SecureEnclave.flags(accessControl); context = authenticationContext; dataRepresentation = blob; publicKey = key.publicKey
            }
            public init<D: ContiguousBytes>(dataRepresentation: D, authenticationContext: LAContext? = nil) throws {
                let blob = _bytes(dataRepresentation)
                let (seed, f) = try SecureEnclave.openSeed(0x20, 32, blob)
                key = try CryptoKit.MLDSA65.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = f; context = authenticationContext; self.dataRepresentation = Data(blob); publicKey = key.publicKey
            }
            public func signature<D: ContiguousBytes>(for data: D) throws -> Data {
                try SecureEnclave.authorize(flags, context, "use a key to sign")
                return try key.signature(for: data)
            }
            public func signature<D: ContiguousBytes, C: ContiguousBytes>(for data: D, context signingContext: C) throws -> Data {
                try SecureEnclave.authorize(flags, context, "use a key to sign")
                return try key.signature(for: data, context: signingContext)
            }
        }
    }
}

@available(iOS 26.0, *)
extension SecureEnclave {
    public enum MLDSA87 {
        public struct PrivateKey: @unchecked Sendable {
            let key: CryptoKit.MLDSA87.PrivateKey, flags: UInt8
            let context: LAContext?
            public let dataRepresentation: Data
            public let publicKey: CryptoKit.MLDSA87.PublicKey
            public init(accessControl: SecAccessControl = SecureEnclave.defaultAccessControl, authenticationContext: LAContext? = nil) throws {
                let (seed, blob) = try SecureEnclave.makeSeed(0x21, 32, accessControl)
                key = try CryptoKit.MLDSA87.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = SecureEnclave.flags(accessControl); context = authenticationContext; dataRepresentation = blob; publicKey = key.publicKey
            }
            public init<D: ContiguousBytes>(dataRepresentation: D, authenticationContext: LAContext? = nil) throws {
                let blob = _bytes(dataRepresentation)
                let (seed, f) = try SecureEnclave.openSeed(0x21, 32, blob)
                key = try CryptoKit.MLDSA87.PrivateKey(seedRepresentation: seed, publicKey: nil)
                flags = f; context = authenticationContext; self.dataRepresentation = Data(blob); publicKey = key.publicKey
            }
            public func signature<D: ContiguousBytes>(for data: D) throws -> Data {
                try SecureEnclave.authorize(flags, context, "use a key to sign")
                return try key.signature(for: data)
            }
            public func signature<D: ContiguousBytes, C: ContiguousBytes>(for data: D, context signingContext: C) throws -> Data {
                try SecureEnclave.authorize(flags, context, "use a key to sign")
                return try key.signature(for: data, context: signingContext)
            }
        }
    }
}
