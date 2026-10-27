/* isim AppleArchive: headers, field key sets and XAT blobs (adapted). A header's encoding: "AA01", its total size
 * (little-endian uint16), then each field as its 3-character key and a type character: '*' a flag; '1' '2' '4' '8' an
 * unsigned integer of that many bytes; 'P' a string (uint16 length + bytes); 'F' 'G' 'H' 'I' 'J' a CRC32 / SHA-1 /
 * SHA-256 / SHA-384 / SHA-512 hash; 'S' a time in seconds (8 bytes), 'T' seconds and nanoseconds (8 + 4); 'A' 'B' 'C' a
 * blob of a 2 / 4 / 8-byte size, whose bytes follow the header in field order. Self-authored. */
#include "AAInternal.h"
#include <CommonCrypto/CommonDigest.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>
#include <zlib.h>

AAFieldKey aa_key(const char *s) { AAFieldKey k = { .ikey = 0 }; memcpy(k.skey, s, 3); return k; }
int aa_key_is(AAFieldKey k, const char *s) { return k.ikey == aa_key(s).ikey; }
size_t aa_hash_size(AAHashFunction f) {
    switch (f) {
    case AA_HASH_FUNCTION_CRC32: return 4;
    case AA_HASH_FUNCTION_SHA1: return 20;
    case AA_HASH_FUNCTION_SHA256: return 32;
    case AA_HASH_FUNCTION_SHA384: return 48;
    case AA_HASH_FUNCTION_SHA512: return 64;
    default: return 0;
    }
}

/* ================= field key sets ================= */
struct AAFieldKeySet_impl { AAFieldKey *keys; uint32_t count, cap; };
AAFieldKeySet AAFieldKeySetCreate(void) { return calloc(1, sizeof(struct AAFieldKeySet_impl)); }
void AAFieldKeySetDestroy(AAFieldKeySet s) { if (s) { free(s->keys); free(s); } }
int AAFieldKeySetClear(AAFieldKeySet s) { s->count = 0; return 0; }
int AAFieldKeySetContainsKey(AAFieldKeySet s, AAFieldKey k) {
    for (uint32_t i = 0; i < s->count; i++) if (s->keys[i].ikey == k.ikey) return 1;
    return 0;
}
int AAFieldKeySetInsertKey(AAFieldKeySet s, AAFieldKey k) {
    k.skey[3] = 0;
    if (AAFieldKeySetContainsKey(s, k)) return 0;
    if (s->count == s->cap) {
        AAFieldKey *n = realloc(s->keys, (s->cap ? s->cap * 2 : 16) * sizeof *n);
        if (!n) return -1;
        s->keys = n; s->cap = s->cap ? s->cap * 2 : 16;
    }
    s->keys[s->count++] = k;
    return 0;
}
int AAFieldKeySetRemoveKey(AAFieldKeySet s, AAFieldKey k) {
    for (uint32_t i = 0; i < s->count; i++)
        if (s->keys[i].ikey == k.ikey) { memmove(s->keys + i, s->keys + i + 1, (s->count - i - 1) * sizeof *s->keys); s->count--; return 0; }
    return 0;
}
AAFieldKeySet AAFieldKeySetCreateWithString(const char *str) {
    AAFieldKeySet s = AAFieldKeySetCreate();
    if (!s) return NULL;
    const char *p = str;
    while (*p) {
        while (*p == ',' || *p == ' ') p++;
        if (!*p) break;
        const char *e = p;
        while (*e && *e != ',' && *e != ' ') e++;
        if (e - p != 3) { AAFieldKeySetDestroy(s); errno = EINVAL; return NULL; }
        AAFieldKeySetInsertKey(s, aa_key(p));
        p = e;
    }
    return s;
}
AAFieldKeySet AAFieldKeySetClone(AAFieldKeySet s) {
    AAFieldKeySet c = AAFieldKeySetCreate();
    if (!c) return NULL;
    for (uint32_t i = 0; i < s->count; i++) AAFieldKeySetInsertKey(c, s->keys[i]);
    return c;
}
int AAFieldKeySetInsertKeySet(AAFieldKeySet s, AAFieldKeySet o) { for (uint32_t i = 0; i < o->count; i++) AAFieldKeySetInsertKey(s, o->keys[i]); return 0; }
int AAFieldKeySetRemoveKeySet(AAFieldKeySet s, AAFieldKeySet o) { for (uint32_t i = 0; i < o->count; i++) AAFieldKeySetRemoveKey(s, o->keys[i]); return 0; }
int AAFieldKeySetSelectKeySet(AAFieldKeySet s, AAFieldKeySet o) {
    uint32_t n = 0;
    for (uint32_t i = 0; i < s->count; i++) if (AAFieldKeySetContainsKey(o, s->keys[i])) s->keys[n++] = s->keys[i];
    s->count = n;
    return 0;
}
uint32_t AAFieldKeySetGetKeyCount(AAFieldKeySet s) { return s->count; }
AAFieldKey AAFieldKeySetGetKey(AAFieldKeySet s, uint32_t i) { AAFieldKey none = { .ikey = 0 }; return i < s->count ? s->keys[i] : none; }
int AAFieldKeySetSerialize(AAFieldKeySet s, size_t cap, char *out) {
    size_t need = s->count ? s->count * 4 : 1;
    if (cap < need) return -1;
    char *p = out;
    for (uint32_t i = 0; i < s->count; i++) { if (i) *p++ = ','; memcpy(p, s->keys[i].skey, 3); p += 3; }
    *p = 0;
    return 0;
}

