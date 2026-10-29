// isim HomeKit (issue #416): simulated homes. The classes and protocols are the HomeKit Swift overlay's (@objc with
// Apple's names and selectors); the constants, the value enums (HMTypes.h, generated) and the generic
// HMCharacteristicWriteAction and HMCharacteristicEvent are HomeKit.framework's. Swift sees the constants and enums
// from here and the classes from the overlay.
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#ifndef HM_EXTERN
#define HM_EXTERN extern __attribute__((visibility("default")))
#endif

#import <HomeKit/HMTypes.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * HMSignificantEvent NS_TYPED_EXTENSIBLE_ENUM;
HM_EXTERN HMSignificantEvent const HMSignificantEventSunrise;
HM_EXTERN HMSignificantEvent const HMSignificantEventSunset;

typedef NS_OPTIONS(NSUInteger, HMHomeManagerAuthorizationStatus) {
    HMHomeManagerAuthorizationStatusDetermined = 1 << 0,
    HMHomeManagerAuthorizationStatusRestricted = 1 << 1,
    HMHomeManagerAuthorizationStatusAuthorized = 1 << 2,
};
typedef NS_ENUM(NSUInteger, HMHomeHubState) {
    HMHomeHubStateNotAvailable = 0,
    HMHomeHubStateConnected,
    HMHomeHubStateDisconnected,
};
typedef NS_ENUM(NSUInteger, HMCameraStreamState) {
    HMCameraStreamStateStarting = 1,
    HMCameraStreamStateStreaming = 2,
    HMCameraStreamStateStopping = 3,
    HMCameraStreamStateNotStreaming = 4,
};
typedef NS_ENUM(NSUInteger, HMCameraAudioStreamSetting) {
    HMCameraAudioStreamSettingMuted = 1,
    HMCameraAudioStreamSettingIncomingAudioAllowed = 2,
    HMCameraAudioStreamSettingBidirectionalAudioAllowed = 3,
};
typedef NS_ENUM(NSUInteger, HMEventTriggerActivationState) {
    HMEventTriggerActivationStateDisabled = 0,
    HMEventTriggerActivationStateDisabledNoHomeHub = 1,
    HMEventTriggerActivationStateDisabledNoCompatibleHomeHub = 2,
    HMEventTriggerActivationStateDisabledNoLocationServicesAuthorization = 3,
    HMEventTriggerActivationStateEnabled = 4,
};
typedef NS_ENUM(NSUInteger, HMPresenceEventType) {
    HMPresenceEventTypeEveryEntry = 1,
    HMPresenceEventTypeEveryExit = 2,
    HMPresenceEventTypeFirstEntry = 3,
    HMPresenceEventTypeLastExit = 4,
    HMPresenceEventTypeAtHome = HMPresenceEventTypeFirstEntry,
    HMPresenceEventTypeNotAtHome = HMPresenceEventTypeLastExit,
};
typedef NS_ENUM(NSUInteger, HMPresenceEventUserType) {
    HMPresenceEventUserTypeCurrentUser = 1,
    HMPresenceEventUserTypeHomeUsers = 2,
    HMPresenceEventUserTypeCustomUsers = 3,
};

#if !defined(__swift__)
typedef void (^HMErrorBlock)(NSError * _Nullable error);

@class HMHome, HMRoom, HMZone, HMServiceGroup, HMUser, HMAccessory, HMService, HMCharacteristic, HMActionSet, HMAction, HMTrigger;
@class HMEvent, HMAccessoryProfile, HMCameraProfile, HMAddAccessoryRequest, HMAccessorySetupPayload, HMHomeAccessControl;
@class HMCameraStreamControl, HMCameraSnapshotControl, HMCameraSettingsControl, HMCameraAudioControl, HMCameraStream, HMCameraSnapshot;

// MARK: - the home manager and homes

@class HMHomeManager;
@protocol HMHomeManagerDelegate <NSObject>
@optional
- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager;
- (void)homeManagerDidUpdatePrimaryHome:(HMHomeManager *)manager;
- (void)homeManager:(HMHomeManager *)manager didAddHome:(HMHome *)home;
- (void)homeManager:(HMHomeManager *)manager didRemoveHome:(HMHome *)home;
- (void)homeManager:(HMHomeManager *)manager didReceiveAddAccessoryRequest:(HMAddAccessoryRequest *)request;
- (void)homeManager:(HMHomeManager *)manager didUpdateAuthorizationStatus:(HMHomeManagerAuthorizationStatus)status;
@end

