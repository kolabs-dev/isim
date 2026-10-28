// isim CoreMIDI: the Objective-C classes. Network MIDI keeps its contacts and connections but reaches no host; MIDI-CI
// finds no device (none is connected to isim); UMP endpoints the app creates are virtual sources and destinations of
// the MIDI server, listed by MIDIUMPEndpointManager.
#import "MIDIPrivate.h"

NSString * const MIDINetworkBonjourServiceType = @"_apple-midi._udp";
NSString * const MIDINetworkNotificationContactsDidChange = @"MIDINetworkNotificationContactsDidChange";
NSString * const MIDINetworkNotificationSessionDidChange = @"MIDINetworkNotificationSessionDidChange";
MIDIUMPEndpointManagerDictionaryKey const MIDIUMPEndpointObjectKey = @"MIDIUMPEndpointObjectKey";
MIDIUMPEndpointManagerDictionaryKey const MIDIUMPFunctionBlockObjectKey = @"MIDIUMPFunctionBlockObjectKey";
NSNotificationName const MIDIUMPEndpointWasAddedNotification = @"MIDIUMPEndpointWasAddedNotification";
NSNotificationName const MIDIUMPEndpointWasRemovedNotification = @"MIDIUMPEndpointWasRemovedNotification";
NSNotificationName const MIDIUMPEndpointWasUpdatedNotification = @"MIDIUMPEndpointWasUpdatedNotification";
NSNotificationName const MIDIUMPFunctionBlockWasUpdatedNotification = @"MIDIUMPFunctionBlockWasUpdatedNotification";
MIDICIDeviceManagerDictionaryKey const MIDICIDeviceObjectKey = @"MIDICIDeviceObjectKey";
MIDICIDeviceManagerDictionaryKey const MIDICIProfileObjectKey = @"MIDICIProfileObjectKey";
NSNotificationName const MIDICIDeviceWasAddedNotification = @"MIDICIDeviceWasAddedNotification";
NSNotificationName const MIDICIDeviceWasRemovedNotification = @"MIDICIDeviceWasRemovedNotification";
NSNotificationName const MIDICIProfileWasUpdatedNotification = @"MIDICIProfileWasUpdatedNotification";
NSNotificationName const MIDICIProfileWasRemovedNotification = @"MIDICIProfileWasRemovedNotification";

static NSError *midiError(OSStatus code, NSString *what) {
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: what }];
}

// MARK: - network MIDI

@implementation MIDINetworkHost
+ (instancetype)hostWithName:(NSString *)name address:(NSString *)address port:(NSUInteger)port {
    MIDINetworkHost *h = [self new];
    h->_name = [name copy]; h->_address = [address copy]; h->_port = port;
    return h;
}
+ (instancetype)hostWithName:(NSString *)name netService:(NSNetService *)netService {
    // isim has no NSNetService (deprecated since iOS 16): an object with its keys is read
    id s = (id)netService;
    NSInteger port = [[s valueForKey:@"port"] integerValue];
    MIDINetworkHost *h = [self hostWithName:name address:[s valueForKey:@"hostName"] ?: @"" port:port > 0 ? (NSUInteger)port : 0];
    h->_netServiceName = [[s valueForKey:@"name"] copy]; h->_netServiceDomain = [[s valueForKey:@"domain"] copy];
    return h;
}
+ (instancetype)hostWithName:(NSString *)name netServiceName:(NSString *)netServiceName netServiceDomain:(NSString *)netServiceDomain {
    MIDINetworkHost *h = [self hostWithName:name address:@"" port:0];
    h->_netServiceName = [netServiceName copy]; h->_netServiceDomain = [netServiceDomain copy];
    return h;
}
- (BOOL)hasSameAddressAs:(MIDINetworkHost *)other {
    if (_netServiceName.length || other.netServiceName.length)
        return [_netServiceName isEqualToString:other.netServiceName] && [(_netServiceDomain ?: @"") isEqualToString:other.netServiceDomain ?: @""];
    return [_address isEqualToString:other.address] && _port == other.port;
}
- (BOOL)isEqual:(id)object { return [object isKindOfClass:MIDINetworkHost.class] && [self hasSameAddressAs:object] && [_name isEqualToString:[object name]]; }
- (NSUInteger)hash { return _name.hash ^ _address.hash ^ _port; }
@end

