#pragma once
/* isim SDK (self-authored, Apple's declarations): archive streams — a sequence of entries (a header, then its blobs).
   Encoding writes them to a byte stream; decoding reads them; extraction makes files in a directory; conversion
   changes their fields; custom streams call back. */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

APPLE_ARCHIVE_API AAArchiveStream _Nullable AAEncodeArchiveOutputStreamOpen(AAByteStream stream, void *_Nullable msg_data,
                                                                            AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAArchiveStream _Nullable AADecodeArchiveInputStreamOpen(AAByteStream stream, void *_Nullable msg_data,
                                                                           AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAArchiveStream _Nullable AAExtractArchiveOutputStreamOpen(const char *dir, void *_Nullable msg_data,
                                                                             AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags, int n_threads);
/* entries written to it go on to `stream` with the keys of insert_key_set added (from the file system: no) and those
   of remove_key_set removed */
APPLE_ARCHIVE_API AAArchiveStream _Nullable AAConvertArchiveOutputStreamOpen(AAArchiveStream stream, AAFieldKeySet _Nullable insert_key_set,
                                                                             AAFieldKeySet _Nullable remove_key_set, void *_Nullable msg_data,
                                                                             AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags, int n_threads);

typedef int (*AAArchiveStreamCloseProc)(void *_Nullable arg);
typedef int (*AAArchiveStreamWriteHeaderProc)(void *_Nullable arg, AAHeader hdr);
typedef int (*AAArchiveStreamWriteBlobProc)(void *_Nullable arg, AAFieldKey key, const void *buf, size_t nbyte);
typedef int (*AAArchiveStreamReadHeaderProc)(void *_Nullable arg, AAHeader _Nullable *_Nonnull hdr);
typedef int (*AAArchiveStreamReadBlobProc)(void *_Nullable arg, AAFieldKey key, void *buf, size_t nbyte);
typedef void (*AAArchiveStreamCancelProc)(void *_Nullable arg);
APPLE_ARCHIVE_API AAArchiveStream _Nullable AACustomArchiveStreamOpen(void);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetData(AAArchiveStream s, void *_Nullable data);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetCloseProc(AAArchiveStream s, AAArchiveStreamCloseProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetWriteHeaderProc(AAArchiveStream s, AAArchiveStreamWriteHeaderProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetWriteBlobProc(AAArchiveStream s, AAArchiveStreamWriteBlobProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetReadHeaderProc(AAArchiveStream s, AAArchiveStreamReadHeaderProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetReadBlobProc(AAArchiveStream s, AAArchiveStreamReadBlobProc _Nullable proc);
APPLE_ARCHIVE_API void AACustomArchiveStreamSetCancelProc(AAArchiveStream s, AAArchiveStreamCancelProc _Nullable proc);

/* 0, or -1 */
APPLE_ARCHIVE_API int AAArchiveStreamWriteHeader(AAArchiveStream s, AAHeader header);
APPLE_ARCHIVE_API int AAArchiveStreamWriteBlob(AAArchiveStream s, AAFieldKey key, const void *buf, size_t nbyte);
/* 1 and the next entry's header (owned by the stream until the next call), 0 at the end, or -1 */
APPLE_ARCHIVE_API int AAArchiveStreamReadHeader(AAArchiveStream s, AAHeader _Nullable *_Nonnull header);
APPLE_ARCHIVE_API int AAArchiveStreamReadBlob(AAArchiveStream s, AAFieldKey key, void *buf, size_t nbyte);
APPLE_ARCHIVE_API void AAArchiveStreamCancel(AAArchiveStream s);
APPLE_ARCHIVE_API int AAArchiveStreamClose(AAArchiveStream _Nullable s);

/* writes an entry (header with key_set's fields, then its data) for each path of path_list under dir */
APPLE_ARCHIVE_API int AAArchiveStreamWritePathList(AAArchiveStream s, AAPathList path_list, AAFieldKeySet key_set, const char *dir,
                                                   void *_Nullable msg_data, AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags,
                                                   int n_threads);
/* copies every entry of istream to ostream: the number of entries, or -1 */
APPLE_ARCHIVE_API ssize_t AAArchiveStreamProcess(AAArchiveStream istream, AAArchiveStream ostream, void *_Nullable msg_data,
                                                 AAEntryMessageProc _Nullable msg_proc, AAFlagSet flags, int n_threads);

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