@interface HMHomeManager : NSObject
@property (weak, nonatomic, nullable) id<HMHomeManagerDelegate> delegate;
@property (readonly, nonatomic) HMHomeManagerAuthorizationStatus authorizationStatus;
@property (readonly, copy, nonatomic) NSArray<HMHome *> *homes;
@property (readonly, strong, nonatomic, nullable) HMHome *primaryHome API_DEPRECATED("No longer supported.", ios(8.0, 16.1));
- (void)updatePrimaryHome:(HMHome *)home completionHandler:(HMErrorBlock)completion API_DEPRECATED("No longer supported.", ios(8.0, 16.1));
- (void)addHomeWithName:(NSString *)homeName completionHandler:(void (^)(HMHome * _Nullable home, NSError * _Nullable error))completion;
- (void)removeHome:(HMHome *)home completionHandler:(HMErrorBlock)completion;
- (void)findVendorAccessoryWithHAPPublicKey:(NSData *)hapPublicKey completionHandler:(void (^)(HMAccessory * _Nullable accessory, NSError * _Nullable error))completion;
@end

@protocol HMHomeDelegate <NSObject>
@optional
- (void)homeDidUpdateName:(HMHome *)home;
- (void)homeDidUpdateAccessControlForCurrentUser:(HMHome *)home;
- (void)home:(HMHome *)home didAddAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didRemoveAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didAddUser:(HMUser *)user;
- (void)home:(HMHome *)home didRemoveUser:(HMUser *)user;
- (void)home:(HMHome *)home didUpdateRoom:(HMRoom *)room forAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didAddRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didRemoveRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didUpdateNameForRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didAddZone:(HMZone *)zone;
- (void)home:(HMHome *)home didRemoveZone:(HMZone *)zone;
- (void)home:(HMHome *)home didUpdateNameForZone:(HMZone *)zone;
- (void)home:(HMHome *)home didAddRoom:(HMRoom *)room toZone:(HMZone *)zone;
- (void)home:(HMHome *)home didRemoveRoom:(HMRoom *)room fromZone:(HMZone *)zone;
- (void)home:(HMHome *)home didAddServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didRemoveServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didUpdateNameForServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didAddService:(HMService *)service toServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didRemoveService:(HMService *)service fromServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didAddActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didRemoveActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didUpdateNameForActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didUpdateActionsForActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didAddTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didRemoveTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUpdateNameForTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUpdateTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUnblockAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didEncounterError:(NSError *)error forAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didUpdateHomeHubState:(HMHomeHubState)homeHubState;
- (void)homeDidUpdateSupportedFeatures:(HMHome *)home;
@end