/* ================= headers ================= */
struct field {
    AAFieldKey key;
    AAFieldType type;
    uint64_t uint;                       /* UINT; BLOB: its size */
    char *string; size_t length;         /* STRING */
    AAHashFunction hash; uint8_t digest[AA_HASH_MAX_SIZE];
    struct timespec ts;
};
struct AAHeader_impl {
    struct field *fields;
    uint32_t count, cap;
    uint8_t *encoded; size_t encoded_size;   /* the last encoding (rebuilt when stale) */
    int stale;
};
AAHeader AAHeaderCreate(void) { AAHeader h = calloc(1, sizeof(struct AAHeader_impl)); if (h) h->stale = 1; return h; }
int AAHeaderClear(AAHeader h) {
    for (uint32_t i = 0; i < h->count; i++) free(h->fields[i].string);
    h->count = 0; h->stale = 1;
    return 0;
}
void AAHeaderDestroy(AAHeader h) { if (!h) return; AAHeaderClear(h); free(h->fields); free(h->encoded); free(h); }
int AAHeaderAssign(AAHeader h, AAHeader from) {
    if (h == from) return 0;
    AAHeaderClear(h);
    for (uint32_t i = 0; i < from->count; i++) {
        if (h->count == h->cap) {
            struct field *n = realloc(h->fields, (h->cap ? h->cap * 2 : 16) * sizeof *n);
            if (!n) return -1;
            h->fields = n; h->cap = h->cap ? h->cap * 2 : 16;
        }
        h->fields[h->count] = from->fields[i];
        if (from->fields[i].string) {
            h->fields[h->count].string = malloc(from->fields[i].length + 1);
            memcpy(h->fields[h->count].string, from->fields[i].string, from->fields[i].length + 1);
        }
        h->count++;
    }
    h->stale = 1;
    return 0;
}
AAHeader AAHeaderClone(AAHeader h) { AAHeader c = AAHeaderCreate(); if (c && AAHeaderAssign(c, h) < 0) { AAHeaderDestroy(c); return NULL; } return c; }
uint32_t AAHeaderGetFieldCount(AAHeader h) { return h->count; }
int AAHeaderGetKeyIndex(AAHeader h, AAFieldKey k) {
    k.skey[3] = 0;
    for (uint32_t i = 0; i < h->count; i++) if (h->fields[i].key.ikey == k.ikey) return (int)i;
    return -1;
}
AAFieldKey AAHeaderGetFieldKey(AAHeader h, uint32_t i) { AAFieldKey none = { .ikey = 0 }; return i < h->count ? h->fields[i].key : none; }
int AAHeaderGetFieldType(AAHeader h, uint32_t i) { return i < h->count ? (int)h->fields[i].type : -1; }
int AAHeaderGetFieldUInt(AAHeader h, uint32_t i, uint64_t *v) {
    if (i >= h->count) return -1;
    if (h->fields[i].type != AA_FIELD_TYPE_UINT) return 1;
    *v = h->fields[i].uint;
    return 0;
}
int AAHeaderGetFieldString(AAHeader h, uint32_t i, size_t cap, char *v, size_t *len) {
    if (i >= h->count) return -1;
    struct field *f = &h->fields[i];
    if (f->type != AA_FIELD_TYPE_STRING) return 1;
    if (len) *len = f->length;
    if (v && cap) {
        if (cap <= f->length) return -1;
        memcpy(v, f->string, f->length); v[f->length] = 0;
    }
    return 0;
}
int AAHeaderGetFieldHash(AAHeader h, uint32_t i, size_t cap, AAHashFunction *fn, uint8_t *v) {
    if (i >= h->count) return -1;
    struct field *f = &h->fields[i];
    if (f->type != AA_FIELD_TYPE_HASH) return 1;
    if (fn) *fn = f->hash;
    if (v) { size_t n = aa_hash_size(f->hash); if (cap < n) return -1; memcpy(v, f->digest, n); }
    return 0;
}
int AAHeaderGetFieldTimespec(AAHeader h, uint32_t i, struct timespec *v) {
    if (i >= h->count) return -1;
    if (h->fields[i].type != AA_FIELD_TYPE_TIMESPEC) return 1;
    *v = h->fields[i].ts;
    return 0;
}
int AAHeaderGetFieldBlob(AAHeader h, uint32_t i, uint64_t *size, uint64_t *offset) {
    if (i >= h->count) return -1;
    if (h->fields[i].type != AA_FIELD_TYPE_BLOB) return 1;
    uint64_t off = 0;
    for (uint32_t j = 0; j < i; j++) if (h->fields[j].type == AA_FIELD_TYPE_BLOB) off += h->fields[j].uint;
    *size = h->fields[i].uint; *offset = off;
    return 0;
}
uint64_t AAHeaderGetPayloadSize(AAHeader h) {
    uint64_t n = 0;
    for (uint32_t i = 0; i < h->count; i++) if (h->fields[i].type == AA_FIELD_TYPE_BLOB) n += h->fields[i].uint;
    return n;
}
/* the field to set: index i, the key's field (AA_HEADER_FIELD_INDEX_BY_KEY), or a new one (i == count) */
static struct field *slot(AAHeader h, uint32_t i, AAFieldKey key) {
    key.skey[3] = 0;
    if (i == AA_HEADER_FIELD_INDEX_BY_KEY) { int k = AAHeaderGetKeyIndex(h, key); i = k < 0 ? h->count : (uint32_t)k; }
    if (i > h->count) { errno = EINVAL; return NULL; }
    if (i == h->count) {
        if (h->count == h->cap) {
            struct field *n = realloc(h->fields, (h->cap ? h->cap * 2 : 16) * sizeof *n);
            if (!n) return NULL;
            h->fields = n; h->cap = h->cap ? h->cap * 2 : 16;
        }
        memset(&h->fields[h->count], 0, sizeof h->fields[0]);
        h->count++;
    }
    struct field *f = &h->fields[i];
    free(f->string);
    memset(f, 0, sizeof *f);
    f->key = key;
    h->stale = 1;
    return f;
}
int AAHeaderSetFieldFlag(AAHeader h, uint32_t i, AAFieldKey k) { struct field *f = slot(h, i, k); if (!f) return -1; f->type = AA_FIELD_TYPE_FLAG; return 0; }
int AAHeaderSetFieldUInt(AAHeader h, uint32_t i, AAFieldKey k, uint64_t v) { struct field *f = slot(h, i, k); if (!f) return -1; f->type = AA_FIELD_TYPE_UINT; f->uint = v; return 0; }
int AAHeaderSetFieldString(AAHeader h, uint32_t i, AAFieldKey k, const char *v, size_t len) {
    if (len > 0xffff) { errno = EINVAL; return -1; }
    struct field *f = slot(h, i, k);
    if (!f) return -1;
    f->type = AA_FIELD_TYPE_STRING; f->length = len;
    f->string = malloc(len + 1);
    if (len) memcpy(f->string, v, len);
    f->string[len] = 0;
    return 0;
}
int AAHeaderSetFieldHash(AAHeader h, uint32_t i, AAFieldKey k, AAHashFunction fn, const uint8_t *v) {
    size_t n = aa_hash_size(fn);
    if (!n) { errno = EINVAL; return -1; }
    struct field *f = slot(h, i, k);
    if (!f) return -1;
    f->type = AA_FIELD_TYPE_HASH; f->hash = fn; memcpy(f->digest, v, n);
    return 0;
}
int AAHeaderSetFieldTimespec(AAHeader h, uint32_t i, AAFieldKey k, const struct timespec *v) {
    struct field *f = slot(h, i, k);
    if (!f) return -1;
    f->type = AA_FIELD_TYPE_TIMESPEC; f->ts = *v;
    return 0;
}
int AAHeaderSetFieldBlob(AAHeader h, uint32_t i, AAFieldKey k, uint64_t size) { struct field *f = slot(h, i, k); if (!f) return -1; f->type = AA_FIELD_TYPE_BLOB; f->uint = size; return 0; }
int AAHeaderRemoveField(AAHeader h, uint32_t i) {
    if (i >= h->count) return -1;
    free(h->fields[i].string);
    memmove(h->fields + i, h->fields + i + 1, (h->count - i - 1) * sizeof *h->fields);
    h->count--; h->stale = 1;
    return 0;
}

