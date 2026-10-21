// isim CoreFoundation: CFURL (toll-free bridged: a CFURLRef is the NSURL) and the CFBundle resource, localization and
// executable functions (a CFBundleRef is the NSBundle), over Foundation. Allocators are accepted and ignored.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

/* NSURL's own (Additions.m, not in isim's header; isim resolves a relative URL when it is made, so it has no base) */
@interface NSURL (IsimCFURL)
@property (readonly, copy) NSURL *absoluteURL;
@property (readonly, copy) NSURL *baseURL;
@property (readonly, copy) NSString *password, *relativePath, *resourceSpecifier;
@property (readonly) BOOL hasDirectoryPath;
@property (readonly, copy) NSURL *URLByDeletingLastPathComponent, *URLByDeletingPathExtension;
- (BOOL)checkResourceIsReachableAndReturnError:(NSError **)error;
@end

#define URL(u) ((__bridge NSURL *)(u))
#define STR(s) ((__bridge NSString *)(s))
static CFURLRef ret_url(NSURL *u) { return u ? (__bridge_retained CFURLRef)u : NULL; }
static CFStringRef ret_str(NSString *s) { return s ? (__bridge_retained CFStringRef)[s copy] : NULL; }

/* ================= CFURL ================= */
CFTypeID CFURLGetTypeID(void) { return 29; }
CFURLRef CFURLCreateWithString(CFAllocatorRef a, CFStringRef string, CFURLRef base) {
    if (!string) return NULL;
    return ret_url([NSURL URLWithString:STR(string) relativeToURL:URL(base)]);
}
CFURLRef CFURLCreateWithBytes(CFAllocatorRef a, const UInt8 *bytes, CFIndex length, CFStringEncoding encoding, CFURLRef base) {
    if (!bytes) return NULL;
    NSString *s = [[NSString alloc] initWithBytes:bytes length:(NSUInteger)length encoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
    return s ? ret_url([NSURL URLWithString:s relativeToURL:URL(base)]) : NULL;
}
CFURLRef CFURLCreateAbsoluteURLWithBytes(CFAllocatorRef a, const UInt8 *bytes, CFIndex length, CFStringEncoding encoding, CFURLRef base, Boolean compat) {
    CFURLRef rel = CFURLCreateWithBytes(a, bytes, length, encoding, base);
    if (!rel) return NULL;
    NSURL *abs = URL(rel).absoluteURL;
    CFRelease(rel);
    return ret_url(abs);
}
/* POSIX paths (the only style on iOS; HFS and Windows paths are taken as POSIX paths) */
CFURLRef CFURLCreateWithFileSystemPath(CFAllocatorRef a, CFStringRef path, CFURLPathStyle style, Boolean isDirectory) {
    if (!path) return NULL;
    return ret_url([NSURL fileURLWithPath:STR(path) isDirectory:isDirectory]);
}
CFURLRef CFURLCreateWithFileSystemPathRelativeToBase(CFAllocatorRef a, CFStringRef path, CFURLPathStyle style, Boolean isDirectory, CFURLRef base) {
    if (!path) return NULL;
    NSString *p = STR(path);
    if (base && !p.isAbsolutePath) p = [URL(base).path stringByAppendingPathComponent:p];
    return ret_url([NSURL fileURLWithPath:p isDirectory:isDirectory]);
}
CFURLRef CFURLCreateFromFileSystemRepresentation(CFAllocatorRef a, const UInt8 *buffer, CFIndex length, Boolean isDirectory) {
    if (!buffer) return NULL;
    NSString *path = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)length encoding:NSUTF8StringEncoding];
    return path ? ret_url([NSURL fileURLWithPath:path isDirectory:isDirectory]) : NULL;
}
Boolean CFURLGetFileSystemRepresentation(CFURLRef url, Boolean resolveAgainstBase, UInt8 *buffer, CFIndex max) {
    NSURL *u = resolveAgainstBase ? URL(url).absoluteURL : URL(url);
    NSString *path = u.isFileURL || !u.scheme ? (resolveAgainstBase ? u.path : (u.relativePath ?: u.path)) : nil;
    const char *c = path.fileSystemRepresentation;
    if (!c || !buffer || (CFIndex)strlen(c) + 1 > max) return false;
    memcpy(buffer, c, strlen(c) + 1);
    return true;
}
CFDataRef CFURLCreateData(CFAllocatorRef a, CFURLRef url, CFStringEncoding encoding, Boolean escapeWhitespace) {
    NSData *d = [URL(url).relativeString dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
    return d ? (__bridge_retained CFDataRef)d : NULL;
}
CFURLRef CFURLCopyAbsoluteURL(CFURLRef url) { return ret_url(URL(url).absoluteURL); }
CFStringRef CFURLGetString(CFURLRef url) { return (__bridge CFStringRef)URL(url).relativeString; }
CFURLRef CFURLGetBaseURL(CFURLRef url) { return (__bridge CFURLRef)URL(url).baseURL; }      /* adapted: always NULL */
/* a URL decomposes when it follows RFC 1808's generic syntax: no scheme, or a scheme followed by "//" or "/" */
Boolean CFURLCanBeDecomposed(CFURLRef url) {
    NSURL *u = URL(url).absoluteURL;
    if (!u.scheme) return true;
    NSString *rest = [u.absoluteString substringFromIndex:u.scheme.length + 1];
    return [rest hasPrefix:@"/"];
}
CFStringRef CFURLCopyScheme(CFURLRef url) { return ret_str(URL(url).absoluteURL.scheme); }
CFStringRef CFURLCopyNetLocation(CFURLRef url) {
    NSURLComponents *c = [NSURLComponents componentsWithURL:URL(url).absoluteURL resolvingAgainstBaseURL:YES];
    if (!c.percentEncodedHost) return NULL;
    NSMutableString *s = [NSMutableString string];
    if (c.percentEncodedUser) { [s appendString:c.percentEncodedUser]; if (c.percentEncodedPassword) [s appendFormat:@":%@", c.percentEncodedPassword]; [s appendString:@"@"]; }
    [s appendString:c.percentEncodedHost];
    if (c.port) [s appendFormat:@":%@", c.port];
    return ret_str(s);
}
/* the path, still percent-encoded (like CFURLCopyPath; NSURL's path decodes it) */
CFStringRef CFURLCopyPath(CFURLRef url) {
    NSURLComponents *c = [NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:NO];
    return ret_str(c ? c.percentEncodedPath : URL(url).relativePath);
}
CFStringRef CFURLCopyStrictPath(CFURLRef url, Boolean *isAbsolute) {
    NSString *p = [NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:NO].percentEncodedPath ?: @"";
    if (isAbsolute) *isAbsolute = [p hasPrefix:@"/"];
    if ([p hasPrefix:@"/"]) p = [p substringFromIndex:1];
    return ret_str(p);
}
CFStringRef CFURLCopyFileSystemPath(CFURLRef url, CFURLPathStyle style) {
    NSURL *u = URL(url);
    NSString *p = u.baseURL ? u.relativePath : u.path;
    if (p.length > 1 && [p hasSuffix:@"/"]) p = [p substringToIndex:p.length - 1];
    return ret_str(p);
}
Boolean CFURLHasDirectoryPath(CFURLRef url) {          /* the path (not the query or fragment) ends in "/" */
    NSString *p = [NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:YES].percentEncodedPath;
    return p ? [p hasSuffix:@"/"] : URL(url).hasDirectoryPath;
}
CFStringRef CFURLCopyResourceSpecifier(CFURLRef url) {
    NSURL *u = URL(url);
    if (!CFURLCanBeDecomposed(url)) return ret_str(u.resourceSpecifier);
    NSURLComponents *c = [NSURLComponents componentsWithURL:u resolvingAgainstBaseURL:NO];
    NSMutableString *s = [NSMutableString string];
    if (c.percentEncodedQuery) [s appendFormat:@"?%@", c.percentEncodedQuery];
    if (c.percentEncodedFragment) [s appendFormat:@"#%@", c.percentEncodedFragment];
    return s.length ? ret_str(s) : NULL;
}
CFStringRef CFURLCopyHostName(CFURLRef url) { return ret_str(URL(url).absoluteURL.host); }
SInt32 CFURLGetPortNumber(CFURLRef url) { NSNumber *p = URL(url).absoluteURL.port; return p ? p.intValue : -1; }
CFStringRef CFURLCopyUserName(CFURLRef url) { return ret_str([NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:YES].user); }
CFStringRef CFURLCopyPassword(CFURLRef url) { return ret_str([NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:YES].password); }
/* charactersToLeaveEscaped NULL: the part as it is in the URL; otherwise it is unescaped except for those characters */
static CFStringRef unescape_part(NSString *part, CFStringRef keep) {
    if (!part) return NULL;
    if (!keep) return ret_str(part);
    return CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)part, keep);
}
CFStringRef CFURLCopyQueryString(CFURLRef url, CFStringRef keep) {
    return unescape_part([NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:NO].percentEncodedQuery, keep);
}
CFStringRef CFURLCopyFragment(CFURLRef url, CFStringRef keep) {
    return unescape_part([NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:NO].percentEncodedFragment, keep);
}
CFStringRef CFURLCopyLastPathComponent(CFURLRef url) { return ret_str(URL(url).lastPathComponent ?: @""); }
CFStringRef CFURLCopyPathExtension(CFURLRef url) { NSString *e = URL(url).pathExtension; return e.length ? ret_str(e) : NULL; }
/* the URL with another (percent-encoded) path; the rest (query, fragment) is kept */
static CFURLRef with_path(CFURLRef url, NSString *(^change)(NSString *path)) {
    NSURLComponents *c = [NSURLComponents componentsWithURL:URL(url) resolvingAgainstBaseURL:YES];
    if (!c) return NULL;
    c.percentEncodedPath = change(c.percentEncodedPath ?: @"");
    return ret_url(c.URL);
}
static NSString *encode_component(NSString *s) {          /* a path component: "/" escaped too */
    NSString *e = [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] ?: s;
    return [e stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
}
CFURLRef CFURLCreateCopyAppendingPathComponent(CFAllocatorRef a, CFURLRef url, CFStringRef component, Boolean isDirectory) {
    if (!url || !component) return NULL;
    if (URL(url).isFileURL) return ret_url([URL(url) URLByAppendingPathComponent:STR(component) isDirectory:isDirectory]);
    return with_path(url, ^NSString *(NSString *p) {
        NSString *base = [p hasSuffix:@"/"] ? p : [p stringByAppendingString:@"/"];
        return [[base stringByAppendingString:encode_component(STR(component))] stringByAppendingString:isDirectory ? @"/" : @""];
    });
}
CFURLRef CFURLCreateCopyDeletingLastPathComponent(CFAllocatorRef a, CFURLRef url) {
    return with_path(url, ^NSString *(NSString *p) {
        NSString *trimmed = p.length > 1 && [p hasSuffix:@"/"] ? [p substringToIndex:p.length - 1] : p;
        NSRange slash = [trimmed rangeOfString:@"/" options:NSBackwardsSearch];
        return slash.location == NSNotFound ? @"./" : [trimmed substringToIndex:slash.location + 1];
    });
}
CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef a, CFURLRef url, CFStringRef ext) {
    if (!ext) return NULL;
    return with_path(url, ^NSString *(NSString *p) {
        BOOL dir = p.length > 1 && [p hasSuffix:@"/"];
        NSString *core = dir ? [p substringToIndex:p.length - 1] : p;
        return [[core stringByAppendingFormat:@".%@", encode_component(STR(ext))] stringByAppendingString:dir ? @"/" : @""];
    });
}
CFURLRef CFURLCreateCopyDeletingPathExtension(CFAllocatorRef a, CFURLRef url) {
    return with_path(url, ^NSString *(NSString *p) {
        BOOL dir = p.length > 1 && [p hasSuffix:@"/"];
        NSString *core = dir ? [p substringToIndex:p.length - 1] : p;
        NSRange dot = [core rangeOfString:@"." options:NSBackwardsSearch], slash = [core rangeOfString:@"/" options:NSBackwardsSearch];
        if (dot.location != NSNotFound && (slash.location == NSNotFound || dot.location > slash.location + 1)) core = [core substringToIndex:dot.location];
        return [core stringByAppendingString:dir ? @"/" : @""];
    });
}
/* %XX escapes become their UTF-8 characters, except the characters in charactersToLeaveEscaped; NULL if an escape is
   malformed or the escapes are not UTF-8 */
