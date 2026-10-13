#pragma once
/* isim: Visual Format Language, the keyboard layout guide (iOS 15), trait change registration (iOS 17). */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UILayoutGuide.h>
#import <UIKit/NSLayoutConstraint.h>
#import <UIKit/UITraitCollection.h>
#import <UIKit/UIScene.h>
#import <UIKit/UIButton.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, NSLayoutFormatOptions) {
    NSLayoutFormatAlignAllLeft = (1 << NSLayoutAttributeLeft), NSLayoutFormatAlignAllRight = (1 << NSLayoutAttributeRight),
    NSLayoutFormatAlignAllTop = (1 << NSLayoutAttributeTop), NSLayoutFormatAlignAllBottom = (1 << NSLayoutAttributeBottom),
    NSLayoutFormatAlignAllLeading = (1 << NSLayoutAttributeLeading), NSLayoutFormatAlignAllTrailing = (1 << NSLayoutAttributeTrailing),
    NSLayoutFormatAlignAllCenterX = (1 << NSLayoutAttributeCenterX), NSLayoutFormatAlignAllCenterY = (1 << NSLayoutAttributeCenterY),
    NSLayoutFormatAlignAllLastBaseline = (1 << NSLayoutAttributeLastBaseline), NSLayoutFormatAlignAllFirstBaseline = (1 << NSLayoutAttributeFirstBaseline),
    NSLayoutFormatAlignmentMask = 0xFFFF,
    NSLayoutFormatDirectionLeadingToTrailing = 0 << 16, NSLayoutFormatDirectionLeftToRight = 1 << 16, NSLayoutFormatDirectionRightToLeft = 2 << 16,
    NSLayoutFormatDirectionMask = 0x3 << 16,
    NSLayoutFormatSpacingEdgeToEdge = 0 << 19, NSLayoutFormatSpacingBaselineToBaseline API_AVAILABLE(ios(11.0)) = 1 << 19,
    NSLayoutFormatSpacingMask API_AVAILABLE(ios(11.0)) = 0x1 << 19 };
@interface NSLayoutConstraint (NSLayoutConstraintVisualFormat)
+ (NSArray<NSLayoutConstraint *> *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)opts
                                                       metrics:(nullable NSDictionary<NSString *, id> *)metrics views:(NSDictionary<NSString *, id> *)views;
@end
UIKIT_EXTERN NSDictionary<NSString *, id> *_NSDictionaryOfVariableBindings(NSString *commaSeparatedKeysString, _Nullable id firstValue, ...);
#define NSDictionaryOfVariableBindings(...) _NSDictionaryOfVariableBindings(@"" # __VA_ARGS__, __VA_ARGS__, nil)

