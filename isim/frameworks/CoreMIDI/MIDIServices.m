// isim CoreMIDI: the MIDI server, in the app's process (adapted). Objects (clients, ports, devices, entities,
// endpoints, thru connections) live in one table under one lock and are named by MIDIObjectRefs. Messages go through
// the delivery queue (a serial, high-priority dispatch queue, like CoreMIDI's MIDI thread), at their timestamps:
//  - to a client's destination: its read proc/block, or its receive block in the destination's protocol;
//  - to the simulated "isim MIDI" destination: logged ("CoreMIDI: isim MIDI received 90 3C 64");
//  - to a host ALSA port (MIDIHost.m);
//  - from a source (MIDIReceived): to the input ports connected to it and the thru connections from it.
// The `midi` script command (an app system event) sends messages from the isim MIDI source and takes the device
// offline or online. Messages convert between MIDI 1.0 bytes and Universal MIDI Packets (MIDIConvert.m).
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import "MIDIPrivate.h"
#include <mach/mach_time.h>
#include <pthread.h>

#define K(name) const CFStringRef name = CFSTR(#name);
K(kMIDIPropertyName) K(kMIDIPropertyManufacturer) K(kMIDIPropertyModel) K(kMIDIPropertyUniqueID) K(kMIDIPropertyDeviceID)
K(kMIDIPropertyReceiveChannels) K(kMIDIPropertyTransmitChannels) K(kMIDIPropertyMaxSysExSpeed)
K(kMIDIPropertyAdvanceScheduleTimeMuSec) K(kMIDIPropertyIsEmbeddedEntity) K(kMIDIPropertyIsBroadcast)
K(kMIDIPropertySingleRealtimeEntity) K(kMIDIPropertyConnectionUniqueID) K(kMIDIPropertyOffline) K(kMIDIPropertyPrivate)
K(kMIDIPropertyDriverOwner) K(kMIDIPropertyFactoryPatchNameFile) K(kMIDIPropertyUserPatchNameFile)
K(kMIDIPropertyNameConfiguration) K(kMIDIPropertyNameConfigurationDictionary) K(kMIDIPropertyImage)
K(kMIDIPropertyDriverVersion) K(kMIDIPropertySupportsGeneralMIDI) K(kMIDIPropertySupportsMMC) K(kMIDIPropertyCanRoute)
K(kMIDIPropertyReceivesClock) K(kMIDIPropertyReceivesMTC) K(kMIDIPropertyReceivesNotes) K(kMIDIPropertyReceivesProgramChanges)
K(kMIDIPropertyReceivesBankSelectMSB) K(kMIDIPropertyReceivesBankSelectLSB) K(kMIDIPropertyTransmitsClock)
K(kMIDIPropertyTransmitsMTC) K(kMIDIPropertyTransmitsNotes) K(kMIDIPropertyTransmitsProgramChanges)
K(kMIDIPropertyTransmitsBankSelectMSB) K(kMIDIPropertyTransmitsBankSelectLSB) K(kMIDIPropertyPanDisruptsStereo)
K(kMIDIPropertyIsSampler) K(kMIDIPropertyIsDrumMachine) K(kMIDIPropertyIsMixer) K(kMIDIPropertyIsEffectUnit)
K(kMIDIPropertyMaxReceiveChannels) K(kMIDIPropertyMaxTransmitChannels) K(kMIDIPropertyDriverDeviceEditorApp)
K(kMIDIPropertySupportsShowControl) K(kMIDIPropertyDisplayName) K(kMIDIPropertyProtocolID)
K(kMIDIPropertyUMPActiveGroupBitmap) K(kMIDIPropertyUMPCanTransmitGroupless) K(kMIDIPropertyAssociatedEndpoint)
K(kMIDIDriverPropertyUsesSerial)
#undef K

@implementation _MIDIObject
- (instancetype)init {
    if ((self = [super init])) { _props = [NSMutableDictionary dictionary]; _children = [NSMutableArray array]; _connections = [NSMutableDictionary dictionary]; }
    return self;
}
@end

static NSRecursiveLock *lock;
static NSMutableDictionary<NSNumber *, _MIDIObject *> *objects;
static NSMutableArray<_MIDIObject *> *devices, *externalDevices, *virtualSources, *virtualDestinations, *clients;
static MIDIObjectRef nextRef = 0x10000;
static dispatch_queue_t deliveryQueue;
static _MIDIObject *isimDevice;
static uint64_t flushGeneration;

dispatch_queue_t _MIDIDeliveryQueue(void) { return deliveryQueue; }
NSRecursiveLock *_MIDILock(void) { return lock; }

static void handleScriptEvent(NSString *text);

static pthread_t builder;      // the thread setting the server up, which uses the API itself

static void setUp(void) {
    static dispatch_once_t once;
    if (builder && pthread_equal(builder, pthread_self())) return;
    dispatch_once(&once, ^{
        builder = pthread_self();
        lock = [NSRecursiveLock new];
        objects = [NSMutableDictionary dictionary];
        devices = [NSMutableArray array]; externalDevices = [NSMutableArray array];
        virtualSources = [NSMutableArray array]; virtualDestinations = [NSMutableArray array]; clients = [NSMutableArray array];
        deliveryQueue = dispatch_queue_create("com.apple.coremidi.delivery", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
        // the simulated device: one entity with a source and a destination
        MIDIDeviceRef dev; MIDIEntityRef ent;
        MIDIDeviceCreate(NULL, CFSTR("isim MIDI"), CFSTR("isim"), CFSTR("Simulated MIDI Device"), &dev);
        MIDIDeviceNewEntity(dev, CFSTR("isim MIDI"), kMIDIProtocol_1_0, true, 1, 1, &ent);
        MIDISetupAddDevice(dev);
        isimDevice = _MIDILookup(dev, _MIDIKindDevice);
        isimDevice.props[@"isim.simulated"] = @YES;
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
            NSString *t = [n.object isKindOfClass:NSString.class] ? n.object : nil;
            if ([t hasPrefix:@"midi"]) handleScriptEvent(t);
        }];
        _MIDIHostStart();
        builder = 0;
    });
}

_MIDIObject *_MIDILookup(MIDIObjectRef ref, int kind) {
    setUp();
    [lock lock];
    _MIDIObject *o = objects[@(ref)];
    [lock unlock];
    return o && !o.disposed && (kind < 0 || o.kind == kind) ? o : nil;
}

static SInt32 newUniqueID(void) {
    for (;;) {
        SInt32 u = (SInt32)arc4random();
        if (u == kMIDIInvalidUniqueID) continue;
        BOOL used = NO;
        for (_MIDIObject *o in objects.allValues) if ([o.props[(__bridge NSString *)kMIDIPropertyUniqueID] intValue] == u) { used = YES; break; }
        if (!used) return u;
    }
}

