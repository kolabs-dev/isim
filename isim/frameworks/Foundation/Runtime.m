/* isim Foundation (ARC): exceptions, bundle + plist, dates, run loop/timers, notifications,
 * process info, user defaults, libdispatch subset. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <objc/objc-exception.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <pthread.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <Block.h>
#include "isim_foundation.h"

extern int *_NSGetArgc(void);
extern char ***_NSGetArgv(void);
extern char ***_NSGetEnviron(void);
extern int _NSGetExecutablePath(char *buf, uint32_t *size);
extern long sysconf(int name);

static double wall_now(void) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
static double mono_now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
#define REF_EPOCH 978307200.0   /* 2001-01-01 relative to 1970 */

/* ================= NSException ================= */
NSExceptionName const NSGenericException = @"NSGenericException";
NSExceptionName const NSRangeException = @"NSRangeException";
NSExceptionName const NSInvalidArgumentException = @"NSInvalidArgumentException";
NSExceptionName const NSInternalInconsistencyException = @"NSInternalInconsistencyException";

@interface NSException () { @public NSArray<NSNumber *> *_isimCallStack; } @end
/* exception preprocessor (libobjc): records the throw site's return addresses (frame pointer chain) */
static id isim_exception_preprocessor(id e) {
    if ([e isKindOfClass:[NSException class]] && !((NSException *)e)->_isimCallStack) {
        NSMutableArray *a = [NSMutableArray array];
        void **fp = __builtin_frame_address(0);
        for (int i = 0; i < 128 && fp && !((uintptr_t)fp & 7); i++) {
            void **next = fp[0]; void *ret = fp[1];
            if (!ret) break;
            [a addObject:@((uintptr_t)ret)];
            if (next <= fp) break;
            fp = next;
        }
        ((NSException *)e)->_isimCallStack = [a copy];
    }
    return e;
}
static NSUncaughtExceptionHandler *uncaught_handler;
NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void) { return uncaught_handler; }
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *h) {
    uncaught_handler = h;
    objc_setUncaughtExceptionHandler((objc_uncaught_exception_handler)h);
}
__attribute__((constructor)) static void isim_install_exception_preprocessor(void) { objc_setExceptionPreprocessor(isim_exception_preprocessor); }

/* "0   Image   0x...  symbol + offset" lines, like -[NSException callStackSymbols] */
NSArray<NSString *> *isim_symbolicate(NSArray<NSNumber *> *addresses) {
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger i = 0;
    for (NSNumber *n in addresses) {
        Dl_info di; void *pc = (void *)(uintptr_t)n.unsignedLongValue;
        const char *img = "???", *sym = NULL; uintptr_t off = 0;
        if (dladdr(pc, &di)) {
            if (di.dli_fname) { const char *b = strrchr(di.dli_fname, '/'); img = b ? b + 1 : di.dli_fname; }
            if (di.dli_sname) { sym = di.dli_sname; off = (uintptr_t)pc - (uintptr_t)di.dli_saddr; }
        }
        [out addObject:sym ? [NSString stringWithFormat:@"%-3lu %-35s 0x%016lx %s + %lu", (unsigned long)i, img, (unsigned long)(uintptr_t)pc, sym, (unsigned long)off]
                           : [NSString stringWithFormat:@"%-3lu %-35s 0x%016lx", (unsigned long)i, img, (unsigned long)(uintptr_t)pc]];
        i++;
    }
    return out;
}

@implementation NSException
+ (NSException *)exceptionWithName:(NSExceptionName)n reason:(NSString *)r userInfo:(NSDictionary *)u { return [[self alloc] initWithName:n reason:r userInfo:u]; }
+ (void)raise:(NSExceptionName)name format:(NSString *)format arguments:(va_list)ap {
    [[self exceptionWithName:name reason:[[NSString alloc] initWithFormat:format arguments:ap] userInfo:nil] raise];
    __builtin_unreachable();
}
- (NSArray<NSNumber *> *)callStackReturnAddresses { return _isimCallStack ?: @[]; }
- (NSArray<NSString *> *)callStackSymbols { return isim_symbolicate(self.callStackReturnAddresses); }
- (instancetype)initWithName:(NSExceptionName)n reason:(NSString *)r userInfo:(NSDictionary *)u {
    if ((self = [super init])) { _name = [n copy]; _reason = [r copy]; _userInfo = [u copy]; }
    return self;
}
- (void)raise { objc_exception_throw(self); }
+ (void)raise:(NSExceptionName)name format:(NSString *)format, ... {
    va_list ap; va_start(ap, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    [[self exceptionWithName:name reason:reason userInfo:nil] raise];
    __builtin_unreachable();
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"%@: %@", _name, _reason]; }
@end

/* property lists: PropertyList.m (isim_plist_parse) */

/* ================= NSBundle ================= */
/* bundles of app extensions loaded into this process (isim hosts custom keyboards in-process):
 * their code asks Bundle.main for its strings, so the main bundle falls back to them */
