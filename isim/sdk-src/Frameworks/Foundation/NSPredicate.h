#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSOrderedCollections.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDictionary<KeyType, ObjectType>, NSMutableDictionary<KeyType, ObjectType>, NSPredicate;

typedef NS_ENUM(NSUInteger, NSExpressionType) {
    NSConstantValueExpressionType NS_SWIFT_NAME(constantValue) = 0, NSEvaluatedObjectExpressionType NS_SWIFT_NAME(evaluatedObject), NSVariableExpressionType NS_SWIFT_NAME(variable), NSKeyPathExpressionType NS_SWIFT_NAME(keyPath),
    NSFunctionExpressionType NS_SWIFT_NAME(function), NSUnionSetExpressionType NS_SWIFT_NAME(unionSet), NSIntersectSetExpressionType NS_SWIFT_NAME(intersectSet), NSMinusSetExpressionType NS_SWIFT_NAME(minusSet),
    NSSubqueryExpressionType NS_SWIFT_NAME(subquery) = 13, NSAggregateExpressionType NS_SWIFT_NAME(aggregate), NSAnyKeyExpressionType NS_SWIFT_NAME(anyKey) = 15, NSBlockExpressionType NS_SWIFT_NAME(block) = 19, NSConditionalExpressionType NS_SWIFT_NAME(conditional) = 20
};
@interface NSExpression : NSObject <NSSecureCoding, NSCopying>
+ (NSExpression *)expressionWithFormat:(NSString *)expressionFormat argumentArray:(NSArray *)arguments;
+ (NSExpression *)expressionWithFormat:(NSString *)expressionFormat, ...;
+ (NSExpression *)expressionWithFormat:(NSString *)expressionFormat arguments:(va_list)argList;
+ (NSExpression *)expressionForConstantValue:(nullable id)obj;
+ (NSExpression *)expressionForEvaluatedObject NS_SWIFT_NAME(expressionForEvaluatedObject());
+ (NSExpression *)expressionForVariable:(NSString *)string;
+ (NSExpression *)expressionForKeyPath:(NSString *)keyPath;
+ (NSExpression *)expressionForFunction:(NSString *)name arguments:(NSArray *)parameters;
+ (NSExpression *)expressionForAggregate:(NSArray<NSExpression *> *)subexpressions;
+ (NSExpression *)expressionForBlock:(id (^)(id _Nullable evaluatedObject, NSArray<NSExpression *> *expressions, NSMutableDictionary * _Nullable context))block arguments:(nullable NSArray<NSExpression *> *)arguments;
+ (NSExpression *)expressionForFunction:(NSExpression *)target selectorName:(NSString *)name arguments:(nullable NSArray *)parameters;
+ (NSExpression *)expressionForAnyKey NS_SWIFT_NAME(expressionForAnyKey());
/* FIRST, LAST or SIZE (the index of "array[FIRST]"); nil for anything else (Apple: private, used by Foundation's Swift code) */
+ (nullable NSExpression *)expressionForSymbolicString:(NSString *)string NS_SWIFT_NAME(init(forSymbolicString:));
+ (NSExpression *)expressionForSubquery:(NSExpression *)expression usingIteratorVariable:(NSString *)variable predicate:(NSPredicate *)predicate;
+ (NSExpression *)expressionForUnionSet:(NSExpression *)left with:(NSExpression *)right;
+ (NSExpression *)expressionForIntersectSet:(NSExpression *)left with:(NSExpression *)right;
+ (NSExpression *)expressionForMinusSet:(NSExpression *)left with:(NSExpression *)right;
+ (NSExpression *)expressionForConditional:(NSPredicate *)predicate trueExpression:(NSExpression *)trueExpression falseExpression:(NSExpression *)falseExpression;
- (instancetype)initWithExpressionType:(NSExpressionType)type NS_DESIGNATED_INITIALIZER;
@property (readonly) NSExpressionType expressionType;
@property (nullable, readonly, retain) id constantValue;
@property (readonly, copy) NSString *keyPath;
@property (readonly, copy) NSString *function;
@property (readonly, copy) NSString *variable;
@property (readonly, copy) NSExpression *operand;
@property (nullable, readonly, copy) NSArray<NSExpression *> *arguments;
@property (readonly, retain) id collection;
@property (readonly, copy) NSPredicate *predicate;
@property (readonly, copy) NSExpression *leftExpression;
@property (readonly, copy) NSExpression *rightExpression;
@property (readonly, copy) NSExpression *trueExpression;
@property (readonly, copy) NSExpression *falseExpression;
@property (readonly, copy) id (^expressionBlock)(id _Nullable, NSArray<NSExpression *> *, NSMutableDictionary * _Nullable);
- (nullable id)expressionValueWithObject:(nullable id)object context:(nullable NSMutableDictionary *)context;
- (void)allowEvaluation;
@end

