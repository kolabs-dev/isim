// Known-answer tests for CommonCrypto and CryptoKit (vectors from FIPS 180, RFC 1321, RFC 4231, RFC 5869, RFC 6070,
// FIPS 197, SP 800-38A, the GCM spec, RFC 8439, RFC 7748, RFC 8032 and RFC 6979).
import Foundation
import CommonCrypto
import CryptoKit

func unhex(_ s: String) -> [UInt8] {
    var out = [UInt8](), hi: UInt8? = nil
    for c in s.utf8 where c != 32 {
        let v: UInt8 = c >= 97 ? c - 87 : c >= 65 ? c - 55 : c - 48
        if let h = hi { out.append(h << 4 | v); hi = nil } else { hi = v }
    }
    return out
}
func hex<S: Sequence>(_ s: S) -> String where S.Element == UInt8 { s.map { String(format: "%02x", $0) }.joined() }

func commonCryptoTests() {
    let abc = Array("abc".utf8)
    var md = [UInt8](repeating: 0, count: 64)
    _ = CC_SHA256(abc, CC_LONG(abc.count), &md)
    check(hex(md.prefix(32)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "CC_SHA256(\"abc\")")
    _ = CC_MD5(abc, 3, &md)
    check(hex(md.prefix(16)) == "900150983cd24fb0d6963f7d28e17f72", "CC_MD5(\"abc\")")
    _ = CC_SHA1(abc, 3, &md)
    check(hex(md.prefix(20)) == "a9993e364706816aba3e25717850c26c9cd0d89d", "CC_SHA1(\"abc\")")
    _ = CC_SHA224(abc, 3, &md)
    check(hex(md.prefix(28)) == "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7", "CC_SHA224(\"abc\")")
    _ = CC_SHA384(abc, 3, &md)
    check(hex(md.prefix(48)) == "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7", "CC_SHA384(\"abc\")")
    _ = CC_SHA512(abc, 3, &md)
    check(hex(md) == "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", "CC_SHA512(\"abc\")")

    // streaming with odd chunk sizes across block boundaries: one million "a"
    let chunk = [UInt8](repeating: 0x61, count: 997)
    var ctx = CC_SHA256_CTX()
    _ = CC_SHA256_Init(&ctx)
    var left = 1_000_000
    while left > 0 { let n = min(left, chunk.count); _ = CC_SHA256_Update(&ctx, chunk, CC_LONG(n)); left -= n }
    _ = CC_SHA256_Final(&md, &ctx)
    check(hex(md.prefix(32)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0", "CC_SHA256_Init/Update/Final, 10^6 x \"a\"")
    var c5 = CC_SHA512_CTX()
    _ = CC_SHA512_Init(&c5)
    left = 1_000_000
    while left > 0 { let n = min(left, 113); _ = CC_SHA512_Update(&c5, chunk, CC_LONG(n)); left -= n }
    _ = CC_SHA512_Final(&md, &c5)
    check(hex(md) == "e718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973ebde0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b", "CC_SHA512 streaming, 10^6 x \"a\"")
    var c1 = CC_MD5_CTX()
    _ = CC_MD5_Init(&c1)
    left = 1_000_000
    while left > 0 { let n = min(left, 61); _ = CC_MD5_Update(&c1, chunk, CC_LONG(n)); left -= n }
    _ = CC_MD5_Final(&md, &c1)
    check(hex(md.prefix(16)) == "7707d6ae4e027c70eea2a935c2296f21", "CC_MD5 streaming, 10^6 x \"a\"")

    // HMAC (RFC 4231 cases 1, 2, 6)
    var mac = [UInt8](repeating: 0, count: 64)
    let k1 = [UInt8](repeating: 0x0b, count: 20), hi = Array("Hi There".utf8)
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), k1, k1.count, hi, hi.count, &mac)
    check(hex(mac.prefix(32)) == "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", "CCHmac SHA256 (RFC 4231 #1)")
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA512), k1, k1.count, hi, hi.count, &mac)
    check(hex(mac) == "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854", "CCHmac SHA512 (RFC 4231 #1)")
    var hctx = CCHmacContext()
    let jefe = Array("Jefe".utf8), what = Array("what do ya want for nothing?".utf8)
    CCHmacInit(&hctx, CCHmacAlgorithm(kCCHmacAlgSHA256), jefe, jefe.count)
    CCHmacUpdate(&hctx, what, 10); CCHmacUpdate(&hctx, Array(what[10...]), what.count - 10)
    CCHmacFinal(&hctx, &mac)
    check(hex(mac.prefix(32)) == "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", "CCHmacInit/Update/Final (RFC 4231 #2)")
    let bigKey = [UInt8](repeating: 0xaa, count: 131), longMsg = Array("Test Using Larger Than Block-Size Key - Hash Key First".utf8)
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), bigKey, bigKey.count, longMsg, longMsg.count, &mac)
    check(hex(mac.prefix(32)) == "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54", "CCHmac with a key longer than the block (RFC 4231 #6)")

    // PBKDF2 (RFC 6070 and SHA-256 equivalents)
    var dk = [UInt8](repeating: 0, count: 32)
    var st = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), "password", 8, Array("salt".utf8), 4, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 4096, &dk, 20)
    check(st == kCCSuccess && hex(dk.prefix(20)) == "4b007901b765489abead49d926f721d065a429c1", "CCKeyDerivationPBKDF SHA1 4096 rounds (RFC 6070)")
    st = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), "password", 8, Array("salt".utf8), 4, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 4096, &dk, 32)
    check(st == kCCSuccess && hex(dk) == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a", "CCKeyDerivationPBKDF SHA256 4096 rounds")

    // AES (FIPS-197 C.1/C.3, SP 800-38A F.2.1) with CCCrypt
    var out = [UInt8](repeating: 0, count: 64), moved = 0
    let pt = unhex("00112233445566778899aabbccddeeff")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode), unhex("000102030405060708090a0b0c0d0e0f"), 16, nil, pt, 16, &out, out.count, &moved)
    check(st == kCCSuccess && moved == 16 && hex(out.prefix(16)) == "69c4e0d86a7b0430d8cdb78070b4c55a", "CCCrypt AES-128 ECB (FIPS-197)")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode), unhex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"), 32, nil, pt, 16, &out, out.count, &moved)
    check(st == kCCSuccess && hex(out.prefix(16)) == "8ea2b7ca516745bfeafc49904b496089", "CCCrypt AES-256 ECB (FIPS-197)")
    let cbcKey = unhex("2b7e151628aed2a6abf7158809cf4f3c"), iv = unhex("000102030405060708090a0b0c0d0e0f")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), 0, cbcKey, 16, iv, unhex("6bc1bee22e409f96e93d7e117393172a"), 16, &out, out.count, &moved)
    check(st == kCCSuccess && hex(out.prefix(16)) == "7649abac8119b246cee98e9b12e9197d", "CCCrypt AES-128 CBC (SP 800-38A)")
    // PKCS#7 round trip and error codes
    let msg = Array("isim CommonCrypto round trip!".utf8)
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), cbcKey, 16, iv, msg, msg.count, &out, out.count, &moved)
    let ct = Array(out.prefix(moved))
    check(st == kCCSuccess && moved == 32, "CCCrypt AES-CBC PKCS7 pads to whole blocks")
    var back = [UInt8](repeating: 0, count: 64)
    st = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), cbcKey, 16, iv, ct, ct.count, &back, back.count, &moved)
    check(st == kCCSuccess && Array(back.prefix(moved)) == msg, "CCCrypt AES-CBC PKCS7 decrypts")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), 0, cbcKey, 16, iv, msg, msg.count, &out, out.count, &moved)
    check(st == kCCAlignmentError, "CCCrypt without padding rejects partial blocks (kCCAlignmentError)")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), cbcKey, 16, iv, msg, msg.count, &out, 8, &moved)
    check(st == kCCBufferTooSmall && moved == 32, "CCCrypt reports kCCBufferTooSmall with the needed size")
    st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), 0, Array(cbcKey.prefix(15)), 15, iv, pt, 16, &out, out.count, &moved)
    check(st == kCCParamError, "CCCrypt rejects a bad key size (kCCParamError)")
    // CCCryptor CTR (SP 800-38A F.5.1)
    var cr: CCCryptorRef?
    st = CCCryptorCreateWithMode(CCOperation(kCCEncrypt), CCMode(kCCModeCTR), CCAlgorithm(kCCAlgorithmAES), CCPadding(ccNoPadding), unhex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"), cbcKey, 16, nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &cr)
    st = st == kCCSuccess ? CCCryptorUpdate(cr, unhex("6bc1bee22e409f96e93d7e117393172a"), 16, &out, out.count, &moved) : st
    check(st == kCCSuccess && hex(out.prefix(16)) == "874d6191b620e3261bef6864990db6ce", "CCCryptorCreateWithMode AES-CTR (SP 800-38A)")
    CCCryptorRelease(cr)
    var rnd = [UInt8](repeating: 0, count: 32)
    check(CCRandomGenerateBytes(&rnd, 32) == kCCSuccess && rnd != [UInt8](repeating: 0, count: 32), "CCRandomGenerateBytes")
}

