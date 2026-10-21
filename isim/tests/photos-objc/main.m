// Photos and PhotosUI from Objective-C (PhotosObjCTest.app, issue #545): #import <Photos/Photos.h> and <PhotosUI/PhotosUI.h>,
// -framework Photos -framework PhotosUI. With ISIM_PHOTOS_PERMISSION=allow it reads the seeded library (fetches,
// PHFetchResult, image and data requests, resources), saves a picture into a new album and favourites it (change
// requests, a change observer and its fetch result change details), then shows a PHPickerViewController (the "pick"
// button) whose results it loads. Each result is logged ("PhotosObjC: ...").
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

static void say(NSString *s) { NSLog(@"PhotosObjC: %@", s); }

@interface TestViewController : UIViewController <PHPhotoLibraryChangeObserver, PHPickerViewControllerDelegate>
@property (nonatomic, strong) PHFetchResult<PHAsset *> *all;
@property (nonatomic, copy) NSString *createdID;
@property (nonatomic) BOOL sawChange;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIButton *pick = [UIButton buttonWithType:UIButtonTypeSystem];
    [pick setTitle:@"Pick" forState:UIControlStateNormal];
    pick.frame = CGRectMake(20, 120, 200, 44);
    pick.accessibilityIdentifier = @"pick";
    [pick addTarget:self action:@selector(pick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pick];
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            say([NSString stringWithFormat:@"authorization %ld legacy %ld add %ld", (long)status, (long)[PHPhotoLibrary authorizationStatus],
                 (long)[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly]]);
            if (status == PHAuthorizationStatusAuthorized) [self library];
        });
    }];
}

- (void)library {
    PHFetchOptions *opts = [[PHFetchOptions alloc] init];
    opts.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    self.all = [PHAsset fetchAssetsWithOptions:opts];
    NSUInteger fast = 0;
    for (PHAsset *a in self.all) if ([a isKindOfClass:[PHAsset class]]) fast++;
    __block NSUInteger enumerated = 0;
    [self.all enumerateObjectsUsingBlock:^(PHAsset *a, NSUInteger i, BOOL *stop) { enumerated++; }];
    PHAsset *first = self.all.firstObject;
    say([NSString stringWithFormat:@"assets %lu fast %lu enumerated %lu images %lu first %lux%lu type %ld index %lu contains %d",
         (unsigned long)self.all.count, (unsigned long)fast, (unsigned long)enumerated,
         (unsigned long)[self.all countOfAssetsWithMediaType:PHAssetMediaTypeImage], (unsigned long)first.pixelWidth,
         (unsigned long)first.pixelHeight, (long)first.mediaType, (unsigned long)[self.all indexOfObject:first], [self.all containsObject:self.all[1]]]);
    PHFetchOptions *limited = [[PHFetchOptions alloc] init];
    limited.fetchLimit = 2;
    limited.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", (int)PHAssetMediaTypeImage];
    say([NSString stringWithFormat:@"limited %lu by id %lu", (unsigned long)[PHAsset fetchAssetsWithOptions:limited].count,
         (unsigned long)[PHAsset fetchAssetsWithLocalIdentifiers:@[first.localIdentifier] options:nil].count]);

    /* images: a scaled image (synchronous), the data with its orientation, the resources */
    PHImageRequestOptions *ro = [[PHImageRequestOptions alloc] init];
    ro.synchronous = YES;
    ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    [[PHImageManager defaultManager] requestImageForAsset:first targetSize:CGSizeMake(100, 100) contentMode:PHImageContentModeAspectFit options:ro
                                            resultHandler:^(UIImage *image, NSDictionary *info) {
        say([NSString stringWithFormat:@"image %.0fx%.0f degraded %@ id %@", image.size.width * image.scale, image.size.height * image.scale,
             info[PHImageResultIsDegradedKey], info[PHImageResultRequestIDKey] ? @"yes" : @"no"]);
    }];
    [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:first options:ro
                                                               resultHandler:^(NSData *data, NSString *uti, CGImagePropertyOrientation o, NSDictionary *info) {
        say([NSString stringWithFormat:@"data %@ uti %@ orientation %u", data.length > 1000 ? @"yes" : @"no", uti, (unsigned)o]);
    }];
    PHAssetResource *res = [PHAssetResource assetResourcesForAsset:first].firstObject;
    __block NSUInteger bytes = 0;
    [[PHAssetResourceManager defaultManager] requestDataForAssetResource:res options:nil dataReceivedHandler:^(NSData *d) { bytes += d.length; }
                                                        completionHandler:^(NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            say([NSString stringWithFormat:@"resource %@ type %ld bytes %@ error %@", res.originalFilename, (long)res.type,
                 bytes > 1000 ? @"yes" : @"no", e ? e.domain : @"none"]);
            [self changes];
        });
    }];
}

