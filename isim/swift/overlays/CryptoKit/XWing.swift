// isim CryptoKit: X-Wing (iOS 26), the hybrid KEM of ML-KEM-768 and X25519 (draft-connolly-cfrg-xwing-kem-06), and its
// HPKE KEM (id 0x647a). Implemented here in Swift (adapted) on isim's ML-KEM, SHA-3 and X25519; same API as Apple's
// XWingMLKEM768X25519. The private key's seedRepresentation is X-Wing's 32-byte decapsulation key; the
// integrityCheckedRepresentation is that seed followed by SHA3-256 of the public key.
import Foundation

struct _XWing {
    static let label: [UInt8] = [0x5c, 0x2e, 0x2f, 0x2f, 0x5e, 0x5c]      // "\.//^\"
    static let publicKeySize = 1216, ciphertextSize = 1120
    static func combine(_ ssM: [UInt8], _ ssX: [UInt8], _ ctX: [UInt8], _ pkX: [UInt8]) -> [UInt8] {
        _Keccak.sha3_256(ssM + ssX + ctX + pkX + label)
    }
    /// expandDecapsulationKey: (dk_M, sk_X, pk)
    static func expand(_ sk: [UInt8]) throws -> ([UInt8], Curve25519.KeyAgreement.PrivateKey, [UInt8]) {
        let e = _Keccak.shake256(sk, 96)
        let (pkM, dkM) = _MLKEM.p768.keyGen(Array(e[0..<64]))
        let skX = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Array(e[64..<96]))
        return (dkM, skX, pkM + _bytes(skX.publicKey.rawRepresentation))
    }
    static func encaps(_ pk: [UInt8], eseed: [UInt8]) throws -> (ss: [UInt8], ct: [UInt8]) {
        let pkM = Array(pk[0..<1184]), pkX = Array(pk[1184..<1216])
        let ekX = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Array(eseed[32..<64]))
        let ctX = _bytes(ekX.publicKey.rawRepresentation)
        let ssX = _bytes(try ekX.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: pkX)))
        let (ssM, ctM) = _MLKEM.p768.encaps(pkM, m: Array(eseed[0..<32]))
        return (combine(ssM, ssX, ctX, pkX), ctM + ctX)
    }
    static func decaps(_ dkM: [UInt8], _ skX: Curve25519.KeyAgreement.PrivateKey, _ pk: [UInt8], _ ct: [UInt8]) throws -> [UInt8] {
        guard ct.count == ciphertextSize else { throw CryptoKitError.incorrectParameterSize }
        let ctX = Array(ct[1088..<1120])
        let ssM = _MLKEM.p768.decaps(dkM, Array(ct[0..<1088]))
        let ssX = _bytes(try skX.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ctX)))
        return combine(ssM, ssX, ctX, Array(pk[1184..<1216]))
    }
}

