#pragma once
/* isim CloudKit: records, their IDs, zones, references and assets (the CloudKit Swift overlay's classes, over a local
 * store in the device data: no iCloud). */
#import <CloudKit/CKDefines.h>
#import <CoreLocation/CoreLocation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NSString * CKRecordType;
typedef NSString * CKRecordFieldKey;
CK_EXTERN NSString * const CKCurrentUserDefaultName;
CK_EXTERN NSString * const CKRecordZoneDefaultName;
CK_EXTERN CKRecordType const CKRecordTypeShare;
CK_EXTERN NSString * const CKRecordNameZoneWideShare;

/* the values a field can hold: NSString, NSNumber, NSDate, NSData, CKAsset, CKReference, CLLocation and arrays of them */
@protocol CKRecordValue <NSObject>
@end
@interface NSString (CKRecordValue) <CKRecordValue>
@end
@interface NSNumber (CKRecordValue) <CKRecordValue>
@end
@interface NSArray (CKRecordValue) <CKRecordValue>
@end
@interface NSDate (CKRecordValue) <CKRecordValue>
@end
@interface NSData (CKRecordValue) <CKRecordValue>
@end
@interface CLLocation (CKRecordValue) <CKRecordValue>
@end

@interface CKRecordZoneID : NSObject <NSCopying>
- (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *zoneName;
@property (nonatomic, readonly, copy) NSString *ownerName;
@end
@interface CKRecordID : NSObject <NSCopying>
- (instancetype)initWithRecordName:(NSString *)recordName;
- (instancetype)initWithRecordName:(NSString *)recordName zoneID:(CKRecordZoneID *)zoneID;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *recordName;
@property (nonatomic, readonly, strong) CKRecordZoneID *zoneID;
@end
typedef NS_OPTIONS(NSUInteger, CKRecordZoneCapabilities) {
    CKRecordZoneCapabilityFetchChanges = 1 << 0, CKRecordZoneCapabilityAtomic = 1 << 1, CKRecordZoneCapabilitySharing = 1 << 2,
    CKRecordZoneCapabilityZoneWideSharing = 1 << 3
};
@interface CKRecordZone : NSObject
+ (CKRecordZone *)defaultRecordZone;
- (instancetype)initWithZoneName:(NSString *)zoneName;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, strong) CKRecordZoneID *zoneID;
@property (nonatomic, assign) CKRecordZoneCapabilities capabilities;
@end
typedef NS_ENUM(NSUInteger, CKReferenceAction) { CKReferenceActionNone = 0, CKReferenceActionDeleteSelf = 1 };
@class CKRecord;
@interface CKReference : NSObject <NSCopying, CKRecordValue>
- (instancetype)initWithRecordID:(CKRecordID *)recordID action:(CKReferenceAction)action;
- (instancetype)initWithRecord:(CKRecord *)record action:(CKReferenceAction)action;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, assign) CKReferenceAction referenceAction;
@property (nonatomic, readonly, copy) CKRecordID *recordID;
@end
@interface CKAsset : NSObject <CKRecordValue>
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy, nullable) NSURL *fileURL;
@end
@protocol CKRecordKeyValueSetting <NSObject>
- (nullable __kindof id<CKRecordValue>)objectForKey:(CKRecordFieldKey)key;
- (void)setObject:(nullable __kindof id<CKRecordValue>)object forKey:(CKRecordFieldKey)key;
- (nullable __kindof id<CKRecordValue>)objectForKeyedSubscript:(CKRecordFieldKey)key;
- (void)setObject:(nullable __kindof id<CKRecordValue>)object forKeyedSubscript:(CKRecordFieldKey)key;
- (NSArray<CKRecordFieldKey> *)allKeys;
- (NSArray<CKRecordFieldKey> *)changedKeys;
@end
@interface CKRecord : NSObject <NSCopying, CKRecordKeyValueSetting>
- (instancetype)initWithRecordType:(CKRecordType)recordType;
- (instancetype)initWithRecordType:(CKRecordType)recordType recordID:(CKRecordID *)recordID;
- (instancetype)initWithRecordType:(CKRecordType)recordType zoneID:(CKRecordZoneID *)zoneID;
/* restores a record from encodeSystemFieldsWithCoder: data (no field values, like CloudKit) */
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) CKRecordType recordType;
@property (nonatomic, readonly, copy) CKRecordID *recordID;
@property (nonatomic, readonly, copy, nullable) NSString *recordChangeTag;
@property (nonatomic, readonly, copy, nullable) CKRecordID *creatorUserRecordID;
@property (nonatomic, readonly, copy, nullable) NSDate *creationDate;
@property (nonatomic, readonly, copy, nullable) CKRecordID *lastModifiedUserRecordID;
@property (nonatomic, readonly, copy, nullable) NSDate *modificationDate;
@property (nonatomic, copy, nullable) CKReference *parent;
- (void)setParentReferenceFromRecord:(nullable CKRecord *)parentRecord;
- (void)setParentReferenceFromRecordID:(nullable CKRecordID *)parentRecordID;
/* isim keeps encrypted values like the others (the store is local) */
@property (nonatomic, readonly, copy) id<CKRecordKeyValueSetting> encryptedValues;
- (void)encodeSystemFieldsWithCoder:(NSCoder *)coder;
@end
NS_ASSUME_NONNULL_END
#endif
