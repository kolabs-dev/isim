// isim CoreMIDI: packet lists and event lists, and messages between MIDI 1.0 bytes, MIDI 1.0 Universal MIDI Packets
// and MIDI 2.0 channel voice messages, with the specification's default translation (M2-104-UM, appendix D):
// min-center-max scaling up, bit shifts down, a note on with velocity 0 as a note off.
#import "MIDIPrivate.h"
#include <stddef.h>

@implementation _MIDIMessage
@end

// MARK: - building lists (MIDIServices.h)

MIDIPacket *MIDIPacketListInit(MIDIPacketList *pktlist) {
    pktlist->numPackets = 0;
    return &pktlist->packet[0];
}

MIDIPacket *MIDIPacketListAdd(MIDIPacketList *pktlist, ByteCount listSize, MIDIPacket *curPacket, MIDITimeStamp time,
                              ByteCount nData, const Byte *data) {
    const uint8_t *end = (const uint8_t *)pktlist + listSize;
    if (pktlist->numPackets > 0 && curPacket->timeStamp == time && curPacket->length > 0 && nData > 0
        && curPacket->data[0] != 0xF0 && data[0] != 0xF0 && data[0] >= 0x80
        && &curPacket->data[curPacket->length + nData] <= end) {
        memcpy(&curPacket->data[curPacket->length], data, nData);     // same time, no system-exclusive: one packet
        curPacket->length += (UInt16)nData;
        return curPacket;
    }
    MIDIPacket *p = pktlist->numPackets ? MIDIPacketNext(curPacket) : curPacket;
    if ((const uint8_t *)&p->data[nData] > end || nData > 0xFFFF) return NULL;
    p->timeStamp = time;
    p->length = (UInt16)nData;
    memcpy(p->data, data, nData);
    pktlist->numPackets++;
    return p;
}

MIDIEventPacket *MIDIEventListInit(MIDIEventList *evtlist, MIDIProtocolID protocol) {
    evtlist->protocol = protocol;
    evtlist->numPackets = 0;
    evtlist->packet[0].wordCount = 0;
    return &evtlist->packet[0];
}

MIDIEventPacket *MIDIEventListAdd(MIDIEventList *evtlist, ByteCount listSize, MIDIEventPacket *curPacket, MIDITimeStamp time,
                                  ByteCount wordCount, const UInt32 *words) {
    const uint8_t *end = (const uint8_t *)evtlist + listSize;
    if (wordCount > 64) return NULL;
    if (evtlist->numPackets > 0 && curPacket->timeStamp == time && curPacket->wordCount + wordCount <= 64
        && (const uint8_t *)&curPacket->words[curPacket->wordCount + wordCount] <= end) {
        memcpy(&curPacket->words[curPacket->wordCount], words, wordCount * 4);
        curPacket->wordCount += (UInt32)wordCount;
        return curPacket;
    }
    MIDIEventPacket *p = evtlist->numPackets ? MIDIEventPacketNext(curPacket) : curPacket;
    if ((const uint8_t *)&p->words[wordCount] > end) return NULL;
    p->timeStamp = time;
    p->wordCount = (UInt32)wordCount;
    memcpy(p->words, words, wordCount * 4);
    evtlist->numPackets++;
    return p;
}

// MARK: - MIDI 1.0 bytes

static int channelLength(uint8_t status) { return (status & 0xF0) == 0xC0 || (status & 0xF0) == 0xD0 ? 2 : 3; }
static int systemLength(uint8_t status) {
    switch (status) {
    case 0xF1: case 0xF3: return 2;
    case 0xF2: return 3;
    default: return 1;
    }
}

static void addBytes(NSMutableArray *out, const uint8_t *b, size_t n, MIDITimeStamp t) {
    if (!n) return;
    _MIDIMessage *m = [_MIDIMessage new];
    m.timeStamp = t; m.bytes = [NSData dataWithBytes:b length:n];
    [out addObject:m];
}

