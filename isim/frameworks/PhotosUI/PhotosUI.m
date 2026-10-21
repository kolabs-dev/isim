// isim PhotosUI for Objective-C (issue #545): PHPickerConfiguration, PHPickerFilter and PHPickerResult, which Swift has
// as structs. PHPickerViewController (Swift) reads a configuration and its filter through key-value coding (the _isim_
// keys below) and makes the results the same way (PhotosUI's ObjC.swift).
#import <PhotosUI/PhotosUI.h>

@interface PHPickerFilter ()
@property (nonatomic, copy) NSString *_isim_kind;          /* a kind of item ("image", "video", ...), or nil */
@property (nonatomic, copy) NSString *_isim_op;            /* otherwise "any", "all" or "not" */
@property (nonatomic, copy) NSArray<PHPickerFilter *> *_isim_subfilters;
@end
@implementation PHPickerFilter
+ (PHPickerFilter *)_isim_kind:(NSString *)kind { PHPickerFilter *f = [[self alloc] _isim_init]; f._isim_kind = kind; return f; }
+ (PHPickerFilter *)_isim_op:(NSString *)op of:(NSArray *)subs {
    PHPickerFilter *f = [[self alloc] _isim_init]; f._isim_op = op; f._isim_subfilters = [subs copy] ?: @[]; return f;
}
- (instancetype)_isim_init { return [super init]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
+ (PHPickerFilter *)imagesFilter { return [self _isim_kind:@"image"]; }
+ (PHPickerFilter *)videosFilter { return [self _isim_kind:@"video"]; }
+ (PHPickerFilter *)livePhotosFilter { return [self _isim_kind:@"livePhoto"]; }
+ (PHPickerFilter *)depthEffectPhotosFilter { return [self _isim_kind:@"depth"]; }
+ (PHPickerFilter *)burstsFilter { return [self _isim_kind:@"burst"]; }
+ (PHPickerFilter *)panoramasFilter { return [self _isim_kind:@"panorama"]; }
+ (PHPickerFilter *)screenshotsFilter { return [self _isim_kind:@"screenshot"]; }
+ (PHPickerFilter *)screenRecordingsFilter { return [self _isim_kind:@"screenRecording"]; }
+ (PHPickerFilter *)cinematicVideosFilter { return [self _isim_kind:@"cinematic"]; }
+ (PHPickerFilter *)slomoVideosFilter { return [self _isim_kind:@"slomo"]; }
+ (PHPickerFilter *)timelapseVideosFilter { return [self _isim_kind:@"timelapse"]; }
+ (PHPickerFilter *)spatialMediaFilter { return [self _isim_kind:@"spatial"]; }
+ (PHPickerFilter *)playbackStyleFilter:(NSInteger)playbackStyle { return [self imagesFilter]; }
+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters { return [self _isim_op:@"any" of:subfilters]; }
+ (PHPickerFilter *)allFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters { return [self _isim_op:@"all" of:subfilters]; }
+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter { return [self _isim_op:@"not" of:@[subfilter]]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[PHPickerFilter class]]) return NO;
    PHPickerFilter *f = o;
    return (self._isim_kind == f._isim_kind || [self._isim_kind isEqual:f._isim_kind]) && (self._isim_op == f._isim_op || [self._isim_op isEqual:f._isim_op]) &&
           (self._isim_subfilters == f._isim_subfilters || [self._isim_subfilters isEqual:f._isim_subfilters]);
}
- (NSUInteger)hash { return self._isim_kind.hash ^ self._isim_op.hash ^ self._isim_subfilters.count; }
- (NSString *)description {
    return self._isim_kind ? [NSString stringWithFormat:@"<PHPickerFilter %@>", self._isim_kind]
                           : [NSString stringWithFormat:@"<PHPickerFilter %@ %@>", self._isim_op, self._isim_subfilters];
}
@end

@interface PHPickerConfiguration ()
@property (nonatomic) BOOL _isim_withPhotoLibrary;
@end
@implementation PHPickerConfiguration
- (instancetype)init {
    if ((self = [super init])) { _selectionLimit = 1; _preselectedAssetIdentifiers = @[]; }
    return self;
}
- (instancetype)initWithPhotoLibrary:(PHPhotoLibrary *)photoLibrary {
    if ((self = [self init])) self._isim_withPhotoLibrary = YES;
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    PHPickerConfiguration *c = [[PHPickerConfiguration alloc] init];
    c.preferredAssetRepresentationMode = self.preferredAssetRepresentationMode;
    c.selection = self.selection;
    c.selectionLimit = self.selectionLimit;
    c.filter = self.filter;
    c.preselectedAssetIdentifiers = self.preselectedAssetIdentifiers;
    c._isim_withPhotoLibrary = self._isim_withPhotoLibrary;
    return c;
}
@end

@interface PHPickerResult ()
@property (nonatomic, readwrite, strong) NSItemProvider *itemProvider;
@property (nonatomic, readwrite, copy) NSString *assetIdentifier;
@end
@implementation PHPickerResult
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PHPickerResult class]] && ((PHPickerResult *)o).itemProvider == self.itemProvider; }
- (NSUInteger)hash { return (NSUInteger)(__bridge void *)self.itemProvider; }
@end
