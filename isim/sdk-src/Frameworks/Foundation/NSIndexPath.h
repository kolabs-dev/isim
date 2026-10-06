#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSIndexPath : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)indexPathWithIndex:(NSUInteger)index;
+ (instancetype)indexPathWithIndexes:(const NSUInteger [_Nullable])indexes length:(NSUInteger)length;
- (instancetype)initWithIndexes:(const NSUInteger [_Nullable])indexes length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithIndex:(NSUInteger)index;
- (instancetype)init;
- (NSIndexPath *)indexPathByAddingIndex:(NSUInteger)index;
- (NSIndexPath *)indexPathByRemovingLastIndex;
- (NSUInteger)indexAtPosition:(NSUInteger)position;
@property (readonly) NSUInteger length;
- (void)getIndexes:(NSUInteger *)indexes range:(NSRange)positionRange;
- (void)getIndexes:(NSUInteger *)indexes;
- (NSComparisonResult)compare:(NSIndexPath *)otherObject;
@end
NS_ASSUME_NONNULL_END