/* ---- encoding ---- */
static void put_le(uint8_t *p, uint64_t v, int n) { for (int i = 0; i < n; i++) { p[i] = (uint8_t)v; v >>= 8; } }
static uint64_t get_le(const uint8_t *p, int n) { uint64_t v = 0; for (int i = n - 1; i >= 0; i--) v = (v << 8) | p[i]; return v; }
static int uint_width(uint64_t v) { return v <= 0xff ? 1 : v <= 0xffff ? 2 : v <= 0xffffffffu ? 4 : 8; }
static int encode(AAHeader h) {
    size_t size = 6;
    for (uint32_t i = 0; i < h->count; i++) {
        struct field *f = &h->fields[i];
        size += 4;
        switch (f->type) {
        case AA_FIELD_TYPE_UINT: size += (size_t)uint_width(f->uint); break;
        case AA_FIELD_TYPE_STRING: size += 2 + f->length; break;
        case AA_FIELD_TYPE_HASH: size += aa_hash_size(f->hash); break;
        case AA_FIELD_TYPE_TIMESPEC: size += f->ts.tv_nsec ? 12 : 8; break;
        case AA_FIELD_TYPE_BLOB: size += f->uint <= 0xffff ? 2 : f->uint <= 0xffffffffu ? 4 : 8; break;
        }
    }
    if (size > 0xffff) { errno = E2BIG; return -1; }
    uint8_t *e = realloc(h->encoded, size), *p;
    if (!e) return -1;
    h->encoded = e; h->encoded_size = size;
    memcpy(e, "AA01", 4); put_le(e + 4, size, 2);
    p = e + 6;
    for (uint32_t i = 0; i < h->count; i++) {
        struct field *f = &h->fields[i];
        memcpy(p, f->key.skey, 3);
        switch (f->type) {
        case AA_FIELD_TYPE_FLAG: p[3] = '*'; p += 4; break;
        case AA_FIELD_TYPE_UINT: { int w = uint_width(f->uint); p[3] = (uint8_t)('0' + w); put_le(p + 4, f->uint, w); p += 4 + w; break; }
        case AA_FIELD_TYPE_STRING: p[3] = 'P'; put_le(p + 4, f->length, 2); memcpy(p + 6, f->string, f->length); p += 6 + f->length; break;
        case AA_FIELD_TYPE_HASH: { size_t n = aa_hash_size(f->hash); p[3] = (uint8_t)('E' + f->hash); memcpy(p + 4, f->digest, n); p += 4 + n; break; }
        case AA_FIELD_TYPE_TIMESPEC:
            if (f->ts.tv_nsec) { p[3] = 'T'; put_le(p + 4, (uint64_t)f->ts.tv_sec, 8); put_le(p + 12, (uint64_t)f->ts.tv_nsec, 4); p += 16; }
            else { p[3] = 'S'; put_le(p + 4, (uint64_t)f->ts.tv_sec, 8); p += 12; }
            break;
        case AA_FIELD_TYPE_BLOB: {
            int w = f->uint <= 0xffff ? 2 : f->uint <= 0xffffffffu ? 4 : 8;
            p[3] = w == 2 ? 'A' : w == 4 ? 'B' : 'C'; put_le(p + 4, f->uint, w); p += 4 + w;
            break;
        }
        }
    }
    h->stale = 0;
    return 0;
}
size_t AAHeaderGetEncodedSize(AAHeader h) { if (h->stale && encode(h) < 0) return 0; return h->encoded_size; }
const uint8_t *AAHeaderGetEncodedData(AAHeader h) { if (h->stale && encode(h) < 0) return NULL; return h->encoded; }

