#pragma once
#include <Foundation/NSObjCRuntime.h>
#import <objc/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSMethodSignature, NSInvocation, Protocol;

@protocol NSCopying
- (id)copyWithZone:(nullable NSZone *)zone;
@end
@protocol NSMutableCopying
- (id)mutableCopyWithZone:(nullable NSZone *)zone;
@end
@class NSCoder;
@protocol NSCoding
- (void)encodeWithCoder:(NSCoder *)coder;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
@end
@protocol NSSecureCoding <NSCoding>
@end

typedef struct {
    unsigned long state;
    __unsafe_unretained id _Nullable * _Nullable itemsPtr;
    unsigned long * _Nullable mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;
@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer count:(NSUInteger)len;
@end

@interface NSObject (NSIsimFoundationExtras)
+ (id)copyWithZone:(nullable struct _NSZone *)zone;
- (nullable id)forwardingTargetForSelector:(SEL)aSelector;
+ (NSUInteger)hash;
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget;
@end
NS_ASSUME_NONNULL_END
