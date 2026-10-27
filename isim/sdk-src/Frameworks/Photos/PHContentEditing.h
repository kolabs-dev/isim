#pragma once
/* isim: PHAdjustmentData, PHContentEditingInputRequestOptions, PHContentEditingInput and PHContentEditingOutput (Apple
   declares them in PHAdjustmentData.h, PHContentEditingInput.h and PHContentEditingOutput.h, which include this) */
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIImage, CLLocation, AVAsset, PHLivePhoto, PHObjectPlaceholder, UTType;
/* an app's description of an edit, stored with the edited asset */
API_AVAILABLE(ios(8))
@interface PHAdjustmentData : NSObject <NSSecureCoding>
- (instancetype)initWithFormatIdentifier:(NSString *)formatIdentifier formatVersion:(NSString *)formatVersion data:(NSData *)data;
@property (nonatomic, copy) NSString *formatIdentifier;
@property (nonatomic, copy) NSString *formatVersion;
@property (nonatomic, strong) NSData *data;
@end
typedef NS_ENUM(NSInteger, PHContentEditingInputRequestOptionsOriginalResourceChoice) {
    PHContentEditingInputRequestOptionsOriginalResourceChoiceDefault = 0,
    PHContentEditingInputRequestOptionsOriginalResourceChoiceAlternate = 1,
} API_AVAILABLE(ios(17));
API_AVAILABLE(ios(8))
@interface PHContentEditingInputRequestOptions : NSObject
@property (nonatomic, copy) BOOL (^canHandleAdjustmentData)(PHAdjustmentData *adjustmentData);
@property (nonatomic, assign, getter=isNetworkAccessAllowed) BOOL networkAccessAllowed;
@property (nonatomic, copy, nullable) void (^progressHandler)(double progress, BOOL *stop);
@property (nonatomic, assign) BOOL skipsDisplaySizeImage API_AVAILABLE(ios(17));
@property (nonatomic, assign) NSInteger originalResourceChoice API_AVAILABLE(ios(17));
@end
API_AVAILABLE(ios(8))
@interface PHContentEditingInput : NSObject
@property (nonatomic, assign, readonly) PHAssetMediaType mediaType;
@property (nonatomic, assign, readonly) PHAssetMediaSubtype mediaSubtypes;
@property (nonatomic, assign, readonly) PHAssetPlaybackStyle playbackStyle API_AVAILABLE(ios(11));
@property (nonatomic, copy, readonly, nullable) NSDate *creationDate;
@property (nonatomic, copy, readonly, nullable) CLLocation *location;
@property (nonatomic, copy, readonly, nullable) NSString *uniformTypeIdentifier;
@property (nonatomic, strong, readonly, nullable) PHAdjustmentData *adjustmentData;
@property (nonatomic, strong, readonly, nullable) UIImage *displaySizeImage;
@property (nonatomic, copy, readonly, nullable) NSURL *fullSizeImageURL;
@property (nonatomic, assign, readonly) int fullSizeImageOrientation;
@property (nonatomic, strong, readonly, nullable) AVAsset *audiovisualAsset API_AVAILABLE(ios(9));
@property (nonatomic, strong, readonly, nullable) PHLivePhoto *livePhoto API_AVAILABLE(ios(10));
@end
/* where an app puts an edit: a JPEG (or PNG) for photos, a QuickTime movie for videos, with the adjustments */
API_AVAILABLE(ios(8))
@interface PHContentEditingOutput : NSObject <NSSecureCoding>
- (instancetype)initWithContentEditingInput:(PHContentEditingInput *)contentEditingInput;
- (instancetype)initWithPlaceholderForCreatedAsset:(PHObjectPlaceholder *)placeholderForCreatedAsset;
@property (nonatomic, strong, nullable) PHAdjustmentData *adjustmentData;
@property (nonatomic, copy, readonly) NSURL *renderedContentURL;
@end
NS_ASSUME_NONNULL_END
#endif
