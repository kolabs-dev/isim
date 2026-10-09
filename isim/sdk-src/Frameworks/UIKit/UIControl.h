#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIAction, UITouch;
typedef NS_OPTIONS(NSUInteger, UIControlEvents) {
    UIControlEventTouchDown = 1 << 0, UIControlEventTouchDownRepeat = 1 << 1, UIControlEventTouchDragInside = 1 << 2,
    UIControlEventTouchDragOutside = 1 << 3, UIControlEventTouchDragEnter = 1 << 4, UIControlEventTouchDragExit = 1 << 5,
    UIControlEventTouchUpInside = 1 << 6, UIControlEventTouchUpOutside = 1 << 7, UIControlEventTouchCancel = 1 << 8,
    UIControlEventValueChanged = 1 << 12, UIControlEventPrimaryActionTriggered = 1 << 13, UIControlEventMenuActionTriggered = 1 << 14,
    UIControlEventEditingDidBegin = 1 << 16, UIControlEventEditingChanged = 1 << 17, UIControlEventEditingDidEnd = 1 << 18,
    UIControlEventEditingDidEndOnExit = 1 << 19, UIControlEventAllTouchEvents = 0x00000FFF, UIControlEventAllEditingEvents = 0x000F0000,
    UIControlEventApplicationReserved = 0x0F000000, UIControlEventSystemReserved = 0xF0000000, UIControlEventAllEvents = 0xFFFFFFFF
};
typedef NS_OPTIONS(NSUInteger, UIControlState) {
    UIControlStateNormal = 0, UIControlStateHighlighted = 1 << 0, UIControlStateDisabled = 1 << 1, UIControlStateSelected = 1 << 2,
    UIControlStateFocused = 1 << 3, UIControlStateApplication = 0x00FF0000, UIControlStateReserved = 0xFF000000
};
typedef NS_ENUM(NSInteger, UIControlContentHorizontalAlignment) { UIControlContentHorizontalAlignmentCenter = 0, UIControlContentHorizontalAlignmentLeft, UIControlContentHorizontalAlignmentRight, UIControlContentHorizontalAlignmentFill, UIControlContentHorizontalAlignmentLeading, UIControlContentHorizontalAlignmentTrailing };
typedef NS_ENUM(NSInteger, UIControlContentVerticalAlignment) { UIControlContentVerticalAlignmentCenter = 0, UIControlContentVerticalAlignmentTop, UIControlContentVerticalAlignmentBottom, UIControlContentVerticalAlignmentFill };
@interface UIControl : UIView
- (instancetype)initWithFrame:(CGRect)frame primaryAction:(nullable UIAction *)primaryAction;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic) UIControlContentVerticalAlignment contentVerticalAlignment;
@property (nonatomic) UIControlContentHorizontalAlignment contentHorizontalAlignment;
@property (nonatomic, readonly) UIControlState state;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic, readonly, getter=isTouchInside) BOOL touchInside;
- (void)addTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)addAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents;
@property (nonatomic, readonly) NSSet *allTargets;
@property (nonatomic, readonly) UIControlEvents allControlEvents;
- (nullable NSArray<NSString *> *)actionsForTarget:(nullable id)target forControlEvent:(UIControlEvents)controlEvent;
- (void)sendAction:(SEL)action to:(nullable id)target forEvent:(nullable UIEvent *)event;
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents;
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(nullable UIEvent *)event;
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(nullable UIEvent *)event;
- (void)endTrackingWithTouch:(nullable UITouch *)touch withEvent:(nullable UIEvent *)event;
- (void)cancelTrackingWithEvent:(nullable UIEvent *)event;
@end
typedef void (^UIActionHandler)(UIAction *action);
@class UIImage;
typedef NS_OPTIONS(NSUInteger, UIMenuElementAttributes) { UIMenuElementAttributesDisabled = 1 << 0, UIMenuElementAttributesDestructive = 1 << 1, UIMenuElementAttributesHidden = 1 << 2 };
typedef NS_ENUM(NSInteger, UIMenuElementState) { UIMenuElementStateOff, UIMenuElementStateOn, UIMenuElementStateMixed };
NS_SWIFT_UI_ACTOR
/* iOS 27: whether a menu shows an element's image (automatic: shown when it has one) */
typedef NS_ENUM(NSInteger, UIMenuElementImageVisibility) { UIMenuElementImageVisibilityAutomatic = 0, UIMenuElementImageVisibilityVisible = 1,
    UIMenuElementImageVisibilityHidden = 2 } NS_SWIFT_NAME(UIMenuElement.ImageVisibility) API_AVAILABLE(ios(27.0));
@interface UIMenuElement : NSObject <NSCopying>
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) UIImage *image;
@property (nullable, nonatomic, copy) NSString *subtitle;      /* a second line under the title in menus */
@property (nonatomic) UIMenuElementImageVisibility preferredImageVisibility API_AVAILABLE(ios(27.0));
/* iOS 27: called when the element's row in a menu is highlighted or unhighlighted (touch down, keyboard navigation) */
@property (nullable, nonatomic, copy) void (^highlightStateUpdateHandler)(UIMenuElement *element, BOOL isHighlighted) API_AVAILABLE(ios(27.0));
@end
NS_SWIFT_UI_ACTOR
@interface UIAction : UIMenuElement
+ (instancetype)actionWithHandler:(UIActionHandler)handler;
+ (instancetype)actionWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier handler:(UIActionHandler)handler;
+ (instancetype)actionWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier
           discoverabilityTitle:(nullable NSString *)discoverabilityTitle attributes:(UIMenuElementAttributes)attributes
                          state:(UIMenuElementState)state handler:(UIActionHandler)handler
    NS_SWIFT_NAME(init(__title:image:identifier:discoverabilityTitle:attributes:state:handler:));
@property (nonatomic, readonly, nullable, weak) id sender;
@property (nonatomic) UIMenuElementAttributes attributes;
@property (nonatomic) UIMenuElementState state;
@property (nonatomic, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END
