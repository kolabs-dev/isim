#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSException.h>
NS_ASSUME_NONNULL_BEGIN
@class NSError, NSString, NSMutableArray, NSIndexSet;
FOUNDATION_EXPORT NSExceptionName const NSUndefinedKeyException;
typedef NSString *NSKeyValueOperator NS_TYPED_ENUM;
FOUNDATION_EXPORT NSKeyValueOperator const NSAverageKeyValueOperator, NSCountKeyValueOperator, NSDistinctUnionOfArraysKeyValueOperator,
    NSDistinctUnionOfObjectsKeyValueOperator, NSDistinctUnionOfSetsKeyValueOperator, NSMaximumKeyValueOperator, NSMinimumKeyValueOperator,
    NSSumKeyValueOperator, NSUnionOfArraysKeyValueOperator, NSUnionOfObjectsKeyValueOperator, NSUnionOfSetsKeyValueOperator;

@interface NSObject (NSKeyValueCoding)
@property (class, readonly) BOOL accessInstanceVariablesDirectly;
- (nullable id)valueForKey:(NSString *)key;
- (void)setValue:(nullable id)value forKey:(NSString *)key;
- (BOOL)validateValue:(inout id _Nullable * _Nonnull)ioValue forKey:(NSString *)inKey error:(out NSError **)outError;
- (NSMutableArray *)mutableArrayValueForKey:(NSString *)key;
- (nullable id)valueForKeyPath:(NSString *)keyPath;
- (void)setValue:(nullable id)value forKeyPath:(NSString *)keyPath;
- (nullable id)valueForUndefinedKey:(NSString *)key;
- (void)setValue:(nullable id)value forUndefinedKey:(NSString *)key;
- (void)setNilValueForKey:(NSString *)key;
- (NSDictionary<NSString *, id> *)dictionaryWithValuesForKeys:(NSArray<NSString *> *)keys;
- (void)setValuesForKeysWithDictionary:(NSDictionary<NSString *, id> *)keyedValues;
@end
@interface NSArray<ObjectType> (NSKeyValueCoding)
- (id)valueForKey:(NSString *)key;
- (void)setValue:(nullable id)value forKey:(NSString *)key;
@end
@interface NSDictionary<KeyType, ObjectType> (NSKeyValueCoding)
- (nullable ObjectType)valueForKey:(NSString *)key;
@end
@interface NSMutableDictionary<KeyType, ObjectType> (NSKeyValueCoding)
- (void)setValue:(nullable ObjectType)value forKey:(NSString *)key;
@end
@interface NSSet<ObjectType> (NSKeyValueCoding)
- (id)valueForKey:(NSString *)key;
- (void)setValue:(nullable id)value forKey:(NSString *)key;
@end

/* key-value observing */
typedef NS_OPTIONS(NSUInteger, NSKeyValueObservingOptions) {
    NSKeyValueObservingOptionNew NS_SWIFT_NAME(new) = 0x01, NSKeyValueObservingOptionOld NS_SWIFT_NAME(old) = 0x02,
    NSKeyValueObservingOptionInitial NS_SWIFT_NAME(initial) = 0x04, NSKeyValueObservingOptionPrior NS_SWIFT_NAME(prior) = 0x08
};
typedef NS_ENUM(NSUInteger, NSKeyValueChange) {
    NSKeyValueChangeSetting NS_SWIFT_NAME(setting) = 1, NSKeyValueChangeInsertion NS_SWIFT_NAME(insertion) = 2,
    NSKeyValueChangeRemoval NS_SWIFT_NAME(removal) = 3, NSKeyValueChangeReplacement NS_SWIFT_NAME(replacement) = 4
};
typedef NSString *NSKeyValueChangeKey NS_TYPED_ENUM;
FOUNDATION_EXPORT NSKeyValueChangeKey const NSKeyValueChangeKindKey, NSKeyValueChangeNewKey, NSKeyValueChangeOldKey,
    NSKeyValueChangeIndexesKey, NSKeyValueChangeNotificationIsPriorKey;
@interface NSObject (NSKeyValueObserving)
- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context;
@end
/* isim: observing wraps the key's setter in place (no dynamic NSKVONotifying_ subclass); dotted key paths are
 * observed on their first key */
@interface NSObject (NSKeyValueObserverRegistration)
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
@end
@interface NSObject (NSKeyValueObserverNotification)
- (void)willChangeValueForKey:(NSString *)key;
- (void)didChangeValueForKey:(NSString *)key;
- (void)willChange:(NSKeyValueChange)changeKind valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key;
- (void)didChange:(NSKeyValueChange)changeKind valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key;
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key;
+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