/* splits bytes into messages (running status, real-time bytes inside others, system-exclusive pieces) */
static void parseBytes(NSMutableArray *out, const uint8_t *b, size_t n, MIDITimeStamp t, uint8_t *running, BOOL *inSysex) {
    size_t i = 0;
    NSMutableData *sysex = nil;
    if (*inSysex) sysex = [NSMutableData data];
    while (i < n) {
        uint8_t c = b[i];
        if (c >= 0xF8) { addBytes(out, &c, 1, t); i++; continue; }        // real-time, anywhere
        if (sysex) {
            if (c < 0x80) { [sysex appendBytes:&c length:1]; i++; continue; }
            if (c == 0xF7) { [sysex appendBytes:&c length:1]; i++; }
            addBytes(out, sysex.bytes, sysex.length, t);
            sysex = nil; *inSysex = NO;
            continue;
        }
        if (c == 0xF0) { sysex = [NSMutableData dataWithBytes:&c length:1]; *inSysex = YES; i++; *running = 0; continue; }
        if (c == 0xF7) { i++; continue; }                                  // a stray end of exclusive
        int len;
        uint8_t status;
        size_t start;
        if (c >= 0x80) {
            status = c; start = i;
            len = c >= 0xF0 ? systemLength(c) : channelLength(c);
            if (c < 0xF0) *running = c; else *running = 0;
            if (i + len > n) break;                                        // incomplete
            addBytes(out, b + start, len, t);
            i += len;
        } else if (*running) {
            status = *running;
            len = channelLength(status);
            if (i + len - 1 > n) break;
            uint8_t msg[3] = { status, b[i], len == 3 ? b[i + 1] : 0 };
            addBytes(out, msg, len, t);
            i += len - 1;
        } else i++;                                                        // a data byte without status
    }
    if (sysex) addBytes(out, sysex.bytes, sysex.length, t);
}

NSArray<_MIDIMessage *> *_MIDIMessagesFromBytes(NSData *bytes, MIDITimeStamp t) {
    NSMutableArray *out = [NSMutableArray array];
    uint8_t running = 0; BOOL inSysex = NO;
    parseBytes(out, bytes.bytes, bytes.length, t, &running, &inSysex);
    return out;
}

NSArray<_MIDIMessage *> *_MIDIMessagesFromPacketList(const MIDIPacketList *list) {
    NSMutableArray *out = [NSMutableArray array];
    const MIDIPacket *p = &list->packet[0];
    uint8_t running = 0; BOOL inSysex = NO;
    for (UInt32 i = 0; i < list->numPackets; i++) {
        parseBytes(out, p->data, p->length, p->timeStamp, &running, &inSysex);
        p = MIDIPacketNext(p);
    }
    return out;
}

// MARK: - Universal MIDI Packets

static UInt32 umpWords(UInt32 w) {
    static const UInt32 sizes[16] = { 1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4 };
    return sizes[w >> 28];
}

NSArray<_MIDIMessage *> *_MIDIMessagesFromWords(const UInt32 *words, UInt32 count, MIDITimeStamp t) {
    NSMutableArray *out = [NSMutableArray array];
    for (UInt32 i = 0; i < count;) {
        UInt32 n = umpWords(words[i]);
        if (i + n > count) break;
        _MIDIMessage *m = [_MIDIMessage new];
        m.timeStamp = t; m.words = [NSData dataWithBytes:words + i length:n * 4];
        [out addObject:m];
        i += n;
    }
    return out;
}

NSArray<_MIDIMessage *> *_MIDIMessagesFromEventList(const MIDIEventList *list) {
    NSMutableArray *out = [NSMutableArray array];
    const MIDIEventPacket *p = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++) {
        [out addObjectsFromArray:_MIDIMessagesFromWords(p->words, p->wordCount, p->timeStamp)];
        p = MIDIEventPacketNext(p);
    }
    return out;
}

