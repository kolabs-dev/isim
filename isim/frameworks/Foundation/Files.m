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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
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

@implementation NSFileManager
+ (NSFileManager *)defaultManager { static NSFileManager *m; if (!m) m = [NSFileManager new]; return m; }
- (BOOL)fileExistsAtPath:(NSString *)p { return access(p.UTF8String, F_OK) == 0; }
- (BOOL)fileExistsAtPath:(NSString *)p isDirectory:(BOOL *)isDir {
    if (access(p.UTF8String, F_OK) != 0) return NO;
    if (isDir) { int fd = open([p stringByAppendingString:@"/."].UTF8String, O_RDONLY); *isDir = fd >= 0; if (fd >= 0) close(fd); }
    return YES;
}
- (BOOL)createDirectoryAtPath:(NSString *)p withIntermediateDirectories:(BOOL)inter attributes:(id)a error:(id *)err {
    if (inter) mkdirs(p); else mkdir(p.UTF8String, 0755);
    return access(p.UTF8String, F_OK) == 0;
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
@end

/* ---------------- property list writer (XML) ---------------- */
static void xml_escape(NSMutableString *out, NSString *s) {
    NSString *e = [[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    [out appendString:e];
}
static void plist_write(NSMutableString *out, id v, int depth) {
    NSString *ind = [@"" stringByPaddingToLength_isim:(NSUInteger)depth];
    if ([v isKindOfClass:[NSString class]]) { [out appendFormat:@"%@<string>", ind]; xml_escape(out, v); [out appendString:@"</string>\n"]; }
    else if ([v isKindOfClass:[NSNumber class]]) {
        NSNumber *n = v; double d = n.doubleValue;
        const char *desc = [[n description] UTF8String];
        BOOL isBool = [n respondsToSelector:@selector(_isim_isBool)] && ((BOOL (*)(id, SEL))[n methodForSelector:@selector(_isim_isBool)])(n, @selector(_isim_isBool));
        if (isBool) [out appendFormat:@"%@<%@/>\n", ind, n.boolValue ? @"true" : @"false"];
        else if (strchr(desc, '.') || strchr(desc, 'e')) [out appendFormat:@"%@<real>%.17g</real>\n", ind, d];
        else [out appendFormat:@"%@<integer>%lld</integer>\n", ind, n.longLongValue];
    } else if ([v isKindOfClass:[NSDate class]]) [out appendFormat:@"%@<date>%@</date>\n", ind, [v description]];
    else if ([v isKindOfClass:[NSArray class]]) {
        [out appendFormat:@"%@<array>\n", ind];
        for (id x in v) plist_write(out, x, depth + 1);
        [out appendFormat:@"%@</array>\n", ind];
    } else if ([v isKindOfClass:[NSDictionary class]]) {
        [out appendFormat:@"%@<dict>\n", ind];
        NSArray *keys = [[v allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *k in keys) { [out appendFormat:@"%@\t<key>", ind]; xml_escape(out, k); [out appendString:@"</key>\n"]; plist_write(out, v[k], depth + 1); }
        [out appendFormat:@"%@</dict>\n", ind];
    }
}
NSString *isim_plist_xml(id root) { return isim_plist_write_xml(root); }

@implementation NSString (IsimPad)
- (NSString *)stringByPaddingToLength_isim:(NSUInteger)n { NSMutableString *s = [NSMutableString string]; for (NSUInteger i = 0; i < n; i++) [s appendString:@"\t"]; return s; }
@end