static NSMutableArray<NSBundle *> *extension_bundles;
@interface NSBundle (IsimLookup)
- (NSString *)_isim_lookup:(NSString *)key table:(NSString *)t;
@end
@implementation NSBundle { NSString *_path; NSDictionary *_info; NSMutableDictionary *_tables; }
+ (NSBundle *)mainBundle {
    static NSBundle *main;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        char buf[4096]; uint32_t size = sizeof buf;
        NSString *exe = _NSGetExecutablePath(buf, &size) == 0 ? @(buf) : @".";
        main = [[NSBundle alloc] init];
        main->_path = [exe stringByDeletingLastPathComponent];
    });
    return main;
}
+ (instancetype)bundleWithPath:(NSString *)path { return [[self alloc] initWithPath:path]; }
- (instancetype)initWithPath:(NSString *)path {
    BOOL dir = NO;
    if (!path || ![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&dir] || !dir) return nil;
    if ((self = [super init])) _path = [path copy];
    return self;
}
/* the bundle whose executable contains the class's code (app, or an extension loaded in-process) */
+ (NSBundle *)bundleForClass:(Class)cls {
    Dl_info di;
    if (cls && dladdr((__bridge void *)cls, &di) && di.dli_fname) {
        NSString *dir = [@(di.dli_fname) stringByDeletingLastPathComponent];
        if ([dir isEqualToString:NSBundle.mainBundle.bundlePath]) return NSBundle.mainBundle;
        if ([dir hasSuffix:@".appex"] || [dir hasSuffix:@".bundle"] || [dir hasSuffix:@".app"] || [dir hasSuffix:@".xctest"] || [dir hasSuffix:@".framework"])
            return [NSBundle bundleWithPath:dir] ?: NSBundle.mainBundle;
    }
    return NSBundle.mainBundle;
}
+ (NSBundle *)bundleWithIdentifier:(NSString *)ident {
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:ident]) return NSBundle.mainBundle;
    for (NSBundle *b in extension_bundles) if ([b.bundleIdentifier isEqualToString:ident]) return b;
    for (NSBundle *b in [self.allFrameworks arrayByAddingObjectsFromArray:self.allBundles])
        if ([b.bundleIdentifier isEqualToString:ident]) return b;
    return nil;
}
/* bundles whose executables are loaded: the image list, each image's enclosing .framework / .bundle / .app */
static NSArray<NSBundle *> *loaded_bundles(BOOL frameworks) {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    if (!frameworks) { [out addObject:NSBundle.mainBundle]; [seen addObject:NSBundle.mainBundle.bundlePath]; }
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *dir = [@(name) stringByDeletingLastPathComponent];
        BOOL fw = [dir.pathExtension isEqualToString:@"framework"];
        if (fw != frameworks || (!fw && ![dir.pathExtension isEqualToString:@"bundle"]) || [seen containsObject:dir]) continue;
        [seen addObject:dir];
        NSBundle *b = [NSBundle bundleWithPath:dir];
        if (b) [out addObject:b];
    }
    return out;
}
+ (NSArray<NSBundle *> *)allFrameworks { return loaded_bundles(YES); }
+ (NSArray<NSBundle *> *)allBundles { return loaded_bundles(NO); }
- (NSString *)builtInPlugInsPath { return [_path stringByAppendingPathComponent:@"PlugIns"]; }
- (NSString *)privateFrameworksPath { return [_path stringByAppendingPathComponent:@"Frameworks"]; }
- (NSString *)sharedFrameworksPath { return [_path stringByAppendingPathComponent:@"SharedFrameworks"]; }

/* code loading: dlopen of the executable (images are never unloaded, as on iOS for Objective-C and Swift code) */
- (BOOL)isLoaded {
    if (self == NSBundle.mainBundle || [_path isEqualToString:NSBundle.mainBundle.bundlePath]) return YES;
    NSString *exe = self.executablePath;
    return exe && dlopen(exe.UTF8String, RTLD_NOLOAD | RTLD_LAZY) != NULL;
}
static NSError *bundle_error(NSBundle *b, NSInteger code, NSString *why, NSString *debug) {
    NSString *name = [b objectForInfoDictionaryKey:@"CFBundleName"] ?: b.bundlePath.lastPathComponent.stringByDeletingPathExtension;
    NSMutableDictionary *info = [@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The bundle “%@” couldn’t be loaded%@.", name, why],
                                    @"NSFilePath": b.executablePath ?: b.bundlePath, @"NSBundlePath": b.bundlePath } mutableCopy];
    if (debug) info[NSDebugDescriptionErrorKey] = debug;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}
