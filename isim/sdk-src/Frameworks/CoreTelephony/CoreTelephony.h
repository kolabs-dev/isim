#pragma once
/* isim CoreTelephony: adapted like Apple's Simulator, which has no cellular radio: no carriers, no radio access
   technology (nil), no subscribers (no SIM), the cellular data restriction state unknown, no eSIM (plans cannot be
   added), and no change notifications. */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const CTRadioAccessTechnologyGPRS, * const CTRadioAccessTechnologyEdge, * const CTRadioAccessTechnologyWCDMA,
    * const CTRadioAccessTechnologyHSDPA, * const CTRadioAccessTechnologyHSUPA, * const CTRadioAccessTechnologyCDMA1x,
    * const CTRadioAccessTechnologyCDMAEVDORev0, * const CTRadioAccessTechnologyCDMAEVDORevA, * const CTRadioAccessTechnologyCDMAEVDORevB,
    * const CTRadioAccessTechnologyeHRPD, * const CTRadioAccessTechnologyLTE, * const CTRadioAccessTechnologyNRNSA, * const CTRadioAccessTechnologyNR;
FOUNDATION_EXPORT NSNotificationName const CTRadioAccessTechnologyDidChangeNotification;
FOUNDATION_EXPORT NSNotificationName const CTServiceRadioAccessTechnologyDidChangeNotification;
@interface CTCarrier : NSObject
@property (nonatomic, readonly, retain, nullable) NSString *carrierName;
@property (nonatomic, readonly, retain, nullable) NSString *mobileCountryCode;
@property (nonatomic, readonly, retain, nullable) NSString *mobileNetworkCode;
@property (nonatomic, readonly, retain, nullable) NSString *isoCountryCode;
@property (nonatomic, readonly, assign) BOOL allowsVOIP;
@end
@class CTTelephonyNetworkInfo;
@protocol CTTelephonyNetworkInfoDelegate <NSObject>
@optional
- (void)dataServiceIdentifierDidChange:(NSString *)identifier;
@end
@interface CTTelephonyNetworkInfo : NSObject
@property (readonly, retain, nullable) NSString *dataServiceIdentifier;
@property (nonatomic, weak, nullable) id<CTTelephonyNetworkInfoDelegate> delegate;
@property (readonly, retain, nullable) NSDictionary<NSString *, CTCarrier *> *serviceSubscriberCellularProviders;
@property (readonly, retain, nullable) CTCarrier *subscriberCellularProvider;
@property (nonatomic, copy, nullable) void (^serviceSubscriberCellularProvidersDidUpdateNotifier)(NSString *);
@property (nonatomic, copy, nullable) void (^subscriberCellularProviderDidUpdateNotifier)(CTCarrier *);
@property (readonly, retain, nullable) NSDictionary<NSString *, NSString *> *serviceCurrentRadioAccessTechnology;
@property (nonatomic, readonly, retain, nullable) NSString *currentRadioAccessTechnology;
@end

/* cellular data: whether the user restricted this app's cellular data (Settings > Cellular) */
typedef NS_ENUM(NSUInteger, CTCellularDataRestrictedState) {
    kCTCellularDataRestrictedStateUnknown,
    kCTCellularDataRestricted,
    kCTCellularDataNotRestricted,
};
typedef void (^CellularDataRestrictionDidUpdateNotifier)(CTCellularDataRestrictedState);
@interface CTCellularData : NSObject
@property (copy, nullable) CellularDataRestrictionDidUpdateNotifier cellularDataRestrictionDidUpdateNotifier;
@property (nonatomic, readonly) CTCellularDataRestrictedState restrictedState;
@end

/* subscribers: one per SIM or eSIM */
@class CTSubscriber;
FOUNDATION_EXPORT NSString * const CTSubscriberTokenRefreshed API_DEPRECATED("use the delegate", ios(7.0, 12.1));
@protocol CTSubscriberDelegate <NSObject>
- (void)subscriberTokenRefreshed:(CTSubscriber *)subscriber;
@end
@interface CTSubscriber : NSObject
@property (nonatomic, readonly, retain, nullable) NSData *carrierToken;
- (BOOL)refreshCarrierToken;
@property (nonatomic, readonly, retain) NSString *identifier;
@property (nonatomic, weak, nullable) id<CTSubscriberDelegate> delegate;
@property (nonatomic, readonly, assign) BOOL isSIMInserted API_AVAILABLE(ios(18.0));
@end
@interface CTSubscriberInfo : NSObject
+ (NSArray<CTSubscriber *> *)subscribers;
+ (CTSubscriber *)subscriber API_DEPRECATED_WITH_REPLACEMENT("subscribers", ios(6.0, 12.1));
@end

/* cellular plans (eSIM) */
typedef NS_ENUM(NSInteger, CTCellularPlanProvisioningAddPlanResult) {
    CTCellularPlanProvisioningAddPlanResultUnknown = 0,
    CTCellularPlanProvisioningAddPlanResultFail,
    CTCellularPlanProvisioningAddPlanResultSuccess,
    CTCellularPlanProvisioningAddPlanResultCancel API_AVAILABLE(ios(17.0)),
};
@interface CTCellularPlanProvisioningRequest : NSObject <NSSecureCoding>
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy, nullable) NSString *matchingID;
@property (nonatomic, copy, nullable) NSString *OID;
@property (nonatomic, copy, nullable) NSString *confirmationCode;
@property (nonatomic, copy, nullable) NSString *ICCID;
@property (nonatomic, copy, nullable) NSString *EID;
@end
@interface CTCellularPlanProvisioning : NSObject
@property (nonatomic, readonly) BOOL supportsEmbeddedSIM API_AVAILABLE(ios(16.0));
- (BOOL)supportsCellularPlan;
- (void)addPlanWith:(CTCellularPlanProvisioningRequest *)request completionHandler:(void (^)(CTCellularPlanProvisioningAddPlanResult result))completionHandler;
@end

/* errors */
typedef struct __CTError { int32_t domain; int32_t error; } CTError;
enum { kCTErrorDomainNoError = 0, kCTErrorDomainPOSIX = 1, kCTErrorDomainMach = 2 };
NS_ASSUME_NONNULL_END
