// isim Photos for Objective-C (issue #545): the constants, and the classes Swift's generics cannot be — PHFetchResult (the
// objects a fetch returned, and how to run it again), PHObjectChangeDetails and PHFetchResultChangeDetails (the fetch
// run again, compared with the first) — with the fetch class methods over the Swift overlay's (ObjC.swift).
#import <Photos/Photos.h>
// the fetches and change details are declared in the classes' @interfaces (Apple's headers) and implemented here
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSString * const PHPhotosErrorDomain = @"PHPhotosErrorDomain";
NSString * const PHLocalIdentifierNotFound = @"Not Found";
NSString * const PHImageResultIsInCloudKey = @"PHImageResultIsInCloudKey";
NSString * const PHImageResultIsDegradedKey = @"PHImageResultIsDegradedKey";
NSString * const PHImageResultRequestIDKey = @"PHImageResultRequestIDKey";
NSString * const PHImageCancelledKey = @"PHImageCancelledKey";
NSString * const PHImageErrorKey = @"PHImageErrorKey";
CGSize const PHImageManagerMaximumSize = { -1, -1 };
NSString * const PHContentEditingInputResultIsInCloudKey = @"PHContentEditingInputResultIsInCloudKey";
NSString * const PHContentEditingInputCancelledKey = @"PHContentEditingInputCancelledKey";
NSString * const PHContentEditingInputErrorKey = @"PHContentEditingInputErrorKey";
NSString * const PHLivePhotoInfoErrorKey = @"PHLivePhotoInfoErrorKey";
NSString * const PHLivePhotoInfoIsDegradedKey = @"PHLivePhotoInfoIsDegradedKey";
NSString * const PHLivePhotoInfoCancelledKey = @"PHLivePhotoInfoCancelledKey";

// MARK: - PHFetchResult

@interface PHFetchResult ()
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSArray * (^again)(void);
+ (instancetype)_isim_resultWithFetch:(NSArray * (^)(void))fetch;
- (PHFetchResult *)_isim_refetched;
@end

@implementation PHFetchResult
+ (instancetype)_isim_resultWithFetch:(NSArray * (^)(void))fetch {
    PHFetchResult *r = [[self alloc] init];
    r.items = fetch() ?: @[];
    r.again = fetch;
    return r;
}
- (PHFetchResult *)_isim_refetched { return self.again ? [PHFetchResult _isim_resultWithFetch:self.again] : self; }
/* the objects, for the Swift side (change requests take a PHFetchResult where they take assets) */
- (NSArray *)_isim_allObjects { return self.items; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSUInteger)count { return self.items.count; }
- (id)objectAtIndex:(NSUInteger)index { return self.items[index]; }
- (id)objectAtIndexedSubscript:(NSUInteger)idx { return self.items[idx]; }
- (BOOL)containsObject:(id)anObject { return [self.items containsObject:anObject]; }
- (NSUInteger)indexOfObject:(id)anObject { return [self.items indexOfObject:anObject]; }
- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range { return [self.items indexOfObject:anObject inRange:range]; }
- (id)firstObject { return self.items.firstObject; }
- (id)lastObject { return self.items.lastObject; }
- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes { return [self.items objectsAtIndexes:indexes]; }
- (void)enumerateObjectsUsingBlock:(void (^)(id, NSUInteger, BOOL *))block { [self.items enumerateObjectsUsingBlock:block]; }
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id, NSUInteger, BOOL *))block {
    [self.items enumerateObjectsWithOptions:opts usingBlock:block];
}
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (^)(id, NSUInteger, BOOL *))block {
    [self.items enumerateObjectsAtIndexes:s options:opts usingBlock:block];
}
- (NSUInteger)countOfAssetsWithMediaType:(PHAssetMediaType)mediaType {
    NSUInteger n = 0;
    for (id o in self.items) if ([o isKindOfClass:[PHAsset class]] && ((PHAsset *)o).mediaType == mediaType) n++;
    return n;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    return [self.items countByEnumeratingWithState:state objects:buffer count:len];
}
- (NSString *)description { return [NSString stringWithFormat:@"<PHFetchResult: %p> count=%lu", self, (unsigned long)self.items.count]; }
@end

// MARK: - fetches (Swift returns the objects; the result runs the same fetch again for change details)

@interface PHAsset (ISIMFetch)
+ (NSArray *)_isim_fetchAssetsWithOptions:(PHFetchOptions *)options;
+ (NSArray *)_isim_fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(PHFetchOptions *)options;
+ (NSArray *)_isim_fetchAssetsWithLocalIdentifiers:(NSArray *)identifiers options:(PHFetchOptions *)options;
+ (NSArray *)_isim_fetchAssetsInAssetCollection:(PHAssetCollection *)collection options:(PHFetchOptions *)options;
@end
@interface PHCollection (ISIMFetch)
+ (NSArray *)_isim_fetchTopLevelUserCollectionsWithOptions:(PHFetchOptions *)options;
@end
@interface PHAssetCollection (ISIMFetch)
+ (NSArray *)_isim_fetchAssetCollectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype options:(PHFetchOptions *)options;
+ (NSArray *)_isim_fetchAssetCollectionsWithLocalIdentifiers:(NSArray *)identifiers options:(PHFetchOptions *)options;
+ (NSArray *)_isim_fetchAssetCollectionsContainingAsset:(PHAsset *)asset withType:(PHAssetCollectionType)type options:(PHFetchOptions *)options;
@end

