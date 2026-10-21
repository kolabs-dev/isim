#pragma once
/* isim CloudKit: CKErrorDomain and its codes and keys (the CloudKit Swift overlay's values). */
#import <CloudKit/CKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
CK_EXTERN NSString * const CKErrorDomain;
CK_EXTERN NSString * const CKPartialErrorsByItemIDKey;
CK_EXTERN NSString * const CKRecordChangedErrorAncestorRecordKey;
CK_EXTERN NSString * const CKRecordChangedErrorServerRecordKey;
CK_EXTERN NSString * const CKRecordChangedErrorClientRecordKey;
CK_EXTERN NSString * const CKErrorRetryAfterKey;
typedef NS_ERROR_ENUM(CKErrorDomain, CKErrorCode) {
    CKErrorInternalError = 1, CKErrorPartialFailure = 2, CKErrorNetworkUnavailable = 3, CKErrorNetworkFailure = 4,
    CKErrorBadContainer = 5, CKErrorServiceUnavailable = 6, CKErrorRequestRateLimited = 7, CKErrorMissingEntitlement = 8,
    CKErrorNotAuthenticated = 9, CKErrorPermissionFailure = 10, CKErrorUnknownItem = 11, CKErrorInvalidArguments = 12,
    CKErrorResultsTruncated = 13, CKErrorServerRecordChanged = 14, CKErrorServerRejectedRequest = 15, CKErrorAssetFileNotFound = 16,
    CKErrorAssetFileModified = 17, CKErrorIncompatibleVersion = 18, CKErrorConstraintViolation = 19, CKErrorOperationCancelled = 20,
    CKErrorChangeTokenExpired = 21, CKErrorBatchRequestFailed = 22, CKErrorZoneBusy = 23, CKErrorBadDatabase = 24,
    CKErrorQuotaExceeded = 25, CKErrorZoneNotFound = 26, CKErrorLimitExceeded = 27, CKErrorUserDeletedZone = 28,
    CKErrorTooManyParticipants = 29, CKErrorAlreadyShared = 30, CKErrorReferenceViolation = 31, CKErrorManagedAccountRestricted = 32,
    CKErrorParticipantMayNeedVerification = 33, CKErrorServerResponseLost = 34, CKErrorAssetNotAvailable = 35,
    CKErrorAccountTemporarilyUnavailable = 36
};
NS_ASSUME_NONNULL_END
#endif