static int decode_into(AAHeader h, size_t size, const uint8_t *d) {
    if (size < 6 || (memcmp(d, "AA01", 4) && memcmp(d, "YAA1", 4)) || get_le(d + 4, 2) != size) { errno = EINVAL; return -1; }
    AAHeaderClear(h);
    const uint8_t *p = d + 6, *end = d + size;
    while (p < end) {
        if (end - p < 4) goto bad;
        AAFieldKey k = aa_key((const char *)p);
        uint8_t t = p[3];
        p += 4;
        uint32_t idx = h->count;
        if (t == '*') AAHeaderSetFieldFlag(h, idx, k);
        else if (t == '1' || t == '2' || t == '4' || t == '8') {
            int w = t - '0';
            if (end - p < w) goto bad;
            AAHeaderSetFieldUInt(h, idx, k, get_le(p, w)); p += w;
        } else if (t == 'P') {
            if (end - p < 2) goto bad;
            size_t len = (size_t)get_le(p, 2);
            if ((size_t)(end - p - 2) < len) goto bad;
            AAHeaderSetFieldString(h, idx, k, (const char *)p + 2, len); p += 2 + len;
        } else if (t >= 'F' && t <= 'J') {
            AAHashFunction fn = (AAHashFunction)(t - 'E');
            size_t n = aa_hash_size(fn);
            if ((size_t)(end - p) < n) goto bad;
            AAHeaderSetFieldHash(h, idx, k, fn, p); p += n;
        } else if (t == 'S' || t == 'T') {
            int n = t == 'S' ? 8 : 12;
            if (end - p < n) goto bad;
            struct timespec ts = { (time_t)get_le(p, 8), t == 'T' ? (long)get_le(p + 8, 4) : 0 };
            AAHeaderSetFieldTimespec(h, idx, k, &ts); p += n;
        } else if (t == 'A' || t == 'B' || t == 'C') {
            int w = t == 'A' ? 2 : t == 'B' ? 4 : 8;
            if (end - p < w) goto bad;
            AAHeaderSetFieldBlob(h, idx, k, get_le(p, w)); p += w;
        } else goto bad;
    }
    return 0;
bad:
    AAHeaderClear(h);
    errno = EINVAL;
    return -1;
}
AAHeader AAHeaderCreateWithEncodedData(size_t size, const uint8_t *d) {
    AAHeader h = AAHeaderCreate();
    if (h && decode_into(h, size, d) < 0) { AAHeaderDestroy(h); return NULL; }
    return h;
}
/* the next header of an encoded stream (NULL with *eof at the end) */
AAHeader aa_header_read(AAByteStream s, int *eof) {
    uint8_t head[6];
    *eof = 0;
    ssize_t r = aa_read_all(s, head, 6);
    if (r == 0) { *eof = 1; return NULL; }
    if (r != 6) return NULL;
    size_t size = (size_t)get_le(head + 4, 2);
    if (size < 6) return NULL;
    uint8_t *buf = malloc(size);
    if (!buf) return NULL;
    memcpy(buf, head, 6);
    AAHeader h = NULL;
    if (aa_read_all(s, buf + 6, size - 6) == (ssize_t)(size - 6)) h = AAHeaderCreateWithEncodedData(size, buf);
    free(buf);
    return h;
}