@implementation MIDINetworkConnection
+ (instancetype)connectionWithHost:(MIDINetworkHost *)host { MIDINetworkConnection *c = [self new]; c->_host = host; return c; }
- (BOOL)isEqual:(id)object { return [object isKindOfClass:MIDINetworkConnection.class] && [_host isEqual:[object host]]; }
- (NSUInteger)hash { return _host.hash; }
@end

@implementation MIDINetworkSession {
    NSMutableSet<MIDINetworkHost *> *_contacts;
    NSMutableSet<MIDINetworkConnection *> *_connections;
    MIDIEndpointRef _source, _destination;
}
+ (MIDINetworkSession *)defaultSession {
    static MIDINetworkSession *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [MIDINetworkSession new]; });
    return s;
}
- (instancetype)init {
    if ((self = [super init])) {
        _contacts = [NSMutableSet set]; _connections = [NSMutableSet set];
        _connectionPolicy = MIDINetworkConnectionPolicy_NoOne;
        _localName = [NSString stringWithFormat:@"%@", NSProcessInfo.processInfo.hostName];
        _networkName = _localName;
        _networkPort = 5004;
        // the session's endpoints: a network device with one entity
        MIDIDeviceRef dev; MIDIEntityRef ent;
        MIDIDeviceCreate(NULL, CFSTR("Network"), CFSTR("Apple Inc."), CFSTR("Network MIDI"), &dev);
        MIDIDeviceNewEntity(dev, CFSTR("Session 1"), kMIDIProtocol_1_0, false, 1, 1, &ent);
        MIDIObjectSetIntegerProperty(dev, kMIDIPropertyOffline, 1);
        MIDISetupAddDevice(dev);
        _source = MIDIEntityGetSource(ent, 0); _destination = MIDIEntityGetDestination(ent, 0);
    }
    return self;
}
- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) return;
    _enabled = enabled;
    MIDIEntityRef ent; MIDIDeviceRef dev;
    if (MIDIEndpointGetEntity(_source, &ent) == noErr && MIDIEntityGetDevice(ent, &dev) == noErr)
        MIDIObjectSetIntegerProperty(dev, kMIDIPropertyOffline, enabled ? 0 : 1);
    [NSNotificationCenter.defaultCenter postNotificationName:MIDINetworkNotificationSessionDidChange object:self];
}
- (NSSet<MIDINetworkHost *> *)contacts { @synchronized (self) { return [_contacts copy]; } }
- (BOOL)addContact:(MIDINetworkHost *)contact {
    @synchronized (self) { [_contacts addObject:contact]; }
    [NSNotificationCenter.defaultCenter postNotificationName:MIDINetworkNotificationContactsDidChange object:self];
    return YES;
}
- (BOOL)removeContact:(MIDINetworkHost *)contact {
    BOOL had;
    @synchronized (self) { had = [_contacts containsObject:contact]; [_contacts removeObject:contact]; }
    if (had) [NSNotificationCenter.defaultCenter postNotificationName:MIDINetworkNotificationContactsDidChange object:self];
    return had;
}
- (NSSet<MIDINetworkConnection *> *)connections { @synchronized (self) { return [_connections copy]; } }
- (BOOL)addConnection:(MIDINetworkConnection *)connection {
    @synchronized (self) { [_connections addObject:connection]; }
    [NSNotificationCenter.defaultCenter postNotificationName:MIDINetworkNotificationSessionDidChange object:self];
    return YES;
}
- (BOOL)removeConnection:(MIDINetworkConnection *)connection {
    BOOL had;
    @synchronized (self) { had = [_connections containsObject:connection]; [_connections removeObject:connection]; }
    if (had) [NSNotificationCenter.defaultCenter postNotificationName:MIDINetworkNotificationSessionDidChange object:self];
    return had;
}
- (MIDIEndpointRef)sourceEndpoint { return _source; }
- (MIDIEndpointRef)destinationEndpoint { return _destination; }
@end

// MARK: - MIDI-CI over system-exclusive messages (deprecated)

