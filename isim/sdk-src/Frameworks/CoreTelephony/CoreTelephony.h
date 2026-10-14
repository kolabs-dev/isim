#pragma once
/* isim CoreTelephony: adapted like Apple's Simulator, which has no cellular radio: no carriers, no radio access
   technology (nil), and no change notifications. */
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
NS_ASSUME_NONNULL_END
