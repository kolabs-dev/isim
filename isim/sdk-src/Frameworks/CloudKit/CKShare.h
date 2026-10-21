#pragma once
/* isim CloudKit: shares, participants and user identities. Sharing is local: shares and identities stay in the device's
 * CloudKit store, no invitation is sent and no Apple directory is queried. A saved share's URL names its container, zone
 * and record, so any app on the device finds it. */
#import <CloudKit/CKOperation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
CK_EXTERN NSString * const CKShareTitleKey;
CK_EXTERN NSString * const CKShareThumbnailImageDataKey;
CK_EXTERN NSString * const CKShareTypeKey;
@interface CKUserIdentityLookupInfo : NSObject
- (instancetype)initWithEmailAddress:(NSString *)emailAddress;
- (instancetype)initWithPhoneNumber:(NSString *)phoneNumber;
- (instancetype)initWithUserRecordID:(CKRecordID *)userRecordID;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;
@property (nonatomic, readonly, copy, nullable) NSString *phoneNumber;
@property (nonatomic, readonly, copy, nullable) CKRecordID *userRecordID;
@end
@interface CKUserIdentity : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy, nullable) CKRecordID *userRecordID;
@property (nonatomic, readonly, copy, nullable) NSPersonNameComponents *nameComponents;
@property (nonatomic, readonly, assign) BOOL hasiCloudAccount;
@property (nonatomic, readonly, copy) NSArray<NSString *> *contactIdentifiers;
@end
typedef NS_ENUM(NSInteger, CKShareParticipantAcceptanceStatus) {
    CKShareParticipantAcceptanceStatusUnknown, CKShareParticipantAcceptanceStatusPending, CKShareParticipantAcceptanceStatusAccepted,
    CKShareParticipantAcceptanceStatusRemoved
};
typedef NS_ENUM(NSInteger, CKShareParticipantPermission) {
    CKShareParticipantPermissionUnknown, CKShareParticipantPermissionNone, CKShareParticipantPermissionReadOnly, CKShareParticipantPermissionReadWrite
};
typedef NS_ENUM(NSInteger, CKShareParticipantRole) {
    CKShareParticipantRoleUnknown = 0, CKShareParticipantRoleOwner = 1, CKShareParticipantRolePrivateUser = 3, CKShareParticipantRolePublicUser = 4
};
@interface CKShareParticipant : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) CKUserIdentity *userIdentity;
@property (nonatomic, readonly, assign) CKShareParticipantRole role;
@property (nonatomic, readonly, assign) CKShareParticipantAcceptanceStatus acceptanceStatus;
@property (nonatomic, assign) CKShareParticipantPermission permission;
@end
@interface CKShare : CKRecord
- (instancetype)initWithRootRecord:(CKRecord *)rootRecord;
- (instancetype)initWithRootRecord:(CKRecord *)rootRecord shareID:(CKRecordID *)shareID;
- (instancetype)initWithRecordZoneID:(CKRecordZoneID *)recordZoneID;
@property (nonatomic, assign) CKShareParticipantPermission publicPermission;
@property (nonatomic, readonly, copy, nullable) NSURL *URL;
@property (nonatomic, readonly, copy) NSArray<CKShareParticipant *> *participants;
@property (nonatomic, readonly, copy) CKShareParticipant *owner;
@property (nonatomic, readonly, copy, nullable) CKShareParticipant *currentUserParticipant;
- (void)addParticipant:(CKShareParticipant *)participant;
- (void)removeParticipant:(CKShareParticipant *)participant;
@end
@interface CKShareMetadata : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *containerIdentifier;
@property (nonatomic, readonly, copy) CKShare *share;
@property (nonatomic, readonly, copy, nullable) CKRecordID *hierarchicalRootRecordID;
@property (nonatomic, readonly, assign) CKShareParticipantRole participantRole;
@property (nonatomic, readonly, assign) CKShareParticipantAcceptanceStatus participantStatus;
@property (nonatomic, readonly, assign) CKShareParticipantPermission participantPermission;
@property (nonatomic, readonly, copy) CKUserIdentity *ownerIdentity;
@property (nonatomic, readonly, copy, nullable) CKRecord *rootRecord;
@end
@interface CKFetchShareMetadataOperation : CKOperation
- (instancetype)initWithShareURLs:(NSArray<NSURL *> *)shareURLs;
@property (nonatomic, copy, nullable) NSArray<NSURL *> *shareURLs;
@property (nonatomic, assign) BOOL shouldFetchRootRecord;
@property (nonatomic, copy, nullable) NSArray<CKRecordFieldKey> *rootRecordDesiredKeys;
@property (nonatomic, copy, nullable) void (^perShareMetadataBlock)(NSURL *shareURL, CKShareMetadata * _Nullable shareMetadata, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^fetchShareMetadataCompletionBlock)(NSError * _Nullable operationError);
@end
@interface CKAcceptSharesOperation : CKOperation
- (instancetype)initWithShareMetadatas:(NSArray<CKShareMetadata *> *)shareMetadatas;
@property (nonatomic, copy, nullable) NSArray<CKShareMetadata *> *shareMetadatas;
@property (nonatomic, copy, nullable) void (^perShareCompletionBlock)(CKShareMetadata *shareMetadata, CKShare * _Nullable acceptedShare, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^acceptSharesCompletionBlock)(NSError * _Nullable operationError);
@end
typedef NS_OPTIONS(NSUInteger, CKSharingParticipantAccessOption) {
    CKSharingParticipantAccessOptionAnyoneWithLink = 1 << 0, CKSharingParticipantAccessOptionSpecifiedRecipientsOnly = 1 << 1,
    CKSharingParticipantAccessOptionAny = CKSharingParticipantAccessOptionAnyoneWithLink | CKSharingParticipantAccessOptionSpecifiedRecipientsOnly
};
typedef NS_OPTIONS(NSUInteger, CKSharingParticipantPermissionOption) {
    CKSharingParticipantPermissionOptionReadOnly = 1 << 0, CKSharingParticipantPermissionOptionReadWrite = 1 << 1,
    CKSharingParticipantPermissionOptionAny = CKSharingParticipantPermissionOptionReadOnly | CKSharingParticipantPermissionOptionReadWrite
};
@interface CKAllowedSharingOptions : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithAllowedParticipantPermissionOptions:(CKSharingParticipantPermissionOption)allowedParticipantPermissionOptions
                            allowedParticipantAccessOptions:(CKSharingParticipantAccessOption)allowedParticipantAccessOptions;
@property (nonatomic, assign) CKSharingParticipantPermissionOption allowedParticipantPermissionOptions;
@property (nonatomic, assign) CKSharingParticipantAccessOption allowedParticipantAccessOptions;
@property (nonatomic, assign) BOOL allowsAccessRequests;
@property (nonatomic, assign) BOOL allowsParticipantsToInviteOthers;
@property (class, nonatomic, readonly, strong) CKAllowedSharingOptions *standardOptions;
@end
NS_ASSUME_NONNULL_END
#endif
