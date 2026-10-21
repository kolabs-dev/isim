#pragma once
/* isim AccessorySetupKit (iOS 18): like Apple's Simulator, the device has no Bluetooth or Wi-Fi accessories nearby.
   A session activates (an ASAccessoryEventTypeActivated event) and has no accessories; the picker finds nothing and
   completes with ASErrorCodeDiscoveryTimeout. CBUUID is the CoreBluetooth Swift overlay's class, so Swift gets
   ASDiscoveryDescriptor.bluetoothServiceUUID from the AccessorySetupKit overlay. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@class CBUUID;

FOUNDATION_EXPORT NSErrorDomain const ASErrorDomain API_AVAILABLE(ios(18.0));
typedef NS_ERROR_ENUM(ASErrorDomain, ASErrorCode) {
    ASErrorCodeSuccess = 0,
    ASErrorCodeUnknown = 1,
    ASErrorCodeActivationFailed = 100,
    ASErrorCodeConnectionFailed = 150,
    ASErrorCodeDiscoveryTimeout = 200,
    ASErrorCodeExtensionNotFound = 300,
    ASErrorCodeInvalidated = 400,
    ASErrorCodeInvalidRequest = 450,
    ASErrorCodePickerAlreadyActive = 500,
    ASErrorCodePickerRestricted = 550,
    ASErrorCodeUserCancelled = 700,
    ASErrorCodeUserRestricted = 750,
} API_AVAILABLE(ios(18.0));

typedef NS_ENUM(NSInteger, ASAccessoryState) {
    ASAccessoryStateUnauthorized = 0,
    ASAccessoryStateAwaitingAuthorization = 10,
    ASAccessoryStateAuthorized = 20,
} API_AVAILABLE(ios(18.0));

typedef NS_OPTIONS(NSUInteger, ASAccessoryRenameOptions) {
    ASAccessoryRenameSSID = (1U << 0),
} API_AVAILABLE(ios(18.0));

typedef NS_OPTIONS(NSUInteger, ASAccessorySupportOptions) {
    ASAccessorySupportBluetoothPairingLE = (1U << 1),
    ASAccessorySupportBluetoothTransportBridging = (1U << 2),
    ASAccessorySupportBluetoothHID = (1U << 3),
} API_AVAILABLE(ios(18.0));

typedef NS_ENUM(NSInteger, ASDiscoveryDescriptorRange) {
    ASDiscoveryDescriptorRangeDefault = 0,
    ASDiscoveryDescriptorRangeImmediate = 10,
} API_AVAILABLE(ios(18.0));

typedef uint16_t ASBluetoothCompanyIdentifier;

typedef NS_ENUM(NSInteger, ASAccessoryEventType) {
    ASAccessoryEventTypeUnknown = 0,
    ASAccessoryEventTypeActivated = 10,
    ASAccessoryEventTypeInvalidated = 11,
    ASAccessoryEventTypeMigrationComplete = 20,
    ASAccessoryEventTypeAccessoryAdded = 30,
    ASAccessoryEventTypeAccessoryRemoved = 31,
    ASAccessoryEventTypeAccessoryChanged = 32,
    ASAccessoryEventTypePickerDidPresent = 40,
    ASAccessoryEventTypePickerDidDismiss = 50,
    ASAccessoryEventTypePickerSetupBridging = 60,
    ASAccessoryEventTypePickerSetupFailed = 70,
    ASAccessoryEventTypePickerSetupPairing = 80,
    ASAccessoryEventTypePickerSetupRename = 90,
} API_AVAILABLE(ios(18.0));

typedef NS_OPTIONS(NSUInteger, ASPickerDisplayItemSetupOptions) {
    ASPickerDisplayItemSetupRename = (1U << 0),
    ASPickerDisplayItemSetupConfirmAuthorization = (1U << 1),
    ASPickerDisplayItemSetupFinishInApp = (1U << 2),
} API_AVAILABLE(ios(18.0));

/* what the picker looks for */
API_AVAILABLE(ios(18.0))
@interface ASDiscoveryDescriptor : NSObject
@property (nonatomic, assign) ASAccessorySupportOptions supportedOptions;
@property (nonatomic, assign) ASBluetoothCompanyIdentifier bluetoothCompanyIdentifier;
@property (nonatomic, copy, nullable) NSData *bluetoothManufacturerDataBlob;
@property (nonatomic, copy, nullable) NSData *bluetoothManufacturerDataMask;
#if !defined(__swift__)
@property (nonatomic, copy, nullable) CBUUID *bluetoothServiceUUID;
#else
@property (nonatomic, copy, nullable) id bluetoothServiceUUID NS_REFINED_FOR_SWIFT;
#endif
@property (nonatomic, copy, nullable) NSData *bluetoothServiceDataBlob;
@property (nonatomic, copy, nullable) NSData *bluetoothServiceDataMask;
@property (nonatomic, copy, nullable) NSString *bluetoothNameSubstring;
@property (nonatomic, assign) ASDiscoveryDescriptorRange bluetoothRange;
@property (nonatomic, copy, nullable) NSString *SSID;
@property (nonatomic, copy, nullable) NSString *SSIDPrefix;
@end

API_AVAILABLE(ios(18.0))
@interface ASAccessory : NSObject
@property (nonatomic, readonly, assign) ASAccessoryState state;
@property (nonatomic, readonly, copy, nullable) NSUUID *bluetoothIdentifier;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy, nullable) NSString *SSID;
@property (nonatomic, readonly, copy) ASDiscoveryDescriptor *descriptor;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0))
@interface ASPickerDisplayItem : NSObject
- (instancetype)initWithName:(NSString *)name productImage:(UIImage *)productImage descriptor:(ASDiscoveryDescriptor *)descriptor;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) UIImage *productImage;
@property (nonatomic, readonly, copy) ASDiscoveryDescriptor *descriptor;
@property (nonatomic, assign) ASAccessoryRenameOptions renameOptions;
@property (nonatomic, assign) ASPickerDisplayItemSetupOptions setupOptions;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0))
@interface ASAccessoryEvent : NSObject
@property (nonatomic, readonly, assign) ASAccessoryEventType eventType;
@property (nonatomic, readonly, copy, nullable) ASAccessory *accessory;
@property (nonatomic, readonly, copy, nullable) NSError *error;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0))
@interface ASAccessorySession : NSObject
@property (nonatomic, readonly, copy) NSArray<ASAccessory *> *accessories;
#if !defined(__swift__)
- (void)activateWithQueue:(dispatch_queue_t)queue eventHandler:(void (^)(ASAccessoryEvent *event))eventHandler;
#else   /* isim's DispatchQueue is Swift's: activate(on:eventHandler:) is in the overlay (events on the main queue, then the queue) */
- (void)activateWithQueue:(nullable void *)queue eventHandler:(void (^)(ASAccessoryEvent *event))eventHandler NS_REFINED_FOR_SWIFT;
#endif
- (void)invalidate;
- (void)showPickerForDisplayItems:(NSArray<ASPickerDisplayItem *> *)displayItems completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(showPicker(for:completionHandler:));
- (void)removeAccessory:(ASAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(removeAccessory(_:completionHandler:));
- (void)renameAccessory:(ASAccessory *)accessory options:(ASAccessoryRenameOptions)renameOptions completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(renameAccessory(_:options:completionHandler:));
@end

NS_ASSUME_NONNULL_END
