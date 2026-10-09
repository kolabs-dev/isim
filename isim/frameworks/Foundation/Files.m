/* isim Foundation (ARC): NSURL, NSFileManager, app container directories, property-list writing,
 * and persistent NSUserDefaults.
 * App data lives in ISIM_HOME when set (manual override), else in $ISIM_DATA/Containers/<bundle id>; the
 * equivalent of the simulator's per-app data container: Documents/, Library/Preferences/, tmp/. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <isim_host.h>
#include "isim_foundation.h"


/* ---------------- NSURL ---------------- */
/* percent-encodes what may not appear in a URL path (spaces, %, #, ?, quotes, non-ASCII ...) */
static NSString *encode_path(NSString *path, BOOL keepSlash) {
    NSUInteger n; const char *b = [path _isim_bytes:&n];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < n; i++) {
        unsigned char c = (unsigned char)b[i];
        if (isalnum(c) || strchr("-._~!$&'()*+,;=:@", c) || (c == '/' && keepSlash)) [out appendFormat:@"%c", c];
        else [out appendFormat:@"%%%02X", c];
    }
    return out;
}
@implementation NSURL { NSString *_string; NSString *_scheme, *_host, *_path, *_query, *_fragment, *_user; NSNumber *_port; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSURL class]); }    /* NS.base, NS.relative */
- (instancetype)initWithCoder:(NSCoder *)c {
    NSURL *base = [c decodeObjectOfClass:[NSURL class] forKey:@"NS.base"];
    NSString *rel = [c decodeObjectOfClass:[NSString class] forKey:@"NS.relative"];
    NSURL *u = rel ? [NSURL URLWithString:rel relativeToURL:base] : nil;     /* isim keeps URLs absolute */
    return u ? [self initWithString:u.absoluteString] : nil;
}
+ (instancetype)URLWithString:(NSString *)s { return [[self alloc] initWithString:s]; }
/* removes "." and ".." segments (RFC 3986 5.2.4) */
static NSString *remove_dot_segments(NSString *path) {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *segs = [path componentsSeparatedByString:@"/"];
    for (NSUInteger i = 0; i < segs.count; i++) {
        NSString *seg = segs[i]; BOOL last = i + 1 == segs.count;
        if ([seg isEqualToString:@"."]) { if (last) [out addObject:@""]; continue; }
        if ([seg isEqualToString:@".."]) { if (out.count > 1) [out removeLastObject]; if (last) [out addObject:@""]; continue; }
        [out addObject:seg];
    }
    return [out componentsJoinedByString:@"/"];
}
/* RFC 3986 5.2.2 reference resolution; the result is stored as an absolute URL (no separate baseURL) */
+ (instancetype)URLWithString:(NSString *)s relativeToURL:(NSURL *)base {
    NSURL *ref = [self URLWithString:s];
    if (!base || !ref || ref->_scheme) return ref;
    NSString *b = base.absoluteString;
    NSRange cut = [b rangeOfString:@"#"]; if (cut.location != NSNotFound) b = [b substringToIndex:cut.location];
    NSString *bq = nil; cut = [b rangeOfString:@"?"];
    if (cut.location != NSNotFound) { bq = [b substringFromIndex:cut.location]; b = [b substringToIndex:cut.location]; }
    /* prefix = scheme://authority, bpath = the base path */
    NSString *prefix = base->_scheme ? [base->_scheme stringByAppendingString:@":"] : @"", *bpath = [b substringFromIndex:prefix.length];
    if ([bpath hasPrefix:@"//"]) {
        NSRange slash = [[bpath substringFromIndex:2] rangeOfString:@"/"];
        NSUInteger end = slash.location == NSNotFound ? bpath.length : slash.location + 2;
        prefix = [prefix stringByAppendingString:[bpath substringToIndex:end]]; bpath = [bpath substringFromIndex:end];
    }
    NSString *frag = ref->_fragment ? [@"#" stringByAppendingString:ref->_fragment] : @"";
    NSString *q = ref->_query ? [@"?" stringByAppendingString:ref->_query] : nil;
    NSString *result;
    if ([s hasPrefix:@"//"]) result = [NSString stringWithFormat:@"%@%@", base->_scheme ? [base->_scheme stringByAppendingString:@":"] : @"", s];
    else if (!ref->_path.length) result = [NSString stringWithFormat:@"%@%@%@%@", prefix, bpath, q ?: (bq ?: @""), frag];
    else if ([ref->_path hasPrefix:@"/"]) result = [NSString stringWithFormat:@"%@%@%@%@", prefix, remove_dot_segments(ref->_path), q ?: @"", frag];
    else {
        NSRange ls = [bpath rangeOfString:@"/" options:NSBackwardsSearch];
        NSString *dir = ls.location == NSNotFound ? @"/" : [bpath substringToIndex:ls.location + 1];
        result = [NSString stringWithFormat:@"%@%@%@%@", prefix, remove_dot_segments([dir stringByAppendingString:ref->_path]), q ?: @"", frag];
    }
    return [self URLWithString:result];
}
+ (NSURL *)fileURLWithPath:(NSString *)path { return [[self alloc] initFileURLWithPath:path]; }
+ (NSURL *)fileURLWithPath:(NSString *)path isDirectory:(BOOL)d { return [self fileURLWithPath:d && ![path hasSuffix:@"/"] ? [path stringByAppendingString:@"/"] : path]; }
- (instancetype)initFileURLWithPath:(NSString *)path {
    NSString *abs = [path hasPrefix:@"/"] ? path : [NSHomeDirectory() stringByAppendingPathComponent:path];
    return [self initWithString:[@"file://" stringByAppendingString:encode_path(abs, YES)]];
}
- (instancetype)initWithString:(NSString *)s {
    if (!s.length) return nil;
    for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c == ' ' || c == '"' || c == '<' || c == '>') return nil; }
    if (!(self = [super init])) return nil;
    _string = [s copy];
    NSString *rest = s;
    NSRange colon = [rest rangeOfString:@":"];
    if (colon.location != NSNotFound && colon.location > 0) {
        NSString *scheme = [rest substringToIndex:colon.location];
        BOOL ok = YES;
        for (NSUInteger i = 0; i < scheme.length; i++) { unichar c = [scheme characterAtIndex:i]; if (!(isalnum(c) || c == '+' || c == '-' || c == '.')) ok = NO; }
        if (ok) { _scheme = scheme.lowercaseString; rest = [rest substringFromIndex:colon.location + 1]; }
    }
    NSRange hash = [rest rangeOfString:@"#"];
    if (hash.location != NSNotFound) { _fragment = [rest substringFromIndex:hash.location + 1]; rest = [rest substringToIndex:hash.location]; }
    NSRange q = [rest rangeOfString:@"?"];
    if (q.location != NSNotFound) { _query = [rest substringFromIndex:q.location + 1]; rest = [rest substringToIndex:q.location]; }
    if ([rest hasPrefix:@"//"]) {
        rest = [rest substringFromIndex:2];
        NSRange slash = [rest rangeOfString:@"/"];
        NSString *authority = slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location];
        rest = slash.location == NSNotFound ? @"" : [rest substringFromIndex:slash.location];
        NSRange at = [authority rangeOfString:@"@"];
        if (at.location != NSNotFound) { _user = [authority substringToIndex:at.location]; authority = [authority substringFromIndex:at.location + 1]; }
        NSRange pc = [authority rangeOfString:@":" options:NSBackwardsSearch], rb = [authority rangeOfString:@"]"];
        if (pc.location != NSNotFound && (rb.location == NSNotFound || pc.location > rb.location)) {
            NSString *ps = [authority substringFromIndex:pc.location + 1];
            if (ps.length) _port = @([ps integerValue]);
            authority = [authority substringToIndex:pc.location];
        }
        if ([authority hasPrefix:@"["] && [authority hasSuffix:@"]"]) authority = [authority substringWithRange:NSMakeRange(1, authority.length - 2)];   /* IPv6 literal */
        _host = authority.length ? authority : nil;
    }
    _path = rest;
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSURL class]] && [_string isEqualToString:[o absoluteString]]; }
- (NSUInteger)hash { return _string.hash; }
- (NSString *)description { return _string; }
- (NSString *)absoluteString { return _string; }
- (NSString *)relativeString { return _string; }
- (NSString *)scheme { return _scheme; }
- (NSString *)host { return _host; }
- (NSNumber *)port { return _port; }
- (NSString *)path {
    NSString *p = [_path stringByRemovingPercentEncoding_isim];
    return p.length > 1 && [p hasSuffix:@"/"] ? [p substringToIndex:p.length - 1] : p;
}
- (NSString *)query { return _query; }
- (NSString *)fragment { return _fragment; }
- (NSString *)user { return _user; }
- (BOOL)isFileURL { return [_scheme isEqualToString:@"file"]; }
- (NSString *)lastPathComponent { return self.path.lastPathComponent; }
- (NSString *)pathExtension { return self.path.pathExtension; }
- (NSURL *)URLByAppendingPathComponent:(NSString *)c {
    NSString *base = [_string hasSuffix:@"/"] ? _string : [_string stringByAppendingString:@"/"];
    return [NSURL URLWithString:[base stringByAppendingString:encode_path(c, YES)]];
}
@end

