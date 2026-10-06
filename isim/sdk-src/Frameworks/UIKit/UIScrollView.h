#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIScrollView, UIPanGestureRecognizer, UIPinchGestureRecognizer, UILayoutGuide;
typedef NS_ENUM(NSInteger, UIScrollViewContentInsetAdjustmentBehavior) {
    UIScrollViewContentInsetAdjustmentAutomatic, UIScrollViewContentInsetAdjustmentScrollableAxes,
    UIScrollViewContentInsetAdjustmentNever, UIScrollViewContentInsetAdjustmentAlways
};
typedef NS_ENUM(NSInteger, UIScrollViewKeyboardDismissMode) { UIScrollViewKeyboardDismissModeNone, UIScrollViewKeyboardDismissModeOnDrag, UIScrollViewKeyboardDismissModeInteractive };
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
