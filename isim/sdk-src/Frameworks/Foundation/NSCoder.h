#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSPropertyList.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSData, NSSet<ObjectType>, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSError;
typedef NS_ENUM(NSInteger, NSDecodingFailurePolicy) {
    NSDecodingFailurePolicyRaiseException NS_SWIFT_NAME(raiseException), NSDecodingFailurePolicySetErrorAndReturn NS_SWIFT_NAME(setErrorAndReturn)
} NS_SWIFT_NAME(NSCoder.DecodingFailurePolicy);
/* isim: keyed coding (NSKeyedArchiver / NSKeyedUnarchiver); sequential (non-keyed) coding is not supported */
@interface NSCoder : NSObject
@property (readonly) BOOL allowsKeyedCoding;
@property (readonly) BOOL requiresSecureCoding;
@property (readonly) NSDecodingFailurePolicy decodingFailurePolicy;
@property (nullable, readonly, copy) NSError *error;
- (void)failWithError:(NSError *)error;
- (void)encodeObject:(nullable id)object forKey:(NSString *)key;
- (void)encodeConditionalObject:(nullable id)object forKey:(NSString *)key;
- (void)encodeBool:(BOOL)value forKey:(NSString *)key;
- (void)encodeInt:(int)value forKey:(NSString *)key;
- (void)encodeInt32:(int32_t)value forKey:(NSString *)key;
- (void)encodeInt64:(int64_t)value forKey:(NSString *)key;
- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key;
- (void)encodeFloat:(float)value forKey:(NSString *)key;
- (void)encodeDouble:(double)value forKey:(NSString *)key;
- (void)encodeBytes:(nullable const uint8_t *)bytes length:(NSUInteger)length forKey:(NSString *)key;
- (void)encodeRootObject:(id)rootObject;
- (BOOL)containsValueForKey:(NSString *)key;
- (nullable id)decodeObjectForKey:(NSString *)key;
- (nullable id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error NS_SWIFT_UNAVAILABLE("use decodeTopLevelObject(forKey:)");
- (BOOL)decodeBoolForKey:(NSString *)key;
- (int)decodeIntForKey:(NSString *)key;
- (int32_t)decodeInt32ForKey:(NSString *)key;
- (int64_t)decodeInt64ForKey:(NSString *)key;
- (NSInteger)decodeIntegerForKey:(NSString *)key;
- (float)decodeFloatForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
- (nullable const uint8_t *)decodeBytesForKey:(NSString *)key returnedLength:(nullable NSUInteger *)lengthp NS_RETURNS_INNER_POINTER;
- (nullable id)decodeObjectOfClass:(Class)aClass forKey:(NSString *)key NS_SWIFT_NAME(_isimDecodeObject(of:forKey:));
- (nullable id)decodeObjectOfClasses:(nullable NSSet<Class> *)classes forKey:(NSString *)key NS_SWIFT_NAME(_isimDecodeObject(ofClasses:forKey:));
- (nullable NSArray *)decodeArrayOfObjectsOfClass:(Class)cls forKey:(NSString *)key NS_SWIFT_NAME(_isimDecodeArrayOfObjects(ofClass:forKey:));
- (nullable NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)keyCls objectsOfClass:(Class)objectCls forKey:(NSString *)key NS_SWIFT_NAME(_isimDecodeDictionary(withKeysOfClass:objectsOfClass:forKey:));
@property (nullable, readonly, copy) NSSet<Class> *allowedClasses;
@end

@protocol NSKeyedArchiverDelegate;
@protocol NSKeyedUnarchiverDelegate;
FOUNDATION_EXPORT NSString * const NSKeyedArchiveRootObjectKey;
FOUNDATION_EXPORT NSString * const NSInvalidArchiveOperationException;
FOUNDATION_EXPORT NSString * const NSInvalidUnarchiveOperationException;
/* isim: archives use Apple's keyed-archive format ($archiver/$version/$top/$objects, binary or XML plist) */
@interface NSKeyedArchiver : NSCoder
- (instancetype)initRequiringSecureCoding:(BOOL)requiresSecureCoding NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
+ (nullable NSData *)archivedDataWithRootObject:(id)object requiringSecureCoding:(BOOL)requiresSecureCoding error:(NSError **)error;
+ (NSData *)archivedDataWithRootObject:(id)rootObject;
+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path;
@property (nullable, weak) id<NSKeyedArchiverDelegate> delegate;
@property NSPropertyListFormat outputFormat;
@property (readonly, strong) NSData *encodedData;
- (void)finishEncoding;
+ (void)setClassName:(nullable NSString *)codedName forClass:(Class)cls;
- (void)setClassName:(nullable NSString *)codedName forClass:(Class)cls;
+ (nullable NSString *)classNameForClass:(Class)cls;
- (nullable NSString *)classNameForClass:(Class)cls;
@property (readwrite) BOOL requiresSecureCoding;
@end
@interface NSKeyedUnarchiver : NSCoder
- (nullable instancetype)initForReadingFromData:(NSData *)data error:(NSError **)error NS_DESIGNATED_INITIALIZER;
+ (nullable id)unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(_isimUnarchivedObject(ofClass:from:));
+ (nullable id)unarchivedObjectOfClasses:(NSSet<Class> *)classes fromData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(_isimUnarchivedObject(ofClasses:from:));
+ (nullable id)unarchivedArrayOfObjectsOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(_isimUnarchivedArrayOfObjects(ofClass:from:));
+ (nullable id)unarchivedDictionaryWithKeysOfClass:(Class)keyCls objectsOfClass:(Class)valueCls fromData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(_isimUnarchivedDictionary(ofKeyClass:objectClass:from:));
+ (nullable id)unarchiveObjectWithData:(NSData *)data;
+ (nullable id)unarchiveTopLevelObjectWithData:(NSData *)data error:(NSError **)error NS_SWIFT_UNAVAILABLE("use unarchivedObject(ofClass:from:)");
+ (nullable id)unarchiveObjectWithFile:(NSString *)path;
@property (nullable, weak) id<NSKeyedUnarchiverDelegate> delegate;
- (void)finishDecoding;
+ (void)setClass:(nullable Class)cls forClassName:(NSString *)codedName;
- (void)setClass:(nullable Class)cls forClassName:(NSString *)codedName;
+ (nullable Class)classForClassName:(NSString *)codedName;
- (nullable Class)classForClassName:(NSString *)codedName;
@property (readwrite) BOOL requiresSecureCoding;
@property (readwrite) NSDecodingFailurePolicy decodingFailurePolicy;
@end
@protocol NSKeyedArchiverDelegate <NSObject>
@optional
- (nullable id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object;
- (void)archiver:(NSKeyedArchiver *)archiver didEncodeObject:(nullable id)object;
- (void)archiverDidFinish:(NSKeyedArchiver *)archiver;
@end
@protocol NSKeyedUnarchiverDelegate <NSObject>
@optional
- (nullable Class)unarchiver:(NSKeyedUnarchiver *)unarchiver cannotDecodeObjectOfClassName:(NSString *)name originalClasses:(NSArray<NSString *> *)classNames;
- (nullable id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(nullable id)object;
- (void)unarchiverDidFinish:(NSKeyedUnarchiver *)unarchiver;
@end
@interface NSObject (NSCoderMethods)
- (nullable id)awakeAfterUsingCoder:(NSCoder *)coder;
@end
@interface NSObject (NSKeyedArchiverObjectSubstitution)
@property (nullable, readonly) Class classForKeyedArchiver;
+ (NSArray<NSString *> *)classFallbacksForKeyedArchiver;
@end
NS_ASSUME_NONNULL_END