@interface HMHome : NSObject
@property (weak, nonatomic, nullable) id<HMHomeDelegate> delegate;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@property (readonly, getter=isPrimary, nonatomic) BOOL primary;
@property (readonly, nonatomic) HMHomeHubState homeHubState;
@property (readonly, nonatomic) BOOL supportsAddingNetworkRouter;
@property (readonly, getter=isProvisionalHome, nonatomic) BOOL provisionalHome;
@property (readonly, copy, nonatomic) NSString *matterControllerID;
@property (readonly, copy, nonatomic) NSXPCConnection * (^matterControllerXPCConnectBlock)(void);
@property (readonly, copy, nonatomic) NSXPCConnection * (^matterStartupParametersXPCConnectBlock)(void);
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
@property (readonly, strong, nonatomic) HMUser *currentUser;
@property (readonly, copy, nonatomic) NSArray<HMUser *> *users API_DEPRECATED("Use -manageUsersWithCompletionHandler:", ios(8.0, 9.0));
- (void)addUserWithCompletionHandler:(void (^)(HMUser * _Nullable user, NSError * _Nullable error))completion API_DEPRECATED("", ios(8.0, 9.0));
- (void)removeUser:(HMUser *)user completionHandler:(HMErrorBlock)completion API_DEPRECATED("", ios(8.0, 9.0));
- (void)manageUsersWithCompletionHandler:(HMErrorBlock)completion;
- (HMHomeAccessControl *)homeAccessControlForUser:(HMUser *)user;
@property (readonly, copy, nonatomic) NSArray<HMAccessory *> *accessories;
- (void)addAccessory:(HMAccessory *)accessory completionHandler:(HMErrorBlock)completion;
- (void)removeAccessory:(HMAccessory *)accessory completionHandler:(HMErrorBlock)completion;
- (void)assignAccessory:(HMAccessory *)accessory toRoom:(HMRoom *)room completionHandler:(HMErrorBlock)completion;
- (nullable NSArray<HMService *> *)servicesWithTypes:(NSArray<NSString *> *)serviceTypes;
- (void)unblockAccessory:(HMAccessory *)accessory completionHandler:(HMErrorBlock)completion;
- (void)addAndSetupAccessoriesWithCompletionHandler:(HMErrorBlock)completion API_DEPRECATED("Use -[HMAccessorySetupManager performAccessorySetupUsingRequest:completionHandler:]", ios(10.0, 15.4));
- (void)addAndSetupAccessoriesWithPayload:(HMAccessorySetupPayload *)payload completionHandler:(void (^)(NSArray<HMAccessory *> * _Nullable accessories, NSError * _Nullable error))completion API_DEPRECATED("Use -[HMAccessorySetupManager performAccessorySetupUsingRequest:completionHandler:]", ios(11.3, 15.4));
@property (readonly, copy, nonatomic) NSArray<HMRoom *> *rooms;
- (void)addRoomWithName:(NSString *)roomName completionHandler:(void (^)(HMRoom * _Nullable room, NSError * _Nullable error))completion;
- (void)removeRoom:(HMRoom *)room completionHandler:(HMErrorBlock)completion;
- (HMRoom *)roomForEntireHome;
@property (readonly, copy, nonatomic) NSArray<HMZone *> *zones;
- (void)addZoneWithName:(NSString *)zoneName completionHandler:(void (^)(HMZone * _Nullable zone, NSError * _Nullable error))completion;
- (void)removeZone:(HMZone *)zone completionHandler:(HMErrorBlock)completion;
@property (readonly, copy, nonatomic) NSArray<HMServiceGroup *> *serviceGroups;
- (void)addServiceGroupWithName:(NSString *)serviceGroupName completionHandler:(void (^)(HMServiceGroup * _Nullable group, NSError * _Nullable error))completion;
- (void)removeServiceGroup:(HMServiceGroup *)group completionHandler:(HMErrorBlock)completion;
@property (readonly, copy, nonatomic) NSArray<HMActionSet *> *actionSets;
- (void)addActionSetWithName:(NSString *)actionSetName completionHandler:(void (^)(HMActionSet * _Nullable actionSet, NSError * _Nullable error))completion;
- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(HMErrorBlock)completion;
- (void)executeActionSet:(HMActionSet *)actionSet completionHandler:(HMErrorBlock)completion;
- (nullable HMActionSet *)builtinActionSetOfType:(NSString *)actionSetType;
@property (readonly, copy, nonatomic) NSArray<HMTrigger *> *triggers;
- (void)addTrigger:(HMTrigger *)trigger completionHandler:(HMErrorBlock)completion;
- (void)removeTrigger:(HMTrigger *)trigger completionHandler:(HMErrorBlock)completion;
@end

@interface HMRoom : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSArray<HMAccessory *> *accessories;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
@end

@interface HMZone : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSArray<HMRoom *> *rooms;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)addRoom:(HMRoom *)room completionHandler:(HMErrorBlock)completion;
- (void)removeRoom:(HMRoom *)room completionHandler:(HMErrorBlock)completion;
@end

@interface HMServiceGroup : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSArray<HMService *> *services;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)addService:(HMService *)service completionHandler:(HMErrorBlock)completion;
- (void)removeService:(HMService *)service completionHandler:(HMErrorBlock)completion;
@end

@interface HMUser : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@end

@interface HMAccessControl : NSObject
@end
@interface HMHomeAccessControl : HMAccessControl
@property (readonly, getter=isAdministrator, nonatomic) BOOL administrator;
@end

// MARK: - accessories

@class HMAccessoryCategory;
@protocol HMAccessoryDelegate <NSObject>
@optional
- (void)accessoryDidUpdateName:(HMAccessory *)accessory;
- (void)accessory:(HMAccessory *)accessory didUpdateNameForService:(HMService *)service;
- (void)accessory:(HMAccessory *)accessory didUpdateAssociatedServiceTypeForService:(HMService *)service;
- (void)accessoryDidUpdateServices:(HMAccessory *)accessory;
- (void)accessory:(HMAccessory *)accessory didAddProfile:(HMAccessoryProfile *)profile;
- (void)accessory:(HMAccessory *)accessory didRemoveProfile:(HMAccessoryProfile *)profile;
- (void)accessoryDidUpdateReachability:(HMAccessory *)accessory;
- (void)accessory:(HMAccessory *)accessory service:(HMService *)service didUpdateValueForCharacteristic:(HMCharacteristic *)characteristic;
- (void)accessory:(HMAccessory *)accessory didUpdateFirmwareVersion:(NSString *)firmwareVersion;
@end

