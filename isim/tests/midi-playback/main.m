// MIDI playback from C and Objective-C (MIDIPlaybackTest.app, issue #389): Music Sequence (tracks, events, iterators,
// Standard MIDI Files, the tempo map, editing), Music Player, the Sampler and MIDISynth units through MusicDevice.h,
// Audio File Stream Services, CAClock, and the AVFAudio classes (AVAudioUnitSampler, AVAudioSequencer and AVMusicTrack
// with AVBeatRange, the AVMusicEvent classes, AVMIDIPlayer) through Apple's names.
#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static void wait_for(volatile BOOL *flag) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!*flag && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static int streamProperties, streamPackets;
static UInt32 streamBytes;
static void streamProperty(void *client, AudioFileStreamID stream, AudioFileStreamPropertyID pid, AudioFileStreamPropertyFlags *flags) {
    if (pid == kAudioFileStreamProperty_ReadyToProducePackets) streamProperties++;
}
static void streamPacketsProc(void *client, UInt32 bytes, UInt32 packets, const void *data, AudioStreamPacketDescription *descs) {
    streamBytes += bytes; streamPackets += packets;
}

static volatile int notesReceived;
static void readMIDI(const MIDIPacketList *list, void *refCon, void *srcRefCon) {
    const MIDIPacket *p = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++, p = MIDIPacketNext(p))
        if (p->length >= 3 && (p->data[0] & 0xF0) == 0x90 && p->data[2] > 0) notesReceived++;
}

static volatile int userEvents;
static void userCallback(void *client, MusicSequence seq, MusicTrack track, MusicTimeStamp t, const MusicEventUserData *data, MusicTimeStamp a, MusicTimeStamp b) {
    if (data->length == 3 && memcmp(data->data, "abc", 3) == 0) userEvents++;
}