@available(iOS 26.0, *)
public enum XWingMLKEM768X25519 {
    public struct PublicKey: KEMPublicKey, HPKEKEMPublicKey, Sendable {
        public typealias EphemeralPrivateKey = PrivateKey
        public typealias HPKEEphemeralPrivateKey = PrivateKey
        let raw: [UInt8]
        init(raw: [UInt8]) { self.raw = raw }
        public init<D: ContiguousBytes>(rawRepresentation: D) throws {
            raw = _bytes(rawRepresentation)
            guard raw.count == _XWing.publicKeySize, _MLKEM.p768.checkPublicKey(Array(raw[0..<1184])) else { throw CryptoKitError.incorrectKeySize }
        }
        public var rawRepresentation: Data { Data(raw) }
        public func encapsulate() throws -> KEM.EncapsulationResult {
            let (ss, ct) = try _XWing.encaps(raw, eseed: _randomBytes(64))
            return KEM.EncapsulationResult(sharedSecret: SymmetricKey(data: ss), encapsulated: Data(ct))
        }
        /// draft-connolly-cfrg-xwing-kem's EncapsulateDerand, for known-answer tests
        @_spi(isim) public func _encapsulate(eseed: [UInt8]) throws -> KEM.EncapsulationResult {
            let (ss, ct) = try _XWing.encaps(raw, eseed: eseed)
            return KEM.EncapsulationResult(sharedSecret: SymmetricKey(data: ss), encapsulated: Data(ct))
        }
        public init<D: ContiguousBytes>(_ serialization: D, kem: HPKE.KEM) throws {
            guard kem == .XWingMLKEM768X25519 else { throw HPKE.Errors.inconsistentParameters }
            try self.init(rawRepresentation: serialization)
        }
        public func hpkeRepresentation(kem: HPKE.KEM) throws -> Data {
            guard kem == .XWingMLKEM768X25519 else { throw HPKE.Errors.inconsistentParameters }
            return rawRepresentation
        }
        public func _hpkeEncapsulate(kem: HPKE.KEM) throws -> (sharedSecret: [UInt8], encapsulated: [UInt8]) {
            guard kem == .XWingMLKEM768X25519 else { throw HPKE.Errors.inconsistentParameters }
            let r = try encapsulate()
            return (_bytes(r.sharedSecret), _bytes(r.encapsulated))
        }
    }
    public struct PrivateKey: KEMPrivateKey, HPKEKEMPrivateKeyGeneration, Sendable {
        let seed: [UInt8], dkM: [UInt8]
        let skX: Curve25519.KeyAgreement.PrivateKey
        public let publicKey: PublicKey
        public init() throws { try self.init(seed: _randomBytes(32), publicKey: nil) }
        public static func generate() throws -> PrivateKey { try PrivateKey() }
        init(seed: [UInt8], publicKey pk: [UInt8]?) throws {
            guard seed.count == 32 else { throw KEM.Errors.invalidSeed }
            let (dkM, skX, derived) = try _XWing.expand(seed)
            if let pk, !_safeEqual(pk, derived) { throw KEM.Errors.publicKeyMismatchDuringInitialization }
            self.seed = seed; self.dkM = dkM; self.skX = skX; publicKey = PublicKey(raw: derived)
        }
        public init<D: ContiguousBytes>(seedRepresentation: D, publicKey: PublicKey?) throws {
            try self.init(seed: _bytes(seedRepresentation), publicKey: publicKey?.raw)
        }
        public var seedRepresentation: Data { Data(seed) }
        public init<D: ContiguousBytes>(integrityCheckedRepresentation: D) throws {
            let blob = _bytes(integrityCheckedRepresentation)
            try self.init(seed: try _integrityChecked(blob, seedCount: 32), publicKey: nil)
            guard _safeEqual(_Keccak.sha3_256(publicKey.raw), Array(blob[32...])) else { throw KEM.Errors.publicKeyMismatchDuringInitialization }
        }
        public var integrityCheckedRepresentation: Data { Data(seed + _Keccak.sha3_256(publicKey.raw)) }
        public func decapsulate<D: ContiguousBytes>(_ encapsulated: D) throws -> SymmetricKey {
            SymmetricKey(data: try _XWing.decaps(dkM, skX, publicKey.raw, _bytes(encapsulated)))
        }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey { try decapsulate([UInt8](encapsulated)) }
        public func _hpkeDecapsulate(_ encapsulated: [UInt8], kem: HPKE.KEM) throws -> [UInt8] {
            guard kem == .XWingMLKEM768X25519 else { throw HPKE.Errors.inconsistentParameters }
            return try _XWing.decaps(dkM, skX, publicKey.raw, encapsulated)
        }
    }    /// a key for one decapsulation (iOS 27)
    @available(iOS 27.0, *)
    public struct OneTimePrivateKey: KEMOneTimePrivateKey, Sendable {
        let key: PrivateKey
        let state = _OneTimeUse()
        public var publicKey: PublicKey { key.publicKey }
        public init() throws { key = try PrivateKey() }
        public static func generate() throws -> OneTimePrivateKey { try OneTimePrivateKey() }
        public func decapsulate(_ encapsulated: Data) throws -> SymmetricKey {
            try state.take()
            return try key.decapsulate(encapsulated)
        }
    }
}
