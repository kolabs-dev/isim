#pragma once
/* isim: UIUpdateLink (iOS 18) — per-frame actions for a view (while it is visible) or a window scene; requiresContinuousUpdates
   keeps frames coming. Adapted: the phases run in Apple's order around the display links and the frame's drawing; the
   low-latency phases never run (low-latency event dispatch is never confirmed). eventDispatch is isim's earlier name
   for beforeEventDispatch. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UIScene.h>
#import <UIKit/UIMoreControls.h>
NS_ASSUME_NONNULL_BEGIN
@class UIUpdateLink;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIUpdateActionPhase : NSObject
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterUpdateScheduled;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeEventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *eventDispatch;     /* isim's earlier name for beforeEventDispatch */
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterEventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeLowLatencyEventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterLowLatencyEventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeCADisplayLinkDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterCADisplayLinkDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeLowLatencyCATransactionCommit;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterLowLatencyCATransactionCommit;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeCATransactionCommit;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterCATransactionCommit;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterUpdateComplete;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIUpdateInfo : NSObject
@property (nonatomic, readonly) CFTimeInterval modelTime;
@property (nonatomic, readonly) CFTimeInterval completionDeadlineTime;
@property (nonatomic, readonly) CFTimeInterval estimatedPresentationTime;
@property (nonatomic, readonly, getter=isImmediatePresentationExpected) BOOL immediatePresentationExpected;
@property (nonatomic, readonly, getter=isLowLatencyEventDispatchConfirmed) BOOL lowLatencyEventDispatchConfirmed;
@property (nonatomic, readonly, getter=isPerformingLowLatencyPhases) BOOL performingLowLatencyPhases;
/* the update in progress (from before the display links until the frame is drawn), else nil */
+ (nullable instancetype)currentUpdateInfoForWindowScene:(UIWindowScene *)windowScene NS_SWIFT_NAME(current(for:));
+ (nullable instancetype)currentUpdateInfoForView:(UIView *)view NS_SWIFT_NAME(current(for:));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIUpdateLink : NSObject
+ (instancetype)updateLinkForWindowScene:(UIWindowScene *)windowScene NS_SWIFT_NAME(init(windowScene:));
+ (instancetype)updateLinkForWindowScene:(UIWindowScene *)windowScene actionTarget:(id)target selector:(SEL)selector NS_SWIFT_NAME(init(windowScene:actionTarget:selector:));
+ (instancetype)updateLinkForView:(UIView *)view NS_SWIFT_NAME(init(view:));
+ (instancetype)updateLinkForView:(UIView *)view actionTarget:(id)target selector:(SEL)selector NS_SWIFT_NAME(init(view:actionTarget:selector:));
- (void)addActionToPhase:(UIUpdateActionPhase *)phase handler:(void (^)(UIUpdateLink *updateLink, UIUpdateInfo *updateInfo))handler NS_SWIFT_NAME(addAction(to:handler:));
- (void)addActionToPhase:(UIUpdateActionPhase *)phase target:(id)target selector:(SEL)selector NS_SWIFT_NAME(addAction(to:target:selector:));
- (void)addActionWithHandler:(void (^)(UIUpdateLink *updateLink, UIUpdateInfo *updateInfo))handler NS_SWIFT_NAME(addAction(handler:));
- (void)addActionWithTarget:(id)target selector:(SEL)selector NS_SWIFT_NAME(addAction(target:selector:));
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) BOOL requiresContinuousUpdates;
@property (nonatomic) BOOL wantsLowLatencyEventDispatch;
@property (nonatomic) BOOL wantsImmediatePresentation;
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic, readonly, nullable) UIUpdateInfo *currentUpdateInfo;
@end

/* iOS 26: updateProperties runs before layout when properties need updating (setNeedsUpdateProperties; once at first);
   with automatic observation tracking a change to an @Observable property read there calls setNeedsUpdateProperties */
@interface UIView (UIUpdateProperties)
- (void)updateProperties API_AVAILABLE(ios(26.0));
- (void)setNeedsUpdateProperties API_AVAILABLE(ios(26.0));
- (void)updatePropertiesIfNeeded API_AVAILABLE(ios(26.0));
@end
@class UIViewController;
@interface UIViewController (UIUpdateProperties)
- (void)updateProperties API_AVAILABLE(ios(26.0));
- (void)setNeedsUpdateProperties API_AVAILABLE(ios(26.0));
- (void)updatePropertiesIfNeeded API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