_MIDIObject *_MIDINew(int kind, MIDIObjectType type, NSString *name) {
    setUp();
    [lock lock];
    _MIDIObject *o = [_MIDIObject new];
    o.ref = nextRef++;
    o.kind = kind; o.type = type;
    if (name) o.props[(__bridge NSString *)kMIDIPropertyName] = name;
    if (kind == _MIDIKindDevice || kind == _MIDIKindEntity || kind == _MIDIKindEndpoint)
        o.props[(__bridge NSString *)kMIDIPropertyUniqueID] = @(newUniqueID());
    objects[@(o.ref)] = o;
    [lock unlock];
    return o;
}

static void forget(_MIDIObject *o) {
    [lock lock];
    for (_MIDIObject *c in [o.children copy]) forget(c);
    [objects removeObjectForKey:@(o.ref)];
    o.disposed = YES;
    [lock unlock];
}

// MARK: - notifications

static void notifyAll(void (^make)(void (^send)(const MIDINotification *))) {
    [lock lock];
    NSArray *cs = [clients copy];
    [lock unlock];
    for (_MIDIObject *c in cs) {
        if (!c.notifyBlock && !c.notifyProc) continue;
        void (^deliver)(const MIDINotification *) = ^(const MIDINotification *m) {
            NSData *copy = [NSData dataWithBytes:m length:m->messageSize];
            MIDINotifyBlock b = c.notifyBlock; MIDINotifyProc p = c.notifyProc; void *refCon = c.notifyRefCon;
            void (^call)(void) = ^{
                if (c.disposed) return;
                if (b) b(copy.bytes); else p(copy.bytes, refCon);
            };
            CFRunLoopRef rl = c.runLoop;
            if (rl) { CFRunLoopPerformBlock(rl, kCFRunLoopCommonModes, call); CFRunLoopWakeUp(rl); }
            else dispatch_async(dispatch_get_main_queue(), call);
        };
        make(deliver);
    }
}

void _MIDINotifyAddRemove(BOOL added, _MIDIObject *parent, _MIDIObject *child) {
    notifyAll(^(void (^send)(const MIDINotification *)) {
        MIDIObjectAddRemoveNotification m = { added ? kMIDIMsgObjectAdded : kMIDIMsgObjectRemoved, sizeof m,
                                              parent ? parent.ref : 0, parent ? parent.type : kMIDIObjectType_Other,
                                              child.ref, child.type };
        send((const MIDINotification *)&m);
    });
}
void _MIDINotifySetupChanged(void) {
    notifyAll(^(void (^send)(const MIDINotification *)) {
        MIDINotification m = { kMIDIMsgSetupChanged, sizeof m };
        send(&m);
    });
}
static void notifyProperty(_MIDIObject *o, NSString *name) {
    notifyAll(^(void (^send)(const MIDINotification *)) {
        MIDIObjectPropertyChangeNotification m = { kMIDIMsgPropertyChanged, sizeof m, o.ref, o.type, (__bridge CFStringRef)name };
        send((const MIDINotification *)&m);
    });
}
void _MIDINotifyThruChanged(void) {
    notifyAll(^(void (^send)(const MIDINotification *)) {
        MIDINotification m = { kMIDIMsgThruConnectionsChanged, sizeof m };
        send(&m);
    });
}

// MARK: - clients

static OSStatus createClient(CFStringRef name, MIDINotifyProc proc, void *refCon, MIDINotifyBlock block, MIDIClientRef *out) {
    if (!name || !out) return kMIDIUnknownError;
    _MIDIObject *c = _MIDINew(_MIDIKindClient, kMIDIObjectType_Other, (__bridge NSString *)name);
    c.notifyProc = proc; c.notifyRefCon = refCon; c.notifyBlock = block;
    c.runLoop = CFRunLoopGetCurrent();
    [lock lock]; [clients addObject:c]; [lock unlock];
    *out = c.ref;
    return noErr;
}
OSStatus MIDIClientCreate(CFStringRef name, MIDINotifyProc notifyProc, void *notifyRefCon, MIDIClientRef *outClient) {
    return createClient(name, notifyProc, notifyRefCon, nil, outClient);
}
OSStatus MIDIClientCreateWithBlock(CFStringRef name, MIDIClientRef *outClient, MIDINotifyBlock notifyBlock) {
    return createClient(name, NULL, NULL, notifyBlock, outClient);
}
OSStatus MIDIClientDispose(MIDIClientRef client) {
    _MIDIObject *c = _MIDILookup(client, _MIDIKindClient);
    if (!c) return kMIDIInvalidClient;
    [lock lock];
    NSArray *owned = [objects.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(_MIDIObject *o, id _) { return o.client == client; }]];
    [lock unlock];
    for (_MIDIObject *o in owned) {
        if (o.kind == _MIDIKindEndpoint) MIDIEndpointDispose(o.ref);
        else if (o.kind == _MIDIKindPort) MIDIPortDispose(o.ref);
    }
    [lock lock]; [clients removeObject:c]; [lock unlock];
    forget(c);
    return noErr;
}

// MARK: - ports

