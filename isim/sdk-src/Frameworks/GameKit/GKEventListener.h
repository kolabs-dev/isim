#pragma once
/* isim GameKit: the local player's listener protocols (one Swift protocol, GKLocalPlayerListener, on isim; an
 * Objective-C listener is wrapped when it is registered). */
#import <GameKit/GKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKPlayer, GKSavedGame, GKInvite, GKTurnBasedMatch, GKTurnBasedExchange, GKTurnBasedExchangeReply, GKChallenge, GKGameActivity;
@protocol GKSavedGameListener <NSObject>
@optional
- (void)player:(GKPlayer *)player didModifySavedGame:(GKSavedGame *)savedGame;
- (void)player:(GKPlayer *)player hasConflictingSavedGames:(NSArray<GKSavedGame *> *)savedGames;
@end
@protocol GKInviteEventListener <NSObject>
@optional
- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite;
- (void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray<GKPlayer *> *)recipientPlayers;
@end
@protocol GKTurnBasedEventListener <NSObject>
@optional
- (void)player:(GKPlayer *)player didRequestMatchWithOtherPlayers:(NSArray<GKPlayer *> *)playersToInvite;
- (void)player:(GKPlayer *)player receivedTurnEventForMatch:(GKTurnBasedMatch *)match didBecomeActive:(BOOL)didBecomeActive;
- (void)player:(GKPlayer *)player matchEnded:(GKTurnBasedMatch *)match;
- (void)player:(GKPlayer *)player receivedExchangeRequest:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match;
- (void)player:(GKPlayer *)player receivedExchangeCancellation:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match;
- (void)player:(GKPlayer *)player receivedExchangeReplies:(NSArray<GKTurnBasedExchangeReply *> *)replies
    forCompletedExchange:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match;
- (void)player:(GKPlayer *)player wantsToQuitMatch:(GKTurnBasedMatch *)match;
@end
@protocol GKChallengeListener <NSObject>
@optional
- (void)player:(GKPlayer *)player wantsToPlayChallenge:(GKChallenge *)challenge;
- (void)player:(GKPlayer *)player didReceiveChallenge:(GKChallenge *)challenge;
- (void)player:(GKPlayer *)player didCompleteChallenge:(GKChallenge *)challenge issuedByFriend:(GKPlayer *)friendPlayer;
- (void)player:(GKPlayer *)player issuedChallengeWasCompleted:(GKChallenge *)challenge byFriend:(GKPlayer *)friendPlayer;
@end
@protocol GKGameActivityListener <NSObject>
@optional
- (void)player:(GKPlayer *)player wantsToPlayGameActivity:(GKGameActivity *)activity completionHandler:(void (^)(BOOL handled))completionHandler
    API_AVAILABLE(ios(26.0));
@end
@protocol GKLocalPlayerListener <GKChallengeListener, GKInviteEventListener, GKSavedGameListener, GKTurnBasedEventListener, GKGameActivityListener>
@end
NS_ASSUME_NONNULL_END
#endif