@implementation NSString (IsimPercent)
- (NSString *)stringByRemovingPercentEncoding_isim {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    char *out = malloc(n + 1); NSUInteger o = 0;
    for (NSUInteger i = 0; i < n; i++) {
        if (b[i] == '%' && i + 2 < n && isxdigit((unsigned char)b[i + 1]) && isxdigit((unsigned char)b[i + 2])) {
            char hex[3] = { b[i + 1], b[i + 2], 0 }; out[o++] = (char)strtol(hex, NULL, 16); i += 2;
        } else out[o++] = b[i];
    }
    return isim_string_take(out, o);
}
@end

/* ---------------- container directories ---------------- */
static void mkdirs(NSString *path) {
    char buf[4096]; snprintf(buf, sizeof buf, "%s", path.UTF8String);
    for (char *p = buf + 1; *p; p++) if (*p == '/') { *p = 0; mkdir(buf, 0755); *p = '/'; }
    mkdir(buf, 0755);
}
/* isim's device data: ISIM_DATA or ~/.local/share/isim (installed apps, app containers, system preferences) */
NSString *isim_data_dir(void) {
    const char *d = getenv("ISIM_DATA");
    if (d && *d) return @(d);
    const char *h = getenv("HOME");
    return [@(h && *h ? h : "/tmp") stringByAppendingPathComponent:@".local/share/isim"];
}
NSString *NSHomeDirectory(void) {
    static NSString *home;
    if (!home) {
        const char *h = getenv("ISIM_HOME");
        if (h && *h) home = @(h);
        else if (getenv("ISIM_CLIENT_SOCK") || getenv("ISIM_DATA")) {      /* under the shell: one container per app, like iOS */
            NSString *ident = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
            home = [[isim_data_dir() stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:ident];
        } else home = [NSTemporaryDirectory_isim() stringByAppendingPathComponent:@"isim-app-home"];
        for (NSString *sub in @[@"Documents", @"Library/Preferences", @"Library/Caches", @"Library/Application Support", @"tmp"])
            mkdirs([home stringByAppendingPathComponent:sub]);
    }
    return home;
}
NSString *NSTemporaryDirectory_isim(void) { const char *t = getenv("TMPDIR"); return @(t && *t ? t : "/tmp"); }
NSString *NSTemporaryDirectory(void) { return [[NSHomeDirectory() stringByAppendingPathComponent:@"tmp"] stringByAppendingString:@"/"]; }
NSArray<NSString *> *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory dir, NSSearchPathDomainMask mask, BOOL expand) {
    NSString *home = NSHomeDirectory(), *sub = nil;
    switch (dir) {
    case NSDocumentDirectory: sub = @"Documents"; break;
    case NSLibraryDirectory: sub = @"Library"; break;
    case NSCachesDirectory: sub = @"Library/Caches"; break;
    case NSApplicationSupportDirectory: sub = @"Library/Application Support"; break;
    default: return @[];
    }
    return @[[home stringByAppendingPathComponent:sub]];
}

@interface NSDirectoryEnumerator ()
- (instancetype)initWithIsimRoot:(NSString *)root URLs:(BOOL)urls options:(NSDirectoryEnumerationOptions)opts errorHandler:(BOOL (^)(NSURL *, NSError *))h;
@end
BOOL isim_is_package_path(NSString *path);

