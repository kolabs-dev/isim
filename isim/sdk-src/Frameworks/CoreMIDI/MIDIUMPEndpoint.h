#pragma once
/* isim CoreMIDI: UMP endpoints and function blocks (MIDI 2.0). A mutable endpoint is a virtual source and destination
   pair the app creates; MIDIUMPEndpointManager lists the endpoints in the app's MIDI server. */
#import <Foundation/Foundation.h>
#include <CoreMIDI/MIDIServices.h>
#include <CoreMIDI/MIDIMessages.h>
#import <CoreMIDI/MIDICapabilityInquiry.h>

NS_ASSUME_NONNULL_BEGIN

typedef CF_OPTIONS(MIDIUInteger4, MIDIUMPProtocolOptions) {
    kMIDIUMPProtocolOptionsMIDI1 = 1,
    kMIDIUMPProtocolOptionsMIDI2 = 1 << 1,
};
typedef CF_ENUM(UInt8, MIDIUMPCIObjectBackingType) {
    kMIDIUMPCIObjectBackingTypeUnknown = 0,
    kMIDIUMPCIObjectBackingTypeVirtual = 1,
    kMIDIUMPCIObjectBackingTypeDriverDevice = 2,
    kMIDIUMPCIObjectBackingTypeUSBMIDI = 3,
};

typedef struct MIDI2DeviceManufacturer { UInt8 sysExIDByte[3]; } MIDI2DeviceManufacturer;
typedef struct MIDI2DeviceRevisionLevel { UInt8 revisionLevel[4]; } MIDI2DeviceRevisionLevel;

@class MIDIUMPEndpoint, MIDIUMPFunctionBlock, MIDICIDevice, MIDIUMPMutableEndpoint;

@interface MIDI2DeviceInfo : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithManufacturerID:(MIDI2DeviceManufacturer)manufacturerID family:(MIDIUInteger14)family
                           modelNumber:(MIDIUInteger14)modelNumber revisionLevel:(MIDI2DeviceRevisionLevel)revisionLevel;
@property (nonatomic, readonly) MIDI2DeviceManufacturer manufacturerID;
@property (nonatomic, readonly) MIDIUInteger14 family;
@property (nonatomic, readonly) MIDIUInteger14 modelNumber;
@property (nonatomic, readonly) MIDI2DeviceRevisionLevel revisionLevel;
@end

@interface MIDIUMPEndpoint : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) MIDIProtocolID MIDIProtocol;
@property (nonatomic, readonly) MIDIUMPProtocolOptions supportedMIDIProtocols;
@property (nonatomic, readonly) MIDIEndpointRef MIDIDestination;
@property (nonatomic, readonly) MIDIEndpointRef MIDISource;
@property (nonatomic, readonly) MIDI2DeviceInfo *deviceInfo;
@property (nonatomic, readonly, copy) NSString *productInstanceID;
@property (nonatomic, readonly) BOOL hasStaticFunctionBlocks;
@property (nonatomic, readonly) BOOL hasJRTSReceiveCapability;
@property (nonatomic, readonly) BOOL hasJRTSTransmitCapability;
@property (nonatomic, readonly) MIDIUMPCIObjectBackingType endpointType;
@property (nonatomic, readonly, copy) NSArray<MIDIUMPFunctionBlock *> *functionBlocks;
@end

@interface MIDIUMPFunctionBlock : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) MIDIUMPFunctionBlockID functionBlockID;
@property (nonatomic, readonly) MIDIUMPFunctionBlockDirection direction;
@property (nonatomic, readonly) MIDIUMPGroupNumber firstGroup;
@property (nonatomic, readonly) MIDIUInteger7 totalGroupsSpanned;
@property (nonatomic, readonly) UInt8 maxSysEx8Streams;
@property (nonatomic, readonly) MIDIUMPFunctionBlockMIDI1Info MIDI1Info;
@property (nonatomic, readonly) MIDIUMPFunctionBlockUIHint UIHint;
@property (nonatomic, readonly, weak, nullable) MIDIUMPEndpoint *UMPEndpoint;
@property (nonatomic, readonly, weak, nullable) MIDICIDevice *midiCIDevice;
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@end

@interface MIDIUMPMutableFunctionBlock : MIDIUMPFunctionBlock
- (nullable instancetype)initWithName:(NSString *)name direction:(MIDIUMPFunctionBlockDirection)direction
                           firstGroup:(MIDIUMPGroupNumber)firstGroup totalGroupsSpanned:(MIDIUInteger7)totalGroupsSpanned
                     maxSysEx8Streams:(MIDIUInteger7)maxSysEx8Streams MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info
                               UIHint:(MIDIUMPFunctionBlockUIHint)UIHint isEnabled:(BOOL)isEnabled;
@property (nonatomic, readonly, weak, nullable) MIDIUMPMutableEndpoint *UMPEndpoint;
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error;
- (BOOL)setName:(NSString *)name error:(NSError **)error;
- (BOOL)reconfigureWithFirstGroup:(MIDIUMPGroupNumber)firstGroup direction:(MIDIUMPFunctionBlockDirection)direction
                        MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info UIHint:(MIDIUMPFunctionBlockUIHint)UIHint error:(NSError **)error;
@end

