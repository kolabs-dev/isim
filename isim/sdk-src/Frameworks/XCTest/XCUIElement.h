#pragma once
#import <XCTest/XCUIElementTypes.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class XCUIApplication, XCUICoordinate;

/* Attributes of a UI element as last seen in the app (isim: from a snapshot of the app's view tree). */
@protocol XCUIElementAttributes
@property (readonly) NSString *identifier;
@property (readonly) CGRect frame;
@property (readonly, nullable) id value;
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *label;
@property (readonly) XCUIElementType elementType;
@property (readonly, getter=isEnabled) BOOL enabled;
@property (readonly, getter=isSelected) BOOL selected;
@property (readonly) BOOL hasFocus;
@property (readonly, nullable) NSString *placeholderValue;
@end

/* A UI element of the application under test. Every access resolves its query against a fresh snapshot of the
 * app, like XCUITest does; actions are sent to the app as touches and key input through isim's control channel. */
@interface XCUIElement : NSObject <XCUIElementAttributes, XCUIElementTypeQueryProvider>
@property (readonly) BOOL exists;
@property (readonly, getter=isHittable) BOOL hittable;
- (BOOL)waitForExistenceWithTimeout:(NSTimeInterval)timeout NS_SWIFT_NAME(waitForExistence(timeout:));
- (BOOL)waitForNonExistenceWithTimeout:(NSTimeInterval)timeout NS_SWIFT_NAME(waitForNonExistence(timeout:));
- (XCUIElementQuery *)descendantsMatchingType:(XCUIElementType)type NS_SWIFT_NAME(descendants(matching:));
- (XCUIElementQuery *)childrenMatchingType:(XCUIElementType)type NS_SWIFT_NAME(children(matching:));
@property (readonly, copy) NSString *debugDescription;

- (void)tap;
- (void)doubleTap;
- (void)twoFingerTap;
- (void)pressForDuration:(NSTimeInterval)duration NS_SWIFT_NAME(press(forDuration:));
- (void)typeText:(NSString *)text;
- (void)swipeUp;
- (void)swipeDown;
- (void)swipeLeft;
- (void)swipeRight;
- (void)adjustToNormalizedSliderPosition:(CGFloat)normalizedSliderPosition NS_SWIFT_NAME(adjust(toNormalizedSliderPosition:));
- (XCUICoordinate *)coordinateWithNormalizedOffset:(CGVector)normalizedOffset NS_SWIFT_NAME(coordinate(withNormalizedOffset:));
@end

/* A point relative to an element (or the screen). */
@interface XCUICoordinate : NSObject
@property (readonly, nullable) XCUIElement *referencedElement;
@property (readonly) CGVector normalizedOffset;
@property (readonly) CGVector pointsOffset;
@property (readonly) CGPoint screenPoint;
- (XCUICoordinate *)coordinateWithOffset:(CGVector)offsetVector NS_SWIFT_NAME(withOffset(_:));
- (void)tap;
- (void)doubleTap;
- (void)pressForDuration:(NSTimeInterval)duration NS_SWIFT_NAME(press(forDuration:));
- (void)pressForDuration:(NSTimeInterval)duration thenDragToCoordinate:(XCUICoordinate *)otherCoordinate NS_SWIFT_NAME(press(forDuration:thenDragTo:));
@end

NS_ASSUME_NONNULL_END