@implementation NSFileManager
+ (NSFileManager *)defaultManager { static NSFileManager *m; if (!m) m = [NSFileManager new]; return m; }
- (BOOL)fileExistsAtPath:(NSString *)p { return access(p.UTF8String, F_OK) == 0; }
- (BOOL)fileExistsAtPath:(NSString *)p isDirectory:(BOOL *)isDir {
    if (access(p.UTF8String, F_OK) != 0) return NO;
    if (isDir) { int fd = open([p stringByAppendingString:@"/."].UTF8String, O_RDONLY); *isDir = fd >= 0; if (fd >= 0) close(fd); }
    return YES;
}
static NSError *file_error(NSInteger code, NSString *path, int e);
- (BOOL)createDirectoryAtPath:(NSString *)p withIntermediateDirectories:(BOOL)inter attributes:(id)a error:(NSError **)err {
    struct stat st;
    if (!p.length) { if (err) *err = file_error(4, p, ENOENT); return NO; }
    if (inter && stat(p.UTF8String, &st) == 0 && S_ISDIR(st.st_mode)) return YES;     /* already there: fine with intermediates */
    if (inter) mkdirs(p);
    else if (mkdir(p.UTF8String, 0755) != 0) {         /* NSFileWriteFileExistsError / NSFileNoSuchFileError / NSFileWriteNoPermissionError */
        int e = errno;
        if (err) *err = file_error(e == EEXIST ? 516 : e == ENOENT || e == ENOTDIR ? 4 : e == EACCES || e == EPERM ? 513 : 512, p, e);
        return NO;
    }
    if (stat(p.UTF8String, &st) != 0 || !S_ISDIR(st.st_mode)) {
        if (err) *err = file_error(lstat(p.UTF8String, &st) == 0 ? 516 : 512, p, EEXIST);
        return NO;
    }
    return [a isKindOfClass:[NSDictionary class]] ? [self setAttributes:a ofItemAtPath:p error:err] : YES;
}
static BOOL remove_tree(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) return NO;
    if (S_ISDIR(st.st_mode)) {
        DIR *d = opendir(path);
        if (d) {
            for (struct dirent *e; (e = readdir(d));) {
                if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
                char child[4096]; snprintf(child, sizeof child, "%s/%s", path, e->d_name);
                remove_tree(child);
            }
            closedir(d);
        }
        return rmdir(path) == 0;
    }
    return unlink(path) == 0;
}
- (BOOL)removeItemAtPath:(NSString *)p error:(NSError **)err {
    if (remove_tree(p.UTF8String)) return YES;
    if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:4 userInfo:@{ @"NSFilePath": p ?: @"" }];
    return NO;
}
- (NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)p error:(id *)err {
    DIR *d = opendir(p.UTF8String);
    if (!d) { if (err) *err = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:260 userInfo:@{ @"NSFilePath": p ?: @"" }]; return nil; }
    NSMutableArray *out = [NSMutableArray array];
    for (struct dirent *e; (e = readdir(d));) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        [out addObject:@(e->d_name)];
    }
    closedir(d);
    [out sortUsingSelector:@selector(compare:)];
    return out;
}
- (NSArray<NSURL *> *)URLsForDirectory:(NSSearchPathDirectory)d inDomains:(NSSearchPathDomainMask)m {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in NSSearchPathForDirectoriesInDomains(d, m, YES)) [out addObject:[NSURL fileURLWithPath:p isDirectory:YES]];
    return out;
}
/* file attributes from lstat (a symbolic link's own, like iOS) */
static NSError *file_error(NSInteger code, NSString *path, int e) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code
                           userInfo:@{ @"NSFilePath": path ?: @"", NSUnderlyingErrorKey: [NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil] }];
}
static NSDate *date_of(struct timespec t) { return [NSDate dateWithTimeIntervalSince1970:(double)t.tv_sec + t.tv_nsec / 1e9]; }
- (NSDictionary<NSFileAttributeKey, id> *)attributesOfItemAtPath:(NSString *)p error:(NSError **)err {
    struct stat st;
    if (!p || lstat(p.UTF8String, &st) != 0) {          /* NSFileReadNoSuchFileError / NSFileReadNoPermissionError / NSFileReadUnknownError */
        int e = p ? errno : ENOENT;
        if (err) *err = file_error(e == ENOENT || e == ENOTDIR ? 260 : e == EACCES || e == EPERM ? 257 : 256, p, e);
        return nil;
    }
    NSFileAttributeType type = NSFileTypeUnknown;
    switch (st.st_mode & S_IFMT) {
    case S_IFREG: type = NSFileTypeRegular; break;
    case S_IFDIR: type = NSFileTypeDirectory; break;
    case S_IFLNK: type = NSFileTypeSymbolicLink; break;
    case S_IFSOCK: type = NSFileTypeSocket; break;
    case S_IFCHR: type = NSFileTypeCharacterSpecial; break;
    case S_IFBLK: type = NSFileTypeBlockSpecial; break;
    }
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[NSFileType] = type;
    a[NSFileSize] = @((unsigned long long)st.st_size);
    a[NSFileModificationDate] = date_of(st.st_mtimespec);
    a[NSFileCreationDate] = date_of(st.st_birthtimespec);
    a[NSFileReferenceCount] = @((unsigned long)st.st_nlink);
    a[NSFileSystemNumber] = @((int)st.st_dev);
    a[NSFileSystemFileNumber] = @((unsigned long long)st.st_ino);
    a[NSFilePosixPermissions] = @((unsigned short)(st.st_mode & 07777));
    a[NSFileOwnerAccountID] = @((unsigned int)st.st_uid);
    a[NSFileGroupOwnerAccountID] = @((unsigned int)st.st_gid);
    char name[256];
    if (isim_account_name(0, st.st_uid, name, sizeof name)) a[NSFileOwnerAccountName] = @(name);
    if (isim_account_name(1, st.st_gid, name, sizeof name)) a[NSFileGroupOwnerAccountName] = @(name);
    if ((st.st_mode & S_IFMT) == S_IFCHR || (st.st_mode & S_IFMT) == S_IFBLK) a[NSFileDeviceIdentifier] = @((int)st.st_rdev);
    a[NSFileExtensionHidden] = @NO;
    return [a copy];
}
/* applies what Linux can: permissions, owner and group (by id or name), modification date. The creation date, data
 * protection, the immutable / append-only flags, HFS codes and the hidden extension have no Linux equivalent an app
 * may set, and are accepted and ignored (adapted). */
- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attrs ofItemAtPath:(NSString *)p error:(NSError **)err {
    const char *path = p.UTF8String;
    if (!path || access(path, F_OK) != 0) { if (err) *err = file_error(4, p, ENOENT); return NO; }   /* NSFileNoSuchFileError */
    int rc = 0;
    long uid = -1, gid = -1;
    if ([attrs[NSFileOwnerAccountID] isKindOfClass:[NSNumber class]]) uid = [attrs[NSFileOwnerAccountID] longValue];
    else if ([attrs[NSFileOwnerAccountName] isKindOfClass:[NSString class]] && (uid = isim_account_id(0, [attrs[NSFileOwnerAccountName] UTF8String])) < 0) { errno = EINVAL; rc = -1; }
    if ([attrs[NSFileGroupOwnerAccountID] isKindOfClass:[NSNumber class]]) gid = [attrs[NSFileGroupOwnerAccountID] longValue];
    else if ([attrs[NSFileGroupOwnerAccountName] isKindOfClass:[NSString class]] && (gid = isim_account_id(1, [attrs[NSFileGroupOwnerAccountName] UTF8String])) < 0) { errno = EINVAL; rc = -1; }
    if (!rc && (uid >= 0 || gid >= 0)) rc = chown(path, (uid_t)uid, (gid_t)gid);
    if (!rc && [attrs[NSFilePosixPermissions] isKindOfClass:[NSNumber class]]) rc = chmod(path, (mode_t)([attrs[NSFilePosixPermissions] unsignedLongValue] & 07777));
    NSDate *m = attrs[NSFileModificationDate];
    if (!rc && [m isKindOfClass:[NSDate class]]) {
        struct stat st; rc = stat(path, &st);           /* keeps the access time */
        if (!rc) {
            double t = m.timeIntervalSince1970, sec = floor(t);
            struct timeval tv[2] = { { st.st_atimespec.tv_sec, (int)(st.st_atimespec.tv_nsec / 1000) }, { (time_t)sec, (int)((t - sec) * 1e6) } };
            rc = utimes(path, tv);
        }
    }
    if (rc) {                                           /* NSFileWriteNoPermissionError / NSFileWriteUnknownError */
        int e = errno;
        if (err) *err = file_error(e == EPERM || e == EACCES ? 513 : e == EROFS ? 642 : 512, p, e);
        return NO;
    }
    return YES;
}
- (NSDictionary<NSFileAttributeKey, id> *)attributesOfFileSystemForPath:(NSString *)p error:(NSError **)err {
    unsigned long long v[4];
    struct stat st;
    int rc = p ? isim_fs_stats(p.UTF8String, v) : -ENOENT;
    if (!rc && stat(p.UTF8String, &st) != 0) rc = -errno;
    if (rc) { if (err) *err = file_error(-rc == ENOENT || -rc == ENOTDIR ? 260 : 256, p, -rc); return nil; }
    return @{ NSFileSystemSize: @(v[0]), NSFileSystemFreeSize: @(v[1]), NSFileSystemNodes: @(v[2]), NSFileSystemFreeNodes: @(v[3]),
              NSFileSystemNumber: @((int)st.st_dev) };
}

