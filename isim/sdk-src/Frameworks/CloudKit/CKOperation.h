#pragma once
/* isim CloudKit: operations. isim's CKOperation is an NSObject (not an NSOperation): add operations to a CKContainer or
 * CKDatabase (addOperation:), which run them on CloudKit's own queue, or call -start. */
#import <CloudKit/CKContainer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CKOperationGroup;
typedef NSString * CKOperationID;
@interface CKOperationConfiguration : NSObject
@property (nonatomic, strong, nullable) CKContainer *container;
@property (nonatomic, assign) NSQualityOfService qualityOfService;
@property (nonatomic, assign) BOOL allowsCellularAccess;
@property (nonatomic, assign, getter=isLongLived) BOOL longLived;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@end
@interface CKOperation : NSObject
@property (nonatomic, copy, null_resettable) CKOperationConfiguration *configuration;
@property (nonatomic, strong, nullable) CKOperationGroup *group;
@property (nonatomic, readonly, copy) CKOperationID operationID;
@property (nonatomic, copy, nullable) void (^completionBlock)(void);
@property (nonatomic, assign) NSQualityOfService qualityOfService;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) void (^longLivedOperationWasPersistedBlock)(void);
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, getter=isExecuting) BOOL executing;
@property (nonatomic, readonly, getter=isFinished) BOOL finished;
- (void)start;
- (void)main;
- (void)cancel;
@end
@interface CKOperationGroup : NSObject <NSSecureCoding>
@property (nonatomic, readonly, copy) NSString *operationGroupID;
@property (nonatomic, copy, null_resettable) CKOperationConfiguration *defaultConfiguration;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, assign) NSUInteger quantity;
@end
@interface CKDatabaseOperation : CKOperation
@property (nonatomic, strong, nullable) CKDatabase *database;
@end

@interface CKQueryCursor : NSObject
- (instancetype)init NS_UNAVAILABLE;
@end
CK_EXTERN const NSUInteger CKQueryOperationMaximumResults;
@interface CKQueryOperation : CKDatabaseOperation
- (instancetype)initWithQuery:(CKQuery *)query;
- (instancetype)initWithCursor:(CKQueryCursor *)cursor;
@property (nonatomic, copy, nullable) CKQuery *query;
@property (nonatomic, copy, nullable) CKQueryCursor *cursor;
@property (nonatomic, copy, nullable) CKRecordZoneID *zoneID;
@property (nonatomic, assign) NSUInteger resultsLimit;
@property (nonatomic, copy, nullable) NSArray<CKRecordFieldKey> *desiredKeys;
@property (nonatomic, copy, nullable) void (^recordMatchedBlock)(CKRecordID *recordID, CKRecord * _Nullable record, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^queryCompletionBlock)(CKQueryCursor * _Nullable cursor, NSError * _Nullable operationError);
@property (nonatomic, copy, nullable) void (^recordFetchedBlock)(CKRecord *record) API_DEPRECATED("use recordMatchedBlock", ios(8.0, 15.0));
@end

typedef NS_ENUM(NSInteger, CKRecordSavePolicy) {
    CKRecordSaveIfServerRecordUnchanged = 0, CKRecordSaveChangedKeys = 1, CKRecordSaveAllKeys = 2
};
@interface CKModifyRecordsOperation : CKDatabaseOperation
- (instancetype)initWithRecordsToSave:(nullable NSArray<CKRecord *> *)records recordIDsToDelete:(nullable NSArray<CKRecordID *> *)recordIDs;
@property (nonatomic, copy, nullable) NSArray<CKRecord *> *recordsToSave;
@property (nonatomic, copy, nullable) NSArray<CKRecordID *> *recordIDsToDelete;
@property (nonatomic, assign) CKRecordSavePolicy savePolicy;
@property (nonatomic, copy, nullable) NSData *clientChangeTokenData;
/* only custom zones are atomic, as in CloudKit */
@property (nonatomic, assign, getter=isAtomic) BOOL atomic;
@property (nonatomic, copy, nullable) void (^perRecordProgressBlock)(CKRecord *record, double progress);
@property (nonatomic, copy, nullable) void (^perRecordSaveBlock)(CKRecordID *recordID, CKRecord * _Nullable record, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^perRecordDeleteBlock)(CKRecordID *recordID, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^modifyRecordsCompletionBlock)(NSArray<CKRecord *> * _Nullable savedRecords,
                                                                           NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError);
