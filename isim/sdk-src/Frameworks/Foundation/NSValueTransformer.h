#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
typedef NSString *NSValueTransformerName NS_EXTENSIBLE_STRING_ENUM;
FOUNDATION_EXPORT NSValueTransformerName const NSNegateBooleanTransformerName;
FOUNDATION_EXPORT NSValueTransformerName const NSIsNilTransformerName;
FOUNDATION_EXPORT NSValueTransformerName const NSIsNotNilTransformerName;
FOUNDATION_EXPORT NSValueTransformerName const NSUnarchiveFromDataTransformerName;
FOUNDATION_EXPORT NSValueTransformerName const NSKeyedUnarchiveFromDataTransformerName;
FOUNDATION_EXPORT NSValueTransformerName const NSSecureUnarchiveFromDataTransformerName;

NS_SWIFT_NAME(ValueTransformer)
@interface NSValueTransformer : NSObject
+ (void)setValueTransformer:(nullable NSValueTransformer *)transformer forName:(NSValueTransformerName)name;
+ (nullable NSValueTransformer *)valueTransformerForName:(NSValueTransformerName)name;
+ (NSArray<NSValueTransformerName> *)valueTransformerNames;
+ (Class)transformedValueClass;
+ (BOOL)allowsReverseTransformation;
- (nullable id)transformedValue:(nullable id)value;
- (nullable id)reverseTransformedValue:(nullable id)value;
@end

/// Data <-> objects with NSKeyedArchiver/NSKeyedUnarchiver secure coding (forward = unarchive).
@interface NSSecureUnarchiveFromDataTransformer : NSValueTransformer
@property (class, readonly, copy) NSArray<Class> *allowedTopLevelClasses;
@end
NS_ASSUME_NONNULL_END
