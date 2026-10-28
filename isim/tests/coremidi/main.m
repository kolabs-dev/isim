// CoreMIDI from C and Objective-C (CoreMIDITest.app, issue #390): clients, ports, virtual endpoints, properties and
// their inheritance, errors with Apple's codes, packet and event list building, the inline UMP constructors,
// conversions between MIDI 1.0 bytes, MIDI 1.0 UMP and MIDI 2.0, decoding (MIDIEventListForEachEvent), thru
// connections, the setup (external devices), notifications, and the Objective-C classes.
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static void wait_for(volatile BOOL *flag) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!*flag && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static NSMutableArray<NSString *> *decoded;
static void visit(void *ctx, MIDITimeStamp t, MIDIUniversalMessage m) {
    if (m.type == kMIDIMessageTypeChannelVoice2 && m.channelVoice2.status == kMIDICVStatusNoteOn)
        [decoded addObject:[NSString stringWithFormat:@"on %u %04X", m.channelVoice2.note.number, m.channelVoice2.note.velocity]];
    else if (m.type == kMIDIMessageTypeChannelVoice2 && m.channelVoice2.status == kMIDICVStatusNoteOff)
        [decoded addObject:[NSString stringWithFormat:@"off %u %04X", m.channelVoice2.note.number, m.channelVoice2.note.velocity]];
    else if (m.type == kMIDIMessageTypeChannelVoice2 && m.channelVoice2.status == kMIDICVStatusPitchBend)
        [decoded addObject:[NSString stringWithFormat:@"bend %08X", m.channelVoice2.pitchBend]];
    else if (m.type == kMIDIMessageTypeChannelVoice1)
        [decoded addObject:[NSString stringWithFormat:@"cv1 %X %u %u", m.channelVoice1.status, m.channelVoice1.note.number, m.channelVoice1.note.velocity]];
    else if (m.type == kMIDIMessageTypeSysEx)
        [decoded addObject:[NSString stringWithFormat:@"sysex %u %u", m.sysEx.status, m.sysEx.channel]];
    else if (m.type == kMIDIMessageTypeSystem)
        [decoded addObject:[NSString stringWithFormat:@"system %X", m.system.status]];
}

