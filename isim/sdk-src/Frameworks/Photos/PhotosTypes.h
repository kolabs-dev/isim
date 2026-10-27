#pragma once
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define PHOTOS_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define PHOTOS_EXTERN extern __attribute__((visibility("default")))
#endif
typedef NS_ENUM(NSInteger, PHAuthorizationStatus) {
    PHAuthorizationStatusNotDetermined = 0, PHAuthorizationStatusRestricted, PHAuthorizationStatusDenied, PHAuthorizationStatusAuthorized,
    PHAuthorizationStatusLimited API_AVAILABLE(ios(14)),
};
typedef NS_ENUM(NSInteger, PHAccessLevel) { PHAccessLevelAddOnly = 1, PHAccessLevelReadWrite = 2 } API_AVAILABLE(ios(14));
typedef NS_ENUM(NSInteger, PHAssetMediaType) { PHAssetMediaTypeUnknown = 0, PHAssetMediaTypeImage, PHAssetMediaTypeVideo, PHAssetMediaTypeAudio };
typedef NS_OPTIONS(NSUInteger, PHAssetMediaSubtype) {
    PHAssetMediaSubtypeNone = 0, PHAssetMediaSubtypePhotoPanorama = 1 << 0, PHAssetMediaSubtypePhotoHDR = 1 << 1,
    PHAssetMediaSubtypePhotoScreenshot = 1 << 2, PHAssetMediaSubtypePhotoLive = 1 << 3, PHAssetMediaSubtypePhotoDepthEffect = 1 << 4,
    PHAssetMediaSubtypeVideoStreamed = 1 << 16, PHAssetMediaSubtypeVideoHighFrameRate = 1 << 17, PHAssetMediaSubtypeVideoTimelapse = 1 << 18,
    PHAssetMediaSubtypeVideoCinematic = 1 << 21,
};
typedef NS_OPTIONS(NSUInteger, PHAssetSourceType) {
    PHAssetSourceTypeNone = 0, PHAssetSourceTypeUserLibrary = 1 << 0, PHAssetSourceTypeCloudShared = 1 << 1, PHAssetSourceTypeiTunesSynced = 1 << 2,
};
typedef NS_ENUM(NSInteger, PHAssetResourceType) {
    PHAssetResourceTypePhoto = 1, PHAssetResourceTypeVideo = 2, PHAssetResourceTypeAudio = 3, PHAssetResourceTypeAlternatePhoto = 4,
    PHAssetResourceTypeFullSizePhoto = 5, PHAssetResourceTypeFullSizeVideo = 6, PHAssetResourceTypeAdjustmentData = 7,
    PHAssetResourceTypeAdjustmentBasePhoto = 8, PHAssetResourceTypePairedVideo = 9, PHAssetResourceTypeFullSizePairedVideo = 10,
    PHAssetResourceTypeAdjustmentBasePairedVideo = 11, PHAssetResourceTypeAdjustmentBaseVideo = 12, PHAssetResourceTypePhotoProxy = 19,
};
typedef NS_ENUM(NSInteger, PHAssetPlaybackStyle) {
    PHAssetPlaybackStyleUnsupported = 0, PHAssetPlaybackStyleImage = 1, PHAssetPlaybackStyleImageAnimated = 2, PHAssetPlaybackStyleLivePhoto = 3,
    PHAssetPlaybackStyleVideo = 4, PHAssetPlaybackStyleVideoLooping = 5,
} API_AVAILABLE(ios(11));
typedef NS_ENUM(NSInteger, PHAssetCollectionType) { PHAssetCollectionTypeAlbum = 1, PHAssetCollectionTypeSmartAlbum = 2, PHAssetCollectionTypeMoment = 3 };
typedef NS_ENUM(NSInteger, PHAssetCollectionSubtype) {
    PHAssetCollectionSubtypeAlbumRegular = 2, PHAssetCollectionSubtypeAlbumSyncedEvent = 3, PHAssetCollectionSubtypeAlbumSyncedFaces = 4,
    PHAssetCollectionSubtypeAlbumSyncedAlbum = 5, PHAssetCollectionSubtypeAlbumImported = 6, PHAssetCollectionSubtypeAlbumMyPhotoStream = 100,
    PHAssetCollectionSubtypeAlbumCloudShared = 101, PHAssetCollectionSubtypeSmartAlbumGeneric = 200, PHAssetCollectionSubtypeSmartAlbumPanoramas = 201,
    PHAssetCollectionSubtypeSmartAlbumVideos = 202, PHAssetCollectionSubtypeSmartAlbumFavorites = 203, PHAssetCollectionSubtypeSmartAlbumTimelapses = 204,
    PHAssetCollectionSubtypeSmartAlbumAllHidden = 205, PHAssetCollectionSubtypeSmartAlbumRecentlyAdded = 206, PHAssetCollectionSubtypeSmartAlbumBursts = 207,
    PHAssetCollectionSubtypeSmartAlbumSlomoVideos = 208, PHAssetCollectionSubtypeSmartAlbumUserLibrary = 209, PHAssetCollectionSubtypeSmartAlbumSelfPortraits = 210,
    PHAssetCollectionSubtypeSmartAlbumScreenshots = 211, PHAssetCollectionSubtypeSmartAlbumDepthEffect = 212, PHAssetCollectionSubtypeSmartAlbumLivePhotos = 213,
    PHAssetCollectionSubtypeSmartAlbumAnimated = 214, PHAssetCollectionSubtypeSmartAlbumLongExposures = 215, PHAssetCollectionSubtypeSmartAlbumUnableToUpload = 216,
    PHAssetCollectionSubtypeSmartAlbumRAW = 217, PHAssetCollectionSubtypeSmartAlbumCinematic = 218, PHAssetCollectionSubtypeSmartAlbumSpatial = 219,
    PHAssetCollectionSubtypeAny = NSIntegerMax,
};
typedef NS_ENUM(NSInteger, PHCollectionEditOperation) {
    PHCollectionEditOperationDeleteContent = 1, PHCollectionEditOperationRemoveContent = 2, PHCollectionEditOperationAddContent = 3,
    PHCollectionEditOperationCreateContent = 4, PHCollectionEditOperationRearrangeContent = 5, PHCollectionEditOperationDelete = 6,
    PHCollectionEditOperationRename = 7,
};
typedef NS_ENUM(NSInteger, PHAssetEditOperation) { PHAssetEditOperationDelete = 1, PHAssetEditOperationContent = 2, PHAssetEditOperationProperties = 3 };
NS_ASSUME_NONNULL_END
#endif