@interface HMAccessory : NSObject
@property (weak, nonatomic, nullable) id<HMAccessoryDelegate> delegate;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSUUID *identifier API_DEPRECATED_WITH_REPLACEMENT("uniqueIdentifier", ios(8.0, 9.0));
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@property (readonly, getter=isReachable, nonatomic) BOOL reachable;
@property (readonly, getter=isBridged, nonatomic) BOOL bridged;
@property (readonly, copy, nonatomic, nullable) NSArray<NSUUID *> *identifiersForBridgedAccessories API_DEPRECATED_WITH_REPLACEMENT("uniqueIdentifiersForBridgedAccessories", ios(8.0, 9.0));
@property (readonly, copy, nonatomic, nullable) NSArray<NSUUID *> *uniqueIdentifiersForBridgedAccessories;
@property (readonly, weak, nonatomic, nullable) HMRoom *room;
@property (readonly, copy, nonatomic) NSArray<HMService *> *services;
@property (readonly, copy, nonatomic) NSArray<HMAccessoryProfile *> *profiles;
@property (readonly, getter=isBlocked, nonatomic) BOOL blocked;
@property (readonly, copy, nonatomic, nullable) NSString *model;
@property (readonly, copy, nonatomic, nullable) NSString *manufacturer;
@property (readonly, copy, nonatomic, nullable) NSString *firmwareVersion;
@property (readonly, nonatomic) BOOL supportsIdentify;
@property (readonly, strong, nonatomic) HMAccessoryCategory *category;
@property (readonly, copy, nonatomic, nullable) NSNumber *matterNodeID;
@property (readonly, copy, nonatomic, nullable) NSArray<HMCameraProfile *> *cameraProfiles;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)identifyWithCompletionHandler:(HMErrorBlock)completion;
@end

@interface HMAccessoryCategory : NSObject
@property (readonly, copy, nonatomic) NSString *categoryType;
@property (readonly, copy, nonatomic) NSString *localizedDescription;
@end

@interface HMAccessoryProfile : NSObject
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@property (readonly, copy, nonatomic) NSArray<HMService *> *services;
@property (readonly, weak, nonatomic, nullable) HMAccessory *accessory;
@end

@interface HMService : NSObject
@property (readonly, weak, nonatomic, nullable) HMAccessory *accessory;
@property (readonly, copy, nonatomic) NSString *serviceType;
@property (readonly, copy, nonatomic) NSString *localizedDescription;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic, nullable) NSString *associatedServiceType;
@property (readonly, copy, nonatomic) NSArray<HMCharacteristic *> *characteristics;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@property (readonly, getter=isUserInteractive, nonatomic) BOOL userInteractive;
@property (readonly, getter=isPrimaryService, nonatomic) BOOL primaryService;
@property (readonly, copy, nonatomic, nullable) NSArray<HMService *> *linkedServices;
@property (readonly, copy, nonatomic, nullable) NSNumber *matterEndpointID;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)updateAssociatedServiceType:(nullable NSString *)serviceType completionHandler:(HMErrorBlock)completion;
@end

@interface HMCharacteristicMetadata : NSObject
@property (readonly, nonatomic, nullable) NSNumber *minimumValue;
@property (readonly, nonatomic, nullable) NSNumber *maximumValue;
@property (readonly, nonatomic, nullable) NSNumber *stepValue;
@property (readonly, nonatomic, nullable) NSNumber *maxLength;
@property (readonly, copy, nonatomic, nullable) NSString *format;
@property (readonly, copy, nonatomic, nullable) NSString *units;
@property (readonly, copy, nonatomic, nullable) NSString *manufacturerDescription;
@property (readonly, copy, nonatomic, nullable) NSArray<NSNumber *> *validValues;
@end

@interface HMCharacteristic : NSObject
@property (readonly, copy, nonatomic) NSString *characteristicType;
@property (readonly, copy, nonatomic) NSString *localizedDescription;
@property (readonly, weak, nonatomic, nullable) HMService *service;
@property (readonly, copy, nonatomic) NSArray<NSString *> *properties;
@property (readonly, strong, nonatomic, nullable) HMCharacteristicMetadata *metadata;
@property (readonly, copy, nonatomic, nullable) id value;
@property (readonly, getter=isNotificationEnabled, nonatomic) BOOL notificationEnabled;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
- (void)writeValue:(nullable id)value completionHandler:(HMErrorBlock)completion;
- (void)readValueWithCompletionHandler:(HMErrorBlock)completion;
- (void)enableNotification:(BOOL)enable completionHandler:(HMErrorBlock)completion;
- (void)updateAuthorizationData:(nullable NSData *)data completionHandler:(HMErrorBlock)completion;
@end

