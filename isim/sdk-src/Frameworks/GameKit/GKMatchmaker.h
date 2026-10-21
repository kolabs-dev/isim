#pragma once
/* isim GameKit: match requests, invites and the matchmaker (players are the other isim devices on this computer). */
#import <GameKit/GKPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKMatch;
typedef NS_ENUM(NSUInteger, GKMatchType) { GKMatchTypePeerToPeer = 0, GKMatchTypeHosted, GKMatchTypeTurnBased };
typedef NS_ENUM(NSInteger, GKInviteRecipientResponse) {
    GKInviteRecipientResponseAccepted = 0, GKInviteRecipientResponseDeclined = 1, GKInviteRecipientResponseFailed = 2,
    GKInviteRecipientResponseIncompatible = 3, GKInviteRecipientResponseUnableToConnect = 4, GKInviteRecipientResponseNoAnswer = 5
};
@interface GKMatchRequest : NSObject
@property (nonatomic) NSUInteger minPlayers;
@property (nonatomic) NSUInteger maxPlayers;
@property (nonatomic) NSUInteger defaultNumberOfPlayers;
@property (nonatomic) NSUInteger playerGroup;
@property (nonatomic) uint32_t playerAttributes;
@property (nonatomic, copy, nullable) NSString *inviteMessage;
@property (nonatomic, retain, nullable) NSArray<GKPlayer *> *recipients;
@property (nonatomic, copy, nullable) NSString *queueName;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *properties;
@property (nonatomic, copy, nullable) NSDictionary<GKPlayer *, NSDictionary<NSString *, id> *> *recipientProperties;
@property (nonatomic) BOOL restrictToAutomatch;
@property (nonatomic, copy, nullable) void (^recipientResponseHandler)(GKPlayer *player, GKInviteRecipientResponse response);
+ (NSUInteger)maxPlayersAllowedForMatchOfType:(GKMatchType)matchType;
@end
@interface GKInvite : NSObject
@property (nonatomic, readonly) GKPlayer *sender;
@property (nonatomic, readonly, getter=isHosted) BOOL hosted;
@property (nonatomic, readonly) NSUInteger playerGroup;
@property (nonatomic, readonly) uint32_t playerAttributes;
@end
@interface GKMatchmaker : NSObject
+ (GKMatchmaker *)sharedMatchmaker;
- (void)matchForInvite:(GKInvite *)invite completionHandler:(void (^ _Nullable)(GKMatch * _Nullable match, NSError * _Nullable error))completionHandler;
- (void)findMatchForRequest:(GKMatchRequest *)request withCompletionHandler:(void (^ _Nullable)(GKMatch * _Nullable match, NSError * _Nullable error))completionHandler;
- (void)findPlayersForHostedRequest:(GKMatchRequest *)request
              withCompletionHandler:(void (^ _Nullable)(NSArray<GKPlayer *> * _Nullable players, NSError * _Nullable error))completionHandler;
- (void)addPlayersToMatch:(GKMatch *)match matchRequest:(GKMatchRequest *)matchRequest completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)cancel;
- (void)cancelPendingInviteToPlayer:(GKPlayer *)player;
- (void)finishMatchmakingForMatch:(GKMatch *)match;
- (void)queryPlayerGroupActivity:(NSUInteger)playerGroup withCompletionHandler:(void (^ _Nullable)(NSInteger activity, NSError * _Nullable error))completionHandler;
- (void)queryActivityWithCompletionHandler:(void (^ _Nullable)(NSInteger activity, NSError * _Nullable error))completionHandler;
- (void)startBrowsingForNearbyPlayersWithHandler:(void (^ _Nullable)(GKPlayer *player, BOOL reachable))reachableHandler;
- (void)stopBrowsingForNearbyPlayers;
@end
NS_ASSUME_NONNULL_END
#endif