static OSStatus createInputPort(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIReadProc proc, void *refCon,
                                MIDIReadBlock readBlock, MIDIReceiveBlock receiveBlock, MIDIPortRef *out) {
    if (!_MIDILookup(client, _MIDIKindClient)) return kMIDIInvalidClient;
    if (!out || !name) return kMIDIUnknownError;
    _MIDIObject *p = _MIDINew(_MIDIKindPort, kMIDIObjectType_Other, (__bridge NSString *)name);
    p.client = client; p.input = YES;
    p.protocol = receiveBlock ? protocol : 0;
    p.receiveProtocol = receiveBlock ? protocol : 0;
    p.readProc = proc; p.readRefCon = refCon; p.readBlock = readBlock; p.receiveBlock = receiveBlock;
    *out = p.ref;
    return noErr;
}
OSStatus MIDIInputPortCreateWithProtocol(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol, MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock) {
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0) return kMIDIUnknownError;
    return createInputPort(client, portName, protocol, NULL, NULL, nil, receiveBlock, outPort);
}
OSStatus MIDIInputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIReadProc readProc, void *refCon, MIDIPortRef *outPort) {
    return createInputPort(client, portName, 0, readProc, refCon, nil, nil, outPort);
}
OSStatus MIDIInputPortCreateWithBlock(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort, MIDIReadBlock readBlock) {
    return createInputPort(client, portName, 0, NULL, NULL, readBlock, nil, outPort);
}
OSStatus MIDIOutputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort) {
    if (!_MIDILookup(client, _MIDIKindClient)) return kMIDIInvalidClient;
    if (!outPort || !portName) return kMIDIUnknownError;
    _MIDIObject *p = _MIDINew(_MIDIKindPort, kMIDIObjectType_Other, (__bridge NSString *)portName);
    p.client = client;
    *outPort = p.ref;
    return noErr;
}
OSStatus MIDIPortDispose(MIDIPortRef port) {
    _MIDIObject *p = _MIDILookup(port, _MIDIKindPort);
    if (!p) return kMIDIInvalidPort;
    [lock lock];
    for (_MIDIObject *o in objects.allValues) [o.connections removeObjectForKey:@(port)];
    [lock unlock];
    forget(p);
    return noErr;
}
OSStatus MIDIPortConnectSource(MIDIPortRef port, MIDIEndpointRef source, void *connRefCon) {
    _MIDIObject *p = _MIDILookup(port, _MIDIKindPort);
    if (!p || !p.input) return kMIDIInvalidPort;
    _MIDIObject *s = _MIDILookup(source, _MIDIKindEndpoint);
    if (!s) return kMIDIUnknownEndpoint;
    if (!(s.type == kMIDIObjectType_Source || s.type == kMIDIObjectType_ExternalSource)) return kMIDIWrongEndpointType;
    [lock lock]; s.connections[@(port)] = [NSValue valueWithPointer:connRefCon]; [lock unlock];
    return noErr;
}
OSStatus MIDIPortDisconnectSource(MIDIPortRef port, MIDIEndpointRef source) {
    _MIDIObject *p = _MIDILookup(port, _MIDIKindPort);
    if (!p) return kMIDIInvalidPort;
    _MIDIObject *s = _MIDILookup(source, _MIDIKindEndpoint);
    if (!s) return kMIDIUnknownEndpoint;
    [lock lock];
    BOOL had = s.connections[@(port)] != nil;
    [s.connections removeObjectForKey:@(port)];
    [lock unlock];
    return had ? noErr : kMIDINoConnection;
}

// MARK: - devices, entities, endpoints

static BOOL online(_MIDIObject *o) {
    for (_MIDIObject *x = o; x; x = _MIDILookup(x.parent, -1))
        if ([x.props[(__bridge NSString *)kMIDIPropertyOffline] intValue]) return NO;
    return YES;
}
/* the endpoints of the devices in the setup and the virtual ones, as MIDIGetSource/MIDIGetDestination count them */
static NSArray<_MIDIObject *> *endpoints(BOOL sources) {
    [lock lock];
    NSMutableArray *a = [NSMutableArray array];
    for (_MIDIObject *d in devices) {
        if (!online(d)) continue;
        for (_MIDIObject *e in d.children) for (_MIDIObject *p in e.children)
            if (p.type == (sources ? kMIDIObjectType_Source : kMIDIObjectType_Destination)) [a addObject:p];
    }
    [a addObjectsFromArray:sources ? virtualSources : virtualDestinations];
    [lock unlock];
    return a;
}
ItemCount MIDIGetNumberOfDevices(void) { setUp(); [lock lock]; ItemCount n = devices.count; [lock unlock]; return n; }
MIDIDeviceRef MIDIGetDevice(ItemCount i) { setUp(); [lock lock]; MIDIDeviceRef r = i < devices.count ? devices[i].ref : 0; [lock unlock]; return r; }
ItemCount MIDIGetNumberOfExternalDevices(void) { setUp(); [lock lock]; ItemCount n = externalDevices.count; [lock unlock]; return n; }
MIDIDeviceRef MIDIGetExternalDevice(ItemCount i) { setUp(); [lock lock]; MIDIDeviceRef r = i < externalDevices.count ? externalDevices[i].ref : 0; [lock unlock]; return r; }
ItemCount MIDIDeviceGetNumberOfEntities(MIDIDeviceRef device) { return _MIDILookup(device, _MIDIKindDevice).children.count; }
MIDIEntityRef MIDIDeviceGetEntity(MIDIDeviceRef device, ItemCount i) {
    NSArray *c = _MIDILookup(device, _MIDIKindDevice).children;
    return i < c.count ? ((_MIDIObject *)c[i]).ref : 0;
}
static NSArray<_MIDIObject *> *entityEndpoints(MIDIEntityRef entity, BOOL sources) {
    _MIDIObject *e = _MIDILookup(entity, _MIDIKindEntity);
    NSMutableArray *a = [NSMutableArray array];
    for (_MIDIObject *p in e.children) if ((p.type & ~kMIDIObjectType_ExternalMask) == (sources ? kMIDIObjectType_Source : kMIDIObjectType_Destination)) [a addObject:p];
    return a;
}
ItemCount MIDIEntityGetNumberOfSources(MIDIEntityRef entity) { return entityEndpoints(entity, YES).count; }
MIDIEndpointRef MIDIEntityGetSource(MIDIEntityRef entity, ItemCount i) { NSArray *a = entityEndpoints(entity, YES); return i < a.count ? ((_MIDIObject *)a[i]).ref : 0; }
ItemCount MIDIEntityGetNumberOfDestinations(MIDIEntityRef entity) { return entityEndpoints(entity, NO).count; }
MIDIEndpointRef MIDIEntityGetDestination(MIDIEntityRef entity, ItemCount i) { NSArray *a = entityEndpoints(entity, NO); return i < a.count ? ((_MIDIObject *)a[i]).ref : 0; }
OSStatus MIDIEntityGetDevice(MIDIEntityRef inEntity, MIDIDeviceRef *outDevice) {
    _MIDIObject *e = _MIDILookup(inEntity, _MIDIKindEntity);
    if (!e) return kMIDIObjectNotFound;
    if (outDevice) *outDevice = e.parent;
    return noErr;
}
ItemCount MIDIGetNumberOfSources(void) { setUp(); return endpoints(YES).count; }
MIDIEndpointRef MIDIGetSource(ItemCount i) { setUp(); NSArray *a = endpoints(YES); return i < a.count ? ((_MIDIObject *)a[i]).ref : 0; }
ItemCount MIDIGetNumberOfDestinations(void) { setUp(); return endpoints(NO).count; }
MIDIEndpointRef MIDIGetDestination(ItemCount i) { setUp(); NSArray *a = endpoints(NO); return i < a.count ? ((_MIDIObject *)a[i]).ref : 0; }
OSStatus MIDIEndpointGetEntity(MIDIEndpointRef inEndpoint, MIDIEntityRef *outEntity) {
    _MIDIObject *p = _MIDILookup(inEndpoint, _MIDIKindEndpoint);
    if (!p) return kMIDIUnknownEndpoint;
    if (!p.parent) return kMIDIObjectNotFound;     // a virtual endpoint has no entity
    if (outEntity) *outEntity = p.parent;
    return noErr;
}