@class HMAccessoryBrowser;
@protocol HMAccessoryBrowserDelegate <NSObject>
@optional
- (void)accessoryBrowser:(HMAccessoryBrowser *)browser didFindNewAccessory:(HMAccessory *)accessory;
- (void)accessoryBrowser:(HMAccessoryBrowser *)browser didRemoveNewAccessory:(HMAccessory *)accessory;
@end

@interface HMAccessoryBrowser : NSObject
@property (weak, nonatomic, nullable) id<HMAccessoryBrowserDelegate> delegate;
@property (readonly, copy, nonatomic) NSArray<HMAccessory *> *discoveredAccessories;
- (void)startSearchingForNewAccessories;
- (void)stopSearchingForNewAccessories;
@end

@interface HMAccessoryOwnershipToken : NSObject
- (nullable instancetype)initWithData:(NSData *)data;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HMAccessorySetupPayload : NSObject
- (nullable instancetype)initWithURL:(nullable NSURL *)setupPayloadURL;
- (nullable instancetype)initWithURL:(NSURL *)setupPayloadURL ownershipToken:(nullable HMAccessoryOwnershipToken *)ownershipToken;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HMAccessorySetupRequest : NSObject <NSCopying>
@property (copy, nonatomic, nullable) HMAccessorySetupPayload *payload;
@property (copy, nonatomic, nullable) NSUUID *homeUniqueIdentifier;
@property (copy, nonatomic, nullable) NSUUID *suggestedRoomUniqueIdentifier;
@property (copy, nonatomic, nullable) NSString *suggestedAccessoryName;
@end

@interface HMAccessorySetupResult : NSObject <NSCopying>
@property (readonly, copy, nonatomic) NSUUID *homeUniqueIdentifier;
@property (readonly, copy, nonatomic) NSArray<NSUUID *> *accessoryUniqueIdentifiers;
@end

@interface HMAccessorySetupManager : NSObject
@property (class, readonly, nonatomic) BOOL isSupported;
- (void)performAccessorySetupUsingRequest:(HMAccessorySetupRequest *)request completionHandler:(void (^)(HMAccessorySetupResult * _Nullable result, NSError * _Nullable error))completion;
@end

@interface HMAddAccessoryRequest : NSObject
@property (readonly, strong, nonatomic) HMHome *home;
@property (readonly, strong, nonatomic) HMAccessoryCategory *accessoryCategory;
@property (readonly, copy, nonatomic) NSString *accessoryName;
@property (readonly, nonatomic) BOOL requiresSetupPayloadURL;
@property (readonly, nonatomic) BOOL requiresOwnershipToken API_DEPRECATED("", ios(13.0, 13.0));
- (nullable HMAccessorySetupPayload *)payloadWithOwnershipToken:(HMAccessoryOwnershipToken *)ownershipToken;
- (nullable HMAccessorySetupPayload *)payloadWithURL:(NSURL *)setupPayloadURL ownershipToken:(HMAccessoryOwnershipToken *)ownershipToken;
- (instancetype)init NS_UNAVAILABLE;
@end

@class HMNetworkConfigurationProfile;
@protocol HMNetworkConfigurationProfileDelegate <NSObject>
@optional
- (void)profileDidUpdateNetworkAccessMode:(HMNetworkConfigurationProfile *)profile;
@end
@interface HMNetworkConfigurationProfile : HMAccessoryProfile
@property (weak, nonatomic, nullable) id<HMNetworkConfigurationProfileDelegate> delegate;
@property (readonly, getter=isNetworkAccessRestricted, nonatomic) BOOL networkAccessRestricted;
@end

// MARK: - action sets and triggers

@interface HMAction : NSObject
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@end

@interface HMCharacteristicWriteAction<TargetValueType : id<NSCopying>> : HMAction
- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic targetValue:(TargetValueType)targetValue;
@property (readonly, strong, nonatomic) HMCharacteristic *characteristic;
@property (readonly, copy, nonatomic) TargetValueType targetValue;
- (void)updateTargetValue:(TargetValueType)targetValue completionHandler:(HMErrorBlock)completion;
@end

@interface HMActionSet : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSSet<HMAction *> *actions;
@property (readonly, getter=isExecuting, nonatomic) BOOL executing;
@property (readonly, copy, nonatomic) NSString *actionSetType;
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@property (readonly, copy, nonatomic, nullable) NSDate *lastExecutionDate;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)addAction:(HMAction *)action completionHandler:(HMErrorBlock)completion;
- (void)removeAction:(HMAction *)action completionHandler:(HMErrorBlock)completion;
@end

