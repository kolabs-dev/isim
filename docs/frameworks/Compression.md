# Compression

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 92.3% of Apple's iOS API (72 of 78, exact) · **Rows:** 11: 10 ✅ 1 ❌ · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Foundation & CoreFoundation](../COVERAGE.md#foundation) · **Apple:** [Compression](https://developer.apple.com/documentation/compression) · **Issues:** [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

## How isim implements it

- **Approach:** adapted. libcompression (`/usr/lib/libcompression.dylib`) is part of isim's runtime
  (`isim/runtime/host_compression.inc`), and it writes and reads Apple's formats:
  - ZLIB: raw DEFLATE (RFC 1951), through the host's zlib.
  - LZMA: the xz format, through the host's liblzma.
  - LZ4: Apple's frames (`bv41` compressed blocks, `bv4-` stored blocks, `bv4$` end), with the LZ4 blocks from the
    host's liblz4; LZ4_RAW is one raw block.
  - LZFSE: Apple's reference encoder and decoder (lzfse-1.0, BSD-3-Clause), fetched into `third_party/lzfse` by
    `build.py fetch` and built into the runtime (`host_lzfse.c`).
  - Brotli: through the host's libbrotlienc / libbrotlidec.
  - A host library that is missing makes its algorithm fail the way Apple's calls fail. Every Linux distribution ships
    them (liblzma5, liblz4-1, libbrotli1).
- **Swift:** the `Compression` module re-exports `compression.h` and adds the filters (`isim/swift/overlays/Compression`).
- **Objective-C / C interface:** `compression.h` (`isim/sdk-src/usr/include`, module map `Compression`); NSData's
  compression in `Foundation/NSData.h`.
- **Versus Apple's Simulator:**
  - Data compressed by isim decompresses on Apple's platforms, and the other way round.
  - The compressed bytes are not always the same as Apple's (other encoder levels and block sizes).
  - LZ4 and LZFSE streams are buffered: an encoder gives its output at `COMPRESSION_STREAM_FINALIZE`, an LZFSE decoder
    when the end-of-stream block has arrived.
  - LZBITMAP (an undocumented Apple format) is not available.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `compression_encode_buffer`, `compression_decode_buffer`, `compression_encode_scratch_buffer_size` / `decode_scratch_buffer_size` | ✅ | ≤17 | adapted: every algorithm but LZBITMAP; a destination too small to decode into gets what fits, as on Apple's. Tested (CompressionTest: test_compression_c) |
| `compression_stream`, `compression_stream_init`, `compression_stream_process`, `compression_stream_destroy`, `COMPRESSION_STREAM_ENCODE` / `DECODE`, `COMPRESSION_STREAM_FINALIZE`, `COMPRESSION_STATUS_*` | ✅ | ≤17 | adapted: the zlib, liblzma and Brotli streams; LZ4 decodes block by block; LZ4 encoders and LZFSE are buffered (see above). Tested (test_compression_c, small pieces into small buffers) |
| `COMPRESSION_LZFSE` | ✅ | ≤17 | adapted: Apple's reference LZFSE. Tested (test_compression_c, test_compression_swift; HelloSystemObjC: test_system_objc) |
| `COMPRESSION_LZ4`, `COMPRESSION_LZ4_RAW` | ✅ | ≤17 | adapted: Apple's frames over the host's liblz4. Tested (test_compression_c) |
| `COMPRESSION_LZMA` | ✅ | ≤17 | adapted: xz, preset 6, through the host's liblzma. Tested (test_compression_c) |
| `COMPRESSION_ZLIB` | ✅ | ≤17 | adapted: raw DEFLATE through the host's zlib (level 5). Tested (test_compression_c: zlib reads it back) |
| `COMPRESSION_BROTLI` | ✅ | ≤17 | adapted: through the host's libbrotli. Tested (test_compression_c) |
| `COMPRESSION_LZBITMAP` | ❌ | ≤17 | stub: Apple's own undocumented format; the calls fail (0, `COMPRESSION_STATUS_ERROR`). Tested (test_compression_c) |
| `Algorithm`, `FilterOperation`, `FilterError` | ✅ | ≤17 | Swift; raw values are the C constants. Tested (SwiftCompressionTest: test_compression_swift) |
| `OutputFilter` (`init(_:using:bufferCapacity:writingTo:)`, `write(_:)`, `finalize()`) | ✅ | ≤17 | adapted, over `compression_stream`: the closure gets each piece of output, then nil. Tested (test_compression_swift) |
| `InputFilter` (`init(_:using:bufferCapacity:readingFrom:)`, `readData(ofLength:)`) | ✅ | ≤17 | adapted, over `compression_stream`. Tested (test_compression_swift) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
6 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`case brotli`](https://developer.apple.com/documentation/compression/algorithm/brotli)
- [`case lzbitmap`](https://developer.apple.com/documentation/compression/algorithm/lzbitmap)
- [`var COMPRESSION_LZMESH: compression_algorithm`](https://developer.apple.com/documentation/compression/compression_lzmesh)
- [`var COMPRESSION_LZMESH: compression_algorithm`](https://developer.apple.com/documentation/compression/compression_lzmesh)
- [`var COMPRESSION_LZRAVEN: compression_algorithm`](https://developer.apple.com/documentation/compression/compression_lzraven)
- [`var COMPRESSION_LZRAVEN: compression_algorithm`](https://developer.apple.com/documentation/compression/compression_lzraven)

</details>
<!-- /generated:missing -->
