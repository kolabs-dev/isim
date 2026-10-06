#pragma once
/* isim Foundation: NSUserActivity (self-authored). Activities made current with isEligibleForSearch are indexed for
 * the home screen's Spotlight; continuing one (Spotlight, universal links, state restoration) is done by UIKit. */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSError.h>
NS_ASSUME_NONNULL_BEGIN
@class NSUserActivity, NSArray;
typedef NSString *NSUserActivityPersistentIdentifier;
FOUNDATION_EXPORT NSString * const NSUserActivityTypeBrowsingWeb;

@protocol NSUserActivityDelegate <NSObject>
@optional
- (void)userActivityWillSave:(NSUserActivity *)userActivity;
- (void)userActivityWasContinued:(NSUserActivity *)userActivity;
@end

@interface NSUserActivity : NSObject
- (instancetype)initWithActivityType:(NSString *)activityType NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
@property (readonly, copy) NSString *activityType;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSDictionary *userInfo;
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)otherDictionary;
@property (nullable, copy) NSSet<NSString *> *requiredUserInfoKeys;
@property BOOL needsSave;
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
/* isim: becomeCurrent indexes the activity for Spotlight when isEligibleForSearch; there is no Handoff (one device) */
- (void)becomeCurrent;
- (void)resignCurrent;
- (void)invalidate;
+ (void)deleteSavedUserActivitiesWithPersistentIdentifiers:(NSArray<NSUserActivityPersistentIdentifier> *)persistentIdentifiers completionHandler:(void (^)(void))handler;
+ (void)deleteAllSavedUserActivitiesWithCompletionHandler:(void (^)(void))handler;
/* isim-private: plist form (activity type, title, userInfo, URLs, ...) used to pass activities between processes */
- (NSDictionary *)_isim_plist;
+ (nullable instancetype)_isim_activityWithPlist:(NSDictionary *)plist;
@end
NS_ASSUME_NONNULL_END

#import <Foundation/NSFileManager.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSFileManager (NSAppGroupContainers)
/* isim: app groups share <isim data>/Shared/AppGroup/<identifier> (apps and their extensions on the device) */
- (nullable NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end
NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN
/* property-list files (XML) */
@interface NSDictionary (NSDictionaryPropertyListWriting)
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error;
@end
@interface NSArray (NSArrayPropertyListWriting)
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
