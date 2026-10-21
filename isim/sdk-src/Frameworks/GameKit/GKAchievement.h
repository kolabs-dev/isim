#pragma once
/* isim GameKit: achievements and their descriptions (titles and points from the app's isim-GameCenter.json). */
#import <GameKit/GKPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface GKAchievement : NSObject
+ (void)loadAchievementsWithCompletionHandler:(void (^ _Nullable)(NSArray<GKAchievement *> * _Nullable achievements, NSError * _Nullable error))completionHandler;
+ (void)resetAchievementsWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (instancetype)initWithIdentifier:(nullable NSString *)identifier;
+ (void)reportAchievements:(NSArray<GKAchievement *> *)achievements withCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic) double percentComplete;
@property (nonatomic, readonly, getter=isCompleted) BOOL completed;
@property (nonatomic, copy, readonly) NSDate *lastReportedDate;
@property (nonatomic) BOOL showsCompletionBanner;
- (UIViewController *)challengeComposeControllerWithMessage:(nullable NSString *)message players:(nullable NSArray<GKPlayer *> *)players
    completion:(void (^ _Nullable)(UIViewController *composeController, BOOL didIssueChallenge, NSArray<GKPlayer *> * _Nullable sentPlayers))completionHandler;
- (void)issueChallengeToPlayers:(nullable NSArray<GKPlayer *> *)players message:(nullable NSString *)message;
@end
@interface GKAchievementDescription : NSObject
+ (void)loadAchievementDescriptionsWithCompletionHandler:(void (^ _Nullable)(NSArray<GKAchievementDescription *> * _Nullable descriptions, NSError * _Nullable error))completionHandler;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly, nullable) NSString *groupIdentifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *achievedDescription;
@property (nonatomic, readonly) NSString *unachievedDescription;
@property (nonatomic, readonly) NSInteger maximumPoints;
@property (nonatomic, readonly, getter=isHidden) BOOL hidden;
@property (nonatomic, readonly, getter=isReplayable) BOOL replayable;
@property (nonatomic, readonly, nullable) NSNumber *rarityPercent;
- (void)loadImageWithCompletionHandler:(void (^ _Nullable)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
+ (UIImage *)incompleteAchievementImage;
+ (UIImage *)placeholderCompletedAchievementImage;
@end
NS_ASSUME_NONNULL_END
#endif