@implementation MIDICIDeviceInfo
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithDestination:(MIDIEntityRef)midiDestination manufacturer:(NSData *)manufacturer family:(NSData *)family
                              model:(NSData *)modelNumber revision:(NSData *)revisionLevel {
    if ((self = [super init])) {
        _midiDestination = midiDestination; _manufacturerID = [manufacturer copy]; _family = [family copy];
        _modelNumber = [modelNumber copy]; _revisionLevel = [revisionLevel copy];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInt32:(int32_t)_midiDestination forKey:@"destination"]; [c encodeObject:_manufacturerID forKey:@"manufacturer"];
    [c encodeObject:_family forKey:@"family"]; [c encodeObject:_modelNumber forKey:@"model"]; [c encodeObject:_revisionLevel forKey:@"revision"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithDestination:(MIDIEntityRef)[c decodeInt32ForKey:@"destination"]
                        manufacturer:[c decodeObjectOfClass:NSData.class forKey:@"manufacturer"] ?: [NSData data]
                              family:[c decodeObjectOfClass:NSData.class forKey:@"family"] ?: [NSData data]
                               model:[c decodeObjectOfClass:NSData.class forKey:@"model"] ?: [NSData data]
                            revision:[c decodeObjectOfClass:NSData.class forKey:@"revision"] ?: [NSData data]];
}
@end

@implementation MIDICIProfile
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithData:(NSData *)data { return [self initWithData:data name:@""]; }
- (instancetype)initWithData:(NSData *)data name:(NSString *)inName {
    if ((self = [super init])) { _profileID = [data copy]; _name = [inName copy]; }
    return self;
}
- (BOOL)isEqual:(id)object { return [object isKindOfClass:MIDICIProfile.class] && [_profileID isEqualToData:((MIDICIProfile *)object).profileID]; }
- (NSUInteger)hash { return _profileID.hash; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_profileID forKey:@"id"]; [c encodeObject:_name forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithData:[c decodeObjectOfClass:NSData.class forKey:@"id"] ?: [NSData data] name:[c decodeObjectOfClass:NSString.class forKey:@"name"] ?: @""];
}
@end

@implementation MIDICIProfileState
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithChannel:(MIDIChannelNumber)midiChannelNum enabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled {
    if ((self = [super init])) { _midiChannel = midiChannelNum; _enabledProfiles = [enabled copy]; _disabledProfiles = [disabled copy]; }
    return self;
}
- (instancetype)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled {
    return [self initWithChannel:MIDIChannelsWholePort enabledProfiles:enabled disabledProfiles:disabled];
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInt:_midiChannel forKey:@"channel"]; [c encodeObject:_enabledProfiles forKey:@"enabled"]; [c encodeObject:_disabledProfiles forKey:@"disabled"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSSet *cls = [NSSet setWithObjects:NSArray.class, MIDICIProfile.class, nil];
    return [self initWithChannel:(MIDIChannelNumber)[c decodeIntForKey:@"channel"]
                 enabledProfiles:[c decodeObjectOfClasses:cls forKey:@"enabled"] ?: @[]
                disabledProfiles:[c decodeObjectOfClasses:cls forKey:@"disabled"] ?: @[]];
}
@end

@implementation MIDICIDiscoveredNode
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_deviceInfo forKey:@"deviceInfo"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _deviceInfo = [c decodeObjectOfClass:MIDICIDeviceInfo.class forKey:@"deviceInfo"];
        _destination = _deviceInfo.midiDestination;
        _maximumSysExSize = @0;
    }
    return self;
}
@end

@implementation MIDICIDiscoveryManager
+ (MIDICIDiscoveryManager *)sharedInstance {
    static MIDICIDiscoveryManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [MIDICIDiscoveryManager new]; });
    return m;
}
- (void)discoverWithHandler:(MIDICIDiscoveryResponseBlock)completedHandler {
    // no MIDI-CI device answers on isim: discovery ends with no nodes after the specification's three-second wait
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ completedHandler(@[]); });
}
@end

@implementation MIDICISession {
    MIDICISessionDisconnectBlock _disconnect;
}
- (instancetype)initWithDiscoveredNode:(MIDICIDiscoveredNode *)discoveredNode dataReadyHandler:(void (^)(void))handler
                     disconnectHandler:(MIDICISessionDisconnectBlock)disconnectHandler {
    if ((self = [super init])) {
        _midiDestination = discoveredNode.destination; _deviceInfo = discoveredNode.deviceInfo;
        _maxSysExSize = discoveredNode.maximumSysExSize ?: @0; _maxPropertyRequests = @0;
        _disconnect = [disconnectHandler copy];
        // the node does not answer: the session disconnects
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_disconnect) self->_disconnect(self, midiError(kMIDINoConnection, @"The MIDI-CI device did not answer"));
        });
    }
    return self;
}
- (MIDICIProfileState *)profileStateForChannel:(MIDIChannelNumber)channel {
    return [[MIDICIProfileState alloc] initWithChannel:channel enabledProfiles:@[] disabledProfiles:@[]];
}
- (BOOL)enableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError {
    if (outError) *outError = midiError(kMIDINoConnection, @"The MIDI-CI device is not connected");
    return NO;
}
- (BOOL)disableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError {
    if (outError) *outError = midiError(kMIDINoConnection, @"The MIDI-CI device is not connected");
    return NO;
}
- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData { return NO; }
@end

