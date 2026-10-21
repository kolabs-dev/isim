#pragma once
/* isim GameKit: GKErrorDomain and GKErrorCode (the overlay's GKError bridges to NSError in this domain). */
#import <GameKit/GKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
GK_EXTERN NSString * const GKErrorDomain;
typedef NS_ERROR_ENUM(GKErrorDomain, GKErrorCode) {
    GKErrorUnknown = 1, GKErrorCancelled = 2, GKErrorCommunicationsFailure = 3, GKErrorUserDenied = 4, GKErrorInvalidCredentials = 5,
    GKErrorNotAuthenticated = 6, GKErrorAuthenticationInProgress = 7, GKErrorInvalidPlayer = 8, GKErrorScoreNotSet = 9,
    GKErrorParentalControlsBlocked = 10, GKErrorPlayerStatusExceedsMaximumLength = 11, GKErrorPlayerStatusInvalid = 12,
    GKErrorMatchRequestInvalid = 13, GKErrorUnderage = 14, GKErrorGameUnrecognized = 15, GKErrorNotSupported = 16,
    GKErrorInvalidParameter = 17, GKErrorUnexpectedConnection = 18, GKErrorChallengeInvalid = 19, GKErrorTurnBasedMatchDataTooLarge = 20,
    GKErrorTurnBasedTooManySessions = 21, GKErrorTurnBasedInvalidParticipant = 22, GKErrorTurnBasedInvalidTurn = 23,
    GKErrorTurnBasedInvalidState = 24, GKErrorInvitationsDisabled = 25, GKErrorPlayerPhotoFailure = 26, GKErrorUbiquityContainerUnavailable = 27,
    GKErrorMatchNotConnected = 28, GKErrorGameSessionRequestInvalid = 29, GKErrorRestrictedToAutomatch = 30, GKErrorAPINotAvailable = 31,
    GKErrorNotAuthorized = 32, GKErrorConnectionTimeout = 33, GKErrorAPIObsolete = 34, GKErrorICloudUnavailable = 35, GKErrorLockdownMode = 36,
    GKErrorAppUnlisted = 37, GKErrorFriendListDescriptionMissing = 100, GKErrorFriendListRestricted = 101, GKErrorFriendListDenied = 102,
    GKErrorFriendRequestNotAvailable = 103
};
NS_ASSUME_NONNULL_END
#endif
