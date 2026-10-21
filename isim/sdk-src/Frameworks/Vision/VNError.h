#pragma once
#import <Vision/VNDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
VN_EXPORT NSString * const VNErrorDomain API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSInteger, VNErrorCode) {
    VNErrorTuplesOutOfRange = 0, VNErrorRequestCancelled, VNErrorInvalidFormat, VNErrorOperationFailed, VNErrorOutOfBoundsError,
    VNErrorInvalidOption, VNErrorIOError, VNErrorMissingOption, VNErrorNotImplemented, VNErrorInternalError, VNErrorOutOfMemory,
    VNErrorUnknownError, VNErrorInvalidOperation, VNErrorInvalidImage, VNErrorInvalidArgument, VNErrorInvalidModel,
    VNErrorUnsupportedRevision, VNErrorDataUnavailable, VNErrorTimeStampNotFound, VNErrorUnsupportedRequest, VNErrorTimeout,
    VNErrorUnsupportedComputeStage, VNErrorUnsupportedComputeDevice,
} API_AVAILABLE(ios(11.0));
NS_ASSUME_NONNULL_END
#endif