/* MIDI 1.0 bytes as MIDI 1.0 Universal MIDI Packets (group 0) */
static void wordsFromBytes(NSData *bytes, NSMutableArray<NSData *> *out) {
    const uint8_t *b = bytes.bytes;
    size_t n = bytes.length;
    if (!n) return;
    if (b[0] >= 0x80 && b[0] < 0xF0) {
        UInt32 w = MIDI1UPChannelVoiceMessage(0, b[0] >> 4, b[0] & 0xF, n > 1 ? b[1] : 0, n > 2 ? b[2] : 0);
        [out addObject:[NSData dataWithBytes:&w length:4]];
    } else if (b[0] >= 0xF1 && b[0] != 0xF7) {
        UInt32 w = MIDI1UPSystemCommon(0, b[0], n > 1 ? b[1] : 0, n > 2 ? b[2] : 0);
        [out addObject:[NSData dataWithBytes:&w length:4]];
    } else {
        // system-exclusive: six bytes a packet, without F0 and F7
        BOOL starts = b[0] == 0xF0, ends = b[n - 1] == 0xF7;
        size_t from = starts ? 1 : 0, to = ends ? n - 1 : n;
        size_t count = to - from;
        size_t packets = count ? (count + 5) / 6 : 1;
        for (size_t k = 0; k < packets; k++) {
            size_t s = from + k * 6, len = MIN((size_t)6, to - s);
            if (s > to) len = 0;
            BOOL first = k == 0 && starts, last = k == packets - 1 && ends;
            UInt8 st = first && last ? kMIDISysExStatusComplete : first ? kMIDISysExStatusStart : last ? kMIDISysExStatusEnd : kMIDISysExStatusContinue;
            MIDIMessage_64 m = MIDI1UPSysExArray(0, st, b + s, b + s + len);
            UInt32 w[2] = { m.word0, m.word1 };
            [out addObject:[NSData dataWithBytes:w length:8]];
        }
    }
}

/* min-center-max scaling (M2-104-UM D.3) */
static UInt32 scaleUp(UInt32 v, int srcBits, int dstBits) {
    int scaleBits = dstBits - srcBits;
    UInt32 shifted = v << scaleBits, center = 1u << (srcBits - 1);
    if (v <= center) return shifted;
    int repeatBits = srcBits - 1;
    UInt32 repeat = v & ((1u << repeatBits) - 1);
    repeat = scaleBits > repeatBits ? repeat << (scaleBits - repeatBits) : repeat >> (repeatBits - scaleBits);
    while (repeat) { shifted |= repeat; repeat >>= repeatBits; }
    return shifted;
}

/* a MIDI 1.0 channel voice word as a MIDI 2.0 message (nil: no MIDI 2.0 form, the word stays) */
static NSData *upgrade(UInt32 w) {
    UInt8 group = w >> 24 & 0xF, status = w >> 20 & 0xF, ch = w >> 16 & 0xF, d1 = w >> 8 & 0x7F, d2 = w & 0x7F;
    MIDIMessage_64 m;
    switch (status) {
    case 0x8: m = MIDI2NoteOff(group, ch, d1, 0, (UInt16)scaleUp(d2, 7, 16), 0); break;
    case 0x9: m = d2 ? MIDI2NoteOn(group, ch, d1, 0, (UInt16)scaleUp(d2, 7, 16), 0) : MIDI2NoteOff(group, ch, d1, 0, 0x8000, 0); break;
    case 0xA: m = MIDI2PolyPressure(group, ch, d1, scaleUp(d2, 7, 32)); break;
    case 0xB: m = MIDI2ControlChange(group, ch, d1, scaleUp(d2, 7, 32)); break;
    case 0xC: m = MIDI2ProgramChange(group, ch, false, d1, 0, 0); break;
    case 0xD: m = MIDI2ChannelPressure(group, ch, scaleUp(d1, 7, 32)); break;
    case 0xE: m = MIDI2PitchBend(group, ch, scaleUp((UInt32)d2 << 7 | d1, 14, 32)); break;
    default: return nil;
    }
    UInt32 out[2] = { m.word0, m.word1 };
    return [NSData dataWithBytes:out length:8];
}

