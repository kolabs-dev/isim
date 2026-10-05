#pragma once
#include <Foundation/NSObjCRuntime.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSMethodSignature, NSInvocation, Protocol;

@protocol NSObject
- (BOOL)isEqual:(id)object;
@property (readonly) NSUInteger hash;
@property (readonly) Class superclass;
- (Class)class;
- (instancetype)self;
- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(nullable id)object;
- (id)performSelector:(SEL)aSelector withObject:(nullable id)object1 withObject:(nullable id)object2;
- (BOOL)isProxy;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (instancetype)retain NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (oneway void)release NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (instancetype)autorelease NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (NSUInteger)retainCount NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (struct _NSZone *)zone NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
@property (readonly, copy) NSString *description;
@optional
@property (readonly, copy) NSString *debugDescription;
@end

@protocol NSCopying
- (id)copyWithZone:(nullable NSZone *)zone;
@end
@protocol NSMutableCopying
- (id)mutableCopyWithZone:(nullable NSZone *)zone;
@end
@protocol NSCoding
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

OBJC_ROOT_CLASS
@interface NSObject <NSObject> {
    Class isa;
}
+ (void)load;
+ (void)initialize;
- (instancetype)init;
+ (instancetype)new;
+ (instancetype)allocWithZone:(nullable struct _NSZone *)zone;
+ (instancetype)alloc;
- (void)dealloc;
- (id)copy;
- (id)mutableCopy;
+ (id)copyWithZone:(nullable struct _NSZone *)zone;
+ (BOOL)instancesRespondToSelector:(SEL)aSelector;
+ (BOOL)conformsToProtocol:(Protocol *)protocol;
- (IMP)methodForSelector:(SEL)aSelector;
- (void)doesNotRecognizeSelector:(SEL)aSelector;
- (nullable id)forwardingTargetForSelector:(SEL)aSelector;
+ (BOOL)isSubclassOfClass:(Class)aClass;
+ (NSUInteger)hash;
+ (Class)superclass;
+ (Class)class;
+ (NSString *)description;
+ (NSString *)debugDescription;
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget;
@end
NS_ASSUME_NONNULL_END