int main(void) {
    @autoreleasepool {
        // the inline constructors build the specification's words
        CHECK(MIDI1UPNoteOn(1, 2, 60, 100) == 0x21923C64, "MIDI1UPNoteOn: 0x%08X", MIDI1UPNoteOn(1, 2, 60, 100));
        MIDIMessage_64 on2 = MIDI2NoteOn(0, 0, 60, kMIDINoteAttributeNone, 0x8000, 0);
        CHECK(on2.word0 == 0x40903C00 && on2.word1 == 0x80000000, "MIDI2NoteOn: %08X %08X", on2.word0, on2.word1);
        MIDIMessage_64 pc = MIDI2ProgramChange(0, 3, true, 5, 1, 2);
        CHECK(pc.word0 == 0x40C30001 && pc.word1 == 0x05000102, "MIDI2ProgramChange with a bank: %08X %08X", pc.word0, pc.word1);
        MIDIMessage_64 sx = MIDI1UPSysEx(0, kMIDISysExStatusComplete, 3, 0x7E, 0x7F, 0x09, 0, 0, 0);
        CHECK(sx.word0 == 0x30037E7F && sx.word1 == 0x09000000, "MIDI1UPSysEx: %08X %08X", sx.word0, sx.word1);
        CHECK(MIDIMessageTypeForUPWord(0x40903C00) == kMIDIMessageTypeChannelVoice2 && MIDIMessageTypeForUPWord(MIDINoOpMessage()) == kMIDIMessageTypeUtility,
              "MIDIMessageTypeForUPWord");
        MIDIMessage_128 eod = MIDI2EndpointDiscoveryMessage(1, 1, true, false, true, false, false);
        CHECK(eod.word0 == 0xF0000101 && eod.word1 == 0x05, "MIDI2EndpointDiscoveryMessage: %08X %08X", eod.word0, eod.word1);

        // packet lists: one packet per time stamp, system-exclusive alone, the list's size respected
        Byte buf[64];
        MIDIPacketList *pl = (MIDIPacketList *)buf;
        MIDIPacket *p = MIDIPacketListInit(pl);
        Byte on[3] = { 0x90, 60, 100 }, off[3] = { 0x80, 60, 0 }, sys[4] = { 0xF0, 0x7D, 0x01, 0xF7 };
        p = MIDIPacketListAdd(pl, sizeof buf, p, 10, 3, on);
        p = MIDIPacketListAdd(pl, sizeof buf, p, 10, 3, off);
        CHECK(pl->numPackets == 1 && p->length == 6, "MIDIPacketListAdd: the same time stamp shares a packet");
        p = MIDIPacketListAdd(pl, sizeof buf, p, 10, 4, sys);
        CHECK(pl->numPackets == 2 && p->length == 4 && p->data[0] == 0xF0, "MIDIPacketListAdd: system-exclusive in its own packet");
        Byte big[60] = { 0x90 };
        CHECK(MIDIPacketListAdd(pl, sizeof buf, p, 20, sizeof big, big) == NULL, "MIDIPacketListAdd: NULL when the list is full");
        CHECK(MIDIPacketNext(&pl->packet[0]) == p, "MIDIPacketNext");

        // event lists
        UInt32 ebuf[64];
        MIDIEventList *el = (MIDIEventList *)ebuf;
        MIDIEventPacket *ep = MIDIEventListInit(el, kMIDIProtocol_2_0);
        UInt32 w[4] = { on2.word0, on2.word1, MIDI2PitchBend(0, 0, 0x80000000).word0, 0x80000000 };
        ep = MIDIEventListAdd(el, sizeof ebuf, ep, 5, 2, w);
        ep = MIDIEventListAdd(el, sizeof ebuf, ep, 5, 2, w + 2);
        CHECK(el->protocol == kMIDIProtocol_2_0 && el->numPackets == 1 && ep->wordCount == 4, "MIDIEventListAdd");
        decoded = [NSMutableArray array];
        MIDIEventListForEachEvent(el, visit, NULL);
        CHECK([decoded isEqualToArray:(@[ @"on 60 8000", @"bend 80000000" ])], "MIDIEventListForEachEvent: %s", decoded.description.UTF8String);
        CFDataRef sysData = NULL;
        UInt32 sxw[2] = { sx.word0, sx.word1 };
        MIDIEventPacket sxp = { 0, 2, { 0 } };
        memcpy(sxp.words, sxw, sizeof sxw);
        CHECK(MIDIEventPacketSysexBytesForGroup(&sxp, 0, &sysData) == noErr && CFDataGetLength(sysData) == 5 && CFDataGetBytePtr(sysData)[0] == 0xF0
              && CFDataGetBytePtr(sysData)[4] == 0xF7, "MIDIEventPacketSysexBytesForGroup");
        if (sysData) CFRelease(sysData);

        // a client and its notifications
        __block NSMutableArray<NSNumber *> *messages = [NSMutableArray array];
        MIDIClientRef client = 0;
        CHECK(MIDIClientCreateWithBlock(CFSTR("Test"), &client, ^(const MIDINotification *n) { [messages addObject:@(n->messageID)]; }) == noErr && client,
              "MIDIClientCreateWithBlock");

        // a MIDI 2.0 destination hears MIDI 1.0 bytes up-converted; a MIDI 1.0 port hears MIDI 2.0 down-converted
        __block NSMutableArray *got2 = [NSMutableArray array], *got1 = [NSMutableArray array];
        __block volatile BOOL done2 = NO, done1 = NO;
        MIDIEndpointRef dest2 = 0, src = 0;
        CHECK(MIDIDestinationCreateWithProtocol(client, CFSTR("Dest 2.0"), kMIDIProtocol_2_0, &dest2, ^(const MIDIEventList *list, void *refCon) {
            decoded = [NSMutableArray array];
            MIDIEventListForEachEvent(list, visit, NULL);
            [got2 addObjectsFromArray:decoded];
            if (got2.count >= 3) done2 = YES;
        }) == noErr, "MIDIDestinationCreateWithProtocol (2.0)");
        MIDIPortRef out = 0, in = 0;
        MIDIOutputPortCreate(client, CFSTR("Out"), &out);
        p = MIDIPacketListInit(pl);
        Byte notes[] = { 0x90, 60, 127, 64, 0, 0xE0, 0x00, 0x40 };      // running status: a note on with velocity 0
        p = MIDIPacketListAdd(pl, sizeof buf, p, 0, sizeof notes, notes);
        CHECK(MIDISend(out, dest2, pl) == noErr, "MIDISend");
        wait_for(&done2);
        CHECK([got2 isEqualToArray:(@[ @"on 60 FFFF", @"off 64 8000", @"bend 80000000" ])], "up-converted: %s", got2.description.UTF8String);

        MIDISourceCreate(client, CFSTR("Source"), &src);
        CHECK(MIDIInputPortCreateWithBlock(client, CFSTR("In"), &in, ^(const MIDIPacketList *list, void *refCon) {
            const MIDIPacket *q = &list->packet[0];
            for (UInt32 i = 0; i < list->numPackets; i++, q = MIDIPacketNext(q))
                for (UInt16 k = 0; k < q->length; k++) [got1 addObject:@(q->data[k])];
            if (refCon == (void *)0x55 && got1.count >= 6) done1 = YES;
        }) == noErr, "MIDIInputPortCreateWithBlock");
        CHECK(MIDIPortConnectSource(in, src, (void *)0x55) == noErr, "MIDIPortConnectSource");
        MIDIEventPacket *rp = MIDIEventListInit(el, kMIDIProtocol_2_0);
        UInt32 m2[4] = { MIDI2NoteOn(0, 0, 61, 0, 0x4000, 0).word0, 0x40000000, MIDI2ControlChange(0, 0, 7, 0xFFFFFFFF).word0, 0xFFFFFFFF };
        MIDIEventListAdd(el, sizeof ebuf, rp, 0, 4, m2);
        CHECK(MIDIReceivedEventList(src, el) == noErr, "MIDIReceivedEventList");
        wait_for(&done1);
        CHECK([got1 isEqualToArray:(@[ @0x90, @61, @32, @0xB0, @7, @127 ])], "down-converted: %s", got1.description.UTF8String);
        CHECK(MIDIPortDisconnectSource(in, src) == noErr && MIDIPortDisconnectSource(in, src) == kMIDINoConnection, "MIDIPortDisconnectSource");

        // errors
        CHECK(MIDISend(in, dest2, pl) == kMIDIInvalidPort, "MIDISend through an input port: kMIDIInvalidPort");
        CHECK(MIDISend(out, src, pl) == kMIDIWrongEndpointType, "MIDISend to a source: kMIDIWrongEndpointType");
        CHECK(MIDIReceived(dest2, pl) == kMIDIWrongEndpointType, "MIDIReceived on a destination");
        CHECK(MIDIPortConnectSource(in, 0x7fffffff, NULL) == kMIDIUnknownEndpoint, "unknown endpoint: kMIDIUnknownEndpoint");
        CHECK(MIDIOutputPortCreate(0x7fffffff, CFSTR("x"), &out) == kMIDIInvalidClient, "unknown client: kMIDIInvalidClient");
        MIDIEntityRef none;
        CHECK(MIDIEndpointGetEntity(src, &none) == kMIDIObjectNotFound, "a virtual endpoint has no entity");

        // properties: set, typed, inherited from the device, the display name, unique IDs
        MIDIDeviceRef dev = 0; MIDIEntityRef ent = 0;
        CHECK(MIDIExternalDeviceCreate(CFSTR("Synth"), CFSTR("Maker"), CFSTR("S-1"), &dev) == noErr, "MIDIExternalDeviceCreate");
        CHECK(MIDIDeviceAddEntity(dev, CFSTR("Port A"), false, 1, 1, &ent) == noErr && MIDIEntityGetNumberOfSources(ent) == 1
              && MIDIEntityGetNumberOfDestinations(ent) == 1, "MIDIDeviceAddEntity");
        MIDIEndpointRef extSrc = MIDIEntityGetSource(ent, 0);
        MIDIObjectSetIntegerProperty(dev, kMIDIPropertyReceiveChannels, 0xFFFF);
        SInt32 channels = 0;
        CHECK(MIDIObjectGetIntegerProperty(extSrc, kMIDIPropertyReceiveChannels, &channels) == noErr && channels == 0xFFFF, "a property inherited from the device");
        CFStringRef str = NULL;
        CHECK(MIDIObjectGetStringProperty(extSrc, kMIDIPropertyDisplayName, &str) == noErr && CFEqual(str, CFSTR("Synth Port A")), "kMIDIPropertyDisplayName");
        if (str) CFRelease(str);
        CHECK(MIDIObjectGetStringProperty(extSrc, kMIDIPropertyReceiveChannels, &str) == kMIDIWrongPropertyType, "kMIDIWrongPropertyType");
        CHECK(MIDIObjectGetIntegerProperty(extSrc, kMIDIPropertyMaxSysExSpeed, &channels) == kMIDIUnknownProperty, "kMIDIUnknownProperty");
        MIDIObjectType type;
        SInt32 uid = 0; MIDIObjectRef found = 0;
        MIDIObjectGetIntegerProperty(extSrc, kMIDIPropertyUniqueID, &uid);
        CHECK(MIDIObjectFindByUniqueID(uid, &found, &type) == noErr && found == extSrc && type == kMIDIObjectType_ExternalSource, "MIDIObjectFindByUniqueID");
        SInt32 other = 0;
        MIDIObjectGetIntegerProperty(dev, kMIDIPropertyUniqueID, &other);
        CHECK(MIDIObjectSetIntegerProperty(extSrc, kMIDIPropertyUniqueID, other) == kMIDIIDNotUnique, "kMIDIIDNotUnique");
        CFPropertyListRef props = NULL;
        CHECK(MIDIObjectGetProperties(dev, &props, true) == noErr && [((__bridge NSDictionary *)props)[@"entities"] count] == 1, "MIDIObjectGetProperties (deep)");
        if (props) CFRelease(props);
        ItemCount external = MIDIGetNumberOfExternalDevices();
        CHECK(MIDISetupAddExternalDevice(dev) == noErr && MIDIGetNumberOfExternalDevices() == external + 1 && MIDIGetExternalDevice(external) == dev,
              "MIDISetupAddExternalDevice");
        CHECK(MIDIDeviceDispose(dev) == kMIDINotPermitted && MIDISetupRemoveExternalDevice(dev) == noErr && MIDIDeviceDispose(dev) == noErr,
              "a device in the setup is removed before it is disposed");

        // a thru connection: channel 1 to 2, notes below 48 filtered out
        __block NSMutableArray *thruGot = [NSMutableArray array];
        __block volatile BOOL thruDone = NO;
        MIDIEndpointRef thruDest = 0;
        MIDIDestinationCreateWithBlock(client, CFSTR("Thru"), &thruDest, ^(const MIDIPacketList *list, void *refCon) {
            for (UInt16 k = 0; k < list->packet[0].length; k++) [thruGot addObject:@(list->packet[0].data[k])];
            thruDone = YES;
        });
        MIDIThruConnectionParams params;
        MIDIThruConnectionParamsInitialize(&params);
        CHECK(params.channelMap[5] == 5 && params.highNote == 127 && MIDIThruConnectionParamsSize(&params) == sizeof params, "MIDIThruConnectionParamsInitialize");
        params.numSources = 1; params.sources[0].endpointRef = src;
        params.numDestinations = 1; params.destinations[0].endpointRef = thruDest;
        params.channelMap[0] = 1; params.lowNote = 48;
        MIDIThruConnectionRef thru = 0;
        CFDataRef pd = CFDataCreate(NULL, (const UInt8 *)&params, sizeof params);
        CHECK(MIDIThruConnectionCreate(CFSTR("dev.isim.test"), pd, &thru) == noErr, "MIDIThruConnectionCreate");
        CFRelease(pd);
        p = MIDIPacketListInit(pl);
        Byte two[6] = { 0x90, 40, 100, 0x90, 50, 100 };
        MIDIPacketListAdd(pl, sizeof buf, p, 0, sizeof two, two);
        MIDIReceived(src, pl);
        wait_for(&thruDone);
        CHECK([thruGot isEqualToArray:(@[ @0x91, @50, @100 ])], "thru: channel map and note range: %s", thruGot.description.UTF8String);
        CFDataRef list = NULL;
        CHECK(MIDIThruConnectionFind(CFSTR("dev.isim.test"), &list) == noErr && CFDataGetLength(list) == sizeof(MIDIThruConnectionRef), "MIDIThruConnectionFind");
        if (list) CFRelease(list);
        CHECK(MIDIThruConnectionDispose(thru) == noErr && MIDIThruConnectionDispose(thru) == kMIDIObjectNotFound, "MIDIThruConnectionDispose");

        // notifications arrive on the client's run loop
        volatile BOOL any = NO;
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:2];
        while (!(any = messages.count > 0) && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        CHECK([messages containsObject:@(kMIDIMsgObjectAdded)] && [messages containsObject:@(kMIDIMsgSetupChanged)]
              && [messages containsObject:@(kMIDIMsgThruConnectionsChanged)], "notifications: %s", messages.description.UTF8String);
        CHECK(MIDIEndpointDispose(src) == noErr && MIDIEndpointDispose(src) == kMIDIUnknownEndpoint, "MIDIEndpointDispose");
        CHECK(MIDIClientDispose(client) == noErr && MIDIClientDispose(client) == kMIDIInvalidClient, "MIDIClientDispose");

        // the Objective-C classes
        MIDINetworkSession *session = [MIDINetworkSession defaultSession];
        MIDINetworkHost *h = [MIDINetworkHost hostWithName:@"A" address:@"10.0.0.2" port:5004];
        CHECK([session addContact:h] && [session.contacts containsObject:[MIDINetworkHost hostWithName:@"A" address:@"10.0.0.2" port:5004]]
              && [session removeContact:h] && session.contacts.count == 0, "MIDINetworkSession contacts");
        CHECK([h hasSameAddressAs:[MIDINetworkHost hostWithName:@"B" address:@"10.0.0.2" port:5004]], "-hasSameAddressAs:");
        MIDICIProfile *profile = [[MIDICIProfile alloc] initWithData:[NSData dataWithBytes:"\x7e\x00\x01\x01\x01" length:5] name:@"GM"];
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:profile requiringSecureCoding:YES error:nil];
        MIDICIProfile *back = [NSKeyedUnarchiver unarchivedObjectOfClass:MIDICIProfile.class fromData:archived error:nil];
        CHECK([back.name isEqualToString:@"GM"] && [back isEqual:profile], "MIDICIProfile secure coding");
        MIDI2DeviceManufacturer man = { { 0x7D, 0, 0 } };
        MIDI2DeviceRevisionLevel rev = { { 1, 0, 0, 0 } };
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:man family:1 modelNumber:2 revisionLevel:rev];
        MIDIUMPMutableEndpoint *ump = [[MIDIUMPMutableEndpoint alloc] initWithName:@"UMP" deviceInfo:info productInstanceID:@"x"
                                                                       MIDIProtocol:kMIDIProtocol_2_0 destinationCallback:^(const MIDIEventList *l, void *r) {}];
        NSError *error = nil;
        CHECK(ump && [ump setEnabled:YES error:&error] && ump.MIDISource && ump.MIDIDestination && [MIDIUMPEndpointManager.sharedInstance.UMPEndpoints containsObject:ump],
              "MIDIUMPMutableEndpoint enabled");
        CHECK(![ump registerFunctionBlocks:@[] markAsStatic:NO error:&error] && error.code == kMIDINotPermitted, "function blocks are registered before enabling");
        CHECK([ump setEnabled:NO error:&error] && !ump.MIDISource && MIDICIDeviceManager.sharedInstance.discoveredCIDevices.count == 0, "disabled; no MIDI-CI devices");
        printf("coremidi: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
