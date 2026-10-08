/* The device photo library as UIKit sees it: UIImageWriteToSavedPhotosAlbum and UIImagePickerController.
 *
 * The library lives in the device data like the Simulator's: $ISIM_DATA/Media/DCIM/100APPLE/IMG_nnnn.PNG plus an index,
 * $ISIM_DATA/Media/PhotoData/Photos.plist ({seeded, assets: [{id, file, created, width, height, favorite, app}]}; videos
 * add kind = video, duration and poster, a PNG of their first frame in PhotoData/Thumbnails),
 * shared with isim's Photos framework (Swift). On first use it is seeded with six generated landscape pictures,
 * standing in for the Simulator's sample photos (Apple's sample photos are not shipped).
 * Permission answers are stored in the app's defaults under _ISIMPrivacy.photos / _ISIMPrivacy.photosAdd (the same keys
 * the Photos framework uses). ISIM_PHOTOS_PERMISSION=allow|limited|deny answers the prompt without showing it. */
#import "UIKitPrivate.h"
#import "UIImagePickerCamera.h"
#include <objc/message.h>
#include <stdlib.h>
#include <sys/stat.h>

UIImagePickerControllerInfoKey const UIImagePickerControllerMediaType = @"UIImagePickerControllerMediaType";
UIImagePickerControllerInfoKey const UIImagePickerControllerOriginalImage = @"UIImagePickerControllerOriginalImage";
UIImagePickerControllerInfoKey const UIImagePickerControllerEditedImage = @"UIImagePickerControllerEditedImage";
UIImagePickerControllerInfoKey const UIImagePickerControllerCropRect = @"UIImagePickerControllerCropRect";
UIImagePickerControllerInfoKey const UIImagePickerControllerMediaURL = @"UIImagePickerControllerMediaURL";
UIImagePickerControllerInfoKey const UIImagePickerControllerReferenceURL = @"UIImagePickerControllerReferenceURL";
UIImagePickerControllerInfoKey const UIImagePickerControllerMediaMetadata = @"UIImagePickerControllerMediaMetadata";
UIImagePickerControllerInfoKey const UIImagePickerControllerImageURL = @"UIImagePickerControllerImageURL";
UIImagePickerControllerInfoKey const UIImagePickerControllerPHAsset = @"UIImagePickerControllerPHAsset";
UIImagePickerControllerInfoKey const UIImagePickerControllerLivePhoto = @"UIImagePickerControllerLivePhoto";

