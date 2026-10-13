#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIGestureRecognizer.h>
NS_ASSUME_NONNULL_BEGIN
@class UIScrollView, UIPanGestureRecognizer, UIPinchGestureRecognizer, UILayoutGuide, UIGestureRecognizer, UITouch, UIEvent;
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
/* a tap on the status bar scrolls the one visible scroll view with scrollsToTop to its top */
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView NS_SWIFT_NAME(scrollViewShouldScrollToTop(_:));
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView NS_SWIFT_NAME(scrollViewDidScrollToTop(_:));
@end
/* VoiceOver speaks the scroll status after a three-finger scroll (accessibilityScroll) or a page scrolled notification */
NS_SWIFT_UI_ACTOR
@protocol UIScrollViewAccessibilityDelegate <UIScrollViewDelegate>
@optional
- (nullable NSString *)accessibilityScrollStatusForScrollView:(UIScrollView *)scrollView;
- (nullable NSAttributedString *)accessibilityAttributedScrollStatusForScrollView:(UIScrollView *)scrollView API_AVAILABLE(ios(11.0));
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
typedef NS_ENUM(NSInteger, UIScrollViewIndicatorStyle) { UIScrollViewIndicatorStyleDefault, UIScrollViewIndicatorStyleBlack, UIScrollViewIndicatorStyleWhite } NS_SWIFT_NAME(UIScrollView.IndicatorStyle);
/* table and collection view section indexes (tvOS shows them only when asked) */
typedef NS_ENUM(NSInteger, UIScrollViewIndexDisplayMode) { UIScrollViewIndexDisplayModeAutomatic, UIScrollViewIndexDisplayModeAlwaysHidden } NS_SWIFT_NAME(UIScrollView.IndexDisplayMode);
/* isim: scroll view members from the documentation sweep (#9). UIScrollView.m (stored outside the instances) */
@interface UIScrollView (UIScrollViewExtras)
/* called when adjustedContentInset changes (before the delegate's scrollViewDidChangeAdjustedContentInset:) */
- (void)adjustedContentInsetDidChange NS_REQUIRES_SUPER;
/* a drag that starts mostly along one axis scrolls only along it */
@property (nonatomic, getter=isDirectionalLockEnabled) BOOL directionalLockEnabled;
/* rubber-banding per axis (with bounces) */
@property (nonatomic) BOOL bouncesHorizontally API_AVAILABLE(ios(17.4));
@property (nonatomic) BOOL bouncesVertically API_AVAILABLE(ios(17.4));
/* an animated setContentOffset / scroll to top, an animated zoom */
@property (nonatomic, readonly, getter=isScrollAnimating) BOOL scrollAnimating API_AVAILABLE(ios(17.4));
@property (nonatomic, readonly, getter=isZoomAnimating) BOOL zoomAnimating API_AVAILABLE(ios(17.4));
/* stops dragging, deceleration, scrolling and zooming animations where they are */
- (void)stopScrollingAndZooming API_AVAILABLE(ios(17.4));
@property (nonatomic) UIScrollViewIndicatorStyle indicatorStyle;
/* the indicators keep out of the safe area (NO: only scrollIndicatorInsets move them) */
@property (nonatomic) BOOL automaticallyAdjustsScrollIndicatorInsets API_AVAILABLE(ios(13.0));
/* both indicators' insets (setting it sets vertical and horizontal) */
@property (nonatomic) UIEdgeInsets scrollIndicatorInsets;
/* the indicators show while the block changes the content offset */
- (void)withScrollIndicatorsShownForContentOffsetChanges:(void (NS_NOESCAPE ^)(void))changes NS_SWIFT_NAME(withScrollIndicatorsShown(forContentOffsetChanges:)) API_AVAILABLE(ios(17.4));
/* content touches: whether the content view gets a touch (NO: the scroll view keeps it), and whether a drag that starts
   on content may scroll (default: not on a control that tracks drags); canCancelContentTouches NO: a drag that starts
   on a control does not scroll. isim delivers touches at once (delaysContentTouches is stored) */
- (BOOL)touchesShouldBegin:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event inContentView:(UIView *)view NS_SWIFT_NAME(touchesShouldBegin(_:with:in:));
- (BOOL)touchesShouldCancelInContentView:(UIView *)view NS_SWIFT_NAME(touchesShouldCancel(in:));
@property (nonatomic) BOOL canCancelContentTouches;
@property (nonatomic) BOOL delaysContentTouches;
/* arrow keys and remote presses (tvOS; isim: a disabled recognizer) */
@property (nonatomic, readonly) UIGestureRecognizer *directionalPressGestureRecognizer;
/* where content smaller than the scroll view rests (0,0: top left; 1,1: bottom right) */
@property (nonatomic) CGPoint contentAlignmentPoint API_AVAILABLE(ios(17.4));
/* scrolling past the edge hands the drag to a parent scroll view (isim: stored; the innermost scroll view scrolls) */
@property (nonatomic) BOOL transfersHorizontalScrollingToParent API_AVAILABLE(ios(17.4));
@property (nonatomic) BOOL transfersVerticalScrollingToParent API_AVAILABLE(ios(17.4));
/* hardware keyboard: arrows, Page Up / Down, Space, Home and End scroll the main scroll view */
@property (nonatomic) BOOL allowsKeyboardScrolling API_AVAILABLE(ios(17.0));
@end
/* iOS 26: a container of elements over a scroll view's edge (floating buttons, a custom bar); isim: stored (the bars of
   navigation controllers draw the edge effect) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIScrollEdgeElementContainerInteraction : NSObject <UIInteraction>
@property (nonatomic, weak, nullable) UIScrollView *scrollView;
@property (nonatomic) UIRectEdge edge;
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
