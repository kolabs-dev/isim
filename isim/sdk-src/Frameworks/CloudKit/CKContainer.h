#pragma once
/* isim CloudKit: containers and databases. isim's CloudKit is local: no iCloud, no sync, no Apple servers. Records,
 * zones, queries, subscriptions and change tokens behave like CloudKit's against a store in the device data, and the
 * device is signed in to a simulated iCloud account (ISIM_ICLOUD=noAccount signs it out). Completion handlers run on a
 * background queue, like CloudKit's. */
#import <CloudKit/CKRecord.h>
#import <CloudKit/CKQuery.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CKDatabase, CKOperation, CKDatabaseOperation, CKSubscription, CKShare, CKShareMetadata, CKShareParticipant, CKUserIdentity, CKUserIdentityLookupInfo;
typedef NS_ENUM(NSInteger, CKAccountStatus) {
    CKAccountStatusCouldNotDetermine = 0, CKAccountStatusAvailable = 1, CKAccountStatusRestricted = 2, CKAccountStatusNoAccount = 3,
    CKAccountStatusTemporarilyUnavailable = 4
};
CK_EXTERN NSString * const CKAccountChangedNotification;
typedef NS_ENUM(NSInteger, CKDatabaseScope) { CKDatabaseScopePublic = 1, CKDatabaseScopePrivate, CKDatabaseScopeShared };
typedef NSString * CKSubscriptionID;

@interface CKContainer : NSObject
/* "iCloud.<bundle id>" */
+ (CKContainer *)defaultContainer;
+ (CKContainer *)containerWithIdentifier:(NSString *)containerIdentifier;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, nullable) NSString *containerIdentifier;
- (void)addOperation:(CKOperation *)operation;
@property (nonatomic, readonly) CKDatabase *privateCloudDatabase;
@property (nonatomic, readonly) CKDatabase *publicCloudDatabase;
@property (nonatomic, readonly) CKDatabase *sharedCloudDatabase;
- (CKDatabase *)databaseWithDatabaseScope:(CKDatabaseScope)databaseScope;
- (void)accountStatusWithCompletionHandler:(void (^)(CKAccountStatus accountStatus, NSError * _Nullable error))completionHandler;
- (void)fetchUserRecordIDWithCompletionHandler:(void (^)(CKRecordID * _Nullable recordID, NSError * _Nullable error))completionHandler;
- (void)fetchShareParticipantWithEmailAddress:(NSString *)emailAddress
                            completionHandler:(void (^)(CKShareParticipant * _Nullable shareParticipant, NSError * _Nullable error))completionHandler;
- (void)fetchShareParticipantWithPhoneNumber:(NSString *)phoneNumber
                           completionHandler:(void (^)(CKShareParticipant * _Nullable shareParticipant, NSError * _Nullable error))completionHandler;
- (void)fetchShareParticipantWithUserRecordID:(CKRecordID *)userRecordID
                            completionHandler:(void (^)(CKShareParticipant * _Nullable shareParticipant, NSError * _Nullable error))completionHandler;
- (void)fetchShareMetadataWithURL:(NSURL *)url completionHandler:(void (^)(CKShareMetadata * _Nullable metadata, NSError * _Nullable error))completionHandler;
- (void)acceptShareMetadata:(CKShareMetadata *)metadata completionHandler:(void (^)(CKShare * _Nullable acceptedShare, NSError * _Nullable error))completionHandler;
- (void)discoverUserIdentityWithEmailAddress:(NSString *)email completionHandler:(void (^)(CKUserIdentity * _Nullable userInfo, NSError * _Nullable error))completionHandler
    API_DEPRECATED("no longer supported", ios(10.0, 17.0));
- (void)discoverUserIdentityWithPhoneNumber:(NSString *)phoneNumber completionHandler:(void (^)(CKUserIdentity * _Nullable userInfo, NSError * _Nullable error))completionHandler
    API_DEPRECATED("no longer supported", ios(10.0, 17.0));
- (void)discoverUserIdentityWithUserRecordID:(CKRecordID *)userRecordID completionHandler:(void (^)(CKUserIdentity * _Nullable userInfo, NSError * _Nullable error))completionHandler
    API_DEPRECATED("no longer supported", ios(10.0, 17.0));
@end

@interface CKDatabase : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (void)addOperation:(CKDatabaseOperation *)operation;
@property (nonatomic, readonly, assign) CKDatabaseScope databaseScope;
- (void)fetchRecordWithID:(CKRecordID *)recordID completionHandler:(void (^)(CKRecord * _Nullable record, NSError * _Nullable error))completionHandler;
- (void)saveRecord:(CKRecord *)record completionHandler:(void (^)(CKRecord * _Nullable record, NSError * _Nullable error))completionHandler;
- (void)deleteRecordWithID:(CKRecordID *)recordID completionHandler:(void (^)(CKRecordID * _Nullable recordID, NSError * _Nullable error))completionHandler;
- (void)performQuery:(CKQuery *)query inZoneWithID:(nullable CKRecordZoneID *)zoneID
   completionHandler:(void (^)(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error))completionHandler
    API_DEPRECATED("use CKQueryOperation", ios(8.0, 15.0));
- (void)fetchAllRecordZonesWithCompletionHandler:(void (^)(NSArray<CKRecordZone *> * _Nullable zones, NSError * _Nullable error))completionHandler;
- (void)saveRecordZone:(CKRecordZone *)zone completionHandler:(void (^)(CKRecordZone * _Nullable zone, NSError * _Nullable error))completionHandler;
- (void)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZoneID * _Nullable zoneID, NSError * _Nullable error))completionHandler;
- (void)fetchSubscriptionWithID:(CKSubscriptionID)subscriptionID completionHandler:(void (^)(CKSubscription * _Nullable subscription, NSError * _Nullable error))completionHandler;
- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error))completionHandler;
- (void)saveSubscription:(CKSubscription *)subscription completionHandler:(void (^)(CKSubscription * _Nullable subscription, NSError * _Nullable error))completionHandler;
- (void)deleteSubscriptionWithID:(CKSubscriptionID)subscriptionID completionHandler:(void (^)(CKSubscriptionID _Nullable subscriptionID, NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
