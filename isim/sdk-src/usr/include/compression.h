#pragma once
/* isim libcompression (/usr/lib/libcompression.dylib): the buffer and stream APIs, adapted for every algorithm but
   LZBITMAP: ZLIB through the host's zlib, LZMA through liblzma, LZ4 through liblz4 (in Apple's frames), Brotli through
   libbrotli, LZFSE through Apple's reference sources (built into isim). LZBITMAP (and an algorithm whose host library
   is missing) fails: 0 from the buffer calls, COMPRESSION_STATUS_ERROR from compression_stream_init. */
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
typedef enum {
    COMPRESSION_LZ4 = 0x100, COMPRESSION_LZ4_RAW = 0x101, COMPRESSION_ZLIB = 0x205, COMPRESSION_LZMA = 0x306,
    COMPRESSION_LZFSE = 0x801, COMPRESSION_BROTLI = 0xB02, COMPRESSION_LZBITMAP = 0x702,
} compression_algorithm;
size_t compression_encode_scratch_buffer_size(compression_algorithm algorithm);
size_t compression_encode_buffer(uint8_t *__restrict dst_buffer, size_t dst_size, const uint8_t *__restrict src_buffer,
                                 size_t src_size, void *__restrict scratch_buffer, compression_algorithm algorithm);
size_t compression_decode_scratch_buffer_size(compression_algorithm algorithm);
size_t compression_decode_buffer(uint8_t *__restrict dst_buffer, size_t dst_size, const uint8_t *__restrict src_buffer,
                                 size_t src_size, void *__restrict scratch_buffer, compression_algorithm algorithm);

/* streams: LZ4 and LZFSE encoders give their output at COMPRESSION_STREAM_FINALIZE (isim buffers them) */
typedef struct {
    uint8_t *dst_ptr;           /* the next output byte */
    size_t dst_size;            /* the room left at dst_ptr */
    const uint8_t *src_ptr;     /* the next input byte */
    size_t src_size;            /* the input left at src_ptr */
    void *state;                /* private */
} compression_stream;
typedef enum { COMPRESSION_STREAM_ENCODE = 0, COMPRESSION_STREAM_DECODE = 1 } compression_stream_operation;
typedef enum { COMPRESSION_STREAM_FINALIZE = 0x0001 } compression_stream_flags;
typedef enum { COMPRESSION_STATUS_OK = 0, COMPRESSION_STATUS_ERROR = -1, COMPRESSION_STATUS_END = 1 } compression_status;
compression_status compression_stream_init(compression_stream *stream, compression_stream_operation operation,
                                           compression_algorithm algorithm);
compression_status compression_stream_process(compression_stream *stream, int flags);
compression_status compression_stream_destroy(compression_stream *stream);
__END_DECLS
