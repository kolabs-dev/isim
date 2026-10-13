// isim CryptoKit: the Secure Enclave (adapted: isim's simulated enclave, in software). P-256 signing and key agreement
// keys are made and used in isim's process; a key leaves "the enclave" only as its dataRepresentation, the private key
// sealed (AES-GCM) with this simulated device's key (Security's _SecureEnclaveStore), so it opens on the same device
// data only, like a real enclave's blob. The key's access control is enforced when it is used: biometry / user presence
// ask for the device owner (LocalAuthentication's Face ID / Touch ID prompt, passcode unless biometry only), unless the
// authenticationContext has already authenticated. isAvailable is true (iPhones have an enclave); ISIM_SECURE_ENCLAVE=0
// makes it false, like a Simulator without one.
import Foundation
@_spi(isim) import Security
import LocalAuthentication

public enum SecureEnclave {
    public static var isAvailable: Bool { _SecureEnclaveStore.isAvailable }

    /// the default access control: the key may be used (no owner check), on this device only
    @usableFromInline static var defaultAccessControl: SecAccessControl {
        SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .privateKeyUsage, nil)!
    }
    static func flags(_ ac: SecAccessControl) -> UInt8 { (ac._requiresOwner ? 1 : 0) | (ac._biometryOnly ? 2 : 0) }
    static func make(_ ac: SecAccessControl) throws -> ([UInt8], Data) {
        guard isAvailable else { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
        let d = _EC.generate(256)
        guard let blob = _SecureEnclaveStore.wrap(d, flags: flags(ac)) else { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
        return (d, blob)
    }
    static func open(_ data: [UInt8]) throws -> ([UInt8], UInt8) {
        guard isAvailable else { throw CryptoKitError.underlyingCoreCryptoError(error: -25293) }
        // another device's (or a damaged) key: errSecDecode, like a blob from another enclave
        guard let (d, f) = _SecureEnclaveStore.unwrap(data) else { throw CryptoKitError.underlyingCoreCryptoError(error: -26275) }
        return (d, f)
    }
    static func authorize(_ flags: UInt8, _ context: LAContext?, _ what: String) throws {
        guard _SecureEnclaveStore.authenticate(flags: flags, reason: what, context: context) else {
            throw CryptoKitError.underlyingCoreCryptoError(error: -128)       // errSecUserCanceled / authentication failed
        }
    }

    public enum P256 {
        public enum Signing {
            public struct PrivateKey: @unchecked Sendable {
                let d: [UInt8], q: [UInt8], flags: UInt8
                let context: LAContext?
                public let dataRepresentation: Data
                public init(compactRepresentable: Bool = true, accessControl: SecAccessControl = SecureEnclave.defaultAccessControl,
                            authenticationContext: LAContext? = nil) throws {
                    let (d, blob) = try SecureEnclave.make(accessControl)
                    self.d = d; q = try _EC.publicKey(256, d); flags = SecureEnclave.flags(accessControl)
                    context = authenticationContext; dataRepresentation = blob
                }
                public init(dataRepresentation: Data, authenticationContext: LAContext? = nil) throws {
                    let (d, f) = try SecureEnclave.open([UInt8](dataRepresentation))
                    self.d = d; q = try _EC.publicKey(256, d); flags = f; context = authenticationContext
                    self.dataRepresentation = dataRepresentation
                }
                public var publicKey: CryptoKit.P256.Signing.PublicKey { CryptoKit.P256.Signing.PublicKey(q: q) }
                public func signature<D: Digest>(for digest: D) throws -> CryptoKit.P256.Signing.ECDSASignature {
                    try SecureEnclave.authorize(flags, context, "use a key to sign")
                    return CryptoKit.P256.Signing.ECDSASignature(raw: try _EC.sign(256, d, digest: _bytes(digest)))
                }
                public func signature<D: ContiguousBytes>(for data: D) throws -> CryptoKit.P256.Signing.ECDSASignature {
                    try signature(for: SHA256.hash(data: data))
                }
            }
        }
        public enum KeyAgreement {
            public struct PrivateKey: @unchecked Sendable {
                let d: [UInt8], q: [UInt8], flags: UInt8
                let context: LAContext?
                public let dataRepresentation: Data
                public init(compactRepresentable: Bool = true, accessControl: SecAccessControl = SecureEnclave.defaultAccessControl,
                            authenticationContext: LAContext? = nil) throws {
                    let (d, blob) = try SecureEnclave.make(accessControl)
                    self.d = d; q = try _EC.publicKey(256, d); flags = SecureEnclave.flags(accessControl)
                    context = authenticationContext; dataRepresentation = blob
                }
                public init(dataRepresentation: Data, authenticationContext: LAContext? = nil) throws {
                    let (d, f) = try SecureEnclave.open([UInt8](dataRepresentation))
                    self.d = d; q = try _EC.publicKey(256, d); flags = f; context = authenticationContext
                    self.dataRepresentation = dataRepresentation
                }
                public var publicKey: CryptoKit.P256.KeyAgreement.PublicKey { CryptoKit.P256.KeyAgreement.PublicKey(q: q) }
                public func sharedSecretFromKeyAgreement(with publicKeyShare: CryptoKit.P256.KeyAgreement.PublicKey) throws -> SharedSecret {
                    try SecureEnclave.authorize(flags, context, "use a key to agree on a secret")
                    return try _EC.ecdh(256, d, publicKeyShare.q)
                }
            }
        }
    }
}
