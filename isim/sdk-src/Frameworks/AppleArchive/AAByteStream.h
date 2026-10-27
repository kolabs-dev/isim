#pragma once
/* isim SDK (self-authored, Apple's declarations): byte streams — files, temporary files, custom callbacks, a shared
   buffer pipe, and AppleArchive's block compression (the "pbz" stream format: blocks compressed with libcompression). */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

APPLE_ARCHIVE_API AAByteStream _Nullable AAFileStreamOpenWithFD(int fd, int automatic_close);
APPLE_ARCHIVE_API AAByteStream _Nullable AAFileStreamOpenWithPath(const char *path, int open_flags, mode_t open_mode);
APPLE_ARCHIVE_API AAByteStream _Nullable AATempFileStreamOpen(void);
APPLE_ARCHIVE_API int AASharedBufferPipeOpen(AAByteStream _Nullable *_Nonnull ostream, AAByteStream _Nullable *_Nonnull istream,
                                             size_t buffer_capacity);

/* streams over callbacks */
typedef int (*AAByteStreamCloseProc)(void *_Nullable arg);
typedef ssize_t (*AAByteStreamReadProc)(void *_Nullable arg, void *buf, size_t nbyte);
typedef ssize_t (*AAByteStreamPReadProc)(void *_Nullable arg, void *buf, size_t nbyte, off_t offset);
typedef ssize_t (*AAByteStreamWriteProc)(void *_Nullable arg, const void *buf, size_t nbyte);
typedef ssize_t (*AAByteStreamPWriteProc)(void *_Nullable arg, const void *buf, size_t nbyte, off_t offset);
typedef off_t (*AAByteStreamSeekProc)(void *_Nullable arg, off_t offset, int whence);
typedef void (*AAByteStreamCancelProc)(void *_Nullable arg);
APPLE_ARCHIVE_API AAByteStream _Nullable AACustomByteStreamOpen(void);
APPLE_ARCHIVE_API void AACustomByteStreamSetData(AAByteStream s, void *_Nullable data);
APPLE_ARCHIVE_API void AACustomByteStreamSetCloseProc(AAByteStream s, AAByteStreamCloseProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetReadProc(AAByteStream s, AAByteStreamReadProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetPReadProc(AAByteStream s, AAByteStreamPReadProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetWriteProc(AAByteStream s, AAByteStreamWriteProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetPWriteProc(AAByteStream s, AAByteStreamPWriteProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetSeekProc(AAByteStream s, AAByteStreamSeekProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomByteStreamSetCancelProc(AAByteStream s, AAByteStreamCancelProc _Nullable proc);

/* compression: writes to `compressed_stream` in blocks of `block_size` bytes (0: 4 MiB); OpenExisting appends to a
   compressed stream it reads the header of; decompression reads one (sequentially, or by offsets) */
APPLE_ARCHIVE_API AAByteStream _Nullable AACompressionOutputStreamOpen(AAByteStream compressed_stream, AACompressionAlgorithm compression_algorithm,
                                                                       size_t block_size, AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAByteStream _Nullable AACompressionOutputStreamOpenExisting(AAByteStream compressed_stream, AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAByteStream _Nullable AADecompressionInputStreamOpen(AAByteStream compressed_stream, AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAByteStream _Nullable AADecompressionRandomAccessInputStreamOpen(AAByteStream compressed_stream, size_t alloc_limit,
                                                                                    AAFlagSet flags, int n_threads);

/* the stream functions: bytes moved, or -1 (an error, a callback missing) */
APPLE_ARCHIVE_API ssize_t AAByteStreamWrite(AAByteStream s, const void *buf, size_t nbyte);
APPLE_ARCHIVE_API ssize_t AAByteStreamPWrite(AAByteStream s, const void *buf, size_t nbyte, off_t offset);
APPLE_ARCHIVE_API ssize_t AAByteStreamRead(AAByteStream s, void *buf, size_t nbyte);
APPLE_ARCHIVE_API ssize_t AAByteStreamPRead(AAByteStream s, void *buf, size_t nbyte, off_t offset);
APPLE_ARCHIVE_API off_t AAByteStreamSeek(AAByteStream s, off_t offset, int whence);
APPLE_ARCHIVE_API void AAByteStreamCancel(AAByteStream s);
/* closes and frees the stream (a compression stream writes its last block); 0, or -1 */
APPLE_ARCHIVE_API int AAByteStreamClose(AAByteStream _Nullable s);
/* copies istream to its end into ostream: the bytes copied, or -1 */
APPLE_ARCHIVE_API off_t AAByteStreamProcess(AAByteStream istream, AAByteStream ostream);

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
