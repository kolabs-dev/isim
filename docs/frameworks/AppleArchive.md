# AppleArchive

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 77.5% of Apple's iOS API (189 of 244, exact) · **Rows:** 10: 8 ✅ 1 🟡 1 ❌ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Foundation & CoreFoundation](../COVERAGE.md#foundation) · **Apple:** [AppleArchive](https://developer.apple.com/documentation/applearchive) · **Issues:** [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

## How isim implements it

- **Approach:** adapted. isim's own C framework (`isim/frameworks/AppleArchive`: `ByteStream.c`, `Header.c`,
  `Archive.c`), with a Swift overlay over it (`isim/swift/overlays/AppleArchive`). The Swift overlay builds on System's
  `FilePath` / `FileDescriptor` and Compression's `Algorithm`.
  - **Archives:** a sequence of entries. Each entry is a header encoded as `AA01` + its size + fields (a 3-character
    key and a type character per field), then its blobs (DAT, XAT, …) in field order.
  - **Compression streams:** AppleArchive's block format (`pbz` + the algorithm, the block size, then each block's sizes
    and bytes), compressed with isim's libcompression. Blocks are stored raw when compression does not shrink them.
  - **Headers from files:** `stat` / `lstat`, `readlink`, CommonCrypto's hashes, zlib's CRC32 and the file's extended
    attributes.
- **Objective-C / C interface:** Apple's C API, headers in `isim/sdk-src/Frameworks/AppleArchive`:
  - `AADefs.h`, `AAByteStream.h`, `AAFieldKeySet.h`, `AAHeader.h`, `AAArchiveStream.h`, `AAPathList.h` and
    `AAEntryXATBlob.h`;
  - tested by AppleArchiveTest (`tests/applearchive/main.m`).
- **Versus Apple's Simulator:**
  - Archives are written and read by isim's own implementation of the format. They are not verified byte for byte
    against archives Apple's `aa` writes.
  - `threadCount` is accepted and the work runs on the calling thread.
  - Extraction makes regular files, directories and symbolic links. FIFOs, devices and sockets are skipped, as an app's
    container allows.
  - ACL blobs are not applied.
  - Apple Encrypted Archive (`ArchiveEncryptionContext`, `AEA*`) is not in isim: #670.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ArchiveByteStream` file streams: `fileStream(path:mode:options:permissions:)`, `fileStream(fd:automaticClose:)`, `temporaryFileStream()` and their `with…` forms; `read` / `write` (also at an offset), `seek`, `cancel`, `close`; `process(readingFrom:writingTo:)` | ✅ | 14.0 | adapted (over isim's libSystem). Tested (SwiftAppleArchiveTest, AppleArchiveTest: test_applearchive) |
