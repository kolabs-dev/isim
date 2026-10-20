#pragma once
#import <XCTest/XCUIElementTypes.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class XCUIApplication, XCUICoordinate;
@protocol XCUIElementSnapshot;

/* Gesture speeds in points per second (isim, adapted: a gesture's duration is its distance over the velocity). */
typedef CGFloat XCUIGestureVelocity NS_TYPED_EXTENSIBLE_ENUM;
XCT_EXPORT const XCUIGestureVelocity XCUIGestureVelocityDefault;
XCT_EXPORT const XCUIGestureVelocity XCUIGestureVelocitySlow;
XCT_EXPORT const XCUIGestureVelocity XCUIGestureVelocityFast;

/* The keys of an element snapshot's dictionaryRepresentation. */
typedef NSString *XCUIElementAttributeName NS_TYPED_ENUM;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameIdentifier;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameFrame;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameValue;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameTitle;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameLabel;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameElementType;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameEnabled;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNamePlaceholderValue;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameSelected;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameHasFocus;
XCT_EXPORT XCUIElementAttributeName const XCUIElementAttributeNameChildren;

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

/* An element's attributes and its descendants at one moment (XCUIElement snapshot()): no further queries. */
@protocol XCUIElementSnapshot <XCUIElementAttributes>
@property (readonly, copy) NSArray<id<XCUIElementSnapshot>> *children;
@property (readonly, copy) NSDictionary<XCUIElementAttributeName, id> *dictionaryRepresentation;
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
/* isim (adapted): scripted touch has two fingers; more touches are recorded as an issue and tapped with two */
- (void)tapWithNumberOfTaps:(NSUInteger)numberOfTaps numberOfTouches:(NSUInteger)numberOfTouches
    NS_SWIFT_NAME(tap(withNumberOfTaps:numberOfTouches:));
- (void)pressForDuration:(NSTimeInterval)duration NS_SWIFT_NAME(press(forDuration:));
- (void)pressForDuration:(NSTimeInterval)duration thenDragToElement:(XCUIElement *)otherElement NS_SWIFT_NAME(press(forDuration:thenDragTo:));
- (void)pressForDuration:(NSTimeInterval)duration thenDragToElement:(XCUIElement *)otherElement withVelocity:(XCUIGestureVelocity)velocity
     thenHoldForDuration:(NSTimeInterval)holdDuration NS_SWIFT_NAME(press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:));
- (void)typeText:(NSString *)text;
- (void)swipeUp;
- (void)swipeDown;
- (void)swipeLeft;
- (void)swipeRight;
- (void)swipeUpWithVelocity:(XCUIGestureVelocity)velocity NS_SWIFT_NAME(swipeUp(velocity:));
- (void)swipeDownWithVelocity:(XCUIGestureVelocity)velocity NS_SWIFT_NAME(swipeDown(velocity:));
- (void)swipeLeftWithVelocity:(XCUIGestureVelocity)velocity NS_SWIFT_NAME(swipeLeft(velocity:));
- (void)swipeRightWithVelocity:(XCUIGestureVelocity)velocity NS_SWIFT_NAME(swipeRight(velocity:));
/* two fingers around the element's centre: scale > 1 spreads them (zoom in); velocity in scale factor per second */
- (void)pinchWithScale:(CGFloat)scale velocity:(CGFloat)velocity;
/* two fingers turning around the element's centre: rotation in radians, velocity in radians per second */
- (void)rotate:(CGFloat)rotation withVelocity:(CGFloat)velocity;
/* the element's attributes and descendants now (nil, with the error, when it does not exist) */
- (nullable id<XCUIElementSnapshot>)snapshotWithError:(NSError **)error NS_SWIFT_NAME(snapshot());
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
- (void)pressForDuration:(NSTimeInterval)duration thenDragToCoordinate:(XCUICoordinate *)otherCoordinate withVelocity:(XCUIGestureVelocity)velocity
     thenHoldForDuration:(NSTimeInterval)holdDuration NS_SWIFT_NAME(press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:));
@end

NS_ASSUME_NONNULL_END
