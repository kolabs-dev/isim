// isim ExternalAccessory: like Apple's Simulator, there are no MFi accessories.
#import <ExternalAccessory/ExternalAccessory.h>

NSString * const EABluetoothAccessoryPickerErrorDomain = @"EABluetoothAccessoryPickerErrorDomain";
NSString * const EAAccessoryDidConnectNotification = @"EAAccessoryDidConnectNotification";
NSString * const EAAccessoryDidDisconnectNotification = @"EAAccessoryDidDisconnectNotification";
NSString * const EAAccessoryKey = @"EAAccessoryKey";
NSString * const EAAccessorySelectedKey = @"EAAccessorySelectedKey";

@implementation EAAccessory
- (BOOL)isConnected { return NO; }
- (NSUInteger)connectionID { return EAConnectionIDNone; }
- (NSString *)manufacturer { return @""; }
- (NSString *)name { return @""; }
- (NSString *)modelNumber { return @""; }
- (NSString *)serialNumber { return @""; }
- (NSString *)firmwareRevision { return @""; }
- (NSString *)hardwareRevision { return @""; }
- (NSString *)dockType { return @""; }
- (NSArray *)protocolStrings { return @[]; }
@end

@implementation EAAccessoryManager
+ (EAAccessoryManager *)sharedAccessoryManager {
    static EAAccessoryManager *m; static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[self alloc] init]; });
    return m;
}
- (void)showBluetoothAccessoryPickerWithNameFilter:(NSPredicate *)predicate completion:(EABluetoothAccessoryPickerCompletion)completion {
    NSLog(@"isim ExternalAccessory: no Bluetooth accessories nearby (like the Simulator)");
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{
        completion([NSError errorWithDomain:EABluetoothAccessoryPickerErrorDomain code:EABluetoothAccessoryPickerResultNotFound userInfo:nil]);
    });
}
- (void)registerForLocalNotifications {}
- (void)unregisterForLocalNotifications {}
- (NSArray *)connectedAccessories { return @[]; }
@end

@implementation EASession
- (instancetype)initWithAccessory:(EAAccessory *)accessory forProtocol:(NSString *)protocolString {
    NSLog(@"isim ExternalAccessory: cannot open a session for %@: the accessory is not connected", protocolString);
    return nil;
}
- (EAAccessory *)accessory { return nil; }
- (NSString *)protocolString { return nil; }
- (NSInputStream *)inputStream { return nil; }
- (NSOutputStream *)outputStream { return nil; }
@end
