#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available")
@interface NSMethodSignature : NSObject
+ (nullable NSMethodSignature *)signatureWithObjCTypes:(const char *)types;
@property (readonly) NSUInteger numberOfArguments;
- (const char *)getArgumentTypeAtIndex:(NSUInteger)idx NS_RETURNS_INNER_POINTER;
@property (readonly) NSUInteger frameLength;
- (BOOL)isOneway;
@property (readonly) const char *methodReturnType NS_RETURNS_INNER_POINTER;
@property (readonly) NSUInteger methodReturnLength;
@end
/* size and alignment of the first type in an Objective-C type encoding; returns the rest of the string */
FOUNDATION_EXPORT const char *NSGetSizeAndAlignment(const char *typePtr, NSUInteger * _Nullable sizep, NSUInteger * _Nullable alignp);
NS_ASSUME_NONNULL_END