/* ---- a header from the file system ---- */
int aa_hash_file(int fd, AAHashFunction fn, uint8_t *out) {
    unsigned char buf[65536];
    ssize_t n;
    if (lseek(fd, 0, SEEK_SET) < 0) return -1;
    switch (fn) {
    case AA_HASH_FUNCTION_CRC32: {
        uLong c = crc32(0, Z_NULL, 0);
        while ((n = read(fd, buf, sizeof buf)) > 0) c = crc32(c, buf, (uInt)n);
        out[0] = (uint8_t)(c >> 24); out[1] = (uint8_t)(c >> 16); out[2] = (uint8_t)(c >> 8); out[3] = (uint8_t)c;
        break;
    }
    case AA_HASH_FUNCTION_SHA1: { CC_SHA1_CTX c; CC_SHA1_Init(&c); while ((n = read(fd, buf, sizeof buf)) > 0) CC_SHA1_Update(&c, buf, (CC_LONG)n); CC_SHA1_Final(out, &c); break; }
    case AA_HASH_FUNCTION_SHA256: { CC_SHA256_CTX c; CC_SHA256_Init(&c); while ((n = read(fd, buf, sizeof buf)) > 0) CC_SHA256_Update(&c, buf, (CC_LONG)n); CC_SHA256_Final(out, &c); break; }
    case AA_HASH_FUNCTION_SHA384: { CC_SHA512_CTX c; CC_SHA384_Init(&c); while ((n = read(fd, buf, sizeof buf)) > 0) CC_SHA384_Update(&c, buf, (CC_LONG)n); CC_SHA384_Final(out, &c); break; }
    case AA_HASH_FUNCTION_SHA512: { CC_SHA512_CTX c; CC_SHA512_Init(&c); while ((n = read(fd, buf, sizeof buf)) > 0) CC_SHA512_Update(&c, buf, (CC_LONG)n); CC_SHA512_Final(out, &c); break; }
    default: errno = EINVAL; return -1;
    }
    lseek(fd, 0, SEEK_SET);
    return n < 0 ? -1 : 0;
}
static char type_letter(mode_t m) {
    switch (m & S_IFMT) {
    case S_IFREG: return AA_ENTRY_TYPE_REG;
    case S_IFDIR: return AA_ENTRY_TYPE_DIR;
    case S_IFLNK: return AA_ENTRY_TYPE_LNK;
    case S_IFIFO: return AA_ENTRY_TYPE_FIFO;
    case S_IFCHR: return AA_ENTRY_TYPE_CHR;
    case S_IFBLK: return AA_ENTRY_TYPE_BLK;
    case S_IFSOCK: return AA_ENTRY_TYPE_SOCK;
    default: return 0;
    }
}
/* the fields of key_set for dir/path, in the key set's order */
AAHeader AAHeaderCreateWithPath(AAFieldKeySet keys, const char *dir, const char *path, AAFlagSet flags) {
    char full[2048];
    snprintf(full, sizeof full, "%s/%s", dir, path);
    struct stat st;
    if (lstat(full, &st) != 0) return NULL;
    AAHeader h = AAHeaderCreate();
    if (!h) return NULL;
    int fd = -1;
    for (uint32_t i = 0; i < keys->count; i++) {
        AAFieldKey k = keys->keys[i];
        const uint32_t at = AA_HEADER_FIELD_INDEX_BY_KEY;
        if (aa_key_is(k, "TYP")) AAHeaderSetFieldUInt(h, at, k, (uint64_t)type_letter(st.st_mode));
        else if (aa_key_is(k, "PAT")) AAHeaderSetFieldString(h, at, k, path, strlen(path));
        else if (aa_key_is(k, "LNK") && S_ISLNK(st.st_mode)) {
            char target[1024];
            ssize_t n = readlink(full, target, sizeof target);
            if (n >= 0) AAHeaderSetFieldString(h, at, k, target, (size_t)n);
        }
        else if (aa_key_is(k, "DEV") && ((st.st_mode & S_IFMT) == S_IFCHR || (st.st_mode & S_IFMT) == S_IFBLK)) AAHeaderSetFieldUInt(h, at, k, (uint64_t)st.st_rdev);
        else if (aa_key_is(k, "UID")) AAHeaderSetFieldUInt(h, at, k, st.st_uid);
        else if (aa_key_is(k, "GID")) AAHeaderSetFieldUInt(h, at, k, st.st_gid);
        else if (aa_key_is(k, "MOD")) AAHeaderSetFieldUInt(h, at, k, st.st_mode & 07777);
        else if (aa_key_is(k, "FLG")) AAHeaderSetFieldUInt(h, at, k, st.st_flags);
        else if (aa_key_is(k, "MTM")) AAHeaderSetFieldTimespec(h, at, k, &st.st_mtimespec);
        else if (aa_key_is(k, "BTM")) AAHeaderSetFieldTimespec(h, at, k, &st.st_birthtimespec);
        else if (aa_key_is(k, "CTM")) AAHeaderSetFieldTimespec(h, at, k, &st.st_ctimespec);
        else if (aa_key_is(k, "INO")) AAHeaderSetFieldUInt(h, at, k, st.st_ino);
        else if (aa_key_is(k, "NLK")) AAHeaderSetFieldUInt(h, at, k, st.st_nlink);
        else if (aa_key_is(k, "SIZ") && S_ISREG(st.st_mode)) AAHeaderSetFieldUInt(h, at, k, (uint64_t)st.st_size);
        else if (aa_key_is(k, "DAT") && S_ISREG(st.st_mode)) AAHeaderSetFieldBlob(h, at, k, (uint64_t)st.st_size);
        else if (S_ISREG(st.st_mode) && (aa_key_is(k, "CKS") || aa_key_is(k, "SH1") || aa_key_is(k, "SH2") || aa_key_is(k, "SH3") || aa_key_is(k, "SH5"))) {
            AAHashFunction fn = aa_key_is(k, "CKS") ? AA_HASH_FUNCTION_CRC32 : aa_key_is(k, "SH1") ? AA_HASH_FUNCTION_SHA1 :
                                aa_key_is(k, "SH2") ? AA_HASH_FUNCTION_SHA256 : aa_key_is(k, "SH3") ? AA_HASH_FUNCTION_SHA384 : AA_HASH_FUNCTION_SHA512;
            uint8_t digest[AA_HASH_MAX_SIZE];
            if (fd < 0) fd = open(full, O_RDONLY);
            if (fd >= 0 && aa_hash_file(fd, fn, digest) == 0) AAHeaderSetFieldHash(h, at, k, fn, digest);
        }
        else if (aa_key_is(k, "XAT")) {
            AAEntryXATBlob x = AAEntryXATBlobCreateWithPath(dir, path, flags);
            if (x && AAEntryXATBlobGetEntryCount(x)) AAHeaderSetFieldBlob(h, at, k, AAEntryXATBlobGetEncodedSize(x));
            AAEntryXATBlobDestroy(x);
        }
    }
    if (fd >= 0) close(fd);
    return h;
}

