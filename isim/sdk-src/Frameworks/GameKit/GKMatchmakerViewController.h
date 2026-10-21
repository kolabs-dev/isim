#pragma once
/* isim GameKit: the matchmaking sheet. On isim GameKit's view controllers are UIViewControllers that host their
 * content (UINavigationControllers on iOS). */
#import <GameKit/GKMatchmaker.h>
#import <GameKit/GKMatch.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKMatchmakerViewController;
typedef NS_ENUM(NSInteger, GKMatchmakingMode) {
    GKMatchmakingModeDefault = 0, GKMatchmakingModeNearbyOnly = 1, GKMatchmakingModeAutomatchOnly = 2, GKMatchmakingModeInviteOnly = 3
};
@protocol GKMatchmakerViewControllerDelegate <NSObject>
@required
- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController;
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error;
@optional
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match;
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindHostedPlayers:(NSArray<GKPlayer *> *)players;
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController hostedPlayerDidAccept:(GKPlayer *)player;
@end
@interface GKMatchmakerViewController : UIViewController
- (nullable instancetype)initWithMatchRequest:(GKMatchRequest *)request;
- (nullable instancetype)initWithInvite:(GKInvite *)invite;
@property (nonatomic, weak, nullable) id<GKMatchmakerViewControllerDelegate> matchmakerDelegate;
@property (nonatomic, readonly) GKMatchRequest *matchRequest;
@property (nonatomic, getter=isHosted) BOOL hosted;
@property (nonatomic) GKMatchmakingMode matchmakingMode;
@property (nonatomic) BOOL canStartWithMinimumPlayers;
- (void)addPlayersToMatch:(GKMatch *)match;
- (void)setHostedPlayer:(GKPlayer *)player didConnect:(BOOL)connected;
@end
NS_ASSUME_NONNULL_END
#endif
