#pragma once
/* isim SDK (self-authored, Apple's declarations): a file's extended attributes as an XAT blob. */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

APPLE_ARCHIVE_API AAEntryXATBlob _Nullable AAEntryXATBlobCreate(void);
APPLE_ARCHIVE_API AAEntryXATBlob _Nullable AAEntryXATBlobCreateWithEncodedData(const uint8_t *data, size_t data_size);
APPLE_ARCHIVE_API AAEntryXATBlob _Nullable AAEntryXATBlobCreateWithPath(const char *dir, const char *path, AAFlagSet flags);
APPLE_ARCHIVE_API int AAEntryXATBlobApplyToPath(AAEntryXATBlob xat, const char *dir, const char *path, AAFlagSet flags);
APPLE_ARCHIVE_API void AAEntryXATBlobDestroy(AAEntryXATBlob _Nullable xat);
APPLE_ARCHIVE_API int AAEntryXATBlobClear(AAEntryXATBlob xat);
APPLE_ARCHIVE_API uint32_t AAEntryXATBlobGetEntryCount(AAEntryXATBlob xat);
/* entry i's key and data (lengths in *key_length / *data_size; copied when the capacities allow) */
APPLE_ARCHIVE_API int AAEntryXATBlobGetEntry(AAEntryXATBlob xat, uint32_t i, size_t key_capacity, char *_Nullable key,
                                             size_t *_Nullable key_length, size_t data_capacity, uint8_t *_Nullable data,
                                             size_t *_Nullable data_size);
APPLE_ARCHIVE_API int AAEntryXATBlobSetEntry(AAEntryXATBlob xat, uint32_t i, const char *key, const uint8_t *data, size_t data_size);
APPLE_ARCHIVE_API int AAEntryXATBlobAppendEntry(AAEntryXATBlob xat, const char *key, const uint8_t *data, size_t data_size);
APPLE_ARCHIVE_API int AAEntryXATBlobRemoveEntry(AAEntryXATBlob xat, uint32_t i);
APPLE_ARCHIVE_API size_t AAEntryXATBlobGetEncodedSize(AAEntryXATBlob xat);
APPLE_ARCHIVE_API const uint8_t *_Nullable AAEntryXATBlobGetEncodedData(AAEntryXATBlob xat);

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