static int hex_value(unichar c) {
    return c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
}
CFStringRef CFURLCreateStringByReplacingPercentEscapes(CFAllocatorRef a, CFStringRef original, CFStringRef keep) {
    NSString *s = STR(original), *k = keep ? STR(keep) : @"";
    if (!s) return NULL;
    NSMutableString *out = [NSMutableString string];
    NSUInteger i = 0, n = s.length;
    while (i < n) {
        unichar ch = [s characterAtIndex:i];
        if (ch != '%') { [out appendFormat:@"%C", ch]; i++; continue; }
        NSMutableData *bytes = [NSMutableData data];
        NSUInteger j = i;
        while (j + 2 < n && [s characterAtIndex:j] == '%') {           /* a run of escapes: one UTF-8 sequence or more */
            int hi = hex_value([s characterAtIndex:j + 1]), lo = hex_value([s characterAtIndex:j + 2]);
            if (hi < 0 || lo < 0) break;
            uint8_t b = (uint8_t)(hi * 16 + lo);
            [bytes appendBytes:&b length:1];
            j += 3;
        }
        if (!bytes.length) return NULL;
        NSString *decoded = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        if (!decoded) return NULL;
        NSUInteger pos = i;                                             /* characters to keep stay as their escapes */
        for (NSUInteger c = 0; c < decoded.length;) {
            NSRange r = [decoded rangeOfComposedCharacterSequenceAtIndex:c];
            NSString *one = [decoded substringWithRange:r];
            NSUInteger len = [one lengthOfBytesUsingEncoding:NSUTF8StringEncoding] * 3;
            [out appendString:[k rangeOfString:one].location != NSNotFound ? [s substringWithRange:NSMakeRange(pos, len)] : one];
            pos += len; c = NSMaxRange(r);
        }
        i = j;
    }
    return ret_str(out);
}
Boolean CFURLResourceIsReachable(CFURLRef url, CFErrorRef *error) {
    NSError *e = nil;
    BOOL ok = [URL(url) checkResourceIsReachableAndReturnError:&e];
    if (!ok && error) *error = (__bridge_retained CFErrorRef)e;
    return ok;
}
CFURLRef CFURLCreateFilePathURL(CFAllocatorRef a, CFURLRef url, CFErrorRef *error) {
    NSURL *u = URL(url);
    if (!u.isFileURL) {
        if (error) *error = (__bridge_retained CFErrorRef)[NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnsupportedSchemeError userInfo:nil];
        return NULL;
    }
    return ret_url([NSURL fileURLWithPath:u.path isDirectory:u.hasDirectoryPath]);
}
/* isim (adapted): file reference URLs are path URLs, like on iOS since file references are not kept across launches */
CFURLRef CFURLCreateFileReferenceURL(CFAllocatorRef a, CFURLRef url, CFErrorRef *error) { return CFURLCreateFilePathURL(a, url, error); }