@implementation PHAsset (ISIMFetches)
+ (PHFetchResult *)fetchAssetsWithOptions:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAsset _isim_fetchAssetsWithOptions:o]; }];
}
+ (PHFetchResult *)fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAsset _isim_fetchAssetsWithMediaType:mediaType options:o]; }];
}
+ (PHFetchResult *)fetchAssetsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    NSArray *ids = [identifiers copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAsset _isim_fetchAssetsWithLocalIdentifiers:ids options:o]; }];
}
+ (PHFetchResult *)fetchAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAsset _isim_fetchAssetsInAssetCollection:assetCollection options:o]; }];
}
+ (PHFetchResult *)fetchKeyAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(PHFetchOptions *)options {
    return [self fetchAssetsInAssetCollection:assetCollection options:options];
}
@end
@implementation PHCollection (ISIMFetches)
+ (PHFetchResult *)fetchTopLevelUserCollectionsWithOptions:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHCollection _isim_fetchTopLevelUserCollectionsWithOptions:o]; }];
}
@end
@implementation PHAssetCollection (ISIMFetches)
+ (PHFetchResult *)fetchAssetCollectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAssetCollection _isim_fetchAssetCollectionsWithType:type subtype:subtype options:o]; }];
}
+ (PHFetchResult *)fetchAssetCollectionsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    NSArray *ids = [identifiers copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAssetCollection _isim_fetchAssetCollectionsWithLocalIdentifiers:ids options:o]; }];
}
+ (PHFetchResult *)fetchAssetCollectionsContainingAsset:(PHAsset *)asset withType:(PHAssetCollectionType)type options:(PHFetchOptions *)options {
    PHFetchOptions *o = [options copy];
    return [PHFetchResult _isim_resultWithFetch:^{ return [PHAssetCollection _isim_fetchAssetCollectionsContainingAsset:asset withType:type options:o]; }];
}
@end

// MARK: - change details

@interface PHObjectChangeDetails ()
@property (atomic, strong) id before, after;
@end
@implementation PHObjectChangeDetails
- (id)objectBeforeChanges { return self.before; }
- (id)objectAfterChanges { return self.after; }
- (BOOL)assetContentChanged { return self.after != nil; }
- (BOOL)objectWasDeleted { return self.after == nil; }
@end

@interface PHFetchResultChangeDetails ()
@property (atomic, strong) PHFetchResult *before, *after;
@property (atomic, strong) NSIndexSet *removed, *inserted, *changed;
@end
@implementation PHFetchResultChangeDetails
+ (instancetype)changeDetailsFromFetchResult:(PHFetchResult *)fromResult toFetchResult:(PHFetchResult *)toResult changedObjects:(NSArray *)changedObjects {
    PHFetchResultChangeDetails *d = [[self alloc] init];
    d.before = fromResult; d.after = toResult;
    NSMutableIndexSet *removed = [NSMutableIndexSet indexSet], *inserted = [NSMutableIndexSet indexSet], *changed = [NSMutableIndexSet indexSet];
    [fromResult enumerateObjectsUsingBlock:^(id o, NSUInteger i, BOOL *stop) { if (![toResult containsObject:o]) [removed addIndex:i]; }];
    [toResult enumerateObjectsUsingBlock:^(id o, NSUInteger i, BOOL *stop) {
        if (![fromResult containsObject:o]) [inserted addIndex:i];
        else if ([changedObjects containsObject:o]) [changed addIndex:i];
    }];
    d.removed = removed; d.inserted = inserted; d.changed = changed;
    return d;
}
- (PHFetchResult *)fetchResultBeforeChanges { return self.before; }
- (PHFetchResult *)fetchResultAfterChanges { return self.after; }
- (BOOL)hasIncrementalChanges { return YES; }
- (NSIndexSet *)removedIndexes { return self.removed; }
- (NSArray *)removedObjects { return [self.before objectsAtIndexes:self.removed]; }
- (NSIndexSet *)insertedIndexes { return self.inserted; }
- (NSArray *)insertedObjects { return [self.after objectsAtIndexes:self.inserted]; }
- (NSIndexSet *)changedIndexes { return self.changed; }
- (NSArray *)changedObjects { return [self.after objectsAtIndexes:self.changed]; }
/* isim: a fetch keeps its sort order, so the comparison finds no moves */
- (BOOL)hasMoves { return NO; }
- (void)enumerateMovesWithBlock:(void (^)(NSUInteger, NSUInteger))handler {}
@end

@interface PHChange (ISIMIdentifiers)
- (NSArray<NSString *> *)_isim_changedIdentifiers;
@end
@implementation PHChange (ISIMDetails)
- (PHObjectChangeDetails *)changeDetailsForObject:(PHObject *)object {
    if (![[self _isim_changedIdentifiers] containsObject:object.localIdentifier]) return nil;
    PHObjectChangeDetails *d = [[PHObjectChangeDetails alloc] init];
    d.before = object;
    /* the object as it is now: fetched again by its identifier */
    if ([object isKindOfClass:[PHAsset class]]) d.after = [PHAsset fetchAssetsWithLocalIdentifiers:@[object.localIdentifier] options:nil].firstObject;
    else if ([object isKindOfClass:[PHAssetCollection class]])
        d.after = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[object.localIdentifier] options:nil].firstObject;
    else d.after = object;
    return d;
}
- (PHFetchResultChangeDetails *)changeDetailsForFetchResult:(PHFetchResult *)object {
    PHFetchResult *after = [object _isim_refetched];
    NSArray *ids = [self _isim_changedIdentifiers];
    NSMutableArray *changed = [NSMutableArray array];
    for (PHObject *o in after) if ([o isKindOfClass:[PHObject class]] && [ids containsObject:o.localIdentifier]) [changed addObject:o];
    PHFetchResultChangeDetails *d = [PHFetchResultChangeDetails changeDetailsFromFetchResult:object toFetchResult:after changedObjects:changed];
    return d.removed.count || d.inserted.count || d.changed.count ? d : nil;
}
@end
