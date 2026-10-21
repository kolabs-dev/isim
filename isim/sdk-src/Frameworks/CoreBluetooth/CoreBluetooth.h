#pragma once
/* isim Core Bluetooth for Objective-C: the classes are the CoreBluetooth Swift overlay's (CoreBluetooth.framework
   re-exports libswiftCoreBluetooth.dylib). Like Apple's Simulator there is no Bluetooth radio: managers report
   CBManagerStateUnsupported (unauthorized without NSBluetoothAlwaysUsageDescription), commands that need a powered-on
   radio log iOS's API MISUSE message, nothing is discovered. A manager made from Objective-C calls its delegate on the
   main queue. Swift uses the overlay; these declarations are hidden from Swift. The classes are not subclassable from
   Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CBManagerState) {
    CBManagerStateUnknown = 0, CBManagerStateResetting, CBManagerStateUnsupported, CBManagerStateUnauthorized,
    CBManagerStatePoweredOff, CBManagerStatePoweredOn,
};
typedef NS_ENUM(NSInteger, CBManagerAuthorization) {
    CBManagerAuthorizationNotDetermined = 0, CBManagerAuthorizationRestricted, CBManagerAuthorizationDenied, CBManagerAuthorizationAllowedAlways,
};
typedef NS_ENUM(NSInteger, CBPeripheralState) { CBPeripheralStateDisconnected = 0, CBPeripheralStateConnecting, CBPeripheralStateConnected, CBPeripheralStateDisconnecting };
typedef NS_ENUM(NSInteger, CBCharacteristicWriteType) { CBCharacteristicWriteWithResponse = 0, CBCharacteristicWriteWithoutResponse };
typedef NS_OPTIONS(NSUInteger, CBCharacteristicProperties) {
    CBCharacteristicPropertyBroadcast = 0x01, CBCharacteristicPropertyRead = 0x02, CBCharacteristicPropertyWriteWithoutResponse = 0x04,
    CBCharacteristicPropertyWrite = 0x08, CBCharacteristicPropertyNotify = 0x10, CBCharacteristicPropertyIndicate = 0x20,
    CBCharacteristicPropertyAuthenticatedSignedWrites = 0x40, CBCharacteristicPropertyExtendedProperties = 0x80,
    CBCharacteristicPropertyNotifyEncryptionRequired = 0x100, CBCharacteristicPropertyIndicateEncryptionRequired = 0x200,
};
typedef NS_OPTIONS(NSUInteger, CBAttributePermissions) {
    CBAttributePermissionsReadable = 0x01, CBAttributePermissionsWriteable = 0x02,
    CBAttributePermissionsReadEncryptionRequired = 0x04, CBAttributePermissionsWriteEncryptionRequired = 0x08,
};
typedef NS_ENUM(NSInteger, CBPeripheralManagerConnectionLatency) {
    CBPeripheralManagerConnectionLatencyLow = 0, CBPeripheralManagerConnectionLatencyMedium, CBPeripheralManagerConnectionLatencyHigh,
};
typedef NS_OPTIONS(NSUInteger, CBCentralManagerFeature) { CBCentralManagerFeatureExtendedScanAndConnect = 1UL << 0 };
typedef uint16_t CBL2CAPPSM;

FOUNDATION_EXPORT NSString * const CBErrorDomain;
typedef NS_ENUM(NSInteger, CBError) {
    CBErrorUnknown = 0, CBErrorInvalidParameters, CBErrorInvalidHandle, CBErrorNotConnected, CBErrorOutOfSpace,
    CBErrorOperationCancelled, CBErrorConnectionTimeout, CBErrorPeripheralDisconnected, CBErrorUUIDNotAllowed,
    CBErrorAlreadyAdvertising, CBErrorConnectionFailed, CBErrorConnectionLimitReached, CBErrorUnknownDevice,
    CBErrorOperationNotSupported, CBErrorPeerRemovedPairingInformation, CBErrorEncryptionTimedOut, CBErrorTooManyLEPairedDevices,
};
FOUNDATION_EXPORT NSString * const CBATTErrorDomain;
typedef NS_ENUM(NSInteger, CBATTError) {
    CBATTErrorSuccess = 0, CBATTErrorInvalidHandle, CBATTErrorReadNotPermitted, CBATTErrorWriteNotPermitted, CBATTErrorInvalidPdu,
    CBATTErrorInsufficientAuthentication, CBATTErrorRequestNotSupported, CBATTErrorInvalidOffset, CBATTErrorInsufficientAuthorization,
    CBATTErrorPrepareQueueFull, CBATTErrorAttributeNotFound, CBATTErrorAttributeNotLong, CBATTErrorInsufficientEncryptionKeySize,
    CBATTErrorInvalidAttributeValueLength, CBATTErrorUnlikelyError, CBATTErrorInsufficientEncryption, CBATTErrorUnsupportedGroupType,
    CBATTErrorInsufficientResources,
};

FOUNDATION_EXPORT NSString * const CBAdvertisementDataLocalNameKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataManufacturerDataKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataServiceDataKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataServiceUUIDsKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataOverflowServiceUUIDsKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataTxPowerLevelKey;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataIsConnectable;
FOUNDATION_EXPORT NSString * const CBAdvertisementDataSolicitedServiceUUIDsKey;
FOUNDATION_EXPORT NSString * const CBCentralManagerScanOptionAllowDuplicatesKey;
FOUNDATION_EXPORT NSString * const CBCentralManagerOptionShowPowerAlertKey;
FOUNDATION_EXPORT NSString * const CBCentralManagerOptionRestoreIdentifierKey;
FOUNDATION_EXPORT NSString * const CBConnectPeripheralOptionNotifyOnDisconnectionKey;
FOUNDATION_EXPORT NSString * const CBPeripheralManagerOptionShowPowerAlertKey;
FOUNDATION_EXPORT NSString * const CBPeripheralManagerOptionRestoreIdentifierKey;
FOUNDATION_EXPORT NSString * const CBPeripheralManagerRestoredStateServicesKey;
FOUNDATION_EXPORT NSString * const CBPeripheralManagerRestoredStateAdvertisementDataKey;
FOUNDATION_EXPORT NSString * const CBUUIDCharacteristicExtendedPropertiesString;
FOUNDATION_EXPORT NSString * const CBUUIDCharacteristicUserDescriptionString;
FOUNDATION_EXPORT NSString * const CBUUIDClientCharacteristicConfigurationString;
FOUNDATION_EXPORT NSString * const CBUUIDServerCharacteristicConfigurationString;
FOUNDATION_EXPORT NSString * const CBUUIDCharacteristicFormatString;
FOUNDATION_EXPORT NSString * const CBUUIDCharacteristicAggregateFormatString;
FOUNDATION_EXPORT NSString * const CBUUIDCharacteristicValidRangeString;
FOUNDATION_EXPORT NSString * const CBUUIDL2CAPPSMCharacteristicString;

@interface CBUUID : NSObject <NSCopying>
+ (CBUUID *)UUIDWithString:(NSString *)theString;
+ (CBUUID *)UUIDWithData:(NSData *)theData;
+ (CBUUID *)UUIDWithNSUUID:(NSUUID *)theUUID;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSString *UUIDString;
@end

@class CBPeripheral, CBCharacteristic, CBDescriptor, CBService, CBCentral;
@interface CBAttribute : NSObject
@property (readonly, nonatomic) CBUUID *UUID;
@end
@interface CBService : CBAttribute
@property (weak, readonly, nonatomic, nullable) CBPeripheral *peripheral;
@property (readonly, nonatomic) BOOL isPrimary;
@property (readonly, nullable) NSArray<CBService *> *includedServices;
@property (readonly, nullable) NSArray<CBCharacteristic *> *characteristics;
@end
@interface CBMutableService : CBService
- (instancetype)initWithType:(CBUUID *)UUID primary:(BOOL)isPrimary;
@property (readwrite, nonatomic) CBUUID *UUID;
@property (readwrite, nonatomic) BOOL isPrimary;
@property (readwrite, nullable) NSArray<CBService *> *includedServices;
@property (readwrite, nullable) NSArray<CBCharacteristic *> *characteristics;
@end
@interface CBCharacteristic : CBAttribute
@property (weak, readonly, nullable) CBService *service;
@property (readonly, nonatomic) CBCharacteristicProperties properties;
@property (readonly, nullable) NSData *value;
@property (readonly, nullable) NSArray<CBDescriptor *> *descriptors;
@property (readonly) BOOL isNotifying;
@end
@interface CBMutableCharacteristic : CBCharacteristic
- (instancetype)initWithType:(CBUUID *)UUID properties:(CBCharacteristicProperties)properties value:(nullable NSData *)value permissions:(CBAttributePermissions)permissions;
@property (assign, readwrite, nonatomic) CBAttributePermissions permissions;
@property (readonly, nullable) NSArray<CBCentral *> *subscribedCentrals;
@property (readwrite, nonatomic) CBUUID *UUID;
@property (assign, readwrite, nonatomic) CBCharacteristicProperties properties;
@property (retain, readwrite, nullable) NSData *value;
@property (retain, readwrite, nullable) NSArray<CBDescriptor *> *descriptors;
@end
@interface CBDescriptor : CBAttribute
@property (weak, readonly, nullable) CBCharacteristic *characteristic;
@property (readonly, nullable) id value;
@end
@interface CBMutableDescriptor : CBDescriptor
- (instancetype)initWithType:(CBUUID *)UUID value:(nullable id)value;
@end

@interface CBPeer : NSObject
@property (readonly, nonatomic) NSUUID *identifier;
@end
@interface CBCentral : CBPeer
@property (readonly, nonatomic) NSUInteger maximumUpdateValueLength;
@end
@interface CBATTRequest : NSObject
@property (readonly, nonatomic) CBCentral *central;
@property (readonly, nonatomic) CBCharacteristic *characteristic;
@property (readonly, nonatomic) NSUInteger offset;
@property (readwrite, copy, nullable) NSData *value;
@end
@interface CBL2CAPChannel : NSObject
@property (readonly, nonatomic, nullable) CBPeer *peer;
@property (readonly, nonatomic, nullable) NSInputStream *inputStream;
@property (readonly, nonatomic, nullable) NSOutputStream *outputStream;
@property (readonly, nonatomic) CBL2CAPPSM PSM;
@end

@protocol CBPeripheralDelegate <NSObject>
@optional
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral;
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error;
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error;
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error;
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error;
- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral;
- (void)peripheral:(CBPeripheral *)peripheral didOpenL2CAPChannel:(nullable CBL2CAPChannel *)channel error:(nullable NSError *)error;
@end
@interface CBPeripheral : CBPeer
@property (weak, nonatomic, nullable) id<CBPeripheralDelegate> delegate;
@property (retain, readonly, nullable) NSString *name;
@property (readonly) CBPeripheralState state;
@property (retain, readonly, nullable) NSArray<CBService *> *services;
@property (readonly) BOOL canSendWriteWithoutResponse;
- (void)readRSSI;
- (void)discoverServices:(nullable NSArray<CBUUID *> *)serviceUUIDs;
- (void)discoverIncludedServices:(nullable NSArray<CBUUID *> *)includedServiceUUIDs forService:(CBService *)service;
- (void)discoverCharacteristics:(nullable NSArray<CBUUID *> *)characteristicUUIDs forService:(CBService *)service;
- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic;
- (NSUInteger)maximumWriteValueLengthForType:(CBCharacteristicWriteType)type;
- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type;
- (void)setNotifyValue:(BOOL)enabled forCharacteristic:(CBCharacteristic *)characteristic;
- (void)discoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic;
- (void)readValueForDescriptor:(CBDescriptor *)descriptor;
- (void)writeValue:(NSData *)data forDescriptor:(CBDescriptor *)descriptor;
- (void)openL2CAPChannel:(CBL2CAPPSM)PSM;
@end

@interface CBManager : NSObject
@property (nonatomic, assign, readonly) CBManagerState state;
@property (nonatomic, assign, readonly) CBManagerAuthorization authorization;
@property (class, nonatomic, assign, readonly) CBManagerAuthorization authorization;
@end

@class CBCentralManager;
@protocol CBCentralManagerDelegate <NSObject>
@required
- (void)centralManagerDidUpdateState:(CBCentralManager *)central;
@optional
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict;
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI;
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;
@end
@interface CBCentralManager : CBManager
@property (nonatomic, weak, nullable) id<CBCentralManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isScanning;
+ (BOOL)supportsFeatures:(CBCentralManagerFeature)features;
- (instancetype)init;
- (instancetype)initWithDelegate:(nullable id<CBCentralManagerDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
- (instancetype)initWithDelegate:(nullable id<CBCentralManagerDelegate>)delegate queue:(nullable dispatch_queue_t)queue options:(nullable NSDictionary<NSString *, id> *)options;
- (NSArray<CBPeripheral *> *)retrievePeripheralsWithIdentifiers:(NSArray<NSUUID *> *)identifiers;
- (NSArray<CBPeripheral *> *)retrieveConnectedPeripheralsWithServices:(NSArray<CBUUID *> *)serviceUUIDs;
- (void)scanForPeripheralsWithServices:(nullable NSArray<CBUUID *> *)serviceUUIDs options:(nullable NSDictionary<NSString *, id> *)options;
- (void)stopScan;
- (void)connectPeripheral:(CBPeripheral *)peripheral options:(nullable NSDictionary<NSString *, id> *)options;
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral;
@end

@class CBPeripheralManager;
@protocol CBPeripheralManagerDelegate <NSObject>
@required
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral;
@optional
- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary<NSString *, id> *)dict;
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error;
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic;
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests;
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didPublishL2CAPChannel:(CBL2CAPPSM)PSM error:(nullable NSError *)error;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didUnpublishL2CAPChannel:(CBL2CAPPSM)PSM error:(nullable NSError *)error;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didOpenL2CAPChannel:(nullable CBL2CAPChannel *)channel error:(nullable NSError *)error;
@end
@interface CBPeripheralManager : CBManager
@property (nonatomic, weak, nullable) id<CBPeripheralManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isAdvertising;
- (instancetype)init;
- (instancetype)initWithDelegate:(nullable id<CBPeripheralManagerDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
- (instancetype)initWithDelegate:(nullable id<CBPeripheralManagerDelegate>)delegate queue:(nullable dispatch_queue_t)queue options:(nullable NSDictionary<NSString *, id> *)options;
- (void)startAdvertising:(nullable NSDictionary<NSString *, id> *)advertisementData;
- (void)stopAdvertising;
- (void)setDesiredConnectionLatency:(CBPeripheralManagerConnectionLatency)latency forCentral:(CBCentral *)central;
- (void)addService:(CBMutableService *)service;
- (void)removeService:(CBMutableService *)service;
- (void)removeAllServices;
- (void)respondToRequest:(CBATTRequest *)request withResult:(CBATTError)result;
- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(nullable NSArray<CBCentral *> *)centrals;
- (void)publishL2CAPChannelWithEncryption:(BOOL)encryptionRequired;
- (void)unpublishL2CAPChannel:(CBL2CAPPSM)PSM;
@end

NS_ASSUME_NONNULL_END
#endif