@implementation MIDICIResponder {
    NSArray<MIDICIProfileState *> *_states;
    BOOL _started;
}
- (instancetype)initWithDeviceInfo:(MIDICIDeviceInfo *)deviceInfo profileDelegate:(id<MIDICIProfileResponderDelegate>)delegate
                     profileStates:(NSArray<MIDICIProfileState *> *)profileList supportProperties:(BOOL)propertiesSupported {
    if ((self = [super init])) { _deviceInfo = deviceInfo; _profileDelegate = delegate; _states = [profileList copy]; }
    return self;
}
- (NSArray<MIDICIInitiatiorMUID> *)initiators { return @[]; }
- (BOOL)notifyProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel isEnabled:(BOOL)enabledState { return _started; }
- (BOOL)sendProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData { return _started; }
- (BOOL)start { _started = YES; return YES; }
- (void)stop { _started = NO; }
@end

// MARK: - UMP endpoints

@implementation MIDI2DeviceInfo
- (instancetype)initWithManufacturerID:(MIDI2DeviceManufacturer)manufacturerID family:(MIDIUInteger14)family
                           modelNumber:(MIDIUInteger14)modelNumber revisionLevel:(MIDI2DeviceRevisionLevel)revisionLevel {
    if ((self = [super init])) { _manufacturerID = manufacturerID; _family = family; _modelNumber = modelNumber; _revisionLevel = revisionLevel; }
    return self;
}
@end

@interface MIDIUMPEndpoint () {
@public
    NSString *_name, *_productInstanceID;
    MIDIProtocolID _MIDIProtocol;
    MIDIEndpointRef _MIDIDestination, _MIDISource;
    MIDI2DeviceInfo *_deviceInfo;
    BOOL _hasStaticFunctionBlocks;
    NSArray<MIDIUMPFunctionBlock *> *_functionBlocks;
}
- (instancetype)_isimInit;
@end
@implementation MIDIUMPEndpoint
- (instancetype)_isimInit { return [super init]; }
@synthesize name = _name, productInstanceID = _productInstanceID, MIDIProtocol = _MIDIProtocol, MIDIDestination = _MIDIDestination,
            MIDISource = _MIDISource, deviceInfo = _deviceInfo, hasStaticFunctionBlocks = _hasStaticFunctionBlocks, functionBlocks = _functionBlocks;
- (MIDIUMPProtocolOptions)supportedMIDIProtocols { return _MIDIProtocol == kMIDIProtocol_2_0 ? kMIDIUMPProtocolOptionsMIDI2 | kMIDIUMPProtocolOptionsMIDI1 : kMIDIUMPProtocolOptionsMIDI1; }
- (BOOL)hasJRTSReceiveCapability { return NO; }
- (BOOL)hasJRTSTransmitCapability { return NO; }
- (MIDIUMPCIObjectBackingType)endpointType { return kMIDIUMPCIObjectBackingTypeVirtual; }
@end

@interface MIDIUMPFunctionBlock () {
@public
    NSString *_name;
    MIDIUMPFunctionBlockID _functionBlockID;
    MIDIUMPFunctionBlockDirection _direction;
    MIDIUMPGroupNumber _firstGroup;
    MIDIUInteger7 _totalGroupsSpanned;
    UInt8 _maxSysEx8Streams;
    MIDIUMPFunctionBlockMIDI1Info _MIDI1Info;
    MIDIUMPFunctionBlockUIHint _UIHint;
    BOOL _enabled;
    __weak MIDIUMPEndpoint *_UMPEndpoint;
}
- (instancetype)_isimInit;
@end
@implementation MIDIUMPFunctionBlock
- (instancetype)_isimInit { return [super init]; }
@synthesize name = _name, functionBlockID = _functionBlockID, direction = _direction, firstGroup = _firstGroup,
            totalGroupsSpanned = _totalGroupsSpanned, maxSysEx8Streams = _maxSysEx8Streams, MIDI1Info = _MIDI1Info, UIHint = _UIHint,
            enabled = _enabled, UMPEndpoint = _UMPEndpoint;