/* ================= CFBundle (resources, localizations, executable) ================= */
#define BUNDLE(b) ((__bridge NSBundle *)(b))
CFTypeID CFBundleGetTypeID(void) { return 31; }
CFBundleRef CFBundleCreate(CFAllocatorRef a, CFURLRef url) {
    NSBundle *b = url ? [NSBundle bundleWithPath:URL(url).path] : nil;
    return b ? (__bridge_retained CFBundleRef)b : NULL;
}
CFArrayRef CFBundleGetAllBundles(void) {
    static NSArray *all;
    all = [NSBundle.allBundles arrayByAddingObjectsFromArray:NSBundle.allFrameworks];
    return (__bridge CFArrayRef)all;
}
static CFURLRef ret_dir(NSString *path) { return path ? ret_url([NSURL fileURLWithPath:path isDirectory:YES]) : NULL; }
static CFURLRef ret_file(NSString *path) { return path ? ret_url([NSURL fileURLWithPath:path]) : NULL; }
CFURLRef CFBundleCopyBundleURL(CFBundleRef b) { return ret_dir(BUNDLE(b).bundlePath); }
CFURLRef CFBundleCopyResourcesDirectoryURL(CFBundleRef b) { return ret_dir(BUNDLE(b).resourcePath); }
CFURLRef CFBundleCopyExecutableURL(CFBundleRef b) { return ret_file(BUNDLE(b).executablePath); }
CFURLRef CFBundleCopyBuiltInPlugInsURL(CFBundleRef b) { return ret_dir(BUNDLE(b).builtInPlugInsPath); }
CFURLRef CFBundleCopyPrivateFrameworksURL(CFBundleRef b) { return ret_dir(BUNDLE(b).privateFrameworksPath); }
CFURLRef CFBundleCopySharedFrameworksURL(CFBundleRef b) { return ret_dir(BUNDLE(b).sharedFrameworksPath); }
CFURLRef CFBundleCopySharedSupportURL(CFBundleRef b) { return ret_dir([BUNDLE(b).bundlePath stringByAppendingPathComponent:@"SharedSupport"]); }
CFURLRef CFBundleCopySupportFilesDirectoryURL(CFBundleRef b) { return ret_dir(BUNDLE(b).bundlePath); }   /* iOS bundles are flat */
CFURLRef CFBundleCopyResourceURL(CFBundleRef b, CFStringRef name, CFStringRef type, CFStringRef subdir) {
    return ret_file([BUNDLE(b) pathForResource:STR(name) ofType:STR(type) inDirectory:STR(subdir) forLocalization:nil]);
}
CFURLRef CFBundleCopyResourceURLForLocalization(CFBundleRef b, CFStringRef name, CFStringRef type, CFStringRef subdir, CFStringRef loc) {
    return ret_file([BUNDLE(b) pathForResource:STR(name) ofType:STR(type) inDirectory:STR(subdir) forLocalization:STR(loc)]);
}
CFURLRef CFBundleCopyResourceURLInDirectory(CFURLRef bundleURL, CFStringRef name, CFStringRef type, CFStringRef subdir) {
    NSBundle *b = bundleURL ? [NSBundle bundleWithPath:URL(bundleURL).path] : nil;
    return ret_file([b pathForResource:STR(name) ofType:STR(type) inDirectory:STR(subdir) forLocalization:nil]);
}
/* the resources of a type: those in the resources directory (or its subdirectory), then those of the preferred
   localization (its .lproj) that are not there */
