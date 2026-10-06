#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSString;
@interface NSProcessInfo : NSObject
@property (class, readonly, strong) NSProcessInfo *processInfo;
@property (readonly, copy) NSDictionary<NSString *, NSString *> *environment;
@property (readonly, copy) NSArray<NSString *> *arguments;
@property (copy) NSString *processName;
@property (readonly) int processIdentifier;
@property (readonly) NSUInteger processorCount;
@property (readonly) NSTimeInterval systemUptime;
@end
typedef struct { NSInteger majorVersion; NSInteger minorVersion; NSInteger patchVersion; } NSOperatingSystemVersion NS_SWIFT_NAME(OperatingSystemVersion);
typedef NS_ENUM(NSInteger, NSProcessInfoThermalState) {
    NSProcessInfoThermalStateNominal NS_SWIFT_NAME(nominal), NSProcessInfoThermalStateFair NS_SWIFT_NAME(fair),
    NSProcessInfoThermalStateSerious NS_SWIFT_NAME(serious), NSProcessInfoThermalStateCritical NS_SWIFT_NAME(critical)
} NS_SWIFT_NAME(ProcessInfo.ThermalState);
typedef NS_OPTIONS(uint64_t, NSActivityOptions) {
    NSActivityIdleDisplaySleepDisabled NS_SWIFT_NAME(idleDisplaySleepDisabled) = (1ULL << 40), NSActivityIdleSystemSleepDisabled NS_SWIFT_NAME(idleSystemSleepDisabled) = (1ULL << 20),
    NSActivitySuddenTerminationDisabled NS_SWIFT_NAME(suddenTerminationDisabled) = (1ULL << 14), NSActivityAutomaticTerminationDisabled NS_SWIFT_NAME(automaticTerminationDisabled) = (1ULL << 15),
    NSActivityUserInitiated NS_SWIFT_NAME(userInitiated) = (0x00FFFFFFULL | (1ULL << 20)), NSActivityUserInteractive NS_SWIFT_NAME(userInteractive) = (0x00FFFFFFULL | (1ULL << 40)),
    NSActivityUserInitiatedAllowingIdleSystemSleep NS_SWIFT_NAME(userInitiatedAllowingIdleSystemSleep) = (0x00FFFFFFULL & ~(1ULL << 20)),
    NSActivityBackground NS_SWIFT_NAME(background) = 0x000000FFULL, NSActivityLatencyCritical NS_SWIFT_NAME(latencyCritical) = 0xFF00000000ULL
} NS_SWIFT_NAME(ProcessInfo.ActivityOptions);
FOUNDATION_EXPORT NSNotificationName const NSProcessInfoThermalStateDidChangeNotification NS_SWIFT_NAME(ProcessInfo.thermalStateDidChangeNotification);
FOUNDATION_EXPORT NSNotificationName const NSProcessInfoPowerStateDidChangeNotification NS_SWIFT_NAME(NSNotification.Name.NSProcessInfoPowerStateDidChange);
/* isim: a simulated iPhone is always cool and never in Low Power Mode */
@interface NSProcessInfo (IsimDevice)
@property (readonly) NSProcessInfoThermalState thermalState;
@property (readonly, getter=isLowPowerModeEnabled) BOOL lowPowerModeEnabled;
@property (readonly) BOOL isiOSAppOnMac;
@property (readonly) BOOL isMacCatalystApp;
@property (readonly) NSUInteger activeProcessorCount;
@property (readonly) unsigned long long physicalMemory;
@property (readonly) NSOperatingSystemVersion operatingSystemVersion;
@property (readonly, copy) NSString *operatingSystemVersionString;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version NS_SWIFT_NAME(isOperatingSystemAtLeast(_:));
@property (readonly, copy) NSString *hostName;
@property (readonly, copy) NSString *globallyUniqueString;
- (id<NSObject>)beginActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason;
- (void)endActivity:(id<NSObject>)activity;
- (void)performActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason usingBlock:(void (NS_NOESCAPE ^)(void))block;
- (void)performExpiringActivityWithReason:(NSString *)reason usingBlock:(void (^)(BOOL expired))block;
@end
NS_ASSUME_NONNULL_END