/* a MIDI 2.0 channel voice message as MIDI 1.0 words (empty: it has none) */
static void downgrade(const UInt32 *w, NSMutableArray<NSData *> *out) {
    UInt8 group = w[0] >> 24 & 0xF, status = w[0] >> 20 & 0xF, ch = w[0] >> 16 & 0xF, i1 = w[0] >> 8 & 0x7F, i2 = w[0] & 0x7F;
    UInt32 v = w[1];
    UInt32 words[4]; int n = 0;
    switch (status) {
    case 0x8: words[n++] = MIDI1UPNoteOff(group, ch, i1, (UInt8)(v >> 25)); break;
    case 0x9: { UInt8 vel = (UInt8)(v >> 25); words[n++] = MIDI1UPNoteOn(group, ch, i1, vel ? vel : 1); break; }
    case 0xA: words[n++] = MIDI1UPPolyPressure(group, ch, i1, (UInt8)(v >> 25)); break;
    case 0xB: words[n++] = MIDI1UPControlChange(group, ch, i1, (UInt8)(v >> 25)); break;
    case 0xC:
        if (w[0] & 1) { words[n++] = MIDI1UPControlChange(group, ch, 0, v >> 8 & 0x7F); words[n++] = MIDI1UPControlChange(group, ch, 32, v & 0x7F); }
        words[n++] = MIDI1UPProgramChange(group, ch, v >> 24 & 0x7F);
        break;
    case 0xD: words[n++] = MIDI1UPChannelPressure(group, ch, (UInt8)(v >> 25)); break;
    case 0xE: { UInt32 b = v >> 18; words[n++] = MIDI1UPPitchBend(group, ch, b & 0x7F, b >> 7 & 0x7F); break; }
    case 0x2: case 0x3: {      // registered and assignable controllers: RPN and NRPN control changes
        BOOL rpn = status == 0x2;
        words[n++] = MIDI1UPControlChange(group, ch, rpn ? 101 : 99, i1);
        words[n++] = MIDI1UPControlChange(group, ch, rpn ? 100 : 98, i2);
        words[n++] = MIDI1UPControlChange(group, ch, 6, v >> 25 & 0x7F);
        words[n++] = MIDI1UPControlChange(group, ch, 38, v >> 18 & 0x7F);
        break;
    }
    default: break;
    }
    for (int k = 0; k < n; k++) [out addObject:[NSData dataWithBytes:&words[k] length:4]];
}

NSArray<NSData *> *_MIDIWordsForProtocol(_MIDIMessage *m, MIDIProtocolID protocol) {
    NSMutableArray<NSData *> *in = [NSMutableArray array], *out = [NSMutableArray array];
    if (m.bytes) wordsFromBytes(m.bytes, in); else [in addObject:m.words];
    for (NSData *d in in) {
        const UInt32 *w = d.bytes;
        UInt8 mt = w[0] >> 28;
        if (protocol == kMIDIProtocol_2_0 && mt == kMIDIMessageTypeChannelVoice1) {
            NSData *up = upgrade(w[0]);
            [out addObject:up ?: d];
        } else if (protocol == kMIDIProtocol_1_0 && mt == kMIDIMessageTypeChannelVoice2) {
            downgrade(w, out);
        } else [out addObject:d];
    }
    return out;
}