/* ---------------- library store ---------------- */
static NSString *media_dir(void) {
    const char *d = getenv("ISIM_DATA"), *h = getenv("HOME");
    NSString *root = d && *d ? @(d) : [@(h && *h ? h : "/tmp") stringByAppendingPathComponent:@".local/share/isim"];
    return [root stringByAppendingPathComponent:@"Media"];
}
static NSString *index_path(void) { return [media_dir() stringByAppendingPathComponent:@"PhotoData/Photos.plist"]; }
static NSMutableDictionary *load_index(void) {
    NSData *raw = [NSData dataWithContentsOfFile:index_path()];
    NSDictionary *d = raw ? [NSPropertyListSerialization propertyListWithData:raw options:0 format:NULL error:NULL] : nil;
    if (![d isKindOfClass:[NSDictionary class]]) d = nil;
    NSMutableDictionary *m = d ? [d mutableCopy] : [NSMutableDictionary dictionary];
    m[@"assets"] = [m[@"assets"] ?: @[] mutableCopy];
    return m;
}
static void save_index(NSDictionary *d) {
    [NSFileManager.defaultManager createDirectoryAtPath:[index_path() stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:d format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    if (![xml writeToFile:index_path() atomically:YES]) NSLog(@"isim: cannot write the photo library index %@", index_path());
}

/* adds a PNG/JPEG file's data to the library; returns the new asset record */
static NSDictionary *add_asset(NSMutableDictionary *idx, NSData *data, NSString *ext, CGSize px, double created, NSString *app) {
    NSString *dcim = [media_dir() stringByAppendingPathComponent:@"DCIM/100APPLE"];
    [NSFileManager.defaultManager createDirectoryAtPath:dcim withIntermediateDirectories:YES attributes:nil error:NULL];
    NSInteger n = [idx[@"next"] integerValue] ?: 1;
    NSString *name = [NSString stringWithFormat:@"IMG_%04ld.%@", (long)n, ext];
    idx[@"next"] = @(n + 1);
    if (![data writeToFile:[dcim stringByAppendingPathComponent:name] atomically:YES]) return nil;
    NSDictionary *a = @{ @"id": [NSString stringWithFormat:@"%@/L0/001", NSUUID.UUID.UUIDString], @"file": [@"DCIM/100APPLE" stringByAppendingPathComponent:name],
                         @"created": @(created), @"width": @(px.width), @"height": @(px.height), @"favorite": @NO, @"app": app ?: @"" };
    [idx[@"assets"] addObject:a];
    return a;
}

static UIImage *seed_picture(int k) {
    /* sky top, sky bottom, sun, far hills, near hills (RGB 0-255) */
    static const int pal[6][5][3] = {
        { {255, 120, 80}, {255, 210, 120}, {255, 245, 200}, {150, 70, 90}, {70, 30, 60} },      /* sunset */
        { {40, 120, 220}, {150, 210, 250}, {255, 250, 220}, {20, 90, 160}, {10, 60, 120} },     /* ocean */
        { {110, 180, 240}, {200, 235, 255}, {255, 255, 230}, {60, 140, 70}, {30, 90, 40} },     /* meadow */
        { {240, 170, 90}, {250, 225, 170}, {255, 250, 235}, {200, 120, 60}, {160, 80, 40} },    /* desert */
        { {10, 20, 60}, {50, 60, 120}, {235, 235, 250}, {30, 40, 80}, {15, 20, 45} },           /* night */
        { {150, 190, 230}, {230, 240, 250}, {255, 255, 255}, {200, 210, 225}, {240, 245, 250} },/* snow */
    };
    const int (*p)[3] = pal[k % 6];
    CGSize sz = CGSizeMake(800, 600);
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat]; fmt.scale = 1; fmt.opaque = YES;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:sz format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        for (int i = 0; i < 60; i++) {                       /* sky gradient in bands */
            double t = i / 59.0;
            CGContextSetRGBFillColor(c, (p[0][0] + (p[1][0] - p[0][0]) * t) / 255, (p[0][1] + (p[1][1] - p[0][1]) * t) / 255, (p[0][2] + (p[1][2] - p[0][2]) * t) / 255, 1);
            CGContextFillRect(c, CGRectMake(0, i * 7.5, sz.width, 8));
        }
        CGContextSetRGBFillColor(c, p[2][0] / 255.0, p[2][1] / 255.0, p[2][2] / 255.0, 1);
        double sx = 180 + 90 * k, sy = 130 + 25 * (k % 3), sr = k == 4 ? 40 : 60;
        CGContextFillEllipseInRect(c, CGRectMake(sx - sr, sy - sr, 2 * sr, 2 * sr));
        for (int layer = 0; layer < 2; layer++) {
            const int *col = p[3 + layer];
            CGContextSetRGBFillColor(c, col[0] / 255.0, col[1] / 255.0, col[2] / 255.0, 1);
            CGContextBeginPath(c);
            double base = layer ? 470 : 390, amp = layer ? 50 : 70, ph = k * 1.3 + layer * 2.1;
            CGContextMoveToPoint(c, 0, sz.height);
            for (int x = 0; x <= 800; x += 20) CGContextAddLineToPoint(c, x, base - amp * sin(x / 130.0 + ph) * cos(x / 310.0 + ph * 0.5));
            CGContextAddLineToPoint(c, sz.width, sz.height);
            CGContextClosePath(c);
            CGContextFillPath(c);
        }
    }];
}

