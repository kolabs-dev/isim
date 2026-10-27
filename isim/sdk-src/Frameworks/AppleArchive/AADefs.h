#pragma once
/* isim SDK (self-authored, Apple's declarations): AppleArchive's types, flags, field keys and messages. */
#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>
#include <time.h>

#ifdef __cplusplus
#define APPLE_ARCHIVE_API extern "C" __attribute__((visibility("default")))
#else
#define APPLE_ARCHIVE_API extern __attribute__((visibility("default")))
#endif
#define APPLE_ARCHIVE_API_VERSION 20241005

#if __has_feature(assume_nonnull)
#define APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define APPLE_ARCHIVE_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#else
#define APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN
#define APPLE_ARCHIVE_ASSUME_NONNULL_END
#endif

APPLE_ARCHIVE_ASSUME_NONNULL_BEGIN

/* option flags of the stream and archive functions (a bit set; verbosity in the top bits) */
typedef uint64_t AAFlagSet;
#define AA_FLAG_IGNORE_EPERM (UINT64_C(1) << 0)
#define AA_FLAG_ARCHIVE_DEDUPLICATE_DAT (UINT64_C(1) << 1)
#define AA_FLAG_ARCHIVE_NO_RESOLVE_ACL_QUALIFIERS (UINT64_C(1) << 2)
#define AA_FLAG_EXTRACT_NO_AUTO_DEDUP (UINT64_C(1) << 3)
#define AA_FLAG_EXTRACT_AUTO_DEDUP_AS_HARD_LINKS (UINT64_C(1) << 4)
#define AA_FLAG_REPLACE_ATTRIBUTES (UINT64_C(1) << 5)
#define AA_FLAG_DECODE_INSERT_IDX (UINT64_C(1) << 6)
#define AA_FLAG_EXCLUDE_METADATA_ENTRIES (UINT64_C(1) << 7)
#define AA_FLAG_EXTRACT_NO_AUTO_SPARSE (UINT64_C(1) << 8)
#define AA_FLAG_CROSS_VOLUME_BOUNDARIES (UINT64_C(1) << 9)
#define AA_FLAG_VERBOSITY_0 (UINT64_C(0) << 62)
#define AA_FLAG_VERBOSITY_1 (UINT64_C(1) << 62)
#define AA_FLAG_VERBOSITY_2 (UINT64_C(2) << 62)
#define AA_FLAG_VERBOSITY_3 (UINT64_C(3) << 62)

/* a header field's key: three characters (packed little-endian in ikey) */
typedef union {
    uint32_t ikey;
    char skey[4];
} AAFieldKey;
#define AA_FIELD_C(s) ((AAFieldKey){ .skey = { (s)[0], (s)[1], (s)[2], 0 } })

/* the field types */
typedef uint32_t AAFieldType;
#define AA_FIELD_TYPE_FLAG 0
#define AA_FIELD_TYPE_UINT 1
#define AA_FIELD_TYPE_STRING 2
#define AA_FIELD_TYPE_HASH 3
#define AA_FIELD_TYPE_TIMESPEC 4
#define AA_FIELD_TYPE_BLOB 5

/* hash functions of HASH fields */
typedef uint32_t AAHashFunction;
#define AA_HASH_FUNCTION_CRC32 1
#define AA_HASH_FUNCTION_SHA1 2
#define AA_HASH_FUNCTION_SHA256 3
#define AA_HASH_FUNCTION_SHA384 4
#define AA_HASH_FUNCTION_SHA512 5
#define AA_HASH_MAX_SIZE 64

/* entry types (the TYP field) */
typedef uint32_t AAEntryType;
#define AA_ENTRY_TYPE_REG 'F'
#define AA_ENTRY_TYPE_DIR 'D'
#define AA_ENTRY_TYPE_LNK 'L'
#define AA_ENTRY_TYPE_FIFO 'P'
#define AA_ENTRY_TYPE_CHR 'C'
#define AA_ENTRY_TYPE_BLK 'B'
#define AA_ENTRY_TYPE_SOCK 'S'
#define AA_ENTRY_TYPE_WHT 'W'
#define AA_ENTRY_TYPE_DOOR 'R'
#define AA_ENTRY_TYPE_PORT 'T'
#define AA_ENTRY_TYPE_METADATA 'M'

/* compression of AACompressionOutputStreamOpen (libcompression's algorithm values) */
typedef uint32_t AACompressionAlgorithm;
#define AA_COMPRESSION_ALGORITHM_NONE 0
#define AA_COMPRESSION_ALGORITHM_LZ4 0x100
#define AA_COMPRESSION_ALGORITHM_ZLIB 0x505
#define AA_COMPRESSION_ALGORITHM_LZMA 0x306
#define AA_COMPRESSION_ALGORITHM_LZFSE 0x801
#define AA_COMPRESSION_ALGORITHM_LZBITMAP 0x702
#define AA_COMPRESSION_ALGORITHM_LZRAVEN 0x80a

/* messages to an entry message callback: what is happening to `path`; the callback answers 0 to continue, a positive
   value to skip the entry (exclude messages) and a negative value to cancel. `data` is the entry's AAHeader for the
   ENCODE_WRITING, DECODE_READING, CONVERT_EXCLUDE, PROCESS_EXCLUDE and EXTRACT_BEGIN messages, its AAEntryXATBlob for
   EXTRACT_XAT, otherwise NULL */
typedef uint32_t AAEntryMessage;
#define AA_ENTRY_MESSAGE_SEARCH_PRUNE_DIR 10
#define AA_ENTRY_MESSAGE_SEARCH_EXCLUDE 11
#define AA_ENTRY_MESSAGE_SEARCH_FAIL 12
#define AA_ENTRY_MESSAGE_EXTRACT_BEGIN 20
#define AA_ENTRY_MESSAGE_EXTRACT_END 21
#define AA_ENTRY_MESSAGE_EXTRACT_FAIL 22
#define AA_ENTRY_MESSAGE_EXTRACT_ATTRIBUTES 23
#define AA_ENTRY_MESSAGE_EXTRACT_XAT 24
#define AA_ENTRY_MESSAGE_EXTRACT_ACL 25
#define AA_ENTRY_MESSAGE_ENCODE_SCANNING 30
#define AA_ENTRY_MESSAGE_ENCODE_WRITING 31
#define AA_ENTRY_MESSAGE_DECODE_READING 40
#define AA_ENTRY_MESSAGE_CONVERT_EXCLUDE 50
#define AA_ENTRY_MESSAGE_PROCESS_EXCLUDE 60
typedef int (*AAEntryMessageProc)(void *_Nullable arg, AAEntryMessage message, const char *path, void *_Nullable data);

/* the opaque objects */
typedef struct AAByteStream_impl *AAByteStream;
typedef struct AAArchiveStream_impl *AAArchiveStream;
typedef struct AAHeader_impl *AAHeader;
typedef struct AAFieldKeySet_impl *AAFieldKeySet;
typedef struct AAPathList_impl *AAPathList;
typedef struct AAEntryXATBlob_impl *AAEntryXATBlob;
typedef struct AAEntryAttributes_impl *AAEntryAttributes;

APPLE_ARCHIVE_ASSUME_NONNULL_END