@interface HMTrigger : NSObject
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, getter=isEnabled, nonatomic) BOOL enabled;
@property (readonly, copy, nonatomic) NSArray<HMActionSet *> *actionSets;
@property (readonly, copy, nonatomic, nullable) NSDate *lastFireDate API_DEPRECATED("No longer supported.", ios(8.0, 17.0));
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
- (void)updateName:(NSString *)name completionHandler:(HMErrorBlock)completion;
- (void)addActionSet:(HMActionSet *)actionSet completionHandler:(HMErrorBlock)completion;
- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(HMErrorBlock)completion;
- (void)enable:(BOOL)enable completionHandler:(HMErrorBlock)completion;
@end

@interface HMTimerTrigger : HMTrigger
- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate recurrence:(nullable NSDateComponents *)recurrence;
- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate timeZone:(nullable NSTimeZone *)timeZone recurrence:(nullable NSDateComponents *)recurrence recurrenceCalendar:(nullable NSCalendar *)recurrenceCalendar API_DEPRECATED_WITH_REPLACEMENT("-initWithName:fireDate:recurrence:", ios(8.0, 16.4));
@property (readonly, copy, nonatomic) NSDate *fireDate;
@property (readonly, copy, nonatomic, nullable) NSTimeZone *timeZone API_DEPRECATED("", ios(8.0, 16.4));
@property (readonly, copy, nonatomic, nullable) NSDateComponents *recurrence;
@property (readonly, copy, nonatomic, nullable) NSCalendar *recurrenceCalendar API_DEPRECATED("", ios(8.0, 16.4));
- (void)updateFireDate:(NSDate *)fireDate completionHandler:(HMErrorBlock)completion;
- (void)updateTimeZone:(nullable NSTimeZone *)timeZone completionHandler:(HMErrorBlock)completion API_DEPRECATED("", ios(8.0, 16.4));
- (void)updateRecurrence:(nullable NSDateComponents *)recurrence completionHandler:(HMErrorBlock)completion;
@end

@class HMSignificantTimeEvent, HMPresenceEvent;
@interface HMEventTrigger : HMTrigger
- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events predicate:(nullable NSPredicate *)predicate;
- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events endEvents:(nullable NSArray<HMEvent *> *)endEvents recurrences:(nullable NSArray<NSDateComponents *> *)recurrences predicate:(nullable NSPredicate *)predicate;
@property (readonly, copy, nonatomic) NSArray<HMEvent *> *events;
@property (readonly, copy, nonatomic) NSArray<HMEvent *> *endEvents;
@property (readonly, copy, nonatomic, nullable) NSPredicate *predicate;
@property (readonly, copy, nonatomic, nullable) NSArray<NSDateComponents *> *recurrences;
@property (readonly, nonatomic) BOOL executeOnce;
@property (readonly, assign, nonatomic) HMEventTriggerActivationState triggerActivationState;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringBeforeSignificantEvent:(HMSignificantTimeEvent *)significantEvent;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringAfterSignificantEvent:(HMSignificantTimeEvent *)significantEvent;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringBetweenSignificantEvent:(HMSignificantTimeEvent *)firstSignificantEvent secondSignificantEvent:(HMSignificantTimeEvent *)secondSignificantEvent;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringBeforeSignificantEvent:(NSString *)significantEvent applyingOffset:(nullable NSDateComponents *)offset API_DEPRECATED("", ios(9.0, 11.0));
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringAfterSignificantEvent:(NSString *)significantEvent applyingOffset:(nullable NSDateComponents *)offset API_DEPRECATED("", ios(9.0, 11.0));
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringBeforeDateWithComponents:(NSDateComponents *)dateComponents;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringOnDateWithComponents:(NSDateComponents *)dateComponents;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringAfterDateWithComponents:(NSDateComponents *)dateComponents;
+ (NSPredicate *)predicateForEvaluatingTriggerOccurringBetweenDateWithComponents:(NSDateComponents *)firstDateComponents secondDateWithComponents:(NSDateComponents *)secondDateWithComponents;
+ (NSPredicate *)predicateForEvaluatingTriggerWithCharacteristic:(HMCharacteristic *)characteristic relatedBy:(NSPredicateOperatorType)operatorType toValue:(id)value;
+ (NSPredicate *)predicateForEvaluatingTriggerWithPresence:(HMPresenceEvent *)presenceEvent;
- (void)addEvent:(HMEvent *)event completionHandler:(HMErrorBlock)completion API_DEPRECATED("Use -updateEvents:completionHandler:", ios(9.0, 11.0));
- (void)removeEvent:(HMEvent *)event completionHandler:(HMErrorBlock)completion API_DEPRECATED("Use -updateEvents:completionHandler:", ios(9.0, 11.0));
- (void)updateEvents:(NSArray<HMEvent *> *)events completionHandler:(HMErrorBlock)completion;
- (void)updateEndEvents:(NSArray<HMEvent *> *)endEvents completionHandler:(HMErrorBlock)completion;
- (void)updatePredicate:(nullable NSPredicate *)predicate completionHandler:(HMErrorBlock)completion;
- (void)updateRecurrences:(nullable NSArray<NSDateComponents *> *)recurrences completionHandler:(HMErrorBlock)completion;
- (void)updateExecuteOnce:(BOOL)executeOnce completionHandler:(HMErrorBlock)completion;
@end

