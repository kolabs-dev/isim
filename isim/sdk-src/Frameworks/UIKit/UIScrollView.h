#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIScrollView, UIPanGestureRecognizer, UILayoutGuide;
typedef NS_ENUM(NSInteger, UIScrollViewContentInsetAdjustmentBehavior) {
    UIScrollViewContentInsetAdjustmentAutomatic, UIScrollViewContentInsetAdjustmentScrollableAxes,
    UIScrollViewContentInsetAdjustmentNever, UIScrollViewContentInsetAdjustmentAlways
};
typedef NS_ENUM(NSInteger, UIScrollViewKeyboardDismissMode) { UIScrollViewKeyboardDismissModeNone, UIScrollViewKeyboardDismissModeOnDrag, UIScrollViewKeyboardDismissModeInteractive };
typedef CGFloat UIScrollViewDecelerationRate NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN const UIScrollViewDecelerationRate UIScrollViewDecelerationRateNormal, UIScrollViewDecelerationRateFast;
@protocol UIScrollViewDelegate <NSObject>
@optional
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView;
@end
/* isim: one-finger scrolling with rubber-banding and deceleration; no zooming or paging animation. */
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
NS_ASSUME_NONNULL_END
