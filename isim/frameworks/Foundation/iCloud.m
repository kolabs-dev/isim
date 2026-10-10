/* isim Foundation (ARC): iCloud documents simulated locally — download states (evict / start downloading),
 * NSMetadataQuery / NSMetadataItem over the ubiquity containers, NSFileCoordinator / NSFilePresenter.
 * Self-authored; adapted: nothing syncs. A ubiquity container is $ISIM_DATA/Mobile Documents/<container id>
 * (Ubiquity.m). Everything in one counts as uploaded. Evicting moves an item's contents into
 * $ISIM_DATA/Library/.isim-icloud-evicted and leaves the empty file under its name (iOS keeps a dataless file);
 * downloading (startDownloadingUbiquitousItemAtURL:, or a coordinated read) brings the contents back, with
 * ubiquitousItemIsDownloading set meanwhile. Queries poll the containers while they run. Coordination is between
 * the coordinators and presenters of this process. */
#import "isim_foundation.h"
#import <Foundation/NSFileCoordinator.h>
#import <Foundation/NSMetadata.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <sys/stat.h>

/* ================= the local iCloud state ================= */
static NSString *mobile_documents(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Mobile Documents"]; }
static NSString *evicted_store(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/.isim-icloud-evicted"]; }
/* the container directory holding `path`, or nil */
static NSString *container_of(NSString *path) {
    NSString *root = mobile_documents().stringByStandardizingPath, *p = path.stringByStandardizingPath;
    if (![p hasPrefix:[root stringByAppendingString:@"/"]]) return nil;
    NSArray *rest = [[p substringFromIndex:root.length + 1] pathComponents];
    if (!rest.count || [rest[0] isEqualToString:@"KeyValueStore"]) return nil;
    return [root stringByAppendingPathComponent:rest[0]];
}
NSDictionary *isim_ubiquity_item_status(NSString *path) {
    NSString *container = container_of(path);
    if (!container) return nil;
    NSString *ident = container.lastPathComponent;
    NSString *display = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?:
                        ([ident hasPrefix:@"iCloud."] ? [ident substringFromIndex:7] : ident);
    NSMutableDictionary *d = [@{ @"container": ident, @"displayName": display } mutableCopy];
    if ([isim_file_meta(path, @"evicted") boolValue]) d[@"evicted"] = @YES;
    if ([isim_file_meta(path, @"downloading") boolValue]) d[@"downloading"] = @YES;
    if ([isim_file_meta(path, @"excludedFromSync") boolValue]) d[@"excludedFromSync"] = @YES;
    return d;
}
static NSError *cocoa_error(NSInteger code, NSURL *url) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:url ? @{ NSURLErrorKey: url, @"NSFilePath": url.path ?: @"" } : nil];
}
/* the regular files at or under a path */
static NSArray<NSString *> *files_under(NSString *path) {
    BOOL dir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&dir]) return @[];
    if (!dir) return @[path];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *rel in [NSFileManager.defaultManager subpathsOfDirectoryAtPath:path error:NULL]) {
        NSString *f = [path stringByAppendingPathComponent:rel];
        if ([NSFileManager.defaultManager fileExistsAtPath:f isDirectory:&dir] && !dir) [out addObject:f];
    }
    return out;
}
static void download_now(NSString *f) {
    NSString *stored = isim_file_meta(f, @"evictedStore");
    if (stored && [NSFileManager.defaultManager fileExistsAtPath:stored]) {
        [NSFileManager.defaultManager removeItemAtPath:f error:NULL];
        [NSFileManager.defaultManager moveItemAtPath:stored toPath:f error:NULL];
    }
    isim_file_meta_set(f, @"evicted", nil);
    isim_file_meta_set(f, @"evictedStore", nil);
    isim_file_meta_set(f, @"downloading", nil);
}
/* a coordinated read of an evicted item waits for its download (NSFileCoordinator) */
static void ensure_downloaded(NSString *path) {
    if (!container_of(path)) return;
    for (NSString *f in files_under(path)) if ([isim_file_meta(f, @"evicted") boolValue]) download_now(f);
}