/* ---- reading, copying, moving, links ---- */
- (NSData *)contentsAtPath:(NSString *)p { return p ? [NSData dataWithContentsOfFile:p] : nil; }
- (BOOL)createFileAtPath:(NSString *)p contents:(NSData *)data attributes:(NSDictionary<NSFileAttributeKey, id> *)attr {
    if (!p || ![data ?: [NSData data] writeToFile:p atomically:NO]) return NO;
    return attr.count ? [self setAttributes:attr ofItemAtPath:p error:NULL] : YES;
}
- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)inter attributes:(NSDictionary *)a error:(NSError **)err {
    return [self createDirectoryAtPath:url.path withIntermediateDirectories:inter attributes:a error:err];
}
/* an error code for a failed write (create / copy / move / link) */
static NSInteger write_code(int e) { return e == EEXIST ? 516 : e == EACCES || e == EPERM ? 513 : e == ENOSPC ? 640 : e == EROFS ? 642 : 512; }
static BOOL copy_file(const char *src, const char *dst, mode_t mode) {
    FILE *in = fopen(src, "rb");
    if (!in) return NO;
    FILE *out = fopen(dst, "wb");
    if (!out) { int e = errno; fclose(in); errno = e; return NO; }
    char buf[65536]; size_t n; BOOL ok = YES;
    while ((n = fread(buf, 1, sizeof buf, in)) > 0) if (fwrite(buf, 1, n, out) != n) { ok = NO; break; }
    int e = errno;
    fclose(in);
    if (fclose(out) != 0) ok = NO;
    if (ok) chmod(dst, mode & 07777);
    else { unlink(dst); errno = e ?: EIO; }
    return ok;
}
/* copies a file, a symbolic link (as a link) or a directory tree; keeps permissions and modification dates */
static BOOL copy_tree(const char *src, const char *dst) {
    struct stat st;
    if (lstat(src, &st) != 0) return NO;
    if (S_ISLNK(st.st_mode)) {
        char target[4096]; ssize_t n = readlink(src, target, sizeof target - 1);
        if (n < 0) return NO;
        target[n] = 0;
        return symlink(target, dst) == 0;
    }
    if (S_ISDIR(st.st_mode)) {
        if (mkdir(dst, (st.st_mode & 07777) | 0700) != 0) return NO;
        DIR *d = opendir(src);
        if (!d) return NO;
        BOOL ok = YES;
        for (struct dirent *e; ok && (e = readdir(d));) {
            if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
            char cs[4096], cd[4096];
            snprintf(cs, sizeof cs, "%s/%s", src, e->d_name); snprintf(cd, sizeof cd, "%s/%s", dst, e->d_name);
            ok = copy_tree(cs, cd);
        }
        int e = errno;
        closedir(d);
        chmod(dst, st.st_mode & 07777);
        errno = e;
        if (!ok) return NO;
    } else if (!copy_file(src, dst, st.st_mode)) return NO;
    struct timeval tv[2] = { { st.st_atimespec.tv_sec, (int)(st.st_atimespec.tv_nsec / 1000) }, { st.st_mtimespec.tv_sec, (int)(st.st_mtimespec.tv_nsec / 1000) } };
    utimes(dst, tv);
    return YES;
}
- (BOOL)copyItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)err {
    struct stat st;
    if (!src || lstat(src.UTF8String, &st) != 0) { if (err) *err = file_error(260, src, ENOENT); return NO; }   /* NSFileReadNoSuchFileError */
    if (!dst || lstat(dst.UTF8String, &st) == 0) { if (err) *err = file_error(516, dst, EEXIST); return NO; }    /* NSFileWriteFileExistsError */
    NSString *from = [src.stringByResolvingSymlinksInPath stringByAppendingString:@"/"];
    NSString *into = dst.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath;
    if ([[into stringByAppendingString:@"/"] hasPrefix:from]) { if (err) *err = file_error(512, dst, EINVAL); return NO; }  /* a directory into itself */
    if (copy_tree(src.UTF8String, dst.UTF8String)) return YES;
    int e = errno;
    remove_tree(dst.UTF8String);                        /* no half-copied tree left behind */
    if (err) *err = file_error(e == ENOENT || e == ENOTDIR ? 4 : write_code(e), dst, e);
    return NO;
}
- (BOOL)copyItemAtURL:(NSURL *)src toURL:(NSURL *)dst error:(NSError **)err { return [self copyItemAtPath:src.path toPath:dst.path error:err]; }
/* rename(2), or a copy and a removal across file systems; never replaces an existing item */
- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)err {
    struct stat st;
    if (!src || lstat(src.UTF8String, &st) != 0) { if (err) *err = file_error(4, src, ENOENT); return NO; }      /* NSFileNoSuchFileError */
    if (!dst || lstat(dst.UTF8String, &st) == 0) { if (err) *err = file_error(516, dst, EEXIST); return NO; }
    if (rename(src.UTF8String, dst.UTF8String) == 0) return YES;
    int e = errno;
    if (e == EXDEV) {
        if (copy_tree(src.UTF8String, dst.UTF8String)) { remove_tree(src.UTF8String); return YES; }
        e = errno; remove_tree(dst.UTF8String);
    }
    if (err) *err = file_error(e == ENOENT || e == ENOTDIR ? 4 : write_code(e), src, e);
    return NO;
}
- (BOOL)moveItemAtURL:(NSURL *)src toURL:(NSURL *)dst error:(NSError **)err { return [self moveItemAtPath:src.path toPath:dst.path error:err]; }
- (BOOL)removeItemAtURL:(NSURL *)url error:(NSError **)err { return [self removeItemAtPath:url.path error:err]; }
- (BOOL)isReadableFileAtPath:(NSString *)p { return p && access(p.UTF8String, R_OK) == 0; }
- (BOOL)isWritableFileAtPath:(NSString *)p { return p && access(p.UTF8String, W_OK) == 0; }
- (BOOL)isExecutableFileAtPath:(NSString *)p { return p && access(p.UTF8String, X_OK) == 0; }
/* an item can be removed when its directory is writable */
- (BOOL)isDeletableFileAtPath:(NSString *)p {
    struct stat st;
    if (!p.length || lstat(p.UTF8String, &st) != 0) return NO;
    NSString *dir = p.stringByDeletingLastPathComponent;
    return access((dir.length ? dir : @".").UTF8String, W_OK | X_OK) == 0;
}
static BOOL same_contents(const char *a, const char *b) {
    struct stat sa, sb;
    if (lstat(a, &sa) != 0 || lstat(b, &sb) != 0 || (sa.st_mode & S_IFMT) != (sb.st_mode & S_IFMT)) return NO;
    if (sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino) return YES;
    if (S_ISLNK(sa.st_mode)) {
        char ta[4096], tb[4096]; ssize_t na = readlink(a, ta, sizeof ta), nb = readlink(b, tb, sizeof tb);
        return na >= 0 && na == nb && !memcmp(ta, tb, (size_t)na);
    }
    if (S_ISDIR(sa.st_mode)) {
        NSArray *ca = [NSFileManager.defaultManager contentsOfDirectoryAtPath:@(a) error:NULL], *cb = [NSFileManager.defaultManager contentsOfDirectoryAtPath:@(b) error:NULL];
        if (!ca || ![ca isEqual:cb]) return NO;
        for (NSString *name in ca) {
            char ea[4096], eb[4096];
            snprintf(ea, sizeof ea, "%s/%s", a, name.UTF8String); snprintf(eb, sizeof eb, "%s/%s", b, name.UTF8String);
            if (!same_contents(ea, eb)) return NO;
        }
        return YES;
    }
    if (!S_ISREG(sa.st_mode) || sa.st_size != sb.st_size) return NO;
    FILE *fa = fopen(a, "rb"), *fb = fopen(b, "rb");
    BOOL same = fa && fb;
    char ba[65536], bb[65536];
    while (same) {
        size_t na = fread(ba, 1, sizeof ba, fa), nb = fread(bb, 1, sizeof bb, fb);
        if (na != nb || memcmp(ba, bb, na)) same = NO;
        if (na < sizeof ba) break;
    }
    if (fa) fclose(fa);
    if (fb) fclose(fb);
    return same;
}
- (BOOL)contentsEqualAtPath:(NSString *)a andPath:(NSString *)b { return a && b && same_contents(a.UTF8String, b.UTF8String); }
/* adapted: the file name (iOS also hides a known extension and localizes system folders) */
- (NSString *)displayNameAtPath:(NSString *)p { return p.lastPathComponent; }
- (BOOL)linkItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)err {
    if (src && dst && link(src.UTF8String, dst.UTF8String) == 0) return YES;
    int e = src && dst ? errno : ENOENT;
    struct stat st;
    if (err) *err = src && lstat(src.UTF8String, &st) != 0 ? file_error(260, src, e) : file_error(write_code(e), dst, e);
    return NO;
}
- (BOOL)linkItemAtURL:(NSURL *)src toURL:(NSURL *)dst error:(NSError **)err { return [self linkItemAtPath:src.path toPath:dst.path error:err]; }
- (BOOL)createSymbolicLinkAtPath:(NSString *)p withDestinationPath:(NSString *)dest error:(NSError **)err {
    if (p && dest && symlink(dest.UTF8String, p.UTF8String) == 0) return YES;
    int e = p && dest ? errno : EINVAL;
    if (err) *err = file_error(e == ENOENT || e == ENOTDIR ? 4 : write_code(e), p, e);
    return NO;
}
/* a file URL destination links to its path; any other URL to its string, as on iOS */
- (BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)dest error:(NSError **)err {
    return [self createSymbolicLinkAtPath:url.path withDestinationPath:dest.isFileURL ? dest.path : dest.absoluteString error:err];
}
- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)p error:(NSError **)err {
    char target[4096];
    ssize_t n = p ? readlink(p.UTF8String, target, sizeof target - 1) : -1;
    if (n >= 0) return [[NSString alloc] initWithBytes:target length:(NSUInteger)n encoding:NSUTF8StringEncoding];
    int e = p ? errno : ENOENT;                         /* NSFileReadNoSuchFileError / NSFileReadUnknownError (not a link) */
    if (err) *err = file_error(e == ENOENT || e == ENOTDIR ? 260 : e == EACCES ? 257 : 256, p, e);
    return nil;
}

