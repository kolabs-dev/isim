#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDictionary, NSSet, NSURL, NSDate, NSError;
/* isim: activities are delivered to the app (universal links, NSUserActivityTypeBrowsingWeb); Handoff,
   Spotlight indexing and predictions are accepted and ignored. */
FOUNDATION_EXPORT NSString * const NSUserActivityTypeBrowsingWeb;
typedef NSString *NSUserActivityPersistentIdentifier;
@protocol NSUserActivityDelegate;
@interface NSUserActivity : NSObject
- (instancetype)initWithActivityType:(NSString *)activityType NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
@property (readonly, copy) NSString *activityType;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSDictionary *userInfo;
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)otherDictionary;
@property (nullable, copy) NSSet<NSString *> *requiredUserInfoKeys;
@property (assign) BOOL needsSave;
@property (nullable, copy) NSURL *webpageURL;
@property (nullable, copy) NSURL *referrerURL;
@property (nullable, copy) NSDate *expirationDate;
@property (copy) NSSet<NSString *> *keywords;
@property BOOL supportsContinuationStreams;
@property (nullable, weak) id<NSUserActivityDelegate> delegate;
@property (nullable, copy) NSString *targetContentIdentifier;
@property (getter=isEligibleForHandoff) BOOL eligibleForHandoff;
@property (getter=isEligibleForSearch) BOOL eligibleForSearch;
@property (getter=isEligibleForPublicIndexing) BOOL eligibleForPublicIndexing;
@property (getter=isEligibleForPrediction) BOOL eligibleForPrediction;
@property (copy, nullable) NSUserActivityPersistentIdentifier persistentIdentifier;
- (void)becomeCurrent;
- (void)resignCurrent;
- (void)invalidate;
@end
@protocol NSUserActivityDelegate <NSObject>
@optional
- (void)userActivityWillSave:(NSUserActivity *)userActivity;
- (void)userActivityWasContinued:(NSUserActivity *)userActivity;
@end
NS_ASSUME_NONNULL_END
