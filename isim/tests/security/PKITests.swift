// SecKey (RSA / EC through the host's OpenSSL), keys in the keychain, certificates / policies / trust, PKCS#12 and
// identities, CryptoKit extras (AES Key Wrap, compact and PKCS#8 keys, HPKE against OpenSSL-made messages),
// Secure Enclave reported unavailable.
import Foundation
import Security
import CryptoKit

func fixture(_ name: String) -> Data? {
    guard let path = Bundle.main.path(forResource: name, ofType: nil) else { return nil }
    return FileManager.default.contents(atPath: path)
}
func errorCode(_ e: Unmanaged<CFError>?) -> Int { e.map { ($0.takeRetainedValue() as Error as NSError).code } ?? 0 }
func sign(_ k: SecKey, _ alg: SecKeyAlgorithm, _ data: Data) -> Data? { SecKeyCreateSignature(k, alg, data as CFData, nil) as Data? }
func verify(_ k: SecKey, _ alg: SecKeyAlgorithm, _ data: Data, _ sig: Data?) -> Bool {
    guard let sig else { return false }
    return SecKeyVerifySignature(k, alg, data as CFData, sig as CFData, nil)
}
func external(_ k: SecKey) -> Data? { SecKeyCopyExternalRepresentation(k, nil) as Data? }
func keyFrom(_ d: Data, rsa: Bool, priv: Bool) -> SecKey? {
    SecKeyCreateWithData(d as CFData, [kSecAttrKeyType: rsa ? kSecAttrKeyTypeRSA : kSecAttrKeyTypeECSECPrimeRandom,
                                       kSecAttrKeyClass: priv ? kSecAttrKeyClassPrivate : kSecAttrKeyClassPublic] as CFDictionary, nil)
}

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
        let sig = sign(rsa, alg, message)
        check(verify(rsaPub, alg, message, sig) && !verify(rsaPub, alg, Data("other".utf8), sig) && sig?.count == 256,
              "RSA \(alg.rawValue): sign / verify / reject tampered")
    }
    let digest = Data(SHA256.hash(data: message))
    let dsig = sign(rsa, .rsaSignatureDigestPKCS1v15SHA256, digest), msig = sign(rsa, .rsaSignatureMessagePKCS1v15SHA256, message)
    check(dsig != nil && dsig == msig, "PKCS#1 v1.5 digest and message algorithms agree (deterministic)")
    check(!SecKeyIsAlgorithmSupported(rsaPub, .sign, .rsaSignatureMessagePKCS1v15SHA256) && SecKeyIsAlgorithmSupported(rsaPub, .encrypt, .rsaEncryptionOAEPSHA256)
          && !SecKeyIsAlgorithmSupported(rsa, .sign, .ecdsaSignatureMessageX962SHA256), "SecKeyIsAlgorithmSupported")
    for alg in [SecKeyAlgorithm.rsaEncryptionOAEPSHA256, .rsaEncryptionOAEPSHA1, .rsaEncryptionPKCS1] {
        let secret = Data("attack at dawn".utf8)
        let ct = SecKeyCreateEncryptedData(rsaPub, alg, secret as CFData, &error) as Data?
        let pt = ct.flatMap { SecKeyCreateDecryptedData(rsa, alg, $0 as CFData, &error) as Data? }
        check(ct?.count == 256 && pt == secret, "RSA \(alg.rawValue) encrypt / decrypt")
    }
    if let ext = external(rsaPub) {
        check(keyFrom(ext, rsa: true, priv: false) == rsaPub && ext.first == 0x30, "RSA public key: PKCS#1 DER external representation round trip")
    } else { check(false, "SecKeyCopyExternalRepresentation RSA") }
    check(SecKeyCreateWithData(Data([1, 2, 3]) as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, &error) == nil
          && errorCode(error) == Int(errSecDecode), "SecKeyCreateWithData rejects garbage (errSecDecode)")

    // EC (P-256), interoperating with CryptoKit
    guard let ec = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: 256] as CFDictionary, &error),
          let ecPub = SecKeyCopyPublicKey(ec), let ecPriv = external(ec), let ecPubData = external(ecPub) else { check(false, "SecKeyCreateRandomKey EC P-256"); return }
    check(ecPriv.count == 97 && ecPubData.count == 65 && ecPubData.first == 4, "EC P-256 external representations (X9.63, 97/65 bytes)")
    let ckPriv = try? P256.Signing.PrivateKey(x963Representation: ecPriv)
    let ckSig = try? ckPriv?.signature(for: message)
    check(verify(ecPub, .ecdsaSignatureMessageX962SHA256, message, ckSig?.derRepresentation), "SecKey verifies a CryptoKit ECDSA signature (X9.62 DER)")
    let secSig = sign(ec, .ecdsaSignatureMessageX962SHA256, message)
    let ckPub = try? P256.Signing.PublicKey(x963Representation: ecPubData)
    check(secSig.flatMap { try? P256.Signing.ECDSASignature(derRepresentation: $0) }.map { ckPub?.isValidSignature($0, for: message) ?? false } ?? false,
          "CryptoKit verifies a SecKey ECDSA signature")
    let raw = sign(ec, .ecdsaSignatureMessageRFC4754SHA256, message)
    check(raw?.count == 64 && verify(ecPub, .ecdsaSignatureMessageRFC4754SHA256, message, raw), "ECDSA RFC 4754 (raw r||s) signatures")
    check(verify(ecPub, .ecdsaSignatureMessageX962SHA256, message, sign(ec, .ecdsaSignatureDigestX962SHA256, digest)), "ECDSA digest vs message algorithms")
    let peer = P256.KeyAgreement.PrivateKey()
    if let peerPub = keyFrom(peer.publicKey.x963Representation, rsa: false, priv: false), let ours = try? P256.KeyAgreement.PublicKey(x963Representation: ecPubData) {
        let info = Data("isim ecdh".utf8)
        let secKey = SecKeyCopyKeyExchangeResult(ec, .ecdhKeyExchangeStandardX963SHA256, peerPub,
                                                 [kSecKeyKeyExchangeParameterRequestedSize: 32, kSecKeyKeyExchangeParameterSharedInfo: info] as CFDictionary, &error) as Data?
        let ckKey = (try? peer.sharedSecretFromKeyAgreement(with: ours))?.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: info, outputByteCount: 32)
        check(secKey != nil && ckKey.map { $0.withUnsafeBytes { Data($0) } } == secKey, "ECDH + X9.63 KDF matches CryptoKit")
        let plain = SecKeyCopyKeyExchangeResult(ec, .ecdhKeyExchangeStandard, peerPub, [:] as CFDictionary, nil) as Data?
        check(plain?.count == 32, "ECDH standard (shared x coordinate)")
    } else { check(false, "EC public key import") }
    for bits in [384, 521] {
        let k = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeEC, kSecAttrKeySizeInBits: bits] as CFDictionary, nil)
        let ok = k.map { verify(SecKeyCopyPublicKey($0)!, .ecdsaSignatureMessageX962SHA512, message, sign($0, .ecdsaSignatureMessageX962SHA512, message)) } ?? false
        check(ok, "EC P-\(bits) keys sign and verify")
    }
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
    check(foundKey.map { verify(SecKeyCopyPublicKey(stored!)!, .ecdsaSignatureMessageX962SHA256, message, sign($0, .ecdsaSignatureMessageX962SHA256, message)) } == true,
          "the key read back from the keychain signs")
    let pubTag = Data("dev.isim.test.rsa-public".utf8)
    SecItemDelete([kSecClass: kSecClassKey, kSecAttrApplicationTag: pubTag] as CFDictionary)
    let addSt = SecItemAdd([kSecClass: kSecClassKey, kSecValueRef: rsaPub, kSecAttrApplicationTag: pubTag] as CFDictionary, nil)
    let dup = SecItemAdd([kSecClass: kSecClassKey, kSecValueRef: rsaPub, kSecAttrApplicationTag: pubTag] as CFDictionary, nil)
    var attrsOut: CFTypeRef?
    _ = SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: pubTag, kSecReturnAttributes: true, kSecReturnData: true] as CFDictionary, &attrsOut)
    let a = attrsOut as? [String: Any] ?? [:]
    check(addSt == errSecSuccess && dup == errSecDuplicateItem && (a[kSecValueData as String] as? Data) == external(rsaPub)
          && a[kSecAttrKeyClass as String] as? String == "0" && a[kSecAttrApplicationLabel as String] != nil,
          "SecItemAdd(kSecValueRef: public key), duplicate detection, attributes + data")
    check(SecItemDelete([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag] as CFDictionary) == errSecSuccess
          && SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag] as CFDictionary, nil) == errSecItemNotFound, "SecItemDelete for keys")
}