static OSStatus createVirtual(MIDIClientRef client, CFStringRef name, BOOL source, MIDIProtocolID protocol, MIDIReadProc proc, void *refCon,
                              MIDIReadBlock readBlock, MIDIReceiveBlock receiveBlock, MIDIEndpointRef *out) {
    if (!_MIDILookup(client, _MIDIKindClient)) return kMIDIInvalidClient;
    if (!name || !out) return kMIDIUnknownError;
    _MIDIObject *p = _MIDINew(_MIDIKindEndpoint, source ? kMIDIObjectType_Source : kMIDIObjectType_Destination, (__bridge NSString *)name);
    p.client = client; p.protocol = protocol ? protocol : kMIDIProtocol_1_0;
    p.props[(__bridge NSString *)kMIDIPropertyProtocolID] = @(p.protocol);
    p.readProc = proc; p.readRefCon = refCon; p.readBlock = readBlock; p.receiveBlock = receiveBlock;
    p.receiveProtocol = receiveBlock ? protocol : 0;
    [lock lock]; [(source ? virtualSources : virtualDestinations) addObject:p]; [lock unlock];
    _MIDINotifyAddRemove(YES, nil, p);
    _MIDINotifySetupChanged();
    *out = p.ref;
    return noErr;
}
OSStatus MIDIDestinationCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock) {
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0) return kMIDIUnknownError;
    return createVirtual(client, name, NO, protocol, NULL, NULL, nil, readBlock, outDest);
}
OSStatus MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon, MIDIEndpointRef *outDest) {
    return createVirtual(client, name, NO, kMIDIProtocol_1_0, readProc, refCon, nil, nil, outDest);
}
OSStatus MIDIDestinationCreateWithBlock(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outDest, MIDIReadBlock readBlock) {
    return createVirtual(client, name, NO, kMIDIProtocol_1_0, NULL, NULL, readBlock, nil, outDest);
}
OSStatus MIDISourceCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc) {
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0) return kMIDIUnknownError;
    return createVirtual(client, name, YES, protocol, NULL, NULL, nil, nil, outSrc);
}
OSStatus MIDISourceCreate(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outSrc) {
    return createVirtual(client, name, YES, kMIDIProtocol_1_0, NULL, NULL, nil, nil, outSrc);
}
OSStatus MIDIEndpointDispose(MIDIEndpointRef endpt) {
    _MIDIObject *p = _MIDILookup(endpt, _MIDIKindEndpoint);
    if (!p) return kMIDIUnknownEndpoint;
    if (!p.client) return kMIDIWrongEndpointType;     // a device's endpoints belong to its entity
    [lock lock]; [virtualSources removeObject:p]; [virtualDestinations removeObject:p]; [lock unlock];
    forget(p);
    _MIDINotifyAddRemove(NO, nil, p);
    _MIDINotifySetupChanged();
    return noErr;
}
OSStatus MIDIEndpointSetRefCons(MIDIEndpointRef endpt, void *ref1, void *ref2) {
    _MIDIObject *p = _MIDILookup(endpt, _MIDIKindEndpoint);
    if (!p) return kMIDIUnknownEndpoint;
    p.refCon1 = ref1; p.refCon2 = ref2;
    return noErr;
}
OSStatus MIDIEndpointGetRefCons(MIDIEndpointRef endpt, void **ref1, void **ref2) {
    _MIDIObject *p = _MIDILookup(endpt, _MIDIKindEndpoint);
    if (!p) return kMIDIUnknownEndpoint;
    if (ref1) *ref1 = p.refCon1;
    if (ref2) *ref2 = p.refCon2;
    return noErr;
}

// MARK: - the setup (MIDISetup.h, MIDIDriver.h)

