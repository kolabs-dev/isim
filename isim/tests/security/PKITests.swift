// SecKey (RSA / EC through the host's OpenSSL), keys in the keychain, CryptoKit extras (AES Key Wrap, compact and
// PKCS#8 keys, HPKE against OpenSSL-made messages), Secure Enclave reported unavailable.
import Foundation
import Security
import CryptoKit

func fixture(_ name: String) -> Data? {
    guard let path = Bundle.main.path(forResource: name, ofType: nil) else { return nil }
    return FileManager.default.contents(atPath: path)
}
func errorCode(_ e: Unmanaged<CFError>?) -> Int { e.map { ($0.takeRetainedValue() as Error as NSError).code } ?? 0 }

func secKeyTests() {
    var error: Unmanaged<CFError>?
    // RSA
    guard let rsa = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, &error),
          let rsaPub = SecKeyCopyPublicKey(rsa) else { check(false, "SecKeyCreateRandomKey RSA 2048"); return }
    check(SecKeyGetBlockSize(rsa) == 256, "RSA 2048 key: block size 256")
    let attrs = SecKeyCopyAttributes(rsa) as NSDictionary? as? [String: Any] ?? [:]
    check(attrs[kSecAttrKeyType as String] as? String == "42" && attrs[kSecAttrKeyClass as String] as? String == "1" && attrs[kSecAttrKeySizeInBits as String] as? Int == 2048,
          "SecKeyCopyAttributes (type, class, size)")
    let message = Data("isim signs this".utf8)
    for alg in [SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256, .rsaSignatureMessagePSSSHA256, .rsaSignatureMessagePKCS1v15SHA512] {
        let sig = SecKeyCreateSignature(rsa, alg, message as CFData, &error)
        let ok = sig.map { SecKeyVerifySignature(rsaPub, alg, message as CFData, $0 as CFData, &error) } ?? false
        let tampered = sig.map { SecKeyVerifySignature(rsaPub, alg, Data("other".utf8) as CFData, $0 as CFData, nil) } ?? true
        check(ok && !tampered && sig?.count == 256, "RSA \(alg.rawValue): sign / verify / reject tampered")
    }
    let digest = Data(SHA256.hash(data: message))
    let dsig = SecKeyCreateSignature(rsa, .rsaSignatureDigestPKCS1v15SHA256, digest as CFData, nil)
    let msig = SecKeyCreateSignature(rsa, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, nil)
    check(dsig != nil && dsig == msig, "PKCS#1 v1.5 digest and message algorithms agree (deterministic)")
    check(!SecKeyIsAlgorithmSupported(rsaPub, .sign, .rsaSignatureMessagePKCS1v15SHA256) && SecKeyIsAlgorithmSupported(rsaPub, .encrypt, .rsaEncryptionOAEPSHA256)
          && !SecKeyIsAlgorithmSupported(rsa, .sign, .ecdsaSignatureMessageX962SHA256), "SecKeyIsAlgorithmSupported")
    for alg in [SecKeyAlgorithm.rsaEncryptionOAEPSHA256, .rsaEncryptionOAEPSHA1, .rsaEncryptionPKCS1] {
        let secret = Data("attack at dawn".utf8)
        let ct = SecKeyCreateEncryptedData(rsaPub, alg, secret as CFData, &error)
        let pt = ct.flatMap { SecKeyCreateDecryptedData(rsa, alg, $0 as CFData, &error) }
        check(ct?.count == 256 && pt == secret, "RSA \(alg.rawValue) encrypt / decrypt")
    }
    // external representation round trip (PKCS#1)
    if let ext = SecKeyCopyExternalRepresentation(rsaPub, &error) {
        let back = SecKeyCreateWithData(ext as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, &error)
        check(back == rsaPub && ext.first == 0x30, "RSA public key: PKCS#1 DER external representation round trip")
    } else { check(false, "SecKeyCopyExternalRepresentation RSA") }
    check(SecKeyCreateWithData(Data([1, 2, 3]) as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, &error) == nil
          && errorCode(error) == Int(errSecDecode), "SecKeyCreateWithData rejects garbage (errSecDecode)")

    // EC (P-256), interoperating with CryptoKit
    guard let ec = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: 256] as CFDictionary, &error),
          let ecPub = SecKeyCopyPublicKey(ec), let ecPriv = SecKeyCopyExternalRepresentation(ec, &error),
          let ecPubData = SecKeyCopyExternalRepresentation(ecPub, &error) else { check(false, "SecKeyCreateRandomKey EC P-256"); return }
    check(ecPriv.count == 97 && ecPubData.count == 65 && ecPubData.first == 4, "EC P-256 external representations (X9.63, 97/65 bytes)")
    let ckPriv = try? P256.Signing.PrivateKey(x963Representation: ecPriv)
    let ckSig = try? ckPriv?.signature(for: message)
    check(ckSig.map { SecKeyVerifySignature(ecPub, .ecdsaSignatureMessageX962SHA256, message as CFData, $0.derRepresentation as CFData, nil) } ?? false,
          "SecKey verifies a CryptoKit ECDSA signature (X9.62 DER)")
    let secSig = SecKeyCreateSignature(ec, .ecdsaSignatureMessageX962SHA256, message as CFData, nil)
    let ckPub = try? P256.Signing.PublicKey(x963Representation: ecPubData)
    check(secSig.flatMap { try? P256.Signing.ECDSASignature(derRepresentation: $0) }.map { ckPub?.isValidSignature($0, for: message) ?? false } ?? false,
          "CryptoKit verifies a SecKey ECDSA signature")
    let raw = SecKeyCreateSignature(ec, .ecdsaSignatureMessageRFC4754SHA256, message as CFData, nil)
    check(raw?.count == 64 && raw.map { SecKeyVerifySignature(ecPub, .ecdsaSignatureMessageRFC4754SHA256, message as CFData, $0 as CFData, nil) } == true,
          "ECDSA RFC 4754 (raw r||s) signatures")
    let dig = SecKeyCreateSignature(ec, .ecdsaSignatureDigestX962SHA256, digest as CFData, nil)
    check(dig.map { SecKeyVerifySignature(ecPub, .ecdsaSignatureMessageX962SHA256, message as CFData, $0 as CFData, nil) } == true, "ECDSA digest vs message algorithms")
    // ECDH: SecKey and CryptoKit derive the same X9.63 key
    let peer = P256.KeyAgreement.PrivateKey()
    if let peerPub = SecKeyCreateWithData(peer.publicKey.x963Representation as CFData,
                                          [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, nil),
       let ours = try? P256.KeyAgreement.PublicKey(x963Representation: ecPubData) {
        let info = Data("isim ecdh".utf8)
        let secKey = SecKeyCopyKeyExchangeResult(ec, .ecdhKeyExchangeStandardX963SHA256, peerPub,
                                                 [kSecKeyKeyExchangeParameterRequestedSize: 32, kSecKeyKeyExchangeParameterSharedInfo: info] as CFDictionary, &error)
        let ckKey = (try? peer.sharedSecretFromKeyAgreement(with: ours))?.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: info, outputByteCount: 32)
        check(secKey != nil && ckKey.map { $0.withUnsafeBytes { Data($0) } } == secKey, "ECDH + X9.63 KDF matches CryptoKit")
        let plain = SecKeyCopyKeyExchangeResult(ec, .ecdhKeyExchangeStandard, peerPub, [:] as CFDictionary, nil)
        check(plain?.count == 32, "ECDH standard (shared x coordinate)")
    } else { check(false, "EC public key import") }
    for bits in [384, 521] {
        let k = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeEC, kSecAttrKeySizeInBits: bits] as CFDictionary, nil)
        let s = k.flatMap { SecKeyCreateSignature($0, .ecdsaSignatureMessageX962SHA512, message as CFData, nil) }
        let ok = s.map { SecKeyVerifySignature(SecKeyCopyPublicKey(k!)!, .ecdsaSignatureMessageX962SHA512, message as CFData, $0 as CFData, nil) } ?? false
        check(ok, "EC P-\(bits) keys sign and verify")
    }
    // Secure Enclave: unavailable
    check(SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: 256, kSecAttrTokenID: kSecAttrTokenIDSecureEnclave] as CFDictionary, &error) == nil
          && errorCode(error) == Int(errSecUnimplemented), "Secure Enclave keys fail (no Secure Enclave on isim)")
    check(!SecureEnclave.isAvailable && (try? SecureEnclave.P256.Signing.PrivateKey()) == nil, "CryptoKit SecureEnclave.isAvailable is false")

    // keys in the keychain
    let tag = Data("dev.isim.test.signing".utf8)
    SecItemDelete([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag] as CFDictionary)
    let stored = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: 256,
                                        kSecPrivateKeyAttrs: [kSecAttrIsPermanent: true, kSecAttrApplicationTag: tag]] as CFDictionary, &error)
    var found: CFTypeRef?
    let st = SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag, kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                                  kSecReturnRef: true] as CFDictionary, &found)
    let foundKey = found as! SecKey?
    check(stored != nil && st == errSecSuccess && foundKey == stored, "permanent key (kSecAttrIsPermanent) is found by tag with kSecReturnRef")
    let s2 = foundKey.flatMap { SecKeyCreateSignature($0, .ecdsaSignatureMessageX962SHA256, message as CFData, nil) }
    check(s2.map { SecKeyVerifySignature(SecKeyCopyPublicKey(stored!)!, .ecdsaSignatureMessageX962SHA256, message as CFData, $0 as CFData, nil) } == true,
          "the key read back from the keychain signs")
    let pubTag = Data("dev.isim.test.rsa-public".utf8)
    SecItemDelete([kSecClass: kSecClassKey, kSecAttrApplicationTag: pubTag] as CFDictionary)
    let addSt = SecItemAdd([kSecClass: kSecClassKey, kSecValueRef: rsaPub, kSecAttrApplicationTag: pubTag] as CFDictionary, nil)
    let dup = SecItemAdd([kSecClass: kSecClassKey, kSecValueRef: rsaPub, kSecAttrApplicationTag: pubTag] as CFDictionary, nil)
    var attrsOut: CFTypeRef?
    _ = SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: pubTag, kSecReturnAttributes: true, kSecReturnData: true] as CFDictionary, &attrsOut)
    let a = attrsOut as? [String: Any] ?? [:]
    check(addSt == errSecSuccess && dup == errSecDuplicateItem && (a[kSecValueData as String] as? Data) == SecKeyCopyExternalRepresentation(rsaPub, nil)
          && a[kSecAttrKeyClass as String] as? String == "0" && a[kSecAttrApplicationLabel as String] != nil,
          "SecItemAdd(kSecValueRef: public key), duplicate detection, attributes + data")
    check(SecItemDelete([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag] as CFDictionary) == errSecSuccess
          && SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag] as CFDictionary, nil) == errSecItemNotFound, "SecItemDelete for keys")
}

