#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <JavaScriptCore/JavaScript.h>
NS_ASSUME_NONNULL_BEGIN
@class JSContext;
/* a JavaScript value; Objective-C values convert like Apple's: NSString <-> string, NSNumber <-> number/boolean,
   NSDictionary <-> object, NSArray <-> array, NSDate <-> Date, NSNull <-> null, nil <-> undefined, blocks <-> functions,
   other objects are wrapped (their JSExport protocols' methods and properties are visible to JavaScript). */
@interface JSValue : NSObject
@property (readonly, strong) JSContext *context;
+ (JSValue *)valueWithObject:(nullable id)value inContext:(JSContext *)context;
+ (JSValue *)valueWithBool:(BOOL)value inContext:(JSContext *)context;
+ (JSValue *)valueWithDouble:(double)value inContext:(JSContext *)context;
+ (JSValue *)valueWithInt32:(int32_t)value inContext:(JSContext *)context;
+ (JSValue *)valueWithUInt32:(uint32_t)value inContext:(JSContext *)context;
+ (JSValue *)valueWithNewObjectInContext:(JSContext *)context;
+ (JSValue *)valueWithNewArrayInContext:(JSContext *)context;
+ (JSValue *)valueWithNewRegularExpressionFromPattern:(NSString *)pattern flags:(NSString *)flags inContext:(JSContext *)context;
+ (JSValue *)valueWithNewErrorFromMessage:(NSString *)message inContext:(JSContext *)context;
+ (JSValue *)valueWithNewPromiseInContext:(JSContext *)context fromExecutor:(void (^)(JSValue *resolve, JSValue *reject))callback;
+ (JSValue *)valueWithNewPromiseResolvedWithResult:(id)result inContext:(JSContext *)context;
+ (JSValue *)valueWithNewPromiseRejectedWithReason:(id)reason inContext:(JSContext *)context;
+ (JSValue *)valueWithNewSymbolFromDescription:(NSString *)description inContext:(JSContext *)context;
+ (JSValue *)valueWithNullInContext:(JSContext *)context;
+ (JSValue *)valueWithUndefinedInContext:(JSContext *)context;
+ (JSValue *)valueWithJSValueRef:(JSValueRef)value inContext:(JSContext *)context;
@property (readonly) JSValueRef JSValueRef;
- (nullable id)toObject;
- (nullable id)toObjectOfClass:(Class)expectedClass;
- (BOOL)toBool;
- (double)toDouble;
- (int32_t)toInt32;
- (uint32_t)toUInt32;
- (nullable NSNumber *)toNumber;
- (nullable NSString *)toString;
- (nullable NSDate *)toDate;
- (nullable NSArray *)toArray;
- (nullable NSDictionary *)toDictionary;
- (CGPoint)toPoint;
- (CGRect)toRect;
- (CGSize)toSize;
@property (readonly) BOOL isUndefined;
@property (readonly) BOOL isNull;
@property (readonly) BOOL isBoolean;
@property (readonly) BOOL isNumber;
@property (readonly) BOOL isString;
@property (readonly) BOOL isObject;
@property (readonly) BOOL isArray;
@property (readonly) BOOL isDate;
@property (readonly) BOOL isSymbol;
- (BOOL)isEqualToObject:(nullable id)value;
- (BOOL)isEqualWithTypeCoercionToObject:(nullable id)value;
- (BOOL)isInstanceOf:(id)value;
- (nullable JSValue *)callWithArguments:(nullable NSArray *)arguments;
- (nullable JSValue *)constructWithArguments:(nullable NSArray *)arguments;
- (nullable JSValue *)invokeMethod:(NSString *)method withArguments:(nullable NSArray *)arguments;
- (nullable JSValue *)valueForProperty:(id)property;
- (void)setValue:(nullable id)value forProperty:(id)property;
- (BOOL)deleteProperty:(id)property;
- (BOOL)hasProperty:(id)property;
- (void)defineProperty:(id)property descriptor:(nullable id)descriptor;
- (nullable JSValue *)valueAtIndex:(NSUInteger)index;
- (void)setValue:(nullable id)value atIndex:(NSUInteger)index;
@end
@interface JSValue (SubscriptSupport)
- (nullable JSValue *)objectForKeyedSubscript:(id)key;
- (nullable JSValue *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(nullable id)object forKeyedSubscript:(id)key;
- (void)setObject:(nullable id)object atIndexedSubscript:(NSUInteger)index;
@end
FOUNDATION_EXPORT NSString * const JSPropertyDescriptorWritableKey, * const JSPropertyDescriptorEnumerableKey,
    * const JSPropertyDescriptorConfigurableKey, * const JSPropertyDescriptorValueKey, * const JSPropertyDescriptorGetKey,
    * const JSPropertyDescriptorSetKey;
NS_ASSUME_NONNULL_END