OSStatus MIDIDeviceCreate(MIDIDriverRef owner, CFStringRef name, CFStringRef manufacturer, CFStringRef model, MIDIDeviceRef *outDevice) {
    if (!name || !outDevice) return kMIDIUnknownError;
    _MIDIObject *d = _MIDINew(_MIDIKindDevice, kMIDIObjectType_Device, (__bridge NSString *)name);
    if (manufacturer) d.props[(__bridge NSString *)kMIDIPropertyManufacturer] = (__bridge NSString *)manufacturer;
    if (model) d.props[(__bridge NSString *)kMIDIPropertyModel] = (__bridge NSString *)model;
    d.props[(__bridge NSString *)kMIDIPropertyOffline] = @0;
    d.driver = owner;
    *outDevice = d.ref;
    return noErr;
}
OSStatus MIDIExternalDeviceCreate(CFStringRef name, CFStringRef manufacturer, CFStringRef model, MIDIDeviceRef *outDevice) {
    OSStatus st = MIDIDeviceCreate(NULL, name, manufacturer, model, outDevice);
    if (st == noErr) _MIDILookup(*outDevice, _MIDIKindDevice).type = kMIDIObjectType_ExternalDevice;
    return st;
}
OSStatus MIDIDeviceDispose(MIDIDeviceRef device) {
    _MIDIObject *d = _MIDILookup(device, _MIDIKindDevice);
    if (!d) return kMIDIObjectNotFound;
    [lock lock]; BOOL inSetup = [devices containsObject:d] || [externalDevices containsObject:d]; [lock unlock];
    if (inSetup) return kMIDINotPermitted;          // remove it from the setup first
    forget(d);
    return noErr;
}
OSStatus MIDIDeviceNewEntity(MIDIDeviceRef device, CFStringRef name, MIDIProtocolID protocol, Boolean embedded,
                             ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity) {
    _MIDIObject *d = _MIDILookup(device, _MIDIKindDevice);
    if (!d) return kMIDIObjectNotFound;
    if (!name || !newEntity) return kMIDIUnknownError;
    BOOL external = d.type == kMIDIObjectType_ExternalDevice;
    _MIDIObject *e = _MIDINew(_MIDIKindEntity, external ? kMIDIObjectType_ExternalEntity : kMIDIObjectType_Entity, (__bridge NSString *)name);
    e.parent = d.ref; e.protocol = protocol;
    e.props[(__bridge NSString *)kMIDIPropertyIsEmbeddedEntity] = @(embedded ? 1 : 0);
    e.props[(__bridge NSString *)kMIDIPropertyProtocolID] = @(protocol);
    [lock lock]; [d.children addObject:e]; [lock unlock];
    MIDIEntityAddOrRemoveEndpoints(e.ref, numSourceEndpoints, numDestinationEndpoints);
    *newEntity = e.ref;
    [lock lock]; BOOL inSetup = [devices containsObject:d]; [lock unlock];
    if (inSetup) { _MIDINotifyAddRemove(YES, d, e); _MIDINotifySetupChanged(); }
    return noErr;
}
OSStatus MIDIDeviceAddEntity(MIDIDeviceRef device, CFStringRef name, Boolean embedded, ItemCount numSourceEndpoints,
                             ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity) {
    return MIDIDeviceNewEntity(device, name, kMIDIProtocol_1_0, embedded, numSourceEndpoints, numDestinationEndpoints, newEntity);
}
OSStatus MIDIDeviceRemoveEntity(MIDIDeviceRef device, MIDIEntityRef entity) {
    _MIDIObject *d = _MIDILookup(device, _MIDIKindDevice), *e = _MIDILookup(entity, _MIDIKindEntity);
    if (!d || !e || e.parent != device) return kMIDIObjectNotFound;
    [lock lock]; [d.children removeObject:e]; [lock unlock];
    forget(e);
    _MIDINotifyAddRemove(NO, d, e);
    _MIDINotifySetupChanged();
    return noErr;
}
OSStatus MIDIEntityAddOrRemoveEndpoints(MIDIEntityRef entity, ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints) {
    _MIDIObject *e = _MIDILookup(entity, _MIDIKindEntity);
    if (!e) return kMIDIObjectNotFound;
    BOOL external = e.type == kMIDIObjectType_ExternalEntity;
    for (int pass = 0; pass < 2; pass++) {
        MIDIObjectType t = (pass == 0 ? kMIDIObjectType_Source : kMIDIObjectType_Destination) | (external ? kMIDIObjectType_ExternalMask : 0);
        ItemCount want = pass == 0 ? numSourceEndpoints : numDestinationEndpoints;
        NSArray *have = entityEndpoints(entity, pass == 0);
        for (ItemCount i = have.count; i < want; i++) {
            _MIDIObject *p = _MIDINew(_MIDIKindEndpoint, t, nil);
            p.parent = e.ref; p.protocol = e.protocol ? e.protocol : kMIDIProtocol_1_0;
            [lock lock]; [e.children addObject:p]; [lock unlock];
        }
        for (ItemCount i = have.count; i > want; i--) {
            _MIDIObject *p = have[i - 1];
            [lock lock]; [e.children removeObject:p]; [lock unlock];
            forget(p);
        }
    }
    return noErr;
}
static OSStatus addTo(NSMutableArray *list, MIDIDeviceRef device, BOOL add) {
    _MIDIObject *d = _MIDILookup(device, _MIDIKindDevice);
    if (!d) return kMIDIObjectNotFound;
    [lock lock];
    BOOL has = [list containsObject:d];
    if (add && !has) [list addObject:d];
    if (!add) [list removeObject:d];
    [lock unlock];
    if (add == has) return add ? noErr : kMIDIObjectNotFound;
    _MIDINotifyAddRemove(add, nil, d);
    _MIDINotifySetupChanged();
    return noErr;
}
OSStatus MIDISetupAddDevice(MIDIDeviceRef device) { setUp(); return addTo(devices, device, YES); }
OSStatus MIDISetupRemoveDevice(MIDIDeviceRef device) { setUp(); return addTo(devices, device, NO); }
OSStatus MIDISetupAddExternalDevice(MIDIDeviceRef device) { setUp(); return addTo(externalDevices, device, YES); }
OSStatus MIDISetupRemoveExternalDevice(MIDIDeviceRef device) { setUp(); return addTo(externalDevices, device, NO); }

ItemCount MIDIDeviceListGetNumberOfDevices(MIDIDeviceListRef devList) { return _MIDILookup(devList, _MIDIKindDeviceList).children.count; }
MIDIDeviceRef MIDIDeviceListGetDevice(MIDIDeviceListRef devList, ItemCount i) {
    NSArray *c = _MIDILookup(devList, _MIDIKindDeviceList).children;
    return i < c.count ? ((_MIDIObject *)c[i]).ref : 0;
}
OSStatus MIDIDeviceListAddDevice(MIDIDeviceListRef devList, MIDIDeviceRef dev) {
    _MIDIObject *l = _MIDILookup(devList, _MIDIKindDeviceList), *d = _MIDILookup(dev, _MIDIKindDevice);
    if (!l || !d) return kMIDIObjectNotFound;
    [lock lock]; [l.children addObject:d]; [lock unlock];
    return noErr;
}
OSStatus MIDIDeviceListDispose(MIDIDeviceListRef devList) {
    _MIDIObject *l = _MIDILookup(devList, _MIDIKindDeviceList);
    if (!l) return kMIDIObjectNotFound;
    [lock lock]; [objects removeObjectForKey:@(l.ref)]; [lock unlock];
    return noErr;
}
MIDIDeviceListRef MIDIGetDriverDeviceList(MIDIDriverRef driver) {
    _MIDIObject *l = _MIDINew(_MIDIKindDeviceList, kMIDIObjectType_Other, nil);
    [lock lock];
    for (_MIDIObject *d in devices) if (d.driver == driver) [l.children addObject:d];
    [lock unlock];
    return l.ref;
}
OSStatus MIDIDriverEnableMonitoring(MIDIDriverRef driver, Boolean enabled) { return kMIDINotPermitted; }
CFRunLoopRef MIDIGetDriverIORunLoop(void) { return CFRunLoopGetMain(); }
OSStatus MIDIRestart(void) { setUp(); return noErr; }
OSStatus MIDIBluetoothDriverActivateAllConnections(void) { return noErr; }
OSStatus MIDIBluetoothDriverDisconnect(CFStringRef uuid) { return kMIDIObjectNotFound; }

// MARK: - properties

