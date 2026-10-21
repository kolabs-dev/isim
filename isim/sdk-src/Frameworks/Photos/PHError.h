#pragma once
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
PHOTOS_EXTERN NSString * const PHPhotosErrorDomain API_AVAILABLE(ios(13));
PHOTOS_EXTERN NSString * const PHLocalIdentifierNotFound API_AVAILABLE(ios(15));
typedef NS_ERROR_ENUM(PHPhotosErrorDomain, PHPhotosErrorCode) {
    PHPhotosErrorInternalError = -1, PHPhotosErrorInvalid = -2, PHPhotosErrorUserCancelled = 3072, PHPhotosErrorLibraryVolumeOffline = 3114,
    PHPhotosErrorRelinquishingLibraryBundleToWriter = 3142, PHPhotosErrorSwitchingSystemPhotoLibrary = 3143, PHPhotosErrorNetworkAccessRequired = 3164,
    PHPhotosErrorNetworkError = 3169, PHPhotosErrorIdentifierNotFound = 3201, PHPhotosErrorMultipleIdentifiersFound = 3202,
    PHPhotosErrorChangeNotSupported = 3300, PHPhotosErrorOperationInterrupted = 3301, PHPhotosErrorInvalidResource = 3302,
    PHPhotosErrorMissingResource = 3303, PHPhotosErrorNotEnoughSpace = 3305, PHPhotosErrorRequestNotSupportedForAsset = 3306,
    PHPhotosErrorAccessRestricted = 3310, PHPhotosErrorAccessUserDenied = 3311, PHPhotosErrorLibraryInFileProviderSyncRoot = 5423,
    PHPhotosErrorPersistentChangeTokenExpired = 3105, PHPhotosErrorPersistentChangeDetailsUnavailable = 3210,
} API_AVAILABLE(ios(13));
NS_ASSUME_NONNULL_END
#endif
