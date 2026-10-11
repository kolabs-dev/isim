#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/NSFetchRequest.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObjectID, NSPropertyDescription, NSPersistentHistoryTransaction;

typedef NS_ENUM(NSInteger, NSPersistentHistoryChangeType) {
    NSPersistentHistoryChangeTypeInsert = 0,
    NSPersistentHistoryChangeTypeUpdate = 1,
    NSPersistentHistoryChangeTypeDelete = 2
};
typedef NS_ENUM(NSInteger, NSPersistentHistoryResultType) {
    NSPersistentHistoryResultTypeStatusOnly = 0,
    NSPersistentHistoryResultTypeObjectIDs = 1,
    NSPersistentHistoryResultTypeCount = 2,
    NSPersistentHistoryResultTypeTransactionsOnly = 3,
    NSPersistentHistoryResultTypeChangesOnly = 4,
    NSPersistentHistoryResultTypeTransactionsAndChanges = 5
};

@interface NSPersistentHistoryToken : NSObject <NSCopying, NSSecureCoding>
@end

@interface NSPersistentHistoryChange : NSObject
@property (readonly) int64_t changeID;
@property (readonly, strong) NSManagedObjectID *changedObjectID;
@property (readonly) NSPersistentHistoryChangeType changeType;
@property (nullable, readonly, strong) NSDictionary *tombstone;
@property (nullable, readonly, strong) NSSet<NSPropertyDescription *> *updatedProperties;
@property (readonly, strong) NSPersistentHistoryTransaction *transaction;
@end

@interface NSPersistentHistoryTransaction : NSObject
@property (readonly) int64_t transactionNumber;
@property (readonly, strong) NSPersistentHistoryToken *token;
@property (readonly, strong) NSDate *timestamp;
@property (nullable, readonly, copy) NSString *author;
@property (nullable, readonly, copy) NSString *contextName;
@property (readonly, copy) NSString *storeID;
@property (nullable, readonly, strong) NSArray<NSPersistentHistoryChange *> *changes;
- (NSNotification *)objectIDNotification;
@end

@interface NSPersistentHistoryChangeRequest : NSPersistentStoreRequest
+ (instancetype)fetchHistoryAfterDate:(nullable NSDate *)date;
+ (instancetype)fetchHistoryAfterToken:(nullable NSPersistentHistoryToken *)token;
+ (instancetype)fetchHistoryAfterTransaction:(nullable NSPersistentHistoryTransaction *)transaction;
+ (instancetype)deleteHistoryBeforeDate:(nullable NSDate *)date;
+ (instancetype)deleteHistoryBeforeToken:(nullable NSPersistentHistoryToken *)token;
+ (instancetype)deleteHistoryBeforeTransaction:(nullable NSPersistentHistoryTransaction *)transaction;
@property NSPersistentHistoryResultType resultType;
@property (nullable, strong) NSFetchRequest *fetchRequest;
@end

@interface NSPersistentHistoryResult : NSPersistentStoreResult
@property (nullable, readonly, strong) id result;
@property (readonly) NSPersistentHistoryResultType resultType;
@end
NS_ASSUME_NONNULL_END
