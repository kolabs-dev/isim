// Known-answer tests for CryptoKit's iOS 26 additions: SHA-3 (FIPS 202), ML-KEM (FIPS 203), ML-DSA (FIPS 204) and
// X-Wing (draft-connolly-cfrg-xwing-kem-06, its first test vector). The ML-KEM and ML-DSA answers come from
// independent implementations (kyber-py 1.2, dilithium-py 1.5: ML_KEM_768._keygen_internal / _encaps_internal,
// ML_DSA_65._keygen_internal / sign(deterministic=True)); long values are compared by their SHA3-256.
import Foundation
@_spi(isim) import CryptoKit

@available(iOS 26.0, *)
func postQuantumTests() {
    func h<D: ContiguousBytes>(_ d: D) -> String { hex(SHA3_256.hash(data: d)) }

    // SHA-3
    check(hex(SHA3_256.hash(data: [UInt8]())) == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", "SHA3_256(\"\")")
    check(hex(SHA3_256.hash(data: Array("abc".utf8))) == "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", "SHA3_256(\"abc\")")
    check(hex(SHA3_384.hash(data: Array("abc".utf8))) == "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25", "SHA3_384(\"abc\")")
    check(hex(SHA3_512.hash(data: Array("abc".utf8))) == "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0", "SHA3_512(\"abc\")")
    check(hex(SHA3_384.hash(data: [UInt8](repeating: 0x61, count: 1000))) == "ccf4495ff20b4b33a1cc1917f9f0fe0fcb5e3d08e542cf4d4a90dd950b748e7e1cc07d2f3b36d62dd240724417cdd81b", "SHA3_384(1000 x \"a\")")
    var s3 = SHA3_256(), s5 = SHA3_512()
    let chunk = [UInt8](repeating: 0x61, count: 997)
    var left = 1_000_000
    while left > 0 { let n = min(left, 997); s3.update(data: chunk[0..<n].map { $0 }); left -= n }
    left = 1_000_000
    while left > 0 { let n = min(left, 71); s5.update(data: Array(chunk[0..<n])); left -= n }
    check(hex(s3.finalize()) == "5c8875ae474a3634ba4fd55ec85bffd661f32aca75c6d699d0cdcb6c115891c1", "SHA3_256 streaming, 10^6 x \"a\"")
    check(hex(s5.finalize()) == "3c3a876da14034ab60627c077bb98f7e120a2a5370212dffb3385a18d4f38859ed311d0a9d5141ce9cc5c66ee689b266a8aa18ace8282a0e0db596c90b0a7b87", "SHA3_512 streaming, 10^6 x \"a\"")
    check(SHA3_256.byteCount == 32 && SHA3_256.blockByteCount == 136 && SHA3_512.blockByteCount == 72, "SHA3 sizes")
    let mac = HMAC<SHA3_256>.authenticationCode(for: Array("The quick brown fox jumps over the lazy dog".utf8), using: SymmetricKey(data: Array("key".utf8)))
    check(hex(mac) == "8c6e0683409427f8931711b10ca92a506eb1fafa48fadd66d76126f47ac2c333", "HMAC<SHA3_256>")

    // ML-KEM: seed d ‖ z = 00..3f, encapsulation randomness m = 40..5f
    let seed = (0..<64).map { UInt8($0) }, m = (64..<96).map { UInt8($0) }
    do {
        let sk = try MLKEM768.PrivateKey(seedRepresentation: seed, publicKey: nil)
        check(h(sk.publicKey.rawRepresentation) == "a24e16d8f8f9383a95b77050f4d9fd2f5733eec1d63ef3c23ebf9918173669a7", "MLKEM768 KeyGen_internal (public key)")
        let r = try sk.publicKey._encapsulate(m: m)
        check(h(r.encapsulated) == "b4cfbd24cef67afd3764276c6980e0f88f8e9ca57f59b7f12fe1a9c1e72f4710" && r.encapsulated.count == 1088, "MLKEM768 Encaps_internal (ciphertext)")
        check(hex(_bytes(r.sharedSecret)) == "9cddd089ffe70e3996e76f7c8d06746df34d07e8657bc0fcf2bb0e1c3084aea1", "MLKEM768 Encaps_internal (shared secret)")
        check(hex(_bytes(try sk.decapsulate(r.encapsulated))) == "9cddd089ffe70e3996e76f7c8d06746df34d07e8657bc0fcf2bb0e1c3084aea1", "MLKEM768 decapsulate")
        var bad = [UInt8](r.encapsulated); bad[0] ^= 1
        check(hex(_bytes(try sk.decapsulate(Data(bad)))) == "dcfc80c6db46ff7028e3a4398651c063ae7a42c107a6dc8cb07141861698ab92", "MLKEM768 implicit rejection of a modified ciphertext")
        let fresh = try MLKEM768.PrivateKey()
        let e = try fresh.publicKey.encapsulate()
        check(_bytes(try fresh.decapsulate(e.encapsulated)) == _bytes(e.sharedSecret), "MLKEM768 random key: encapsulate / decapsulate")
        let back = try MLKEM768.PrivateKey(integrityCheckedRepresentation: fresh.integrityCheckedRepresentation)
        check(back.publicKey.rawRepresentation == fresh.publicKey.rawRepresentation && fresh.seedRepresentation.count == 64
              && fresh.integrityCheckedRepresentation.count == 96, "MLKEM768 integrityCheckedRepresentation round trip")
        var damaged = [UInt8](fresh.integrityCheckedRepresentation); damaged[70] ^= 1
        check((try? MLKEM768.PrivateKey(integrityCheckedRepresentation: damaged)) == nil, "MLKEM768 damaged integrityCheckedRepresentation rejected")
        do { _ = try MLKEM768.PrivateKey(seedRepresentation: seed, publicKey: fresh.publicKey); check(false, "MLKEM768 seed / public key mismatch") }
        catch { check(error as? KEM.Errors == .publicKeyMismatchDuringInitialization, "MLKEM768 seed / public key mismatch") }
        var big = [UInt8](sk.publicKey.rawRepresentation); big[0] = 0xff; big[1] |= 0x0f            // first coefficient 4095 >= q
        check((try? MLKEM768.PublicKey(rawRepresentation: big)) == nil, "MLKEM768 public key modulus check")
        check((try? MLKEM768.PublicKey(rawRepresentation: sk.publicKey.rawRepresentation)) != nil, "MLKEM768 PublicKey(rawRepresentation:)")

        let sk4 = try MLKEM1024.PrivateKey(seedRepresentation: seed, publicKey: nil)
        check(h(sk4.publicKey.rawRepresentation) == "61349e5c131a7e116a0463861d7d18663c5627c38c7147ddaadfd48acd7a4535", "MLKEM1024 KeyGen_internal (public key)")
        let r4 = try sk4.publicKey._encapsulate(m: m)
        check(h(r4.encapsulated) == "c1579fa02c614f3762b2a799b51e41cebb8f820f34fa736af02c56de2460ce3c" && r4.encapsulated.count == 1568, "MLKEM1024 Encaps_internal (ciphertext)")
        check(hex(_bytes(try sk4.decapsulate(r4.encapsulated))) == "0ad8d1ea1b8dd788979b4379581218df9321bdce5567eca42ae6be7d395f1a54", "MLKEM1024 decapsulate")
        var bad4 = [UInt8](r4.encapsulated); bad4[0] ^= 1
        check(hex(_bytes(try sk4.decapsulate(Data(bad4)))) == "8f2c880890996c587aa500cf8b6da03372de706a9f96075744bb0956ea6fbaac", "MLKEM1024 implicit rejection")
        let f4 = try MLKEM1024.PrivateKey.generate()
        let e4 = try f4.publicKey.encapsulate()
        check(_bytes(try f4.decapsulate(e4.encapsulated)) == _bytes(e4.sharedSecret), "MLKEM1024 random key: encapsulate / decapsulate")
    } catch { check(false, "ML-KEM threw \(error)") }

    // ML-DSA: seed ξ = 64..83, message "isim"
    let xi = (100..<132).map { UInt8($0) }, msg = Array("isim".utf8)
    do {
        let sk = try MLDSA65.PrivateKey(seedRepresentation: xi, publicKey: nil)
        check(h(sk.publicKey.rawRepresentation) == "e6ac208ad79a37805d4e9fc1187feb870f5c29943c636968bd8e1e3789afc678", "MLDSA65 KeyGen_internal (public key)")
        let d0 = try sk._deterministicSignature(for: msg, context: [])
        let d1 = try sk._deterministicSignature(for: msg, context: Array("ctx".utf8))
        check(d0.count == 3309 && h(d0) == "643e4066e46ae8cea1876e76538e5de59467a8b68a2223c48bd3544393cf11aa", "MLDSA65 deterministic signature")
        check(h(d1) == "a6039c448a9304c901825b5f3101054acc0769dd7de3122697f9a96ca7961484", "MLDSA65 deterministic signature with a context")
        check(sk.publicKey.isValidSignature(d0, for: msg) && sk.publicKey.isValidSignature(d1, for: msg, context: Array("ctx".utf8)), "MLDSA65 verifies")
        check(!sk.publicKey.isValidSignature(d1, for: msg) && !sk.publicKey.isValidSignature(d0, for: Array("isin".utf8)), "MLDSA65 rejects a wrong context or message")
        var t = [UInt8](d0); t[100] ^= 4
        check(!sk.publicKey.isValidSignature(t, for: msg), "MLDSA65 rejects a modified signature")
        let hedged = try sk.signature(for: msg), hedged2 = try sk.signature(for: msg)
        check(hedged != hedged2 && sk.publicKey.isValidSignature(hedged, for: msg), "MLDSA65 hedged signatures differ and verify")
        check((try? sk.signature(for: msg, context: [UInt8](repeating: 1, count: 256))) == nil, "MLDSA65 context longer than 255 bytes rejected")
        let pk = try MLDSA65.PublicKey(rawRepresentation: sk.publicKey.rawRepresentation)
        check(pk.isValidSignature(hedged, for: msg), "MLDSA65 PublicKey(rawRepresentation:)")
        let back = try MLDSA65.PrivateKey(integrityCheckedRepresentation: sk.integrityCheckedRepresentation)
        check(back.publicKey.rawRepresentation == sk.publicKey.rawRepresentation && sk.integrityCheckedRepresentation.count == 64, "MLDSA65 integrityCheckedRepresentation round trip")

        let sk8 = try MLDSA87.PrivateKey(seedRepresentation: xi, publicKey: nil)
        check(h(sk8.publicKey.rawRepresentation) == "6273818499b5775daa7b46b15a6d158470b1f0a0935ae289a53b1c6818ec516e", "MLDSA87 KeyGen_internal (public key)")
        let e0 = try sk8._deterministicSignature(for: msg, context: [])
        check(e0.count == 4627 && h(e0) == "6f7447eb3221a37e7a4f9c240fe69ae3e1a527d5775f56387ac5ede39de4da20", "MLDSA87 deterministic signature")
        check(h(try sk8._deterministicSignature(for: msg, context: Array("ctx".utf8))) == "b0bd9efddad8af48108c69120d4e93d819c1387b7aa9345c56d6c9e4c88203f4", "MLDSA87 deterministic signature with a context")
        let f8 = try MLDSA87.PrivateKey()
        check(f8.publicKey.isValidSignature(try f8.signature(for: msg, context: Array("ctx".utf8)), for: msg, context: Array("ctx".utf8)), "MLDSA87 random key signs and verifies")
        do { _ = try MLDSA87.PrivateKey(seedRepresentation: xi, publicKey: f8.publicKey); check(false, "MLDSA87 seed / public key mismatch") }
        catch { check(error as? KEM.Errors == .publicKeyMismatchDuringInitialization, "MLDSA87 seed / public key mismatch") }
    } catch { check(false, "ML-DSA threw \(error)") }

    // X-Wing: the draft's first test vector
    do {
        let sk = try XWingMLKEM768X25519.PrivateKey(seedRepresentation: unhex("7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"), publicKey: nil)
        check(h(sk.publicKey.rawRepresentation) == "5121745904643ad9dfacca7869292c19a8a69533b53e60666b7db910b4ad6367" && sk.publicKey.rawRepresentation.count == 1216, "XWing public key (draft vector)")
        let eseed = unhex("3cb1eea988004b93103cfb0aeefd2a686e01fa4a58e8a3639ca8a1e3f9ae57e235b8cc873c23dc62b8d260169afa2f75ab916a58d974918835d25e6a435085b2")
        let r = try sk.publicKey._encapsulate(eseed: eseed)
        check(h(r.encapsulated) == "c0abd149f83f45324ac3a7ddc7606c71f257e5ea86113522834a0ee1bcb34e3e" && r.encapsulated.count == 1120, "XWing ciphertext (draft vector)")
        check(hex(_bytes(r.sharedSecret)) == "d2df0522128f09dd8e2c92b1e905c793d8f57a54c3da25861f10bf4ca613e384", "XWing shared secret (draft vector)")
        check(hex(_bytes(try sk.decapsulate(r.encapsulated))) == "d2df0522128f09dd8e2c92b1e905c793d8f57a54c3da25861f10bf4ca613e384", "XWing decapsulate (draft vector)")
        let fresh = try XWingMLKEM768X25519.PrivateKey.generate()
        let e = try fresh.publicKey.encapsulate()
        check(_bytes(try fresh.decapsulate(e.encapsulated)) == _bytes(e.sharedSecret), "XWing random key: encapsulate / decapsulate")
        let back = try XWingMLKEM768X25519.PrivateKey(integrityCheckedRepresentation: fresh.integrityCheckedRepresentation)
        check(back.publicKey.rawRepresentation == fresh.publicKey.rawRepresentation, "XWing integrityCheckedRepresentation round trip")

        // HPKE with X-Wing (base and PSK modes)
        let suite = HPKE.Ciphersuite.XWingMLKEM768X25519_SHA256_AES_GCM_256
        var sender = try HPKE.Sender(recipientKey: fresh.publicKey, ciphersuite: suite, info: Array("isim".utf8))
        let ct = try sender.seal(Array("post-quantum hello".utf8), authenticating: Array("aad".utf8))
        var recipient = try HPKE.Recipient(privateKey: fresh, ciphersuite: suite, info: Array("isim".utf8), encapsulatedKey: sender.encapsulatedKey)
        check(String(decoding: try recipient.open(ct, authenticating: Array("aad".utf8)), as: UTF8.self) == "post-quantum hello" && sender.encapsulatedKey.count == 1120,
              "HPKE XWingMLKEM768X25519_SHA256_AES_GCM_256 seal / open")
        check(_bytes(try sender.exportSecret(context: [1], outputByteCount: 32)) == _bytes(try recipient.exportSecret(context: [1], outputByteCount: 32)), "HPKE X-Wing exportSecret")
        let psk = SymmetricKey(size: .bits256)
        var ps = try HPKE.Sender(recipientKey: fresh.publicKey, ciphersuite: suite, info: [], presharedKey: psk, presharedKeyIdentifier: [7])
        var pr = try HPKE.Recipient(privateKey: fresh, ciphersuite: suite, info: [], encapsulatedKey: ps.encapsulatedKey, presharedKey: psk, presharedKeyIdentifier: [7])
        check(try pr.open(try ps.seal([1, 2, 3])) == Data([1, 2, 3]), "HPKE X-Wing PSK mode")
        check((try? HPKE.Sender(recipientKey: fresh.publicKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: [])) == nil, "HPKE X-Wing key with another KEM's suite rejected")
    } catch { check(false, "X-Wing threw \(error)") }

    // the Secure Enclave's post-quantum keys (isim's simulated enclave)
    do {
        let kem = try SecureEnclave.MLKEM768.PrivateKey.generate()
        let sent = try kem.publicKey.encapsulate()
        check(_bytes(try kem.decapsulate(sent.encapsulated)) == _bytes(sent.sharedSecret), "SecureEnclave.MLKEM768 decapsulates")
        let reopened = try SecureEnclave.MLKEM768.PrivateKey(dataRepresentation: kem.dataRepresentation)
        check(reopened.publicKey.rawRepresentation == kem.publicKey.rawRepresentation
              && !kem.dataRepresentation.contains(kem.publicKey.rawRepresentation.prefix(16)), "SecureEnclave.MLKEM768 dataRepresentation reopens")
        check((try? SecureEnclave.MLKEM1024.PrivateKey(dataRepresentation: kem.dataRepresentation)) == nil
              && (try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: kem.dataRepresentation)) == nil, "SecureEnclave ML-KEM-768 blob refused by other key types")
        let k4 = try SecureEnclave.MLKEM1024.PrivateKey()
        let s4 = try k4.publicKey.encapsulate()
        check(_bytes(try k4.decapsulate(s4.encapsulated)) == _bytes(s4.sharedSecret), "SecureEnclave.MLKEM1024 decapsulates")
        let signer = try SecureEnclave.MLDSA65.PrivateKey()
        let sig = try signer.signature(for: msg, context: Array("ctx".utf8))
        check(signer.publicKey.isValidSignature(sig, for: msg, context: Array("ctx".utf8)), "SecureEnclave.MLDSA65 signs")
        let s2 = try SecureEnclave.MLDSA65.PrivateKey(dataRepresentation: signer.dataRepresentation)
        check(s2.publicKey.rawRepresentation == signer.publicKey.rawRepresentation
              && (try? SecureEnclave.MLDSA87.PrivateKey(dataRepresentation: signer.dataRepresentation)) == nil, "SecureEnclave.MLDSA65 dataRepresentation reopens (and only as ML-DSA-65)")
        let s8 = try SecureEnclave.MLDSA87.PrivateKey()
        check(s8.publicKey.isValidSignature(try s8.signature(for: msg), for: msg), "SecureEnclave.MLDSA87 signs")
    } catch { check(false, "Secure Enclave post-quantum keys threw \(error)") }

    // the Diffie-Hellman keys' HPKE serialization (HPKEPublicKeySerialization)
    do {
        let p = P256.KeyAgreement.PrivateKey().publicKey
        let ser = try p.hpkeRepresentation(kem: .P256_HKDF_SHA256)
        let back = try P256.KeyAgreement.PublicKey(ser, kem: .P256_HKDF_SHA256)
        check(ser.count == 65 && back.rawRepresentation == p.rawRepresentation
              && (try? p.hpkeRepresentation(kem: .XWingMLKEM768X25519)) == nil, "P256 hpkeRepresentation(kem:) / init(_:kem:)")
    } catch { check(false, "HPKE serialization threw \(error)") }

    if #available(iOS 27.0, *) {
        do {
            let once = try MLKEM768.OneTimePrivateKey.generate()
            let e = try once.publicKey.encapsulate()
            check(_bytes(try once.decapsulate(e.encapsulated)) == _bytes(e.sharedSecret) && (try? once.decapsulate(e.encapsulated)) == nil,
                  "MLKEM768.OneTimePrivateKey decapsulates once")
            let x = try XWingMLKEM768X25519.OneTimePrivateKey()
            let ex = try x.publicKey.encapsulate()
            check(_bytes(try x.decapsulate(ex.encapsulated)) == _bytes(ex.sharedSecret) && (try? x.decapsulate(ex.encapsulated)) == nil,
                  "XWingMLKEM768X25519.OneTimePrivateKey decapsulates once")
            let k4 = try MLKEM1024.OneTimePrivateKey()
            let e4 = try k4.publicKey.encapsulate()
            check(_bytes(try k4.decapsulate(e4.encapsulated)) == _bytes(e4.sharedSecret), "MLKEM1024.OneTimePrivateKey")
        } catch { check(false, "one-time keys threw \(error)") }
    } else {
        print("SKIP  one-time KEM keys (iOS 27)")
    }
}

func _bytes<D: ContiguousBytes>(_ d: D) -> [UInt8] { d.withUnsafeBytes { Array($0) } }