NSData *_MIDIBytesFromWords(NSData *words) {
    NSMutableData *out = [NSMutableData data];
    NSMutableArray<NSData *> *pieces = [NSMutableArray array];
    const UInt32 *w0 = words.bytes;
    if (words.length >= 8 && (w0[0] >> 28) == kMIDIMessageTypeChannelVoice2) downgrade(w0, pieces); else [pieces addObject:words];
    for (NSData *d in pieces) {
        const UInt32 *w = d.bytes;
        UInt8 mt = w[0] >> 28;
        if (mt == kMIDIMessageTypeChannelVoice1) {
            uint8_t b[3] = { (uint8_t)(w[0] >> 16), (uint8_t)(w[0] >> 8 & 0x7F), (uint8_t)(w[0] & 0x7F) };
            [out appendBytes:b length:channelLength(b[0])];
        } else if (mt == kMIDIMessageTypeSystem) {
            uint8_t b[3] = { (uint8_t)(w[0] >> 16), (uint8_t)(w[0] >> 8 & 0x7F), (uint8_t)(w[0] & 0x7F) };
            [out appendBytes:b length:systemLength(b[0])];
        } else if (mt == kMIDIMessageTypeSysEx && d.length >= 8) {
            UInt8 st = w[0] >> 20 & 0xF, n = MIN(6, w[0] >> 16 & 0xF);
            uint8_t data[6] = { (uint8_t)(w[0] >> 8 & 0x7F), (uint8_t)(w[0] & 0x7F), (uint8_t)(w[1] >> 24 & 0x7F),
                                (uint8_t)(w[1] >> 16 & 0x7F), (uint8_t)(w[1] >> 8 & 0x7F), (uint8_t)(w[1] & 0x7F) };
            uint8_t f0 = 0xF0, f7 = 0xF7;
            if (st == kMIDISysExStatusComplete || st == kMIDISysExStatusStart) [out appendBytes:&f0 length:1];
            [out appendBytes:data length:n];
            if (st == kMIDISysExStatusComplete || st == kMIDISysExStatusEnd) [out appendBytes:&f7 length:1];
        }
    }
    return out;
}

// MARK: - lists from messages

NSData *_MIDIPacketListFromMessages(NSArray<_MIDIMessage *> *msgs) {
    NSMutableArray<NSData *> *bytes = [NSMutableArray array];
    NSMutableArray<NSNumber *> *times = [NSMutableArray array];
    size_t size = offsetof(MIDIPacketList, packet);
    for (_MIDIMessage *m in msgs) {
        NSData *b = m.bytes ?: _MIDIBytesFromWords(m.words);
        if (!b.length) continue;
        [bytes addObject:b]; [times addObject:@(m.timeStamp)];
        size += offsetof(MIDIPacket, data) + b.length + 4;
    }
    if (!bytes.count) return nil;
    NSMutableData *d = [NSMutableData dataWithLength:MAX(size, sizeof(MIDIPacketList))];
    MIDIPacketList *list = d.mutableBytes;
    MIDIPacket *p = MIDIPacketListInit(list);
    for (NSUInteger i = 0; i < bytes.count; i++)
        p = MIDIPacketListAdd(list, d.length, p, times[i].unsignedLongLongValue, bytes[i].length, bytes[i].bytes);
    return d;
}

NSData *_MIDIEventListFromMessages(NSArray<_MIDIMessage *> *msgs, MIDIProtocolID protocol) {
    NSMutableArray<NSData *> *words = [NSMutableArray array];
    NSMutableArray<NSNumber *> *times = [NSMutableArray array];
    size_t size = offsetof(MIDIEventList, packet);
    for (_MIDIMessage *m in msgs)
        for (NSData *w in _MIDIWordsForProtocol(m, protocol)) {
            [words addObject:w]; [times addObject:@(m.timeStamp)];
            size += offsetof(MIDIEventPacket, words) + w.length;
        }
    if (!words.count) return nil;
    NSMutableData *d = [NSMutableData dataWithLength:MAX(size, sizeof(MIDIEventList))];
    MIDIEventList *list = d.mutableBytes;
    MIDIEventPacket *p = MIDIEventListInit(list, protocol);
    for (NSUInteger i = 0; i < words.count; i++)
        p = MIDIEventListAdd(list, d.length, p, times[i].unsignedLongLongValue, words[i].length / 4, words[i].bytes);
    return d;
}

