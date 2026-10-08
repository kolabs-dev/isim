#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIScrollView, UIPanGestureRecognizer, UIPinchGestureRecognizer, UILayoutGuide;
typedef NS_ENUM(NSInteger, UIScrollViewContentInsetAdjustmentBehavior) {
    UIScrollViewContentInsetAdjustmentAutomatic, UIScrollViewContentInsetAdjustmentScrollableAxes,
    UIScrollViewContentInsetAdjustmentNever, UIScrollViewContentInsetAdjustmentAlways
};
typedef NS_ENUM(NSInteger, UIScrollViewKeyboardDismissMode) { UIScrollViewKeyboardDismissModeNone, UIScrollViewKeyboardDismissModeOnDrag, UIScrollViewKeyboardDismissModeInteractive,
    UIScrollViewKeyboardDismissModeOnDragWithAccessory API_AVAILABLE(ios(16.0)), UIScrollViewKeyboardDismissModeInteractiveWithAccessory API_AVAILABLE(ios(16.0)) };
typedef CGFloat UIScrollViewDecelerationRate NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN const UIScrollViewDecelerationRate UIScrollViewDecelerationRateNormal, UIScrollViewDecelerationRateFast;
NS_SWIFT_UI_ACTOR
@protocol UIScrollViewDelegate <NSObject>
@optional
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView;
- (nullable UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(nullable UIView *)view;
- (void)scrollViewDidZoom:(UIScrollView *)scrollView;
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(nullable UIView *)view atScale:(CGFloat)scale;
@end
/* isim: scrolling with rubber-banding, deceleration and paging; pinch zooming (UIScrollViewZoom.m). */
@interface UIScrollView : UIView
@property (nonatomic) CGPoint contentOffset;
@property (nonatomic) CGSize contentSize;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic, readonly) UIEdgeInsets adjustedContentInset;
@property (nonatomic) UIScrollViewContentInsetAdjustmentBehavior contentInsetAdjustmentBehavior;
@property (nullable, nonatomic, weak) id <UIScrollViewDelegate> delegate;
@property (nonatomic) BOOL bounces, alwaysBounceVertical, alwaysBounceHorizontal;
@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@property (nonatomic, getter=isPagingEnabled) BOOL pagingEnabled;
@property (nonatomic) BOOL showsVerticalScrollIndicator, showsHorizontalScrollIndicator;
@property (nonatomic) UIEdgeInsets verticalScrollIndicatorInsets, horizontalScrollIndicatorInsets;
@property (nonatomic) UIScrollViewKeyboardDismissMode keyboardDismissMode;
@property (nonatomic) UIScrollViewDecelerationRate decelerationRate;
@property (nonatomic) BOOL scrollsToTop;
@property (nonatomic, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic, readonly, getter=isDragging) BOOL dragging;
@property (nonatomic, readonly, getter=isDecelerating) BOOL decelerating;
@property (nonatomic, readonly, strong) UILayoutGuide *contentLayoutGuide;
@property (nonatomic, readonly, strong) UILayoutGuide *frameLayoutGuide;
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated;
- (void)flashScrollIndicators;
@end
/* iOS 26: the effect at each edge where content scrolls under bars (Liquid Glass). isim (adapted): navigation bars and
   toolbars of a navigation controller draw it for its scroll view — automatic / soft: a fade, hard: an opaque band with
   a divider, hidden: none (the bar stays transparent); iOS 17/18 keep the material bars */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIScrollEdgeEffect.Style)
@interface UIScrollEdgeEffectStyle : NSObject
@property (class, nonatomic, readonly) UIScrollEdgeEffectStyle *automaticStyle NS_SWIFT_NAME(automatic);
@property (class, nonatomic, readonly) UIScrollEdgeEffectStyle *softStyle NS_SWIFT_NAME(soft);
@property (class, nonatomic, readonly) UIScrollEdgeEffectStyle *hardStyle NS_SWIFT_NAME(hard);
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIScrollEdgeEffect : NSObject
@property (nonatomic, strong) UIScrollEdgeEffectStyle *style;
@property (nonatomic, getter=isHidden) BOOL hidden;
@end
@interface UIScrollView (UIScrollEdgeEffect)
@property (nonatomic, readonly, strong) UIScrollEdgeEffect *topEdgeEffect API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, strong) UIScrollEdgeEffect *leftEdgeEffect API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, strong) UIScrollEdgeEffect *bottomEdgeEffect API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, strong) UIScrollEdgeEffect *rightEdgeEffect API_AVAILABLE(ios(26.0));
@end
@interface UIScrollView (UIZooming)
/* zooming: the delegate's viewForZoomingInScrollView: scales between the minimum and maximum zoom scales */
@property (nonatomic) CGFloat minimumZoomScale, maximumZoomScale, zoomScale;
@property (nonatomic) BOOL bouncesZoom;
@property (nonatomic, readonly, getter=isZooming) BOOL zooming;
@property (nonatomic, readonly, getter=isZoomBouncing) BOOL zoomBouncing;
@property (nullable, nonatomic, readonly) UIPinchGestureRecognizer *pinchGestureRecognizer;
- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated;
- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
