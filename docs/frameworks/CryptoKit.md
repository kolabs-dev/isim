# CryptoKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 94.5% of Apple's iOS API (699 of 740, exact) · **Rows:** 11: 9 ✅ 2 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [CryptoKit](https://developer.apple.com/documentation/cryptokit) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Adapted:** Swift, with AES, ChaChaPoly and elliptic curves through the host's `libcrypto`. SHA-3 (Keccak), ML-KEM, ML-DSA and X-Wing are implemented in isim's Swift (iOS 26), so they need no newer host library. The Secure Enclave is simulated with a key kept in the device data.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| CryptoKit (SHA-2, HMAC, AES-GCM, ChaChaPoly, P256, Curve25519) | ✅ | ≤17 | also P384/P521, `Insecure.MD5/SHA1`, HKDF, `SharedSecret` HKDF/X9.63 KDFs, ECDSA DER, public keys raw/X9.63/compressed/DER/PEM. AES/ChaCha/EC on the host's OpenSSL `libcrypto.so.3`. Byte inputs are `ContiguousBytes` (isim's Foundation has no `DataProtocol`). Known-answer tests from the RFCs/NIST |
| CryptoKit: HPKE (RFC 9180, all modes; P-256/384/521 and X25519 KEMs; AES-GCM, ChaChaPoly, export-only), `AES.KeyWrap`, compact representations, private-key PKCS#8 DER/PEM (reads SEC1 too) | ✅ | ≤17 | HPKE opens messages sealed by OpenSSL's independent implementation; RFC 3394 vector. Tested: SecurityTest |
| CryptoKit: Secure Enclave (`SecureEnclave.P256.Signing` / `.KeyAgreement`) | ✅ | ≤17 | adapted, simulated: `isAvailable` is true (`ISIM_SECURE_ENCLAVE=0`: false, like the Simulator); P-256 keys whose private part never leaves isim's store: `dataRepresentation` is the key sealed (AES-GCM) with this device data's key, so it only opens on the same device data and tampering is detected; `accessControl` with `.userPresence` / `.biometry*` / `.devicePasscode` asks for Face ID / Touch ID / the passcode on each use, or not when an `authenticationContext` already authenticated. Not hardware-backed: the device key is a file in the device data. Tested: SecurityTest, HelloAttest |
| CryptoKit: SHA-3 (`SHA3_256`, `SHA3_384`, `SHA3_512` and their digests) | ✅ | 26.0 | adapted: Keccak-f[1600] (FIPS 202) in Swift; works with `HMAC` and `HKDF` like the SHA-2 functions. Tested: SecurityTest (FIPS 202 / NIST answers, streaming 10⁶ × "a", HMAC-SHA3-256), HelloSecurity |
| CryptoKit: ML-KEM (`MLKEM768`, `MLKEM1024`), the `KEM`, `KEMPublicKey`, `KEMPrivateKey` protocols, `KEM.EncapsulationResult`, `KEM.Errors` | ✅ | 26.0 | adapted: FIPS 203 in Swift. `seedRepresentation` is the 64-byte seed d ‖ z; `integrityCheckedRepresentation` is the seed followed by SHA3-256 of the public key (proposed: Apple does not document its layout); public keys get FIPS 203's modulus check; decapsulation uses implicit rejection. Tested: SecurityTest (keys, ciphertexts and shared secrets equal to kyber-py's, an independent implementation), HelloSecurity |
| CryptoKit: ML-DSA (`MLDSA65`, `MLDSA87`) | ✅ | 26.0 | adapted: FIPS 204 in Swift, hedged signing (fresh randomness per signature) with FIPS 204's context string (up to 255 bytes). `seedRepresentation` is the 32-byte seed ξ; `integrityCheckedRepresentation` is the seed followed by SHA3-256 of the public key (proposed). Tested: SecurityTest (public keys and deterministic signatures equal to dilithium-py's; wrong message, context or signature rejected), HelloSecurity |
| CryptoKit: X-Wing (`XWingMLKEM768X25519`), HPKE with it (`HPKE.KEM.XWingMLKEM768X25519`, `XWingMLKEM768X25519_SHA256_AES_GCM_256`), `HPKEPublicKeySerialization`, `HPKEKEMPublicKey`, `HPKEKEMPrivateKey`, `HPKEKEMPrivateKeyGeneration` | ✅ | 26.0 | adapted: draft-connolly-cfrg-xwing-kem-06 over isim's ML-KEM-768 and X25519; HPKE KEM id 0x647a, its shared secret used directly (base and PSK modes). The Diffie-Hellman keys also get `hpkeRepresentation(kem:)` / `init(_:kem:)` and `HPKEEphemeralPrivateKey`. Tested: SecurityTest (the draft's first test vector; HPKE seal / open / export), HelloSecurity |
| CryptoKit: Secure Enclave post-quantum keys (`SecureEnclave.MLKEM768`, `.MLKEM1024`, `.MLDSA65`, `.MLDSA87`) | ✅ | 26.0 | adapted, simulated like `SecureEnclave.P256`: `dataRepresentation` is the key's seed sealed with this device data's key and tagged with the key's type (it does not reopen as another type), access control enforced on each use. Tested: SecurityTest |
| CryptoKit: one-time KEM keys (`KEMOneTimePrivateKey`; `MLKEM768`, `MLKEM1024`, `XWingMLKEM768X25519` `.OneTimePrivateKey`) | ✅ | 27.0 | adapted: a key that decapsulates once; a second `decapsulate` throws `CryptoKitError.invalidParameter` (proposed). Tested: SecurityTest under iOS 27 |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CryptoKitASN1Error`, `DiffieHellmanKeyAgreement` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `CorecryptoCurveType` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
41 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var bytes: RawSpan`](https://developer.apple.com/documentation/cryptokit/aes/gcm/nonce/bytes)
- [`init(copying: RawSpan) throws`](https://developer.apple.com/documentation/cryptokit/aes/gcm/nonce/init(copying:))
- [`static func open(inPlace: inout MutableRawSpan, using: SymmetricKey, nonce: AES.GCM.Nonce, authenticating: RawSpan?, tag: RawSpan) throws`](https://developer.apple.com/documentation/cryptokit/aes/gcm/open(inplace:using:nonce:authenticating:tag:))
- [`static func seal(inPlace: inout MutableRawSpan, using: SymmetricKey, nonce: AES.GCM.Nonce, authenticating: RawSpan?, tag: inout OutputRawSpan) throws`](https://developer.apple.com/documentation/cryptokit/aes/gcm/seal(inplace:using:nonce:authenticating:tag:))
- [`var bytes: RawSpan`](https://developer.apple.com/documentation/cryptokit/chachapoly/nonce/bytes)
- [`init(copying: RawSpan) throws`](https://developer.apple.com/documentation/cryptokit/chachapoly/nonce/init(copying:))
- [`static func open(inPlace: inout MutableRawSpan, using: SymmetricKey, nonce: ChaChaPoly.Nonce, authenticating: RawSpan?, tag: RawSpan) throws`](https://developer.apple.com/documentation/cryptokit/chachapoly/open(inplace:using:nonce:authenticating:tag:))
- [`static func seal(inPlace: inout MutableRawSpan, using: SymmetricKey, nonce: ChaChaPoly.Nonce, authenticating: RawSpan?, tag: inout OutputRawSpan) throws`](https://developer.apple.com/documentation/cryptokit/chachapoly/seal(inplace:using:nonce:authenticating:tag:))
- [`CorecryptoCurveType`](https://developer.apple.com/documentation/cryptokit/corecryptocurvetype)
- [`CryptoKitASN1Error`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error)
- [`case invalidASN1IntegerEncoding`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/invalidasn1integerencoding)
- [`case invalidASN1Object`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/invalidasn1object)
- [`case invalidFieldIdentifier`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/invalidfieldidentifier)
- [`case invalidObjectIdentifier`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/invalidobjectidentifier)
- [`case invalidPEMDocument`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/invalidpemdocument)
- [`case truncatedASN1Field`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/truncatedasn1field)
- [`case unexpectedFieldType`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/unexpectedfieldtype)
- [`case unsupportedFieldLength`](https://developer.apple.com/documentation/cryptokit/cryptokitasn1error/unsupportedfieldlength)
- [`CryptoKitMetaError`](https://developer.apple.com/documentation/cryptokit/cryptokitmetaerror)
- [`DiffieHellmanKeyAgreement`](https://developer.apple.com/documentation/cryptokit/diffiehellmankeyagreement)
- [`PublicKey`](https://developer.apple.com/documentation/cryptokit/diffiehellmankeyagreement/publickey-swift.associatedtype)
- [`var publicKey: Self.PublicKey`](https://developer.apple.com/documentation/cryptokit/diffiehellmankeyagreement/publickey-swift.property)
- [`func sharedSecretFromKeyAgreement(with: Self.PublicKey) throws -> SharedSecret`](https://developer.apple.com/documentation/cryptokit/diffiehellmankeyagreement/sharedsecretfromkeyagreement(with:))
- [`static func hash(bytes: RawSpan) -> Self.Digest`](https://developer.apple.com/documentation/cryptokit/hashfunction/hash(bytes:))
- [`func update(bytes: RawSpan)`](https://developer.apple.com/documentation/cryptokit/hashfunction/update(bytes:))
- [`static func deriveKey(inputKeyMaterial: SymmetricKey, salt: RawSpan?, info: RawSpan?, output: inout OutputRawSpan)`](https://developer.apple.com/documentation/cryptokit/hkdf/derivekey(inputkeymaterial:salt:info:output:))
- [`static func deriveKey<Salt>(inputKeyMaterial: SymmetricKey, salt: Salt, outputByteCount: Int) -> SymmetricKey`](https://developer.apple.com/documentation/cryptokit/hkdf/derivekey(inputkeymaterial:salt:outputbytecount:))
- [`static func expand(pseudoRandomKey: RawSpan, info: RawSpan?, into: inout OutputRawSpan)`](https://developer.apple.com/documentation/cryptokit/hkdf/expand(pseudorandomkey:info:into:))
- [`func update(bytes: RawSpan)`](https://developer.apple.com/documentation/cryptokit/hmac/update(bytes:))
- [`HPKE.DHKEM`](https://developer.apple.com/documentation/cryptokit/hpke/dhkem)
- [`SHA2_256`](https://developer.apple.com/documentation/cryptokit/sha2_256)
- [`SHA2_384`](https://developer.apple.com/documentation/cryptokit/sha2_384)
- [`SHA2_512`](https://developer.apple.com/documentation/cryptokit/sha2_512)
- [`var bytes: RawSpan`](https://developer.apple.com/documentation/cryptokit/symmetrickey/bytes)
- [`var bytes: RawSpan`](https://developer.apple.com/documentation/cryptokit/symmetrickey/bytes)
- [`init(copying: RawSpan)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(copying:))
- [`init(copying: RawSpan)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(copying:))
- [`init(copyingWithZeroing: inout MutableRawSpan)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(copyingwithzeroing:))
- [`init(copyingWithZeroing: inout MutableRawSpan)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(copyingwithzeroing:))
- [`init<E>(size: SymmetricKeySize, initializingWith: (inout OutputRawSpan) throws(E) -> Void) throws(E)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(size:initializingwith:))
- [`init<E>(size: SymmetricKeySize, initializingWith: (inout OutputRawSpan) throws(E) -> Void) throws(E)`](https://developer.apple.com/documentation/cryptokit/symmetrickey/init(size:initializingwith:))

</details>
<!-- /generated:missing -->