// MARK: - decoding (MIDIMessages.h)

static MIDIUniversalMessage decode(const UInt32 *w) {
    MIDIUniversalMessage u;
    memset(&u, 0, sizeof u);
    u.type = (MIDIMessageType)(w[0] >> 28);
    u.group = w[0] >> 24 & 0xF;
    switch (u.type) {
    case kMIDIMessageTypeUtility:
        u.group = 0;
        u.utility.status = (MIDIUtilityStatus)(w[0] >> 20 & 0xF);
        if (u.utility.status == kMIDIUtilityStatusTicksSinceLastEvent) u.utility.ticksSinceLastEvent = w[0] & 0xFFFFF;
        else u.utility.jitterReductionClock = (UInt16)(w[0] & 0xFFFF);
        break;
    case kMIDIMessageTypeSystem:
        u.system.status = (MIDISystemStatus)(w[0] >> 16 & 0xFF);
        if (u.system.status == kMIDIStatusSongPosPointer) u.system.songPositionPointer = (UInt16)((w[0] & 0x7F) << 7 | (w[0] >> 8 & 0x7F));
        else u.system.timeCode = w[0] >> 8 & 0x7F;      // MTC quarter frame, song select (same byte)
        break;
    case kMIDIMessageTypeChannelVoice1:
        u.channelVoice1.status = (MIDICVStatus)(w[0] >> 20 & 0xF);
        u.channelVoice1.channel = w[0] >> 16 & 0xF;
        switch (u.channelVoice1.status) {
        case kMIDICVStatusPitchBend: u.channelVoice1.pitchBend = (UInt16)((w[0] & 0x7F) << 7 | (w[0] >> 8 & 0x7F)); break;
        case kMIDICVStatusProgramChange: u.channelVoice1.program = w[0] >> 8 & 0x7F; break;
        case kMIDICVStatusChannelPressure: u.channelVoice1.channelPressure = w[0] >> 8 & 0x7F; break;
        default: u.channelVoice1.note.number = w[0] >> 8 & 0x7F; u.channelVoice1.note.velocity = w[0] & 0x7F; break;
        }
        break;
    case kMIDIMessageTypeSysEx: {
        u.sysEx.status = (MIDISysExStatus)(w[0] >> 20 & 0xF);
        u.sysEx.channel = MIN(6, w[0] >> 16 & 0xF);     // the number of bytes used
        UInt8 d[6] = { (UInt8)(w[0] >> 8 & 0x7F), (UInt8)(w[0] & 0x7F), (UInt8)(w[1] >> 24 & 0x7F), (UInt8)(w[1] >> 16 & 0x7F),
                       (UInt8)(w[1] >> 8 & 0x7F), (UInt8)(w[1] & 0x7F) };
        memcpy(u.sysEx.data, d, 6);
        break;
    }
    case kMIDIMessageTypeChannelVoice2: {
        u.channelVoice2.status = (MIDICVStatus)(w[0] >> 20 & 0xF);
        u.channelVoice2.channel = w[0] >> 16 & 0xF;
        UInt8 i1 = w[0] >> 8 & 0xFF, i2 = w[0] & 0xFF;
        switch (u.channelVoice2.status) {
        case kMIDICVStatusNoteOff: case kMIDICVStatusNoteOn:
            u.channelVoice2.note.number = i1 & 0x7F; u.channelVoice2.note.attributeType = (MIDINoteAttribute)i2;
            u.channelVoice2.note.velocity = (UInt16)(w[1] >> 16); u.channelVoice2.note.attributeData = (UInt16)w[1];
            break;
        case kMIDICVStatusPolyPressure: u.channelVoice2.polyPressure.noteNumber = i1 & 0x7F; u.channelVoice2.polyPressure.pressure = w[1]; break;
        case kMIDICVStatusControlChange: u.channelVoice2.controlChange.index = i1 & 0x7F; u.channelVoice2.controlChange.data = w[1]; break;
        case kMIDICVStatusProgramChange:
            u.channelVoice2.programChange.options = (MIDIProgramChangeOptions)(i2 & 1);
            u.channelVoice2.programChange.program = w[1] >> 24 & 0x7F;
            u.channelVoice2.programChange.bank = (UInt16)((w[1] >> 8 & 0x7F) << 7 | (w[1] & 0x7F));
            break;
        case kMIDICVStatusChannelPressure: u.channelVoice2.channelPressure = w[1]; break;
        case kMIDICVStatusPitchBend: u.channelVoice2.pitchBend = w[1]; break;
        case kMIDICVStatusPerNotePitchBend: u.channelVoice2.perNotePitchBend.noteNumber = i1 & 0x7F; u.channelVoice2.perNotePitchBend.bend = w[1]; break;
        case kMIDICVStatusPerNoteMgmt:
            u.channelVoice2.perNoteManagement.noteNumber = i1 & 0x7F;
            u.channelVoice2.perNoteManagement.options = (MIDIPerNoteManagementOptions)(i2 & 3);
            break;
        case kMIDICVStatusRegisteredPNC: case kMIDICVStatusAssignablePNC:
            u.channelVoice2.perNoteController.noteNumber = i1 & 0x7F; u.channelVoice2.perNoteController.index = i2;
            u.channelVoice2.perNoteController.data = w[1];
            break;
        default:     // registered, assignable and relative controllers
            u.channelVoice2.controller.bank = i1 & 0x7F; u.channelVoice2.controller.index = i2 & 0x7F; u.channelVoice2.controller.data = w[1];
            break;
        }
        break;
    }
    case kMIDIMessageTypeData128:
        u.data128.status = (MIDISysExStatus)(w[0] >> 20 & 0xF);
        u.data128.byteCount = MIN(13, w[0] >> 16 & 0xF);
        u.data128.streamID = w[0] >> 8 & 0xFF;
        u.data128.data[0] = w[0] & 0xFF;
        for (int k = 0; k < 12; k++) u.data128.data[1 + k] = w[1 + k / 4] >> (24 - 8 * (k % 4)) & 0xFF;
        break;
    default:
        for (UInt32 k = 0; k < umpWords(w[0]) && k < 4; k++) u.unknown.words[k] = w[k];
        break;
    }
    return u;
}

