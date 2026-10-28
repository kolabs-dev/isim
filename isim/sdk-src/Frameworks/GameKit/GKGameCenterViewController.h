#pragma once
/* isim GameKit: the Game Center dashboard (leaderboards, achievements, the player's profile) and the access point. */
#import <GameKit/GKLeaderboard.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKGameCenterViewController;
typedef NS_ENUM(NSInteger, GKGameCenterViewControllerState) {
    GKGameCenterViewControllerStateDefault = -1, GKGameCenterViewControllerStateLeaderboards = 0, GKGameCenterViewControllerStateAchievements = 1,
    GKGameCenterViewControllerStateChallenges = 2, GKGameCenterViewControllerStateLocalPlayerProfile = 3,
    GKGameCenterViewControllerStateDashboard = 4, GKGameCenterViewControllerStateLocalPlayerFriendsList = 5
};
@protocol GKGameCenterControllerDelegate <NSObject>
- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController;
@end
@interface GKGameCenterViewController : UIViewController
- (instancetype)initWithState:(GKGameCenterViewControllerState)state;
- (instancetype)initWithLeaderboardID:(NSString *)leaderboardID playerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope;
- (instancetype)initWithAchievementID:(NSString *)achievementID;
- (instancetype)initWithLeaderboardSetID:(NSString *)leaderboardSetID;
- (instancetype)initWithPlayer:(GKPlayer *)player;
@property (nonatomic, weak, nullable) id<GKGameCenterControllerDelegate> gameCenterDelegate;
@property (nonatomic) GKGameCenterViewControllerState viewState;
@property (nonatomic, copy, nullable) NSString *leaderboardIdentifier;
@end
typedef NS_ENUM(NSInteger, GKAccessPointLocation) {
    GKAccessPointLocationTopLeading = 0, GKAccessPointLocationTopTrailing, GKAccessPointLocationBottomLeading, GKAccessPointLocationBottomTrailing
};
@interface GKAccessPoint : NSObject
@property (class, nonatomic, readonly) GKAccessPoint *shared;
@property (nonatomic, weak, nullable) UIWindow *parentWindow;
- (void)triggerForChallengesWithHandler:(void (^ _Nullable)(void))handler API_AVAILABLE(ios(26.0));
- (void)triggerForFriendingWithHandler:(void (^ _Nullable)(void))handler API_AVAILABLE(ios(26.0));
- (void)triggerForPlayTogetherWithHandler:(void (^ _Nullable)(void))handler API_AVAILABLE(ios(26.0));
- (void)triggerForArcadeWithHandler:(void (^ _Nullable)(void))handler API_AVAILABLE(ios(26.0));
@property (nonatomic, getter=isActive) BOOL active;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic, readonly) BOOL isPresentingGameCenter;
@property (nonatomic) BOOL showHighlights;
@property (nonatomic) GKAccessPointLocation location;
@property (nonatomic, readonly) CGRect frameInScreenCoordinates;
@property (nonatomic, getter=isFocused) BOOL focused;
- (void)triggerAccessPointWithHandler:(void (^)(void))handler;
- (void)triggerAccessPointWithState:(GKGameCenterViewControllerState)state handler:(void (^)(void))handler;
- (void)triggerAccessPointWithAchievementID:(NSString *)achievementID handler:(void (^)(void))handler API_AVAILABLE(ios(18.0));
- (void)triggerAccessPointWithLeaderboardID:(NSString *)leaderboardID playerScope:(GKLeaderboardPlayerScope)playerScope
                                  timeScope:(GKLeaderboardTimeScope)timeScope handler:(void (^)(void))handler API_AVAILABLE(ios(18.0));
@end
NS_ASSUME_NONNULL_END
#endif
