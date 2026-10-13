/* isim Core Data (ARC): NSFetchedResultsController (sections by key path, change tracking from the context's
 * ObjectsDidChange notifications with per-object/per-section delegate callbacks, or a diffable snapshot) and
 * a diffable snapshot (UIKit's NSDiffableDataSourceSnapshotReference). */
#import "CoreDataPrivate.h"

/* UIKit's NSIndexPath (section, item) additions, without linking UIKit */
static NSIndexPath *IP(NSUInteger item, NSUInteger section) { NSUInteger ix[2] = { section, item }; return [NSIndexPath indexPathWithIndexes:ix length:2]; }
static NSInteger SEC(NSIndexPath *p) { return (NSInteger)[p indexAtPosition:0]; }
static NSInteger ITEM(NSIndexPath *p) { return (NSInteger)[p indexAtPosition:1]; }

/* the snapshot handed to the delegate: UIKit's NSDiffableDataSourceSnapshotReference (looked up at run time: Core Data
   does not link UIKit) */
@protocol IsimSnapshotReference <NSObject>
- (void)appendItemsWithIdentifiers:(NSArray *)identifiers intoSectionWithIdentifier:(id)sectionIdentifier;
- (void)reloadItemsWithIdentifiers:(NSArray *)identifiers;
@end

@interface CDSectionInfo : NSObject <NSFetchedResultsSectionInfo>
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *indexTitle;
@property (nonatomic, strong) NSMutableArray *objectList;
@end
@implementation CDSectionInfo
- (NSUInteger)numberOfObjects { return _objectList.count; }
- (NSArray *)objects { return [_objectList copy]; }
@end

@implementation NSFetchedResultsController {
    NSArray *_objects;
    NSArray<CDSectionInfo *> *_sections;
    id _observer;
    BOOL _fetched;
}
- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest managedObjectContext:(NSManagedObjectContext *)context sectionNameKeyPath:(NSString *)sectionNameKeyPath cacheName:(NSString *)name {
    if ((self = [super init])) { _fetchRequest = fetchRequest; _managedObjectContext = context; _sectionNameKeyPath = [sectionNameKeyPath copy]; _cacheName = [name copy]; }
    return self;
}
- (void)dealloc { if (_observer) [[NSNotificationCenter defaultCenter] removeObserver:_observer]; }
+ (void)deleteCacheWithName:(NSString *)name {}
- (NSString *)_sectionNameFor:(id)o {
    if (!_sectionNameKeyPath) return @"";
    id v = [o valueForKeyPath:_sectionNameKeyPath];
    if (!v || v == [NSNull null]) return @"";
    return [v isKindOfClass:[NSString class]] ? v : [v description];
}
- (NSArray<CDSectionInfo *> *)_sectionsFor:(NSArray *)objects {
    NSMutableArray *out = [NSMutableArray array];
    CDSectionInfo *cur = nil;
    NSMutableDictionary *byName = [NSMutableDictionary dictionary];
    for (id o in objects) {
        NSString *n = [self _sectionNameFor:o];
        if (!cur || ![cur.name isEqualToString:n]) {
            cur = byName[n];
            if (!cur) {
                cur = [CDSectionInfo new]; cur.name = n; cur.objectList = [NSMutableArray array];
                cur.indexTitle = [self sectionIndexTitleForSectionName:n];
                byName[n] = cur; [out addObject:cur];
            }
        }
        [cur.objectList addObject:o];
    }
    return out;
}
- (NSArray *)_fetch:(NSError **)error {
    __block NSArray *r = nil;
    __block NSError *err = nil;
    NSManagedObjectContext *ctx = _managedObjectContext;
    [ctx performBlockAndWait:^{ NSError *e = nil; r = [ctx executeFetchRequest:self->_fetchRequest error:&e]; err = e; }];
    if (!r && error) *error = err;
    return r;
}
- (BOOL)performFetch:(NSError **)error {
    NSArray *r = [self _fetch:error];
    if (!r) return NO;
    _objects = r;
    _sections = [self _sectionsFor:r];
    _fetched = YES;
    if (!_observer) {
        __weak NSFetchedResultsController *weakSelf = self;
        _observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:_managedObjectContext queue:nil
                                                                  usingBlock:^(NSNotification *n) { [weakSelf _contextChanged:n]; }];
    }
    return YES;
}
- (NSArray *)fetchedObjects { return _fetched ? _objects : nil; }
- (NSArray *)sections { return _fetched ? _sections : nil; }
- (id)objectAtIndexPath:(NSIndexPath *)ip {
    if ((NSUInteger)SEC(ip) >= _sections.count || (NSUInteger)ITEM(ip) >= _sections[SEC(ip)].objectList.count) {
        [NSException raise:NSRangeException format:@"no object at index %ld in section at index %ld", (long)ITEM(ip), (long)SEC(ip)];
        return nil;
    }
    return _sections[SEC(ip)].objectList[ITEM(ip)];
}
- (NSIndexPath *)indexPathForObject:(id)o {
    for (NSUInteger s = 0; s < _sections.count; s++) {
        NSUInteger i = [_sections[s].objectList indexOfObjectIdenticalTo:o];
        if (i != NSNotFound) return IP(i, s);
    }
    return nil;
}
- (NSString *)sectionIndexTitleForSectionName:(NSString *)name {
    id<NSFetchedResultsControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(controller:sectionIndexTitleForSectionName:)]) return [d controller:self sectionIndexTitleForSectionName:name];
    return name.length ? [name substringToIndex:1].uppercaseString : nil;
}
- (NSArray<NSString *> *)sectionIndexTitles {
    NSMutableArray *t = [NSMutableArray array];
    for (CDSectionInfo *s in _sections) if (s.indexTitle && ![t containsObject:s.indexTitle]) [t addObject:s.indexTitle];
    return t;
}
- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)idx {
    for (NSUInteger i = 0; i < _sections.count; i++) if ([_sections[i].indexTitle isEqualToString:title]) return (NSInteger)i;
    return NSNotFound;
}

