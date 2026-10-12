/* The Objective-C diffable data sources: NSDiffableDataSourceSnapshotReference (sections and items as objects; the
 * snapshot NSFetchedResultsController hands its delegate), NSDiffableDataSourceSectionSnapshotReference (one
 * section as an outline) and the table / collection view data sources that show snapshots. Applying a snapshot with
 * the same sections animates item inserts and deletes; other changes reload the view. */
#import "UIKitPrivate.h"
#import <UIKit/UIDiffableDataSourceReference.h>

/* ================= NSDiffableDataSourceSnapshotReference ================= */
@implementation NSDiffableDataSourceSnapshotReference {
    NSMutableArray *_sections; NSMutableArray<NSMutableArray *> *_items; NSMutableArray *_reloaded, *_reconfigured, *_reloadedSections;
}
- (instancetype)init {
    if ((self = [super init])) { _sections = [NSMutableArray array]; _items = [NSMutableArray array]; _reloaded = [NSMutableArray array];
                                 _reconfigured = [NSMutableArray array]; _reloadedSections = [NSMutableArray array]; }
    return self;
}
- (NSInteger)numberOfItems { NSInteger n = 0; for (NSArray *a in _items) n += a.count; return n; }
- (NSInteger)numberOfSections { return _sections.count; }
- (NSArray *)sectionIdentifiers { return [_sections copy]; }
- (NSArray *)itemIdentifiers { NSMutableArray *all = [NSMutableArray array]; for (NSArray *a in _items) [all addObjectsFromArray:a]; return all; }
- (NSArray *)reloadedSectionIdentifiers { return [_reloadedSections copy]; }
- (NSArray *)reloadedItemIdentifiers { return [_reloaded copy]; }
- (NSArray *)reconfiguredItemIdentifiers { return [_reconfigured copy]; }
- (NSInteger)numberOfItemsInSection:(id)s { NSUInteger i = [_sections indexOfObject:s]; return i == NSNotFound ? 0 : _items[i].count; }
- (NSArray *)itemIdentifiersInSectionWithIdentifier:(id)s { NSUInteger i = [_sections indexOfObject:s]; return i == NSNotFound ? @[] : [_items[i] copy]; }
- (NSUInteger)_sectionOfItem:(id)item { for (NSUInteger i = 0; i < _items.count; i++) if ([_items[i] containsObject:item]) return i; return NSNotFound; }
- (id)sectionIdentifierForSectionContainingItemIdentifier:(id)item { NSUInteger i = [self _sectionOfItem:item]; return i == NSNotFound ? nil : _sections[i]; }
- (NSInteger)indexOfItemIdentifier:(id)item { NSUInteger i = [self.itemIdentifiers indexOfObject:item]; return i == NSNotFound ? NSNotFound : (NSInteger)i; }
- (NSInteger)indexOfSectionIdentifier:(id)s { NSUInteger i = [_sections indexOfObject:s]; return i == NSNotFound ? NSNotFound : (NSInteger)i; }
- (void)appendItemsWithIdentifiers:(NSArray *)ids {
    if (!_sections.count) [NSException raise:NSInternalInconsistencyException format:@"There are currently no sections in the data source. Please add a section first."];
    [_items.lastObject addObjectsFromArray:ids];
}
- (void)appendItemsWithIdentifiers:(NSArray *)ids intoSectionWithIdentifier:(id)s {
    NSUInteger i = [_sections indexOfObject:s];
    if (i == NSNotFound) { [self appendSectionsWithIdentifiers:@[s]]; i = _sections.count - 1; }
    [_items[i] addObjectsFromArray:ids];
}
- (void)_insert:(NSArray *)ids at:(id)anchor after:(BOOL)after {
    NSUInteger s = [self _sectionOfItem:anchor];
    if (s == NSNotFound) [NSException raise:NSInternalInconsistencyException format:@"Invalid item identifier %@", anchor];
    NSUInteger i = [_items[s] indexOfObject:anchor] + (after ? 1 : 0);
    [_items[s] insertObjects:ids atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, ids.count)]];
}
- (void)insertItemsWithIdentifiers:(NSArray *)ids beforeItemWithIdentifier:(id)item { [self _insert:ids at:item after:NO]; }
- (void)insertItemsWithIdentifiers:(NSArray *)ids afterItemWithIdentifier:(id)item { [self _insert:ids at:item after:YES]; }
- (void)deleteItemsWithIdentifiers:(NSArray *)ids {
    for (NSMutableArray *a in _items) [a removeObjectsInArray:ids];
    [_reloaded removeObjectsInArray:ids]; [_reconfigured removeObjectsInArray:ids];
}
- (void)deleteAllItems { [_sections removeAllObjects]; [_items removeAllObjects]; [_reloaded removeAllObjects]; [_reconfigured removeAllObjects]; [_reloadedSections removeAllObjects]; }
- (void)moveItemWithIdentifier:(id)from beforeItemWithIdentifier:(id)to { [self deleteItemsWithIdentifiers:@[from]]; [self _insert:@[from] at:to after:NO]; }
- (void)moveItemWithIdentifier:(id)from afterItemWithIdentifier:(id)to { [self deleteItemsWithIdentifiers:@[from]]; [self _insert:@[from] at:to after:YES]; }
- (void)reloadItemsWithIdentifiers:(NSArray *)ids { for (id i in ids) if (![_reloaded containsObject:i]) [_reloaded addObject:i]; }
- (void)reconfigureItemsWithIdentifiers:(NSArray *)ids { for (id i in ids) if (![_reconfigured containsObject:i]) [_reconfigured addObject:i]; }
- (void)appendSectionsWithIdentifiers:(NSArray *)ids { for (id s in ids) { [_sections addObject:s]; [_items addObject:[NSMutableArray array]]; } }
- (void)_insertSections:(NSArray *)ids at:(id)anchor after:(BOOL)after {
    NSUInteger i = [_sections indexOfObject:anchor];
    if (i == NSNotFound) [NSException raise:NSInternalInconsistencyException format:@"Invalid section identifier %@", anchor];
    i += after ? 1 : 0;
    for (id s in ids) { [_sections insertObject:s atIndex:i]; [_items insertObject:[NSMutableArray array] atIndex:i]; i++; }
}
- (void)insertSectionsWithIdentifiers:(NSArray *)ids beforeSectionWithIdentifier:(id)s { [self _insertSections:ids at:s after:NO]; }
- (void)insertSectionsWithIdentifiers:(NSArray *)ids afterSectionWithIdentifier:(id)s { [self _insertSections:ids at:s after:YES]; }
- (void)deleteSectionsWithIdentifiers:(NSArray *)ids {
    for (id s in ids) { NSUInteger i = [_sections indexOfObject:s]; if (i == NSNotFound) continue; [_sections removeObjectAtIndex:i]; [_items removeObjectAtIndex:i]; }
}
- (void)_moveSection:(id)from to:(id)to after:(BOOL)after {
    NSUInteger i = [_sections indexOfObject:from];
    if (i == NSNotFound) return;
    NSMutableArray *items = _items[i];
    [_sections removeObjectAtIndex:i]; [_items removeObjectAtIndex:i];
    NSUInteger j = [_sections indexOfObject:to];
    if (j == NSNotFound) j = _sections.count; else j += after ? 1 : 0;
    [_sections insertObject:from atIndex:j]; [_items insertObject:items atIndex:j];
}
- (void)moveSectionWithIdentifier:(id)from beforeSectionWithIdentifier:(id)to { [self _moveSection:from to:to after:NO]; }
- (void)moveSectionWithIdentifier:(id)from afterSectionWithIdentifier:(id)to { [self _moveSection:from to:to after:YES]; }
- (void)reloadSectionsWithIdentifiers:(NSArray *)ids { for (id s in ids) if (![_reloadedSections containsObject:s]) [_reloadedSections addObject:s]; }
- (id)copyWithZone:(NSZone *)zone {
    NSDiffableDataSourceSnapshotReference *c = [[[self class] alloc] init];
    [c->_sections addObjectsFromArray:_sections];
    for (NSArray *a in _items) [c->_items addObject:[a mutableCopy]];
    [c->_reloaded addObjectsFromArray:_reloaded]; [c->_reconfigured addObjectsFromArray:_reconfigured]; [c->_reloadedSections addObjectsFromArray:_reloadedSections];
    return c;
}
- (void)_isim_forgetReloads { [_reloaded removeAllObjects]; [_reconfigured removeAllObjects]; [_reloadedSections removeAllObjects]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSDiffableDataSourceSnapshotReference: %p> sections %@ items %ld", self, _sections, (long)self.numberOfItems]; }
@end

/* ================= NSDiffableDataSourceSectionSnapshotReference ================= */
@implementation NSDiffableDataSourceSectionSnapshotReference {
@public
    NSMutableArray *_roots; NSMutableDictionary *_children; NSMapTable *_parent; NSMutableSet *_expanded;
}
- (instancetype)init {
    if ((self = [super init])) { _roots = [NSMutableArray array]; _children = [NSMutableDictionary dictionary]; _parent = [NSMapTable strongToStrongObjectsMapTable]; _expanded = [NSMutableSet set]; }
    return self;
}
- (NSMutableArray *)_childrenOf:(id)p { if (!p) return _roots; NSMutableArray *c = _children[p]; if (!c) { c = [NSMutableArray array]; _children[p] = c; } return c; }
- (void)_walk:(NSArray *)items visibleOnly:(BOOL)visible into:(NSMutableArray *)out {
    for (id i in items) { [out addObject:i]; if (!visible || [_expanded containsObject:i]) [self _walk:_children[i] ?: @[] visibleOnly:visible into:out]; }
}
- (NSArray *)items { NSMutableArray *o = [NSMutableArray array]; [self _walk:_roots visibleOnly:NO into:o]; return o; }
- (NSArray *)rootItems { return [_roots copy]; }
- (NSArray *)visibleItems { NSMutableArray *o = [NSMutableArray array]; [self _walk:_roots visibleOnly:YES into:o]; return o; }
- (BOOL)containsItem:(id)item { return [_roots containsObject:item] || [_parent objectForKey:item] != nil; }
- (id)parentOfChildItem:(id)child { return [_parent objectForKey:child]; }
- (NSInteger)levelOfItem:(id)item { NSInteger l = 0; for (id p = [_parent objectForKey:item]; p; p = [_parent objectForKey:p]) l++; return l; }
- (NSInteger)indexOfItem:(id)item { NSUInteger i = [self.items indexOfObject:item]; return i == NSNotFound ? NSNotFound : (NSInteger)i; }
- (BOOL)isExpanded:(id)item { return [_expanded containsObject:item]; }
- (BOOL)isVisible:(id)item {
    if (![self containsItem:item]) return NO;
    for (id p = [_parent objectForKey:item]; p; p = [_parent objectForKey:p]) if (![_expanded containsObject:p]) return NO;
    return YES;
}
- (NSArray *)expandedItems { NSMutableArray *o = [NSMutableArray array]; for (id i in self.items) if ([_expanded containsObject:i]) [o addObject:i]; return o; }
- (void)appendItems:(NSArray *)items { [self appendItems:items intoParentItem:nil]; }
- (void)appendItems:(NSArray *)items intoParentItem:(id)parent {
    if (parent && ![self containsItem:parent]) [NSException raise:NSInternalInconsistencyException format:@"Invalid parent item identifier %@", parent];
    [[self _childrenOf:parent] addObjectsFromArray:items];
    if (parent) for (id i in items) [_parent setObject:parent forKey:i];
}
- (void)_insert:(NSArray *)items at:(id)anchor after:(BOOL)after {
    id p = [_parent objectForKey:anchor];
    NSMutableArray *c = [self _childrenOf:p];
    NSUInteger i = [c indexOfObject:anchor];
    if (i == NSNotFound) [NSException raise:NSInternalInconsistencyException format:@"Invalid item identifier %@", anchor];
    [c insertObjects:items atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i + (after ? 1 : 0), items.count)]];
    if (p) for (id x in items) [_parent setObject:p forKey:x];
}
- (void)insertItems:(NSArray *)items beforeItem:(id)item { [self _insert:items at:item after:NO]; }
- (void)insertItems:(NSArray *)items afterItem:(id)item { [self _insert:items at:item after:YES]; }
- (void)deleteItems:(NSArray *)items {
    for (id item in items) {
        if (![self containsItem:item]) continue;
        NSMutableArray *gone = [NSMutableArray array]; [self _walk:@[item] visibleOnly:NO into:gone];
        [[self _childrenOf:[_parent objectForKey:item]] removeObject:item];
        for (id g in gone) { [_children removeObjectForKey:g]; [_parent removeObjectForKey:g]; [_expanded removeObject:g]; }
    }
}
- (void)deleteAllItems { [_roots removeAllObjects]; [_children removeAllObjects]; [_parent removeAllObjects]; [_expanded removeAllObjects]; }
- (void)expandItems:(NSArray *)items { for (id i in items) if ([self containsItem:i]) [_expanded addObject:i]; }
- (void)collapseItems:(NSArray *)items { for (id i in items) [_expanded removeObject:i]; }
/* the other snapshot's outline added under a parent (nil: at the root) or next to an item */
- (void)_adopt:(NSDiffableDataSourceSectionSnapshotReference *)o {
    for (id p in o->_children) { [_children setObject:[o->_children[p] mutableCopy] forKey:p]; for (id c in o->_children[p]) [_parent setObject:p forKey:c]; }
    [_expanded unionSet:o->_expanded];
}
- (void)replaceChildrenOfParentItem:(id)parent withSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot {
    [self deleteItems:[_children[parent] copy] ?: @[]];
    [self appendItems:snapshot->_roots intoParentItem:parent];
    [self _adopt:snapshot];
}
- (void)insertSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot beforeItem:(id)item { [self _insert:snapshot->_roots at:item after:NO]; [self _adopt:snapshot]; }
- (void)insertSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot afterItem:(id)item { [self _insert:snapshot->_roots at:item after:YES]; [self _adopt:snapshot]; }
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotOfParentItem:(id)parent { return [self snapshotOfParentItem:parent includingParentItem:NO]; }
- (void)_copyChildrenOf:(id)p into:(id)into target:(NSDiffableDataSourceSectionSnapshotReference *)s {
    NSArray *kids = _children[p] ?: @[];
    [s appendItems:kids intoParentItem:into];
    for (id k in kids) [self _copyChildrenOf:k into:k target:s];
}
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotOfParentItem:(id)parent includingParentItem:(BOOL)including {
    NSDiffableDataSourceSectionSnapshotReference *s = [[self class] new];
    if (including) [s appendItems:@[parent]];
    [self _copyChildrenOf:parent into:including ? parent : nil target:s];
    for (id e in _expanded) if ([s containsItem:e]) [s->_expanded addObject:e];
    return s;
}
- (NSString *)visualDescription {
    NSMutableArray *lines = [NSMutableArray array];
    for (id i in self.items) {
        NSString *state = _children[i] ? ([_expanded containsObject:i] ? @" (expanded)" : @" (collapsed)") : @"";
        [lines addObject:[NSString stringWithFormat:@"%@- %@%@", [@"" stringByPaddingToLength:2 * (NSUInteger)[self levelOfItem:i] withString:@" " startingAtIndex:0], i, state]];
    }
    return [lines componentsJoinedByString:@"\n"];
}
- (id)copyWithZone:(NSZone *)z {
    NSDiffableDataSourceSectionSnapshotReference *c = [[self class] new];
    [c->_roots addObjectsFromArray:_roots];
    [c _adopt:self];
    return c;
}
@end

