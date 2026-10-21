#pragma once
/* isim GameKit: the turn-based matchmaker (a UIViewController on isim, a UINavigationController on iOS). */
#import <GameKit/GKTurnBasedMatch.h>
#import <GameKit/GKMatchmakerViewController.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKTurnBasedMatchmakerViewController;
@protocol GKTurnBasedMatchmakerViewControllerDelegate <NSObject>
@required
- (void)turnBasedMatchmakerViewControllerWasCancelled:(GKTurnBasedMatchmakerViewController *)viewController;
- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)viewController didFailWithError:(NSError *)error;
@optional
- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)viewController didFindMatch:(GKTurnBasedMatch *)match
    API_DEPRECATED("use GKTurnBasedEventListener's player:receivedTurnEventForMatch:didBecomeActive:", ios(5.0, 9.0));
@end
@interface GKTurnBasedMatchmakerViewController : UIViewController
- (instancetype)initWithMatchRequest:(GKMatchRequest *)request;
@property (nonatomic, weak, nullable) id<GKTurnBasedMatchmakerViewControllerDelegate> turnBasedMatchmakerDelegate;
@property (nonatomic) BOOL showExistingMatches;
@property (nonatomic) GKMatchmakingMode matchmakingMode;
@end
NS_ASSUME_NONNULL_END
#endif