func cryptoKitTests() {
    check(SHA256.hash(data: Data("abc".utf8)).description == "SHA256 digest: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA256 digest description")
    check(hex(SHA256.hash(data: Data())) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA256 of empty data")
    check(hex(SHA384.hash(data: Array("abc".utf8))) == "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7", "SHA384")
    check(hex(SHA512.hash(data: Array("abc".utf8))) == "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", "SHA512")
    check(Insecure.MD5.hash(data: Data()).description == "MD5 digest: d41d8cd98f00b204e9800998ecf8427e", "Insecure.MD5")
    check(hex(Insecure.SHA1.hash(data: Data("abc".utf8))) == "a9993e364706816aba3e25717850c26c9cd0d89d", "Insecure.SHA1")
    var h = SHA256()
    h.update(data: Data("abcdbcdecdefdefgefghfghighij".utf8))
    let copy = h
    h.update(data: Data("hijkijkljklmklmnlmnomnopnopq".utf8))
    check(hex(h.finalize()) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", "SHA256 incremental update")
    var c2 = copy; c2.update(data: Data("hijkijkljklmklmnlmnomnopnopq".utf8))
    check(c2.finalize() == h.finalize(), "hash functions are values (copies hash independently)")
    check(SHA256Digest.byteCount == 32 && SHA512.byteCount == 64 && SHA256.blockByteCount == 64, "byteCount / blockByteCount")

    let key = SymmetricKey(data: [UInt8](repeating: 0x0b, count: 20))
    let code = HMAC<SHA256>.authenticationCode(for: Data("Hi There".utf8), using: key)
    check(hex(code) == "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", "HMAC<SHA256> (RFC 4231 #1)")
    check(code.description.hasPrefix("HMAC with SHA256: b0344c61"), "HMAC description")
    check(HMAC<SHA256>.isValidAuthenticationCode(Data(code), authenticating: Data("Hi There".utf8), using: key), "HMAC.isValidAuthenticationCode")
    check(!HMAC<SHA256>.isValidAuthenticationCode(Data(code), authenticating: Data("Hi there".utf8), using: key), "HMAC rejects other data")
    check(hex(HMAC<SHA384>.authenticationCode(for: Array("what do ya want for nothing?".utf8), using: SymmetricKey(data: Array("Jefe".utf8)))) ==
          "af45d2e376484031617f78d2b58a6b1b9c7ef464f5a01b47e42ec3736322445e8e2240ca5e69e2c78b3239ecfab21649", "HMAC<SHA384> (RFC 4231 #2)")

    let okm = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: [UInt8](repeating: 0x0b, count: 22)),
                                     salt: unhex("000102030405060708090a0b0c"), info: unhex("f0f1f2f3f4f5f6f7f8f9"), outputByteCount: 42)
    check(okm.withUnsafeBytes { hex($0) } == "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865", "HKDF<SHA256> (RFC 5869 #1)")
    let prk = HKDF<SHA256>.extract(inputKeyMaterial: SymmetricKey(data: [UInt8](repeating: 0x0b, count: 22)), salt: unhex("000102030405060708090a0b0c"))
    check(hex(prk) == "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5", "HKDF.extract (RFC 5869 #1 PRK)")
    check(SymmetricKey(size: .bits256).bitCount == 256 && SymmetricKey(size: .bits256) != SymmetricKey(size: .bits256), "SymmetricKey(size:) is random")

    // AES-GCM (GCM spec test cases 1-2, then round trips)
    do {
        let zeroKey = SymmetricKey(data: [UInt8](repeating: 0, count: 16))
        let nonce = try AES.GCM.Nonce(data: [UInt8](repeating: 0, count: 12))
        let box0 = try AES.GCM.seal(Data(), using: zeroKey, nonce: nonce)
        check(hex(box0.tag) == "58e2fccefa7e3061367f1d57a4e7455a", "AES.GCM empty plaintext tag (GCM test case 1)")
        let box = try AES.GCM.seal([UInt8](repeating: 0, count: 16), using: zeroKey, nonce: nonce)
        check(hex(box.ciphertext) == "0388dace60b6a392f328c2b971b2fe78" && hex(box.tag) == "ab6e47d42cec13bdf53a67b21257bddf", "AES.GCM.seal (GCM test case 2)")
        let k = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(Data("attack at dawn".utf8), using: k, authenticating: Data("hdr".utf8))
        check(sealed.combined!.count == 12 + 14 + 16, "AES.GCM combined = nonce + ciphertext + tag")
        let reopened = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed.combined!), using: k, authenticating: Data("hdr".utf8))
        check(String(decoding: reopened, as: UTF8.self) == "attack at dawn", "AES.GCM round trip with AAD")
        var tampered = Array(sealed.combined!); tampered[13] ^= 1
        do { _ = try AES.GCM.open(try AES.GCM.SealedBox(combined: tampered), using: k, authenticating: Data("hdr".utf8)); check(false, "AES.GCM rejects tampering") }
        catch { check(error as? CryptoKitError == .authenticationFailure, "AES.GCM rejects tampering (authenticationFailure)") }
        do { _ = try AES.GCM.seal(Data(), using: SymmetricKey(data: [UInt8](repeating: 1, count: 10))); check(false, "AES.GCM key size") }
        catch { check(error as? CryptoKitError == .incorrectKeySize, "AES.GCM rejects a bad key size") }
    } catch { check(false, "AES.GCM threw \(error)") }

    // ChaChaPoly (RFC 8439 2.8.2)
    do {
        let key = SymmetricKey(data: unhex("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"))
        let nonce = try ChaChaPoly.Nonce(data: unhex("070000004041424344454647"))
        let text = Data("Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.".utf8)
        let box = try ChaChaPoly.seal(text, using: key, nonce: nonce, authenticating: unhex("50515253c0c1c2c3c4c5c6c7"))
        check(hex(box.ciphertext.prefix(16)) == "d31a8d34648e60db7b86afbc53ef7ec2" && hex(box.tag) == "1ae10b594f09e26a7e902ecbd0600691", "ChaChaPoly.seal (RFC 8439)")
        let opened = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: box.combined), using: key, authenticating: unhex("50515253c0c1c2c3c4c5c6c7"))
        check(opened == text, "ChaChaPoly.open round trip")
    } catch { check(false, "ChaChaPoly threw \(error)") }

    // Curve25519 (RFC 7748 6.1, RFC 8032 test 1)
    do {
        let alice = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: unhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
        let bob = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: unhex("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"))
        check(hex(alice.publicKey.rawRepresentation) == "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a", "X25519 public key (RFC 7748)")
        let s1 = try alice.sharedSecretFromKeyAgreement(with: bob.publicKey), s2 = try bob.sharedSecretFromKeyAgreement(with: alice.publicKey)
        check(s1.withUnsafeBytes { hex($0) } == "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742" && s1 == s2, "X25519 shared secret (RFC 7748)")
        let k1 = s1.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("salt".utf8), sharedInfo: Data("info".utf8), outputByteCount: 32)
        let k2 = s2.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("salt".utf8), sharedInfo: Data("info".utf8), outputByteCount: 32)
        check(k1 == k2 && k1.bitCount == 256, "SharedSecret.hkdfDerivedSymmetricKey")
        let ed = try Curve25519.Signing.PrivateKey(rawRepresentation: unhex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"))
        check(hex(ed.publicKey.rawRepresentation) == "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", "Ed25519 public key (RFC 8032)")
        let sig = try ed.signature(for: Data())
        check(hex(sig) == "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b", "Ed25519 signature (RFC 8032 test 1)")
        check(ed.publicKey.isValidSignature(sig, for: Data()) && !ed.publicKey.isValidSignature(sig, for: Data([1])), "Ed25519 verify")
        let fresh = Curve25519.Signing.PrivateKey()
        let s = try fresh.signature(for: Data("hello".utf8))
        check(try Curve25519.Signing.PublicKey(rawRepresentation: fresh.publicKey.rawRepresentation).isValidSignature(s, for: Data("hello".utf8)), "Ed25519 generated key round trip")
    } catch { check(false, "Curve25519 threw \(error)") }

    // P-256 (RFC 6979 A.2.5 key and SHA-256 "sample" signature)
    do {
        let priv = try P256.Signing.PrivateKey(rawRepresentation: unhex("C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721"))
        check(hex(priv.publicKey.rawRepresentation) == "60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb6" + "7903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299", "P256 public key from private (RFC 6979)")
        let sig = try P256.Signing.ECDSASignature(rawRepresentation: unhex("EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716" + "F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8"))
        check(priv.publicKey.isValidSignature(sig, for: Data("sample".utf8)), "P256 verifies the RFC 6979 signature")
        check(!priv.publicKey.isValidSignature(sig, for: Data("samples".utf8)), "P256 rejects a signature for other data")
        let der = sig.derRepresentation
        check(try P256.Signing.ECDSASignature(derRepresentation: der).rawRepresentation == sig.rawRepresentation, "ECDSASignature DER round trip")
        let mine = try priv.signature(for: Data("isim".utf8))
        check(priv.publicKey.isValidSignature(mine, for: SHA256.hash(data: Data("isim".utf8))), "P256 sign + verify digest")
        let pub2 = try P256.Signing.PublicKey(compressedRepresentation: priv.publicKey.compressedRepresentation)
        check(pub2.x963Representation == priv.publicKey.x963Representation, "P256 compressed public key round trip")
        let pem = priv.publicKey.pemRepresentation
        let fromPEM = try P256.Signing.PublicKey(pemRepresentation: pem)
        check(pem.hasPrefix("-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE") && fromPEM.rawRepresentation == priv.publicKey.rawRepresentation, "P256 PEM public key")
        let a = P256.KeyAgreement.PrivateKey(), b = P256.KeyAgreement.PrivateKey()
        let za = try a.sharedSecretFromKeyAgreement(with: b.publicKey), zb = try b.sharedSecretFromKeyAgreement(with: a.publicKey)
        check(za == zb && za.withUnsafeBytes { $0.count } == 32, "P256 ECDH agrees")
        let x = za.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 16)
        check(x == zb.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 16), "SharedSecret.x963DerivedSymmetricKey")
        let p384 = P384.Signing.PrivateKey(), p521 = P521.Signing.PrivateKey()
        let s384 = try p384.signature(for: Data([1, 2])), s521 = try p521.signature(for: Data([3]))
        check(p384.publicKey.isValidSignature(s384, for: Data([1, 2])) && p521.publicKey.isValidSignature(s521, for: Data([3])), "P384/P521 sign + verify")
        check(p521.rawRepresentation.count == 66 && p521.publicKey.x963Representation.count == 133, "P521 key sizes")
        do { _ = try P256.Signing.PublicKey(rawRepresentation: [UInt8](repeating: 7, count: 64)); check(false, "P256 rejects off-curve points") }
        catch { check(true, "P256 rejects off-curve points") }
    } catch { check(false, "P256 threw \(error)") }
}