/* ================= XAT blobs: per attribute, uint32 entry size, the NUL-terminated name, the data ================= */
struct xat_entry { char *key; uint8_t *data; size_t size; };
struct AAEntryXATBlob_impl { struct xat_entry *e; uint32_t count, cap; uint8_t *encoded; size_t encoded_size; };
AAEntryXATBlob AAEntryXATBlobCreate(void) { return calloc(1, sizeof(struct AAEntryXATBlob_impl)); }
int AAEntryXATBlobClear(AAEntryXATBlob x) {
    for (uint32_t i = 0; i < x->count; i++) { free(x->e[i].key); free(x->e[i].data); }
    x->count = 0;
    return 0;
}
void AAEntryXATBlobDestroy(AAEntryXATBlob x) { if (!x) return; AAEntryXATBlobClear(x); free(x->e); free(x->encoded); free(x); }
uint32_t AAEntryXATBlobGetEntryCount(AAEntryXATBlob x) { return x->count; }
int AAEntryXATBlobAppendEntry(AAEntryXATBlob x, const char *key, const uint8_t *data, size_t size) {
    if (x->count == x->cap) {
        struct xat_entry *n = realloc(x->e, (x->cap ? x->cap * 2 : 8) * sizeof *n);
        if (!n) return -1;
        x->e = n; x->cap = x->cap ? x->cap * 2 : 8;
    }
    struct xat_entry *e = &x->e[x->count++];
    e->key = strdup(key); e->size = size; e->data = malloc(size ? size : 1);
    if (size) memcpy(e->data, data, size);
    return 0;
}
int AAEntryXATBlobSetEntry(AAEntryXATBlob x, uint32_t i, const char *key, const uint8_t *data, size_t size) {
    if (i == x->count) return AAEntryXATBlobAppendEntry(x, key, data, size);
    if (i > x->count) return -1;
    struct xat_entry *e = &x->e[i];
    free(e->key); free(e->data);
    e->key = strdup(key); e->size = size; e->data = malloc(size ? size : 1);
    if (size) memcpy(e->data, data, size);
    return 0;
}
int AAEntryXATBlobRemoveEntry(AAEntryXATBlob x, uint32_t i) {
    if (i >= x->count) return -1;
    free(x->e[i].key); free(x->e[i].data);
    memmove(x->e + i, x->e + i + 1, (x->count - i - 1) * sizeof *x->e);
    x->count--;
    return 0;
}
int AAEntryXATBlobGetEntry(AAEntryXATBlob x, uint32_t i, size_t kcap, char *key, size_t *klen, size_t dcap, uint8_t *data, size_t *dsize) {
    if (i >= x->count) return -1;
    struct xat_entry *e = &x->e[i];
    size_t kl = strlen(e->key);
    if (klen) *klen = kl;
    if (dsize) *dsize = e->size;
    if (key && kcap) { if (kcap <= kl) return -1; memcpy(key, e->key, kl + 1); }
    if (data && dcap) { if (dcap < e->size) return -1; memcpy(data, e->data, e->size); }
    return 0;
}
static void xat_encode(AAEntryXATBlob x) {
    size_t n = 0;
    for (uint32_t i = 0; i < x->count; i++) n += 4 + strlen(x->e[i].key) + 1 + x->e[i].size;
    x->encoded = realloc(x->encoded, n ? n : 1); x->encoded_size = n;
    uint8_t *p = x->encoded;
    for (uint32_t i = 0; i < x->count; i++) {
        size_t kl = strlen(x->e[i].key) + 1, sz = 4 + kl + x->e[i].size;
        put_le(p, sz, 4); memcpy(p + 4, x->e[i].key, kl); memcpy(p + 4 + kl, x->e[i].data, x->e[i].size);
        p += sz;
    }
}
size_t AAEntryXATBlobGetEncodedSize(AAEntryXATBlob x) { xat_encode(x); return x->encoded_size; }
const uint8_t *AAEntryXATBlobGetEncodedData(AAEntryXATBlob x) { xat_encode(x); return x->encoded; }
AAEntryXATBlob AAEntryXATBlobCreateWithEncodedData(const uint8_t *d, size_t size) {
    AAEntryXATBlob x = AAEntryXATBlobCreate();
    if (!x) return NULL;
    const uint8_t *p = d, *end = d + size;
    while (end - p >= 4) {
        size_t sz = (size_t)get_le(p, 4);
        if (sz < 5 || (size_t)(end - p) < sz) goto bad;
        const char *key = (const char *)p + 4;
        size_t kl = strnlen(key, sz - 4);
        if (kl == sz - 4) goto bad;
        AAEntryXATBlobAppendEntry(x, key, p + 4 + kl + 1, sz - 4 - kl - 1);
        p += sz;
    }
    if (p != end) goto bad;
    return x;
bad:
    AAEntryXATBlobDestroy(x);
    errno = EINVAL;
    return NULL;
}
AAEntryXATBlob AAEntryXATBlobCreateWithPath(const char *dir, const char *path, AAFlagSet flags) {
    char full[2048];
    snprintf(full, sizeof full, "%s/%s", dir, path);
    AAEntryXATBlob x = AAEntryXATBlobCreate();
    if (!x) return NULL;
    ssize_t n = listxattr(full, NULL, 0, XATTR_NOFOLLOW);
    if (n <= 0) return x;
    char *names = malloc((size_t)n);
    n = listxattr(full, names, (size_t)n, XATTR_NOFOLLOW);
    for (char *k = names; n > 0 && k < names + n; k += strlen(k) + 1) {
        ssize_t sz = getxattr(full, k, NULL, 0, 0, XATTR_NOFOLLOW);
        if (sz < 0) continue;
        uint8_t *v = malloc((size_t)sz + 1);
        sz = getxattr(full, k, v, (size_t)sz, 0, XATTR_NOFOLLOW);
        if (sz >= 0) AAEntryXATBlobAppendEntry(x, k, v, (size_t)sz);
        free(v);
    }
    free(names);
    return x;
}
int AAEntryXATBlobApplyToPath(AAEntryXATBlob x, const char *dir, const char *path, AAFlagSet flags) {
    char full[2048];
    snprintf(full, sizeof full, "%s/%s", dir, path);
    int r = 0;
    for (uint32_t i = 0; i < x->count; i++)
        if (setxattr(full, x->e[i].key, x->e[i].data, x->e[i].size, 0, XATTR_NOFOLLOW) != 0 && !(flags & AA_FLAG_IGNORE_EPERM)) r = -1;
    return r;
}
