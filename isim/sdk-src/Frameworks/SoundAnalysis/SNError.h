#pragma once
#import <SoundAnalysis/SNDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
SN_EXPORT NSString * const SNErrorDomain API_AVAILABLE(ios(13.0));
typedef NS_ERROR_ENUM(SNErrorDomain, SNErrorCode) {
    SNErrorCodeUnknownError = 1,
    SNErrorCodeOperationFailed,
    SNErrorCodeInvalidFormat,
    SNErrorCodeInvalidModel,
    SNErrorCodeInvalidFile,
} API_AVAILABLE(ios(13.0));
NS_ASSUME_NONNULL_END
#endif
