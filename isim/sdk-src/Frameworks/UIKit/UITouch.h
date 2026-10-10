#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UIView, UIWindow;
/* the region phases are those of a pointer over a view without a button down (hover) */
typedef NS_ENUM(NSInteger, UITouchPhase) { UITouchPhaseBegan, UITouchPhaseMoved, UITouchPhaseStationary, UITouchPhaseEnded, UITouchPhaseCancelled,
    UITouchPhaseRegionEntered API_AVAILABLE(ios(13.4)), UITouchPhaseRegionMoved API_AVAILABLE(ios(13.4)), UITouchPhaseRegionExited API_AVAILABLE(ios(13.4)) };
typedef NS_ENUM(NSInteger, UITouchType) { UITouchTypeDirect, UITouchTypeIndirect, UITouchTypePencil, UITouchTypeStylus = UITouchTypePencil, UITouchTypeIndirectPointer };
typedef NS_OPTIONS(NSInteger, UITouchProperties) {
    UITouchPropertyForce = 1UL << 0, UITouchPropertyAzimuth = 1UL << 1, UITouchPropertyAltitude = 1UL << 2,
    UITouchPropertyLocation = 1UL << 3, UITouchPropertyRoll = 1UL << 4
};
NS_SWIFT_UI_ACTOR
@interface UITouch : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly) UITouchType type;
@property (nullable, nonatomic, readonly, strong) UIWindow *window;
@property (nullable, nonatomic, readonly, strong) UIView *view;
- (CGPoint)locationInView:(nullable UIView *)view;
- (CGPoint)previousLocationInView:(nullable UIView *)view;
- (CGPoint)preciseLocationInView:(nullable UIView *)view;
- (CGPoint)precisePreviousLocationInView:(nullable UIView *)view;
@property (nonatomic, readonly) CGFloat majorRadius;
@property (nonatomic, readonly) CGFloat majorRadiusTolerance;
@property (nonatomic, readonly) CGFloat force;
@property (nonatomic, readonly) CGFloat maximumPossibleForce;
@property (nonatomic, readonly) CGFloat altitudeAngle;
- (CGFloat)azimuthAngleInView:(nullable UIView *)view;
- (CGVector)azimuthUnitVectorInView:(nullable UIView *)view;
@property (nonatomic, readonly) CGFloat rollAngle;
@property (nonatomic, readonly) UITouchProperties estimatedProperties;
@property (nonatomic, readonly) UITouchProperties estimatedPropertiesExpectingUpdates;
@property (nonatomic, readonly, nullable) NSNumber *estimationUpdateIndex;
@property (nullable, nonatomic, readonly, copy) NSArray *gestureRecognizers;
@end
NS_ASSUME_NONNULL_END