@implementation NSFileManager (IsimUbiquity)
- (BOOL)isUbiquitousItemAtURL:(NSURL *)url { return url.isFileURL && container_of(url.path) && [self fileExistsAtPath:url.path]; }
- (BOOL)setUbiquitous:(BOOL)flag itemAtURL:(NSURL *)url destinationURL:(NSURL *)dest error:(NSError **)error {
    if (flag && !container_of(dest.path)) { if (error) *error = cocoa_error(4, dest); return NO; }     /* the destination must be in a container */
    if (!flag && container_of(dest.path)) { if (error) *error = cocoa_error(4, dest); return NO; }
    if (!flag) ensure_downloaded(url.path);
    if (![self moveItemAtURL:url toURL:dest error:error]) return NO;
    return YES;
}
- (BOOL)startDownloadingUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error {
    if (!url.isFileURL || !container_of(url.path)) { if (error) *error = cocoa_error(4, url); return NO; }
    if (![self fileExistsAtPath:url.path]) { if (error) *error = cocoa_error(4, url); return NO; }
    NSMutableArray *pending = [NSMutableArray array];
    for (NSString *f in files_under(url.path)) {
        if (![isim_file_meta(f, @"evicted") boolValue]) continue;
        isim_file_meta_set(f, @"downloading", @YES);
        [pending addObject:f];
    }
    if (pending.count)   /* the "download" finishes shortly after, like a fast network */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            for (NSString *f in pending) if ([isim_file_meta(f, @"downloading") boolValue]) download_now(f);
        });
    return YES;
}
- (BOOL)evictUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error {
    if (!url.isFileURL || !container_of(url.path)) { if (error) *error = cocoa_error(4, url); return NO; }
    if (![self fileExistsAtPath:url.path]) { if (error) *error = cocoa_error(4, url); return NO; }
    [self createDirectoryAtPath:evicted_store() withIntermediateDirectories:YES attributes:nil error:NULL];
    for (NSString *f in files_under(url.path)) {
        if ([isim_file_meta(f, @"evicted") boolValue]) continue;
        NSString *stored = [evicted_store() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        if (![self moveItemAtPath:f toPath:stored error:error]) return NO;
        [self createFileAtPath:f contents:[NSData data] attributes:nil];
        isim_file_meta_set(f, @"evicted", @YES);
        isim_file_meta_set(f, @"evictedStore", stored);
        isim_file_meta_set(f, @"downloading", nil);
    }
    return YES;
}
- (NSURL *)URLForPublishingUbiquitousItemAtURL:(NSURL *)url expirationDate:(NSDate **)outDate error:(NSError **)error {
    if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3328 /* NSFeatureUnsupportedError */
                                        userInfo:@{ NSLocalizedDescriptionKey: @"isim's iCloud is local: items cannot be published", NSURLErrorKey: url ?: [NSNull null] }];
    return nil;
}
@end

/* ================= NSMetadataItem ================= */
NSNotificationName const NSMetadataQueryDidStartGatheringNotification = @"NSMetadataQueryDidStartGatheringNotification",
    NSMetadataQueryGatheringProgressNotification = @"NSMetadataQueryGatheringProgressNotification",
    NSMetadataQueryDidFinishGatheringNotification = @"NSMetadataQueryDidFinishGatheringNotification",
    NSMetadataQueryDidUpdateNotification = @"NSMetadataQueryDidUpdateNotification";
NSString * const NSMetadataQueryUpdateAddedItemsKey = @"kMDQueryUpdateAddedItems", * const NSMetadataQueryUpdateChangedItemsKey = @"kMDQueryUpdateChangedItems",
    * const NSMetadataQueryUpdateRemovedItemsKey = @"kMDQueryUpdateRemovedItems", * const NSMetadataQueryResultContentRelevanceAttribute = @"kMDQueryResultContentRelevance";
NSString * const NSMetadataQueryUbiquitousDocumentsScope = @"NSMetadataQueryUbiquitousDocumentsScope",
    * const NSMetadataQueryUbiquitousDataScope = @"NSMetadataQueryUbiquitousDataScope",
    * const NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope = @"NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope";
NSString * const NSMetadataItemFSNameKey = @"kMDItemFSName", * const NSMetadataItemDisplayNameKey = @"kMDItemDisplayName", * const NSMetadataItemURLKey = @"kMDItemURL",
    * const NSMetadataItemPathKey = @"kMDItemPath", * const NSMetadataItemFSSizeKey = @"kMDItemFSSize", * const NSMetadataItemFSCreationDateKey = @"kMDItemFSCreationDate",
    * const NSMetadataItemFSContentChangeDateKey = @"kMDItemFSContentChangeDate", * const NSMetadataItemContentTypeKey = @"kMDItemContentType",
    * const NSMetadataItemContentTypeTreeKey = @"kMDItemContentTypeTree", * const NSMetadataItemIsUbiquitousKey = @"NSMetadataItemIsUbiquitousKey",
    * const NSMetadataUbiquitousItemHasUnresolvedConflictsKey = @"NSMetadataUbiquitousItemHasUnresolvedConflictsKey",
    * const NSMetadataUbiquitousItemIsDownloadingKey = @"NSMetadataUbiquitousItemIsDownloadingKey", * const NSMetadataUbiquitousItemIsUploadedKey = @"NSMetadataUbiquitousItemIsUploadedKey",
    * const NSMetadataUbiquitousItemIsUploadingKey = @"NSMetadataUbiquitousItemIsUploadingKey", * const NSMetadataUbiquitousItemPercentDownloadedKey = @"NSMetadataUbiquitousItemPercentDownloadedKey",
    * const NSMetadataUbiquitousItemPercentUploadedKey = @"NSMetadataUbiquitousItemPercentUploadedKey",
    * const NSMetadataUbiquitousItemDownloadingStatusKey = @"NSMetadataUbiquitousItemDownloadingStatusKey",
    * const NSMetadataUbiquitousItemDownloadingErrorKey = @"NSMetadataUbiquitousItemDownloadingErrorKey", * const NSMetadataUbiquitousItemUploadingErrorKey = @"NSMetadataUbiquitousItemUploadingErrorKey",
    * const NSMetadataUbiquitousItemDownloadRequestedKey = @"NSMetadataUbiquitousItemDownloadRequestedKey",
    * const NSMetadataUbiquitousItemIsExternalDocumentKey = @"NSMetadataUbiquitousItemIsExternalDocumentKey",
    * const NSMetadataUbiquitousItemContainerDisplayNameKey = @"NSMetadataUbiquitousItemContainerDisplayNameKey",
    * const NSMetadataUbiquitousItemURLInLocalContainerKey = @"NSMetadataUbiquitousItemURLInLocalContainerKey", * const NSMetadataUbiquitousItemIsSharedKey = @"NSMetadataUbiquitousItemIsSharedKey",
    * const NSMetadataUbiquitousItemDownloadingStatusNotDownloaded = @"NSMetadataUbiquitousItemDownloadingStatusNotDownloaded",
    * const NSMetadataUbiquitousItemDownloadingStatusDownloaded = @"NSMetadataUbiquitousItemDownloadingStatusDownloaded",
    * const NSMetadataUbiquitousItemDownloadingStatusCurrent = @"NSMetadataUbiquitousItemDownloadingStatusCurrent";

