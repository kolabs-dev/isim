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
NS_ASSUME_NONNULL_END
#endif