/* ---- directory contents ---- */
/* adapted: a package is a directory with one of the package extensions iOS knows (no Uniform Type lookup) */
BOOL isim_is_package_path(NSString *path) {
    static NSSet *exts;
    if (!exts) exts = [NSSet setWithObjects:@"app", @"appex", @"bundle", @"framework", @"plugin", @"rtfd", @"playground", @"xcodeproj",
                                            @"xcworkspace", @"pages", @"numbers", @"key", @"photoslibrary", @"mlmodelc", nil];
    return [exts containsObject:path.pathExtension.lowercaseString];
}
static NSArray<NSString *> *listing(NSString *dir, NSDirectoryEnumerationOptions opts, int *errOut) {
    DIR *d = opendir(dir.UTF8String);
    if (!d) { *errOut = errno; return nil; }
    NSMutableArray *out = [NSMutableArray array];
    for (struct dirent *e; (e = readdir(d));) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if ((opts & NSDirectoryEnumerationSkipsHiddenFiles) && e->d_name[0] == '.') continue;
        [out addObject:@(e->d_name)];
    }
    closedir(d);
    [out sortUsingSelector:@selector(compare:)];
    return out;
}
static BOOL is_dir_at(NSString *p) { struct stat st; return lstat(p.UTF8String, &st) == 0 && S_ISDIR(st.st_mode); }
static NSError *read_error(NSString *p, int e) { return file_error(e == ENOENT || e == ENOTDIR ? 260 : e == EACCES || e == EPERM ? 257 : 256, p, e); }
- (NSArray<NSURL *> *)contentsOfDirectoryAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)err {
    int e = 0; NSString *dir = url.path;
    NSArray *names = listing(dir, mask & NSDirectoryEnumerationSkipsHiddenFiles, &e);
    if (!names) { if (err) *err = read_error(dir, e); return nil; }
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *n in names) { NSString *p = [dir stringByAppendingPathComponent:n]; [out addObject:[NSURL fileURLWithPath:p isDirectory:is_dir_at(p)]]; }
    return out;
}
- (NSDirectoryEnumerator<NSString *> *)enumeratorAtPath:(NSString *)p {
    return p ? [[NSDirectoryEnumerator alloc] initWithIsimRoot:p URLs:NO options:0 errorHandler:nil] : nil;
}
- (NSDirectoryEnumerator<NSURL *> *)enumeratorAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask
                                       errorHandler:(BOOL (^)(NSURL *, NSError *))handler {
    return url.path.length ? [[NSDirectoryEnumerator alloc] initWithIsimRoot:url.path URLs:YES options:mask errorHandler:handler] : nil;
}
- (NSArray<NSString *> *)subpathsOfDirectoryAtPath:(NSString *)p error:(NSError **)err {
    struct stat st;
    if (!p || stat(p.UTF8String, &st) != 0 || !S_ISDIR(st.st_mode)) { if (err) *err = read_error(p, p && errno != 0 ? errno : ENOENT); return nil; }
    return [self enumeratorAtPath:p].allObjects;
}
- (NSArray<NSString *> *)subpathsAtPath:(NSString *)p { return [self subpathsOfDirectoryAtPath:p error:NULL]; }

