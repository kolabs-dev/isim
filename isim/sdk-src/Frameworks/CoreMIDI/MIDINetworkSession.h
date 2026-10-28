#pragma once
/* isim CoreMIDI: network MIDI (RTP-MIDI). The session has its own source and destination; contacts and connections
   are kept, but isim does not open network MIDI sessions with other hosts (no Bonjour MIDI service), so messages sent
   to the session's destination are not delivered anywhere. */
#import <Foundation/Foundation.h>
#include <CoreMIDI/MIDIServices.h>

NS_ASSUME_NONNULL_BEGIN

@class NSNetService;

FOUNDATION_EXPORT NSString * const MIDINetworkBonjourServiceType;
FOUNDATION_EXPORT NSString * const MIDINetworkNotificationContactsDidChange;
FOUNDATION_EXPORT NSString * const MIDINetworkNotificationSessionDidChange;

typedef NS_ENUM(NSUInteger, MIDINetworkConnectionPolicy) {
    MIDINetworkConnectionPolicy_NoOne = 0,
    MIDINetworkConnectionPolicy_HostsInContactList = 1,
    MIDINetworkConnectionPolicy_Anyone = 2,
};

@interface MIDINetworkHost : NSObject
+ (instancetype)hostWithName:(NSString *)name address:(NSString *)address port:(NSUInteger)port;
+ (instancetype)hostWithName:(NSString *)name netService:(NSNetService *)netService;
+ (instancetype)hostWithName:(NSString *)name netServiceName:(NSString *)netServiceName netServiceDomain:(NSString *)netServiceDomain;
- (BOOL)hasSameAddressAs:(MIDINetworkHost *)other;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, readonly, nullable) NSString *netServiceName;
@property (nonatomic, readonly, nullable) NSString *netServiceDomain;
@end

@interface MIDINetworkConnection : NSObject
+ (instancetype)connectionWithHost:(MIDINetworkHost *)host;
@property (nonatomic, readonly) MIDINetworkHost *host;
@end

@interface MIDINetworkSession : NSObject
+ (MIDINetworkSession *)defaultSession;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) NSUInteger networkPort;
@property (nonatomic, readonly) NSString *networkName;
@property (nonatomic, readonly) NSString *localName;
@property (nonatomic) MIDINetworkConnectionPolicy connectionPolicy;
- (NSSet<MIDINetworkHost *> *)contacts;
- (BOOL)addContact:(MIDINetworkHost *)contact;
- (BOOL)removeContact:(MIDINetworkHost *)contact;
- (NSSet<MIDINetworkConnection *> *)connections;
- (BOOL)addConnection:(MIDINetworkConnection *)connection;
- (BOOL)removeConnection:(MIDINetworkConnection *)connection;
- (MIDIEndpointRef)sourceEndpoint;
- (MIDIEndpointRef)destinationEndpoint;
@end

NS_ASSUME_NONNULL_END
