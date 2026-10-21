#pragma once
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHPickerViewController;
/* a description of what the picker shows: kinds of library items, combined */
API_AVAILABLE(ios(14))
@interface PHPickerFilter : NSObject <NSCopying>
@property (class, readonly) PHPickerFilter *imagesFilter;
@property (class, readonly) PHPickerFilter *videosFilter;
@property (class, readonly) PHPickerFilter *livePhotosFilter;
@property (class, readonly) PHPickerFilter *depthEffectPhotosFilter API_AVAILABLE(ios(16));
@property (class, readonly) PHPickerFilter *burstsFilter API_AVAILABLE(ios(16));
@property (class, readonly) PHPickerFilter *panoramasFilter API_AVAILABLE(ios(15));
@property (class, readonly) PHPickerFilter *screenshotsFilter API_AVAILABLE(ios(15));
@property (class, readonly) PHPickerFilter *screenRecordingsFilter API_AVAILABLE(ios(15));
@property (class, readonly) PHPickerFilter *cinematicVideosFilter API_AVAILABLE(ios(16));
@property (class, readonly) PHPickerFilter *slomoVideosFilter API_AVAILABLE(ios(15));
@property (class, readonly) PHPickerFilter *timelapseVideosFilter API_AVAILABLE(ios(15));
@property (class, readonly) PHPickerFilter *spatialMediaFilter API_AVAILABLE(ios(18));
/* isim: any playback style matches the images */
+ (PHPickerFilter *)playbackStyleFilter:(NSInteger)playbackStyle API_AVAILABLE(ios(17));
+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters;
+ (PHPickerFilter *)allFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters API_AVAILABLE(ios(15));
+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter API_AVAILABLE(ios(15));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
typedef NS_ENUM(NSInteger, PHPickerConfigurationAssetRepresentationMode) {
    PHPickerConfigurationAssetRepresentationModeAutomatic = 0, PHPickerConfigurationAssetRepresentationModeCurrent = 1,
    PHPickerConfigurationAssetRepresentationModeCompatible = 2,
} API_AVAILABLE(ios(14));
typedef NS_ENUM(NSInteger, PHPickerConfigurationSelection) {
    PHPickerConfigurationSelectionDefault = 0, PHPickerConfigurationSelectionOrdered = 1, PHPickerConfigurationSelectionContinuous = 2,
    PHPickerConfigurationSelectionContinuousAndOrdered = 3,
} API_AVAILABLE(ios(15));
API_AVAILABLE(ios(14))
@interface PHPickerConfiguration : NSObject <NSCopying>
@property (nonatomic) PHPickerConfigurationAssetRepresentationMode preferredAssetRepresentationMode;
@property (nonatomic) PHPickerConfigurationSelection selection API_AVAILABLE(ios(15));
/* 0: no limit */
@property (nonatomic) NSInteger selectionLimit;
@property (nonatomic, copy, nullable) PHPickerFilter *filter;
@property (nonatomic, copy) NSArray<NSString *> *preselectedAssetIdentifiers API_AVAILABLE(ios(15));
/* with a photo library, the results carry the assets' identifiers */
- (instancetype)initWithPhotoLibrary:(PHPhotoLibrary *)photoLibrary;
- (instancetype)init;
@end
API_AVAILABLE(ios(14))
@interface PHPickerResult : NSObject
@property (nonatomic, readonly) NSItemProvider *itemProvider;
@property (nonatomic, readonly, nullable) NSString *assetIdentifier;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(14))
@protocol PHPickerViewControllerDelegate <NSObject>
/* called on the main thread; the delegate dismisses the picker */
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results;
@end
/* isim: a grid of the device photo library; like iOS it runs outside the app's photo permission and hands back item
   providers (photos as data, videos as files) */
API_AVAILABLE(ios(14))
@interface PHPickerViewController : UIViewController
@property (nonatomic, copy, readonly) PHPickerConfiguration *configuration;
@property (nonatomic, weak, nullable) id<PHPickerViewControllerDelegate> delegate;
- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (void)deselectAssetsWithIdentifiers:(NSArray<NSString *> *)identifiers API_AVAILABLE(ios(17));
- (void)moveAssetWithIdentifier:(NSString *)identifier afterAssetWithIdentifier:(nullable NSString *)afterIdentifier API_AVAILABLE(ios(17));
- (void)scrollToInitialPosition API_AVAILABLE(ios(17));
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