- (BOOL)preflightAndReturnError:(NSError **)error {
    NSString *exe = self.executablePath;
    if (!exe || access(exe.UTF8String, R_OK) != 0) {
        if (error) *error = bundle_error(self, 4 /* NSFileNoSuchFileError */, @" because its executable couldn’t be located", nil);
        return NO;
    }
    if (self.isLoaded || dlopen_preflight(exe.UTF8String)) return YES;
    const char *why = dlerror();
    if (error) *error = bundle_error(self, 3587 /* NSExecutableLoadError */, @" because it is damaged or missing necessary resources", why ? @(why) : nil);
    return NO;
}
- (BOOL)loadAndReturnError:(NSError **)error {
    if (self.isLoaded) return YES;
    NSString *exe = self.executablePath;
    if (!exe || access(exe.UTF8String, R_OK) != 0) {
        if (error) *error = bundle_error(self, 4 /* NSFileNoSuchFileError */, @" because its executable couldn’t be located", nil);
        return NO;
    }
    if (dlopen(exe.UTF8String, RTLD_LAZY | RTLD_LOCAL)) return YES;
    const char *why = dlerror();
    if (error) *error = bundle_error(self, 3587 /* NSExecutableLoadError */, @" because it is damaged or missing necessary resources", why ? @(why) : nil);
    return NO;
}
- (BOOL)load { return [self loadAndReturnError:NULL]; }
- (BOOL)unload { return NO; }
/* the class named NSPrincipalClass in Info.plist, else the first class the executable defines; loads the bundle */
- (Class)principalClass {
    if (![self load]) return Nil;
    NSString *name = self.infoDictionary[@"NSPrincipalClass"];
    if (name.length) return NSClassFromString(name);
    char *real = realpath(self.executablePath.UTF8String, NULL);
    Class first = Nil;
    for (uint32_t i = 0, n = _dyld_image_count(); real && i < n && !first; i++) {
        const char *img = _dyld_get_image_name(i);
        if (!img || strcmp(img, real)) continue;
        const struct mach_header_64 *mh = (const void *)_dyld_get_image_header(i);
        unsigned long size = 0;
        Class *list = (Class *)(void *)getsectiondata(mh, "__DATA_CONST", "__objc_classlist", &size);
        if (!list) list = (Class *)(void *)getsectiondata(mh, "__DATA", "__objc_classlist", &size);
        if (list && size >= sizeof(Class)) first = list[0];
    }
    free(real);
    return first;
}
- (Class)classNamed:(NSString *)name {
    if (![self load]) return Nil;
    Class c = NSClassFromString(name);
    return c && [[NSBundle bundleForClass:c].bundlePath isEqualToString:_path] ? c : Nil;
}
- (NSString *)bundlePath { return _path; }
- (NSString *)resourcePath { return _path; }
- (NSString *)executablePath {
    NSString *name = self.infoDictionary[@"CFBundleExecutable"];
    return name ? [_path stringByAppendingPathComponent:name] : nil;
}
- (NSDictionary *)infoDictionary {
    if (!_info) _info = [NSDictionary dictionaryWithContentsOfFile:[_path stringByAppendingPathComponent:@"Info.plist"]] ?: @{};
    return _info;
}
/* like iOS: values localized in <lang>.lproj/InfoPlist.strings win (e.g. CFBundleDisplayName) */
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (!key) return nil;
    NSString *loc = [self _isim_lookup:key table:@"InfoPlist"];
    return loc ?: self.infoDictionary[key];
}
- (NSDictionary *)localizedInfoDictionary {
    NSMutableDictionary *d = [self.infoDictionary mutableCopy];
    for (NSString *k in self.infoDictionary) { NSString *loc = [self _isim_lookup:k table:@"InfoPlist"]; if (loc) d[k] = loc; }
    return d;
}
- (NSString *)bundleIdentifier { return self.infoDictionary[@"CFBundleIdentifier"]; }
- (NSArray<NSString *> *)localizations {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *declared = self.infoDictionary[@"CFBundleLocalizations"];
    NSMutableArray *candidates = [NSMutableArray arrayWithArray:declared ?: @[]];
    for (NSString *l in isim_preferred_languages()) { [candidates addObject:l]; [candidates addObject:[l componentsSeparatedByString:@"-"].firstObject]; }
    for (NSString *c in @[@"Base", @"en"]) [candidates addObject:c];
    if (self.developmentLocalization) [candidates addObject:self.developmentLocalization];
    for (NSString *c in candidates) {
        if ([out containsObject:c]) continue;
        NSString *dir = [_path stringByAppendingPathComponent:[c stringByAppendingString:@".lproj"]];
        if (access(dir.UTF8String, R_OK) == 0) [out addObject:c];
    }
    return out;
}
- (NSString *)developmentLocalization { return self.infoDictionary[@"CFBundleDevelopmentRegion"] ?: @"en"; }
/* Matches preferred languages against available localizations the way iOS does in spirit:
 * exact match ("pt-BR"), then language-only ("pt"), then a same-language variant ("pt-PT"). */