/* seeds the library on first use (like the Simulator's sample photos); safe to call often */
void _isim_photos_seed(void) {
    NSMutableDictionary *idx = load_index();
    if ([idx[@"seeded"] boolValue]) return;
    double base = 1546300800;                                /* 2019-01-01; a picture every ~3 months */
    for (int k = 0; k < 6; k++) {
        UIImage *img = seed_picture(k);
        NSData *png = UIImagePNGRepresentation(img);
        if (png) add_asset(idx, png, @"PNG", CGSizeMake(800, 600), base + k * 8000000.0, @"com.apple.mobileslideshow");
    }
    /* sample pictures sort before anything saved earlier */
    NSMutableArray *assets = idx[@"assets"];
    [assets sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"created"] compare:b[@"created"]]; }];
    idx[@"seeded"] = @YES;
    save_index(idx);
    NSLog(@"isim: created the photo library with 6 sample pictures at %@", media_dir());
}

NSArray<NSDictionary *> *_isim_photos_assets(void) { _isim_photos_seed(); return load_index()[@"assets"]; }
NSString *_isim_photos_path(NSDictionary *asset) { return [media_dir() stringByAppendingPathComponent:asset[@"file"]]; }

/* ---------------- permission (shared keys with Photos.framework) ---------------- */
static NSString *app_name(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"App";
}
static UIViewController *top_vc(void) {
    UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController ?: UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}
/* calls done(YES) when the app may add photos; asks once (add-only access) */
static void request_add_access(void (^done)(BOOL)) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSInteger full = [ud integerForKey:@"_ISIMPrivacy.photos"], add = [ud integerForKey:@"_ISIMPrivacy.photosAdd"];
    if (full == 3 || full == 4 || add == 3) { done(YES); return; }
    if (add == 2 || add == 1) { done(NO); return; }
    NSString *purpose = NSBundle.mainBundle.infoDictionary[@"NSPhotoLibraryAddUsageDescription"];
    if (!purpose.length) {
        NSLog(@"isim Photos: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NSPhotoLibraryAddUsageDescription key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim reports the access as denied)");
        done(NO); return;
    }
    void (^answer)(BOOL) = ^(BOOL ok) {
        [ud setInteger:ok ? 3 : 2 forKey:@"_ISIMPrivacy.photosAdd"]; [ud synchronize];
        NSLog(@"isim Photos: adding photos %@ for %@", ok ? @"allowed" : @"not allowed", app_name());
        done(ok);
    };
    const char *env = getenv("ISIM_PHOTOS_PERMISSION");
    if (env && *env) { answer(strcmp(env, "deny") && strcmp(env, "0")); return; }
    UIViewController *top = top_vc();
    if (!top) { done(NO); return; }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"“%@” Would Like to Add to your Photos", app_name()]
                                                               message:purpose preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(NO); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(YES); }]];
    [top presentViewController:a animated:YES completion:nil];
}