@implementation NSMetadataItem { NSURL *_url; NSDictionary *_values; }
- (instancetype)initWithURL:(NSURL *)url {
    if (!url.isFileURL || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) return nil;
    if ((self = [super init])) { _url = url; [self _isim_refresh]; }
    return self;
}
/* the attribute values, read now (a query refreshes them when it polls) */
- (BOOL)_isim_refresh {
    NSString *p = _url.path;
    NSDictionary *rv = [_url resourceValuesForKeys:@[NSURLFileSizeKey, NSURLCreationDateKey, NSURLContentModificationDateKey, NSURLTypeIdentifierKey,
                                                     NSURLLocalizedNameKey, NSURLIsDirectoryKey] error:NULL];
    if (!rv) return NO;
    NSDictionary *ubiq = isim_ubiquity_item_status(p);
    NSMutableDictionary *v = [NSMutableDictionary dictionary];
    v[NSMetadataItemFSNameKey] = p.lastPathComponent;
    v[NSMetadataItemDisplayNameKey] = p.lastPathComponent.stringByDeletingPathExtension;
    v[NSMetadataItemURLKey] = _url;
    v[NSMetadataItemPathKey] = p;
    if (rv[NSURLFileSizeKey] && ![isim_file_meta(p, @"evicted") boolValue]) v[NSMetadataItemFSSizeKey] = rv[NSURLFileSizeKey];
    if (rv[NSURLCreationDateKey]) v[NSMetadataItemFSCreationDateKey] = rv[NSURLCreationDateKey];
    if (rv[NSURLContentModificationDateKey]) v[NSMetadataItemFSContentChangeDateKey] = rv[NSURLContentModificationDateKey];
    if (rv[NSURLTypeIdentifierKey]) {
        v[NSMetadataItemContentTypeKey] = rv[NSURLTypeIdentifierKey];
        v[NSMetadataItemContentTypeTreeKey] = @[rv[NSURLTypeIdentifierKey], [rv[NSURLIsDirectoryKey] boolValue] ? @"public.directory" : @"public.data", @"public.item"];
    }
    v[NSMetadataItemIsUbiquitousKey] = @(ubiq != nil);
    if (ubiq) {
        BOOL evicted = [ubiq[@"evicted"] boolValue], downloading = [ubiq[@"downloading"] boolValue];
        v[NSMetadataUbiquitousItemDownloadingStatusKey] = evicted ? NSMetadataUbiquitousItemDownloadingStatusNotDownloaded : NSMetadataUbiquitousItemDownloadingStatusCurrent;
        v[NSMetadataUbiquitousItemIsDownloadingKey] = @(downloading);
        v[NSMetadataUbiquitousItemDownloadRequestedKey] = @(downloading);
        v[NSMetadataUbiquitousItemPercentDownloadedKey] = @(evicted ? 0.0 : 100.0);
        v[NSMetadataUbiquitousItemIsUploadedKey] = @YES;
        v[NSMetadataUbiquitousItemIsUploadingKey] = @NO;
        v[NSMetadataUbiquitousItemPercentUploadedKey] = @100.0;
        v[NSMetadataUbiquitousItemHasUnresolvedConflictsKey] = @NO;
        v[NSMetadataUbiquitousItemIsExternalDocumentKey] = @NO;
        v[NSMetadataUbiquitousItemIsSharedKey] = @NO;
        v[NSMetadataUbiquitousItemContainerDisplayNameKey] = ubiq[@"displayName"];
    }
    BOOL changed = !_values || ![v isEqualToDictionary:_values];
    _values = v;
    return changed;
}
- (NSURL *)_isim_url { return _url; }
- (id)valueForAttribute:(NSString *)key { return _values[key]; }
- (NSDictionary *)valuesForAttributes:(NSArray<NSString *> *)keys {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in keys) if (_values[k]) d[k] = _values[k];
    return d;
}
- (NSArray<NSString *> *)attributes { return _values.allKeys; }
/* predicates and sort descriptors use KVC: an attribute name is a key */
- (id)valueForKey:(NSString *)key { id v = _values[key]; return v ?: ([key hasPrefix:@"kMD"] || [key hasPrefix:@"NSMetadata"] ? nil : [super valueForKey:key]); }
- (id)valueForUndefinedKey:(NSString *)key { return nil; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSMetadataItem %p %@>", self, _url.path]; }
@end

@implementation NSMetadataQueryAttributeValueTuple
- (instancetype)initWithIsimAttribute:(NSString *)a value:(id)v count:(NSUInteger)n {
    if ((self = [super init])) { _attribute = [a copy]; _value = v; _count = n; }
    return self;
}
@end
@implementation NSMetadataQueryResultGroup
- (instancetype)initWithIsimAttribute:(NSString *)a value:(id)v results:(NSArray *)r subgroups:(NSArray *)sub {
    if ((self = [super init])) { _attribute = [a copy]; _value = v; _results = [r copy]; _subgroups = [sub copy]; }
    return self;
}
- (NSUInteger)resultCount { return _results.count; }
- (id)resultAtIndex:(NSUInteger)idx { return _results[idx]; }
@end

/* ================= NSMetadataQuery ================= */
@implementation NSMetadataQuery {
    NSMutableDictionary<NSString *, NSMetadataItem *> *_items;    /* by path */
    NSArray *_results;
    NSRunLoop *_runLoop;
    dispatch_source_t _poll;
    NSInteger _disabled;
    BOOL _started, _gathering, _stopped, _pendingUpdate;
}
- (instancetype)init {
    if ((self = [super init])) {
        _sortDescriptors = @[]; _valueListAttributes = @[]; _notificationBatchingInterval = 1.0;
        _searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope];
        _items = [NSMutableDictionary dictionary]; _results = @[];
    }
    return self;
}
- (void)dealloc { if (_poll) dispatch_source_cancel(_poll); }
- (BOOL)isStarted { return _started; }
- (BOOL)isGathering { return _gathering; }
- (BOOL)isStopped { return _stopped; }
/* the directories searched: container Documents for the documents scope, the rest of the container for data */
- (NSArray<NSString *> *)_isim_roots:(NSArray<NSString *> **)exclusions {
    NSMutableArray *roots = [NSMutableArray array], *excluded = [NSMutableArray array];
    NSMutableArray *containers = [NSMutableArray array];
    NSArray *ids = NSBundle.mainBundle.infoDictionary[@"ISIMUbiquityContainerIdentifiers"];
    if ([ids isKindOfClass:[NSArray class]] && [ids count]) for (NSString *i in ids) { NSURL *u = [NSFileManager.defaultManager URLForUbiquityContainerIdentifier:i]; if (u) [containers addObject:u.path]; }
    else { NSURL *u = [NSFileManager.defaultManager URLForUbiquityContainerIdentifier:nil]; if (u) [containers addObject:u.path]; }
    for (id scope in _searchScopes) {
        if ([scope isEqual:NSMetadataQueryUbiquitousDocumentsScope]) for (NSString *c in containers) [roots addObject:[c stringByAppendingPathComponent:@"Documents"]];
        else if ([scope isEqual:NSMetadataQueryUbiquitousDataScope]) for (NSString *c in containers) { [roots addObject:c]; [excluded addObject:[c stringByAppendingPathComponent:@"Documents"]]; }
        else if ([scope isKindOfClass:[NSURL class]] && [scope isFileURL]) [roots addObject:[scope path]];
        else if ([scope isKindOfClass:[NSString class]] && [scope hasPrefix:@"/"]) [roots addObject:scope];
    }
    if ([_searchScopes containsObject:NSMetadataQueryUbiquitousDocumentsScope]) [excluded removeAllObjects];   /* both scopes: everything */
    if (exclusions) *exclusions = excluded;
    return roots;
}
- (NSArray<NSString *> *)_isim_scan {
    NSArray *excluded = nil;
    NSMutableOrderedSet *paths = [NSMutableOrderedSet orderedSet];
    for (NSString *root in [self _isim_roots:&excluded]) {
        for (NSString *rel in [NSFileManager.defaultManager subpathsOfDirectoryAtPath:root error:NULL]) {
            if ([rel.lastPathComponent hasPrefix:@"."]) continue;
            NSString *p = [root stringByAppendingPathComponent:rel];
            BOOL skip = NO;
            for (NSString *x in excluded) if ([p isEqualToString:x] || [p hasPrefix:[x stringByAppendingString:@"/"]]) skip = YES;
            if (!skip) [paths addObject:p];
        }
    }
    for (NSURL *u in _searchItems) if ([u isKindOfClass:[NSURL class]] && u.isFileURL) [paths addObject:u.path];
    return paths.array;
}
- (BOOL)_isim_matches:(NSMetadataItem *)item {
    if (!_predicate) return YES;
    @try { return [_predicate evaluateWithObject:item]; } @catch (id e) { return NO; }
}
- (void)_isim_resort {
    NSArray *all = [_items.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSMetadataItem *i, NSDictionary *b) { return [self _isim_matches:i]; }]];
    if (_sortDescriptors.count) all = [all sortedArrayUsingDescriptors:_sortDescriptors];
    else all = [all sortedArrayUsingComparator:^NSComparisonResult(NSMetadataItem *a, NSMetadataItem *b) { return [[a valueForAttribute:NSMetadataItemPathKey] compare:[b valueForAttribute:NSMetadataItemPathKey]]; }];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:all.count];
    for (NSMetadataItem *i in all) {
        id r = i;
        if ([_delegate respondsToSelector:@selector(metadataQuery:replacementObjectForResultObject:)]) r = [_delegate metadataQuery:self replacementObjectForResultObject:i] ?: i;
        [out addObject:r];
    }
    _results = out;
}
/* rescan; returns @{added, changed, removed} (NSMetadataItems that match the predicate) */
- (NSDictionary *)_isim_update {
    NSArray *now = [self _isim_scan];
    NSMutableArray *added = [NSMutableArray array], *changed = [NSMutableArray array], *removed = [NSMutableArray array];
    NSSet *nowSet = [NSSet setWithArray:now];
    for (NSString *p in _items.allKeys) if (![nowSet containsObject:p]) { if ([self _isim_matches:_items[p]]) [removed addObject:_items[p]]; [_items removeObjectForKey:p]; }
    for (NSString *p in now) {
        NSMetadataItem *i = _items[p];
        if (!i) {
            i = [[NSMetadataItem alloc] initWithURL:[NSURL fileURLWithPath:p]];
            if (!i) continue;
            _items[p] = i;
            if ([self _isim_matches:i]) [added addObject:i];
        } else {
            BOOL matched = [self _isim_matches:i];
            if ([i _isim_refresh]) { BOOL m = [self _isim_matches:i]; if (m && matched) [changed addObject:i]; else if (m) [added addObject:i]; else if (matched) [removed addObject:i]; }
        }
    }
    [self _isim_resort];
    return @{ NSMetadataQueryUpdateAddedItemsKey: added, NSMetadataQueryUpdateChangedItemsKey: changed, NSMetadataQueryUpdateRemovedItemsKey: removed };
}
- (void)_isim_post:(NSNotificationName)name userInfo:(NSDictionary *)info {
    NSNotification *n = [NSNotification notificationWithName:name object:self userInfo:info];
    if (_operationQueue) [_operationQueue addOperationWithBlock:^{ [NSNotificationCenter.defaultCenter postNotification:n]; }];
    else [NSNotificationCenter.defaultCenter postNotification:n];
}
/* on the starting thread's run loop (or the operation queue): gathering, then updates every batching interval */
- (BOOL)startQuery {
    if (_started && !_stopped) return NO;
    _started = YES; _stopped = NO; _gathering = YES;
    _runLoop = NSRunLoop.currentRunLoop;
    __weak NSMetadataQuery *weak = self;
    void (^gather)(void) = ^{
        NSMetadataQuery *q = weak;
        if (!q || q->_stopped) return;
        [q _isim_post:NSMetadataQueryDidStartGatheringNotification userInfo:nil];
        [q _isim_update];
        q->_gathering = NO;
        [q _isim_post:NSMetadataQueryDidFinishGatheringNotification userInfo:nil];
    };
    if (_operationQueue) [_operationQueue addOperationWithBlock:gather]; else [_runLoop performInModes:@[NSDefaultRunLoopMode] block:gather];
    double interval = MAX(0.2, MIN(_notificationBatchingInterval, 1.0));
    _poll = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(_poll, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), (uint64_t)(interval * NSEC_PER_SEC), (uint64_t)(0.05 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(_poll, ^{
        NSMetadataQuery *q = weak;
        if (!q || q->_stopped || q->_gathering) return;
        void (^tick)(void) = ^{
            NSMetadataQuery *q2 = weak;
            if (!q2 || q2->_stopped || q2->_disabled > 0) { if (q2) q2->_pendingUpdate = YES; return; }
            NSDictionary *u = [q2 _isim_update];
            if ([u[NSMetadataQueryUpdateAddedItemsKey] count] + [u[NSMetadataQueryUpdateChangedItemsKey] count] + [u[NSMetadataQueryUpdateRemovedItemsKey] count])
                [q2 _isim_post:NSMetadataQueryDidUpdateNotification userInfo:u];
        };
        if (q->_operationQueue) [q->_operationQueue addOperationWithBlock:tick]; else [q->_runLoop performInModes:@[NSDefaultRunLoopMode] block:tick];
    });
    dispatch_resume(_poll);
    return YES;
}
- (void)stopQuery {
    _stopped = YES; _gathering = NO;
    if (_poll) { dispatch_source_cancel(_poll); _poll = nil; }
}
- (void)disableUpdates { _disabled++; }
- (void)enableUpdates { if (_disabled > 0) _disabled--; }
- (NSUInteger)resultCount { return _results.count; }
- (id)resultAtIndex:(NSUInteger)idx { return _results[idx]; }
- (NSArray *)results { return [_results copy]; }
- (NSUInteger)indexOfResult:(id)result { return [_results indexOfObject:result]; }
- (void)enumerateResultsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, BOOL *))block { [_results enumerateObjectsUsingBlock:block]; }
- (id)valueOfAttribute:(NSString *)attr forResultAtIndex:(NSUInteger)idx {
    id r = _results[idx];
    id v = [r isKindOfClass:[NSMetadataItem class]] ? [r valueForAttribute:attr] : [r valueForKey:attr];
    if ([_delegate respondsToSelector:@selector(metadataQuery:replacementValueForAttribute:value:)]) v = [_delegate metadataQuery:self replacementValueForAttribute:attr value:v];
    return v;
}
- (NSDictionary *)valueLists {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *attr in _valueListAttributes) {
        NSCountedSet *counts = [NSCountedSet set];
        for (NSUInteger i = 0; i < _results.count; i++) { id v = [self valueOfAttribute:attr forResultAtIndex:i]; if (v) [counts addObject:v]; }
        NSMutableArray *tuples = [NSMutableArray array];
        for (id v in counts) [tuples addObject:[[NSMetadataQueryAttributeValueTuple alloc] initWithIsimAttribute:attr value:v count:[counts countForObject:v]]];
        out[attr] = tuples;
    }
    return out;
}
- (NSArray *)_isim_group:(NSArray *)results by:(NSArray<NSString *> *)attrs {
    if (!attrs.count) return @[];
    NSString *attr = attrs[0];
    NSMutableArray *order = [NSMutableArray array];
    NSMutableDictionary *buckets = [NSMutableDictionary dictionary];
    for (id r in results) {
        id v = ([r isKindOfClass:[NSMetadataItem class]] ? [r valueForAttribute:attr] : [r valueForKey:attr]) ?: [NSNull null];
        if (!buckets[v]) { buckets[v] = [NSMutableArray array]; [order addObject:v]; }
        [buckets[v] addObject:r];
    }
    NSMutableArray *groups = [NSMutableArray array];
    NSArray *rest = [attrs subarrayWithRange:NSMakeRange(1, attrs.count - 1)];
    for (id v in order)
        [groups addObject:[[NSMetadataQueryResultGroup alloc] initWithIsimAttribute:attr value:v results:buckets[v]
                                                                             subgroups:rest.count ? [self _isim_group:buckets[v] by:rest] : nil]];
    return groups;
}
- (NSArray *)groupedResults { return [self _isim_group:_results by:_groupingAttributes]; }
@end

