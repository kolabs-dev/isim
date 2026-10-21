#pragma once
/* isim ExternalAccessory: like Apple's Simulator, no MFi accessory is ever connected: connectedAccessories is empty,
   EASession cannot open one, and the Bluetooth accessory picker completes with EABluetoothAccessoryPickerResultNotFound.
   The app needs UISupportedExternalAccessoryProtocols in its Info.plist to talk to accessories, as on iOS. */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

enum { EAConnectionIDNone = 0 };


FOUNDATION_EXPORT NSString * const EABluetoothAccessoryPickerErrorDomain;
typedef NS_ERROR_ENUM(EABluetoothAccessoryPickerErrorDomain, EABluetoothAccessoryPickerErrorCode) {
    EABluetoothAccessoryPickerAlreadyConnected = 0,
    EABluetoothAccessoryPickerResultNotFound = 1,
    EABluetoothAccessoryPickerResultCancelled = 2,
    EABluetoothAccessoryPickerResultFailed = 3,
};

FOUNDATION_EXPORT NSString * const EAAccessoryDidConnectNotification;
FOUNDATION_EXPORT NSString * const EAAccessoryDidDisconnectNotification;
FOUNDATION_EXPORT NSString * const EAAccessoryKey;
FOUNDATION_EXPORT NSString * const EAAccessorySelectedKey;

@class EAAccessory;
@protocol EAAccessoryDelegate <NSObject>
@optional
- (void)accessoryDidDisconnect:(EAAccessory *)accessory;
@end

@interface EAAccessory : NSObject
@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly) NSUInteger connectionID;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *dockType;
@property (nonatomic, readonly) NSArray<NSString *> *protocolStrings;
@property (nonatomic, weak, nullable) id<EAAccessoryDelegate> delegate;
@end

typedef void (^EABluetoothAccessoryPickerCompletion)(NSError * _Nullable error);

@interface EAAccessoryManager : NSObject
+ (EAAccessoryManager *)sharedAccessoryManager NS_SWIFT_NAME(shared());
- (void)showBluetoothAccessoryPickerWithNameFilter:(nullable NSPredicate *)predicate completion:(nullable EABluetoothAccessoryPickerCompletion)completion;
- (void)registerForLocalNotifications;
- (void)unregisterForLocalNotifications;
@property (nonatomic, readonly) NSArray<EAAccessory *> *connectedAccessories;
@end

@interface EASession : NSObject
- (nullable instancetype)initWithAccessory:(EAAccessory *)accessory forProtocol:(NSString *)protocolString;
@property (nonatomic, readonly, nullable) EAAccessory *accessory;
@property (nonatomic, readonly, nullable) NSString *protocolString;
@property (nonatomic, readonly, nullable) NSInputStream *inputStream;
@property (nonatomic, readonly, nullable) NSOutputStream *outputStream;
@end

NS_ASSUME_NONNULL_END
