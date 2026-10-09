#pragma once
/* Layout regions (iOS 26; bars on an edge iOS 27.1) and reserved regions (iOS 27.1). Swift: UIView.LayoutRegion and
   UIView.ReservedRegion are value types of the UIKit overlay (UIKit+Arrangements.swift).
   isim (adapted): isim has no window controls, so corner adaptation changes nothing; a bar region is a strip of the
   given extent along the edge of the safe area. Occlusion regions are the Dynamic Island or the notch (where the
   device has one; on its side in landscape), always active, with no margins; isim's devices have no hinge, so there
   are no division regions. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UILayoutGuide.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIButton.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, UIViewLayoutRegionAdaptivityAxis) {
    UIViewLayoutRegionAdaptivityAxisNone = 0,
    UIViewLayoutRegionAdaptivityAxisHorizontal = 1,
    UIViewLayoutRegionAdaptivityAxisVertical = 2,
} NS_SWIFT_NAME(_UIViewLayoutRegionAdaptivityAxisObjC) API_AVAILABLE(ios(26.0));

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIViewLayoutRegionObjC) API_AVAILABLE(ios(26.0))
@interface UIViewLayoutRegion : NSObject <NSCopying>
+ (UIViewLayoutRegion *)safeAreaLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)adaptivityAxis;
+ (UIViewLayoutRegion *)marginsLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)adaptivityAxis;
+ (UIViewLayoutRegion *)readableContentLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)adaptivityAxis;
+ (UIViewLayoutRegion *)layoutRegionForBarOnEdge:(UIRectEdge)edge extent:(CGFloat)extent NS_SWIFT_NAME(_bar(edge:extent:)) API_AVAILABLE(ios(27.1));
+ (UIViewLayoutRegion *)layoutRegionForBarOnDirectionalEdge:(NSDirectionalRectEdge)edge extent:(CGFloat)extent NS_SWIFT_NAME(_bar(directionalEdge:extent:)) API_AVAILABLE(ios(27.1));
@end

@interface UIView (UIViewLayoutRegion)
- (UILayoutGuide *)layoutGuideForLayoutRegion:(UIViewLayoutRegion *)layoutRegion NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(26.0));
- (UIEdgeInsets)edgeInsetsForLayoutRegion:(UIViewLayoutRegion *)layoutRegion NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(26.0));
- (NSDirectionalEdgeInsets)directionalEdgeInsetsForLayoutRegion:(UIViewLayoutRegion *)layoutRegion NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(26.0));
@end

/* ---- reserved regions (iOS 27.1) ---- */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIViewReservedRegionKindObjC) API_AVAILABLE(ios(27.1))
@interface UIViewReservedRegionKind : NSObject <NSCopying>
+ (instancetype)occlusionRegionKind;
+ (instancetype)divisionRegionKind;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIViewReservedRegionIdentifierObjC) API_AVAILABLE(ios(27.1))
@interface UIViewReservedRegionIdentifier : NSObject <NSCopying>
@end
typedef NS_OPTIONS(NSUInteger, UIViewReservedRegionQueryOptions) {
    UIViewReservedRegionQueryOptionsNone = 0,
    UIViewReservedRegionQueryOptionsIncludeInactive = 1 << 0,
} NS_SWIFT_NAME(_UIViewReservedRegionQueryOptionsObjC) API_AVAILABLE(ios(27.1));
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIViewReservedRegionObjC) API_AVAILABLE(ios(27.1))
@interface UIViewReservedRegion : NSObject
@property (nonatomic, readonly) CGRect frame;              /* in the view's coordinate space, including the margins */
@property (nonatomic, readonly, getter=isActive) BOOL active;
@property (nonatomic, readonly) UIViewReservedRegionKind *kind;
@property (nonatomic, readonly) UIViewReservedRegionIdentifier *identifier;
@property (nonatomic, readonly) UIEdgeInsets margins;
@end
@interface UIView (UIViewReservedRegion)
- (NSArray<UIViewReservedRegion *> *)reservedRegionsOfKind:(UIViewReservedRegionKind *)kind NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(27.1));
- (NSArray<UIViewReservedRegion *> *)reservedRegionsOfKind:(UIViewReservedRegionKind *)kind options:(UIViewReservedRegionQueryOptions)options NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(27.1));
@end
NS_ASSUME_NONNULL_END
