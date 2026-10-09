#pragma once
#import <Foundation/NSValue.h>
#import <Foundation/NSException.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDictionary;
/* a base-10 number: up to 38 significant digits (128-bit mantissa) times 10^exponent (-128...127) */
typedef struct {
    signed int _exponent:8;
    unsigned int _length:4;      /* mantissa words in use (0: zero, or NaN when _isNegative) */
    unsigned int _isNegative:1;
    unsigned int _isCompact:1;
    unsigned int _reserved:18;
    unsigned short _mantissa[8];  /* little-endian 16-bit words */
} NSDecimal;
#define NSDecimalMaxSize (8)
#define NSDecimalNoScale 32767
typedef NS_ENUM(NSUInteger, NSRoundingMode) { NSRoundPlain, NSRoundDown, NSRoundUp, NSRoundBankers } NS_SWIFT_NAME(NSDecimalNumber.RoundingMode);
typedef NS_ENUM(NSUInteger, NSCalculationError) {
    NSCalculationNoError = 0, NSCalculationLossOfPrecision, NSCalculationUnderflow, NSCalculationOverflow, NSCalculationDivideByZero
} NS_SWIFT_NAME(NSDecimalNumber.CalculationError);
/* the C API (Swift has these for Decimal in the overlay) */
FOUNDATION_EXPORT BOOL NSDecimalIsNotANumber(const NSDecimal *dcm) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT void NSDecimalCopy(NSDecimal *destination, const NSDecimal *source) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT void NSDecimalCompact(NSDecimal *number) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSComparisonResult NSDecimalCompare(const NSDecimal *leftOperand, const NSDecimal *rightOperand) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT void NSDecimalRound(NSDecimal *result, const NSDecimal *number, NSInteger scale, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalNormalize(NSDecimal *number1, NSDecimal *number2, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalAdd(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalSubtract(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalMultiply(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalDivide(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalPower(NSDecimal *result, const NSDecimal *number, NSUInteger power, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSCalculationError NSDecimalMultiplyByPowerOf10(NSDecimal *result, const NSDecimal *number, short power, NSRoundingMode roundingMode) NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSString *NSDecimalString(const NSDecimal *dcm, id _Nullable locale) NS_REFINED_FOR_SWIFT;

FOUNDATION_EXPORT NSExceptionName const NSDecimalNumberExactnessException;
FOUNDATION_EXPORT NSExceptionName const NSDecimalNumberOverflowException;
FOUNDATION_EXPORT NSExceptionName const NSDecimalNumberUnderflowException;
FOUNDATION_EXPORT NSExceptionName const NSDecimalNumberDivideByZeroException;

@class NSDecimalNumber;
@protocol NSDecimalNumberBehaviors
- (NSRoundingMode)roundingMode;
- (short)scale;
- (nullable NSDecimalNumber *)exceptionDuringOperation:(SEL)operation error:(NSCalculationError)error leftOperand:(NSDecimalNumber *)leftOperand rightOperand:(nullable NSDecimalNumber *)rightOperand;
@end

/* an NSNumber holding an NSDecimal: exact base-10 arithmetic */
@interface NSDecimalNumber : NSNumber
- (instancetype)initWithMantissa:(unsigned long long)mantissa exponent:(short)exponent isNegative:(BOOL)flag;
- (instancetype)initWithDecimal:(NSDecimal)dcm NS_DESIGNATED_INITIALIZER NS_REFINED_FOR_SWIFT;
- (instancetype)initWithString:(nullable NSString *)numberValue;
- (instancetype)initWithString:(nullable NSString *)numberValue locale:(nullable id)locale;
- (NSString *)descriptionWithLocale:(nullable id)locale;
@property (readonly) NSDecimal decimalValue NS_REFINED_FOR_SWIFT;
+ (NSDecimalNumber *)decimalNumberWithMantissa:(unsigned long long)mantissa exponent:(short)exponent isNegative:(BOOL)flag;
+ (NSDecimalNumber *)decimalNumberWithDecimal:(NSDecimal)dcm NS_REFINED_FOR_SWIFT;
+ (NSDecimalNumber *)decimalNumberWithString:(nullable NSString *)numberValue;
+ (NSDecimalNumber *)decimalNumberWithString:(nullable NSString *)numberValue locale:(nullable id)locale;
@property (class, readonly, copy) NSDecimalNumber *zero;
@property (class, readonly, copy) NSDecimalNumber *one;
@property (class, readonly, copy) NSDecimalNumber *minimumDecimalNumber;
@property (class, readonly, copy) NSDecimalNumber *maximumDecimalNumber;
@property (class, readonly, copy) NSDecimalNumber *notANumber;
- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)decimalNumber withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)decimalNumber withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)decimalNumber withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)decimalNumber withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(NSUInteger)power;
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(NSUInteger)power withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)power;
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)power withBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByRoundingAccordingToBehavior:(nullable id<NSDecimalNumberBehaviors>)behavior;
- (NSComparisonResult)compare:(NSNumber *)decimalNumber;
@property (class, strong) id<NSDecimalNumberBehaviors> defaultBehavior;
@end

/* rounding and the conditions that raise (the default: plain rounding, no scale, raise on overflow, underflow and division by zero) */
@interface NSDecimalNumberHandler : NSObject <NSDecimalNumberBehaviors, NSCoding>
@property (class, readonly, strong) NSDecimalNumberHandler *defaultDecimalNumberHandler;
- (instancetype)initWithRoundingMode:(NSRoundingMode)roundingMode scale:(short)scale raiseOnExactness:(BOOL)exact raiseOnOverflow:(BOOL)overflow raiseOnUnderflow:(BOOL)underflow raiseOnDivideByZero:(BOOL)divideByZero NS_DESIGNATED_INITIALIZER;
+ (instancetype)decimalNumberHandlerWithRoundingMode:(NSRoundingMode)roundingMode scale:(short)scale raiseOnExactness:(BOOL)exact raiseOnOverflow:(BOOL)overflow raiseOnUnderflow:(BOOL)underflow raiseOnDivideByZero:(BOOL)divideByZero;
@end

@interface NSNumber (NSDecimalNumberExtensions)
@property (readonly) NSDecimal decimalValue NS_REFINED_FOR_SWIFT;
@end
NS_ASSUME_NONNULL_END