static NSString *displayName(_MIDIObject *o) {
    NSString *name = o.props[(__bridge NSString *)kMIDIPropertyName];
    if (o.kind != _MIDIKindEntity && o.kind != _MIDIKindEndpoint) return name;
    if (!name && o.kind == _MIDIKindEndpoint) name = _MIDILookup(o.parent, _MIDIKindEntity).props[(__bridge NSString *)kMIDIPropertyName];
    _MIDIObject *dev = o;
    while (dev && dev.kind != _MIDIKindDevice) dev = _MIDILookup(dev.parent, -1);
    NSString *devName = dev.props[(__bridge NSString *)kMIDIPropertyName];
    if (!devName) return name ?: @"";
    if (!name || [name isEqualToString:devName]) return devName;
    return [NSString stringWithFormat:@"%@ %@", devName, name];
}
/* a property, inherited from the entity and the device when the object does not have it */
static id property(_MIDIObject *o, NSString *key) {
    if ([key isEqualToString:(__bridge NSString *)kMIDIPropertyDisplayName]) return displayName(o);
    for (_MIDIObject *x = o; x; x = _MIDILookup(x.parent, -1)) {
        id v = x.props[key];
        if (v) return v;
        if ([key isEqualToString:(__bridge NSString *)kMIDIPropertyUniqueID] || [key isEqualToString:(__bridge NSString *)kMIDIPropertyName]) break;
    }
    return nil;
}
static OSStatus get(MIDIObjectRef obj, CFStringRef propertyID, Class cls, id *out) {
    _MIDIObject *o = _MIDILookup(obj, -1);
    if (!o) return kMIDIObjectNotFound;
    if (!propertyID) return kMIDIUnknownProperty;
    id v = property(o, (__bridge NSString *)propertyID);
    if (!v) return kMIDIUnknownProperty;
    if (![v isKindOfClass:cls]) return kMIDIWrongPropertyType;
    *out = v;
    return noErr;
}
static OSStatus set(MIDIObjectRef obj, CFStringRef propertyID, id value) {
    _MIDIObject *o = _MIDILookup(obj, -1);
    if (!o) return kMIDIObjectNotFound;
    if (!propertyID || !value) return kMIDIUnknownProperty;
    NSString *key = (__bridge NSString *)propertyID;
    if ([key isEqualToString:(__bridge NSString *)kMIDIPropertyDisplayName]) return kMIDINotPermitted;
    if ([key isEqualToString:(__bridge NSString *)kMIDIPropertyUniqueID]) {
        if (![value isKindOfClass:NSNumber.class]) return kMIDIWrongPropertyType;
        [lock lock];
        for (_MIDIObject *x in objects.allValues)
            if (x != o && [x.props[key] isEqual:value]) { [lock unlock]; return kMIDIIDNotUnique; }
        [lock unlock];
    }
    [lock lock]; o.props[key] = value; [lock unlock];
    notifyProperty(o, key);
    return noErr;
}
OSStatus MIDIObjectGetIntegerProperty(MIDIObjectRef obj, CFStringRef propertyID, SInt32 *outValue) {
    NSNumber *v; OSStatus st = get(obj, propertyID, NSNumber.class, &v);
    if (st == noErr && outValue) *outValue = v.intValue;
    return st;
}
OSStatus MIDIObjectSetIntegerProperty(MIDIObjectRef obj, CFStringRef propertyID, SInt32 value) {
    OSStatus st = set(obj, propertyID, @(value));
    if (st == noErr && CFEqual(propertyID, kMIDIPropertyOffline)) _MIDINotifySetupChanged();
    return st;
}
OSStatus MIDIObjectGetStringProperty(MIDIObjectRef obj, CFStringRef propertyID, CFStringRef *str) {
    NSString *v; OSStatus st = get(obj, propertyID, NSString.class, &v);
    if (str) *str = st == noErr ? (CFStringRef)CFBridgingRetain([v copy]) : NULL;
    return st;
}
OSStatus MIDIObjectSetStringProperty(MIDIObjectRef obj, CFStringRef propertyID, CFStringRef str) { return set(obj, propertyID, [(__bridge NSString *)str copy]); }
OSStatus MIDIObjectGetDataProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDataRef *outData) {
    NSData *v; OSStatus st = get(obj, propertyID, NSData.class, &v);
    if (outData) *outData = st == noErr ? (CFDataRef)CFBridgingRetain([v copy]) : NULL;
    return st;
}
OSStatus MIDIObjectSetDataProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDataRef data) { return set(obj, propertyID, [(__bridge NSData *)data copy]); }
OSStatus MIDIObjectGetDictionaryProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDictionaryRef *outDict) {
    NSDictionary *v; OSStatus st = get(obj, propertyID, NSDictionary.class, &v);
    if (outDict) *outDict = st == noErr ? (CFDictionaryRef)CFBridgingRetain([v copy]) : NULL;
    return st;
}
OSStatus MIDIObjectSetDictionaryProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDictionaryRef dict) { return set(obj, propertyID, [(__bridge NSDictionary *)dict copy]); }
OSStatus MIDIObjectRemoveProperty(MIDIObjectRef obj, CFStringRef propertyID) {
    _MIDIObject *o = _MIDILookup(obj, -1);
    if (!o) return kMIDIObjectNotFound;
    NSString *key = (__bridge NSString *)propertyID;
    [lock lock]; BOOL had = o.props[key] != nil; [o.props removeObjectForKey:key]; [lock unlock];
    if (!had) return kMIDIUnknownProperty;
    notifyProperty(o, key);
    return noErr;
}
static NSDictionary *allProperties(_MIDIObject *o, BOOL deep) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [lock lock];
    [o.props enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *_) { if (![k hasPrefix:@"isim."]) d[k] = v; }];
    if (deep && o.kind == _MIDIKindDevice) {
        NSMutableArray *ents = [NSMutableArray array];
        for (_MIDIObject *e in o.children) [ents addObject:allProperties(e, YES)];
        d[@"entities"] = ents;
    } else if (deep && o.kind == _MIDIKindEntity) {
        NSMutableArray *src = [NSMutableArray array], *dst = [NSMutableArray array];
        for (_MIDIObject *p in o.children)
            [((p.type & ~kMIDIObjectType_ExternalMask) == kMIDIObjectType_Source ? src : dst) addObject:allProperties(p, NO)];
        d[@"sources"] = src; d[@"destinations"] = dst;
    }
    [lock unlock];
    return d;
}
OSStatus MIDIObjectGetProperties(MIDIObjectRef obj, CFPropertyListRef *outProperties, Boolean deep) {
    _MIDIObject *o = _MIDILookup(obj, -1);
    if (!o) return kMIDIObjectNotFound;
    if (outProperties) *outProperties = CFBridgingRetain(allProperties(o, deep));
    return noErr;
}
OSStatus MIDIObjectFindByUniqueID(MIDIUniqueID uid, MIDIObjectRef *outObject, MIDIObjectType *outObjectType) {
    setUp();
    [lock lock];
    _MIDIObject *found = nil;
    for (_MIDIObject *o in objects.allValues)
        if ((o.kind == _MIDIKindDevice || o.kind == _MIDIKindEntity || o.kind == _MIDIKindEndpoint)
            && [o.props[(__bridge NSString *)kMIDIPropertyUniqueID] intValue] == uid) { found = o; break; }
    [lock unlock];
    if (outObject) *outObject = found ? found.ref : 0;
    if (outObjectType) *outObjectType = found ? found.type : kMIDIObjectType_Other;
    return found ? noErr : kMIDIObjectNotFound;
}