@property (nonatomic, copy, nullable) void (^perRecordCompletionBlock)(CKRecord *record, NSError * _Nullable error)
    API_DEPRECATED("use perRecordSaveBlock", ios(8.0, 15.0));
@end
@interface CKFetchRecordsOperation : CKDatabaseOperation
+ (instancetype)fetchCurrentUserRecordOperation;
- (instancetype)initWithRecordIDs:(NSArray<CKRecordID *> *)recordIDs;
@property (nonatomic, copy, nullable) NSArray<CKRecordID *> *recordIDs;
@property (nonatomic, copy, nullable) NSArray<CKRecordFieldKey> *desiredKeys;
@property (nonatomic, copy, nullable) void (^perRecordCompletionBlock)(CKRecord * _Nullable record, CKRecordID * _Nullable recordID, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^fetchRecordsCompletionBlock)(NSDictionary<CKRecordID *, CKRecord *> * _Nullable recordsByRecordID,
                                                                          NSError * _Nullable operationError);
@end

@interface CKModifyRecordZonesOperation : CKDatabaseOperation
- (instancetype)initWithRecordZonesToSave:(nullable NSArray<CKRecordZone *> *)recordZonesToSave
                    recordZoneIDsToDelete:(nullable NSArray<CKRecordZoneID *> *)recordZoneIDsToDelete;
@property (nonatomic, copy, nullable) NSArray<CKRecordZone *> *recordZonesToSave;
@property (nonatomic, copy, nullable) NSArray<CKRecordZoneID *> *recordZoneIDsToDelete;
@property (nonatomic, copy, nullable) void (^perRecordZoneSaveBlock)(CKRecordZoneID *recordZoneID, CKRecordZone * _Nullable recordZone, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^perRecordZoneDeleteBlock)(CKRecordZoneID *recordZoneID, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^modifyRecordZonesCompletionBlock)(NSArray<CKRecordZone *> * _Nullable savedRecordZones,
                                                                               NSArray<CKRecordZoneID *> * _Nullable deletedRecordZoneIDs, NSError * _Nullable operationError);
@end
@interface CKFetchRecordZonesOperation : CKDatabaseOperation
+ (instancetype)fetchAllRecordZonesOperation;
- (instancetype)initWithRecordZoneIDs:(NSArray<CKRecordZoneID *> *)zoneIDs;
@property (nonatomic, copy, nullable) NSArray<CKRecordZoneID *> *recordZoneIDs;
@property (nonatomic, copy, nullable) void (^perRecordZoneCompletionBlock)(CKRecordZoneID *zoneID, CKRecordZone * _Nullable recordZone, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^fetchRecordZonesCompletionBlock)(NSDictionary<CKRecordZoneID *, CKRecordZone *> * _Nullable recordZonesByZoneID,
                                                                              NSError * _Nullable operationError);
@end

@class CKSubscription;
@interface CKModifySubscriptionsOperation : CKDatabaseOperation
- (instancetype)initWithSubscriptionsToSave:(nullable NSArray<CKSubscription *> *)subscriptionsToSave
                    subscriptionIDsToDelete:(nullable NSArray<CKSubscriptionID> *)subscriptionIDsToDelete;
@property (nonatomic, copy, nullable) NSArray<CKSubscription *> *subscriptionsToSave;
@property (nonatomic, copy, nullable) NSArray<CKSubscriptionID> *subscriptionIDsToDelete;
@property (nonatomic, copy, nullable) void (^perSubscriptionSaveBlock)(CKSubscriptionID subscriptionID, CKSubscription * _Nullable subscription, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^perSubscriptionDeleteBlock)(CKSubscriptionID subscriptionID, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^modifySubscriptionsCompletionBlock)(NSArray<CKSubscription *> * _Nullable savedSubscriptions,
                                                                                 NSArray<CKSubscriptionID> * _Nullable deletedSubscriptionIDs, NSError * _Nullable operationError);
