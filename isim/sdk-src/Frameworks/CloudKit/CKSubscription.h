#pragma once
/* isim CloudKit: subscriptions and notifications. Subscriptions are kept in the local store; when a record change in
 * the same process matches one, a CloudKit-style payload goes to the app delegate's
 * application:didReceiveRemoteNotification:fetchCompletionHandler: (there is no APNs). */
#import <CloudKit/CKContainer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, CKSubscriptionType) { CKSubscriptionTypeQuery = 1, CKSubscriptionTypeRecordZone = 2, CKSubscriptionTypeDatabase = 3 };
@interface CKNotificationInfo : NSObject
@property (nonatomic, copy, nullable) NSString *alertBody;
@property (nonatomic, copy, nullable) NSString *alertLocalizationKey;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *soundName;
@property (nonatomic, copy, nullable) NSArray<CKRecordFieldKey> *desiredKeys;
@property (nonatomic, assign) BOOL shouldBadge;
@property (nonatomic, assign) BOOL shouldSendContentAvailable;
@property (nonatomic, assign) BOOL shouldSendMutableContent;
@property (nonatomic, copy, nullable) NSString *category;
@property (nonatomic, copy, nullable) NSString *collapseIDKey;
@end
@interface CKSubscription : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) CKSubscriptionID subscriptionID;
@property (nonatomic, readonly, assign) CKSubscriptionType subscriptionType;
@property (nonatomic, copy, nullable) CKNotificationInfo *notificationInfo;
@end
typedef NS_OPTIONS(NSUInteger, CKQuerySubscriptionOptions) {
    CKQuerySubscriptionOptionsFiresOnRecordCreation = 1 << 0, CKQuerySubscriptionOptionsFiresOnRecordUpdate = 1 << 1,
    CKQuerySubscriptionOptionsFiresOnRecordDeletion = 1 << 2, CKQuerySubscriptionOptionsFiresOnce = 1 << 3
};
@interface CKQuerySubscription : CKSubscription
- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate options:(CKQuerySubscriptionOptions)querySubscriptionOptions;
- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate subscriptionID:(CKSubscriptionID)subscriptionID
                           options:(CKQuerySubscriptionOptions)querySubscriptionOptions;
@property (nonatomic, readonly, copy) CKRecordType recordType;
@property (nonatomic, readonly, copy) NSPredicate *predicate;
@property (nonatomic, copy, nullable) CKRecordZoneID *zoneID;
@property (nonatomic, readonly, assign) CKQuerySubscriptionOptions querySubscriptionOptions;
@end
@interface CKRecordZoneSubscription : CKSubscription
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID subscriptionID:(CKSubscriptionID)subscriptionID;
@property (nonatomic, readonly, copy) CKRecordZoneID *zoneID;
@property (nonatomic, copy, nullable) CKRecordType recordType;
@end
@interface CKDatabaseSubscription : CKSubscription
- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID;
@property (nonatomic, copy, nullable) CKRecordType recordType;
@end

typedef NS_ENUM(NSInteger, CKNotificationType) {
    CKNotificationTypeQuery = 1, CKNotificationTypeRecordZone = 2, CKNotificationTypeReadNotification = 3, CKNotificationTypeDatabase = 4
};
@interface CKNotification : NSObject
/* the concrete subclass (CKQueryNotification, CKRecordZoneNotification, CKDatabaseNotification), nil for a payload that is not CloudKit's */
+ (nullable instancetype)notificationFromRemoteNotificationDictionary:(NSDictionary *)notificationDictionary;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, assign) CKNotificationType notificationType;
@property (nonatomic, readonly, copy, nullable) NSString *containerIdentifier;
@property (nonatomic, readonly, copy, nullable) CKSubscriptionID subscriptionID;
@property (nonatomic, readonly, assign) BOOL isPruned;
@property (nonatomic, readonly, copy, nullable) NSString *alertBody;
@property (nonatomic, readonly, copy, nullable) NSString *title;
@end
typedef NS_ENUM(NSInteger, CKQueryNotificationReason) {
    CKQueryNotificationReasonRecordCreated = 1, CKQueryNotificationReasonRecordUpdated, CKQueryNotificationReasonRecordDeleted
};
@interface CKQueryNotification : CKNotification
@property (nonatomic, readonly, assign) CKQueryNotificationReason queryNotificationReason;
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString *, id> *recordFields;
@property (nonatomic, readonly, copy, nullable) CKRecordID *recordID;
@property (nonatomic, readonly, assign) CKDatabaseScope databaseScope;
@end
@interface CKRecordZoneNotification : CKNotification
@property (nonatomic, readonly, copy, nullable) CKRecordZoneID *recordZoneID;
@property (nonatomic, readonly, assign) CKDatabaseScope databaseScope;
@end
@interface CKDatabaseNotification : CKNotification
@property (nonatomic, readonly, assign) CKDatabaseScope databaseScope;
@end
NS_ASSUME_NONNULL_END
#endif