+ (NSArray<NSString *> *)preferredLocalizationsFromArray:(NSArray<NSString *> *)available {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *pref in isim_preferred_languages()) {
        NSString *lang = [pref componentsSeparatedByString:@"-"].firstObject;
        NSString *hit = nil;
        for (NSString *a in available) if ([a caseInsensitiveCompare:pref] == NSOrderedSame || [[a stringByReplacingOccurrencesOfString:@"_" withString:@"-"] caseInsensitiveCompare:pref] == NSOrderedSame) hit = a;
        if (!hit) for (NSString *a in available) if ([a isEqualToString:lang]) hit = a;
        if (!hit) for (NSString *a in available) if ([a hasPrefix:[lang stringByAppendingString:@"-"]] || [a hasPrefix:[lang stringByAppendingString:@"_"]]) { hit = a; break; }
        if (hit) { [out addObject:hit]; break; }
    }
    return out;
}
- (NSArray<NSString *> *)preferredLocalizations {
    NSMutableArray *avail = [NSMutableArray array];
    for (NSString *l in self.localizations) if (![l isEqualToString:@"Base"]) [avail addObject:l];
    NSArray *pref = [NSBundle preferredLocalizationsFromArray:avail];
    if (pref.count) return pref;
    return avail.count ? @[[avail containsObject:self.developmentLocalization] ? self.developmentLocalization : avail.firstObject] : @[self.developmentLocalization];
}
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)sub forLocalization:(NSString *)loc {
    NSString *file = ext.length ? [name stringByAppendingPathExtension:ext] : name;
    NSString *dir = sub.length ? [_path stringByAppendingPathComponent:sub] : _path;
    NSString *p = [(loc ? [dir stringByAppendingPathComponent:[loc stringByAppendingString:@".lproj"]] : dir) stringByAppendingPathComponent:file];
    return access(p.UTF8String, R_OK) == 0 ? p : nil;
}
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext {
    NSString *p = [self pathForResource:name ofType:ext inDirectory:nil forLocalization:nil];
    if (p) return p;
    for (NSString *loc in [self.preferredLocalizations arrayByAddingObjectsFromArray:@[@"Base", self.developmentLocalization]])
        if ((p = [self pathForResource:name ofType:ext inDirectory:nil forLocalization:loc])) return p;
    return nil;
}
void isim_bundle_register_extension(NSString *path) {
    NSBundle *b = [NSBundle bundleWithPath:path];
    if (!b) return;
    @synchronized ([NSBundle class]) { if (!extension_bundles) extension_bundles = [NSMutableArray array]; [extension_bundles addObject:b]; }
}
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)t {
    if (!key) return value ?: @"";
    NSString *hit = [self _isim_lookup:key table:t];
    if (!hit && self == NSBundle.mainBundle) {
        NSArray *exts; @synchronized ([NSBundle class]) { exts = [extension_bundles copy]; }
        for (NSBundle *b in exts) if ((hit = [b _isim_lookup:key table:t])) break;
    }
    return hit ?: (value.length ? value : key);
}
- (NSString *)_isim_lookup:(NSString *)key table:(NSString *)t {
    NSString *table = t.length ? t : @"Localizable";
    @synchronized (self) {
        if (!_tables) _tables = [NSMutableDictionary dictionary];
        for (NSString *loc in [self.preferredLocalizations arrayByAddingObject:self.developmentLocalization]) {
            NSString *cacheKey = [NSString stringWithFormat:@"%@/%@", loc, table];
            /* .stringsdict (plural rules) wins over .strings, like Apple's */
            NSString *dictKey = [cacheKey stringByAppendingString:@".stringsdict"];
            NSDictionary *plurals = _tables[dictKey];
            if (!plurals) {
                NSString *path = [self pathForResource:table ofType:@"stringsdict" inDirectory:nil forLocalization:loc];
                plurals = (path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil) ?: @{};
                _tables[dictKey] = plurals;
            }
            NSDictionary *entry = plurals[key];
            if ([entry isKindOfClass:[NSDictionary class]] && [entry[@"NSStringLocalizedFormatKey"] isKindOfClass:[NSString class]])
                return isim_plural_format(entry, loc);
            if ([entry isKindOfClass:[NSDictionary class]]) {
                /* device variations: the simulated device's idiom, else "other" */
                NSDictionary *dev = entry[@"NSStringDeviceSpecificRuleType"];
                if ([dev isKindOfClass:[NSDictionary class]] && dev.count) {
                    const char *d = getenv("ISIM_DEVICE");
                    NSString *idiom = d && !strncmp(d, "ipad", 4) ? @"ipad" : @"iphone";
                    id v = dev[idiom] ?: dev[@"other"] ?: dev[[dev.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject];
                    if ([v isKindOfClass:[NSString class]]) return v;
                    if ([v isKindOfClass:[NSDictionary class]] && [v[@"NSStringLocalizedFormatKey"] isKindOfClass:[NSString class]]) return isim_plural_format(v, loc);
                }
                /* width variations: the widest; -variantFittingPresentationWidth: picks another */
                NSDictionary *width = entry[@"NSStringVariableWidthRuleType"];
                if ([width isKindOfClass:[NSDictionary class]] && width.count) return isim_width_variants(width);
            }
            NSDictionary *strings = _tables[cacheKey];
            if (!strings) {
                NSString *path = [self pathForResource:table ofType:@"strings" inDirectory:nil forLocalization:loc];
                strings = (path ? isim_parse_strings_file(path) : nil) ?: @{};
                _tables[cacheKey] = strings;
            }
            NSString *hit = strings[key];
            if (hit) return hit;
        }
    }
    return nil;
}
@end

/* ================= NSDate ================= */
@implementation NSDate { NSTimeInterval _t; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSDate class]); }    /* NS.time */
- (instancetype)initWithCoder:(NSCoder *)c { if ((self = [super init])) _t = [c decodeDoubleForKey:@"NS.time"]; return self; }   /* not via the designated initializer (Swift subclasses) */
+ (NSTimeInterval)timeIntervalSinceReferenceDate_isim { return wall_now() - REF_EPOCH; }
+ (instancetype)date { return [[self alloc] initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH]; }
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)s { return [[self alloc] initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH + s]; }
+ (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)s { return [[self alloc] initWithTimeIntervalSinceReferenceDate:s - REF_EPOCH]; }
+ (instancetype)dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)t { return [[self alloc] initWithTimeIntervalSinceReferenceDate:t]; }
+ (NSDate *)distantFuture { return [[self alloc] initWithTimeIntervalSinceReferenceDate:63113904000.0]; }
+ (NSDate *)distantPast { return [[self alloc] initWithTimeIntervalSinceReferenceDate:-63114076800.0]; }
- (instancetype)init { return [self initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH]; }
- (instancetype)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)t { if ((self = [super init])) _t = t; return self; }
- (NSTimeInterval)timeIntervalSinceReferenceDate { return _t; }
- (NSTimeInterval)timeIntervalSince1970 { return _t + REF_EPOCH; }
- (NSTimeInterval)timeIntervalSinceNow { return _t - (wall_now() - REF_EPOCH); }
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)d { return _t - d.timeIntervalSinceReferenceDate; }
- (NSDate *)dateByAddingTimeInterval:(NSTimeInterval)ti { return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:_t + ti]; }
- (NSComparisonResult)compare:(NSDate *)o { NSTimeInterval b = o.timeIntervalSinceReferenceDate; return _t < b ? NSOrderedAscending : _t > b ? NSOrderedDescending : NSOrderedSame; }
- (BOOL)isEqualToDate:(NSDate *)o { return o && _t == o.timeIntervalSinceReferenceDate; }
- (NSDate *)earlierDate:(NSDate *)o { return [self compare:o] == NSOrderedDescending ? o : self; }
- (NSDate *)laterDate:(NSDate *)o { return [self compare:o] == NSOrderedAscending ? o : self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSDate class]] && [self compare:o] == NSOrderedSame; }
- (NSUInteger)hash { return (NSUInteger)_t; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description {
    time_t s = (time_t)(_t + REF_EPOCH); struct tm tm; gmtime_r(&s, &tm);
    char b[64]; strftime(b, sizeof b, "%Y-%m-%d %H:%M:%S +0000", &tm);
    return @(b);
}
@end


/* ================= NSNotificationCenter ================= */
@implementation NSNotification
+ (instancetype)notificationWithName:(NSNotificationName)n object:(id)o userInfo:(NSDictionary *)u {
    NSNotification *x = [self new]; x->_name = [n copy]; x->_object = o; x->_userInfo = [u copy]; return x;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface __IsimObserver : NSObject
@property (weak) id observer;
@property SEL sel;
@property (copy) NSString *name;
@property (weak) id object;
@property BOOL hasObject;
@property (copy) void (^block)(NSNotification *);
@end
@implementation __IsimObserver @end

@implementation NSNotificationCenter { NSMutableArray<__IsimObserver *> *_obs; }
+ (NSNotificationCenter *)defaultCenter { static NSNotificationCenter *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [NSNotificationCenter new]; }); return c; }
- (instancetype)init { if ((self = [super init])) _obs = [NSMutableArray array]; return self; }
- (void)addObserver:(id)observer selector:(SEL)sel name:(NSNotificationName)name object:(id)obj {
    __IsimObserver *o = [__IsimObserver new];
    o.observer = observer; o.sel = sel; o.name = name; o.object = obj; o.hasObject = obj != nil;
    @synchronized (self) { [_obs addObject:o]; }
}
- (id<NSObject>)addObserverForName:(NSNotificationName)name object:(id)obj queue:(NSOperationQueue *)q usingBlock:(void (^)(NSNotification *))block {
    __IsimObserver *o = [__IsimObserver new];
    o.name = name; o.object = obj; o.hasObject = obj != nil; o.observer = o;
    o.block = q ? ^(NSNotification *n) { if (q == NSOperationQueue.currentQueue) block(n); else [q addOperationWithBlock:^{ block(n); }]; } : block;
    @synchronized (self) { [_obs addObject:o]; }
    return o;
}
- (void)postNotification:(NSNotification *)n {
    NSArray *snapshot; @synchronized (self) { snapshot = [_obs copy]; }
    for (__IsimObserver *o in snapshot) {
        if (o.name && ![o.name isEqualToString:n.name]) continue;
        if (o.hasObject && o.object != n.object) continue;
        if (o.block) o.block(n);
        else { id target = o.observer; if (target) ((void (*)(id, SEL, id))[target methodForSelector:o.sel])(target, o.sel, n); }
    }
}
- (void)postNotificationName:(NSNotificationName)name object:(id)obj { [self postNotificationName:name object:obj userInfo:nil]; }
- (void)postNotificationName:(NSNotificationName)name object:(id)obj userInfo:(NSDictionary *)u {
    [self postNotification:[NSNotification notificationWithName:name object:obj userInfo:u]];
}
- (void)removeObserver:(id)observer { [self removeObserver:observer name:nil object:nil]; }
- (void)removeObserver:(id)observer name:(NSNotificationName)name object:(id)obj {
    @synchronized (self) {
        for (__IsimObserver *o in [_obs copy]) {
            if (o.observer != observer && o != observer) continue;
            if (name && ![o.name isEqualToString:name]) continue;
            if (obj && o.object != obj) continue;
            [_obs removeObject:o];
        }
    }
}
@end

