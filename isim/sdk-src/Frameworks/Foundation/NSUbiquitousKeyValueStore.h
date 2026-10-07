#pragma once
/* isim (self-authored): iCloud key-value storage, app group and ubiquity containers, NSNotificationQueue.
 * Local simulation: no iCloud. The key-value store and "iCloud Drive" containers live in the device data
 * ($ISIM_DATA/Mobile Documents); the simulated iCloud account is signed in unless ISIM_ICLOUD=noAccount. */
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSRunLoop.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray, NSDictionary<KeyType, ObjectType>, NSData, NSURL;

@interface NSFileManager (IsimContainers)
/* app group container: $ISIM_DATA/Shared/AppGroup/<group> (shared by every app using the group; entitlements are
 * not checked, like the Simulator) */
- (nullable NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
/* nil when the simulated iCloud account is signed out (ISIM_ICLOUD=noAccount) */
- (nullable NSURL *)URLForUbiquityContainerIdentifier:(nullable NSString *)containerIdentifier;
@property (nullable, readonly, copy) id<NSObject, NSCopying, NSCoding> ubiquityIdentityToken;
@end
FOUNDATION_EXPORT NSNotificationName const NSUbiquityIdentityDidChangeNotification;

@interface NSUbiquitousKeyValueStore : NSObject
@property (class, readonly, strong) NSUbiquitousKeyValueStore *defaultStore NS_SWIFT_NAME(default);
- (nullable id)objectForKey:(NSString *)aKey;
- (void)setObject:(nullable id)anObject forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)removeObjectForKey:(NSString *)aKey;
- (nullable NSString *)stringForKey:(NSString *)aKey;
- (nullable NSArray *)arrayForKey:(NSString *)aKey;
- (nullable NSDictionary<NSString *, id> *)dictionaryForKey:(NSString *)aKey;
- (nullable NSData *)dataForKey:(NSString *)aKey;
- (long long)longLongForKey:(NSString *)aKey;
- (double)doubleForKey:(NSString *)aKey;
- (BOOL)boolForKey:(NSString *)aKey;
- (void)setString:(nullable NSString *)aString forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setData:(nullable NSData *)aData forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setArray:(nullable NSArray *)anArray forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setDictionary:(nullable NSDictionary<NSString *, id> *)aDictionary forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setLongLong:(long long)value forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setDouble:(double)value forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
- (void)setBool:(BOOL)value forKey:(NSString *)aKey NS_SWIFT_NAME(set(_:forKey:));
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryRepresentation;
- (BOOL)synchronize;
@end
FOUNDATION_EXPORT NSNotificationName const NSUbiquitousKeyValueStoreDidChangeExternallyNotification NS_SWIFT_NAME(NSUbiquitousKeyValueStore.didChangeExternallyNotification);
FOUNDATION_EXPORT NSString * const NSUbiquitousKeyValueStoreChangeReasonKey;
FOUNDATION_EXPORT NSString * const NSUbiquitousKeyValueStoreChangedKeysKey;
enum {
    NSUbiquitousKeyValueStoreServerChange = 0,
    NSUbiquitousKeyValueStoreInitialSyncChange = 1,
    NSUbiquitousKeyValueStoreQuotaViolationChange = 2,
    NSUbiquitousKeyValueStoreAccountChange = 3
};

typedef NS_ENUM(NSUInteger, NSPostingStyle) {
    NSPostWhenIdle NS_SWIFT_NAME(whenIdle) = 1,
    NSPostASAP NS_SWIFT_NAME(asap) = 2,
    NSPostNow NS_SWIFT_NAME(now) = 3
} NS_SWIFT_NAME(NotificationQueue.PostingStyle);
typedef NS_OPTIONS(NSUInteger, NSNotificationCoalescing) {
    NSNotificationNoCoalescing NS_SWIFT_NAME(none) = 0,
    NSNotificationCoalescingOnName NS_SWIFT_NAME(onName) = 1,
    NSNotificationCoalescingOnSender NS_SWIFT_NAME(onSender) = 2
} NS_SWIFT_NAME(NotificationQueue.NotificationCoalescing);
NS_SWIFT_NAME(NotificationQueue)
@interface NSNotificationQueue : NSObject
@property (class, readonly, strong) NSNotificationQueue *defaultQueue NS_SWIFT_NAME(default);
- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter NS_DESIGNATED_INITIALIZER;
- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle NS_SWIFT_NAME(enqueue(_:postingStyle:));
- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle coalesceMask:(NSNotificationCoalescing)coalesceMask forModes:(nullable NSArray<NSRunLoopMode> *)modes NS_SWIFT_NAME(enqueue(_:postingStyle:coalesceMask:forModes:));
- (void)dequeueNotificationsMatching:(NSNotification *)notification coalesceMask:(NSUInteger)coalesceMask NS_SWIFT_NAME(dequeueNotifications(matching:coalesceMask:));
@end
NS_ASSUME_NONNULL_END