@interface NSPredicate : NSObject <NSSecureCoding, NSCopying>
+ (NSPredicate *)predicateWithFormat:(NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments;
+ (NSPredicate *)predicateWithFormat:(NSString *)predicateFormat, ...;
+ (NSPredicate *)predicateWithFormat:(NSString *)predicateFormat arguments:(va_list)argList;
+ (NSPredicate *)predicateWithValue:(BOOL)value;
+ (NSPredicate *)predicateWithBlock:(BOOL (^)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block;
@property (readonly, copy) NSString *predicateFormat;
- (instancetype)predicateWithSubstitutionVariables:(NSDictionary<NSString *, id> *)variables;
- (BOOL)evaluateWithObject:(nullable id)object;
- (BOOL)evaluateWithObject:(nullable id)object substitutionVariables:(nullable NSDictionary<NSString *, id> *)bindings;
- (void)allowEvaluation;
@end

typedef NS_ENUM(NSUInteger, NSCompoundPredicateType) { NSNotPredicateType = 0, NSAndPredicateType, NSOrPredicateType };
@interface NSCompoundPredicate : NSPredicate
- (instancetype)initWithType:(NSCompoundPredicateType)type subpredicates:(NSArray<NSPredicate *> *)subpredicates NS_DESIGNATED_INITIALIZER;
@property (readonly) NSCompoundPredicateType compoundPredicateType;
@property (readonly, copy) NSArray *subpredicates;
+ (NSCompoundPredicate *)andPredicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates NS_SWIFT_NAME(init(andPredicateWithSubpredicates:));
+ (NSCompoundPredicate *)orPredicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates NS_SWIFT_NAME(init(orPredicateWithSubpredicates:));
+ (NSCompoundPredicate *)notPredicateWithSubpredicate:(NSPredicate *)predicate NS_SWIFT_NAME(init(notPredicateWithSubpredicate:));
@end

typedef NS_OPTIONS(NSUInteger, NSComparisonPredicateOptions) {
    NSCaseInsensitivePredicateOption NS_SWIFT_NAME(caseInsensitive) = 0x01, NSDiacriticInsensitivePredicateOption NS_SWIFT_NAME(diacriticInsensitive) = 0x02,
    NSNormalizedPredicateOption NS_SWIFT_NAME(normalized) = 0x04
} NS_SWIFT_NAME(NSComparisonPredicate.Options);
typedef NS_ENUM(NSUInteger, NSComparisonPredicateModifier) {
    NSDirectPredicateModifier NS_SWIFT_NAME(direct) = 0, NSAllPredicateModifier NS_SWIFT_NAME(all), NSAnyPredicateModifier NS_SWIFT_NAME(any)
} NS_SWIFT_NAME(NSComparisonPredicate.Modifier);
typedef NS_ENUM(NSUInteger, NSPredicateOperatorType) {
    NSLessThanPredicateOperatorType NS_SWIFT_NAME(lessThan) = 0, NSLessThanOrEqualToPredicateOperatorType NS_SWIFT_NAME(lessThanOrEqualTo),
    NSGreaterThanPredicateOperatorType NS_SWIFT_NAME(greaterThan), NSGreaterThanOrEqualToPredicateOperatorType NS_SWIFT_NAME(greaterThanOrEqualTo),
    NSEqualToPredicateOperatorType NS_SWIFT_NAME(equalTo), NSNotEqualToPredicateOperatorType NS_SWIFT_NAME(notEqualTo),
    NSMatchesPredicateOperatorType NS_SWIFT_NAME(matches), NSLikePredicateOperatorType NS_SWIFT_NAME(like),
    NSBeginsWithPredicateOperatorType NS_SWIFT_NAME(beginsWith), NSEndsWithPredicateOperatorType NS_SWIFT_NAME(endsWith),
    NSInPredicateOperatorType NS_SWIFT_NAME(in) = 10, NSCustomSelectorPredicateOperatorType NS_SWIFT_NAME(customSelector),
    NSContainsPredicateOperatorType NS_SWIFT_NAME(contains) = 99, NSBetweenPredicateOperatorType NS_SWIFT_NAME(between)
} NS_SWIFT_NAME(NSComparisonPredicate.Operator);
@interface NSComparisonPredicate : NSPredicate
+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)lhs rightExpression:(NSExpression *)rhs modifier:(NSComparisonPredicateModifier)modifier type:(NSPredicateOperatorType)type options:(NSComparisonPredicateOptions)options;
- (instancetype)initWithLeftExpression:(NSExpression *)lhs rightExpression:(NSExpression *)rhs modifier:(NSComparisonPredicateModifier)modifier type:(NSPredicateOperatorType)type options:(NSComparisonPredicateOptions)options NS_DESIGNATED_INITIALIZER;
@property (readonly) NSPredicateOperatorType predicateOperatorType;
@property (readonly) NSComparisonPredicateModifier comparisonPredicateModifier;
@property (readonly, retain) NSExpression *leftExpression;
@property (readonly, retain) NSExpression *rightExpression;
@property (readonly) NSComparisonPredicateOptions options;
+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)lhs rightExpression:(NSExpression *)rhs customSelector:(SEL)selector;
- (instancetype)initWithLeftExpression:(NSExpression *)lhs rightExpression:(NSExpression *)rhs customSelector:(SEL)selector NS_DESIGNATED_INITIALIZER;
@property (nullable, readonly) SEL customSelector;
@end

@interface NSArray<ObjectType> (NSPredicateSupport)
- (NSArray<ObjectType> *)filteredArrayUsingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(filtered(using:));
@end
@interface NSMutableArray<ObjectType> (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(filter(using:));
@end
@interface NSSet<ObjectType> (NSPredicateSupport)
- (NSSet<ObjectType> *)filteredSetUsingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(filtered(using:));
@end
@interface NSMutableSet<ObjectType> (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(filter(using:));
@end
@interface NSOrderedSet<ObjectType> (NSPredicateSupport)
- (NSOrderedSet<ObjectType> *)filteredOrderedSetUsingPredicate:(NSPredicate *)p NS_SWIFT_NAME(filtered(using:));
@end
@interface NSMutableOrderedSet<ObjectType> (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)p NS_SWIFT_NAME(filter(using:));
@end
NS_ASSUME_NONNULL_END