// MARK: - delivery

uint64_t _MIDINow(void) { return mach_absolute_time(); }

/* runs a block on the delivery queue at a host time (0: now) unless the destination is flushed first */
static void at(MIDITimeStamp t, _MIDIObject *dest, void (^block)(void)) {
    uint64_t now = _MIDINow(), gen = dest.flushGeneration;
    void (^run)(void) = ^{ if (dest.flushGeneration == gen && !dest.disposed) block(); };
    if (t <= now) { dispatch_async(deliveryQueue, run); return; }
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    uint64_t ns = (t - now) * tb.numer / tb.denom;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)ns), deliveryQueue, run);
}

/* a client's read callbacks with a list of messages: in bytes (packet list) or in UMP (event list) */
static void callReader(_MIDIObject *r, NSArray<_MIDIMessage *> *msgs, void *connRefCon, BOOL port) {
    if (r.receiveBlock) {
        MIDIProtocolID proto = r.receiveProtocol ? r.receiveProtocol : kMIDIProtocol_1_0;
        NSData *list = _MIDIEventListFromMessages(msgs, proto);
        if (list) r.receiveBlock(list.bytes, connRefCon);
    } else if (r.readBlock || r.readProc) {
        NSData *list = _MIDIPacketListFromMessages(msgs);
        if (!list) return;
        if (r.readBlock) r.readBlock(list.bytes, connRefCon);
        else r.readProc(list.bytes, port ? r.readRefCon : r.readRefCon, connRefCon);
    }
}

void _MIDIDeliverToSourceListeners(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs) {
    [lock lock];
    NSDictionary *conns = [src.connections copy];
    [lock unlock];
    [conns enumerateKeysAndObjectsUsingBlock:^(NSNumber *portRef, NSValue *refCon, BOOL *_) {
        _MIDIObject *p = _MIDILookup(portRef.unsignedIntValue, _MIDIKindPort);
        if (p && !p.disposed) callReader(p, msgs, refCon.pointerValue, YES);
    }];
    _MIDIThruDeliver(src, msgs);
}

void _MIDIDeliverToDestination(_MIDIObject *dest, NSArray<_MIDIMessage *> *msgs) {
    if (dest.client) { callReader(dest, msgs, NULL, NO); return; }
    _MIDIObject *dev = dest;
    while (dev && dev.kind != _MIDIKindDevice) dev = _MIDILookup(dev.parent, -1);
    if (dev == isimDevice) {
        NSMutableString *s = [NSMutableString string];
        for (_MIDIMessage *m in msgs) {
            NSData *bytes = m.bytes ?: _MIDIBytesFromWords(m.words);
            const uint8_t *b = bytes.bytes;
            for (NSUInteger i = 0; i < bytes.length; i++) [s appendFormat:@"%s%02X", s.length ? " " : "", b[i]];
        }
        if (s.length) NSLog(@"CoreMIDI: isim MIDI received %@", s);
    } else if (dev.props[@"isim.host"]) {
        for (_MIDIMessage *m in msgs) _MIDIHostSend(dest, m.bytes ?: _MIDIBytesFromWords(m.words));
    }
}

/* sends messages to a destination at their timestamps */
static void sendTo(_MIDIObject *dest, NSArray<_MIDIMessage *> *msgs) {
    if (!online(dest)) return;
    NSMutableDictionary<NSNumber *, NSMutableArray *> *byTime = [NSMutableDictionary dictionary];
    for (_MIDIMessage *m in msgs) {
        NSMutableArray *a = byTime[@(m.timeStamp)] ?: (byTime[@(m.timeStamp)] = [NSMutableArray array]);
        [a addObject:m];
    }
    for (NSNumber *t in [byTime.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray *batch = byTime[t];
        at(t.unsignedLongLongValue, dest, ^{ _MIDIDeliverToDestination(dest, batch); });
    }
}
static void receivedFrom(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs) {
    NSMutableDictionary<NSNumber *, NSMutableArray *> *byTime = [NSMutableDictionary dictionary];
    for (_MIDIMessage *m in msgs) {
        NSMutableArray *a = byTime[@(m.timeStamp)] ?: (byTime[@(m.timeStamp)] = [NSMutableArray array]);
        [a addObject:m];
    }
    for (NSNumber *t in [byTime.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray *batch = byTime[t];
        at(t.unsignedLongLongValue, src, ^{ _MIDIDeliverToSourceListeners(src, batch); });
    }
}

static OSStatus checkSend(MIDIPortRef port, MIDIEndpointRef dest, _MIDIObject **d) {
    _MIDIObject *p = _MIDILookup(port, _MIDIKindPort);
    if (!p || p.input) return kMIDIInvalidPort;
    *d = _MIDILookup(dest, _MIDIKindEndpoint);
    if (!*d) return kMIDIUnknownEndpoint;
    if (((*d).type & ~kMIDIObjectType_ExternalMask) != kMIDIObjectType_Destination) return kMIDIWrongEndpointType;
    return noErr;
}
OSStatus MIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIPacketList *pktlist) {
    _MIDIObject *d; OSStatus st = checkSend(port, dest, &d);
    if (st) return st;
    if (!pktlist) return kMIDIUnknownError;
    sendTo(d, _MIDIMessagesFromPacketList(pktlist));
    return noErr;
}
OSStatus MIDISendEventList(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist) {
    _MIDIObject *d; OSStatus st = checkSend(port, dest, &d);
    if (st) return st;
    if (!evtlist) return kMIDIUnknownError;
    sendTo(d, _MIDIMessagesFromEventList(evtlist));
    return noErr;
}
static OSStatus checkReceived(MIDIEndpointRef src, _MIDIObject **s) {
    *s = _MIDILookup(src, _MIDIKindEndpoint);
    if (!*s) return kMIDIUnknownEndpoint;
    if (((*s).type & ~kMIDIObjectType_ExternalMask) != kMIDIObjectType_Source) return kMIDIWrongEndpointType;
    return noErr;
}
OSStatus MIDIReceived(MIDIEndpointRef src, const MIDIPacketList *pktlist) {
    _MIDIObject *s; OSStatus st = checkReceived(src, &s);
    if (st) return st;
    if (!pktlist) return kMIDIUnknownError;
    receivedFrom(s, _MIDIMessagesFromPacketList(pktlist));
    return noErr;
}
OSStatus MIDIReceivedEventList(MIDIEndpointRef src, const MIDIEventList *evtlist) {
    _MIDIObject *s; OSStatus st = checkReceived(src, &s);
    if (st) return st;
    if (!evtlist) return kMIDIUnknownError;
    receivedFrom(s, _MIDIMessagesFromEventList(evtlist));
    return noErr;
}
void _MIDIReceivedMessages(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs) { receivedFrom(src, msgs); }
void _MIDISendMessages(_MIDIObject *dest, NSArray<_MIDIMessage *> *msgs) { sendTo(dest, msgs); }

OSStatus MIDIFlushOutput(MIDIEndpointRef dest) {
    setUp();
    [lock lock];
    NSArray *targets = dest ? @[] : endpoints(NO);
    _MIDIObject *d = dest ? objects[@(dest)] : nil;
    [lock unlock];
    if (dest && !d) return kMIDIUnknownEndpoint;
    for (_MIDIObject *o in d ? @[ d ] : targets) o.flushGeneration = ++flushGeneration;
    return noErr;
}

// MARK: - system-exclusive messages in the background

OSStatus MIDISendSysex(MIDISysexSendRequest *request) {
    if (!request || !request->data) return kMIDIUnknownError;
    _MIDIObject *d = _MIDILookup(request->destination, _MIDIKindEndpoint);
    if (!d) return kMIDIUnknownEndpoint;
    request->complete = false;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // in chunks, at about MIDI 1.0's 3125 bytes a second, unless cancelled (complete set by the app)
        while (request->bytesToSend > 0 && !request->complete) {
            UInt32 n = request->bytesToSend < 256 ? request->bytesToSend : 256;
            _MIDIMessage *m = [_MIDIMessage new];
            m.bytes = [NSData dataWithBytes:request->data length:n];
            sendTo(d, @[ m ]);
            request->data += n; request->bytesToSend -= n;
            usleep(n * 1000000 / 31250);
        }
        request->complete = true;
        if (request->completionProc) request->completionProc(request);
    });
    return noErr;
}
static OSStatus sendUMPSysex(MIDISysexSendRequestUMP *request) {
    if (!request || !request->words) return kMIDIUnknownError;
    _MIDIObject *d = _MIDILookup(request->destination, _MIDIKindEndpoint);
    if (!d) return kMIDIUnknownEndpoint;
    request->complete = false;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (request->wordsToSend > 0 && !request->complete) {
            UInt32 n = request->wordsToSend < 64 ? request->wordsToSend : 64;
            NSArray *msgs = _MIDIMessagesFromWords(request->words, n, 0);
            sendTo(d, msgs);
            request->words += n; request->wordsToSend -= n;
            usleep(n * 4 * 1000000 / 31250);
        }
        request->complete = true;
        if (request->completionProc) request->completionProc(request);
    });
    return noErr;
}
OSStatus MIDISendUMPSysex(MIDISysexSendRequestUMP *umpRequest) { return sendUMPSysex(umpRequest); }
OSStatus MIDISendUMPSysex8(MIDISysexSendRequestUMP *umpRequest) { return sendUMPSysex(umpRequest); }