| `ArchiveByteStream` compression: `compressionStream(using:writingTo:blockSize:flags:threadCount:)`, `compressionStream(appendingTo:)`, `decompressionStream(readingFrom:)`, `randomAccessDecompressionStream(readingFrom:allocationLimit:)` and their `with…` forms; `ArchiveCompression` (none, lz4, zlib, lzma, lzfse, lzbitmap, lzraven, `init(algo:)`) | 🟡 | 14.0 | adapted. AppleArchive's block format over libcompression: LZ4, zlib, LZMA and LZFSE. LZBITMAP writes its blocks uncompressed (isim's libcompression has no LZBITMAP encoder), and LZRAVEN streams do not open. Random access decompresses only the blocks a read needs. Tested: every algorithm from C, LZFSE and zlib (random access) from Swift |
| `ArchiveByteStream.customStream(instance:)`, `withStream(wrapping:_:)`, `ArchiveByteStreamProtocol`; `sharedBufferPipe(capacity:)` | ✅ | 14.0 | adapted: the C stream calls the instance; the pipe is a bounded buffer between a writer and a reader thread. Tested (an in-memory stream, a pipe across threads) |
| `ArchiveStream`: `encodeStream(writingTo:)`, `decodeStream(readingFrom:)`, `extractStream(extractingTo:)`, `convertStream(writingTo:insertKeySet:removeKeySet:)`, their `with…` forms, `process(readingFrom:writingTo:)`, `writeDirectoryContents(archiveFrom:path:keySet:selectUsing:flags:threadCount:)`, `readHeader()`, `readBlob(key:into:)`, `writeHeader(_:)`, `writeBlob(key:from:)`, `customStream(instance:)`, `ArchiveStreamProtocol` | ✅ | 14.0 | adapted. Decoding skips the blobs an entry's reader does not read. Extraction refuses paths that leave its directory (`..`, absolute) and sets the mode and modification time, of directories after their contents. Conversion removes fields and inserts SIZ and the hashes (CKS, SH1, SH2, SH3, SH5) computed from DAT. Tested (a directory archived, compressed, decoded, extracted and compared; conversion; a `../` path refused) |
| `ArchiveHeader`: `init()`, `init(keySet:directory:path:flags:)`, `init(withAAEncodedData:)`, `init(copying:)`, `field(forKey:)`, `append(_:)`, `remove(at:)`, `removeAll()`, `withAAEncodedData(_:)`, `entryType`, `entryPath`, the fields as a collection; `Field`, `FieldKey`, `FieldType`, `FieldKeySet` (`defaultForArchive`, `defaultForManifest`), `EntryType` | ✅ | 14.0 | adapted. Fields from a file: TYP, PAT, LNK, DEV, UID, GID, MOD, FLG, MTM, BTM, CTM, INO, NLK, SIZ, DAT, CKS / SH1 / SH2 / SH3 / SH5 and XAT. Tested |
| Entry filters: `ArchiveHeader.EntryFilter`, `EntryMessage`, `EntryMessageStatus`, `EntryFilterData` | ✅ | 14.0 | adapted. The filter gets the entry's header (encode, decode, convert, process and extract-begin messages) or its XAT blob, and skips entries or cancels. `EntryAttributes` is declared but never passed. Tested (a search exclusion, encode-writing headers, extract-begin counts) |
| `ArchiveHeader.EntryXATBlob` (`init(directory:path:flags:)`, `init(withAAEncodedData:)`, `apply(directory:path:flags:)`, `ExtendedAttribute`, `append`, `remove(at:)`, `removeAll`, `withAAEncodedData`) | ✅ | 14.0 | adapted. Each entry is a uint32 size + a NUL-terminated name + the value. Extended attributes come through isim's libSystem. Tested (encoding round trip) |
| `ArchiveFlags`, `ArchiveHash`, `ArchiveError`, `APPLE_ARCHIVE_API_VERSION` | ✅ | 14.0 | Tested (values) |
| C API: `AAByteStream*`, `AAFileStream*`, `AATempFileStreamOpen`, `AASharedBufferPipeOpen`, `AACustomByteStream*`, `AACompressionOutputStreamOpen[Existing]`, `AADecompression[RandomAccess]InputStreamOpen`, `AAFieldKeySet*`, `AAHeader*`, `AAEntryXATBlob*`, `AA{Encode,Decode,Extract,Convert}ArchiveOutputStreamOpen`, `AACustomArchiveStream*`, `AAArchiveStream*`, `AAPathList*` | ✅ | 14.0 | adapted. Tested (AppleArchiveTest: key sets, headers, XAT blobs, compression, path lists, encode / decode / convert / extract, custom streams) |
| `ArchiveEncryptionContext`, `ArchiveByteStream.close(updatingContext:)`, encryption and decryption streams (Apple Encrypted Archive) | ❌ | 15.0 | not in isim: #670 |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
55 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AEAContextTraits`](https://developer.apple.com/documentation/applearchive/aeacontexttraits)
- [`static func aaDestroy(AEAContextTraits.AAType?)`](https://developer.apple.com/documentation/applearchive/aeacontexttraits/aadestroy(_:))
- [`AEAContextTraits.AAType`](https://developer.apple.com/documentation/applearchive/aeacontexttraits/aatype)
- [`static func decryptionStream(readingFrom: ArchiveByteStream, encryptionContext: ArchiveEncryptionContext, flags: ArchiveFlags, threadCount: Int) -> ArchiveByteStream?`](https://developer.apple.com/documentation/applearchive/archivebytestream/decryptionstream(readingfrom:encryptioncontext:flags:threadcount:))
- [`static func encryptionStream(appendingTo: ArchiveByteStream, encryptionContext: ArchiveEncryptionContext, flags: ArchiveFlags, threadCount: Int) -> ArchiveByteStream?`](https://developer.apple.com/documentation/applearchive/archivebytestream/encryptionstream(appendingto:encryptioncontext:flags:threadcount:))
- [`static func encryptionStream(writingTo: ArchiveByteStream, encryptionContext: ArchiveEncryptionContext, flags: ArchiveFlags, threadCount: Int) -> ArchiveByteStream?`](https://developer.apple.com/documentation/applearchive/archivebytestream/encryptionstream(writingto:encryptioncontext:flags:threadcount:))
- [`static func randomAccessDecryptionStream(readingFrom: ArchiveByteStream, encryptionContext: ArchiveEncryptionContext, allocationLimit: Int, flags: ArchiveFlags, threadCount: Int) -> ArchiveByteStream?`](https://developer.apple.com/documentation/applearchive/archivebytestream/randomaccessdecryptionstream(readingfrom:encryptioncontext:allocationlimit:flags:threadcount:))
- [`ArchiveEncryptionContext`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext)
- [`var archiveIdentifier: Data?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/archiveidentifier)
- [`var authData: Data?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/authdata)
- [`var checksumMode: ArchiveEncryptionContext.ChecksumMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/checksummode-swift.property)
- [`ArchiveEncryptionContext.ChecksumMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/checksummode-swift.struct)
- [`static let murmurhash64: ArchiveEncryptionContext.ChecksumMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/checksummode-swift.struct/murmurhash64)
- [`static let none: ArchiveEncryptionContext.ChecksumMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/checksummode-swift.struct/none)
- [`static let sha256: ArchiveEncryptionContext.ChecksumMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/checksummode-swift.struct/sha256)
- [`var compressionAlgorithm: ArchiveCompression`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/compressionalgorithm)
- [`var compressionBlockSize: Int`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/compressionblocksize)
- [`var containerSize: Int`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/containersize)
- [`func decryptAttributes() -> Bool`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/decryptattributes())
- [`var encryptionMode: ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.property)
- [`ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.struct)
- [`static let ecdhe_p256: ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.struct/ecdhe_p256)
- [`static let none: ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.struct/none)
- [`static let scrypt: ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.struct/scrypt)
- [`static let symmetric: ArchiveEncryptionContext.EncryptionMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/encryptionmode-swift.struct/symmetric)
- [`func generatePassword() throws -> String`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/generatepassword())
- [`func generateSymmetricKey() throws -> SymmetricKey`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/generatesymmetrickey())
- [`init?(from: ArchiveByteStream)`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/init(from:))
- [`init(profile: ArchiveEncryptionContext.Profile, compressionAlgorithm: ArchiveCompression, compressionBlockSize: Int)`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/init(profile:compressionalgorithm:compressionblocksize:))
- [`var mainKey: SymmetricKey?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/mainkey)
- [`var paddingSize: Int`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/paddingsize)
- [`var password: String?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/password)
- [`var profile: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.property)
- [`ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct)
- [`static let hkdf_sha256_aesctr_hmac__ecdhe_p256__ecdsa_p256: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_aesctr_hmac__ecdhe_p256__ecdsa_p256)
- [`static let hkdf_sha256_aesctr_hmac__ecdhe_p256__none: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_aesctr_hmac__ecdhe_p256__none)
- [`static let hkdf_sha256_aesctr_hmac__scrypt__none: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_aesctr_hmac__scrypt__none)
- [`static let hkdf_sha256_aesctr_hmac__symmetric__ecdsa_p256: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_aesctr_hmac__symmetric__ecdsa_p256)
- [`static let hkdf_sha256_aesctr_hmac__symmetric__none: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_aesctr_hmac__symmetric__none)
- [`static let hkdf_sha256_hmac__none__ecdsa_p256: ArchiveEncryptionContext.Profile`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/profile-swift.struct/hkdf_sha256_hmac__none__ecdsa_p256)
- [`var rawSize: Int`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/rawsize)
- [`func setPassword(String) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setpassword(_:))
- [`func setRecipientPrivateKey(P256.KeyAgreement.PrivateKey) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setrecipientprivatekey(_:))
- [`func setRecipientPublicKey(P256.KeyAgreement.PublicKey) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setrecipientpublickey(_:))
- [`func setSigningPrivateKey(P256.Signing.PrivateKey) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setsigningprivatekey(_:))
- [`func setSigningPublicKey(P256.Signing.PublicKey) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setsigningpublickey(_:))
- [`func setSymmetricKey(SymmetricKey) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/setsymmetrickey(_:))
- [`static func sign(encryptedStream: ArchiveByteStream, encryptionContext: ArchiveEncryptionContext) throws`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/sign(encryptedstream:encryptioncontext:))
- [`var signatureEncryptionKey: SymmetricKey?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signatureencryptionkey)
- [`var signatureMode: ArchiveEncryptionContext.SignatureMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signaturemode-swift.property)
- [`ArchiveEncryptionContext.SignatureMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signaturemode-swift.struct)
- [`static let ecdsa_p256: ArchiveEncryptionContext.SignatureMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signaturemode-swift.struct/ecdsa_p256)
- [`static let none: ArchiveEncryptionContext.SignatureMode`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signaturemode-swift.struct/none)
- [`var rawValue: UInt32`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/signaturemode-swift.struct/rawvalue)
- [`var symmetricKey: SymmetricKey?`](https://developer.apple.com/documentation/applearchive/archiveencryptioncontext/symmetrickey)

</details>
<!-- /generated:missing -->
