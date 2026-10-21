#pragma once
/* isim GameKit: turn-based matches, their participants and exchanges (kept on isim's local Game Center network). */
#import <GameKit/GKMatchmaker.h>
#import <GameKit/GKLeaderboard.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GKTurnBasedParticipantStatus) {
    GKTurnBasedParticipantStatusUnknown = 0, GKTurnBasedParticipantStatusInvited, GKTurnBasedParticipantStatusDeclined,
    GKTurnBasedParticipantStatusMatching, GKTurnBasedParticipantStatusActive, GKTurnBasedParticipantStatusDone
};
typedef NS_ENUM(NSInteger, GKTurnBasedMatchStatus) {
    GKTurnBasedMatchStatusUnknown = 0, GKTurnBasedMatchStatusOpen = 1, GKTurnBasedMatchStatusEnded = 2, GKTurnBasedMatchStatusMatching = 3
};
typedef NS_ENUM(NSInteger, GKTurnBasedMatchOutcome) {
    GKTurnBasedMatchOutcomeNone = 0, GKTurnBasedMatchOutcomeQuit = 1, GKTurnBasedMatchOutcomeWon = 2, GKTurnBasedMatchOutcomeLost = 3,
    GKTurnBasedMatchOutcomeTied = 4, GKTurnBasedMatchOutcomeTimeExpired = 5, GKTurnBasedMatchOutcomeFirst = 6, GKTurnBasedMatchOutcomeSecond = 7,
    GKTurnBasedMatchOutcomeThird = 8, GKTurnBasedMatchOutcomeFourth = 9, GKTurnBasedMatchOutcomeCustomRange = 0x00FF0000
};
typedef NS_ENUM(int8_t, GKTurnBasedExchangeStatus) {
    GKTurnBasedExchangeStatusUnknown = 0, GKTurnBasedExchangeStatusActive = 1, GKTurnBasedExchangeStatusComplete = 2,
    GKTurnBasedExchangeStatusResolved = 3, GKTurnBasedExchangeStatusCanceled = 4
};
GK_EXTERN NSTimeInterval GKTurnTimeoutDefault;
GK_EXTERN NSTimeInterval GKTurnTimeoutNone;
GK_EXTERN NSTimeInterval GKExchangeTimeoutDefault;
GK_EXTERN NSTimeInterval GKExchangeTimeoutNone;
@class GKTurnBasedExchange, GKTurnBasedExchangeReply;
@interface GKTurnBasedParticipant : NSObject
@property (nonatomic, readonly, nullable) GKPlayer *player;
@property (nonatomic, readonly, nullable) NSDate *lastTurnDate;
@property (nonatomic, readonly) GKTurnBasedParticipantStatus status;
@property (nonatomic) GKTurnBasedMatchOutcome matchOutcome;
@property (nonatomic, readonly, nullable) NSDate *timeoutDate;
@end
@interface GKTurnBasedMatch : NSObject
@property (nonatomic, readonly, nullable) NSString *matchID;
@property (nonatomic, readonly, nullable) NSDate *creationDate;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedParticipant *> *participants;
@property (nonatomic, readonly) GKTurnBasedMatchStatus status;
@property (nonatomic, readonly, nullable) GKTurnBasedParticipant *currentParticipant;
@property (nonatomic, readonly, nullable) NSData *matchData;
@property (nonatomic, readonly) NSUInteger matchDataMaximumSize;
@property (nonatomic, copy, nullable) NSString *message;
- (void)setLocalizableMessageWithKey:(NSString *)key arguments:(nullable NSArray<NSString *> *)arguments;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedExchange *> *exchanges;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedExchange *> *activeExchanges;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedExchange *> *completedExchanges;
@property (nonatomic, readonly) NSUInteger exchangeDataMaximumSize;
@property (nonatomic, readonly) NSUInteger exchangeMaxInitiatedExchangesPerPlayer;
+ (void)findMatchForRequest:(GKMatchRequest *)request withCompletionHandler:(void (^)(GKTurnBasedMatch * _Nullable match, NSError * _Nullable error))completionHandler;
+ (void)loadMatchesWithCompletionHandler:(void (^ _Nullable)(NSArray<GKTurnBasedMatch *> * _Nullable matches, NSError * _Nullable error))completionHandler;
+ (void)loadMatchWithID:(NSString *)matchID withCompletionHandler:(void (^ _Nullable)(GKTurnBasedMatch * _Nullable match, NSError * _Nullable error))completionHandler;
- (void)rematchWithCompletionHandler:(void (^ _Nullable)(GKTurnBasedMatch * _Nullable match, NSError * _Nullable error))completionHandler;
- (void)acceptInviteWithCompletionHandler:(void (^ _Nullable)(GKTurnBasedMatch * _Nullable match, NSError * _Nullable error))completionHandler;
- (void)declineInviteWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)removeWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)loadMatchDataWithCompletionHandler:(void (^ _Nullable)(NSData * _Nullable matchData, NSError * _Nullable error))completionHandler;
- (void)endTurnWithNextParticipants:(NSArray<GKTurnBasedParticipant *> *)nextParticipants turnTimeout:(NSTimeInterval)timeout
                          matchData:(NSData *)matchData completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)participantQuitInTurnWithOutcome:(GKTurnBasedMatchOutcome)matchOutcome nextParticipants:(NSArray<GKTurnBasedParticipant *> *)nextParticipants
                             turnTimeout:(NSTimeInterval)timeout matchData:(NSData *)matchData
                       completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)participantQuitOutOfTurnWithOutcome:(GKTurnBasedMatchOutcome)matchOutcome
                      withCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)endMatchInTurnWithMatchData:(NSData *)matchData completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)endMatchInTurnWithMatchData:(NSData *)matchData leaderboardScores:(NSArray<GKLeaderboardScore *> *)scores achievements:(NSArray *)achievements
                  completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)saveCurrentTurnWithMatchData:(NSData *)matchData completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)saveMergedMatchData:(NSData *)matchData withResolvedExchanges:(NSArray<GKTurnBasedExchange *> *)exchanges
          completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)sendExchangeToParticipants:(NSArray<GKTurnBasedParticipant *> *)participants data:(NSData *)data localizableMessageKey:(NSString *)key
                         arguments:(NSArray<NSString *> *)arguments timeout:(NSTimeInterval)timeout
                 completionHandler:(void (^ _Nullable)(GKTurnBasedExchange * _Nullable exchange, NSError * _Nullable error))completionHandler;