void UIImageWriteToSavedPhotosAlbum(UIImage *image, id target, SEL sel, void *ctx) {
    dispatch_async(dispatch_get_main_queue(), ^{
        request_add_access(^(BOOL ok) {
            NSError *err = nil;
            if (ok) {
                NSData *png = image ? UIImagePNGRepresentation(image) : nil;
                _isim_photos_seed();
                NSMutableDictionary *idx = load_index();
                CGSize px = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
                NSDictionary *a = png ? add_asset(idx, png, @"PNG", px, NSDate.date.timeIntervalSince1970, NSBundle.mainBundle.bundleIdentifier) : nil;
                if (a) { save_index(idx); NSLog(@"isim Photos: saved %@ to the photo library", [a[@"file"] lastPathComponent]); }
                else err = [NSError errorWithDomain:@"ALAssetsLibraryErrorDomain" code:-3304 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to encode image for saved photos." }];
            } else err = [NSError errorWithDomain:@"ALAssetsLibraryErrorDomain" code:-3310 userInfo:@{ NSLocalizedDescriptionKey: @"Data unavailable" }];
            if (target && sel) ((void (*)(id, SEL, UIImage *, NSError *, void *))objc_msgSend)(target, sel, image, err, ctx);
        });
    });
}
/* a movie ffprobe can read with a video stream */
BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath) {
    struct isim_media_info i = {0};
    return videoPath.length && [NSFileManager.defaultManager fileExistsAtPath:videoPath] && isim_media_probe(videoPath.UTF8String, &i) && i.has_video;
}
/* copies the movie into the library (IMG_nnnn.MOV / .MP4) with a poster frame */
static NSDictionary *add_video_asset(NSMutableDictionary *idx, NSString *src, NSString *app) {
    struct isim_media_info info = {0};
    if (!isim_media_probe(src.UTF8String, &info) || !info.has_video) return nil;
    NSString *dcim = [media_dir() stringByAppendingPathComponent:@"DCIM/100APPLE"], *thumbs = [media_dir() stringByAppendingPathComponent:@"PhotoData/Thumbnails"];
    for (NSString *d in @[dcim, thumbs]) [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    NSInteger n = [idx[@"next"] integerValue] ?: 1;
    NSString *ext = [src.pathExtension.uppercaseString isEqualToString:@"MP4"] ? @"MP4" : @"MOV";
    NSString *name = [NSString stringWithFormat:@"IMG_%04ld.%@", (long)n, ext], *poster = [NSString stringWithFormat:@"IMG_%04ld.PNG", (long)n];
    if (![[NSData dataWithContentsOfFile:src] writeToFile:[dcim stringByAppendingPathComponent:name] atomically:YES]) return nil;
    idx[@"next"] = @(n + 1);
    void *png = NULL; long len = 0;
    if (isim_media_thumbnail_png([dcim stringByAppendingPathComponent:name].UTF8String, 0, 640, &png, &len) && png && len > 0)
        [[NSData dataWithBytes:png length:(NSUInteger)len] writeToFile:[thumbs stringByAppendingPathComponent:poster] atomically:YES];
    if (png) isim_media_free(png);
    NSDictionary *a = @{ @"id": [NSString stringWithFormat:@"%@/L0/001", NSUUID.UUID.UUIDString], @"file": [@"DCIM/100APPLE" stringByAppendingPathComponent:name],
                         @"created": @(NSDate.date.timeIntervalSince1970), @"width": @(info.width), @"height": @(info.height), @"favorite": @NO, @"app": app ?: @"",
                         @"kind": @"video", @"duration": @(info.duration), @"poster": [@"PhotoData/Thumbnails" stringByAppendingPathComponent:poster] };
    [idx[@"assets"] addObject:a];
    return a;
}
void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id target, SEL sel, void *ctx) {
    NSString *path = [videoPath copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        request_add_access(^(BOOL ok) {
            NSError *err = nil;
            if (ok) {
                _isim_photos_seed();
                NSMutableDictionary *idx = load_index();
                NSDictionary *a = add_video_asset(idx, path, NSBundle.mainBundle.bundleIdentifier);
                if (a) { save_index(idx); NSLog(@"isim Photos: saved video %@ to the photo library", [a[@"file"] lastPathComponent]); }
                else err = [NSError errorWithDomain:@"ALAssetsLibraryErrorDomain" code:-3302 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid data" }];
            } else err = [NSError errorWithDomain:@"ALAssetsLibraryErrorDomain" code:-3310 userInfo:@{ NSLocalizedDescriptionKey: @"Data unavailable" }];
            if (target && sel) ((void (*)(id, SEL, NSString *, NSError *, void *))objc_msgSend)(target, sel, path, err, ctx);
        });
    });
}
static BOOL is_video(NSDictionary *asset) { return [asset[@"kind"] isEqualToString:@"video"]; }
static UIImage *asset_thumbnail(NSDictionary *asset) {
    NSString *p = is_video(asset) ? [media_dir() stringByAppendingPathComponent:asset[@"poster"] ?: @""] : _isim_photos_path(asset);
    return [UIImage imageWithContentsOfFile:p];
}