@interface NSLayoutConstraint (NSLayoutConstraintArchiving)
/* whether archiving a view keeps the constraint (Interface Builder's constraints are archived; isim keeps the flag) */
@property BOOL shouldBeArchived;
@end
@interface NSLayoutXAxisAnchor (NSLayoutAnchorExtras)
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)anchor multiplier:(CGFloat)multiplier NS_SWIFT_NAME(constraint(greaterThanOrEqualToSystemSpacingAfter:multiplier:)) API_AVAILABLE(ios(11.0));
- (NSLayoutConstraint *)constraintLessThanOrEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)anchor multiplier:(CGFloat)multiplier NS_SWIFT_NAME(constraint(lessThanOrEqualToSystemSpacingAfter:multiplier:)) API_AVAILABLE(ios(11.0));
/* the distance from this anchor to another, as a dimension that constraints can use (isim: a spacer layout guide) */
- (NSLayoutDimension *)anchorWithOffsetToAnchor:(NSLayoutXAxisAnchor *)otherAnchor NS_SWIFT_NAME(anchorWithOffset(to:)) API_AVAILABLE(ios(10.0));
@end
@interface NSLayoutYAxisAnchor (NSLayoutAnchorExtras)
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)anchor multiplier:(CGFloat)multiplier NS_SWIFT_NAME(constraint(greaterThanOrEqualToSystemSpacingBelow:multiplier:)) API_AVAILABLE(ios(11.0));
- (NSLayoutConstraint *)constraintLessThanOrEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)anchor multiplier:(CGFloat)multiplier NS_SWIFT_NAME(constraint(lessThanOrEqualToSystemSpacingBelow:multiplier:)) API_AVAILABLE(ios(11.0));
- (NSLayoutDimension *)anchorWithOffsetToAnchor:(NSLayoutYAxisAnchor *)otherAnchor NS_SWIFT_NAME(anchorWithOffset(to:)) API_AVAILABLE(ios(10.0));
@end
@interface UILayoutGuide (UILayoutGuideDebugging)
- (NSArray<NSLayoutConstraint *> *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis API_AVAILABLE(ios(10.0));
@property (nonatomic, readonly) BOOL hasAmbiguousLayout API_AVAILABLE(ios(10.0));
@end
/* scene resizing priorities (Mac Catalyst; iOS has them too) */
static const UILayoutPriority UILayoutPriorityDragThatCanResizeScene = 510;
static const UILayoutPriority UILayoutPrioritySceneSizeStayPut = 500;
static const UILayoutPriority UILayoutPriorityDragThatCannotResizeScene = 490;
/* the top and bottom layout guides of view controllers (deprecated by the safe area) */
NS_SWIFT_UI_ACTOR
@protocol UILayoutSupport <NSObject>
@property (nonatomic, readonly) CGFloat length;
@property (readonly, strong) NSLayoutYAxisAnchor *topAnchor API_AVAILABLE(ios(9.0));
@property (readonly, strong) NSLayoutYAxisAnchor *bottomAnchor API_AVAILABLE(ios(9.0));
@property (readonly, strong) NSLayoutDimension *heightAnchor API_AVAILABLE(ios(9.0));
@end

/* a layout guide that follows something (the keyboard): constraints that are active only while it is near an edge of
   its view, or away from one; the keyboard guide is near the bottom while the keyboard is docked */
NS_SWIFT_UI_ACTOR
@interface UITrackingLayoutGuide : UILayoutGuide
- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenNearEdge:(NSDirectionalRectEdge)edge;
- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenNearEdge:(NSDirectionalRectEdge)edge NS_SWIFT_NAME(constraints(activeWhenNearEdge:));
- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenAwayFromEdge:(NSDirectionalRectEdge)edge NS_SWIFT_NAME(setConstraints(_:activeWhenAwayFrom:));
- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenAwayFromEdge:(NSDirectionalRectEdge)edge NS_SWIFT_NAME(constraints(activeWhenAwayFrom:));
- (void)removeAllTrackedConstraints;
@end
NS_SWIFT_UI_ACTOR
@interface UIKeyboardLayoutGuide : UITrackingLayoutGuide
@property (nonatomic) BOOL followsUndockedKeyboard;
@property (nonatomic) BOOL usesBottomSafeArea;
@property (nonatomic) CGFloat keyboardDismissPadding;
@end
@interface UIView (UIKeyboardLayoutGuide)
@property (nonatomic, readonly, strong) UIKeyboardLayoutGuide *keyboardLayoutGuide;
@end

/* traits as types (iOS 17): UITraitDefinition and the system trait classes are declared in UITraitCollection.h */
@protocol UITraitChangeRegistration <NSObject, NSCopying>
@end
typedef void (^UITraitChangeHandler)(id<UITraitEnvironment> traitEnvironment, UITraitCollection *previousCollection);
@interface UIView (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_REFINED_FOR_SWIFT;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
- (id<UITraitChangeRegistration>)_isim_registerForTraits:(NSArray *)traits handler:(nullable UITraitChangeHandler)handler target:(nullable id)target action:(nullable SEL)action;   /* traits: classes or Swift trait identifiers */
@end
@interface UIViewController (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_REFINED_FOR_SWIFT;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
- (id<UITraitChangeRegistration>)_isim_registerForTraits:(NSArray *)traits handler:(nullable UITraitChangeHandler)handler target:(nullable id)target action:(nullable SEL)action;   /* traits: classes or Swift trait identifiers */
@end
@class UIWindowScene;
@interface UIWindowScene (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_REFINED_FOR_SWIFT;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
- (id<UITraitChangeRegistration>)_isim_registerForTraits:(NSArray *)traits handler:(nullable UITraitChangeHandler)handler target:(nullable id)target action:(nullable SEL)action;   /* traits: classes or Swift trait identifiers */
@end
@class UIPresentationController;
@interface UIPresentationController (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_REFINED_FOR_SWIFT;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
- (id<UITraitChangeRegistration>)_isim_registerForTraits:(NSArray *)traits handler:(nullable UITraitChangeHandler)handler target:(nullable id)target action:(nullable SEL)action;   /* traits: classes or Swift trait identifiers */
@end
NS_ASSUME_NONNULL_END