// MARK: - events

@interface HMEvent : NSObject
@property (readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
+ (BOOL)isSupportedForHome:(HMHome *)home;
@end

@interface HMTimeEvent : HMEvent
@end

@interface HMCalendarEvent : HMTimeEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithFireDateComponents:(NSDateComponents *)fireDateComponents;
@property (readonly, strong, nonatomic) NSDateComponents *fireDateComponents;
@end
@interface HMMutableCalendarEvent : HMCalendarEvent
@property (readwrite, strong, nonatomic) NSDateComponents *fireDateComponents;
@end

@interface HMSignificantTimeEvent : HMTimeEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithSignificantEvent:(HMSignificantEvent)significantEvent offset:(nullable NSDateComponents *)offset;
@property (readonly, strong, nonatomic) HMSignificantEvent significantEvent;
@property (readonly, strong, nonatomic, nullable) NSDateComponents *offset;
@end
@interface HMMutableSignificantTimeEvent : HMSignificantTimeEvent
@property (readwrite, strong, nonatomic) HMSignificantEvent significantEvent;
@property (readwrite, strong, nonatomic) NSDateComponents *offset;
@end

@interface HMDurationEvent : HMTimeEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithDuration:(NSTimeInterval)duration;
@property (readonly, assign, nonatomic) NSTimeInterval duration;
@end
@interface HMMutableDurationEvent : HMDurationEvent
@property (readwrite, assign, nonatomic) NSTimeInterval duration;
@end

@interface HMCharacteristicEvent<TriggerValueType : id<NSCopying>> : HMEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic triggerValue:(nullable TriggerValueType)triggerValue;
@property (readonly, strong, nonatomic) HMCharacteristic *characteristic;
@property (readonly, copy, nonatomic, nullable) TriggerValueType triggerValue;
- (void)updateTriggerValue:(nullable TriggerValueType)triggerValue completionHandler:(HMErrorBlock)completion API_DEPRECATED("", ios(9.0, 11.0));
@end
@interface HMMutableCharacteristicEvent<TriggerValueType : id<NSCopying>> : HMCharacteristicEvent<TriggerValueType>
@property (readwrite, strong, nonatomic) HMCharacteristic *characteristic;
@property (readwrite, copy, nonatomic, nullable) TriggerValueType triggerValue;
@end

@interface HMNumberRange : NSObject
+ (instancetype)numberRangeWithMinValue:(NSNumber *)minValue maxValue:(NSNumber *)maxValue;
+ (instancetype)numberRangeWithMinValue:(NSNumber *)minValue;
+ (instancetype)numberRangeWithMaxValue:(NSNumber *)maxValue;
@property (readonly, strong, nonatomic, nullable) NSNumber *minValue;
@property (readonly, strong, nonatomic, nullable) NSNumber *maxValue;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HMCharacteristicThresholdRangeEvent : HMEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic thresholdRange:(HMNumberRange *)thresholdRange;
@property (readonly, strong, nonatomic) HMCharacteristic *characteristic;
@property (readonly, copy, nonatomic) HMNumberRange *thresholdRange;
@end
@interface HMMutableCharacteristicThresholdRangeEvent : HMCharacteristicThresholdRangeEvent
@property (readwrite, strong, nonatomic) HMCharacteristic *characteristic;
@property (readwrite, copy, nonatomic) HMNumberRange *thresholdRange;
@end

@interface HMLocationEvent : HMEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithRegion:(CLRegion *)region;
@property (readonly, strong, nonatomic, nullable) CLRegion *region;
- (void)updateRegion:(CLRegion *)region completionHandler:(HMErrorBlock)completion API_DEPRECATED("", ios(9.0, 11.0));
@end
@interface HMMutableLocationEvent : HMLocationEvent
@property (readwrite, strong, nonatomic, nullable) CLRegion *region;
@end

HM_EXTERN NSString * const HMPresenceKeyPath;
@interface HMPresenceEvent : HMEvent <NSCopying, NSMutableCopying>
- (instancetype)initWithPresenceEventType:(HMPresenceEventType)presenceEventType presenceUserType:(HMPresenceEventUserType)presenceUserType;
@property (readonly, assign, nonatomic) HMPresenceEventType presenceEventType;
@property (readonly, assign, nonatomic) HMPresenceEventUserType presenceUserType;
@end
@interface HMMutablePresenceEvent : HMPresenceEvent
@property (readwrite, assign, nonatomic) HMPresenceEventType presenceEventType;
@property (readwrite, assign, nonatomic) HMPresenceEventUserType presenceUserType;
@end

// MARK: - cameras

@interface HMCameraProfile : HMAccessoryProfile
@property (readonly, strong, nonatomic, nullable) HMCameraStreamControl *streamControl;
@property (readonly, strong, nonatomic, nullable) HMCameraSnapshotControl *snapshotControl;
@property (readonly, strong, nonatomic, nullable) HMCameraSettingsControl *settingsControl;
@property (readonly, strong, nonatomic, nullable) HMCameraAudioControl *speakerControl;
@property (readonly, strong, nonatomic, nullable) HMCameraAudioControl *microphoneControl;
@end

@interface HMCameraControl : NSObject
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HMCameraSettingsControl : HMCameraControl
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *currentHorizontalTilt;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *targetHorizontalTilt;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *currentVerticalTilt;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *targetVerticalTilt;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *opticalZoom;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *digitalZoom;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *imageRotation;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *imageMirroring;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *nightVision;
@end

@interface HMCameraAudioControl : HMCameraControl
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *mute;
@property (readonly, strong, nonatomic, nullable) HMCharacteristic *volume;
@end

@interface HMCameraSource : NSObject
@property (readonly, assign, nonatomic) double aspectRatio;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HMCameraStream : HMCameraSource
@property (readonly, assign, nonatomic) HMCameraAudioStreamSetting audioStreamSetting;
- (void)updateAudioStreamSetting:(HMCameraAudioStreamSetting)audioStreamSetting completionHandler:(HMErrorBlock)completion;
- (void)setAudioStreamSetting:(HMCameraAudioStreamSetting)audioStreamSetting API_DEPRECATED_WITH_REPLACEMENT("-updateAudioStreamSetting:completionHandler:", ios(10.0, 10.0));
@end

@interface HMCameraSnapshot : HMCameraSource
@property (readonly, copy, nonatomic) NSDate *captureDate;
@end

@protocol HMCameraStreamControlDelegate <NSObject>
@optional
- (void)cameraStreamControlDidStartStream:(HMCameraStreamControl *)cameraStreamControl;
- (void)cameraStreamControl:(HMCameraStreamControl *)cameraStreamControl didStopStreamWithError:(nullable NSError *)error;
@end

@interface HMCameraStreamControl : HMCameraControl
@property (weak, nonatomic, nullable) id<HMCameraStreamControlDelegate> delegate;
@property (readonly, assign, nonatomic) HMCameraStreamState streamState;
@property (readonly, strong, nonatomic, nullable) HMCameraStream *cameraStream;
- (void)startStream;
- (void)stopStream;
@end

@protocol HMCameraSnapshotControlDelegate <NSObject>
@optional
- (void)cameraSnapshotControl:(HMCameraSnapshotControl *)cameraSnapshotControl didTakeSnapshot:(nullable HMCameraSnapshot *)snapshot error:(nullable NSError *)error;
- (void)cameraSnapshotControlDidUpdateMostRecentSnapshot:(HMCameraSnapshotControl *)cameraSnapshotControl;
@end

@interface HMCameraSnapshotControl : HMCameraControl
@property (weak, nonatomic, nullable) id<HMCameraSnapshotControlDelegate> delegate;
@property (readonly, strong, nonatomic, nullable) HMCameraSnapshot *mostRecentSnapshot;
- (void)takeSnapshot;
@end

@interface HMCameraView : UIView
@property (strong, nonatomic, nullable) HMCameraSource *cameraSource;
@end

#endif  // !defined(__swift__)

NS_ASSUME_NONNULL_END