/* ---- replacing ---- */
/* the new item takes the original's place with rename(2) (atomic on one file system); the original goes to the backup
 * name when one is given, kept with NSFileManagerItemReplacementWithoutDeletingBackupItem. Unless
 * NSFileManagerItemReplacementUsingNewMetadataOnly, the new item gets the original's permissions (adapted: the only
 * metadata Linux keeps that iOS carries over). */
- (BOOL)replaceItemAtURL:(NSURL *)original withItemAtURL:(NSURL *)newItem backupItemName:(NSString *)backupName
                 options:(NSFileManagerItemReplacementOptions)options resultingItemURL:(NSURL **)resulting error:(NSError **)err {
    NSString *orig = original.path, *src = newItem.path;
    struct stat ost, nst;
    if (!src || lstat(src.UTF8String, &nst) != 0) { if (err) *err = file_error(4, src, ENOENT); return NO; }
    BOOL hadOriginal = orig && lstat(orig.UTF8String, &ost) == 0;
    NSString *backup = backupName.length ? [orig.stringByDeletingLastPathComponent stringByAppendingPathComponent:backupName] : nil;
    if (hadOriginal && !(options & NSFileManagerItemReplacementUsingNewMetadataOnly) && !S_ISLNK(nst.st_mode)) chmod(src.UTF8String, ost.st_mode & 07777);
    if (hadOriginal && backup) {
        remove_tree(backup.UTF8String);
        if (rename(orig.UTF8String, backup.UTF8String) != 0) { int e = errno; if (err) *err = file_error(write_code(e), orig, e); return NO; }
    }
    if (rename(src.UTF8String, orig.UTF8String) != 0) {
        int e = errno;
        if (e == EXDEV || (e == EISDIR || e == ENOTDIR || e == EEXIST)) {     /* across file systems, or a directory over a file */
            NSString *aside = hadOriginal && !backup ? [orig stringByAppendingFormat:@".isim-replace-%d", getpid()] : nil;
            if (aside && rename(orig.UTF8String, aside.UTF8String) != 0) aside = nil;
            if (copy_tree(src.UTF8String, orig.UTF8String)) {
                remove_tree(src.UTF8String);
                if (aside) remove_tree(aside.UTF8String);
                goto done;
            }
            e = errno;
            if (aside) { remove_tree(orig.UTF8String); rename(aside.UTF8String, orig.UTF8String); }
        }
        if (backup) rename(backup.UTF8String, orig.UTF8String);    /* puts the original back */
        if (err) *err = file_error(write_code(e), orig, e);
        return NO;
    }
done:
    if (backup && hadOriginal && !(options & NSFileManagerItemReplacementWithoutDeletingBackupItem)) remove_tree(backup.UTF8String);
    if (resulting) *resulting = original;
    return YES;
}

/* ---- working directory, file system representation ---- */
- (NSString *)currentDirectoryPath { char buf[4096]; return getcwd(buf, sizeof buf) ? @(buf) : @""; }
- (BOOL)changeCurrentDirectoryPath:(NSString *)p { return p && chdir(p.UTF8String) == 0; }
- (const char *)fileSystemRepresentationWithPath:(NSString *)p { return p.fileSystemRepresentation; }
- (NSString *)stringWithFileSystemRepresentation:(const char *)str length:(NSUInteger)len {
    return [[NSString alloc] initWithBytes:str length:len encoding:NSUTF8StringEncoding] ?: @"";
}
@end

/* ---------------- NSDirectoryEnumerator ---------------- */
/* a depth-first, pre-order walk (entries of each directory sorted by name); symbolic links are returned, never
 * followed. A directory's contents are read on the nextObject call after it is returned, so skipDescendants works. */
@interface IsimDirFrame : NSObject { @public NSString *abs, *rel; NSArray<NSString *> *names; NSUInteger idx, level; }
@end
@implementation IsimDirFrame
@end
@implementation NSDirectoryEnumerator {
    NSString *_root; BOOL _urls; NSDirectoryEnumerationOptions _opts; BOOL (^_handler)(NSURL *, NSError *);
    NSMutableArray<IsimDirFrame *> *_stack;
    NSString *_currentAbs, *_pendingAbs, *_pendingRel; NSUInteger _pendingLevel, _level;
    BOOL _postOrder, _done;
    id _last;                                           /* the object fast enumeration handed out */
}
- (instancetype)initWithIsimRoot:(NSString *)root URLs:(BOOL)urls options:(NSDirectoryEnumerationOptions)opts errorHandler:(BOOL (^)(NSURL *, NSError *))h {
    if (!(self = [super init])) return nil;
    _root = [root copy]; _urls = urls; _opts = opts; _handler = [h copy];
    _stack = [NSMutableArray array];
    _pendingAbs = _root; _pendingRel = @""; _pendingLevel = 1;     /* the root's contents, read on the first nextObject */
    return self;
}
- (id)objectForAbs:(NSString *)abs rel:(NSString *)rel isDir:(BOOL)dir {
    return _urls ? [NSURL fileURLWithPath:abs isDirectory:dir] : rel;
}
/* reads the pending directory; NO when the error handler stops the walk */
- (BOOL)descend {
    NSString *abs = _pendingAbs; _pendingAbs = nil;
    int e = 0;
    NSArray *names = listing(abs, _opts, &e);
    if (!names) {
        BOOL go = YES;
        if (_urls && _handler) go = _handler([NSURL fileURLWithPath:abs isDirectory:YES], read_error(abs, e));
        return go;
    }
    IsimDirFrame *f = [IsimDirFrame new];
    f->abs = abs; f->rel = _pendingRel; f->names = names; f->level = _pendingLevel;
    [_stack addObject:f];
    return YES;
}
- (id)nextObject {
    if (_done) return nil;
    if (_pendingAbs && ![self descend]) { _done = YES; [_stack removeAllObjects]; return nil; }
    while (_stack.count) {
        IsimDirFrame *f = _stack.lastObject;
        if (f->idx < f->names.count) {
            NSString *name = f->names[f->idx++];
            NSString *abs = [f->abs stringByAppendingPathComponent:name], *rel = f->rel.length ? [f->rel stringByAppendingPathComponent:name] : name;
            BOOL dir = is_dir_at(abs);
            _currentAbs = abs; _level = f->level; _postOrder = NO;
            BOOL deep = dir && !(_opts & NSDirectoryEnumerationSkipsSubdirectoryDescendants) &&
                        !((_opts & NSDirectoryEnumerationSkipsPackageDescendants) && isim_is_package_path(abs));
            if (deep) { _pendingAbs = abs; _pendingRel = rel; _pendingLevel = f->level + 1; }
            return [self objectForAbs:abs rel:rel isDir:dir];
        }
        [_stack removeLastObject];
        if (f->level > 1 && (_opts & NSDirectoryEnumerationIncludesDirectoriesPostOrder)) {
            _currentAbs = f->abs; _level = f->level - 1; _postOrder = YES;
            return [self objectForAbs:f->abs rel:f->rel isDir:YES];
        }
    }
    _done = YES; _currentAbs = nil;
    return nil;
}
/* one object per call, so a for-in body sees the enumerator's state for that object (skipDescendants, level, ...) */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    state->mutationsPtr = &state->extra[0];
    if (!len || !(_last = [self nextObject])) return 0;
    buffer[0] = _last; state->itemsPtr = buffer;
    return 1;
}
- (NSDictionary<NSFileAttributeKey, id> *)fileAttributes { return _currentAbs ? [NSFileManager.defaultManager attributesOfItemAtPath:_currentAbs error:NULL] : nil; }
- (NSDictionary<NSFileAttributeKey, id> *)directoryAttributes { return [NSFileManager.defaultManager attributesOfItemAtPath:_root error:NULL]; }
- (BOOL)isEnumeratingDirectoryPostOrder { return _postOrder; }
- (void)skipDescendants { if (!_postOrder) _pendingAbs = nil; }
- (void)skipDescendents { [self skipDescendants]; }
- (NSUInteger)level { return _level; }
@end

