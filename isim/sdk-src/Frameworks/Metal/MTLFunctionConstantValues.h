#pragma once
#import <Metal/MTLArgument.h>
NS_ASSUME_NONNULL_BEGIN
/* the values of a library's [[function_constant(n)]] declarations for one function (makeFunction(name:constantValues:)) */
@interface MTLFunctionConstantValues : NSObject <NSCopying>
- (void)setConstantValue:(const void *)value type:(MTLDataType)type atIndex:(NSUInteger)index NS_SWIFT_NAME(setConstantValue(_:type:index:));
- (void)setConstantValues:(const void *)values type:(MTLDataType)type withRange:(NSRange)range NS_SWIFT_NAME(__setConstantValues(_:type:with:));
- (void)setConstantValue:(const void *)value type:(MTLDataType)type withName:(NSString *)name;
- (void)reset;
@end
NS_ASSUME_NONNULL_END