/* ================= data sources ================= */
/* the changes from one snapshot to the next when the sections are the same: deleted and inserted item index paths */
static BOOL item_changes(NSDiffableDataSourceSnapshotReference *old, NSDiffableDataSourceSnapshotReference *new, NSMutableArray *dels, NSMutableArray *ins) {
    if (!old || ![old.sectionIdentifiers isEqualToArray:new.sectionIdentifiers]) return NO;
    NSArray *secs = new.sectionIdentifiers;
    for (NSUInteger s = 0; s < secs.count; s++) {
        NSArray *a = [old itemIdentifiersInSectionWithIdentifier:secs[s]], *b = [new itemIdentifiersInSectionWithIdentifier:secs[s]];
        NSMutableArray *kept = [NSMutableArray array];
        for (NSUInteger i = 0; i < a.count; i++) { if (![b containsObject:a[i]]) [dels addObject:[NSIndexPath indexPathForItem:i inSection:s]]; else [kept addObject:a[i]]; }
        NSMutableArray *keptNew = [NSMutableArray array];
        for (NSUInteger i = 0; i < b.count; i++) { if (![a containsObject:b[i]]) [ins addObject:[NSIndexPath indexPathForItem:i inSection:s]]; else [keptNew addObject:b[i]]; }
        if (![kept isEqualToArray:keptNew]) return NO;            /* (moves: reload) */
    }
    return YES;
}
static NSArray *paths_of(NSDiffableDataSourceSnapshotReference *snap, NSArray *items) {
    NSMutableArray *o = [NSMutableArray array];
    NSArray *secs = snap.sectionIdentifiers;
    for (id item in items) {
        id s = [snap sectionIdentifierForSectionContainingItemIdentifier:item];
        if (!s) continue;
        [o addObject:[NSIndexPath indexPathForItem:[[snap itemIdentifiersInSectionWithIdentifier:s] indexOfObject:item] inSection:[secs indexOfObject:s]]];
    }
    return o;
}
static void finish(void (^completion)(void), BOOL animated) {
    if (!completion) return;
    if (animated) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.31 * NSEC_PER_SEC)), dispatch_get_main_queue(), completion);
    else completion();
}

