#pragma once
/* isim CoreMIDI: MIDI Capability Inquiry (MIDI-CI) over MIDI 1.0 system-exclusive messages (deprecated in iOS 18;
   MIDICIDeviceManager and MIDIUMPCIProfile replace it). No MIDI-CI device is connected to isim: discovery finds no
   node, and a responder answers nobody. Profiles, profile states and device info are values. */
#import <Foundation/Foundation.h>
#include <CoreMIDI/MIDIServices.h>
#include <CoreMIDI/MIDIMessages.h>

NS_ASSUME_NONNULL_BEGIN

typedef UInt8 MIDICIDeviceID;
static const MIDICIDeviceID kMIDIDeviceIDUMPGroup = 0x7E;
static const MIDICIDeviceID kMIDIDeviceIDFunctionBlock = 0x7F;
static const MIDIChannelNumber MIDIChannelsWholePort = 0x7F;
typedef MIDIUInteger28 MIDICIMUID;
typedef NSNumber *MIDICIInitiatiorMUID;

typedef UInt8 MIDICIPropertyExchangeRequestID NS_TYPED_EXTENSIBLE_ENUM;
static const MIDICIPropertyExchangeRequestID kMIDICIPropertyExchangeBadRequestID = 0xFF;

typedef struct MIDICIDeviceIdentification {
    UInt8 manufacturer[3];
    UInt8 family[2];
    UInt8 modelNumber[2];
    UInt8 revisionLevel[4];
    UInt8 reserved[5];
} MIDICIDeviceIdentification;

typedef struct MIDICIProfileIDStandard {
    MIDIUInteger7 profileIDByte1;
    MIDIUInteger7 profileBank;
    MIDIUInteger7 profileNumber;
    MIDIUInteger7 profileVersion;
    MIDIUInteger7 profileLevel;
} MIDICIProfileIDStandard;
typedef struct MIDICIProfileIDManufacturerSpecific {
    MIDIUInteger7 sysExID1;
    MIDIUInteger7 sysExID2;
    MIDIUInteger7 sysExID3;
    MIDIUInteger7 info1;
    MIDIUInteger7 info2;
} MIDICIProfileIDManufacturerSpecific;
typedef union MIDICIProfileID {
    MIDICIProfileIDStandard standard;
    MIDICIProfileIDManufacturerSpecific manufacturerSpecific;
} MIDICIProfileID;

typedef CF_ENUM(UInt8, MIDICIProfileType) {
    kMIDICIProfileTypeSingleChannel = 1,
    kMIDICIProfileTypeGroup = 2,
    kMIDICIProfileTypeFunctionBlock = 3,
    kMIDICIProfileTypeMultichannel = 4,
};
typedef CF_OPTIONS(MIDIUInteger7, MIDICICategoryOptions) {
    kMIDICICategoryOptionsNone = 0,
    kMIDICICategoryOptionsProtocolNegotiation = 1 << 1,
    kMIDICICategoryOptionsProfileConfigurationSupported = 1 << 2,
    kMIDICICategoryOptionsPropertyExchangeSupported = 1 << 3,
    kMIDICICategoryOptionsProcessInquirySupported = 1 << 4,
};
typedef CF_ENUM(UInt8, MIDICIDeviceType) {
    kMIDICIDeviceTypeUnknown = 0,
    kMIDICIDeviceTypeLegacyMIDI1 = 1,
    kMIDICIDeviceTypeVirtual = 2,
    kMIDICIDeviceTypeUSBMIDI = 3,
};
typedef CF_ENUM(UInt8, MIDICIManagementMessageType) {
    kMIDICIManagementMessageTypeDiscovery = 0x70,
    kMIDICIManagementMessageTypeReplyToDiscovery = 0x71,
    kMIDICIManagementMessageTypeInquiryEndpointInformation = 0x72,
    kMIDICIManagementMessageTypeReplyToEndpointInformation = 0x73,
    kMIDICIManagementMessageTypeMIDICIACK = 0x7D,
    kMIDICIManagementMessageTypeInvalidateMUID = 0x7E,
    kMIDICIManagementMessageTypeMIDICINAK = 0x7F,
};
typedef CF_ENUM(UInt8, MIDICIProfileMessageType) {
    kMIDICIProfileMessageTypeProfileInquiry = 0x20,
    kMIDICIProfileMessageTypeReplyToProfileInquiry = 0x21,
    kMIDICIProfileMessageTypeSetProfileOn = 0x22,
    kMIDICIProfileMessageTypeSetProfileOff = 0x23,
    kMIDICIProfileMessageTypeProfileEnabledReport = 0x24,
    kMIDICIProfileMessageTypeProfileDisabledReport = 0x25,
    kMIDICIProfileMessageTypeProfileAdded = 0x26,
    kMIDICIProfileMessageTypeProfileRemoved = 0x27,
    kMIDICIProfileMessageTypeDetailsInquiry = 0x28,
    kMIDICIProfileMessageTypeReplyToDetailsInquiry = 0x29,
    kMIDICIProfileMessageTypeProfileSpecificData = 0x2F,
};
typedef CF_ENUM(UInt8, MIDICIPropertyExchangeMessageType) {
    kMIDICIPropertyExchangeMessageTypeInquiryPropertyExchangeCapabilities = 0x30,
    kMIDICIPropertyExchangeMessageTypeReplyToPropertyExchangeCapabilities = 0x31,
    kMIDICIPropertyExchangeMessageTypeInquiryHasPropertyData_Reserved = 0x32,
    kMIDICIPropertyExchangeMessageTypeInquiryReplyToHasPropertyData_Reserved = 0x33,
    kMIDICIPropertyExchangeMessageTypeInquiryGetPropertyData = 0x34,
    kMIDICIPropertyExchangeMessageTypeReplyToGetProperty = 0x35,
    kMIDICIPropertyExchangeMessageTypeInquirySetPropertyData = 0x36,
    kMIDICIPropertyExchangeMessageTypeReplyToSetPropertyData = 0x37,
    kMIDICIPropertyExchangeMessageTypeSubscription = 0x38,
    kMIDICIPropertyExchangeMessageTypeReplyToSubscription = 0x39,
    kMIDICIPropertyExchangeMessageTypeNotify = 0x3F,
};
typedef CF_ENUM(UInt8, MIDICIProcessInquiryMessageType) {
    kMIDICIProcessInquiryMessageTypeInquiryProcessInquiryCapabilities = 0x40,
    kMIDICIProcessInquiryMessageTypeReplyToProcessInquiryCapabilities = 0x41,
    kMIDICIProcessInquiryMessageTypeInquiryMIDIMessageReport = 0x42,
    kMIDICIProcessInquiryMessageTypeReplyToMIDIMessageReport = 0x43,
    kMIDICIProcessInquiryMessageTypeEndOfMIDIMessageReport = 0x44,
};

