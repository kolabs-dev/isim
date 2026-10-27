#pragma once
/* isim SDK (self-authored, Apple's declarations): archive entry headers — typed fields (flag, unsigned integer,
   string, hash, timespec, blob) in AppleArchive's encoding ("AA01", the header size, then key/type/value fields). */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

APPLE_ARCHIVE_API AAHeader _Nullable AAHeaderCreate(void);
APPLE_ARCHIVE_API AAHeader _Nullable AAHeaderCreateWithEncodedData(size_t data_size, const uint8_t *data);
/* a header for the file system object `dir`/`path`, with the fields of key_set (TYP, PAT, LNK, DEV, UID, GID, MOD,
   FLG, MTM, BTM, CTM, DAT / SIZ for a regular file's data, SH1 / SH2 / SH3 / SH5 / CKS hashes, XAT, INO, NLK) */
APPLE_ARCHIVE_API AAHeader _Nullable AAHeaderCreateWithPath(AAFieldKeySet key_set, const char *dir, const char *path, AAFlagSet flags);
APPLE_ARCHIVE_API AAHeader _Nullable AAHeaderClone(AAHeader header);
APPLE_ARCHIVE_API void AAHeaderDestroy(AAHeader _Nullable header);
APPLE_ARCHIVE_API int AAHeaderAssign(AAHeader header, AAHeader from_header);
APPLE_ARCHIVE_API int AAHeaderClear(AAHeader header);

APPLE_ARCHIVE_API uint32_t AAHeaderGetFieldCount(AAHeader header);
/* the field index of a key, or -1 */
APPLE_ARCHIVE_API int AAHeaderGetKeyIndex(AAHeader header, AAFieldKey key);
APPLE_ARCHIVE_API AAFieldKey AAHeaderGetFieldKey(AAHeader header, uint32_t i);
/* a field's type, or -1 */
APPLE_ARCHIVE_API int AAHeaderGetFieldType(AAHeader header, uint32_t i);
/* the getters return 0, 1 when the field has another type, -1 for no such field */
APPLE_ARCHIVE_API int AAHeaderGetFieldUInt(AAHeader header, uint32_t i, uint64_t *value);
/* the string (length in *length; copied with a NUL into value when capacity allows) */
APPLE_ARCHIVE_API int AAHeaderGetFieldString(AAHeader header, uint32_t i, size_t capacity, char *_Nullable value, size_t *_Nullable length);
APPLE_ARCHIVE_API int AAHeaderGetFieldHash(AAHeader header, uint32_t i, size_t capacity, AAHashFunction *_Nullable hash_function,
                                           uint8_t *_Nullable value);
APPLE_ARCHIVE_API int AAHeaderGetFieldTimespec(AAHeader header, uint32_t i, struct timespec *value);
/* a blob's size and its offset from the end of the header in the payload */
APPLE_ARCHIVE_API int AAHeaderGetFieldBlob(AAHeader header, uint32_t i, uint64_t *size, uint64_t *offset);

/* the setters replace the field at index i (i < 0: the key's field, else a new last field); 0, or -1 */
APPLE_ARCHIVE_API int AAHeaderSetFieldFlag(AAHeader header, uint32_t i, AAFieldKey key);
APPLE_ARCHIVE_API int AAHeaderSetFieldUInt(AAHeader header, uint32_t i, AAFieldKey key, uint64_t value);
APPLE_ARCHIVE_API int AAHeaderSetFieldString(AAHeader header, uint32_t i, AAFieldKey key, const char *_Nullable value, size_t length);
APPLE_ARCHIVE_API int AAHeaderSetFieldHash(AAHeader header, uint32_t i, AAFieldKey key, AAHashFunction hash_function, const uint8_t *value);
APPLE_ARCHIVE_API int AAHeaderSetFieldTimespec(AAHeader header, uint32_t i, AAFieldKey key, const struct timespec *value);
APPLE_ARCHIVE_API int AAHeaderSetFieldBlob(AAHeader header, uint32_t i, AAFieldKey key, uint64_t size);
APPLE_ARCHIVE_API int AAHeaderRemoveField(AAHeader header, uint32_t i);

/* the encoded header */
APPLE_ARCHIVE_API size_t AAHeaderGetEncodedSize(AAHeader header);
APPLE_ARCHIVE_API const uint8_t *_Nullable AAHeaderGetEncodedData(AAHeader header);
/* the total size of the header's blobs */
APPLE_ARCHIVE_API uint64_t AAHeaderGetPayloadSize(AAHeader header);

/* the setters' "i" for "the field with this key, or a new one" */
#define AA_HEADER_FIELD_INDEX_BY_KEY ((uint32_t)-1)

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
