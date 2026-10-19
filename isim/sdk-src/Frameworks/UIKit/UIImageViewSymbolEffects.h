// isim UIKit: symbol effects on image views from Objective-C (iOS 17; issue #235). The effects are Symbols.framework's
// classes; link Symbols.framework to use them (it also brings the UIKit overlay that plays them). Swift has the
// generic methods of the UIKit overlay (UIImageView.addSymbolEffect(_:options:animated:completion:)).
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIImage.h>
#import <Symbols/Symbols.h>

#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

UIKIT_EXTERN API_AVAILABLE(ios(17.0)) NS_SWIFT_UI_ACTOR
@interface UISymbolEffectCompletionContext : NSObject
@property (nonatomic, readonly, getter=isFinished) BOOL finished;
@property (nonatomic, readonly, weak, nullable) id sender;
@property (nonatomic, readonly, nullable) NSSymbolEffect *effect;
@property (nonatomic, readonly, nullable) NSSymbolContentTransition *contentTransition;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
typedef void (^UISymbolEffectCompletion)(UISymbolEffectCompletionContext *context) API_AVAILABLE(ios(17.0));

@interface UIImageView (UIImageViewSymbolEffects)
- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect API_AVAILABLE(ios(17.0));
- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options API_AVAILABLE(ios(17.0));
- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated API_AVAILABLE(ios(17.0));
- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated
             completion:(nullable UISymbolEffectCompletion)completionHandler API_AVAILABLE(ios(17.0));
- (void)removeSymbolEffectOfType:(NSSymbolEffect *)symbolEffect API_AVAILABLE(ios(17.0));
- (void)removeSymbolEffectOfType:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options API_AVAILABLE(ios(17.0));
- (void)removeSymbolEffectOfType:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated API_AVAILABLE(ios(17.0));
- (void)removeSymbolEffectOfType:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated
                      completion:(nullable UISymbolEffectCompletion)completionHandler API_AVAILABLE(ios(17.0));
- (void)removeAllSymbolEffects API_AVAILABLE(ios(17.0));
- (void)removeAllSymbolEffectsWithOptions:(NSSymbolEffectOptions *)options API_AVAILABLE(ios(17.0));
- (void)removeAllSymbolEffectsWithOptions:(NSSymbolEffectOptions *)options animated:(BOOL)animated API_AVAILABLE(ios(17.0));
- (void)setSymbolImage:(UIImage *)symbolImage withContentTransition:(NSSymbolContentTransition *)transition API_AVAILABLE(ios(17.0));
- (void)setSymbolImage:(UIImage *)symbolImage withContentTransition:(NSSymbolContentTransition *)transition
                options:(NSSymbolEffectOptions *)options API_AVAILABLE(ios(17.0));
- (void)setSymbolImage:(UIImage *)symbolImage withContentTransition:(NSSymbolContentTransition *)transition
                options:(NSSymbolEffectOptions *)options completion:(nullable UISymbolEffectCompletion)completionHandler API_AVAILABLE(ios(17.0));
@end

NS_ASSUME_NONNULL_END
#endif