int main(void) {
    @autoreleasepool {
        // ---- Music Sequence ----
        MusicSequence seq = NULL;
        CHECK(NewMusicSequence(&seq) == noErr && seq, "NewMusicSequence");
        MusicTrack track = NULL, tempo = NULL;
        CHECK(MusicSequenceNewTrack(seq, &track) == noErr && MusicSequenceGetTempoTrack(seq, &tempo) == noErr && track != tempo, "a track and the tempo track");
        CHECK(MusicTrackNewExtendedTempoEvent(tempo, 0, 240) == noErr, "a tempo event");
        for (int i = 0; i < 4; i++) {
            MIDINoteMessage note = {.channel = 0, .note = (UInt8)(60 + i), .velocity = 100, .releaseVelocity = 0, .duration = 0.5f};
            MusicTrackNewMIDINoteEvent(track, i, &note);
        }
        MIDIChannelMessage cc = {.status = 0xB0, .data1 = 7, .data2 = 100};
        MusicTrackNewMIDIChannelEvent(track, 0, &cc);
        struct { UInt32 length; UInt8 data[3]; } user = {3, {'a', 'b', 'c'}};
        CHECK(MusicTrackNewUserEvent(track, 1, (const MusicEventUserData *)&user) == noErr, "a user event");
        UInt32 count = 0;
        MusicSequenceGetTrackCount(seq, &count);
        Float64 seconds = 0;
        MusicSequenceGetSecondsForBeats(seq, 4, &seconds);
        MusicTimeStamp beats = 0;
        MusicSequenceGetBeatsForSeconds(seq, 0.5, &beats);
        CHECK(count == 1 && seconds == 1.0 && beats == 2.0, "track count %u, 4 beats at 240 BPM = %.2f s, 0.5 s = %.2f beats", (unsigned)count, seconds, beats);
        MusicTimeStamp length = 0;
        UInt32 size = sizeof(length);
        CHECK(MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &length, &size) == noErr && length == 3.5, "track length %.2f", length);
        CABarBeatTime bbt;
        CHECK(MusicSequenceBeatsToBarBeatTime(seq, 5.5, 4, &bbt) == noErr && bbt.bar == 2 && bbt.beat == 2 && bbt.subbeat == 2,
              "beats to bar/beat time: %d.%u.%u", bbt.bar, bbt.beat, bbt.subbeat);

        // the iterator
        MusicEventIterator it = NULL;
        CHECK(NewMusicEventIterator(track, &it) == noErr, "NewMusicEventIterator");
        int notes = 0, channel = 0, users = 0;
        Boolean has = false;
        MusicEventIteratorHasCurrentEvent(it, &has);
        while (has) {
            MusicTimeStamp t; MusicEventType type; const void *data; UInt32 dsize;
            MusicEventIteratorGetEventInfo(it, &t, &type, &data, &dsize);
            if (type == kMusicEventType_MIDINoteMessage) notes++;
            if (type == kMusicEventType_MIDIChannelMessage) channel++;
            if (type == kMusicEventType_User) users++;
            MusicEventIteratorNextEvent(it);
            MusicEventIteratorHasCurrentEvent(it, &has);
        }
        CHECK(notes == 4 && channel == 1 && users == 1, "iterated %d notes, %d channel, %d user events", notes, channel, users);
        CHECK(MusicEventIteratorNextEvent(it) == kAudioToolboxErr_EndOfTrack, "past the end: kAudioToolboxErr_EndOfTrack");
        MusicEventIteratorSeek(it, 2);
        MusicTimeStamp at = 0;
        MusicEventIteratorGetEventInfo(it, &at, NULL, NULL, NULL);
        CHECK(at == 2, "seek to beat 2: %.2f", at);
        DisposeMusicEventIterator(it);

        // a Standard MIDI File and back
        CFDataRef smf = NULL;
        CHECK(MusicSequenceFileCreateData(seq, kMusicSequenceFile_MIDIType, kMusicSequenceFileFlags_EraseFile, 480, &smf) == noErr && smf &&
              CFDataGetLength(smf) > 14 && memcmp(CFDataGetBytePtr(smf), "MThd", 4) == 0, "MusicSequenceFileCreateData");
        MusicSequence back = NULL;
        NewMusicSequence(&back);
        CHECK(MusicSequenceFileLoadData(back, smf, kMusicSequenceFile_AnyType, 0) == noErr, "MusicSequenceFileLoadData");
        UInt32 backCount = 0;
        MusicSequenceGetTrackCount(back, &backCount);
        Float64 backSeconds = 0;
        MusicSequenceGetSecondsForBeats(back, 4, &backSeconds);
        CHECK(backCount == 1 && backSeconds == 1.0, "read back: %u track, tempo kept (%.2f s)", (unsigned)backCount, backSeconds);
        CFRelease(smf);
        DisposeMusicSequence(back);

        // editing: cut a beat out
        MusicTrack copy = NULL;
        MusicSequenceNewTrack(seq, &copy);
        CHECK(MusicTrackCopyInsert(track, 0, 4, copy, 0) == noErr && MusicTrackCut(copy, 1, 2) == noErr, "copy and cut");
        size = sizeof(length);
        MusicTrackGetProperty(copy, kSequenceTrackProperty_TrackLength, &length, &size);
        CHECK(length == 2.5, "cut track length %.2f", length);
        CHECK(MusicSequenceDisposeTrack(seq, copy) == noErr, "MusicSequenceDisposeTrack");

        // ---- Music Player to a CoreMIDI destination ----
        MIDIClientRef client = 0;
        MIDIEndpointRef dest = 0;
        MIDIClientCreate(CFSTR("MIDIPlaybackTest"), NULL, NULL, &client);
        MIDIDestinationCreate(client, CFSTR("in"), readMIDI, NULL, &dest);
        CHECK(MusicTrackSetDestMIDIEndpoint(track, dest) == noErr, "MusicTrackSetDestMIDIEndpoint");
        MIDIEndpointRef got = 0;
        MusicTrackGetDestMIDIEndpoint(track, &got);
        CHECK(got == dest, "the track's destination endpoint");
        MusicSequenceSetUserCallback(seq, userCallback, NULL);
        MusicPlayer player = NULL;
        CHECK(NewMusicPlayer(&player) == noErr && MusicPlayerSetSequence(player, seq) == noErr && MusicPlayerPreroll(player) == noErr, "NewMusicPlayer");
        CHECK(MusicPlayerStart(player) == noErr, "MusicPlayerStart");
        Boolean playing = false;
        MusicPlayerIsPlaying(player, &playing);
        CHECK(playing, "playing");
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:10];
        while ((notesReceived < 4 || userEvents < 1) && [end timeIntervalSinceNow] > 0)
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        MusicTimeStamp now = 0;
        MusicPlayerGetTime(player, &now);
        CHECK(notesReceived == 4 && userEvents == 1 && now >= 3, "the destination heard %d notes, the user callback %d events, at beat %.2f",
              notesReceived, userEvents, now);
        MusicPlayerStop(player);
        MusicPlayerIsPlaying(player, &playing);
        CHECK(!playing, "stopped");
        DisposeMusicPlayer(player);
        DisposeMusicSequence(seq);

        // ---- the Sampler unit through MusicDevice.h ----
        AudioComponentDescription samplerDesc = {kAudioUnitType_MusicDevice, kAudioUnitSubType_Sampler, kAudioUnitManufacturer_Apple, 0, 0};
        AudioComponent comp = AudioComponentFindNext(NULL, &samplerDesc);
        AudioUnit sampler = NULL;
        CHECK(comp && AudioComponentInstanceNew(comp, &sampler) == noErr && AudioUnitInitialize(sampler) == noErr, "a Sampler unit");
        CHECK(MusicDeviceMIDIEvent(sampler, 0x90, 69, 100, 0) == noErr, "MusicDeviceMIDIEvent");
        NoteInstanceID noteID = 0;
        MusicDeviceNoteParams params = {.argCount = 2, .mPitch = 72, .mVelocity = 90};
        CHECK(MusicDeviceStartNote(sampler, kMusicNoteEvent_Unused, 0, &noteID, 0, &params) == noErr && noteID != 0, "MusicDeviceStartNote");
        CHECK(MusicDeviceStopNote(sampler, 0, noteID, 0) == noErr, "MusicDeviceStopNote");
        AudioStreamBasicDescription fmt = {48000, kAudioFormatLinearPCM, kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked,
                                           4, 1, 4, 2, 32, 0};
        AudioUnitSetProperty(sampler, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &fmt, sizeof(fmt));
        float left[1024], right[1024];
        struct { UInt32 n; AudioBuffer b[2]; } abl = {2, {{1, sizeof(left), left}, {1, sizeof(right), right}}};
        AudioUnitRenderActionFlags flags = 0;
        AudioTimeStamp ts = {.mFlags = kAudioTimeStampSampleTimeValid};
        OSStatus rs = AudioUnitRender(sampler, &flags, &ts, 0, 1024, (AudioBufferList *)&abl);
        float peak = 0;
        for (int i = 0; i < 1024; i++) if (fabsf(left[i]) > peak) peak = fabsf(left[i]);
        CHECK(rs == noErr && peak > 0.05f, "rendered the sine voice (status %d, peak %.2f)", (int)rs, peak);
        Float32 gain = 0;
        CHECK(AudioUnitSetParameter(sampler, kAUSamplerParam_Gain, kAudioUnitScope_Global, 0, -6, 0) == noErr &&
              AudioUnitGetParameter(sampler, kAUSamplerParam_Gain, kAudioUnitScope_Global, 0, &gain) == noErr && gain == -6, "kAUSamplerParam_Gain");
        AUSamplerInstrumentData missing = {(__bridge CFURLRef)[NSURL fileURLWithPath:@"/nonexistent.sf2"], kInstrumentType_SF2Preset, 0x79, 0, 0};
        CHECK(AudioUnitSetProperty(sampler, kAUSamplerProperty_LoadInstrument, kAudioUnitScope_Global, 0, &missing, sizeof(missing)) != noErr,
              "loading a missing SoundFont fails");
        AudioComponentInstanceDispose(sampler);

        // ---- Audio File Stream Services: a WAV made here, in pieces ----
        NSMutableData *wav = [NSMutableData data];
        UInt32 frames = 1000, dataBytes = frames * 2;
        #define U32(v) do { UInt32 x_ = (v); [wav appendBytes:&x_ length:4]; } while (0)
        #define U16(v) do { UInt16 x_ = (v); [wav appendBytes:&x_ length:2]; } while (0)
        [wav appendBytes:"RIFF" length:4]; U32(36 + dataBytes); [wav appendBytes:"WAVEfmt " length:8]; U32(16);
        U16(1); U16(1); U32(8000); U32(16000); U16(2); U16(16);
        [wav appendBytes:"data" length:4]; U32(dataBytes);
        [wav increaseLengthBy:dataBytes];
        AudioFileStreamID stream = NULL;
        CHECK(AudioFileStreamOpen(NULL, streamProperty, streamPacketsProc, kAudioFileWAVEType, &stream) == noErr && stream, "AudioFileStreamOpen");
        for (NSUInteger o = 0; o < wav.length; o += 300) {
            NSUInteger n = MIN(300, wav.length - o);
            AudioFileStreamParseBytes(stream, (UInt32)n, (const char *)wav.bytes + o, 0);
        }
        AudioStreamBasicDescription sfmt = {0};
        UInt32 ssize = sizeof(sfmt);
        CHECK(AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &ssize, &sfmt) == noErr && sfmt.mSampleRate == 8000 &&
              sfmt.mBitsPerChannel == 16, "the data format: %.0f Hz, %u bits", sfmt.mSampleRate, (unsigned)sfmt.mBitsPerChannel);
        CHECK(streamProperties == 1 && streamBytes == dataBytes && streamPackets == (int)frames, "ready once; %u bytes in %d packets",
              (unsigned)streamBytes, streamPackets);
        Boolean writable = true;
        UInt32 isize = 0;
        CHECK(AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_DataOffset, &isize, &writable) == noErr && isize == 8 && !writable,
              "property info");
        SInt64 byteOffset = 0;
        AudioFileStreamSeekFlags seekFlags = 0;
        CHECK(AudioFileStreamSeek(stream, 100, &byteOffset, &seekFlags) == noErr && byteOffset == 200, "seek to packet 100: byte %lld", byteOffset);
        CHECK(AudioFileStreamClose(stream) == noErr, "AudioFileStreamClose");

        // ---- CAClock ----
        CAClockRef clock = NULL;
        CHECK(CAClockNew(0, &clock) == noErr && clock, "CAClockNew");
        SMPTETime smpte;
        CHECK(CAClockSecondsToSMPTETime(clock, 61.5, 80, &smpte) == noErr && smpte.mMinutes == 1 && smpte.mSeconds == 1, "seconds to SMPTE");
        CAClockSeconds back2 = 0;
        CAClockSMPTETimeToSeconds(clock, &smpte, &back2);
        CHECK(fabs(back2 - 61.5) < 0.05, "and back: %.2f", back2);
        CHECK(CAClockStart(clock) == noErr && CAClockStop(clock) == noErr && CAClockDispose(clock) == noErr, "start, stop, dispose");

        // ---- AVFAudio ----
        AVAudioUnitSampler *avSampler = [[AVAudioUnitSampler alloc] init];
        avSampler.overallGain = -3;
        avSampler.globalTuning = 150;
        avSampler.stereoPan = -0.5f;
        CHECK(avSampler.overallGain == -3 && avSampler.globalTuning == 150 && avSampler.stereoPan == -0.5f && [avSampler isKindOfClass:AVAudioUnitMIDIInstrument.class],
              "AVAudioUnitSampler properties");
        NSError *error = nil;
        CHECK(![avSampler loadInstrumentAtURL:[NSURL fileURLWithPath:@"/nonexistent.aupreset"] error:&error] && error.code == -43, "a missing instrument: %ld",
              (long)error.code);
        [avSampler startNote:60 withVelocity:100 onChannel:0];
        [avSampler stopNote:60 onChannel:0];
        CHECK(avSampler.audioComponentDescription.componentSubType == kAudioUnitSubType_Sampler, "the sampler's component");

        AVAudioSequencer *sequencer = [[AVAudioSequencer alloc] init];
        AVMusicTrack *t = [sequencer createAndAppendTrack];
        [t addEvent:[[AVMIDINoteEvent alloc] initWithChannel:0 key:60 velocity:100 duration:1] atBeat:0];
        [t addEvent:[[AVMIDINoteEvent alloc] initWithChannel:0 key:62 velocity:100 duration:1] atBeat:2];
        [t addEvent:[[AVMIDIControlChangeEvent alloc] initWithChannel:0 messageType:AVMIDIControlChangeMessageTypePan value:20] atBeat:0];
        [t addEvent:[[AVMIDIMetaEvent alloc] initWithType:AVMIDIMetaEventTypeMarker data:[@"A" dataUsingEncoding:NSUTF8StringEncoding]] atBeat:1];
        [sequencer.tempoTrack addEvent:[[AVExtendedTempoEvent alloc] initWithTempo:120] atBeat:0];
        __block int seen = 0, pans = 0, markers = 0;
        [t enumerateEventsInRange:AVMakeBeatRange(0, AVMusicTimeStampEndOfTrack) usingBlock:^(AVMusicEvent *e, AVMusicTimeStamp *ts2, BOOL *remove) {
            seen++;
            if ([e isKindOfClass:AVMIDIControlChangeEvent.class] && ((AVMIDIControlChangeEvent *)e).messageType == AVMIDIControlChangeMessageTypePan) pans++;
            if ([e isKindOfClass:AVMIDIMetaEvent.class] && ((AVMIDIMetaEvent *)e).type == AVMIDIMetaEventTypeMarker) { markers++; *remove = YES; }
        }];
        __block int left2 = 0;
        [t enumerateEventsInRange:AVMakeBeatRange(0, 10) usingBlock:^(AVMusicEvent *e, AVMusicTimeStamp *ts2, BOOL *remove) { left2++; }];
        CHECK(seen == 4 && pans == 1 && markers == 1 && left2 == 3, "enumerated %d events (pan %d, marker %d removed: %d left)", seen, pans, markers, left2);
        [t moveEventsInRange:AVMakeBeatRange(2, 1) byAmount:1];
        t.loopRange = AVMakeBeatRange(0, 4);
        t.loopingEnabled = YES;
        t.numberOfLoops = 3;
        AVBeatRange lr = t.loopRange;
        CHECK(t.lengthInBeats == 4 && lr.start == 0 && lr.length == 4 && t.isLoopingEnabled && t.numberOfLoops == 3,
              "move, loop range %.1f+%.1f, length %.2f", lr.start, lr.length, t.lengthInBeats);
        CHECK([sequencer secondsForBeats:4] == 2 && [sequencer beatsForSeconds:1] == 2, "the sequencer's tempo map");
        NSData *smfData = [sequencer dataWithSMPTEResolution:480 error:&error];
        AVAudioSequencer *loaded = [[AVAudioSequencer alloc] init];
        CHECK([loaded loadFromData:smfData options:AVMusicSequenceLoadSMF_PreserveTracks error:&error] && loaded.tracks.count == 1, "loadFromData:options:error:");
        error = nil;
        CHECK([loaded hostTimeForBeats:1 error:&error] == 0 && error != nil, "hostTimeForBeats: fails while stopped");
        CHECK([sequencer removeTrack:t] && sequencer.tracks.count == 0 && ![sequencer removeTrack:sequencer.tempoTrack], "removeTrack:");

        // AVMIDIPlayer from the file
        NSError *perr = nil;
        AVMIDIPlayer *midi = [[AVMIDIPlayer alloc] initWithData:smfData soundBankURL:nil error:&perr];
        CHECK(midi && perr == nil && fabs(midi.duration - 2.0) < 0.01, "AVMIDIPlayer duration %.2f", midi.duration);
        midi.rate = 4;
        __block BOOL finished = NO;
        [midi prepareToPlay];
        [midi play:^{ finished = YES; }];
        CHECK(midi.isPlaying, "AVMIDIPlayer playing");
        wait_for(&finished);
        CHECK(finished && !midi.isPlaying, "AVMIDIPlayer completed");
        perr = nil;
        CHECK([[AVMIDIPlayer alloc] initWithData:[NSData dataWithBytes:"junk" length:4] soundBankURL:nil error:&perr] == nil && perr != nil, "junk data fails");

        printf("midi playback: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