/// saves a picture into a new album, then favourites it; the observer sees the changes
- (void)changes {
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1;
    UIImage *red = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 30) format:fmt] imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [UIColor.redColor setFill]; UIRectFill(CGRectMake(0, 0, 40, 30));
    }];
    __block NSString *placeholder = nil, *album = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *create = [PHAssetChangeRequest creationRequestForAssetFromImage:red];
        create.favorite = NO;
        PHAssetCollectionChangeRequest *a = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:@"ObjC Album"];
        [a addAssets:@[create.placeholderForCreatedAsset]];
        placeholder = create.placeholderForCreatedAsset.localIdentifier;
        album = a.placeholderForCreatedAssetCollection.localIdentifier;
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.createdID = placeholder;
            PHAsset *made = [PHAsset fetchAssetsWithLocalIdentifiers:@[placeholder] options:nil].firstObject;
            PHAssetCollection *col = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[album] options:nil].firstObject;
            PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
            say([NSString stringWithFormat:@"saved %d error %@ asset %lux%lu album %@ in album %lu albums %lu edit %d", success, error ? error.domain : @"none",
                 (unsigned long)made.pixelWidth, (unsigned long)made.pixelHeight, col.localizedTitle,
                 (unsigned long)[PHAsset fetchAssetsInAssetCollection:col options:nil].count, (unsigned long)albums.count,
                 [col canPerformEditOperation:PHCollectionEditOperationAddContent]]);
            [self favourite:made];
        });
    }];
}

- (void)favourite:(PHAsset *)asset {
    NSError *err = nil;
    BOOL ok = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        [PHAssetChangeRequest changeRequestForAsset:asset].favorite = YES;
    } error:&err];
    PHAssetCollection *favs = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                       subtype:PHAssetCollectionSubtypeSmartAlbumFavorites options:nil].firstObject;
    PHAsset *now = [PHAsset fetchAssetsWithLocalIdentifiers:@[asset.localIdentifier] options:nil].firstObject;
    say([NSString stringWithFormat:@"favourite %d error %@ isFavorite %d favorites %lu smart %@", ok, err ? err.domain : @"none", now.isFavorite,
         (unsigned long)[PHAsset fetchAssetsInAssetCollection:favs options:nil].count, favs.localizedTitle]);
    say(@"ready");
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    PHFetchResultChangeDetails *d = [changeInstance changeDetailsForFetchResult:self.all];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (d && !self.sawChange) {
            self.sawChange = YES;
            say([NSString stringWithFormat:@"change inserted %lu removed %lu after %lu incremental %d moves %d", (unsigned long)d.insertedIndexes.count,
                 (unsigned long)d.removedIndexes.count, (unsigned long)d.fetchResultAfterChanges.count, d.hasIncrementalChanges, d.hasMoves]);
            self.all = d.fetchResultAfterChanges;
        }
    });
}

// MARK: picker

- (void)pick {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.selectionLimit = 2;
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, [PHPickerFilter notFilterOfSubfilter:PHPickerFilter.videosFilter]]];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    say([NSString stringWithFormat:@"picker limit %ld filter %@ delegate %d", (long)picker.configuration.selectionLimit,
         picker.configuration.filter ? @"yes" : @"no", picker.delegate == self]);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    say([NSString stringWithFormat:@"picked %lu identifiers %d", (unsigned long)results.count,
         results.count > 0 && results.firstObject.assetIdentifier.length > 0]);
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *p = results.firstObject.itemProvider;
    if ([p canLoadObjectOfClass:UIImage.class])
        [p loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            UIImage *img = (UIImage *)object;
            dispatch_async(dispatch_get_main_queue(), ^{ say([NSString stringWithFormat:@"picked image %.0fx%.0f", img.size.width, img.size.height]); });
        }];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TestViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