// MARK: - the `midi` script command

static NSData *parseBytes(NSArray<NSString *> *words) {
    NSMutableData *d = [NSMutableData data];
    for (NSString *w in words) {
        unsigned v = 0;
        NSScanner *sc = [NSScanner scannerWithString:w];
        if (![sc scanHexInt:&v] || v > 0xFF) return nil;
        uint8_t b = (uint8_t)v;
        [d appendBytes:&b length:1];
    }
    return d;
}

static void handleScriptEvent(NSString *text) {
    NSArray<NSString *> *w = [[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                              filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSString *verb = w.count > 1 ? w[1] : @"";
    _MIDIObject *entity = isimDevice.children.firstObject;
    _MIDIObject *source = nil;
    for (_MIDIObject *p in entity.children) if (p.type == kMIDIObjectType_Source) source = p;
    if ([verb isEqualToString:@"send"] && w.count > 2) {
        // midi send 90 3C 64 [...]: bytes from the isim MIDI source (running status allowed)
        NSData *bytes = parseBytes([w subarrayWithRange:NSMakeRange(2, w.count - 2)]);
        if (!bytes) { NSLog(@"CoreMIDI: midi send: bytes are hexadecimal (90 3C 64)"); return; }
        if (!online(isimDevice)) { NSLog(@"CoreMIDI: midi send: isim MIDI is offline"); return; }
        receivedFrom(source, _MIDIMessagesFromBytes(bytes, 0));
        NSLog(@"CoreMIDI: isim MIDI sent %@", [[w subarrayWithRange:NSMakeRange(2, w.count - 2)] componentsJoinedByString:@" "].uppercaseString);
    } else if ([verb isEqualToString:@"note"] && w.count > 2) {
        // midi note NOTE [VELOCITY [CHANNEL]]: a note on, and its note off half a second later
        int note = w[2].intValue, vel = w.count > 3 ? w[3].intValue : 100, ch = w.count > 4 ? w[4].intValue - 1 : 0;
        if (note < 0 || note > 127 || vel < 1 || vel > 127 || ch < 0 || ch > 15) { NSLog(@"CoreMIDI: midi note NOTE [VELOCITY [CHANNEL 1-16]]"); return; }
        uint8_t on[3] = { (uint8_t)(0x90 | ch), (uint8_t)note, (uint8_t)vel }, off[3] = { (uint8_t)(0x80 | ch), (uint8_t)note, 0 };
        receivedFrom(source, _MIDIMessagesFromBytes([NSData dataWithBytes:on length:3], 0));
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        receivedFrom(source, _MIDIMessagesFromBytes([NSData dataWithBytes:off length:3], _MIDINow() + 500000000ull * tb.denom / tb.numer));
        NSLog(@"CoreMIDI: isim MIDI note %d velocity %d channel %d", note, vel, ch + 1);
    } else if ([verb isEqualToString:@"offline"] || [verb isEqualToString:@"online"]) {
        MIDIObjectSetIntegerProperty(isimDevice.ref, kMIDIPropertyOffline, [verb isEqualToString:@"offline"] ? 1 : 0);
        NSLog(@"CoreMIDI: isim MIDI is %@", verb);
    } else if ([verb isEqualToString:@"list"]) {
        NSMutableString *s = [NSMutableString string];
        for (ItemCount i = 0; i < MIDIGetNumberOfSources(); i++) [s appendFormat:@"\n  source %@", displayName(_MIDILookup(MIDIGetSource(i), -1))];
        for (ItemCount i = 0; i < MIDIGetNumberOfDestinations(); i++) [s appendFormat:@"\n  destination %@", displayName(_MIDILookup(MIDIGetDestination(i), -1))];
        NSLog(@"CoreMIDI: endpoints:%@", s.length ? s : @" none");
    } else {
        NSLog(@"CoreMIDI: midi send BYTES | note NOTE [VELOCITY [CHANNEL]] | offline | online | list");
    }
}
