#pragma once
/* isim SpriteKit: scene transitions (cross-fade, fade, doors, push, move in, reveal, flips, Core Image filters). */
#import <SpriteKit/SpriteKitBase.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CIFilter;
typedef NS_ENUM(NSInteger, SKTransitionDirection) {
    SKTransitionDirectionUp, SKTransitionDirectionDown, SKTransitionDirectionRight, SKTransitionDirectionLeft
};
@interface SKTransition : NSObject
+ (SKTransition *)crossFadeWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)fadeWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)fadeWithColor:(UIColor *)color duration:(NSTimeInterval)sec;
+ (SKTransition *)flipHorizontalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)flipVerticalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)revealWithDirection:(SKTransitionDirection)direction duration:(NSTimeInterval)sec;
+ (SKTransition *)moveInWithDirection:(SKTransitionDirection)direction duration:(NSTimeInterval)sec;
+ (SKTransition *)pushWithDirection:(SKTransitionDirection)direction duration:(NSTimeInterval)sec;
+ (SKTransition *)doorsOpenHorizontalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)doorsOpenVerticalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)doorsCloseHorizontalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)doorsCloseVerticalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)doorwayWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)transitionWithCIFilter:(CIFilter *)filter duration:(NSTimeInterval)sec;
@property (nonatomic) BOOL pausesIncomingScene;
@property (nonatomic) BOOL pausesOutgoingScene;
@end
NS_ASSUME_NONNULL_END
#endif