- (MIDICIDevice *)midiCIDevice { return nil; }
@end

static NSMutableArray<MIDIUMPEndpoint *> *umpEndpoints;

@implementation MIDIUMPMutableFunctionBlock
@dynamic UMPEndpoint;
- (instancetype)initWithName:(NSString *)name direction:(MIDIUMPFunctionBlockDirection)direction firstGroup:(MIDIUMPGroupNumber)firstGroup
          totalGroupsSpanned:(MIDIUInteger7)totalGroupsSpanned maxSysEx8Streams:(MIDIUInteger7)maxSysEx8Streams
                   MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info UIHint:(MIDIUMPFunctionBlockUIHint)UIHint isEnabled:(BOOL)isEnabled {
    if (firstGroup > 15 || totalGroupsSpanned < 1 || firstGroup + totalGroupsSpanned > 16) return nil;
    if ((self = [super _isimInit])) {
        _name = [name copy]; _direction = direction; _firstGroup = firstGroup; _totalGroupsSpanned = totalGroupsSpanned;
        _maxSysEx8Streams = maxSysEx8Streams; _MIDI1Info = MIDI1Info; _UIHint = UIHint; _enabled = isEnabled;
    }
    return self;
}
- (MIDIUMPMutableEndpoint *)UMPEndpoint { return (MIDIUMPMutableEndpoint *)_UMPEndpoint; }
- (void)changed {
    MIDIUMPEndpoint *e = _UMPEndpoint;
    [NSNotificationCenter.defaultCenter postNotificationName:MIDIUMPFunctionBlockWasUpdatedNotification object:nil
                                                    userInfo:@{ MIDIUMPFunctionBlockObjectKey: self, MIDIUMPEndpointObjectKey: e ?: (id)NSNull.null }];
}
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error {
    if (_UMPEndpoint.hasStaticFunctionBlocks) { if (error) *error = midiError(kMIDINotPermitted, @"The function blocks are static"); return NO; }
    _enabled = isEnabled; [self changed];
    return YES;
}
- (BOOL)setName:(NSString *)name error:(NSError **)error {
    if (_UMPEndpoint.hasStaticFunctionBlocks) { if (error) *error = midiError(kMIDINotPermitted, @"The function blocks are static"); return NO; }
    _name = [name copy]; [self changed];
    return YES;
}
- (BOOL)reconfigureWithFirstGroup:(MIDIUMPGroupNumber)firstGroup direction:(MIDIUMPFunctionBlockDirection)direction
                        MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info UIHint:(MIDIUMPFunctionBlockUIHint)UIHint error:(NSError **)error {
    if (_UMPEndpoint.hasStaticFunctionBlocks || firstGroup + _totalGroupsSpanned > 16) {
        if (error) *error = midiError(kMIDINotPermitted, @"The function block cannot take this configuration");
        return NO;
    }
    _firstGroup = firstGroup; _direction = direction; _MIDI1Info = MIDI1Info; _UIHint = UIHint; [self changed];
    return YES;
}
@end