/* ---------------- file attribute keys and NSDictionary (NSFileAttributes) ---------------- */
NSFileAttributeKey const NSFileType = @"NSFileType", NSFileSize = @"NSFileSize", NSFileModificationDate = @"NSFileModificationDate",
    NSFileReferenceCount = @"NSFileReferenceCount", NSFileDeviceIdentifier = @"NSFileDeviceIdentifier",
    NSFileOwnerAccountName = @"NSFileOwnerAccountName", NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName",
    NSFilePosixPermissions = @"NSFilePosixPermissions", NSFileSystemNumber = @"NSFileSystemNumber",
    NSFileSystemFileNumber = @"NSFileSystemFileNumber", NSFileExtensionHidden = @"NSFileExtensionHidden",
    NSFileHFSCreatorCode = @"NSFileHFSCreatorCode", NSFileHFSTypeCode = @"NSFileHFSTypeCode", NSFileImmutable = @"NSFileImmutable",
    NSFileAppendOnly = @"NSFileAppendOnly", NSFileCreationDate = @"NSFileCreationDate", NSFileOwnerAccountID = @"NSFileOwnerAccountID",
    NSFileGroupOwnerAccountID = @"NSFileGroupOwnerAccountID", NSFileBusy = @"NSFileBusy", NSFileProtectionKey = @"NSFileProtectionKey",
    NSFileSystemSize = @"NSFileSystemSize", NSFileSystemFreeSize = @"NSFileSystemFreeSize", NSFileSystemNodes = @"NSFileSystemNodes",
    NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";
NSFileAttributeType const NSFileTypeDirectory = @"NSFileTypeDirectory", NSFileTypeRegular = @"NSFileTypeRegular",
    NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink", NSFileTypeSocket = @"NSFileTypeSocket",
    NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial", NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial",
    NSFileTypeUnknown = @"NSFileTypeUnknown";
NSFileProtectionType const NSFileProtectionNone = @"NSFileProtectionNone", NSFileProtectionComplete = @"NSFileProtectionComplete",
    NSFileProtectionCompleteUnlessOpen = @"NSFileProtectionCompleteUnlessOpen",
    NSFileProtectionCompleteUntilFirstUserAuthentication = @"NSFileProtectionCompleteUntilFirstUserAuthentication";

@implementation NSDictionary (NSFileAttributes)
- (unsigned long long)fileSize { return [self[NSFileSize] unsignedLongLongValue]; }
- (NSDate *)fileModificationDate { return self[NSFileModificationDate]; }
- (NSString *)fileType { return self[NSFileType]; }
- (NSUInteger)filePosixPermissions { return [self[NSFilePosixPermissions] unsignedIntegerValue]; }
- (NSString *)fileOwnerAccountName { return self[NSFileOwnerAccountName]; }
- (NSString *)fileGroupOwnerAccountName { return self[NSFileGroupOwnerAccountName]; }
- (NSInteger)fileSystemNumber { return [self[NSFileSystemNumber] integerValue]; }
- (NSUInteger)fileSystemFileNumber { return [self[NSFileSystemFileNumber] unsignedIntegerValue]; }
- (BOOL)fileExtensionHidden { return [self[NSFileExtensionHidden] boolValue]; }
- (BOOL)fileIsImmutable { return [self[NSFileImmutable] boolValue]; }
- (BOOL)fileIsAppendOnly { return [self[NSFileAppendOnly] boolValue]; }
- (NSDate *)fileCreationDate { return self[NSFileCreationDate]; }
- (NSNumber *)fileOwnerAccountID { return self[NSFileOwnerAccountID]; }
- (NSNumber *)fileGroupOwnerAccountID { return self[NSFileGroupOwnerAccountID]; }
@end

/* ---------------- NSURL resource values ---------------- */
NSURLResourceKey const NSURLNameKey = @"NSURLNameKey", NSURLLocalizedNameKey = @"NSURLLocalizedNameKey", NSURLPathKey = @"_NSURLPathKey",
    NSURLParentDirectoryURLKey = @"NSURLParentDirectoryURLKey", NSURLIsRegularFileKey = @"NSURLIsRegularFileKey",
    NSURLIsDirectoryKey = @"NSURLIsDirectoryKey", NSURLIsSymbolicLinkKey = @"NSURLIsSymbolicLinkKey", NSURLIsPackageKey = @"NSURLIsPackageKey",
    NSURLIsHiddenKey = @"NSURLIsHiddenKey", NSURLIsReadableKey = @"NSURLIsReadableKey", NSURLIsWritableKey = @"NSURLIsWritableKey",
    NSURLIsExecutableKey = @"NSURLIsExecutableKey", NSURLFileResourceTypeKey = @"NSURLFileResourceTypeKey", NSURLFileSizeKey = @"NSURLFileSizeKey",
    NSURLTotalFileSizeKey = @"NSURLTotalFileSizeKey", NSURLFileAllocatedSizeKey = @"NSURLFileAllocatedSizeKey",
    NSURLTotalFileAllocatedSizeKey = @"NSURLTotalFileAllocatedSizeKey", NSURLLinkCountKey = @"NSURLLinkCountKey",
    NSURLCreationDateKey = @"NSURLCreationDateKey", NSURLContentModificationDateKey = @"NSURLContentModificationDateKey",
    NSURLContentAccessDateKey = @"NSURLContentAccessDateKey", NSURLAttributeModificationDateKey = @"NSURLAttributeModificationDateKey";
