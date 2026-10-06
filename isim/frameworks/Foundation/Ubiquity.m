/* isim Foundation: app group and ubiquity containers, NSUbiquitousKeyValueStore (local), NSNotificationQueue.
 * Self-authored. "iCloud" here is a local simulation: nothing leaves the device data directory.
 *   app groups:        $ISIM_DATA/Shared/AppGroup/<group>/  (same place as UserDefaults(suiteName: group))
 *   ubiquity:          $ISIM_DATA/Mobile Documents/<container id>/Documents
 *   key-value store:   $ISIM_DATA/Mobile Documents/KeyValueStore/<store id>.plist, where the store id is the app's
 *                      Info.plist ISIMUbiquityKeyValueStoreIdentifier (isim-private) or its bundle identifier.
 * ISIM_ICLOUD=noAccount signs the simulated iCloud account out (no ubiquity containers, no identity token). */
#import "isim_foundation.h"
#include <sys/stat.h>
#include <dispatch/dispatch.h>

NSNotificationName const NSUbiquityIdentityDidChangeNotification = @"NSUbiquityIdentityDidChangeNotification";
NSNotificationName const NSUbiquitousKeyValueStoreDidChangeExternallyNotification = @"NSUbiquitousKeyValueStoreDidChangeExternallyNotification";
NSString * const NSUbiquitousKeyValueStoreChangeReasonKey = @"NSUbiquitousKeyValueStoreChangeReasonKey";
NSString * const NSUbiquitousKeyValueStoreChangedKeysKey = @"NSUbiquitousKeyValueStoreChangedKeysKey";

static BOOL icloud_signed_in(void) {
    const char *e = getenv("ISIM_ICLOUD");
    return !(e && (!strcasecmp(e, "noAccount") || !strcmp(e, "0") || !strcasecmp(e, "off")));
}
static NSString *ensure_dir(NSString *path) {
    [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    return path;
}

@implementation NSFileManager (IsimContainers)
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)group {
    if (!group.length || [group containsString:@"/"] || [group hasPrefix:@"."]) return nil;
    NSString *root = [[isim_data_dir() stringByAppendingPathComponent:@"Shared/AppGroup"] stringByAppendingPathComponent:group];
    for (NSString *sub in @[@"Library/Preferences", @"Library/Caches"]) ensure_dir([root stringByAppendingPathComponent:sub]);
    return [NSURL fileURLWithPath:root isDirectory:YES];
}
- (NSURL *)URLForUbiquityContainerIdentifier:(NSString *)ident {
    if (!icloud_signed_in()) return nil;
    if (!ident.length) {
        NSArray *ids = NSBundle.mainBundle.infoDictionary[@"ISIMUbiquityContainerIdentifiers"];
        ident = [ids isKindOfClass:[NSArray class]] && [ids count] ? ids[0] : [@"iCloud." stringByAppendingString:NSBundle.mainBundle.bundleIdentifier ?: @"app"];
    }
    if ([ident containsString:@"/"]) return nil;
    NSString *root = [[isim_data_dir() stringByAppendingPathComponent:@"Mobile Documents"] stringByAppendingPathComponent:ident];
    ensure_dir([root stringByAppendingPathComponent:@"Documents"]);
    return [NSURL fileURLWithPath:root isDirectory:YES];
}
- (id<NSObject, NSCopying, NSCoding>)ubiquityIdentityToken {
    return icloud_signed_in() ? @"isim-local-icloud-account" : nil;
}
@end