@interface MIDIUMPMutableEndpoint : MIDIUMPEndpoint
- (nullable instancetype)initWithName:(NSString *)name deviceInfo:(MIDI2DeviceInfo *)deviceInfo productInstanceID:(NSString *)productInstanceID
                         MIDIProtocol:(MIDIProtocolID)MIDIProtocol destinationCallback:(MIDIReceiveBlock)destinationCallback;
@property (nonatomic, copy) NSArray<MIDIUMPMutableFunctionBlock *> *mutableFunctionBlocks;
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
- (BOOL)setName:(NSString *)name error:(NSError **)error;
- (BOOL)registerFunctionBlocks:(NSArray<MIDIUMPMutableFunctionBlock *> *)functionBlocks markAsStatic:(BOOL)markAsStatic error:(NSError **)error;
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error;
@end

typedef NSString * MIDIUMPEndpointManagerDictionaryKey NS_TYPED_ENUM NS_SWIFT_NAME(MIDIUMPEndpointManager.DictionaryKey);
FOUNDATION_EXPORT MIDIUMPEndpointManagerDictionaryKey const MIDIUMPEndpointObjectKey NS_SWIFT_NAME(MIDIUMPEndpointManager.DictionaryKey.endpointObject);
FOUNDATION_EXPORT MIDIUMPEndpointManagerDictionaryKey const MIDIUMPFunctionBlockObjectKey NS_SWIFT_NAME(MIDIUMPEndpointManager.DictionaryKey.functionBlockObject);
FOUNDATION_EXPORT NSNotificationName const MIDIUMPEndpointWasAddedNotification NS_SWIFT_NAME(MIDIUMPEndpointManager.endpointWasAddedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDIUMPEndpointWasRemovedNotification NS_SWIFT_NAME(MIDIUMPEndpointManager.endpointWasRemovedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDIUMPEndpointWasUpdatedNotification NS_SWIFT_NAME(MIDIUMPEndpointManager.endpointWasUpdatedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDIUMPFunctionBlockWasUpdatedNotification NS_SWIFT_NAME(MIDIUMPEndpointManager.functionBlockWasUpdatedNotification);

@interface MIDIUMPEndpointManager : NSObject
@property (class, nonatomic, readonly) MIDIUMPEndpointManager *sharedInstance NS_SWIFT_NAME(shared);
@property (nonatomic, readonly, copy) NSArray<MIDIUMPEndpoint *> *UMPEndpoints;
@end

/* MIDI-CI devices and their profiles, over UMP */
@interface MIDIUMPCIProfile : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) MIDICIProfileID profileID;
@property (nonatomic, readonly) MIDICIProfileType profileType;
@property (nonatomic, readonly) MIDIUMPGroupNumber groupOffset;
@property (nonatomic, readonly) MIDIChannelNumber firstChannel;
@property (nonatomic, readonly) MIDIUInteger14 enabledChannelCount;
@property (nonatomic, readonly) MIDIUInteger14 totalChannelCount;
@property (nonatomic, readonly) BOOL isEnabled;
- (BOOL)setProfileState:(BOOL)isEnabled enabledChannelCount:(MIDIUInteger14)enabledChannelCount error:(NSError **)error;
@end

@interface MIDICIDevice : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) MIDI2DeviceInfo *deviceInfo;
@property (nonatomic, readonly) MIDICIMUID MUID;
@property (nonatomic, readonly) BOOL supportsProtocolNegotiation;
@property (nonatomic, readonly) BOOL supportsProfileConfiguration;
@property (nonatomic, readonly) BOOL supportsPropertyExchange;
@property (nonatomic, readonly) BOOL supportsProcessInquiry;
@property (nonatomic, readonly) NSUInteger maxSysExSize;
@property (nonatomic, readonly) NSUInteger maxPropertyExchangeRequests;
@property (nonatomic, readonly) MIDICIDeviceType deviceType;
@property (nonatomic, readonly, copy) NSArray<MIDIUMPCIProfile *> *profiles;
@end

typedef NSString * MIDICIDeviceManagerDictionaryKey NS_TYPED_ENUM NS_SWIFT_NAME(MIDICIDeviceManager.DictionaryKey);
FOUNDATION_EXPORT MIDICIDeviceManagerDictionaryKey const MIDICIDeviceObjectKey NS_SWIFT_NAME(MIDICIDeviceManager.DictionaryKey.deviceObject);
FOUNDATION_EXPORT MIDICIDeviceManagerDictionaryKey const MIDICIProfileObjectKey NS_SWIFT_NAME(MIDICIDeviceManager.DictionaryKey.profileObject);
FOUNDATION_EXPORT NSNotificationName const MIDICIDeviceWasAddedNotification NS_SWIFT_NAME(MIDICIDeviceManager.deviceWasAddedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDICIDeviceWasRemovedNotification NS_SWIFT_NAME(MIDICIDeviceManager.deviceWasRemovedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDICIProfileWasUpdatedNotification NS_SWIFT_NAME(MIDICIDeviceManager.profileWasUpdatedNotification);
FOUNDATION_EXPORT NSNotificationName const MIDICIProfileWasRemovedNotification NS_SWIFT_NAME(MIDICIDeviceManager.profileWasRemovedNotification);

@interface MIDICIDeviceManager : NSObject
@property (class, nonatomic, readonly) MIDICIDeviceManager *sharedInstance NS_SWIFT_NAME(shared);
@property (nonatomic, readonly, copy) NSArray<MIDICIDevice *> *discoveredCIDevices;
@end

NS_ASSUME_NONNULL_END