/* ================= NSProcessInfo / NSUserDefaults ================= */
const char *isim_process_name(void) {
    static char name[256];
    if (!name[0]) { char **argv = *_NSGetArgv(); const char *s = argv && argv[0] ? argv[0] : "app"; const char *b = strrchr(s, '/'); snprintf(name, sizeof name, "%s", b ? b + 1 : s); }
    return name;
}
@implementation NSProcessInfo
+ (NSProcessInfo *)processInfo { static NSProcessInfo *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [NSProcessInfo new]; p.processName = @(isim_process_name()); }); return p; }
- (NSArray<NSString *> *)arguments {
    NSMutableArray *a = [NSMutableArray array];
    int argc = *_NSGetArgc(); char **argv = *_NSGetArgv();
    for (int i = 0; i < argc; i++) [a addObject:@(argv[i])];
    return a;
}
- (NSDictionary<NSString *, NSString *> *)environment {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (char **e = *_NSGetEnviron(); e && *e; e++) {
        const char *eq = strchr(*e, '=');
        if (!eq) continue;
        NSString *k = [[NSString alloc] initWithBytes:*e length:(NSUInteger)(eq - *e) encoding:NSUTF8StringEncoding];
        d[k] = @(eq + 1);
    }
    return d;
}
- (int)processIdentifier { return getpid(); }
- (NSUInteger)processorCount { return (NSUInteger)sysconf(58 /* Darwin _SC_NPROCESSORS_ONLN */); }
- (NSTimeInterval)systemUptime { return mono_now(); }
@end