NSURLFileResourceType const NSURLFileResourceTypeNamedPipe = @"NSURLFileResourceTypeNamedPipe",
    NSURLFileResourceTypeCharacterSpecial = @"NSURLFileResourceTypeCharacterSpecial", NSURLFileResourceTypeDirectory = @"NSURLFileResourceTypeDirectory",
    NSURLFileResourceTypeBlockSpecial = @"NSURLFileResourceTypeBlockSpecial", NSURLFileResourceTypeRegular = @"NSURLFileResourceTypeRegular",
    NSURLFileResourceTypeSymbolicLink = @"NSURLFileResourceTypeSymbolicLink", NSURLFileResourceTypeSocket = @"NSURLFileResourceTypeSocket",
    NSURLFileResourceTypeUnknown = @"NSURLFileResourceTypeUnknown";

/* adapted: from lstat (a symbolic link's own values, like iOS) and access(2). Sizes are left out for directories. */
@implementation NSURL (NSURLResourceValues)
- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)err {
    if (!self.isFileURL) {                              /* NSFileReadUnsupportedSchemeError */
        if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:262 userInfo:@{ NSURLErrorKey: self }];
        return nil;
    }
    NSString *p = self.path;
    struct stat st;
    if (lstat(p.UTF8String, &st) != 0) {
        int e = errno;
        if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:e == ENOENT || e == ENOTDIR ? 260 : e == EACCES ? 257 : 256
                                        userInfo:@{ @"NSFilePath": p, NSURLErrorKey: self, NSUnderlyingErrorKey: [NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil] }];
        return nil;
    }
    mode_t type = st.st_mode & S_IFMT;
    BOOL dir = type == S_IFDIR;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSURLResourceKey k in keys) {
        id v = nil;
        if ([k isEqualToString:NSURLNameKey] || [k isEqualToString:NSURLLocalizedNameKey]) v = p.lastPathComponent;
        else if ([k isEqualToString:NSURLPathKey]) v = p;
        else if ([k isEqualToString:NSURLParentDirectoryURLKey]) v = [p isEqualToString:@"/"] ? nil : [NSURL fileURLWithPath:p.stringByDeletingLastPathComponent isDirectory:YES];
        else if ([k isEqualToString:NSURLIsRegularFileKey]) v = @(type == S_IFREG);
        else if ([k isEqualToString:NSURLIsDirectoryKey]) v = @(dir);
        else if ([k isEqualToString:NSURLIsSymbolicLinkKey]) v = @(type == S_IFLNK);
        else if ([k isEqualToString:NSURLIsPackageKey]) v = @(dir && isim_is_package_path(p));
        else if ([k isEqualToString:NSURLIsHiddenKey]) v = @([p.lastPathComponent hasPrefix:@"."]);
        else if ([k isEqualToString:NSURLIsReadableKey]) v = @(access(p.UTF8String, R_OK) == 0);
        else if ([k isEqualToString:NSURLIsWritableKey]) v = @(access(p.UTF8String, W_OK) == 0);
        else if ([k isEqualToString:NSURLIsExecutableKey]) v = @(access(p.UTF8String, X_OK) == 0);
        else if ([k isEqualToString:NSURLFileResourceTypeKey])
            v = type == S_IFREG ? NSURLFileResourceTypeRegular : dir ? NSURLFileResourceTypeDirectory : type == S_IFLNK ? NSURLFileResourceTypeSymbolicLink :
                type == S_IFIFO ? NSURLFileResourceTypeNamedPipe : type == S_IFCHR ? NSURLFileResourceTypeCharacterSpecial :
                type == S_IFBLK ? NSURLFileResourceTypeBlockSpecial : type == S_IFSOCK ? NSURLFileResourceTypeSocket : NSURLFileResourceTypeUnknown;
        else if ([k isEqualToString:NSURLFileSizeKey] || [k isEqualToString:NSURLTotalFileSizeKey]) v = dir ? nil : @((long long)st.st_size);
        else if ([k isEqualToString:NSURLFileAllocatedSizeKey] || [k isEqualToString:NSURLTotalFileAllocatedSizeKey]) v = dir ? nil : @((long long)st.st_blocks * 512);
        else if ([k isEqualToString:NSURLLinkCountKey]) v = @((long)st.st_nlink);
        else if ([k isEqualToString:NSURLCreationDateKey]) v = date_of(st.st_birthtimespec);
        else if ([k isEqualToString:NSURLContentModificationDateKey]) v = date_of(st.st_mtimespec);
        else if ([k isEqualToString:NSURLContentAccessDateKey]) v = date_of(st.st_atimespec);
        else if ([k isEqualToString:NSURLAttributeModificationDateKey]) v = date_of(st.st_ctimespec);
        if (v) out[k] = v;
    }
    return [out copy];
}
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)err {
    NSDictionary *d = key ? [self resourceValuesForKeys:@[key] error:err] : nil;
    *value = d[key];
    return d != nil;
}
/* the real path when the file exists (iOS also drops /private from /private/var paths; Linux has none) */
- (NSURL *)URLByResolvingSymlinksInPath {
    if (!self.isFileURL) return self;
    char buf[4096];
    return realpath(self.path.UTF8String, buf) ? [NSURL fileURLWithPath:@(buf) isDirectory:[self.absoluteString hasSuffix:@"/"]] : self;
}
@end

@implementation NSString (NSStringPathExtensions)
- (const char *)fileSystemRepresentation { return self.UTF8String; }
- (BOOL)getFileSystemRepresentation:(char *)buf maxLength:(NSUInteger)max {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    if (!buf || n + 1 > max || memchr(b, 0, n)) return NO;
    memcpy(buf, b, n); buf[n] = 0;
    return YES;
}
/* each existing component resolved with realpath(3); a path that does not exist comes back standardized */
- (NSString *)stringByResolvingSymlinksInPath {
    NSString *p = self.stringByExpandingTildeInPath;
    char buf[4096];
    if ([p hasPrefix:@"/"] && realpath(p.UTF8String, buf)) return @(buf);
    return p.stringByStandardizingPath;
}
@end

NSString *isim_plist_xml(id root) { return isim_plist_write_xml(root); }

@implementation NSString (IsimPad)
- (NSString *)stringByPaddingToLength_isim:(NSUInteger)n { NSMutableString *s = [NSMutableString string]; for (NSUInteger i = 0; i < n; i++) [s appendString:@"\t"]; return s; }
@end