@implementation MIDIUMPMutableEndpoint {
    MIDIReceiveBlock _callback;
    MIDIClientRef _client;
    BOOL _enabledFlag;
}
- (instancetype)initWithName:(NSString *)name deviceInfo:(MIDI2DeviceInfo *)deviceInfo productInstanceID:(NSString *)productInstanceID
                MIDIProtocol:(MIDIProtocolID)MIDIProtocol destinationCallback:(MIDIReceiveBlock)destinationCallback {
    if (!name.length || productInstanceID.length > 42 || (MIDIProtocol != kMIDIProtocol_1_0 && MIDIProtocol != kMIDIProtocol_2_0)) return nil;
    if ((self = [super _isimInit])) {
        _name = [name copy]; _deviceInfo = deviceInfo; _productInstanceID = [productInstanceID copy]; _MIDIProtocol = MIDIProtocol;
        _callback = [destinationCallback copy]; _functionBlocks = @[]; _mutableFunctionBlocks = @[];
    }
    return self;
}
- (BOOL)isEnabled { return _enabledFlag; }
- (void)updated { [NSNotificationCenter.defaultCenter postNotificationName:MIDIUMPEndpointWasUpdatedNotification object:nil userInfo:@{ MIDIUMPEndpointObjectKey: self }]; }
- (BOOL)setName:(NSString *)name error:(NSError **)error {
    if (!name.length) { if (error) *error = midiError(kMIDIUnknownError, @"The name is empty"); return NO; }
    _name = [name copy];
    if (_MIDISource) { MIDIObjectSetStringProperty(_MIDISource, kMIDIPropertyName, (__bridge CFStringRef)_name); MIDIObjectSetStringProperty(_MIDIDestination, kMIDIPropertyName, (__bridge CFStringRef)_name); }
    [self updated];
    return YES;
}
- (BOOL)registerFunctionBlocks:(NSArray<MIDIUMPMutableFunctionBlock *> *)functionBlocks markAsStatic:(BOOL)markAsStatic error:(NSError **)error {
    if (_hasStaticFunctionBlocks || _enabledFlag || functionBlocks.count > 32) {
        if (error) *error = midiError(kMIDINotPermitted, _enabledFlag ? @"Register function blocks before enabling the endpoint" : @"The function blocks are static");
        return NO;
    }
    MIDIUMPFunctionBlockID i = 0;
    for (MIDIUMPMutableFunctionBlock *b in functionBlocks) { b->_functionBlockID = i++; b->_UMPEndpoint = self; }
    _functionBlocks = [functionBlocks copy]; _mutableFunctionBlocks = [functionBlocks copy];
    _hasStaticFunctionBlocks = markAsStatic;
    return YES;
}
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error {
    if (isEnabled == _enabledFlag) return YES;
    if (isEnabled) {
        MIDIClientRef client;
        MIDIClientCreate((__bridge CFStringRef)_name, NULL, NULL, &client);
        MIDIEndpointRef src, dst;
        OSStatus st = MIDISourceCreateWithProtocol(client, (__bridge CFStringRef)_name, _MIDIProtocol, &src);
        if (st == noErr) st = MIDIDestinationCreateWithProtocol(client, (__bridge CFStringRef)_name, _MIDIProtocol, &dst, _callback);
        if (st) { MIDIClientDispose(client); if (error) *error = midiError(st, @"The endpoint could not be created"); return NO; }
        _client = client; _MIDISource = src; _MIDIDestination = dst;
        MIDIObjectSetIntegerProperty(src, kMIDIPropertyAssociatedEndpoint, (SInt32)dst);
        MIDIObjectSetIntegerProperty(dst, kMIDIPropertyAssociatedEndpoint, (SInt32)src);
        _enabledFlag = YES;
        @synchronized (MIDIUMPEndpointManager.class) { if (!umpEndpoints) umpEndpoints = [NSMutableArray array]; [umpEndpoints addObject:self]; }
        [NSNotificationCenter.defaultCenter postNotificationName:MIDIUMPEndpointWasAddedNotification object:nil userInfo:@{ MIDIUMPEndpointObjectKey: self }];
    } else {
        MIDIClientDispose(_client);
        _client = 0; _MIDISource = 0; _MIDIDestination = 0;
        _enabledFlag = NO;
        @synchronized (MIDIUMPEndpointManager.class) { [umpEndpoints removeObject:self]; }
        [NSNotificationCenter.defaultCenter postNotificationName:MIDIUMPEndpointWasRemovedNotification object:nil userInfo:@{ MIDIUMPEndpointObjectKey: self }];
    }
    return YES;
}
@end

@implementation MIDIUMPEndpointManager
+ (MIDIUMPEndpointManager *)sharedInstance {
    static MIDIUMPEndpointManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [MIDIUMPEndpointManager new]; });
    return m;
}
- (NSArray<MIDIUMPEndpoint *> *)UMPEndpoints { @synchronized (MIDIUMPEndpointManager.class) { return [umpEndpoints copy] ?: @[]; } }
@end

@implementation MIDIUMPCIProfile
- (BOOL)setProfileState:(BOOL)isEnabled enabledChannelCount:(MIDIUInteger14)enabledChannelCount error:(NSError **)error {
    if (error) *error = midiError(kMIDINoConnection, @"The MIDI-CI device is not connected");
    return NO;
}
@end

@implementation MIDICIDevice
@end

@implementation MIDICIDeviceManager
+ (MIDICIDeviceManager *)sharedInstance {
    static MIDICIDeviceManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [MIDICIDeviceManager new]; });
    return m;
}
- (NSArray<MIDICIDevice *> *)discoveredCIDevices { return @[]; }
@end