@class MIDICISession, MIDICIProfile, MIDICIDiscoveredNode;

@interface MIDICIDeviceInfo : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDestination:(MIDIEntityRef)midiDestination manufacturer:(NSData *)manufacturer family:(NSData *)family
                              model:(NSData *)modelNumber revision:(NSData *)revisionLevel;
@property (nonatomic, readonly) NSData *manufacturerID;
@property (nonatomic, readonly) NSData *family;
@property (nonatomic, readonly) NSData *modelNumber;
@property (nonatomic, readonly) NSData *revisionLevel;
@property (nonatomic, readonly) MIDIEndpointRef midiDestination;
@end

@interface MIDICIProfile : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithData:(NSData *)data name:(NSString *)inName;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSData *profileID;
@end

@interface MIDICIProfileState : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithChannel:(MIDIChannelNumber)midiChannelNum enabledProfiles:(NSArray<MIDICIProfile *> *)enabled
               disabledProfiles:(NSArray<MIDICIProfile *> *)disabled;
- (instancetype)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled;
@property (nonatomic, readonly) MIDIChannelNumber midiChannel;
@property (nonatomic, readonly) NSArray<MIDICIProfile *> *enabledProfiles;
@property (nonatomic, readonly) NSArray<MIDICIProfile *> *disabledProfiles;
@end

typedef void (^MIDICIDiscoveryResponseBlock)(NSArray<MIDICIDiscoveredNode *> *discoveredNodes);
typedef void (^MIDICISessionDisconnectBlock)(MIDICISession *session, NSError *error);
typedef void (^MIDICIProfileChangedBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, BOOL enabled);
typedef void (^MIDICIProfileSpecificDataBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, NSData *profileSpecificData);

@interface MIDICIDiscoveredNode : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) MIDIEntityRef destination;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
@property (nonatomic, readonly) BOOL supportsProfiles;
@property (nonatomic, readonly) BOOL supportsProperties;
@property (nonatomic, readonly) NSNumber *maximumSysExSize;
@end

@interface MIDICIDiscoveryManager : NSObject
+ (MIDICIDiscoveryManager *)sharedInstance;
- (void)discoverWithHandler:(MIDICIDiscoveryResponseBlock)completedHandler;
@end

@interface MIDICISession : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDiscoveredNode:(MIDICIDiscoveredNode *)discoveredNode dataReadyHandler:(void (^)(void))handler
                     disconnectHandler:(MIDICISessionDisconnectBlock)disconnectHandler;
@property (nonatomic, readonly) MIDIEntityRef midiDestination;
@property (nonatomic, readonly) BOOL supportsProfileCapability;
@property (nonatomic, readonly) BOOL supportsPropertyCapability;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
@property (nonatomic, readonly) NSNumber *maxSysExSize;
@property (nonatomic, readonly) NSNumber *maxPropertyRequests;
- (MIDICIProfileState *)profileStateForChannel:(MIDIChannelNumber)channel;
- (BOOL)enableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError;
- (BOOL)disableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError;
- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData;
@property (nonatomic, nullable) MIDICIProfileChangedBlock profileChangedCallback;
@property (nonatomic, nullable) MIDICIProfileSpecificDataBlock profileSpecificDataHandler;
@end

@protocol MIDICIProfileResponderDelegate <NSObject>
@required
- (BOOL)connectInitiator:(MIDICIInitiatiorMUID)initiatorMUID withDeviceInfo:(MIDICIDeviceInfo *)deviceInfo;
- (void)initiatorDisconnected:(MIDICIInitiatiorMUID)initiatorMUID;
@optional
- (BOOL)willSetProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel enabled:(BOOL)shouldEnable;
- (void)handleDataForProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel data:(NSData *)inData;
@end

@interface MIDICIResponder : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDeviceInfo:(MIDICIDeviceInfo *)deviceInfo profileDelegate:(id<MIDICIProfileResponderDelegate>)delegate
                     profileStates:(NSArray<MIDICIProfileState *> *)profileList supportProperties:(BOOL)propertiesSupported;
@property (nonatomic, readonly) NSArray<MIDICIInitiatiorMUID> *initiators;
@property (nonatomic, readonly, retain) id<MIDICIProfileResponderDelegate> profileDelegate;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
- (BOOL)notifyProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel isEnabled:(BOOL)enabledState;
- (BOOL)sendProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData;
- (BOOL)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
