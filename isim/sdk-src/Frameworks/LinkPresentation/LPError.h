#pragma once
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSErrorDomain const LPErrorDomain API_AVAILABLE(ios(13.0));
typedef NS_ERROR_ENUM(LPErrorDomain, LPErrorCode) {
    LPErrorUnknown = 1,
    LPErrorMetadataFetchFailed,
    LPErrorMetadataFetchCancelled,
    LPErrorMetadataFetchTimedOut,
    LPErrorMetadataFetchNotAllowed API_AVAILABLE(ios(17.0)),
} API_AVAILABLE(ios(13.0));
NS_ASSUME_NONNULL_END

#endif
