// isim CoreMIDI: thru connections. Each message from a connection's sources is filtered and transformed as its
// parameters say (filters, channel map, note and velocity ranges, value transforms, control transforms and maps) and
// sent to its destinations. Connections live as long as the app's process (Apple keeps persistent ones across launches).
#import "MIDIPrivate.h"

static NSMutableArray<_MIDIObject *> *thrus;

void MIDIThruConnectionParamsInitialize(MIDIThruConnectionParams *p) {
    memset(p, 0, sizeof *p);
    for (int i = 0; i < 16; i++) p->channelMap[i] = (UInt8)i;
    p->lowVelocity = 0; p->highVelocity = 127;
    p->lowNote = 0; p->highNote = 127;
}

static BOOL validParams(CFDataRef data) {
    if (!data || CFDataGetLength(data) < (CFIndex)sizeof(MIDIThruConnectionParams)) return NO;
    const MIDIThruConnectionParams *p = (const MIDIThruConnectionParams *)CFDataGetBytePtr(data);
    if (p->numSources > kMIDIThruConnection_MaxEndpoints || p->numDestinations > kMIDIThruConnection_MaxEndpoints) return NO;
    return (size_t)CFDataGetLength(data) >= MIDIThruConnectionParamsSize(p);
}

OSStatus MIDIThruConnectionCreate(CFStringRef inPersistentOwnerID, CFDataRef inConnectionParams, MIDIThruConnectionRef *outConnection) {
    if (!outConnection) return kMIDIUnknownError;
    if (!validParams(inConnectionParams)) return kMIDIUnknownError;
    _MIDIObject *t = _MIDINew(_MIDIKindThru, kMIDIObjectType_Other, nil);
    t.thruParams = [(__bridge NSData *)inConnectionParams copy];
    t.thruOwner = inPersistentOwnerID ? [(__bridge NSString *)inPersistentOwnerID copy] : nil;
    [_MIDILock() lock];
    if (!thrus) thrus = [NSMutableArray array];
    [thrus addObject:t];
    [_MIDILock() unlock];
    *outConnection = t.ref;
    _MIDINotifyThruChanged();
    return noErr;
}
OSStatus MIDIThruConnectionDispose(MIDIThruConnectionRef connection) {
    _MIDIObject *t = _MIDILookup(connection, _MIDIKindThru);
    if (!t) return kMIDIObjectNotFound;
    [_MIDILock() lock]; [thrus removeObject:t]; t.disposed = YES; [_MIDILock() unlock];
    _MIDINotifyThruChanged();
    return noErr;
}
OSStatus MIDIThruConnectionGetParams(MIDIThruConnectionRef connection, CFDataRef *outConnectionParams) {
    _MIDIObject *t = _MIDILookup(connection, _MIDIKindThru);
    if (!t) return kMIDIObjectNotFound;
    if (outConnectionParams) *outConnectionParams = (CFDataRef)CFBridgingRetain(t.thruParams);
    return noErr;
}
OSStatus MIDIThruConnectionSetParams(MIDIThruConnectionRef connection, CFDataRef inConnectionParams) {
    _MIDIObject *t = _MIDILookup(connection, _MIDIKindThru);
    if (!t) return kMIDIObjectNotFound;
    if (!validParams(inConnectionParams)) return kMIDIUnknownError;
    t.thruParams = [(__bridge NSData *)inConnectionParams copy];
    _MIDINotifyThruChanged();
    return noErr;
}
OSStatus MIDIThruConnectionFind(CFStringRef owner, CFDataRef *outConnectionList) {
    if (!outConnectionList) return kMIDIUnknownError;
    NSMutableData *d = [NSMutableData data];
    [_MIDILock() lock];
    for (_MIDIObject *t in thrus) if (owner && [t.thruOwner isEqualToString:(__bridge NSString *)owner]) {
        MIDIThruConnectionRef r = t.ref;
        [d appendBytes:&r length:sizeof r];
    }
    [_MIDILock() unlock];
    *outConnectionList = (CFDataRef)CFBridgingRetain(d);
    return noErr;
}

// MARK: - transforms

static int transform(MIDITransform t, int v, const MIDIValueMap *maps, UInt16 numMaps, BOOL *drop) {
    switch (t.transform) {
    case kMIDITransform_FilterOut: *drop = YES; return v;
    case kMIDITransform_Add: v += t.param; break;
    case kMIDITransform_Scale: v = v * t.param / 256; break;          // param: fixed point, 256 = 1.0
    case kMIDITransform_MinValue: if (v < t.param) v = t.param; break;
    case kMIDITransform_MaxValue: if (v > t.param) v = t.param; break;
    case kMIDITransform_MapValue: if (t.param >= 0 && t.param < numMaps && v >= 0 && v < 128) v = maps[t.param].value[v]; break;
    default: break;
    }
    return v < 0 ? 0 : v > 127 ? 127 : v;
}

static BOOL endpointMatches(const MIDIThruConnectionEndpoint *e, _MIDIObject *o) {
    if (e->endpointRef == o.ref) return YES;
    return e->uniqueID != kMIDIInvalidUniqueID && [o.props[(__bridge NSString *)kMIDIPropertyUniqueID] intValue] == e->uniqueID;
}