func certificateTests() {
    guard let caData = fixture("ca.der"), let leafData = fixture("leaf.der"), let expiredData = fixture("expired.der"), let selfData = fixture("selfsigned.der"),
          let ca = SecCertificateCreateWithData(nil, caData as CFData), let leaf = SecCertificateCreateWithData(nil, leafData as CFData),
          let expired = SecCertificateCreateWithData(nil, expiredData as CFData), let selfSigned = SecCertificateCreateWithData(nil, selfData as CFData) else {
        check(false, "test certificates load"); return
    }
    check(SecCertificateCreateWithData(nil, Data("not a certificate".utf8) as CFData) == nil, "SecCertificateCreateWithData rejects non-DER data")
    check((SecCertificateCopyData(leaf) as Data) == leafData, "SecCertificateCopyData returns the DER")
    check(SecCertificateCopySubjectSummary(leaf) as String? == "test.isim.dev" && SecCertificateCopySubjectSummary(ca) as String? == "isim Test Root CA", "SecCertificateCopySubjectSummary")
    var cn: CFString?, emails: CFArray?
    _ = SecCertificateCopyCommonName(leaf, &cn); _ = SecCertificateCopyEmailAddresses(leaf, &emails)
    check(cn as String? == "test.isim.dev" && (emails as? [String]) == ["admin@isim.dev"], "SecCertificateCopyCommonName / CopyEmailAddresses")
    check((SecCertificateCopySerialNumberData(leaf, nil) as Data?) == Data([0x12, 0x34]), "SecCertificateCopySerialNumberData")
    let leafKey = SecCertificateCopyKey(leaf), caKey = SecCertificateCopyKey(ca)
    let lk = leafKey.flatMap { SecKeyCopyAttributes($0) as NSDictionary? as? [String: Any] }
    check(lk?[kSecAttrKeyType as String] as? String == "42" && lk?[kSecAttrKeySizeInBits as String] as? Int == 2048
          && caKey.flatMap(external)?.count == 65, "SecCertificateCopyKey (RSA 2048 leaf, P-256 CA)")
    check((SecCertificateCopyNormalizedIssuerSequence(leaf) as Data?) == (SecCertificateCopyNormalizedSubjectSequence(ca) as Data?), "issuer sequence = CA subject sequence")

    func evaluate(_ certs: [SecCertificate], policy: SecPolicy, anchors: [SecCertificate]?, date: Date? = nil) -> (Bool, Int, Int) {
        var trust: SecTrust?
        _ = SecTrustCreateWithCertificates(certs as CFArray, policy, &trust)
        guard let trust else { return (false, -1, 0) }
        if let anchors { _ = SecTrustSetAnchorCertificates(trust, anchors as CFArray) }
        if let date { _ = SecTrustSetVerifyDate(trust, date as CFDate) }
        var e: Unmanaged<CFError>?
        let ok = SecTrustEvaluateWithError(trust, &e)
        return (ok, errorCode(e), SecTrustGetCertificateCount(trust))
    }
    let atDate = Date(timeIntervalSince1970: 1_790_000_000)   // 2026-09 (valid for leaf, after the expired one)
    let good = evaluate([leaf], policy: SecPolicyCreateSSL(true, "test.isim.dev" as CFString), anchors: [ca], date: atDate)
    check(good.0 && good.2 == 2, "trust: leaf + custom anchor (SSL policy, matching host) evaluates; chain of 2")
    let wildcard = evaluate([leaf], policy: SecPolicyCreateSSL(true, "api.test.isim.dev" as CFString), anchors: [ca], date: atDate)
    check(wildcard.0, "trust: wildcard subjectAltName matches api.test.isim.dev")
    let wrongHost = evaluate([leaf], policy: SecPolicyCreateSSL(true, "other.example" as CFString), anchors: [ca], date: atDate)
    check(!wrongHost.0 && wrongHost.1 == Int(errSecHostNameMismatch), "trust: host name mismatch (\(wrongHost.1))")
    let noAnchor = evaluate([leaf], policy: SecPolicyCreateBasicX509(), anchors: nil, date: atDate)
    check(!noAnchor.0 && noAnchor.1 == Int(errSecNotTrusted), "trust: test CA is not in the system anchors -> not trusted")
    let exp = evaluate([expired], policy: SecPolicyCreateBasicX509(), anchors: [ca], date: atDate)
    check(!exp.0 && exp.1 == Int(errSecCertificateExpired), "trust: expired certificate (\(exp.1))")
    let before = evaluate([expired], policy: SecPolicyCreateBasicX509(), anchors: [ca], date: Date(timeIntervalSince1970: 1_768_000_000))
    check(before.0, "trust: SecTrustSetVerifyDate inside the validity period")
    let selfTrust = evaluate([selfSigned], policy: SecPolicyCreateBasicX509(), anchors: [ca], date: atDate)
    check(!selfTrust.0, "trust: self-signed certificate rejected")
    var t: SecTrust?
    _ = SecTrustCreateWithCertificates([selfSigned] as CFArray, SecPolicyCreateBasicX509(), &t)
    if let t {
        _ = SecTrustEvaluateWithError(t, nil)
        var result = SecTrustResultType.invalid
        _ = SecTrustGetTrustResult(t, &result)
        let exceptions = SecTrustCopyExceptions(t)
        let accepted = SecTrustSetExceptions(t, exceptions) && SecTrustEvaluateWithError(t, nil)
        _ = SecTrustGetTrustResult(t, &result)
        check(accepted && result == .proceed, "SecTrustCopyExceptions / SetExceptions accept the leaf (result .proceed)")
        check((SecTrustCopyCertificateChain(t) as? [SecCertificate])?.first == selfSigned && SecTrustCopyKey(t) != nil, "SecTrustCopyCertificateChain / CopyKey")
    }
    if let t2 = t {
        let done = DispatchSemaphore(value: 0)
        var asyncOK = false
        _ = SecTrustEvaluateAsyncWithError(t2, DispatchQueue.global()) { _, ok, _ in asyncOK = ok; done.signal() }
        _ = done.wait(timeout: .now() + 5)
        check(asyncOK, "SecTrustEvaluateAsyncWithError")
    }

    // PKCS#12 import -> identity
    guard let p12 = fixture("identity.p12") else { check(false, "identity.p12 fixture"); return }
    var items: CFArray?
    check(SecPKCS12Import(p12 as CFData, [kSecImportExportPassphrase: "wrong"] as CFDictionary, &items) == errSecAuthFailed, "SecPKCS12Import with a wrong password -> errSecAuthFailed")
    let st = SecPKCS12Import(p12 as CFData, [kSecImportExportPassphrase: "isim"] as CFDictionary, &items)
    let first = (items as? [[String: Any]])?.first
    let identity = first?[kSecImportItemIdentity as String] as! SecIdentity?
    let chain = first?[kSecImportItemCertChain as String] as? [SecCertificate]
    check(st == errSecSuccess && identity != nil && chain?.count == 2 && first?[kSecImportItemLabel as String] as? String == "test.isim.dev",
          "SecPKCS12Import: identity, chain (leaf + CA), label")
    guard let identity else { return }
    var idCert: SecCertificate?, idKey: SecKey?
    _ = SecIdentityCopyCertificate(identity, &idCert); _ = SecIdentityCopyPrivateKey(identity, &idKey)
    let msg = Data("signed with the identity".utf8)
    check(idCert == leaf && idKey.map { verify(SecCertificateCopyKey(leaf)!, .rsaSignatureMessagePKCS1v15SHA256, msg, sign($0, .rsaSignatureMessagePKCS1v15SHA256, msg)) } == true,
          "SecIdentityCopyCertificate / CopyPrivateKey (the key matches the certificate)")

    // certificates and identities in the keychain
    SecItemDelete([kSecClass: kSecClassCertificate] as CFDictionary)
    SecItemDelete([kSecClass: kSecClassIdentity] as CFDictionary)
    let addCert = SecItemAdd([kSecClass: kSecClassCertificate, kSecValueRef: ca, kSecAttrLabel: "isim root"] as CFDictionary, nil)
    let dupCert = SecItemAdd([kSecClass: kSecClassCertificate, kSecValueRef: ca] as CFDictionary, nil)
    var certOut: CFTypeRef?
    let certQ = SecItemCopyMatching([kSecClass: kSecClassCertificate, kSecAttrLabel: "isim root", kSecReturnRef: true] as CFDictionary, &certOut)
    check(addCert == errSecSuccess && dupCert == errSecDuplicateItem && certQ == errSecSuccess && (certOut as! SecCertificate?) == ca,
          "keychain certificates: add, duplicate, find by label (kSecReturnRef)")
    var byIssuer: CFTypeRef?
    _ = SecItemCopyMatching([kSecClass: kSecClassCertificate, kSecAttrIssuer: SecCertificateCopyNormalizedIssuerSequence(ca)! as Data,
                             kSecReturnAttributes: true] as CFDictionary, &byIssuer)
    check((byIssuer as? [String: Any])?[kSecAttrSerialNumber as String] != nil, "keychain certificates: query by issuer, attributes")
    let addId = SecItemAdd([kSecClass: kSecClassIdentity, kSecValueRef: identity] as CFDictionary, nil)
    var idOut: CFTypeRef?
    let idQ = SecItemCopyMatching([kSecClass: kSecClassIdentity, kSecReturnRef: true] as CFDictionary, &idOut)
    var attrsOut: CFTypeRef?
    _ = SecItemCopyMatching([kSecClass: kSecClassIdentity, kSecReturnAttributes: true] as CFDictionary, &attrsOut)
    let hidesKey = (attrsOut as? [String: Any]).map { !$0.keys.contains { $0.hasPrefix("_") } } ?? false
    check(addId == errSecSuccess && idQ == errSecSuccess && (idOut as! SecIdentity?) == identity && hidesKey,
          "keychain identities: SecItemAdd(kSecValueRef: identity), read back as SecIdentity")
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
    let compactKey = P256.KeyAgreement.PrivateKey(compactRepresentable: true)
    let compact = compactKey.publicKey.compactRepresentation
    let restored = compact.flatMap { try? P256.KeyAgreement.PublicKey(compactRepresentation: $0) }
    check(compact?.count == 32 && restored?.x963Representation == compactKey.publicKey.x963Representation, "P-256 compact representation round trip")
    let sk384 = P384.Signing.PrivateKey(compactRepresentable: true)
    check(sk384.publicKey.compactRepresentation.flatMap { try? P384.Signing.PublicKey(compactRepresentation: $0) }?.rawRepresentation == sk384.publicKey.rawRepresentation,
          "P-384 compact representation round trip")
    let sk = P256.Signing.PrivateKey()
    let pem = sk.pemRepresentation
    let back = try? P256.Signing.PrivateKey(pemRepresentation: pem)
    check(pem.hasPrefix("-----BEGIN PRIVATE KEY-----") && back?.rawRepresentation == sk.rawRepresentation, "private key PEM (PKCS#8) round trip")
    check((try? P521.KeyAgreement.PrivateKey(derRepresentation: P521.KeyAgreement.PrivateKey().derRepresentation)) != nil, "P-521 private key DER round trip")
    if let caKey = fixture("ca.key").flatMap({ String(data: $0, encoding: .utf8) }), let caCert = fixture("ca.der").flatMap({ SecCertificateCreateWithData(nil, $0 as CFData) }) {
        let k = try? P256.Signing.PrivateKey(pemRepresentation: caKey)
        check(k.map { $0.publicKey.x963Representation } == SecCertificateCopyKey(caCert).flatMap(external), "reads an OpenSSL SEC1 \"EC PRIVATE KEY\" PEM (matches the CA certificate's key)")
    } else { check(false, "fixture ca.key") }
    for v in hpkeVectors {
        let name = v["name"]!, mode = Int(v["mode"]!)!
        let info = Data("isim HPKE test".utf8), psk = SymmetricKey(data: Data("isim pre-shared key 0123456789!!".utf8)), pskID = Data("isim-psk".utf8)
        do {
            var r: HPKE.Recipient
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
            let exp = try r.exportSecret(context: Data("isim exporter".utf8), outputByteCount: 32)
            check(String(decoding: m1, as: UTF8.self) == "first message from OpenSSL" && String(decoding: m2, as: UTF8.self) == "second message"
                  && exp.withUnsafeBytes { hex($0) } == v["exported"], "HPKE \(name): opens OpenSSL's messages, exporter matches")
        } catch { check(false, "HPKE \(name): \(error)") }
    }
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
