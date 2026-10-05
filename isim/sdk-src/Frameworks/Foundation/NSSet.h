#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>;
@interface NSSet<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSSecureCoding, NSFastEnumeration>
@property (readonly) NSUInteger count;
- (nullable ObjectType)member:(ObjectType)object;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObjects:(const ObjectType _Nonnull [_Nullable])objects count:(NSUInteger)cnt NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
+ (instancetype)set;
+ (instancetype)setWithObject:(ObjectType)object;
+ (instancetype)setWithObjects:(const ObjectType _Nonnull [_Nonnull])objects count:(NSUInteger)cnt;
+ (instancetype)setWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)setWithArray:(NSArray<ObjectType> *)array;
@property (readonly, copy) NSArray<ObjectType> *allObjects;
- (nullable ObjectType)anyObject;
- (BOOL)containsObject:(ObjectType)anObject;
- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, BOOL *stop))block;
@end
@interface NSMutableSet<ObjectType> : NSSet<ObjectType>
- (void)addObject:(ObjectType)object;
- (void)removeObject:(ObjectType)object;
- (void)removeAllObjects;
- (void)addObjectsFromArray:(NSArray<ObjectType> *)array;
+ (instancetype)setWithCapacity:(NSUInteger)numItems;
@end
NS_ASSUME_NONNULL_END