@end
@interface CKFetchSubscriptionsOperation : CKDatabaseOperation
+ (instancetype)fetchAllSubscriptionsOperation;
- (instancetype)initWithSubscriptionIDs:(NSArray<CKSubscriptionID> *)subscriptionIDs;
@property (nonatomic, copy, nullable) NSArray<CKSubscriptionID> *subscriptionIDs;
@property (nonatomic, copy, nullable) void (^perSubscriptionCompletionBlock)(CKSubscriptionID subscriptionID, CKSubscription * _Nullable subscription, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^fetchSubscriptionCompletionBlock)(NSDictionary<CKSubscriptionID, CKSubscription *> * _Nullable subscriptionsBySubscriptionID,
                                                                               NSError * _Nullable operationError);
@end

/* a position in a database's or zone's change history; keep it with NSKeyedArchiver */
@interface CKServerChangeToken : NSObject <NSCopying, NSCoding>
- (instancetype)init NS_UNAVAILABLE;
@end
@interface CKFetchDatabaseChangesOperation : CKDatabaseOperation
- (instancetype)initWithPreviousServerChangeToken:(nullable CKServerChangeToken *)previousServerChangeToken;
@property (nonatomic, copy, nullable) CKServerChangeToken *previousServerChangeToken;
@property (nonatomic, assign) NSUInteger resultsLimit;
@property (nonatomic, assign) BOOL fetchAllChanges;
@property (nonatomic, copy, nullable) void (^recordZoneWithIDChangedBlock)(CKRecordZoneID *zoneID);
@property (nonatomic, copy, nullable) void (^recordZoneWithIDWasDeletedBlock)(CKRecordZoneID *zoneID);
@property (nonatomic, copy, nullable) void (^recordZoneWithIDWasPurgedBlock)(CKRecordZoneID *zoneID);
@property (nonatomic, copy, nullable) void (^changeTokenUpdatedBlock)(CKServerChangeToken *serverChangeToken);
@property (nonatomic, copy, nullable) void (^fetchDatabaseChangesCompletionBlock)(CKServerChangeToken * _Nullable serverChangeToken, BOOL moreComing,
                                                                                  NSError * _Nullable operationError);
@end
@interface CKFetchRecordZoneChangesConfiguration : NSObject
@property (nonatomic, copy, nullable) CKServerChangeToken *previousServerChangeToken;
@property (nonatomic, assign) NSUInteger resultsLimit;
@property (nonatomic, copy, nullable) NSArray<CKRecordFieldKey> *desiredKeys;
@end
@interface CKFetchRecordZoneChangesOperation : CKDatabaseOperation
- (instancetype)initWithRecordZoneIDs:(NSArray<CKRecordZoneID *> *)recordZoneIDs
          configurationsByRecordZoneID:(nullable NSDictionary<CKRecordZoneID *, CKFetchRecordZoneChangesConfiguration *> *)configurationsByRecordZoneID;
@property (nonatomic, copy, nullable) NSArray<CKRecordZoneID *> *recordZoneIDs;
@property (nonatomic, copy, nullable) NSDictionary<CKRecordZoneID *, CKFetchRecordZoneChangesConfiguration *> *configurationsByRecordZoneID;
@property (nonatomic, assign) BOOL fetchAllChanges;
@property (nonatomic, copy, nullable) void (^recordWasChangedBlock)(CKRecordID *recordID, CKRecord * _Nullable record, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^recordWithIDWasDeletedBlock)(CKRecordID *recordID, CKRecordType recordType);
@property (nonatomic, copy, nullable) void (^recordZoneChangeTokensUpdatedBlock)(CKRecordZoneID *recordZoneID, CKServerChangeToken * _Nullable serverChangeToken,
                                                                                 NSData * _Nullable clientChangeTokenData);
@property (nonatomic, copy, nullable) void (^recordZoneFetchCompletionBlock)(CKRecordZoneID *recordZoneID, CKServerChangeToken * _Nullable serverChangeToken,
                                                                             NSData * _Nullable clientChangeTokenData, BOOL moreComing, NSError * _Nullable recordZoneError);
@property (nonatomic, copy, nullable) void (^fetchRecordZoneChangesCompletionBlock)(NSError * _Nullable operationError);
@property (nonatomic, copy, nullable) void (^recordChangedBlock)(CKRecord *record) API_DEPRECATED("use recordWasChangedBlock", ios(10.0, 15.0));
@end
NS_ASSUME_NONNULL_END
#endif