CFArrayRef CFBundleCopyResourceURLsOfType(CFBundleRef b, CFStringRef type, CFStringRef subdir) {
    NSBundle *bundle = BUNDLE(b);
    NSString *root = bundle.resourcePath ?: bundle.bundlePath, *ext = STR(type);
    if (subdir) root = [root stringByAppendingPathComponent:STR(subdir)];
    NSMutableArray *urls = [NSMutableArray array];
    NSMutableSet *names = [NSMutableSet set];
    NSString *lproj = bundle.preferredLocalizations.firstObject;
    for (NSString *dir in @[root, lproj ? [root stringByAppendingPathComponent:[lproj stringByAppendingPathExtension:@"lproj"]] : root]) {
        NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *f in files) {
            if (ext.length && ![f.pathExtension isEqualToString:ext]) continue;
            if ([f.pathExtension isEqualToString:@"lproj"] || [names containsObject:f]) continue;
            [names addObject:f];
            [urls addObject:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:f]]];
        }
    }
    return (__bridge_retained CFArrayRef)urls;
}
CFStringRef CFBundleCopyLocalizedString(CFBundleRef b, CFStringRef key, CFStringRef value, CFStringRef table) {
    if (!key) return value ? ret_str(STR(value)) : NULL;
    return ret_str([BUNDLE(b) localizedStringForKey:STR(key) value:STR(value) table:STR(table)]);
}
CFStringRef CFBundleGetDevelopmentRegion(CFBundleRef b) {
    return (__bridge CFStringRef)([BUNDLE(b) objectForInfoDictionaryKey:@"CFBundleDevelopmentRegion"] ?: BUNDLE(b).developmentLocalization);
}
CFArrayRef CFBundleCopyBundleLocalizations(CFBundleRef b) { return (__bridge_retained CFArrayRef)(BUNDLE(b).localizations ?: @[]); }
CFArrayRef CFBundleCopyPreferredLocalizationsFromArray(CFArrayRef list) {
    return (__bridge_retained CFArrayRef)[NSBundle preferredLocalizationsFromArray:(__bridge NSArray *)list ?: @[]];
}
/* the first preference (or its language) the list has; the list's first entry when none matches */
CFArrayRef CFBundleCopyLocalizationsForPreferences(CFArrayRef list, CFArrayRef prefs) {
    NSArray<NSString *> *have = (__bridge NSArray *)list ?: @[];
    if (!prefs) return CFBundleCopyPreferredLocalizationsFromArray(list);
    for (NSString *p in (__bridge NSArray *)prefs) {
        NSString *lang = [p componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]].firstObject;
        for (NSString *l in have) if ([l isEqualToString:p]) return (__bridge_retained CFArrayRef)@[l];
        for (NSString *l in have) if ([l isEqualToString:lang]) return (__bridge_retained CFArrayRef)@[l];
    }
    return (__bridge_retained CFArrayRef)(have.count ? @[have.firstObject] : @[]);
}
CFDictionaryRef CFBundleGetLocalInfoDictionary(CFBundleRef b) { return (__bridge CFDictionaryRef)BUNDLE(b).localizedInfoDictionary; }
Boolean CFBundleIsExecutableLoaded(CFBundleRef b) { return BUNDLE(b).isLoaded; }
Boolean CFBundleLoadExecutable(CFBundleRef b) { return [BUNDLE(b) load]; }
/* a symbol of the bundle's executable (the main bundle: every image the app has loaded), loading it first */
static void *bundle_symbol(CFBundleRef b, CFStringRef name) {
    if (!b || !name) return NULL;
    NSBundle *bundle = BUNDLE(b);
    const char *sym = STR(name).UTF8String;
    if (bundle == NSBundle.mainBundle) return dlsym(RTLD_DEFAULT, sym);
    if (![bundle load] || !bundle.executablePath) return NULL;
    void *h = dlopen(bundle.executablePath.fileSystemRepresentation, RTLD_NOLOAD | RTLD_LAZY);
    void *p = h ? dlsym(h, sym) : NULL;
    if (h) dlclose(h);
    return p;
}
void *CFBundleGetFunctionPointerForName(CFBundleRef b, CFStringRef name) { return bundle_symbol(b, name); }
void *CFBundleGetDataPointerForName(CFBundleRef b, CFStringRef name) { return bundle_symbol(b, name); }
