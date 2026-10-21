#pragma once
/* isim GameKit: game activities and their definitions (iOS 26; from the app's isim-GameCenter.json). */
#import <GameKit/GKLeaderboard.h>
#import <GameKit/GKAchievement.h>
#import <GameKit/GKMatchmaker.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKMatch;
typedef NS_ENUM(NSInteger, GKGameActivityPlayStyle) {
    GKGameActivityPlayStyleUnspecified = 0, GKGameActivityPlayStyleSynchronous = 1, GKGameActivityPlayStyleAsynchronous = 2
} API_AVAILABLE(ios(26.0));
typedef NS_OPTIONS(NSUInteger, GKGameActivityState) {
    GKGameActivityStateInitialized = 0, GKGameActivityStateActive = 1, GKGameActivityStatePaused = 2, GKGameActivityStateEnded = 4
} API_AVAILABLE(ios(26.0));
API_AVAILABLE(ios(26.0))
@interface GKGameActivityDefinition : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly, nullable) NSString *groupIdentifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly, nullable) NSString *details;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *defaultProperties;
@property (nonatomic, readonly, nullable) NSURL *fallbackURL;
@property (nonatomic, readonly) BOOL supportsPartyCode;
@property (nonatomic, readonly, nullable) NSNumber *maxPlayers;
@property (nonatomic, readonly, nullable) NSNumber *minPlayers;
@property (nonatomic, readonly) BOOL supportsUnlimitedPlayers;
@property (nonatomic, readonly) GKGameActivityPlayStyle playStyle;
+ (void)loadGameActivityDefinitionsWithCompletionHandler:(void (^)(NSArray<GKGameActivityDefinition *> * _Nullable activityDefinitions, NSError * _Nullable error))completionHandler;
+ (void)loadGameActivityDefinitionsWithIDs:(nullable NSArray<NSString *> *)activityDefinitionIDs
                         completionHandler:(void (^)(NSArray<GKGameActivityDefinition *> * _Nullable activityDefinitions, NSError * _Nullable error))completionHandler;
- (void)loadAchievementDescriptionsWithCompletionHandler:(void (^)(NSArray<GKAchievementDescription *> * _Nullable descriptions, NSError * _Nullable error))completionHandler;
- (void)loadLeaderboardsWithCompletionHandler:(void (^)(NSArray<GKLeaderboard *> * _Nullable leaderboards, NSError * _Nullable error))completionHandler;
- (void)loadImageWithCompletionHandler:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
@end
API_AVAILABLE(ios(26.0))
@interface GKGameActivity : NSObject
@property (class, nonatomic, readonly) NSArray<NSString *> *validPartyCodeAlphabet;
+ (BOOL)isValidPartyCode:(NSString *)partyCode;
+ (nullable GKGameActivity *)startWithDefinition:(GKGameActivityDefinition *)activityDefinition error:(NSError **)error;
+ (nullable GKGameActivity *)startWithDefinition:(GKGameActivityDefinition *)activityDefinition partyCode:(NSString *)partyCode error:(NSError **)error;
+ (void)checkPendingGameActivityExistenceWithCompletionHandler:(void (^)(BOOL exists))completionHandler;
- (instancetype)initWithDefinition:(GKGameActivityDefinition *)activityDefinition;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) GKGameActivityDefinition *activityDefinition;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *properties;
@property (nonatomic, readonly) GKGameActivityState state;
@property (nonatomic, readonly, nullable) NSString *partyCode;
@property (nonatomic, readonly, nullable) NSURL *partyURL;
@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, readonly, nullable) NSDate *startDate;
@property (nonatomic, readonly, nullable) NSDate *lastResumeDate;
@property (nonatomic, readonly, nullable) NSDate *endDate;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, nullable) NSSet<GKAchievement *> *achievements;
@property (nonatomic, readonly, nullable) NSSet<GKLeaderboardScore *> *leaderboardScores;
- (void)start;
- (void)pause;
- (void)resume;
- (void)end;
- (void)setScoreOnLeaderboard:(GKLeaderboard *)leaderboard toScore:(NSInteger)score context:(NSUInteger)context;
- (void)setScoreOnLeaderboard:(GKLeaderboard *)leaderboard toScore:(NSInteger)score;
- (nullable GKLeaderboardScore *)scoreOnLeaderboard:(GKLeaderboard *)leaderboard;
- (void)removeScoresFromLeaderboards:(NSArray<GKLeaderboard *> *)leaderboards;
- (void)setProgressOnAchievement:(GKAchievement *)achievement toPercentComplete:(double)percentComplete;
- (void)setAchievementCompleted:(GKAchievement *)achievement;
- (double)progressOnAchievement:(GKAchievement *)achievement;
- (void)removeAchievements:(NSArray<GKAchievement *> *)achievements;
- (GKMatchRequest *)makeMatchRequest;
- (void)findMatchWithCompletionHandler:(void (^)(GKMatch * _Nullable match, NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