@implementation UICollectionViewDiffableDataSourceReference {
    __weak UICollectionView *_cv; UICollectionViewDiffableDataSourceCellProvider _provider;
    NSDiffableDataSourceSnapshotReference *_snap; NSMutableDictionary *_outlines;   /* section -> section snapshot */
}
- (instancetype)initWithCollectionView:(UICollectionView *)cv cellProvider:(UICollectionViewDiffableDataSourceCellProvider)provider {
    if ((self = [super init])) { _cv = cv; _provider = [provider copy]; _snap = [NSDiffableDataSourceSnapshotReference new]; _outlines = [NSMutableDictionary dictionary]; cv.dataSource = self; }
    return self;
}
- (NSDiffableDataSourceSnapshotReference *)snapshot { return [_snap copy]; }
- (void)_show:(NSDiffableDataSourceSnapshotReference *)snap animated:(BOOL)animated reload:(BOOL)forceReload {
    UICollectionView *cv = _cv;
    NSDiffableDataSourceSnapshotReference *old = _snap, *next = [snap copy];
    NSMutableArray *dels = [NSMutableArray array], *ins = [NSMutableArray array];
    BOOL diff = !forceReload && animated && cv.window && item_changes(old, next, dels, ins);
    NSArray *reloads = paths_of(next, next.reloadedItemIdentifiers), *reconfigs = paths_of(next, next.reconfiguredItemIdentifiers);
    BOOL sectionsReloaded = next.reloadedSectionIdentifiers.count > 0;
    [next _isim_forgetReloads];
    _snap = next;
    for (id s in [_outlines allKeys]) if ([next indexOfSectionIdentifier:s] == NSNotFound) [_outlines removeObjectForKey:s];
    if (!diff || sectionsReloaded) { [cv reloadData]; return; }
    [cv performBatchUpdates:^{
        if (dels.count) [cv deleteItemsAtIndexPaths:dels];
        if (ins.count) [cv insertItemsAtIndexPaths:ins];
    } completion:nil];
    if (reloads.count) [cv reloadItemsAtIndexPaths:reloads];
    if (reconfigs.count) [cv reconfigureItemsAtIndexPaths:reconfigs];
}
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)s animatingDifferences:(BOOL)a { [self applySnapshot:s animatingDifferences:a completion:nil]; }
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)s animatingDifferences:(BOOL)a completion:(void (^)(void))c {
    [self _show:s animated:a reload:NO];
    NSLog(@"isim: diffable data source applied %ld section(s), %ld item(s)", (long)s.numberOfSections, (long)s.numberOfItems);
    finish(c, a);
}
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)s { [self applySnapshotUsingReloadData:s completion:nil]; }
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)s completion:(void (^)(void))c { [self _show:s animated:NO reload:YES]; finish(c, NO); }
- (id)itemIdentifierForIndexPath:(NSIndexPath *)ip {
    NSArray *secs = _snap.sectionIdentifiers;
    if (ip.section < 0 || ip.section >= (NSInteger)secs.count) return nil;
    NSArray *items = [_snap itemIdentifiersInSectionWithIdentifier:secs[ip.section]];
    return ip.item >= 0 && ip.item < (NSInteger)items.count ? items[ip.item] : nil;
}
- (NSIndexPath *)indexPathForItemIdentifier:(id)identifier { return paths_of(_snap, @[identifier]).firstObject; }
- (id)sectionIdentifierForIndex:(NSInteger)i { NSArray *s = _snap.sectionIdentifiers; return i >= 0 && i < (NSInteger)s.count ? s[i] : nil; }
- (NSInteger)indexForSectionIdentifier:(id)identifier { return [_snap indexOfSectionIdentifier:identifier]; }
/* section snapshots: the outline is kept; the section shows its visible items */
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotForSection:(id)section {
    NSDiffableDataSourceSectionSnapshotReference *o = _outlines[section];
    if (o) return [o copy];
    NSDiffableDataSourceSectionSnapshotReference *flat = [NSDiffableDataSourceSectionSnapshotReference new];
    [flat appendItems:[_snap itemIdentifiersInSectionWithIdentifier:section]];
    return flat;
}
- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot toSection:(id)section animatingDifferences:(BOOL)a { [self applySnapshot:snapshot toSection:section animatingDifferences:a completion:nil]; }
- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot toSection:(id)section animatingDifferences:(BOOL)a completion:(void (^)(void))c {
    _outlines[section] = [snapshot copy];
    NSDiffableDataSourceSnapshotReference *next = [_snap copy];
    if ([next indexOfSectionIdentifier:section] == NSNotFound) [next appendSectionsWithIdentifiers:@[section]];
    else [next deleteItemsWithIdentifiers:[next itemIdentifiersInSectionWithIdentifier:section]];
    [next appendItemsWithIdentifiers:snapshot.visibleItems intoSectionWithIdentifier:section];
    [self _show:next animated:a reload:NO];
    finish(c, a);
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv { return _snap.numberOfSections; }
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return [_snap numberOfItemsInSection:_snap.sectionIdentifiers[s]]; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    id item = [self itemIdentifierForIndexPath:ip];
    UICollectionViewCell *c = _provider(cv, ip, item);
    if (!c) [NSException raise:NSInternalInconsistencyException format:@"UICollectionViewDiffableDataSource cell provider returned nil for index path %@", ip];
    NSDiffableDataSourceSectionSnapshotReference *outline = _outlines[[self sectionIdentifierForIndex:ip.section]];
    if (outline && [c isKindOfClass:[UICollectionViewListCell class]]) ((UICollectionViewListCell *)c).indentationLevel = [outline levelOfItem:item];   /* outline rows indent */
    return c;
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)cv viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)ip {
    return _supplementaryViewProvider ? _supplementaryViewProvider(cv, kind, ip) : nil;
}
@end

