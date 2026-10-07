/* isim Foundation: NSUserActivity and app group containers.
 *
 * The device-wide Spotlight index lives in <isim data>/Library/Spotlight/<bundle id>.plist:
 *   { items = ( { id, domain, title, description, keywords, kind = item|activity, activity = <plist form> }, ... ) }
 * written here (activities made current with isEligibleForSearch) and by CoreSpotlight (CSSearchableIndex);
 * the home screen's Spotlight searches it. */
#import <Foundation/Foundation.h>
#include <sys/stat.h>

NSString *isim_data_dir(void);
NSString * const NSUserActivityTypeBrowsingWeb = @"NSUserActivityTypeBrowsingWeb";

static id plist_safe(id v) {
    if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSDate class]] || [v isKindOfClass:[NSData class]]) return v;
    if ([v isKindOfClass:[NSURL class]]) return [v absoluteString];
    if ([v isKindOfClass:[NSArray class]]) { NSMutableArray *a = [NSMutableArray array]; for (id x in v) { id y = plist_safe(x); if (y) [a addObject:y]; } return a; }
    if ([v isKindOfClass:[NSSet class]]) return plist_safe([v allObjects]);
    if ([v isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id k in v) { id y = plist_safe(v[k]); if (y) d[[k description]] = y; }
        return d;
    }
    return nil;
}

/* ---- Spotlight index (shared with CoreSpotlight) ---- */
static NSString *spotlight_file(void) {
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Library/Spotlight"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return [dir stringByAppendingPathComponent:[(NSBundle.mainBundle.bundleIdentifier ?: @"unknown") stringByAppendingPathExtension:@"plist"]];
}
static void spotlight_update(void (^edit)(NSMutableArray *items)) {
    NSString *f = spotlight_file();
    NSMutableArray *items = [[NSDictionary dictionaryWithContentsOfFile:f][@"items"] mutableCopy] ?: [NSMutableArray array];
    edit(items);
    [@{ @"items": items } writeToFile:f atomically:YES];
}