/* ================= NSFileCoordinator ================= */
@implementation NSFileAccessIntent { BOOL _writing; NSUInteger _options; }
+ (instancetype)readingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)o { NSFileAccessIntent *i = [self new]; i->_URL = url; i->_options = o; return i; }
+ (instancetype)writingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)o { NSFileAccessIntent *i = [self new]; i->_URL = url; i->_writing = YES; i->_options = o; return i; }
- (BOOL)_isim_writing { return _writing; }
- (NSUInteger)_isim_options { return _options; }
@end

/* readers / writer per item: a writer excludes accesses to the item and to items inside or above it */
static pthread_mutex_t coord_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t coord_cond = PTHREAD_COND_INITIALIZER;
static NSMutableArray<NSArray *> *coord_active;          /* @[path, @(writing)] */
static NSHashTable<id<NSFilePresenter>> *presenters;
static BOOL related(NSString *a, NSString *b) {
    return [a isEqualToString:b] || [a hasPrefix:[b stringByAppendingString:@"/"]] || [b hasPrefix:[a stringByAppendingString:@"/"]];
}
static void coord_acquire(NSArray<NSString *> *paths, NSArray<NSNumber *> *writing) {
    pthread_mutex_lock(&coord_lock);
    if (!coord_active) coord_active = [NSMutableArray array];
    for (;;) {
        BOOL blocked = NO;
        for (NSUInteger i = 0; i < paths.count && !blocked; i++)
            for (NSArray *a in coord_active)
                if (related(a[0], paths[i]) && ([a[1] boolValue] || writing[i].boolValue)) { blocked = YES; break; }
        if (!blocked) break;
        pthread_cond_wait(&coord_cond, &coord_lock);
    }
    for (NSUInteger i = 0; i < paths.count; i++) [coord_active addObject:@[paths[i], writing[i]]];
    pthread_mutex_unlock(&coord_lock);
}
static void coord_release(NSArray<NSString *> *paths, NSArray<NSNumber *> *writing) {
    pthread_mutex_lock(&coord_lock);
    for (NSUInteger i = 0; i < paths.count; i++) {
        NSUInteger k = [coord_active indexOfObject:@[paths[i], writing[i]]];
        if (k != NSNotFound) [coord_active removeObjectAtIndex:k];
    }
    pthread_cond_broadcast(&coord_cond);
    pthread_mutex_unlock(&coord_lock);
}
static NSArray<id<NSFilePresenter>> *presenters_for(NSString *path, id<NSFilePresenter> except) {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized ([NSFileCoordinator class]) {
        for (id<NSFilePresenter> p in presenters.allObjects) {
            if (p == except) continue;
            NSString *pp = p.presentedItemURL.path.stringByStandardizingPath;
            if (pp && related(pp, path)) [out addObject:p];
        }
    }
    return out;
}
/* run on a presenter's queue and wait (bounded) for the presenter to call back */
static void ask(id<NSFilePresenter> p, void (^body)(void (^done)(void))) {
    NSOperationQueue *q = p.presentedItemOperationQueue;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    void (^run)(void) = ^{ body(^{ dispatch_semaphore_signal(sem); }); };
    if (!q || q == NSOperationQueue.currentQueue) run(); else [q addOperationWithBlock:run];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
}
static void tell(id<NSFilePresenter> p, void (^body)(void)) {
    NSOperationQueue *q = p.presentedItemOperationQueue;
    if (q) [q addOperationWithBlock:body]; else body();
}