/* ================= NSUbiquitousKeyValueStore ================= */
@implementation NSUbiquitousKeyValueStore {
    NSMutableDictionary *_values;
    NSString *_file;
    struct timespec _seen;
    dispatch_source_t _poll;
}
+ (NSUbiquitousKeyValueStore *)defaultStore {
    static NSUbiquitousKeyValueStore *store; static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [self new]; });
    return store;
}
- (instancetype)init {
    if ((self = [super init])) {
        NSString *ident = NSBundle.mainBundle.infoDictionary[@"ISIMUbiquityKeyValueStoreIdentifier"];
        if (![ident isKindOfClass:[NSString class]] || !ident.length) ident = NSBundle.mainBundle.bundleIdentifier ?: @(isim_process_name());
        _file = [ensure_dir([isim_data_dir() stringByAppendingPathComponent:@"Mobile Documents/KeyValueStore"])
                 stringByAppendingPathComponent:[ident stringByAppendingPathExtension:@"plist"]];
        _values = [NSMutableDictionary dictionary];
        if (icloud_signed_in()) [self _reload:NO];
        /* changes written by other apps sharing the store (or `isim icloud`) arrive like server changes */
        _poll = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(_poll, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), 500 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
        __unsafe_unretained NSUbiquitousKeyValueStore *weakSelf = self;   /* the default store lives forever */
        dispatch_source_set_event_handler(_poll, ^{ [weakSelf _reload:YES]; });
        dispatch_resume(_poll);
    }
    return self;
}
- (struct timespec)_mtime {
    struct stat st; struct timespec z = { 0, 0 };
    return stat(_file.UTF8String, &st) == 0 ? st.st_mtimespec : z;
}
- (void)_reload:(BOOL)notify {
    if (!icloud_signed_in()) return;
    struct timespec m = [self _mtime];
    NSDictionary *disk = nil;
    NSMutableArray *changed = [NSMutableArray array];
    @synchronized (self) {
        if (m.tv_sec == _seen.tv_sec && m.tv_nsec == _seen.tv_nsec) return;
        _seen = m;
        disk = [NSDictionary dictionaryWithContentsOfFile:_file] ?: @{};
        NSMutableSet *keys = [NSMutableSet setWithArray:disk.allKeys];
        [keys addObjectsFromArray:_values.allKeys];
        for (NSString *k in keys) if (![disk[k] isEqual:_values[k]] && (disk[k] || _values[k])) [changed addObject:k];
        _values = [disk mutableCopy];
    }
    if (notify && changed.count)
        [NSNotificationCenter.defaultCenter postNotificationName:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:self
            userInfo:@{ NSUbiquitousKeyValueStoreChangeReasonKey: @(NSUbiquitousKeyValueStoreServerChange),
                        NSUbiquitousKeyValueStoreChangedKeysKey: [changed sortedArrayUsingSelector:@selector(compare:)] }];
}
- (BOOL)synchronize {
    if (!icloud_signed_in()) return NO;
    @synchronized (self) {
        NSDictionary *snapshot = [_values copy];
        if (![snapshot writeToFile:_file atomically:YES]) return NO;
        _seen = [self _mtime];
    }
    return YES;
}
- (id)objectForKey:(NSString *)k { @synchronized (self) { return _values[k]; } }
- (void)setObject:(id)o forKey:(NSString *)k {
    if (!k) return;
    @synchronized (self) { if (o) _values[k] = o; else [_values removeObjectForKey:k]; }
    [self synchronize];   /* Apple writes asynchronously; isim writes through */
}
- (void)removeObjectForKey:(NSString *)k { [self setObject:nil forKey:k]; }
- (id)_typed:(NSString *)k class:(Class)c { id o = [self objectForKey:k]; return [o isKindOfClass:c] ? o : nil; }
- (NSString *)stringForKey:(NSString *)k { return [self _typed:k class:[NSString class]]; }
- (NSArray *)arrayForKey:(NSString *)k { return [self _typed:k class:[NSArray class]]; }
- (NSDictionary *)dictionaryForKey:(NSString *)k { return [self _typed:k class:[NSDictionary class]]; }
- (NSData *)dataForKey:(NSString *)k { return [self _typed:k class:[NSData class]]; }
- (long long)longLongForKey:(NSString *)k { return [[self _typed:k class:[NSNumber class]] longLongValue]; }
- (double)doubleForKey:(NSString *)k { return [[self _typed:k class:[NSNumber class]] doubleValue]; }
- (BOOL)boolForKey:(NSString *)k { return [[self _typed:k class:[NSNumber class]] boolValue]; }
- (void)setString:(NSString *)s forKey:(NSString *)k { [self setObject:s forKey:k]; }
- (void)setData:(NSData *)d forKey:(NSString *)k { [self setObject:d forKey:k]; }
- (void)setArray:(NSArray *)a forKey:(NSString *)k { [self setObject:a forKey:k]; }
- (void)setDictionary:(NSDictionary *)d forKey:(NSString *)k { [self setObject:d forKey:k]; }
- (void)setLongLong:(long long)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (void)setDouble:(double)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (void)setBool:(BOOL)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (NSDictionary *)dictionaryRepresentation { @synchronized (self) { return [_values copy]; } }
@end