@implementation NSUserActivity {
    NSMutableDictionary *_info;
}
- (instancetype)init { return [self initWithActivityType:NSBundle.mainBundle.bundleIdentifier ?: @"isim.activity"]; }
- (instancetype)initWithActivityType:(NSString *)t {
    if ((self = [super init])) { _activityType = [t copy]; _keywords = [NSSet set]; _eligibleForHandoff = YES; }
    return self;
}
- (NSDictionary *)userInfo { return [_info copy]; }
- (void)setUserInfo:(NSDictionary *)u { _info = [u mutableCopy]; }
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)d { if (!_info) _info = [NSMutableDictionary dictionary]; [_info addEntriesFromDictionary:d]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSUserActivity %p> %@ %@", self, _activityType, _title ?: @""]; }
- (NSString *)_isim_indexID { return [@"activity:" stringByAppendingString:_persistentIdentifier ?: [NSString stringWithFormat:@"%@|%@", _activityType, _title ?: @""]]; }
- (void)becomeCurrent {
    id<NSUserActivityDelegate> d = _delegate;
    if (_needsSave && [d respondsToSelector:@selector(userActivityWillSave:)]) { [d userActivityWillSave:self]; _needsSave = NO; }
    if (!_eligibleForSearch) { NSLog(@"isim: user activity %@ is current (not indexed: isEligibleForSearch is false; no Handoff on isim)", _activityType); return; }
    NSDictionary *entry = @{ @"id": [self _isim_indexID], @"title": _title ?: @"", @"kind": @"activity", @"keywords": _keywords.allObjects ?: @[],
                             @"domain": @"", @"activity": [self _isim_plist] };
    spotlight_update(^(NSMutableArray *items) {
        for (NSUInteger i = 0; i < items.count; i++) if ([items[i][@"id"] isEqual:entry[@"id"]]) { [items removeObjectAtIndex:i]; break; }
        [items addObject:entry];
    });
    NSLog(@"isim: user activity %@ “%@” is current and indexed for Spotlight", _activityType, _title ?: @"");
}
- (void)resignCurrent {}
- (void)invalidate {}
+ (void)deleteSavedUserActivitiesWithPersistentIdentifiers:(NSArray *)ids completionHandler:(void (^)(void))handler {
    spotlight_update(^(NSMutableArray *items) {
        NSMutableSet *gone = [NSMutableSet set]; for (NSString *p in ids) [gone addObject:[@"activity:" stringByAppendingString:p]];
        [items filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *b) { return ![gone containsObject:e[@"id"]]; }]];
    });
    if (handler) dispatch_async(dispatch_get_main_queue(), handler);
}
+ (void)deleteAllSavedUserActivitiesWithCompletionHandler:(void (^)(void))handler {
    spotlight_update(^(NSMutableArray *items) {
        [items filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *b) { return ![e[@"kind"] isEqual:@"activity"]; }]];
    });
    if (handler) dispatch_async(dispatch_get_main_queue(), handler);
}
- (NSDictionary *)_isim_plist {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[@"activityType"] = _activityType;
    if (_title) p[@"title"] = _title;
    id info = plist_safe(_info); if (info) p[@"userInfo"] = info;
    if (_webpageURL) p[@"webpageURL"] = _webpageURL.absoluteString;
    if (_referrerURL) p[@"referrerURL"] = _referrerURL.absoluteString;
    if (_targetContentIdentifier) p[@"targetContentIdentifier"] = _targetContentIdentifier;
    if (_persistentIdentifier) p[@"persistentIdentifier"] = _persistentIdentifier;
    if (_keywords.count) p[@"keywords"] = _keywords.allObjects;
    if (_requiredUserInfoKeys.count) p[@"requiredUserInfoKeys"] = _requiredUserInfoKeys.allObjects;
    p[@"eligibleForSearch"] = @(_eligibleForSearch); p[@"eligibleForHandoff"] = @(_eligibleForHandoff); p[@"eligibleForPrediction"] = @(_eligibleForPrediction);
    return p;
}
+ (instancetype)_isim_activityWithPlist:(NSDictionary *)p {
    if (![p isKindOfClass:[NSDictionary class]] || ![p[@"activityType"] isKindOfClass:[NSString class]]) return nil;
    NSUserActivity *a = [[self alloc] initWithActivityType:p[@"activityType"]];
    a.title = p[@"title"];
    if (p[@"userInfo"]) a.userInfo = p[@"userInfo"];
    if (p[@"webpageURL"]) a.webpageURL = [NSURL URLWithString:p[@"webpageURL"]];
    if (p[@"referrerURL"]) a.referrerURL = [NSURL URLWithString:p[@"referrerURL"]];
    a.targetContentIdentifier = p[@"targetContentIdentifier"];
    a.persistentIdentifier = p[@"persistentIdentifier"];
    if (p[@"keywords"]) a.keywords = [NSSet setWithArray:p[@"keywords"]];
    if (p[@"requiredUserInfoKeys"]) a.requiredUserInfoKeys = [NSSet setWithArray:p[@"requiredUserInfoKeys"]];
    a.eligibleForSearch = [p[@"eligibleForSearch"] boolValue]; a.eligibleForHandoff = [p[@"eligibleForHandoff"] boolValue]; a.eligibleForPrediction = [p[@"eligibleForPrediction"] boolValue];
    return a;
}
@end

@implementation NSFileManager (NSAppGroupContainers)
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)group {
    if (!group.length) return nil;
    NSString *dir = [[isim_data_dir() stringByAppendingPathComponent:@"Shared/AppGroup"] stringByAppendingPathComponent:group];
    for (NSString *sub in @[@"", @"Library/Preferences", @"Library/Caches"])
        [self createDirectoryAtPath:[dir stringByAppendingPathComponent:sub] withIntermediateDirectories:YES attributes:nil error:NULL];
    return [NSURL fileURLWithPath:dir isDirectory:YES];
}
@end

static BOOL write_plist(id plist, NSString *path, NSError **error) {
    NSData *d = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    return d && [d writeToFile:path options:NSDataWritingAtomic error:error];
}
@implementation NSDictionary (NSDictionaryPropertyListWriting)
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)a { return write_plist(self, path, NULL); }
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)e { return url.isFileURL && write_plist(self, url.path, e); }
@end
@implementation NSArray (NSArrayPropertyListWriting)
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)a { return write_plist(self, path, NULL); }
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)e { return url.isFileURL && write_plist(self, url.path, e); }
@end