/* ---------------- the picker grid ---------------- */
@interface __IsimPhotoGrid : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, copy) void (^onPick)(NSDictionary *asset);
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic) BOOL images, videos;          /* the picker's mediaTypes */
@end
@implementation __IsimPhotoGrid { NSArray<NSDictionary *> *_assets; UICollectionView *_grid; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Photos";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    cancel.accessibilityIdentifier = @"photos-cancel";
    [cancel addTarget:self action:@selector(isimPhotoGridCancel) forControlEvents:UIControlEventTouchUpInside];
    [cancel sizeToFit];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];
    NSMutableArray *shown = [NSMutableArray array];
    for (NSDictionary *a in _isim_photos_assets()) if (is_video(a) ? self.videos : self.images) [shown addObject:a];
    _assets = shown;
    UICollectionViewFlowLayout *l = [UICollectionViewFlowLayout new];
    CGFloat side = floor((UIScreen.mainScreen.bounds.size.width - 6) / 4);
    l.itemSize = CGSizeMake(side, side); l.minimumLineSpacing = 2; l.minimumInteritemSpacing = 2;
    _grid = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:l];
    _grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _grid.dataSource = self; _grid.delegate = self;
    _grid.backgroundColor = UIColor.systemBackgroundColor;
    [_grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"p"];
    [self.view addSubview:_grid];
}
- (void)isimPhotoGridCancel { if (self.onCancel) self.onCancel(); }
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return (NSInteger)_assets.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"p" forIndexPath:ip];
    UIImageView *iv = (UIImageView *)[cell.contentView viewWithTag:77];
    if (!iv) {
        iv = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
        iv.tag = 77; iv.contentMode = UIViewContentModeScaleAspectFill; iv.clipsToBounds = YES;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:iv];
    }
    NSDictionary *asset = _assets[ip.item];
    iv.image = asset_thumbnail(asset);
    UILabel *dur = (UILabel *)[cell.contentView viewWithTag:78];
    if (!dur) {
        dur = [[UILabel alloc] initWithFrame:CGRectMake(4, cell.contentView.bounds.size.height - 20, cell.contentView.bounds.size.width - 8, 18)];
        dur.tag = 78; dur.textAlignment = NSTextAlignmentRight; dur.textColor = UIColor.whiteColor;
        dur.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        dur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [cell.contentView addSubview:dur];
    }
    long secs = lround([asset[@"duration"] doubleValue]);
    dur.text = is_video(asset) ? [NSString stringWithFormat:@"%ld:%02ld", secs / 60, secs % 60] : nil;
    cell.accessibilityIdentifier = [NSString stringWithFormat:@"%@-%ld", is_video(asset) ? @"video" : @"photo", (long)ip.item];
    return cell;
}
- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip { if (self.onPick) self.onPick(_assets[ip.item]); }
@end

