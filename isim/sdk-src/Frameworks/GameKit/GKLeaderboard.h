#pragma once
/* isim GameKit: leaderboards, their entries and scores (every player's best score on isim's local Game Center). */
#import <GameKit/GKPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GKLeaderboardTimeScope) { GKLeaderboardTimeScopeToday = 0, GKLeaderboardTimeScopeWeek, GKLeaderboardTimeScopeAllTime };
typedef NS_ENUM(NSInteger, GKLeaderboardPlayerScope) { GKLeaderboardPlayerScopeGlobal = 0, GKLeaderboardPlayerScopeFriendsOnly };
typedef NS_ENUM(NSInteger, GKLeaderboardType) { GKLeaderboardTypeClassic = 0, GKLeaderboardTypeRecurring };
@interface GKLeaderboardEntry : NSObject
@property (nonatomic, readonly) GKPlayer *player;
@property (nonatomic, readonly) NSInteger rank;
@property (nonatomic, readonly) NSInteger score;
@property (nonatomic, readonly) NSString *formattedScore;
@property (nonatomic, readonly) NSUInteger context;
@property (nonatomic, readonly) NSDate *date;
- (UIViewController *)challengeComposeControllerWithMessage:(nullable NSString *)message players:(nullable NSArray<GKPlayer *> *)players
    completion:(void (^ _Nullable)(UIViewController *composeController, BOOL didIssueChallenge, NSArray<GKPlayer *> * _Nullable sentPlayers))completionHandler;
@end
@interface GKLeaderboard : NSObject
@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly, nullable) NSString *groupIdentifier;
@property (nonatomic, readonly) NSString *baseLeaderboardID;
@property (nonatomic, readonly) GKLeaderboardType type;
@property (nonatomic, readonly, nullable) NSDate *startDate;
@property (nonatomic, readonly, nullable) NSDate *nextStartDate;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSString *leaderboardDescription;
@property (nonatomic, readonly) BOOL isHidden;
@property (nonatomic, readonly) GKReleaseState releaseState;
@property (nonatomic, readonly) NSString *activityIdentifier;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *activityProperties;
+ (void)loadLeaderboardsWithIDs:(nullable NSArray<NSString *> *)leaderboardIDs
              completionHandler:(void (^)(NSArray<GKLeaderboard *> * _Nullable leaderboards, NSError * _Nullable error))completionHandler;
- (void)loadPreviousOccurrenceWithCompletionHandler:(void (^)(GKLeaderboard * _Nullable leaderboard, NSError * _Nullable error))completionHandler;
+ (void)submitScore:(NSInteger)score context:(NSUInteger)context player:(GKPlayer *)player leaderboardIDs:(NSArray<NSString *> *)leaderboardIDs
  completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)submitScore:(NSInteger)score context:(NSUInteger)context player:(GKPlayer *)player completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)loadEntriesForPlayerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range
                completionHandler:(void (^)(GKLeaderboardEntry * _Nullable localPlayerEntry, NSArray<GKLeaderboardEntry *> * _Nullable entries,
                                            NSInteger totalPlayerCount, NSError * _Nullable error))completionHandler;
- (void)loadEntriesForPlayers:(NSArray<GKPlayer *> *)players timeScope:(GKLeaderboardTimeScope)timeScope
            completionHandler:(void (^)(GKLeaderboardEntry * _Nullable localPlayerEntry, NSArray<GKLeaderboardEntry *> * _Nullable entries,
                                        NSError * _Nullable error))completionHandler;
- (void)loadImageWithCompletionHandler:(void (^ _Nullable)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
@end
@interface GKLeaderboardScore : NSObject
@property (nonatomic, strong) GKPlayer *player;
@property (nonatomic) NSInteger value;
@property (nonatomic) NSUInteger context;
@property (nonatomic, copy) NSString *leaderboardID;
@end
@interface GKLeaderboardSet : NSObject
@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly, nullable) NSString *groupIdentifier;
@property (nonatomic, copy, nullable) NSString *identifier;
+ (void)loadLeaderboardSetsWithCompletionHandler:(void (^ _Nullable)(NSArray<GKLeaderboardSet *> * _Nullable leaderboardSets, NSError * _Nullable error))completionHandler;
- (void)loadLeaderboardsWithHandler:(void (^)(NSArray<GKLeaderboard *> * _Nullable leaderboards, NSError * _Nullable error))handler;
- (void)loadImageWithCompletionHandler:(void (^ _Nullable)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
