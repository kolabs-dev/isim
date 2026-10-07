#pragma once
/* isim: UIUpdateLink (iOS 18) — per-frame actions for a view (while it is visible) or a window scene, run with the
   display links before a frame is drawn (adapted: the action phases run in their order within one callback per
   frame); requiresContinuousUpdates keeps frames coming. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UIScene.h>
#import <UIKit/UIMoreControls.h>
NS_ASSUME_NONNULL_BEGIN
@class UIUpdateLink;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIUpdateActionPhase : NSObject
@property (class, nonatomic, readonly) UIUpdateActionPhase *eventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterEventDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeCADisplayLinkDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterCADisplayLinkDispatch;
@property (class, nonatomic, readonly) UIUpdateActionPhase *beforeCATransactionCommit;
@property (class, nonatomic, readonly) UIUpdateActionPhase *afterCATransactionCommit;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIUpdateInfo : NSObject
@property (nonatomic, readonly) CFTimeInterval modelTime;
@property (nonatomic, readonly) CFTimeInterval completionDeadlineTime;
@property (nonatomic, readonly) CFTimeInterval estimatedPresentationTime;
@property (nonatomic, readonly, getter=isImmediatePresentationExpected) BOOL immediatePresentationExpected;
@property (nonatomic, readonly, getter=isLowLatencyEventDispatchConfirmed) BOOL lowLatencyEventDispatchConfirmed;
@property (nonatomic, readonly, getter=isPerformingLowLatencyPhases) BOOL performingLowLatencyPhases;
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