/* ================= NSNotificationQueue ================= */
@interface _IsimQueuedNote : NSObject
@property (strong) NSNotification *note;
@property NSPostingStyle style;
@end
@implementation _IsimQueuedNote
@end

@implementation NSNotificationQueue {
    NSNotificationCenter *_center;
    NSMutableArray<_IsimQueuedNote *> *_queue;
    BOOL _asapScheduled, _idleScheduled;
}
+ (NSNotificationQueue *)defaultQueue {
    /* one per thread, like Apple's */
    NSMutableDictionary *td = NSThread.currentThread.threadDictionary;
    NSNotificationQueue *q = td[@"isim.NSNotificationQueue"];
    if (!q) { q = [[self alloc] initWithNotificationCenter:NSNotificationCenter.defaultCenter]; td[@"isim.NSNotificationQueue"] = q; }
    return q;
}
- (instancetype)init { return [self initWithNotificationCenter:NSNotificationCenter.defaultCenter]; }
- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)center {
    if ((self = [super init])) { _center = center; _queue = [NSMutableArray array]; }
    return self;
}
static BOOL coalesces(NSNotification *a, NSNotification *b, NSUInteger mask) {
    if (mask == NSNotificationNoCoalescing) return NO;
    if ((mask & NSNotificationCoalescingOnName) && ![a.name isEqualToString:b.name]) return NO;
    if ((mask & NSNotificationCoalescingOnSender) && a.object != b.object) return NO;
    return YES;
}
- (void)dequeueNotificationsMatching:(NSNotification *)note coalesceMask:(NSUInteger)mask {
    @synchronized (self) {
        NSIndexSet *hits = [_queue indexesOfObjectsPassingTest:^BOOL(_IsimQueuedNote *q, NSUInteger i, BOOL *stop) {
            return mask == NSNotificationNoCoalescing ? q.note == note : coalesces(q.note, note, mask);
        }];
        [_queue removeObjectsAtIndexes:hits];
    }
}
- (void)enqueueNotification:(NSNotification *)note postingStyle:(NSPostingStyle)style {
    [self enqueueNotification:note postingStyle:style coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
}
- (void)enqueueNotification:(NSNotification *)note postingStyle:(NSPostingStyle)style coalesceMask:(NSNotificationCoalescing)mask forModes:(NSArray *)modes {
    if (!note) return;
    if (mask != NSNotificationNoCoalescing) {
        @synchronized (self) {
            for (_IsimQueuedNote *q in _queue) if (coalesces(q.note, note, mask)) return;   /* an equivalent one is waiting */
        }
    }
    if (style == NSPostNow) {
        [self dequeueNotificationsMatching:note coalesceMask:mask];
        [_center postNotification:note];
        return;
    }
    _IsimQueuedNote *q = [_IsimQueuedNote new]; q.note = note; q.style = style;
    BOOL scheduleASAP = NO, scheduleIdle = NO;
    @synchronized (self) {
        [_queue addObject:q];
        if (style == NSPostASAP && !_asapScheduled) { _asapScheduled = YES; scheduleASAP = YES; }
        if (style == NSPostWhenIdle && !_idleScheduled) { _idleScheduled = YES; scheduleIdle = YES; }
    }
    /* ASAP: when the current run loop pass ends; when idle: after the run loop has nothing else to do
     * (isim: a short delay after the ASAP pass) */
    if (scheduleASAP) isim_schedule_perform(self, @selector(_isim_flushASAP), nil, 0);
    if (scheduleIdle) isim_schedule_perform(self, @selector(_isim_flushIdle), nil, 0.01);
}
- (void)_isim_flush:(NSPostingStyle)style {
    NSArray *ready;
    @synchronized (self) {
        NSIndexSet *hits = [_queue indexesOfObjectsPassingTest:^BOOL(_IsimQueuedNote *q, NSUInteger i, BOOL *stop) { return q.style == style; }];
        ready = [_queue objectsAtIndexes:hits];
        [_queue removeObjectsAtIndexes:hits];
        if (style == NSPostASAP) _asapScheduled = NO; else _idleScheduled = NO;
    }
    for (_IsimQueuedNote *q in ready) [_center postNotification:q.note];
}
- (void)_isim_flushASAP { [self _isim_flush:NSPostASAP]; }
- (void)_isim_flushIdle { [self _isim_flush:NSPostWhenIdle]; }
@end
