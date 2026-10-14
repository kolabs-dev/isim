#pragma once
/* isim libcompression (/usr/lib/libcompression.dylib): the buffer API. Adapted: COMPRESSION_ZLIB (raw DEFLATE, like
   Apple's) through the host's zlib; the other algorithms are not available (the calls return 0). */
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
typedef enum {
    COMPRESSION_LZ4 = 0x100, COMPRESSION_LZ4_RAW = 0x101, COMPRESSION_ZLIB = 0x205, COMPRESSION_LZMA = 0x306,
    COMPRESSION_LZFSE = 0x801, COMPRESSION_BROTLI = 0xB02, COMPRESSION_LZBITMAP = 0x702,
} compression_algorithm;
size_t compression_encode_scratch_buffer_size(compression_algorithm algorithm);
size_t compression_encode_buffer(uint8_t *dst_buffer, size_t dst_size, const uint8_t *src_buffer, size_t src_size,
                                 void *scratch_buffer, compression_algorithm algorithm);
size_t compression_decode_scratch_buffer_size(compression_algorithm algorithm);
size_t compression_decode_buffer(uint8_t *dst_buffer, size_t dst_size, const uint8_t *src_buffer, size_t src_size,
                                 void *scratch_buffer, compression_algorithm algorithm);
__END_DECLS