/* System-wide preferences (the global domain, ".GlobalPreferences"): written by the Settings app,
 * read by every app (languages, region, appearance, keyboards, ...). Environment variables win. */
NSString *const NSGlobalDomain = @"NSGlobalDomain";
extern NSString *isim_data_dir(void);
static NSString *global_prefs_path(void) {
    return [isim_data_dir() stringByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
}
NSDictionary *isim_global_preferences(void) {
    static NSDictionary *cache; static struct timespec mtime; static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
    struct stat st;
    pthread_mutex_lock(&lk);
    if (stat(global_prefs_path().UTF8String, &st) != 0) { cache = @{}; mtime = (struct timespec){ 0, 0 }; }
    else if (!cache || st.st_mtimespec.tv_sec != mtime.tv_sec || st.st_mtimespec.tv_nsec != mtime.tv_nsec) {
        cache = [NSDictionary dictionaryWithContentsOfFile:global_prefs_path()] ?: @{};
        mtime = st.st_mtimespec;
    }
    NSDictionary *d = cache;
    pthread_mutex_unlock(&lk);
    return d;
}
static void mkdir_p(NSString *dir) {
    char buf[4096]; snprintf(buf, sizeof buf, "%s", dir.UTF8String);
    for (char *p = buf + 1; *p; p++) if (*p == '/') { *p = 0; mkdir(buf, 0755); *p = '/'; }
    mkdir(buf, 0755);
}

@implementation NSUserDefaults { NSMutableDictionary *_d; NSString *_file; BOOL _global, _standard; }
+ (NSUserDefaults *)standardUserDefaults {
    static NSUserDefaults *u; static dispatch_once_t o;
    dispatch_once(&o, ^{ u = [NSUserDefaults new]; u->_standard = YES; });
    return u;
}
- (instancetype)init {
    if ((self = [super init])) {
        NSString *ident = NSBundle.mainBundle.bundleIdentifier ?: @(isim_process_name());
        _file = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), ident];
        _d = [[NSDictionary dictionaryWithContentsOfFile:_file] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}
/* suites: ".GlobalPreferences" / NSGlobalDomain is the system domain; other names are shared (app group) domains */
- (instancetype)initWithSuiteName:(NSString *)suite {
    if (!suite.length || [suite isEqualToString:NSBundle.mainBundle.bundleIdentifier]) return [self init];
    if ((self = [super init])) {
        _global = [suite isEqualToString:@".GlobalPreferences"] || [suite isEqualToString:NSGlobalDomain];
        _file = _global ? global_prefs_path()
                        : [NSString stringWithFormat:@"%@/Shared/AppGroup/%@/Library/Preferences/%@.plist", isim_data_dir(), suite, suite];
        mkdir_p(_file.stringByDeletingLastPathComponent);
        _d = [[NSDictionary dictionaryWithContentsOfFile:_file] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}
/* re-read the domain from disk (the Settings app writes an app's Settings.bundle values there); YES if it changed */
- (BOOL)_isim_reloadFromDisk {
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:_file] ?: @{};
    @synchronized (self) {
        if ([disk isEqualToDictionary:_d]) return NO;
        _d = [disk mutableCopy];
    }
    return YES;
}
- (void)_save {
    [isim_plist_xml(_d) writeToFile:_file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    if (_global) dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimGlobalPreferencesChanged" object:nil];
    });
}
/* NSArgumentDomain: "-key value" launch arguments override everything (as on iOS; e.g. Xcode scheme arguments) */
static NSDictionary *argument_domain(void) {
    static NSDictionary *args; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        NSArray *a = NSProcessInfo.processInfo.arguments;
        for (NSUInteger i = 1; i + 1 < a.count; i++) {
            NSString *k = a[i];
            if (k.length > 1 && [k hasPrefix:@"-"] && ![k hasPrefix:@"--"]) { d[[k substringFromIndex:1]] = a[i + 1]; i++; }
        }
        args = [d copy];
    });
    return args;
}
- (id)objectForKey:(NSString *)k {
    id v = _standard ? argument_domain()[k] : nil;
    if (v) return v;
    @synchronized (self) { v = _d[k]; }
    if (!v && _standard) v = isim_global_preferences()[k];        /* search list: app domain, then global domain */
    return v;
}
- (void)setObject:(id)v forKey:(NSString *)k { @synchronized (self) { if (v) _d[k] = v; else [_d removeObjectForKey:k]; [self _save]; } }
- (void)removeObjectForKey:(NSString *)k { @synchronized (self) { [_d removeObjectForKey:k]; [self _save]; } }
- (NSDictionary *)dictionaryRepresentation { @synchronized (self) { return [_d copy]; } }
- (NSInteger)integerForKey:(NSString *)k { return [[self objectForKey:k] integerValue]; }
- (void)setInteger:(NSInteger)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (BOOL)boolForKey:(NSString *)k { return [[self objectForKey:k] boolValue]; }
- (void)setBool:(BOOL)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (NSString *)stringForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSString class]] ? v : nil; }
- (double)doubleForKey:(NSString *)k { return [[self objectForKey:k] doubleValue]; }
- (void)setDouble:(double)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (NSArray *)arrayForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSArray class]] ? v : nil; }
- (NSDictionary *)dictionaryForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSDictionary class]] ? v : nil; }
- (void)registerDefaults:(NSDictionary *)defaults { @synchronized (self) { for (NSString *k in defaults) if (!_d[k]) _d[k] = defaults[k]; } }
- (BOOL)synchronize { @synchronized (self) { [self _save]; } return YES; }
@end