/* one MIDI 1.0 message through a connection's parameters (nil: filtered out) */
static NSData *thru(const MIDIThruConnectionParams *p, NSData *bytes) {
    const uint8_t *b = bytes.bytes;
    if (!bytes.length) return nil;
    uint8_t s = b[0];
    if (s == 0xF0 || s < 0x80) return p->filterOutSysEx ? nil : bytes;     // system-exclusive (or a piece of one)
    if (s == 0xF1) return p->filterOutMTC ? nil : bytes;
    if (s == 0xF8 || s == 0xFA || s == 0xFB || s == 0xFC || s == 0xF2) return p->filterOutBeatClock ? nil : bytes;
    if (s == 0xF6) return p->filterOutTuneRequest ? nil : bytes;
    if (s >= 0xF0) return bytes;
    uint8_t out[3];
    memcpy(out, b, MIN(bytes.length, (NSUInteger)3));
    uint8_t ch = s & 0xF, kind = s & 0xF0;
    uint8_t mapped = p->channelMap[ch];
    if (mapped > 15) return nil;                                           // the channel is filtered out
    out[0] = kind | mapped;
    const MIDIControlTransform *ctl = (const MIDIControlTransform *)(p + 1);
    const MIDIValueMap *maps = (const MIDIValueMap *)(ctl + p->numControlTransforms);
    BOOL drop = NO;
    switch (kind) {
    case 0x80: case 0x90: {
        int note = out[1], vel = out[2];
        if (note < p->lowNote || note > p->highNote) {
            if (p->lowNote <= p->highNote) return nil;
        } else if (p->lowNote > p->highNote) return nil;                     // low > high: outside the range passes
        if (kind == 0x90 && vel > 0 && (vel < p->lowVelocity || vel > p->highVelocity)) return nil;
        out[1] = (uint8_t)transform(p->noteNumber, note, maps, p->numMaps, &drop);
        if (kind == 0x90 && vel > 0) out[2] = (uint8_t)MAX(1, transform(p->velocity, vel, maps, p->numMaps, &drop));
        break;
    }
    case 0xA0: out[2] = (uint8_t)transform(p->keyPressure, out[2], maps, p->numMaps, &drop); break;
    case 0xD0: out[1] = (uint8_t)transform(p->channelPressure, out[1], maps, p->numMaps, &drop); break;
    case 0xC0: out[1] = (uint8_t)transform(p->programChange, out[1], maps, p->numMaps, &drop); break;
    case 0xE0: {
        if (p->pitchBend.transform == kMIDITransform_FilterOut) return nil;
        int v = out[2] << 7 | out[1];
        if (p->pitchBend.transform == kMIDITransform_Add) v += p->pitchBend.param;
        else if (p->pitchBend.transform == kMIDITransform_Scale) v = 8192 + (v - 8192) * p->pitchBend.param / 256;
        v = v < 0 ? 0 : v > 16383 ? 16383 : v;
        out[1] = v & 0x7F; out[2] = v >> 7;
        break;
    }
    case 0xB0: {
        if (p->filterOutAllControls) return nil;
        for (UInt16 i = 0; i < p->numControlTransforms; i++) {
            const MIDIControlTransform *c = &ctl[i];
            if (c->controlType != kMIDIControlType_7Bit || c->controlNumber != out[1]) continue;
            if (c->transform == kMIDITransform_MapControl) out[1] = (uint8_t)(c->param & 0x7F);
            else out[2] = (uint8_t)transform((MIDITransform){ c->transform, c->param }, out[2], maps, p->numMaps, &drop);
        }
        break;
    }
    }
    return drop ? nil : [NSData dataWithBytes:out length:bytes.length];
}

void _MIDIThruDeliver(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs) {
    [_MIDILock() lock];
    NSArray *all = [thrus copy];
    [_MIDILock() unlock];
    for (_MIDIObject *t in all) {
        const MIDIThruConnectionParams *p = t.thruParams.bytes;
        BOOL from = NO;
        for (UInt32 i = 0; i < p->numSources; i++) if (endpointMatches(&p->sources[i], src)) { from = YES; break; }
        if (!from) continue;
        NSMutableArray *out = [NSMutableArray array];
        for (_MIDIMessage *m in msgs) {
            NSData *b = thru(p, m.bytes ?: _MIDIBytesFromWords(m.words));
            if (!b) continue;
            _MIDIMessage *x = [_MIDIMessage new];
            x.bytes = b;      // already at its time: sent now
            [out addObject:x];
        }
        if (!out.count) continue;
        for (UInt32 i = 0; i < p->numDestinations; i++) {
            _MIDIObject *d = _MIDILookup(p->destinations[i].endpointRef, _MIDIKindEndpoint);
            if (!d && p->destinations[i].uniqueID) {
                MIDIObjectRef r = 0; MIDIObjectType type;
                if (MIDIObjectFindByUniqueID(p->destinations[i].uniqueID, &r, &type) == noErr) d = _MIDILookup(r, _MIDIKindEndpoint);
            }
            if (d) _MIDISendMessages(d, out);
        }
    }
}
