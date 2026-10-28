#pragma once
/* isim GameKit: GKLocalPlayer (the device's player: isim Settings > Game Center), friends and saved games. */
#import <GameKit/GKPlayer.h>
#import <GameKit/GKEventListener.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GKFriendsAuthorizationStatus) {
    GKFriendsAuthorizationStatusNotDetermined = 0, GKFriendsAuthorizationStatusRestricted, GKFriendsAuthorizationStatusDenied,
    GKFriendsAuthorizationStatusAuthorized
};
@interface GKLocalPlayer : GKPlayer
@property (class, nonatomic, readonly) GKLocalPlayer *local;
+ (GKLocalPlayer *)localPlayer;
@property (nonatomic, readonly, getter=isAuthenticated) BOOL authenticated;
@property (nonatomic, readonly) BOOL isPresentingFriendRequestViewController;
/* identity verification (adapted: an ECDSA P-256 signature; the URL is a file URL of the device key's certificate) */
- (void)fetchItemsForIdentityVerificationSignature:(void (^ _Nullable)(NSURL * _Nullable publicKeyURL, NSData * _Nullable signature, NSData * _Nullable salt,
                                                                      uint64_t timestamp, NSError * _Nullable error))completionHandler;
- (void)loadDefaultLeaderboardIdentifierWithCompletionHandler:(void (^ _Nullable)(NSString * _Nullable leaderboardIdentifier, NSError * _Nullable error))completionHandler;
- (void)setDefaultLeaderboardIdentifier:(NSString *)leaderboardIdentifier completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
@property (nonatomic, readonly, getter=isUnderage) BOOL underage;
@property (nonatomic, readonly, getter=isMultiplayerGamingRestricted) BOOL multiplayerGamingRestricted;
@property (nonatomic, readonly, getter=isPersonalizedCommunicationRestricted) BOOL personalizedCommunicationRestricted;
@property (nonatomic, copy, nullable) void (^authenticateHandler)(UIViewController * _Nullable viewController, NSError * _Nullable error);
- (void)loadFriendsAuthorizationStatus:(void (^)(GKFriendsAuthorizationStatus authorizationStatus, NSError * _Nullable error))completionHandler;
- (void)loadFriends:(void (^)(NSArray<GKPlayer *> * _Nullable friends, NSError * _Nullable error))completionHandler;
- (void)loadFriendsIdentifiedByGamePlayerIDs:(NSArray<NSString *> *)identifiers
                           completionHandler:(void (^)(NSArray<GKPlayer *> * _Nullable friends, NSError * _Nullable error))completionHandler;
- (void)loadRecentPlayersWithCompletionHandler:(void (^ _Nullable)(NSArray<GKPlayer *> * _Nullable recentPlayers, NSError * _Nullable error))completionHandler;
- (void)loadChallengableFriendsWithCompletionHandler:(void (^ _Nullable)(NSArray<GKPlayer *> * _Nullable friends, NSError * _Nullable error))completionHandler;
- (BOOL)presentFriendRequestCreatorFromViewController:(UIViewController *)viewController error:(NSError **)error;
- (void)registerListener:(id<GKLocalPlayerListener>)listener;
- (void)unregisterListener:(id<GKLocalPlayerListener>)listener;
- (void)unregisterAllListeners;
@end
NS_ASSUME_NONNULL_END
#endif
