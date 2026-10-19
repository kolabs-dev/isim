#pragma once
/* isim: spring-loaded interactions for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UISpringLoadedInteraction;
@protocol UISpringLoadedInteractionBehavior, UISpringLoadedInteractionEffect, UISpringLoadedInteractionContext;
typedef NS_ENUM(NSInteger, UISpringLoadedInteractionEffectState) {
    UISpringLoadedInteractionEffectStateInactive, UISpringLoadedInteractionEffectStatePossible,
    UISpringLoadedInteractionEffectStateActivating, UISpringLoadedInteractionEffectStateActivated,
} API_AVAILABLE(ios(11.0));
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UISpringLoadedInteraction : NSObject <UIInteraction>
- (instancetype)initWithInteractionBehavior:(nullable id<UISpringLoadedInteractionBehavior>)interactionBehavior
                          interactionEffect:(nullable id<UISpringLoadedInteractionEffect>)interactionEffect
                          activationHandler:(void (^)(UISpringLoadedInteraction *interaction, id<UISpringLoadedInteractionContext> context))handler NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithActivationHandler:(void (^)(UISpringLoadedInteraction *interaction, id<UISpringLoadedInteractionContext> context))handler;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, strong) id<UISpringLoadedInteractionBehavior> interactionBehavior;
@property (nonatomic, readonly, strong) id<UISpringLoadedInteractionEffect> interactionEffect;
@end
NS_SWIFT_UI_ACTOR
@protocol UISpringLoadedInteractionBehavior <NSObject>
@required
- (BOOL)shouldAllowInteraction:(UISpringLoadedInteraction *)interaction withContext:(id<UISpringLoadedInteractionContext>)context;
@optional
- (void)interactionDidFinish:(UISpringLoadedInteraction *)interaction;
@end
NS_SWIFT_UI_ACTOR
@protocol UISpringLoadedInteractionEffect <NSObject>
@required
- (void)interaction:(UISpringLoadedInteraction *)interaction didChangeWithContext:(id<UISpringLoadedInteractionContext>)context;
@end
NS_SWIFT_UI_ACTOR
@protocol UISpringLoadedInteractionContext <NSObject>
@property (nonatomic, readonly) UISpringLoadedInteractionEffectState state;
@property (nullable, nonatomic, strong) UIView *targetView;
@property (nullable, nonatomic, strong) id targetItem;
- (CGPoint)locationInView:(nullable UIView *)view;
@end
NS_ASSUME_NONNULL_END
#endif
