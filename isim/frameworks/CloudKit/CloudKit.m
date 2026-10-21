// isim CloudKit for Objective-C: the C constants (the values the CloudKit Swift overlay uses), Apple's initializers
// where the overlay's take Swift-only types or default arguments (the overlay's _isim_ entry points make the objects),
// and Apple's setters where the overlay's Bool properties are named isX (Swift's Objective-C setter is setIsX:).
#import <CloudKit/CloudKit.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

NSString * const CKErrorDomain = @"CKErrorDomain";
NSString * const CKPartialErrorsByItemIDKey = @"CKPartialErrors";
NSString * const CKRecordChangedErrorAncestorRecordKey = @"AncestorRecord";
NSString * const CKRecordChangedErrorServerRecordKey = @"ServerRecord";
NSString * const CKRecordChangedErrorClientRecordKey = @"ClientRecord";
NSString * const CKErrorRetryAfterKey = @"CKRetryAfter";
NSString * const CKCurrentUserDefaultName = @"__defaultOwner__";
NSString * const CKRecordZoneDefaultName = @"_defaultZone";
CKRecordType const CKRecordTypeShare = @"cloudkit.share";
NSString * const CKRecordNameZoneWideShare = @"cloudkit.zoneshare";
NSString * const CKAccountChangedNotification = @"CKAccountChangedNotification";
NSString * const CKShareTitleKey = @"cloudkit.title";
NSString * const CKShareThumbnailImageDataKey = @"cloudkit.thumbnailImageData";
NSString * const CKShareTypeKey = @"cloudkit.shareType";
const NSUInteger CKQueryOperationMaximumResults = 0;

@implementation NSString (CKRecordValue)
@end
@implementation NSNumber (CKRecordValue)
@end
@implementation NSArray (CKRecordValue)
@end
@implementation NSDate (CKRecordValue)
@end
@implementation NSData (CKRecordValue)
@end
@implementation CLLocation (CKRecordValue)
@end

@interface NSObject (ISIMCloudKit)
- (void)setIsLongLived:(BOOL)v;
- (void)setIsAtomic:(BOOL)v;
- (id)initWithIdentifier:(NSString *)identifier;
+ (CKReference *)_isim_referenceWithRecordID:(CKRecordID *)recordID action:(NSUInteger)action;
+ (CKQuerySubscription *)_isim_subscriptionWithRecordType:(NSString *)type predicate:(NSPredicate *)predicate subscriptionID:(NSString *)subscriptionID
                                                  options:(NSUInteger)options;
+ (CKAllowedSharingOptions *)_isim_optionsWithPermissions:(NSUInteger)permissions access:(NSUInteger)access;
@end

@implementation CKOperationConfiguration (ISIMSetters)
- (void)setLongLived:(BOOL)v { [self setIsLongLived:v]; }
@end
@implementation CKModifyRecordsOperation (ISIMSetters)
- (void)setAtomic:(BOOL)v { [self setIsAtomic:v]; }
@end

@implementation CKContainer (ISIMFactories)
+ (CKContainer *)containerWithIdentifier:(NSString *)containerIdentifier { return [[self alloc] initWithIdentifier:containerIdentifier]; }
@end

@implementation CKRecordID (ISIMInit)
- (instancetype)initWithRecordName:(NSString *)recordName {
    return [self initWithRecordName:recordName zoneID:[[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName ownerName:CKCurrentUserDefaultName]];
}
@end

@implementation CKRecord (ISIMInit)
- (instancetype)initWithRecordType:(CKRecordType)recordType {
    return [self initWithRecordType:recordType recordID:[[CKRecordID alloc] initWithRecordName:NSUUID.UUID.UUIDString]];
}
@end

@implementation CKReference (ISIMInit)
- (instancetype)initWithRecordID:(CKRecordID *)recordID action:(CKReferenceAction)action {
    return [CKReference _isim_referenceWithRecordID:recordID action:action];
}
- (instancetype)initWithRecord:(CKRecord *)record action:(CKReferenceAction)action {
    return [CKReference _isim_referenceWithRecordID:record.recordID action:action];
}
@end

@implementation CKQuerySubscription (ISIMInit)
- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate options:(CKQuerySubscriptionOptions)options {
    return [CKQuerySubscription _isim_subscriptionWithRecordType:recordType predicate:predicate subscriptionID:NSUUID.UUID.UUIDString options:options];
}
- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate subscriptionID:(CKSubscriptionID)subscriptionID
                           options:(CKQuerySubscriptionOptions)options {
    return [CKQuerySubscription _isim_subscriptionWithRecordType:recordType predicate:predicate subscriptionID:subscriptionID options:options];
}
@end

@implementation CKRecordZoneSubscription (ISIMInit)
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID { return [self initWithZoneID:zoneID subscriptionID:NSUUID.UUID.UUIDString]; }
@end

@implementation CKAllowedSharingOptions (ISIMInit)
- (instancetype)initWithAllowedParticipantPermissionOptions:(CKSharingParticipantPermissionOption)permissions
                            allowedParticipantAccessOptions:(CKSharingParticipantAccessOption)access {
    return [CKAllowedSharingOptions _isim_optionsWithPermissions:permissions access:access];
}
@end
