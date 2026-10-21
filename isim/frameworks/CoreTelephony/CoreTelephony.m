// isim CoreTelephony: like Apple's Simulator, there is no cellular radio: no carriers, no radio access technology, no
// subscribers (no SIM), the cellular data restriction state unknown (no change is ever reported), and no eSIM.
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

@implementation CTCellularData
- (CTCellularDataRestrictedState)restrictedState { return kCTCellularDataRestrictedStateUnknown; }
@end

NSString * const CTSubscriberTokenRefreshed = @"CTSubscriberTokenRefreshed";

@implementation CTSubscriber
- (NSData *)carrierToken { return nil; }
- (BOOL)refreshCarrierToken { return NO; }
- (NSString *)identifier { return @""; }
- (BOOL)isSIMInserted { return NO; }
@end

@implementation CTSubscriberInfo
+ (NSArray<CTSubscriber *> *)subscribers { return @[]; }
+ (CTSubscriber *)subscriber { return [CTSubscriber new]; }
@end

@implementation CTCellularPlanProvisioningRequest
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { if ((self = [super init])) _address = @""; return self; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _address = [c decodeObjectOfClass:NSString.class forKey:@"address"] ?: @"";
        _matchingID = [c decodeObjectOfClass:NSString.class forKey:@"matchingID"];
        _OID = [c decodeObjectOfClass:NSString.class forKey:@"OID"];
        _confirmationCode = [c decodeObjectOfClass:NSString.class forKey:@"confirmationCode"];
        _ICCID = [c decodeObjectOfClass:NSString.class forKey:@"ICCID"];
        _EID = [c decodeObjectOfClass:NSString.class forKey:@"EID"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_address forKey:@"address"]; [c encodeObject:_matchingID forKey:@"matchingID"]; [c encodeObject:_OID forKey:@"OID"];
    [c encodeObject:_confirmationCode forKey:@"confirmationCode"]; [c encodeObject:_ICCID forKey:@"ICCID"]; [c encodeObject:_EID forKey:@"EID"];
}
@end

/* no eSIM, like the Simulator: adding a plan fails */
@implementation CTCellularPlanProvisioning
- (BOOL)supportsEmbeddedSIM { return NO; }
- (BOOL)supportsCellularPlan { return NO; }
- (void)addPlanWith:(CTCellularPlanProvisioningRequest *)request completionHandler:(void (^)(CTCellularPlanProvisioningAddPlanResult))completionHandler {
    NSLog(@"isim CoreTelephony: no eSIM on this device: the cellular plan from %@ cannot be added", request.address);
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(CTCellularPlanProvisioningAddPlanResultFail); });
}
@end
