#pragma once
/* iOS 27.1: a container of a primary and a secondary view controller laid out by an arrangement: split (side by side
   or stacked, sized by dimension ranges) or overlay (the primary layered over the secondary). In Swift the
   arrangements, placements, view states and dimensions are value types of the UIKit overlay
   (UIKit+Arrangements.swift); these Objective-C classes are their `_…ObjC` counterparts there.
   isim (adapted): isim's devices have no hinge, so an overlay never turns side by side; a split stacks its views
   (vertical axis) in compact width portrait and puts them side by side otherwise, within the axes allowed. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UITargetedPreview.h>
#import <UIKit/UIButton.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UIArrangementViewControllerViewPlacement) {
    UIArrangementViewControllerViewPlacementNone = 0,
    UIArrangementViewControllerViewPlacementPrimary = 1,
    UIArrangementViewControllerViewPlacementSecondary = 2,
} NS_SWIFT_NAME(_UIArrangementViewPlacementObjC) API_AVAILABLE(ios(27.1));

/* a size along one axis: automatic (an equal share of what is left), intrinsic (the view's fitting size), absolute
   points, or a fraction of the container */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UISplitArrangementDimensionObjC) API_AVAILABLE(ios(27.1))
@interface UISplitArrangementDimension : NSObject <NSCopying>
+ (instancetype)automaticDimension;
+ (instancetype)intrinsicDimension;
+ (instancetype)absoluteDimension:(CGFloat)absoluteValue;
+ (instancetype)fractionalDimension:(CGFloat)fraction;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UISplitArrangementDimensionRangeObjC) API_AVAILABLE(ios(27.1))
@interface UISplitArrangementDimensionRange : NSObject <NSCopying>
- (instancetype)init;
@property (nonatomic, copy) UISplitArrangementDimension *minimum;
@property (nonatomic, copy) UISplitArrangementDimension *preferred;
@property (nonatomic, copy) UISplitArrangementDimension *maximum;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UISplitArrangementViewPropertiesObjC) API_AVAILABLE(ios(27.1))
@interface UISplitArrangementViewProperties : NSObject <NSCopying>
- (instancetype)init;
@property (nonatomic, copy) UISplitArrangementDimensionRange *width;
@property (nonatomic, copy) UISplitArrangementDimensionRange *height;
/* isim: when the preferred sizes do not fit, the view with the lower priority gives up space first */
@property (nonatomic) CGFloat layoutPriority;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIOverlayArrangementViewPropertiesObjC) API_AVAILABLE(ios(27.1))
@interface UIOverlayArrangementViewProperties : NSObject <NSCopying>
- (instancetype)init;
@property (nonatomic) NSDirectionalRectEdge edge;
@end

/* the abstract base of the arrangements */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIArrangementObjC) API_AVAILABLE(ios(27.1))
@interface UIArrangement : NSObject <NSCopying>
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UISplitArrangementObjC) API_AVAILABLE(ios(27.1))
@interface UISplitArrangement : UIArrangement
+ (instancetype)splitArrangement;
@property (nonatomic) UIAxis axes;
@property (nonatomic, copy, readonly) UISplitArrangementViewProperties *defaultViewProperties;
- (void)setViewProperties:(UISplitArrangementViewProperties *)viewProperties forPlacement:(UIArrangementViewControllerViewPlacement)placement;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIOverlayArrangementObjC) API_AVAILABLE(ios(27.1))
@interface UIOverlayArrangement : UIArrangement
+ (instancetype)overlayArrangement;
@property (nonatomic) UIAxis axes;
@property (nonatomic, copy, readonly) UIOverlayArrangementViewProperties *defaultViewProperties;
- (void)setViewProperties:(UIOverlayArrangementViewProperties *)viewProperties forPlacement:(UIArrangementViewControllerViewPlacement)placement;
@end

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIArrangementViewStateObjC) API_AVAILABLE(ios(27.1))
@interface UIArrangementViewState : NSObject
@property (nonatomic, readonly, getter=isHidden) BOOL hidden;
@property (nonatomic, readonly) UIAxis splitAxis;
@property (nonatomic, readonly) NSInteger zIndex;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(27.1))
@interface UIArrangementViewController : UIViewController
- (instancetype)init;
- (void)updateArrangement:(UIArrangement *)arrangement NS_REFINED_FOR_SWIFT;
- (void)updateArrangement:(UIArrangement *)arrangement animated:(BOOL)animated NS_REFINED_FOR_SWIFT;
- (nullable UIViewController *)viewControllerForPlacement:(UIArrangementViewControllerViewPlacement)placement NS_REFINED_FOR_SWIFT;
- (void)setViewController:(nullable UIViewController *)viewController forPlacement:(UIArrangementViewControllerViewPlacement)placement NS_REFINED_FOR_SWIFT;
- (void)setViewController:(nullable UIViewController *)viewController forPlacement:(UIArrangementViewControllerViewPlacement)placement animated:(BOOL)animated NS_REFINED_FOR_SWIFT;
- (UIArrangementViewControllerViewPlacement)placementForViewController:(UIViewController *)viewController NS_REFINED_FOR_SWIFT;
- (nullable UIArrangementViewState *)stateForPlacement:(UIArrangementViewControllerViewPlacement)placement NS_REFINED_FOR_SWIFT;
@end

@interface UIViewController (UIArrangementViewController)
/* the nearest ancestor arrangement view controller */
@property (nonatomic, readonly, nullable) UIArrangementViewController *arrangementViewController API_AVAILABLE(ios(27.1));
@end
NS_ASSUME_NONNULL_END
