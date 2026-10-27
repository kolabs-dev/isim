#pragma once
/* isim SDK (self-authored, Apple's declarations): lists of relative paths under a directory, for archiving. */
#include <AppleArchive/AADefs.h>

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

/* `path` (relative to `dir`, NULL: the directory itself) and, for a directory, everything under it; the message
   callback can exclude entries (AA_ENTRY_MESSAGE_SEARCH_EXCLUDE) or whole directories (..._PRUNE_DIR) */
APPLE_ARCHIVE_API AAPathList _Nullable AAPathListCreateWithDirectoryContents(const char *dir, const char *_Nullable path,
                                                                             void *_Nullable msg_data, AAEntryMessageProc _Nullable msg_proc,
                                                                             AAFlagSet flags, int n_threads);
APPLE_ARCHIVE_API AAPathList _Nullable AAPathListCreateWithPath(const char *dir, const char *path);
APPLE_ARCHIVE_API void AAPathListDestroy(AAPathList _Nullable path_list);
#define AA_PATH_LIST_NODE_END ((uint64_t)-1)
APPLE_ARCHIVE_API uint64_t AAPathListNodeFirst(AAPathList path_list);
APPLE_ARCHIVE_API uint64_t AAPathListNodeNext(AAPathList path_list, uint64_t node);
/* the node's path into path (capacity bytes with the NUL); 0, or -1 */
APPLE_ARCHIVE_API int AAPathListNodeGetPath(AAPathList path_list, uint64_t node, size_t path_capacity, char *_Nullable path,
                                            size_t *_Nullable path_length);

#ifdef __cplusplus
}
#endif
APPLE_ARCHIVE_ASSUME_NONNULL_END