/* ================= NSError ================= */
NSErrorDomain const NSCocoaErrorDomain = @"NSCocoaErrorDomain";
NSErrorDomain const NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";
NSErrorDomain const NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
NSErrorUserInfoKey const NSLocalizedDescriptionKey = @"NSLocalizedDescription";
NSErrorUserInfoKey const NSUnderlyingErrorKey = @"NSUnderlyingError";
NSErrorUserInfoKey const NSLocalizedFailureReasonErrorKey = @"NSLocalizedFailureReason";
NSErrorUserInfoKey const NSLocalizedRecoverySuggestionErrorKey = @"NSLocalizedRecoverySuggestion";
NSErrorUserInfoKey const NSLocalizedRecoveryOptionsErrorKey = @"NSLocalizedRecoveryOptions";
NSErrorUserInfoKey const NSRecoveryAttempterErrorKey = @"NSRecoveryAttempter";
NSErrorUserInfoKey const NSHelpAnchorErrorKey = @"NSHelpAnchor";
NSErrorUserInfoKey const NSDebugDescriptionErrorKey = @"NSDebugDescription";
NSErrorUserInfoKey const NSLocalizedFailureErrorKey = @"NSLocalizedFailure";
NSErrorUserInfoKey const NSStringEncodingErrorKey = @"NSStringEncodingErrorKey";
NSErrorUserInfoKey const NSURLErrorKey = @"NSURL";
NSErrorUserInfoKey const NSMultipleUnderlyingErrorsKey = @"NSMultipleUnderlyingErrorsKey";
/* +setUserInfoValueProviderForDomain:provider: — consulted for keys missing from an error's userInfo */
static NSMutableDictionary *error_providers;
@implementation NSError
/* keyed coding with Apple's keys (NSDomain, NSCode, NSUserInfo); userInfo values that cannot be archived are left out */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_domain forKey:@"NSDomain"];
    [c encodeInteger:_code forKey:@"NSCode"];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [_userInfo enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
        if ([k isKindOfClass:[NSString class]] && [v respondsToSelector:@selector(encodeWithCoder:)]) info[k] = v;
    }];
    if (info.count) [c encodeObject:info forKey:@"NSUserInfo"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSDate class],
                                           [NSData class], [NSURL class], [NSError class], nil];
    /* state set directly, not through -initWithDomain:code:userInfo: (a Swift subclass that does not override it traps) */
    if ((self = [super init])) {
        _domain = [[c decodeObjectOfClass:[NSString class] forKey:@"NSDomain"] ?: @"" copy];
        _code = [c decodeIntegerForKey:@"NSCode"];
        _userInfo = [[c decodeObjectOfClasses:classes forKey:@"NSUserInfo"] copy] ?: @{};
    }
    return self;
}
+ (instancetype)errorWithDomain:(NSErrorDomain)d code:(NSInteger)c userInfo:(NSDictionary *)u { return [[self alloc] initWithDomain:d code:c userInfo:u]; }
- (instancetype)initWithDomain:(NSErrorDomain)d code:(NSInteger)c userInfo:(NSDictionary *)u {
    if ((self = [super init])) { _domain = [d copy]; _code = c; _userInfo = [u copy] ?: @{}; }
    return self;
}
+ (void)setUserInfoValueProviderForDomain:(NSErrorDomain)domain provider:(id (^)(NSError *, NSErrorUserInfoKey))provider {
    if (!domain) return;
    @synchronized ([NSError class]) {
        if (!error_providers) error_providers = [NSMutableDictionary new];
        if (provider) error_providers[domain] = [provider copy]; else [error_providers removeObjectForKey:domain];
    }
}
+ (id (^)(NSError *, NSErrorUserInfoKey))userInfoValueProviderForDomain:(NSErrorDomain)domain {
    if (!domain) return nil;
    @synchronized ([NSError class]) { return error_providers[domain]; }
}
/* a userInfo value, else the domain's value provider's (Apple's lookup order) */
- (id)_isim_infoValue:(NSErrorUserInfoKey)key {
    id v = self.userInfo[key];
    if (v) return v;
    id (^p)(NSError *, NSErrorUserInfoKey) = [NSError userInfoValueProviderForDomain:self.domain];
    return p ? p(self, key) : nil;
}
/* through the accessors: the Swift runtime's NSError subclass for bridged Swift errors overrides them */
- (NSString *)localizedDescription {
    NSString *s = [self _isim_infoValue:NSLocalizedDescriptionKey];
    if ([s isKindOfClass:[NSString class]]) return s;
    NSString *failure = [self _isim_infoValue:NSLocalizedFailureErrorKey], *reason = self.localizedFailureReason;
    if (failure && reason) return [NSString stringWithFormat:@"%@ %@", failure, reason];
    if (failure) return failure;
    if (reason) return [NSString stringWithFormat:@"The operation couldn’t be completed. %@", reason];
    return [NSString stringWithFormat:@"The operation couldn’t be completed. (%@ error %ld.)", self.domain, (long)self.code];
}
- (NSString *)localizedFailureReason { return [self _isim_infoValue:NSLocalizedFailureReasonErrorKey]; }
- (NSString *)localizedRecoverySuggestion { return [self _isim_infoValue:NSLocalizedRecoverySuggestionErrorKey]; }
- (NSArray<NSString *> *)localizedRecoveryOptions { return [self _isim_infoValue:NSLocalizedRecoveryOptionsErrorKey]; }
- (id)recoveryAttempter { return [self _isim_infoValue:NSRecoveryAttempterErrorKey]; }
- (NSString *)helpAnchor { return [self _isim_infoValue:NSHelpAnchorErrorKey]; }
- (NSArray<NSError *> *)underlyingErrors {
    NSMutableArray *a = [NSMutableArray array];
    id u = self.userInfo[NSUnderlyingErrorKey]; if ([u isKindOfClass:[NSError class]]) [a addObject:u];
    id m = self.userInfo[NSMultipleUnderlyingErrorsKey]; if ([m isKindOfClass:[NSArray class]]) [a addObjectsFromArray:m];
    return a;
}
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSError class]]) return NO;
    NSError *e = o;
    return e.code == self.code && [e.domain isEqual:self.domain] && [e.userInfo isEqual:self.userInfo];
}
- (NSUInteger)hash { return self.domain.hash ^ (NSUInteger)self.code; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"Error Domain=%@ Code=%ld \"%@\"", self.domain, (long)self.code, self.localizedDescription]; }
@end