func cryptoKitExtrasTests() {
    // AES Key Wrap (RFC 3394 4.1)
    let kek = SymmetricKey(data: unhex("000102030405060708090A0B0C0D0E0F"))
    let keyData = SymmetricKey(data: unhex("00112233445566778899AABBCCDDEEFF"))
    let wrapped = try? AES.KeyWrap.wrap(keyData, using: kek)
    check(wrapped.map { hex($0) } == "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5", "AES.KeyWrap.wrap (RFC 3394 vector)")
    let unwrapped = wrapped.flatMap { try? AES.KeyWrap.unwrap($0, using: kek) }
    check(unwrapped == keyData, "AES.KeyWrap.unwrap")
    var bad = wrapped.map(Array.init) ?? []; if !bad.isEmpty { bad[5] ^= 1 }
    check((try? AES.KeyWrap.unwrap(bad, using: kek)) == nil, "AES.KeyWrap.unwrap rejects a modified key")
    // compact representations
    let compactKey = P256.KeyAgreement.PrivateKey(compactRepresentable: true)
    let compact = compactKey.publicKey.compactRepresentation
    let restored = compact.flatMap { try? P256.KeyAgreement.PublicKey(compactRepresentation: $0) }
    check(compact?.count == 32 && restored?.x963Representation == compactKey.publicKey.x963Representation, "P-256 compact representation round trip")
    let sk384 = P384.Signing.PrivateKey(compactRepresentable: true)
    check(sk384.publicKey.compactRepresentation.flatMap { try? P384.Signing.PublicKey(compactRepresentation: $0) }?.rawRepresentation == sk384.publicKey.rawRepresentation,
          "P-384 compact representation round trip")
    // PKCS#8 DER/PEM for private keys
    let sk = P256.Signing.PrivateKey()
    let pem = sk.pemRepresentation
    let back = try? P256.Signing.PrivateKey(pemRepresentation: pem)
    check(pem.hasPrefix("-----BEGIN PRIVATE KEY-----") && back?.rawRepresentation == sk.rawRepresentation, "private key PEM (PKCS#8) round trip")
    check((try? P521.KeyAgreement.PrivateKey(derRepresentation: P521.KeyAgreement.PrivateKey().derRepresentation)) != nil, "P-521 private key DER round trip")
    if let caKey = fixture("ca.key").flatMap({ String(data: $0, encoding: .utf8) }) {
        let k = try? P256.Signing.PrivateKey(pemRepresentation: caKey)
        check(k != nil, "reads an OpenSSL SEC1 \"EC PRIVATE KEY\" PEM")
    } else { check(false, "fixture ca.key") }
    // HPKE: open messages sealed by OpenSSL
    for v in hpkeVectors {
        let name = v["name"]!, mode = Int(v["mode"]!)!
        let info = Data("isim HPKE test".utf8), psk = SymmetricKey(data: Data("isim pre-shared key 0123456789!!".utf8)), pskID = Data("isim-psk".utf8)
        do {
            var r: HPKE.Recipient
            var exp: SymmetricKey
            if name.hasPrefix("P256") {
                let skR = try P256.KeyAgreement.PrivateKey(rawRepresentation: unhex(v["skR"]!))
                let pkS = try P256.KeyAgreement.PublicKey(x963Representation: unhex(v["pkS"]!))
                switch mode {
                case 1: r = try HPKE.Recipient(privateKey: skR, ciphersuite: .P256_SHA256_AES_GCM_256, info: info, encapsulatedKey: unhex(v["enc"]!), presharedKey: psk, presharedKeyIdentifier: pskID)
                case 2: r = try HPKE.Recipient(privateKey: skR, ciphersuite: .P256_SHA256_AES_GCM_256, info: info, encapsulatedKey: unhex(v["enc"]!), authenticatedBy: pkS)
                default: r = try HPKE.Recipient(privateKey: skR, ciphersuite: .P256_SHA256_AES_GCM_256, info: info, encapsulatedKey: unhex(v["enc"]!))
                }
            } else {
                let skR = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: unhex(v["skR"]!))
                let pkS = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: unhex(v["pkS"]!))
                if mode == 3 {
                    r = try HPKE.Recipient(privateKey: skR, ciphersuite: .Curve25519_SHA256_ChachaPoly, info: info, encapsulatedKey: unhex(v["enc"]!),
                                           authenticatedBy: pkS, presharedKey: psk, presharedKeyIdentifier: pskID)
                } else {
                    r = try HPKE.Recipient(privateKey: skR, ciphersuite: .Curve25519_SHA256_ChachaPoly, info: info, encapsulatedKey: unhex(v["enc"]!))
                }
            }
            let m1 = try r.open(unhex(v["ct1"]!), authenticating: Data("header".utf8))
            let m2 = try r.open(unhex(v["ct2"]!))
            exp = try r.exportSecret(context: Data("isim exporter".utf8), outputByteCount: 32)
            check(String(decoding: m1, as: UTF8.self) == "first message from OpenSSL" && String(decoding: m2, as: UTF8.self) == "second message"
                  && exp.withUnsafeBytes { hex($0) } == v["exported"], "HPKE \(name): opens OpenSSL's messages, exporter matches")
        } catch { check(false, "HPKE \(name): \(error)") }
    }
    // HPKE round trips for every ciphersuite
    func roundTrip<SK: HPKEDiffieHellmanPrivateKeyGeneration>(_ type: SK.Type, _ suite: HPKE.Ciphersuite, _ label: String) {
        do {
            let skR = SK(), skS = SK.PublicKey.EphemeralPrivateKey()
            var s = try HPKE.Sender(recipientKey: skR.publicKey, ciphersuite: suite, info: Data("ctx".utf8), authenticatedBy: skS)
            let c1 = try s.seal(Data("one".utf8)), c2 = try s.seal(Data("two".utf8), authenticating: Data("aad".utf8))
            var r = try HPKE.Recipient(privateKey: skR, ciphersuite: suite, info: Data("ctx".utf8), encapsulatedKey: s.encapsulatedKey, authenticatedBy: skS.publicKey)
            let ok = try r.open(c1) == Data("one".utf8) && r.open(c2, authenticating: Data("aad".utf8)) == Data("two".utf8)
            let same = try s.exportSecret(context: Data("e".utf8), outputByteCount: 16) == r.exportSecret(context: Data("e".utf8), outputByteCount: 16)
            var wrong = try HPKE.Recipient(privateKey: SK(), ciphersuite: suite, info: Data("ctx".utf8), encapsulatedKey: s.encapsulatedKey, authenticatedBy: skS.publicKey)
            let rejected = (try? wrong.open(c1)) == nil
            check(ok && same && rejected, "HPKE \(label) auth mode round trip; wrong key rejected")
        } catch { check(false, "HPKE \(label): \(error)") }
    }
    roundTrip(P256.KeyAgreement.PrivateKey.self, .P256_SHA256_AES_GCM_256, "P-256")
    roundTrip(P384.KeyAgreement.PrivateKey.self, .P384_SHA384_AES_GCM_256, "P-384")
    roundTrip(P521.KeyAgreement.PrivateKey.self, .P521_SHA512_AES_GCM_256, "P-521")
    roundTrip(Curve25519.KeyAgreement.PrivateKey.self, .Curve25519_SHA256_ChachaPoly, "X25519")
    let exportOnly = HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA512, aead: .exportOnly)
    if var s = try? HPKE.Sender(recipientKey: Curve25519.KeyAgreement.PrivateKey().publicKey, ciphersuite: exportOnly, info: Data()) {
        check((try? s.seal(Data([1]))) == nil && (try? s.exportSecret(context: Data(), outputByteCount: 64)) != nil, "HPKE export-only suite")
    } else { check(false, "HPKE export-only sender") }
}
