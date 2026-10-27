#pragma once
/* isim SDK (self-authored, Apple's declarations): sets of header field keys ("TYP,PAT,DAT"). */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

APPLE_ARCHIVE_API AAFieldKeySet _Nullable AAFieldKeySetCreate(void);
APPLE_ARCHIVE_API AAFieldKeySet _Nullable AAFieldKeySetCreateWithString(const char *s);
APPLE_ARCHIVE_API AAFieldKeySet _Nullable AAFieldKeySetClone(AAFieldKeySet key_set);
APPLE_ARCHIVE_API void AAFieldKeySetDestroy(AAFieldKeySet _Nullable key_set);
APPLE_ARCHIVE_API int AAFieldKeySetClear(AAFieldKeySet key_set);
APPLE_ARCHIVE_API int AAFieldKeySetContainsKey(AAFieldKeySet key_set, AAFieldKey key);
APPLE_ARCHIVE_API int AAFieldKeySetInsertKey(AAFieldKeySet key_set, AAFieldKey key);
APPLE_ARCHIVE_API int AAFieldKeySetRemoveKey(AAFieldKeySet key_set, AAFieldKey key);
APPLE_ARCHIVE_API int AAFieldKeySetInsertKeySet(AAFieldKeySet key_set, AAFieldKeySet s);
APPLE_ARCHIVE_API int AAFieldKeySetRemoveKeySet(AAFieldKeySet key_set, AAFieldKeySet s);
APPLE_ARCHIVE_API int AAFieldKeySetSelectKeySet(AAFieldKeySet key_set, AAFieldKeySet s);
APPLE_ARCHIVE_API uint32_t AAFieldKeySetGetKeyCount(AAFieldKeySet key_set);
/* the i-th key, or { .ikey = 0 } */
APPLE_ARCHIVE_API AAFieldKey AAFieldKeySetGetKey(AAFieldKeySet key_set, uint32_t i);
/* the keys as "TYP,PAT,…" into s (capacity bytes with the NUL); 0, or -1 when it does not fit */
APPLE_ARCHIVE_API int AAFieldKeySetSerialize(AAFieldKeySet key_set, size_t capacity, char *s);

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
