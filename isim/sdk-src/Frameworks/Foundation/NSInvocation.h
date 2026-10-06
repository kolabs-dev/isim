#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSMethodSignature;
NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available")
@interface NSInvocation : NSObject
+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig;
@property (readonly, retain) NSMethodSignature *methodSignature;
- (void)retainArguments;
@property (readonly) BOOL argumentsRetained;
@property (nullable, assign) id target;
@property SEL selector;
- (void)getReturnValue:(void *)retLoc;
- (void)setReturnValue:(void *)retLoc;
- (void)getArgument:(void *)argumentLocation atIndex:(NSInteger)idx;
- (void)setArgument:(void *)argumentLocation atIndex:(NSInteger)idx;
- (void)invoke;
- (void)invokeWithTarget:(id)target;
- (void)invokeUsingIMP:(IMP)imp;
@end
NS_ASSUME_NONNULL_END
