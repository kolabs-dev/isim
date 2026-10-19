#pragma once
/* isim Symbols for Objective-C (issue #235): the symbol effects, effect options and content transitions UIKit plays
   (-[UIImageView addSymbolEffect:...]). Symbols.framework re-exports the Swift overlay (libswiftSymbols); these
   classes describe an effect, and UIKit plays it the way it plays Swift's (adapted: isim animates the whole image
   rather than individual symbol layers, so byLayer and the variable-colour modes only change the timing).
   Swift uses the overlay's structs (BounceSymbolEffect ...); these declarations are hidden from Swift. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

/* ---- options ---- */
API_AVAILABLE(ios(18.0))
@interface NSSymbolEffectOptionsRepeatBehavior : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)behaviorPeriodic;
+ (instancetype)behaviorPeriodicWithCount:(NSInteger)count;
+ (instancetype)behaviorPeriodicWithDelay:(double)delay;
+ (instancetype)behaviorPeriodicWithCount:(NSInteger)count delay:(double)delay;
+ (instancetype)behaviorContinuous;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolEffectOptions : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)options;
+ (instancetype)optionsWithRepeating API_DEPRECATED("Use optionsWithRepeatBehavior:", ios(17.0, 18.0));
- (instancetype)optionsWithRepeating API_DEPRECATED("Use optionsWithRepeatBehavior:", ios(17.0, 18.0));
+ (instancetype)optionsWithNonRepeating;
- (instancetype)optionsWithNonRepeating;
+ (instancetype)optionsWithRepeatCount:(NSInteger)count;
- (instancetype)optionsWithRepeatCount:(NSInteger)count;
+ (instancetype)optionsWithSpeed:(double)speed;
- (instancetype)optionsWithSpeed:(double)speed;
+ (instancetype)optionsWithRepeatBehavior:(NSSymbolEffectOptionsRepeatBehavior *)behavior API_AVAILABLE(ios(18.0));
- (instancetype)optionsWithRepeatBehavior:(NSSymbolEffectOptionsRepeatBehavior *)behavior API_AVAILABLE(ios(18.0));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/* ---- effects ---- */
API_AVAILABLE(ios(17.0))
@interface NSSymbolEffect : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolPulseEffect : NSSymbolEffect
+ (instancetype)effect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolBounceEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)bounceUpEffect;
+ (instancetype)bounceDownEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolVariableColorEffect : NSSymbolEffect
+ (instancetype)effect;
- (instancetype)effectWithIterative;
- (instancetype)effectWithCumulative;
- (instancetype)effectWithReversing;
- (instancetype)effectWithNonReversing;
- (instancetype)effectWithHideInactiveLayers;
- (instancetype)effectWithDimInactiveLayers;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolScaleEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)scaleUpEffect;
+ (instancetype)scaleDownEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolAppearEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)appearUpEffect;
+ (instancetype)appearDownEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolDisappearEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)disappearUpEffect;
+ (instancetype)disappearDownEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(18.0))
@interface NSSymbolWiggleEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)wiggleClockwiseEffect;
+ (instancetype)wiggleCounterClockwiseEffect;
+ (instancetype)wiggleLeftEffect;
+ (instancetype)wiggleRightEffect;
+ (instancetype)wiggleUpEffect;
+ (instancetype)wiggleDownEffect;
+ (instancetype)wiggleForwardEffect;
+ (instancetype)wiggleBackwardEffect;
+ (instancetype)wiggleCustomAngleEffect:(double)angle;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(18.0))
@interface NSSymbolRotateEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)rotateClockwiseEffect;
+ (instancetype)rotateCounterClockwiseEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(18.0))
@interface NSSymbolBreatheEffect : NSSymbolEffect
+ (instancetype)effect;
+ (instancetype)breathePulseEffect;
+ (instancetype)breathePlainEffect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
@end

API_AVAILABLE(ios(26.0))
@interface NSSymbolDrawOnEffect : NSSymbolEffect
+ (instancetype)effect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
- (instancetype)effectWithIndividually;
@end

API_AVAILABLE(ios(26.0))
@interface NSSymbolDrawOffEffect : NSSymbolEffect
+ (instancetype)effect;
- (instancetype)effectWithByLayer;
- (instancetype)effectWithWholeSymbol;
- (instancetype)effectWithIndividually;
- (instancetype)effectWithReversed;
- (instancetype)effectWithNonReversed;
@end

/* ---- content transitions ---- */
API_AVAILABLE(ios(17.0))
@interface NSSymbolContentTransition : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolReplaceContentTransition : NSSymbolContentTransition
+ (instancetype)transition;
+ (instancetype)replaceDownUpTransition;
+ (instancetype)replaceUpUpTransition;
+ (instancetype)replaceOffUpTransition;
- (instancetype)transitionWithByLayer;
- (instancetype)transitionWithWholeSymbol;
@end

API_AVAILABLE(ios(17.0))
@interface NSSymbolAutomaticContentTransition : NSSymbolContentTransition
+ (instancetype)transition;
@end

NS_ASSUME_NONNULL_END
#endif
