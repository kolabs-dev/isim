// isim CoreTelephony: like Apple's Simulator, there is no cellular radio: no carriers and no radio access technology.
#import <CoreTelephony/CoreTelephony.h>

NSString * const CTRadioAccessTechnologyGPRS = @"CTRadioAccessTechnologyGPRS";
NSString * const CTRadioAccessTechnologyEdge = @"CTRadioAccessTechnologyEdge";
NSString * const CTRadioAccessTechnologyWCDMA = @"CTRadioAccessTechnologyWCDMA";
NSString * const CTRadioAccessTechnologyHSDPA = @"CTRadioAccessTechnologyHSDPA";
NSString * const CTRadioAccessTechnologyHSUPA = @"CTRadioAccessTechnologyHSUPA";
NSString * const CTRadioAccessTechnologyCDMA1x = @"CTRadioAccessTechnologyCDMA1x";
NSString * const CTRadioAccessTechnologyCDMAEVDORev0 = @"CTRadioAccessTechnologyCDMAEVDORev0";
NSString * const CTRadioAccessTechnologyCDMAEVDORevA = @"CTRadioAccessTechnologyCDMAEVDORevA";
NSString * const CTRadioAccessTechnologyCDMAEVDORevB = @"CTRadioAccessTechnologyCDMAEVDORevB";
NSString * const CTRadioAccessTechnologyeHRPD = @"CTRadioAccessTechnologyeHRPD";
NSString * const CTRadioAccessTechnologyLTE = @"CTRadioAccessTechnologyLTE";
NSString * const CTRadioAccessTechnologyNRNSA = @"CTRadioAccessTechnologyNRNSA";
NSString * const CTRadioAccessTechnologyNR = @"CTRadioAccessTechnologyNR";
NSNotificationName const CTRadioAccessTechnologyDidChangeNotification = @"kCTRadioAccessTechnologyDidChangeNotification";
NSNotificationName const CTServiceRadioAccessTechnologyDidChangeNotification = @"kCTServiceRadioAccessTechnologyDidChangeNotification";

@implementation CTCarrier
- (NSString *)carrierName { return nil; }
- (NSString *)mobileCountryCode { return nil; }
- (NSString *)mobileNetworkCode { return nil; }
- (NSString *)isoCountryCode { return nil; }
- (BOOL)allowsVOIP { return NO; }
@end

@implementation CTTelephonyNetworkInfo
- (NSString *)dataServiceIdentifier { return nil; }
- (NSDictionary *)serviceSubscriberCellularProviders { return nil; }
- (CTCarrier *)subscriberCellularProvider { return nil; }
- (NSDictionary *)serviceCurrentRadioAccessTechnology { return nil; }
- (NSString *)currentRadioAccessTechnology { return nil; }
@end