- (BOOL)_relevant:(NSNotification *)n {
    NSDictionary *u = n.userInfo;
    if (u[NSInvalidatedAllObjectsKey]) return YES;
    NSEntityDescription *e = [_fetchRequest _cd_entityInContext:_managedObjectContext];
    for (NSString *k in @[NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSRefreshedObjectsKey, NSInvalidatedObjectsKey])
        for (NSManagedObject *o in u[k]) if (!e || [o.entity isKindOfEntity:e]) return YES;
    return NO;
}
- (void)_contextChanged:(NSNotification *)n {
    if (!_fetched || ![self _relevant:n]) return;
    NSArray *oldObjects = _objects;
    NSArray<CDSectionInfo *> *oldSections = _sections;
    NSArray *r = [self _fetch:NULL];
    if (!r) return;
    _objects = r;
    _sections = [self _sectionsFor:r];
    NSMutableSet *updated = [NSMutableSet set];
    for (NSString *k in @[NSUpdatedObjectsKey, NSRefreshedObjectsKey]) [updated unionSet:n.userInfo[k] ?: [NSSet set]];
    id<NSFetchedResultsControllerDelegate> d = _delegate;
    if (!d) return;
    if ([d respondsToSelector:@selector(controller:didChangeContentWithSnapshot:)]) {
        id<IsimSnapshotReference> snap = [[NSClassFromString(@"NSDiffableDataSourceSnapshotReference") alloc] init];
        if (!snap) return;
        for (CDSectionInfo *s in _sections) {
            NSMutableArray *ids = [NSMutableArray array];
            for (NSManagedObject *o in s.objectList) [ids addObject:o.objectID];
            [snap appendItemsWithIdentifiers:ids intoSectionWithIdentifier:s.name];
        }
        NSMutableArray *reloaded = [NSMutableArray array];
        for (NSManagedObject *o in updated) if ([r containsObject:o] && [oldObjects containsObject:o]) [reloaded addObject:o.objectID];
        if (reloaded.count) [snap reloadItemsWithIdentifiers:reloaded];
        [d controller:self didChangeContentWithSnapshot:(NSDiffableDataSourceSnapshotReference *)snap];
        return;
    }
    BOOL objCB = [d respondsToSelector:@selector(controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:)];
    BOOL secCB = [d respondsToSelector:@selector(controller:didChangeSection:atIndex:forChangeType:)];
    NSMutableArray *changes = [NSMutableArray array];   /* (object, old ip, type, new ip) */
    NSMutableArray *secChanges = [NSMutableArray array];
    NSMutableArray *oldNames = [NSMutableArray array], *newNames = [NSMutableArray array];
    for (CDSectionInfo *s in oldSections) [oldNames addObject:s.name];
    for (CDSectionInfo *s in _sections) [newNames addObject:s.name];
    for (NSUInteger i = 0; i < oldSections.count; i++) if (![newNames containsObject:oldNames[i]]) [secChanges addObject:@[oldSections[i], @(i), @(NSFetchedResultsChangeDelete)]];
    for (NSUInteger i = 0; i < _sections.count; i++) if (![oldNames containsObject:newNames[i]]) [secChanges addObject:@[_sections[i], @(i), @(NSFetchedResultsChangeInsert)]];
    NSIndexPath *(^oldPath)(id) = ^NSIndexPath *(id o) {
        for (NSUInteger s = 0; s < oldSections.count; s++) { NSUInteger i = [oldSections[s].objectList indexOfObjectIdenticalTo:o]; if (i != NSNotFound) return IP(i, s); }
        return nil;
    };
    for (id o in oldObjects) if (![r containsObject:o]) [changes addObject:@[o, oldPath(o), @(NSFetchedResultsChangeDelete), [NSNull null]]];
    for (id o in r) {
        NSIndexPath *np = [self indexPathForObject:o], *op = oldPath(o);
        if (!op) { [changes addObject:@[o, [NSNull null], @(NSFetchedResultsChangeInsert), np]]; continue; }
        BOOL moved = ![oldNames[SEC(op)] isEqualToString:newNames[SEC(np)]];
        if (!moved) {                                    /* relative order among surviving objects changed? */
            NSMutableArray *oldOrder = [NSMutableArray array], *newOrder = [NSMutableArray array];
            for (id x in oldSections[SEC(op)].objectList) if ([r containsObject:x] && [_sections[SEC(np)].objectList containsObject:x]) [oldOrder addObject:x];
            for (id x in _sections[SEC(np)].objectList) if ([oldOrder containsObject:x]) [newOrder addObject:x];
            moved = [oldOrder indexOfObjectIdenticalTo:o] != [newOrder indexOfObjectIdenticalTo:o];
        }
        if (moved) [changes addObject:@[o, op, @(NSFetchedResultsChangeMove), np]];
        else if ([updated containsObject:o]) [changes addObject:@[o, op, @(NSFetchedResultsChangeUpdate), np]];
    }
    if (!changes.count && !secChanges.count) return;
    if ([d respondsToSelector:@selector(controllerWillChangeContent:)]) [d controllerWillChangeContent:self];
    if (secCB) for (NSArray *c in secChanges) [d controller:self didChangeSection:c[0] atIndex:[c[1] unsignedIntegerValue] forChangeType:[c[2] unsignedIntegerValue]];
    if (objCB) for (NSArray *c in changes)
        [d controller:self didChangeObject:c[0] atIndexPath:c[1] == [NSNull null] ? nil : c[1] forChangeType:[c[2] unsignedIntegerValue] newIndexPath:c[3] == [NSNull null] ? nil : c[3]];
    if ([d respondsToSelector:@selector(controllerDidChangeContent:)]) [d controllerDidChangeContent:self];
}
@end