@end
@interface GKTurnBasedExchange : NSObject
@property (nonatomic, readonly, nullable) NSString *exchangeID;
@property (nonatomic, readonly, nullable) GKTurnBasedParticipant *sender;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedParticipant *> *recipients;
@property (nonatomic, readonly) GKTurnBasedExchangeStatus status;
@property (nonatomic, readonly, nullable) NSString *message;
@property (nonatomic, readonly, nullable) NSData *data;
@property (nonatomic, readonly, nullable) NSDate *sendDate;
@property (nonatomic, readonly, nullable) NSDate *timeoutDate;
@property (nonatomic, readonly, nullable) NSDate *completionDate;
@property (nonatomic, readonly, nullable) NSArray<GKTurnBasedExchangeReply *> *replies;
- (void)cancelWithLocalizableMessageKey:(NSString *)key arguments:(NSArray<NSString *> *)arguments
                      completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)replyWithLocalizableMessageKey:(NSString *)key arguments:(NSArray<NSString *> *)arguments data:(NSData *)data
                     completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
@end
@interface GKTurnBasedExchangeReply : NSObject
@property (nonatomic, readonly, nullable) GKTurnBasedParticipant *recipient;
@property (nonatomic, readonly, nullable) NSString *message;
@property (nonatomic, readonly, nullable) NSData *data;
@property (nonatomic, readonly, nullable) NSDate *replyDate;
@end
NS_ASSUME_NONNULL_END
#endif
