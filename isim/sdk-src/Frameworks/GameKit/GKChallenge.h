#pragma once
/* isim GameKit: challenges between players on isim's local Game Center. */
#import <GameKit/GKLeaderboard.h>
#import <GameKit/GKAchievement.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GKChallengeState) {
    GKChallengeStateInvalid = 0, GKChallengeStatePending = 1, GKChallengeStateCompleted = 2, GKChallengeStateDeclined = 3
};
@interface GKChallenge : NSObject
+ (void)loadReceivedChallengesWithCompletionHandler:(void (^ _Nullable)(NSArray<GKChallenge *> * _Nullable challenges, NSError * _Nullable error))completionHandler;
- (void)decline;
@property (nonatomic, readonly, nullable) GKPlayer *issuingPlayer;
@property (nonatomic, readonly, nullable) GKPlayer *receivingPlayer;
@property (nonatomic, readonly) GKChallengeState state;
@property (nonatomic, readonly) NSDate *issueDate;
@property (nonatomic, readonly, nullable) NSDate *completionDate;
@property (nonatomic, readonly, nullable) NSString *message;
@end
@interface GKScoreChallenge : GKChallenge
@property (nonatomic, readonly, nullable) GKLeaderboardEntry *leaderboardEntry;
@property (nonatomic, readonly, nullable) NSString *leaderboardID;
@end
@interface GKAchievementChallenge : GKChallenge
@property (nonatomic, readonly, nullable) GKAchievement *achievement;
@end
@class GKLeaderboard;
/* a challenge players can start from the Games app (iOS 26; isim-GameCenter.json "challenges") */
API_AVAILABLE(ios(26.0))
@interface GKChallengeDefinition : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly, nullable) NSString *groupIdentifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly, nullable) NSString *details;
@property (nonatomic, readonly) NSArray<NSDateComponents *> *durationOptions;
@property (nonatomic, readonly) BOOL isRepeatable;
@property (nonatomic, readonly, nullable) GKLeaderboard *leaderboard;
@property (nonatomic, readonly) GKReleaseState releaseState;
+ (void)loadChallengeDefinitionsWithCompletionHandler:(void (^)(NSArray<GKChallengeDefinition *> * _Nullable definitions, NSError * _Nullable error))completionHandler;
- (void)hasActiveChallengesWithCompletionHandler:(void (^)(BOOL hasActiveChallenges, NSError * _Nullable error))completionHandler;
- (void)loadImageWithCompletionHandler:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