/* NSCoder: Archiver.m */

/* function-pointer variants (used by C/C++ clients such as the Swift runtime) */

/* CGColor objects (CoreGraphics allocates these so CGColorRef is retainable by ARC/Swift).
 * Layout must match struct CGColor in CoreGraphics.c: isa, 4 components, refs. */
@interface __NSCGColor : NSObject { @public CGFloat _c[4]; int _refs; int _space; CGFloat _comp[5]; void *_pattern; }
@end
@implementation __NSCGColor
- (void)dealloc { if (_pattern) CFRelease(_pattern); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGColor %p> [%g %g %g %g]", self, _c[0], _c[1], _c[2], _c[3]]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[__NSCGColor class]] && !memcmp(_c, ((__NSCGColor *)o)->_c, sizeof _c)); }
- (NSUInteger)hash { return (NSUInteger)(_c[0] * 255) << 24 ^ (NSUInteger)(_c[1] * 255) << 16 ^ (NSUInteger)(_c[2] * 255) << 8 ^ (NSUInteger)(_c[3] * 255); }
@end

/* CGPath / CGImage / CGContext objects (allocated by CoreGraphics; layouts must match CoreGraphics.c) */
@interface __NSCGPath : NSObject { @public void *_els; long _count, _cap; }
@end
@implementation __NSCGPath
- (void)dealloc { free(_els); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGPath %p> %ld elements", self, _count]; }
@end
@interface __NSCGImage : NSObject { @public int _handle; double _x, _y, _w, _h; void *_owner; void *_ext; }
@end
@implementation __NSCGImage
- (void)dealloc { if (_owner) CFRelease(_owner); if (_ext) CFRelease(_ext); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGImage %p> (%g x %g)", self, _w, _h]; }
@end
@interface __NSCGContext : NSObject { @public void (*_fin)(void *); }
@end
@implementation __NSCGContext
- (void)dealloc { if (_fin) _fin((__bridge void *)self); }
@end
/* other Core Graphics / ImageIO objects (color spaces, data providers, gradients, ...): a finalizer + private storage */
@interface __NSCGObject : NSObject { @public void (*_fin)(void *); const char *_kind; }
@end
@implementation __NSCGObject
- (void)dealloc { if (_fin) _fin((__bridge void *)self); }
- (NSString *)description { return [NSString stringWithFormat:@"<%s %p>", _kind ?: "CGObject", self]; }
@end