@implementation NSFileCoordinator { __weak id<NSFilePresenter> _presenter; BOOL _cancelled; }
+ (void)addFilePresenter:(id<NSFilePresenter>)p {
    @synchronized (self) { if (!presenters) presenters = [NSHashTable weakObjectsHashTable]; [presenters addObject:p]; }
}
+ (void)removeFilePresenter:(id<NSFilePresenter>)p { @synchronized (self) { [presenters removeObject:p]; } }
+ (NSArray<id<NSFilePresenter>> *)filePresenters { @synchronized (self) { return presenters.allObjects ?: @[]; } }
- (instancetype)init { return [self initWithFilePresenter:nil]; }
- (instancetype)initWithFilePresenter:(id<NSFilePresenter>)p {
    if ((self = [super init])) { _presenter = p; _purposeIdentifier = NSUUID.UUID.UUIDString; }
    return self;
}
- (void)cancel { _cancelled = YES; }
- (NSError *)_isim_cancelledError { return [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]; }

/* before: presenters save their changes; a writer also gets the item relinquished (and deletions accommodated) */
- (void)_isim_willAccess:(NSString *)path writing:(BOOL)writing options:(NSUInteger)options {
    for (id<NSFilePresenter> p in presenters_for(path, _presenter)) {
        if ([p respondsToSelector:@selector(savePresentedItemChangesWithCompletionHandler:)])
            ask(p, ^(void (^done)(void)) { [p savePresentedItemChangesWithCompletionHandler:^(NSError *e) { done(); }]; });
        if (writing && (options & NSFileCoordinatorWritingForDeleting) && [p respondsToSelector:@selector(accommodatePresentedItemDeletionWithCompletionHandler:)] &&
            [p.presentedItemURL.path.stringByStandardizingPath isEqualToString:path])
            ask(p, ^(void (^done)(void)) { [p accommodatePresentedItemDeletionWithCompletionHandler:^(NSError *e) { done(); }]; });
        else if (writing && [p respondsToSelector:@selector(relinquishPresentedItemToWriter:)])
            ask(p, ^(void (^done)(void)) { [p relinquishPresentedItemToWriter:^(void (^reacquirer)(void)) { done(); if (reacquirer) tell(p, reacquirer); }]; });
        else if (!writing && [p respondsToSelector:@selector(relinquishPresentedItemToReader:)])
            ask(p, ^(void (^done)(void)) { [p relinquishPresentedItemToReader:^(void (^reacquirer)(void)) { done(); if (reacquirer) tell(p, reacquirer); }]; });
    }
}
/* after a write: presenters of the item, and of the directory around it, hear that it changed */
- (void)_isim_didWrite:(NSString *)path existed:(BOOL)existed {
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path];
    NSURL *url = [NSURL fileURLWithPath:path];
    for (id<NSFilePresenter> p in presenters_for(path, _presenter)) {
        NSString *pp = p.presentedItemURL.path.stringByStandardizingPath;
        if ([pp isEqualToString:path]) { if (exists && [p respondsToSelector:@selector(presentedItemDidChange)]) tell(p, ^{ [p presentedItemDidChange]; }); }
        else if ([path hasPrefix:[pp stringByAppendingString:@"/"]]) {
            if (exists && !existed && [p respondsToSelector:@selector(presentedSubitemDidAppearAtURL:)]) tell(p, ^{ [p presentedSubitemDidAppearAtURL:url]; });
            else if (exists && [p respondsToSelector:@selector(presentedSubitemDidChangeAtURL:)]) tell(p, ^{ [p presentedSubitemDidChangeAtURL:url]; });
        }
    }
}
- (void)_isim_coordinate:(NSArray<NSURL *> *)urls writing:(NSArray<NSNumber *> *)writing options:(NSArray<NSNumber *> *)options error:(NSError **)err
                accessor:(void (NS_NOESCAPE ^)(NSArray<NSURL *> *))accessor {
    if (_cancelled) { if (err) *err = [self _isim_cancelledError]; return; }
    NSMutableArray *paths = [NSMutableArray array];
    NSMutableArray<NSURL *> *resolved = [NSMutableArray array];
    for (NSUInteger i = 0; i < urls.count; i++) {
        NSURL *u = urls[i];
        if (!writing[i].boolValue && (options[i].unsignedIntegerValue & NSFileCoordinatorReadingResolvesSymbolicLink)) u = u.URLByResolvingSymlinksInPath;
        [resolved addObject:u];
        [paths addObject:u.path.stringByStandardizingPath ?: @""];
    }
    for (NSUInteger i = 0; i < paths.count; i++) {
        [self _isim_willAccess:paths[i] writing:writing[i].boolValue options:options[i].unsignedIntegerValue];
        if (!writing[i].boolValue && !(options[i].unsignedIntegerValue & NSFileCoordinatorReadingImmediatelyAvailableMetadataOnly)) ensure_downloaded(paths[i]);
    }
    NSMutableArray *existed = [NSMutableArray array];
    for (NSString *p in paths) [existed addObject:@([NSFileManager.defaultManager fileExistsAtPath:p])];
    coord_acquire(paths, writing);
    @try { accessor(resolved); }
    @finally { coord_release(paths, writing); }
    for (NSUInteger i = 0; i < paths.count; i++) if (writing[i].boolValue) [self _isim_didWrite:paths[i] existed:[existed[i] boolValue]];
}
- (void)coordinateReadingItemAtURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)o error:(NSError **)err byAccessor:(void (NS_NOESCAPE ^)(NSURL *))reader {
    [self _isim_coordinate:@[url] writing:@[@NO] options:@[@(o)] error:err accessor:^(NSArray<NSURL *> *u) { reader(u[0]); }];
}
- (void)coordinateWritingItemAtURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)o error:(NSError **)err byAccessor:(void (NS_NOESCAPE ^)(NSURL *))writer {
    [self _isim_coordinate:@[url] writing:@[@YES] options:@[@(o)] error:err accessor:^(NSArray<NSURL *> *u) { writer(u[0]); }];
}
- (void)coordinateReadingItemAtURL:(NSURL *)r options:(NSFileCoordinatorReadingOptions)ro writingItemAtURL:(NSURL *)w options:(NSFileCoordinatorWritingOptions)wo
                             error:(NSError **)err byAccessor:(void (NS_NOESCAPE ^)(NSURL *, NSURL *))rw {
    [self _isim_coordinate:@[r, w] writing:@[@NO, @YES] options:@[@(ro), @(wo)] error:err accessor:^(NSArray<NSURL *> *u) { rw(u[0], u[1]); }];
}
- (void)coordinateWritingItemAtURL:(NSURL *)a options:(NSFileCoordinatorWritingOptions)ao writingItemAtURL:(NSURL *)b options:(NSFileCoordinatorWritingOptions)bo
                             error:(NSError **)err byAccessor:(void (NS_NOESCAPE ^)(NSURL *, NSURL *))w {
    [self _isim_coordinate:@[a, b] writing:@[@YES, @YES] options:@[@(ao), @(bo)] error:err accessor:^(NSArray<NSURL *> *u) { w(u[0], u[1]); }];
}
- (void)prepareForReadingItemsAtURLs:(NSArray<NSURL *> *)readingURLs options:(NSFileCoordinatorReadingOptions)ro writingItemsAtURLs:(NSArray<NSURL *> *)writingURLs
                             options:(NSFileCoordinatorWritingOptions)wo error:(NSError **)err byAccessor:(void (NS_NOESCAPE ^)(void (^)(void)))batch {
    if (_cancelled) { if (err) *err = [self _isim_cancelledError]; return; }
    for (NSURL *u in readingURLs) ensure_downloaded(u.path);
    batch(^{});   /* nothing is held for the batch: each coordinated access inside it coordinates itself */
}
- (void)coordinateAccessWithIntents:(NSArray<NSFileAccessIntent *> *)intents queue:(NSOperationQueue *)queue byAccessor:(void (^)(NSError *))accessor {
    NSMutableArray *urls = [NSMutableArray array], *writing = [NSMutableArray array], *options = [NSMutableArray array];
    for (NSFileAccessIntent *i in intents) { [urls addObject:i.URL]; [writing addObject:@([i _isim_writing])]; [options addObject:@([i _isim_options])]; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (self->_cancelled) { [queue addOperationWithBlock:^{ accessor([self _isim_cancelledError]); }]; return; }
        NSError *err = nil;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        [self _isim_coordinate:urls writing:writing options:options error:&err accessor:^(NSArray<NSURL *> *u) {
            [queue addOperationWithBlock:^{ accessor(nil); dispatch_semaphore_signal(finished); }];
            dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);     /* the access lasts while the accessor runs */
        }];
        if (err) [queue addOperationWithBlock:^{ accessor(err); }];
    });
}
- (void)itemAtURL:(NSURL *)oldURL willMoveToURL:(NSURL *)newURL {}
- (void)itemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL {
    NSString *from = oldURL.path.stringByStandardizingPath;
    for (id<NSFilePresenter> p in presenters_for(from, _presenter)) {
        NSString *pp = p.presentedItemURL.path.stringByStandardizingPath;
        if ([pp isEqualToString:from] && [p respondsToSelector:@selector(presentedItemDidMoveToURL:)]) tell(p, ^{ [p presentedItemDidMoveToURL:newURL]; });
        else if ([from hasPrefix:[pp stringByAppendingString:@"/"]] && [p respondsToSelector:@selector(presentedSubitemAtURL:didMoveToURL:)]) tell(p, ^{ [p presentedSubitemAtURL:oldURL didMoveToURL:newURL]; });
    }
    isim_file_meta_move(oldURL.path, newURL.path);
}
- (void)itemAtURL:(NSURL *)url didChangeUbiquityAttributes:(NSSet<NSURLResourceKey> *)attributes {
    for (id<NSFilePresenter> p in presenters_for(url.path.stringByStandardizingPath, _presenter))
        if ([p respondsToSelector:@selector(presentedItemDidChangeUbiquityAttributes:)]) tell(p, ^{ [p presentedItemDidChangeUbiquityAttributes:attributes]; });
}
@end