void MIDIEventListForEachEvent(const MIDIEventList *evtlist, MIDIEventVisitor visitor, void *visitorContext) {
    if (!evtlist || !visitor) return;
    const MIDIEventPacket *p = &evtlist->packet[0];
    for (UInt32 i = 0; i < evtlist->numPackets; i++) {
        for (UInt32 k = 0; k < p->wordCount;) {
            UInt32 n = umpWords(p->words[k]);
            if (k + n > p->wordCount) break;
            visitor(visitorContext, p->timeStamp, decode(&p->words[k]));
            k += n;
        }
        p = MIDIEventPacketNext(p);
    }
}

OSStatus MIDIEventPacketSysexBytesForGroup(const MIDIEventPacket *pkt, UInt8 groupIndex, CFDataRef *outData) {
    if (!pkt || !outData) return kMIDIUnknownError;
    NSMutableData *d = [NSMutableData data];
    for (UInt32 k = 0; k < pkt->wordCount;) {
        UInt32 n = umpWords(pkt->words[k]);
        if (k + n > pkt->wordCount) break;
        if ((pkt->words[k] >> 28) == kMIDIMessageTypeSysEx && (pkt->words[k] >> 24 & 0xF) == groupIndex)
            [d appendData:_MIDIBytesFromWords([NSData dataWithBytes:&pkt->words[k] length:n * 4])];
        k += n;
    }
    *outData = (CFDataRef)CFBridgingRetain(d);
    return noErr;
}
