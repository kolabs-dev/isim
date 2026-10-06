#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSIndexSet : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
+ (instancetype)indexSet;
+ (instancetype)indexSetWithIndex:(NSUInteger)value;
+ (instancetype)indexSetWithIndexesInRange:(NSRange)range;
- (instancetype)initWithIndexesInRange:(NSRange)range NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet;
- (instancetype)initWithIndex:(NSUInteger)value;
- (BOOL)isEqualToIndexSet:(NSIndexSet *)indexSet;
@property (readonly) NSUInteger count;
@property (readonly) NSUInteger firstIndex;
@property (readonly) NSUInteger lastIndex;
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)value;
- (NSUInteger)indexLessThanIndex:(NSUInteger)value;
- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)value;
- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)value;
- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize inIndexRange:(nullable NSRangePointer)range;
- (NSUInteger)countOfIndexesInRange:(NSRange)range;
- (BOOL)containsIndex:(NSUInteger)value;
- (BOOL)containsIndexesInRange:(NSRange)range;
- (BOOL)containsIndexes:(NSIndexSet *)indexSet;
- (BOOL)intersectsIndexesInRange:(NSRange)range;
- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block;
- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block;
- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexPassingTest:(BOOL (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesPassingTest:(BOOL (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))predicate;
- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))block;
- (void)enumerateRangesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))block;
/* isim-private: range access for the Swift overlay */
- (NSUInteger)_rangeCount;
- (NSRange)_rangeAtIndex:(NSUInteger)index;
@end
@interface NSMutableIndexSet : NSIndexSet
- (void)addIndexes:(NSIndexSet *)indexSet;
- (void)removeIndexes:(NSIndexSet *)indexSet;
- (void)removeAllIndexes;
- (void)addIndex:(NSUInteger)value;
- (void)removeIndex:(NSUInteger)value;
- (void)addIndexesInRange:(NSRange)range;
- (void)removeIndexesInRange:(NSRange)range;
- (void)shiftIndexesStartingAtIndex:(NSUInteger)index by:(NSInteger)delta;
@end
NS_ASSUME_NONNULL_END
