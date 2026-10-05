#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
@interface NSValue : NSObject <NSCopying, NSSecureCoding>
+ (NSValue *)valueWithPointer:(nullable const void *)pointer;
+ (NSValue *)valueWithNonretainedObject:(nullable id)anObject;
+ (NSValue *)valueWithRange:(NSRange)range;
+ (NSValue *)valueWithCGPoint:(CGPoint)point;
+ (NSValue *)valueWithCGSize:(CGSize)size;
+ (NSValue *)valueWithCGRect:(CGRect)rect;
@property (nullable, readonly) void *pointerValue;
@property (nullable, readonly) id nonretainedObjectValue;
@property (readonly) NSRange rangeValue;
@property (readonly) CGPoint CGPointValue;
@property (readonly) CGSize CGSizeValue;
@property (readonly) CGRect CGRectValue;
- (BOOL)isEqualToValue:(NSValue *)value;
@end

@interface NSNumber : NSValue
+ (NSNumber *)numberWithChar:(char)value;
+ (NSNumber *)numberWithUnsignedChar:(unsigned char)value;
+ (NSNumber *)numberWithShort:(short)value;
+ (NSNumber *)numberWithUnsignedShort:(unsigned short)value;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithUnsignedInt:(unsigned int)value;
+ (NSNumber *)numberWithLong:(long)value;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber *)numberWithLongLong:(long long)value;
+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value;
+ (NSNumber *)numberWithFloat:(float)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithBool:(BOOL)value;
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
- (instancetype)initWithInt:(int)value;
- (instancetype)initWithInteger:(NSInteger)value;
- (instancetype)initWithDouble:(double)value;
- (instancetype)initWithBool:(BOOL)value;
- (instancetype)initWithLongLong:(long long)value;
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
- (instancetype)initWithUnsignedInteger:(NSUInteger)value;
- (instancetype)initWithFloat:(float)value;
@property (readonly) char charValue;
@property (readonly) unsigned char unsignedCharValue;
@property (readonly) short shortValue;
@property (readonly) int intValue;
@property (readonly) unsigned int unsignedIntValue;
@property (readonly) long longValue;
@property (readonly) unsigned long unsignedLongValue;
@property (readonly) long long longLongValue;
@property (readonly) unsigned long long unsignedLongLongValue;
@property (readonly) float floatValue;
@property (readonly) double doubleValue;
@property (readonly) const char *objCType NS_RETURNS_INNER_POINTER;
@property (readonly) BOOL _isim_isBool;   /* isim-private: created from a BOOL */
@property (readonly) BOOL boolValue;
@property (readonly) NSInteger integerValue;
@property (readonly) NSUInteger unsignedIntegerValue;
@property (readonly, copy) NSString *stringValue;
- (NSComparisonResult)compare:(NSNumber *)otherNumber;
- (BOOL)isEqualToNumber:(NSNumber *)number;
@end
NS_ASSUME_NONNULL_END