/* ---------------- UIImagePickerController ---------------- */
@implementation UIImagePickerController {
    UIImagePickerControllerSourceType _source;
    __IsimCameraController *_camera;
    UIImagePickerControllerCameraDevice _cameraDevice;
    UIImagePickerControllerCameraCaptureMode _captureMode;
    UIView *_overlay;
    BOOL _showsControls;
    CGAffineTransform _viewTransform;
}
@dynamic delegate;
+ (BOOL)isSourceTypeAvailable:(UIImagePickerControllerSourceType)t {
    return t == UIImagePickerControllerSourceTypeCamera ? isim_ui_camera_available() : t == UIImagePickerControllerSourceTypePhotoLibrary || t == UIImagePickerControllerSourceTypeSavedPhotosAlbum;
}
+ (NSArray<NSString *> *)availableMediaTypesForSourceType:(UIImagePickerControllerSourceType)t {
    return [self isSourceTypeAvailable:t] ? @[@"public.image", @"public.movie"] : nil;
}
/* the simulated camera stands in for both (front shows it mirrored) */
+ (BOOL)isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)d { return isim_ui_camera_available(); }
+ (BOOL)isFlashAvailableForCameraDevice:(UIImagePickerControllerCameraDevice)d { return NO; }
+ (NSArray<NSNumber *> *)availableCaptureModesForCameraDevice:(UIImagePickerControllerCameraDevice)d {
    return isim_ui_camera_available() ? @[@(UIImagePickerControllerCameraCaptureModePhoto), @(UIImagePickerControllerCameraCaptureModeVideo)] : nil;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) {
        self.mediaTypes = @[@"public.image"]; self.videoMaximumDuration = 600; _showsControls = YES; _viewTransform = CGAffineTransformIdentity;
        self.videoQuality = UIImagePickerControllerQualityTypeMedium; self.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        self.videoExportPreset = @"AVAssetExportPresetPassthrough";
    }
    return self;
}
- (UIImagePickerControllerSourceType)sourceType { return _source; }
- (void)setSourceType:(UIImagePickerControllerSourceType)t {
    if (![UIImagePickerController isSourceTypeAvailable:t])
        [NSException raise:NSInvalidArgumentException format:@"Source type %ld not available", (long)t];   /* like iOS (the Simulator has no camera) */
    _source = t;
    if (t == UIImagePickerControllerSourceTypeCamera) self.modalPresentationStyle = UIModalPresentationFullScreen;
}
- (void)_requireCamera:(const char *)what {
    if (_source != UIImagePickerControllerSourceTypeCamera)
        [NSException raise:NSInvalidArgumentException format:@"%s is only available for the camera source", what];
}
- (BOOL)showsCameraControls { return _showsControls; }
- (void)setShowsCameraControls:(BOOL)v { [self _requireCamera:"showsCameraControls"]; _showsControls = v; _camera.showsControls = v; }
- (UIView *)cameraOverlayView { return _overlay; }
- (void)setCameraOverlayView:(UIView *)v { [self _requireCamera:"cameraOverlayView"]; _overlay = v; _camera.overlay = v; }
- (CGAffineTransform)cameraViewTransform { return _viewTransform; }
- (void)setCameraViewTransform:(CGAffineTransform)t { [self _requireCamera:"cameraViewTransform"]; _viewTransform = t; _camera.previewTransform = t; }
- (UIImagePickerControllerCameraDevice)cameraDevice { return _camera ? _camera.cameraDevice : _cameraDevice; }
- (void)setCameraDevice:(UIImagePickerControllerCameraDevice)d { [self _requireCamera:"cameraDevice"]; _cameraDevice = d; _camera.cameraDevice = d; }
- (UIImagePickerControllerCameraCaptureMode)cameraCaptureMode { return _captureMode; }
- (void)setCameraCaptureMode:(UIImagePickerControllerCameraCaptureMode)m {
    [self _requireCamera:"cameraCaptureMode"];
    BOOL movie = [self.mediaTypes containsObject:@"public.movie"], image = [self.mediaTypes containsObject:@"public.image"];
    if ((m == UIImagePickerControllerCameraCaptureModeVideo && !movie) || (m == UIImagePickerControllerCameraCaptureModePhoto && !image))
        [NSException raise:NSInvalidArgumentException format:@"cameraCaptureMode %ld is not allowed by mediaTypes %@", (long)m, self.mediaTypes];
    _captureMode = m; _camera.captureMode = m;
}
- (void)setMediaTypes:(NSArray<NSString *> *)t {
    _mediaTypes = [t copy];
    if (_source == UIImagePickerControllerSourceTypeCamera && ![t containsObject:@"public.image"] && [t containsObject:@"public.movie"]) _captureMode = UIImagePickerControllerCameraCaptureModeVideo;
}
- (void)takePicture { if (_camera) [_camera takePicture]; else NSLog(@"isim: -[UIImagePickerController takePicture] without the camera source"); }
- (BOOL)startVideoCapture { return _camera ? [_camera startVideoCapture] : NO; }
- (void)stopVideoCapture { [_camera stopVideoCapture]; }
- (id<UIImagePickerControllerDelegate>)_pickerDelegate { return (id)self.delegate; }
- (void)_finish:(NSDictionary *)info {
    id<UIImagePickerControllerDelegate> d = [self _pickerDelegate];
    if ([d respondsToSelector:@selector(imagePickerController:didFinishPickingMediaWithInfo:)]) [d imagePickerController:self didFinishPickingMediaWithInfo:info];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
- (void)_cancel {
    id<UIImagePickerControllerDelegate> d = [self _pickerDelegate];
    if ([d respondsToSelector:@selector(imagePickerControllerDidCancel:)]) [d imagePickerControllerDidCancel:self];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
/* allowsEditing: the "Move and Scale" square, then the info with the edited image and its crop rect */
- (void)_editImage:(UIImage *)img info:(NSMutableDictionary *)info cancelTitle:(NSString *)cancel onCancel:(void (^)(void))back {
    __IsimCropController *c = [__IsimCropController new];
    c.image = img; c.cancelTitle = cancel;
    __weak UIImagePickerController *w = self;
    c.onCancel = back;
    c.onChoose = ^(UIImage *edited, CGRect r) {
        CGFloat sc = img.scale;
        info[UIImagePickerControllerEditedImage] = edited;
        info[UIImagePickerControllerCropRect] = [NSValue valueWithCGRect:CGRectMake(r.origin.x * sc, r.origin.y * sc, r.size.width * sc, r.size.height * sc)];
        [w _finish:info];
    };
    [self pushViewController:c animated:YES];
}
/* a copy of a library movie in tmp, like iOS's picker (the app owns it) */
static NSURL *movie_copy(NSString *src) {
    NSString *dst = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"trim.%@.%@", NSUUID.UUID.UUIDString, src.pathExtension.uppercaseString ?: @"MOV"]];
    return [[NSData dataWithContentsOfFile:src] writeToFile:dst atomically:YES] ? [NSURL fileURLWithPath:dst] : nil;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.viewControllers.count) return;
    __weak UIImagePickerController *weakSelf = self;
    BOOL images = [self.mediaTypes containsObject:@"public.image"], videos = [self.mediaTypes containsObject:@"public.movie"];
    if (_source == UIImagePickerControllerSourceTypeCamera) {
        self.navigationBarHidden = YES;
        _camera = [__IsimCameraController new];
        _camera.cameraDevice = _cameraDevice; _camera.captureMode = images ? _captureMode : UIImagePickerControllerCameraCaptureModeVideo;
        _camera.allowsPhoto = images; _camera.allowsVideo = videos; _camera.showsControls = _showsControls;
        _camera.quality = self.videoQuality; _camera.maxDuration = self.videoMaximumDuration;
        _camera.previewTransform = _viewTransform; _camera.overlay = _overlay;
        _camera.onCancel = ^{ [weakSelf _cancel]; };
        _camera.onModeChange = ^(UIImagePickerControllerCameraCaptureMode m) { UIImagePickerController *s = weakSelf; if (s) s->_captureMode = m; };
        _camera.onPhoto = ^(UIImage *img, NSDictionary *meta) {
            UIImagePickerController *s = weakSelf; if (!s) return;
            NSMutableDictionary *info = [@{ UIImagePickerControllerMediaType: @"public.image", UIImagePickerControllerOriginalImage: img,
                                            UIImagePickerControllerMediaMetadata: meta } mutableCopy];
            if (s.allowsEditing && s->_showsControls)
                [s _editImage:img info:info cancelTitle:@"Retake" onCancel:^{ [weakSelf popViewControllerAnimated:YES]; }];
            else [s _finish:info];
        };
        _camera.onMovie = ^(NSURL *url) {
            [weakSelf _finish:@{ UIImagePickerControllerMediaType: @"public.movie", UIImagePickerControllerMediaURL: url }];
        };
        self.viewControllers = @[_camera];
        return;
    }
    __IsimPhotoGrid *g = [__IsimPhotoGrid new];
    g.images = images; g.videos = videos;
    if (_source == UIImagePickerControllerSourceTypeSavedPhotosAlbum) g.title = @"Moments";
    g.onCancel = ^{ [weakSelf _cancel]; };
    g.onPick = ^(NSDictionary *asset) {
        UIImagePickerController *s = weakSelf; if (!s) return;
        NSString *path = _isim_photos_path(asset);
        NSLog(@"isim: UIImagePickerController picked %@", [asset[@"file"] lastPathComponent]);
        if (is_video(asset)) {                         /* adapted: allowsEditing does not offer trimming */
            NSURL *u = movie_copy(path);
            if (u) [s _finish:@{ UIImagePickerControllerMediaType: @"public.movie", UIImagePickerControllerMediaURL: u }];
            return;
        }
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        NSMutableDictionary *info = [@{ UIImagePickerControllerMediaType: @"public.image",
                                        UIImagePickerControllerImageURL: [NSURL fileURLWithPath:path] } mutableCopy];
        if (img) info[UIImagePickerControllerOriginalImage] = img;
        if (img && s.allowsEditing) [s _editImage:img info:info cancelTitle:@"Cancel" onCancel:^{ [weakSelf popViewControllerAnimated:YES]; }];
        else [s _finish:info];
    };
    self.viewControllers = @[g];
}
@end
