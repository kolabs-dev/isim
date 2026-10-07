#pragma once
#import <XCTest/XCUIElement.h>

NS_ASSUME_NONNULL_BEGIN

/* Locates elements: by type below an element or query, filtered by identifier/label/predicate. */
@interface XCUIElementQuery : NSObject <XCUIElementTypeQueryProvider>
@property (readonly) XCUIElement *element;
@property (readonly) NSUInteger count;
@property (readonly) XCUIElement *firstMatch;
- (XCUIElement *)elementAtIndex:(NSUInteger)index NS_SWIFT_UNAVAILABLE("use element(boundBy:)");
- (XCUIElement *)elementBoundByIndex:(NSUInteger)index NS_SWIFT_NAME(element(boundBy:));
- (XCUIElement *)elementMatchingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(element(matching:));
- (XCUIElement *)elementMatchingType:(XCUIElementType)elementType identifier:(nullable NSString *)identifier NS_SWIFT_NAME(element(matching:identifier:));
- (XCUIElement *)objectForKeyedSubscript:(NSString *)key;
@property (readonly, copy) NSArray<XCUIElement *> *allElementsBoundByIndex;
@property (readonly, copy) NSArray<XCUIElement *> *allElementsBoundByAccessibilityElement;
- (XCUIElementQuery *)descendantsMatchingType:(XCUIElementType)type NS_SWIFT_NAME(descendants(matching:));
- (XCUIElementQuery *)childrenMatchingType:(XCUIElementType)type NS_SWIFT_NAME(children(matching:));
- (XCUIElementQuery *)matchingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(matching(_:));
- (XCUIElementQuery *)matchingType:(XCUIElementType)elementType identifier:(nullable NSString *)identifier NS_SWIFT_NAME(matching(_:identifier:));
- (XCUIElementQuery *)matchingIdentifier:(NSString *)identifier NS_SWIFT_NAME(matching(identifier:));
- (XCUIElementQuery *)containingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(containing(_:));
- (XCUIElementQuery *)containingType:(XCUIElementType)elementType identifier:(nullable NSString *)identifier NS_SWIFT_NAME(containing(_:identifier:));
@property (readonly, copy) NSString *debugDescription;
@end

NS_ASSUME_NONNULL_END
