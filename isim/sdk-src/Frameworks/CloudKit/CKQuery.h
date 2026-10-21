#pragma once
/* isim CloudKit: queries (NSPredicate and NSSortDescriptor over the records' fields). */
#import <CloudKit/CKRecord.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface CKQuery : NSObject
- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) CKRecordType recordType;
@property (nonatomic, readonly, copy) NSPredicate *predicate;
@property (nonatomic, copy, nullable) NSArray<NSSortDescriptor *> *sortDescriptors;
@end
NS_ASSUME_NONNULL_END
#endif