@implementation UITableViewDiffableDataSourceReference {
    __weak UITableView *_tv; UITableViewDiffableDataSourceCellProvider _provider; NSDiffableDataSourceSnapshotReference *_snap;
}
- (instancetype)initWithTableView:(UITableView *)tv cellProvider:(UITableViewDiffableDataSourceCellProvider)provider {
    if ((self = [super init])) { _tv = tv; _provider = [provider copy]; _snap = [NSDiffableDataSourceSnapshotReference new]; _defaultRowAnimation = UITableViewRowAnimationAutomatic; tv.dataSource = self; }
    return self;
}
- (NSDiffableDataSourceSnapshotReference *)snapshot { return [_snap copy]; }
- (void)_show:(NSDiffableDataSourceSnapshotReference *)snap animated:(BOOL)animated reload:(BOOL)forceReload {
    UITableView *tv = _tv;
    NSDiffableDataSourceSnapshotReference *old = _snap, *next = [snap copy];
    NSMutableArray *dels = [NSMutableArray array], *ins = [NSMutableArray array];
    BOOL diff = !forceReload && animated && tv.window && item_changes(old, next, dels, ins);
    NSArray *reloads = paths_of(next, next.reloadedItemIdentifiers), *reconfigs = paths_of(next, next.reconfiguredItemIdentifiers);
    BOOL sectionsReloaded = next.reloadedSectionIdentifiers.count > 0;
    [next _isim_forgetReloads];
    _snap = next;
    if (!diff || sectionsReloaded) { [tv reloadData]; return; }
    [tv performBatchUpdates:^{
        if (dels.count) [tv deleteRowsAtIndexPaths:dels withRowAnimation:self->_defaultRowAnimation];
        if (ins.count) [tv insertRowsAtIndexPaths:ins withRowAnimation:self->_defaultRowAnimation];
    } completion:nil];
    if (reloads.count) [tv reloadRowsAtIndexPaths:reloads withRowAnimation:_defaultRowAnimation];
    if (reconfigs.count) [tv reconfigureRowsAtIndexPaths:reconfigs];
}
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)s animatingDifferences:(BOOL)a { [self applySnapshot:s animatingDifferences:a completion:nil]; }
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)s animatingDifferences:(BOOL)a completion:(void (^)(void))c {
    [self _show:s animated:a reload:NO];
    NSLog(@"isim: diffable data source applied %ld section(s), %ld item(s)", (long)s.numberOfSections, (long)s.numberOfItems);
    finish(c, a);
}
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)s { [self applySnapshotUsingReloadData:s completion:nil]; }
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)s completion:(void (^)(void))c { [self _show:s animated:NO reload:YES]; finish(c, NO); }
- (id)itemIdentifierForIndexPath:(NSIndexPath *)ip {
    NSArray *secs = _snap.sectionIdentifiers;
    if (ip.section < 0 || ip.section >= (NSInteger)secs.count) return nil;
    NSArray *items = [_snap itemIdentifiersInSectionWithIdentifier:secs[ip.section]];
    return ip.row >= 0 && ip.row < (NSInteger)items.count ? items[ip.row] : nil;
}
- (NSIndexPath *)indexPathForItemIdentifier:(id)identifier { return paths_of(_snap, @[identifier]).firstObject; }
- (id)sectionIdentifierForIndex:(NSInteger)i { NSArray *s = _snap.sectionIdentifiers; return i >= 0 && i < (NSInteger)s.count ? s[i] : nil; }
- (NSInteger)indexForSectionIdentifier:(id)identifier { return [_snap indexOfSectionIdentifier:identifier]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _snap.numberOfSections; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [_snap numberOfItemsInSection:_snap.sectionIdentifiers[s]]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = _provider(tv, ip, [self itemIdentifierForIndexPath:ip]);
    if (!c) [NSException raise:NSInternalInconsistencyException format:@"UITableViewDiffableDataSource cell provider returned nil for index path %@", ip];
    return c;
}
@end
