#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const QLThumbnailErrorDomain API_AVAILABLE(ios(13.0));
/* Swift: the overlay's QLThumbnailError (an error struct that NSErrors of the domain bridge to) */
#if !defined(__swift__)
typedef NS_ERROR_ENUM(QLThumbnailErrorDomain, QLThumbnailError) {
    QLThumbnailErrorGenerationFailed = 0,
    QLThumbnailErrorSavingToURLFailed,
    QLThumbnailErrorNoCachedThumbnail,
    QLThumbnailErrorNoCloudThumbnail,
    QLThumbnailErrorRequestInvalid,
    QLThumbnailErrorRequestCancelled,
} API_AVAILABLE(ios(13.0));
#endif

NS_ASSUME_NONNULL_END
