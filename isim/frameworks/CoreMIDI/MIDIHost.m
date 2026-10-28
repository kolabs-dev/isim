// isim CoreMIDI: the host's MIDI ports (passthrough, runtime/host_midi.c over the ALSA sequencer). Each host port is a
// device with one entity: a source when the port sends, a destination when it receives. A thread reads the host's
// messages and hands them to the sources; messages sent to the destinations go to the host ports.
#import "MIDIPrivate.h"
#include <isim_host.h>

static NSMutableDictionary<NSNumber *, _MIDIObject *> *hostSources;

void _MIDIHostStart(void) {
    char *buf = malloc(16384);
    int n = isim_midi_host_ports(buf, 16384);
    NSString *list = n > 0 ? [NSString stringWithUTF8String:buf] : nil;
    free(buf);
    if (!list) return;
    hostSources = [NSMutableDictionary dictionary];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        NSArray<NSString *> *f = [line componentsSeparatedByString:@"\t"];
        if (f.count < 3) continue;
        int portID = f[0].intValue;
        BOOL sends = [f[2] containsString:@"r"], receives = [f[2] containsString:@"w"];
        MIDIDeviceRef dev; MIDIEntityRef ent;
        MIDIDeviceCreate(NULL, (__bridge CFStringRef)f[1], CFSTR("host"), (__bridge CFStringRef)f[1], &dev);
        MIDIDeviceNewEntity(dev, (__bridge CFStringRef)f[1], kMIDIProtocol_1_0, true, sends ? 1 : 0, receives ? 1 : 0, &ent);
        _MIDIObject *d = _MIDILookup(dev, _MIDIKindDevice);
        d.props[@"isim.host"] = @YES;
        for (_MIDIObject *e in d.children) for (_MIDIObject *p in e.children) {
            p.props[@"isim.hostPort"] = @(portID);
            if (p.type == kMIDIObjectType_Source) hostSources[@(portID)] = p;
        }
        MIDISetupAddDevice(dev);
    }
    if (!hostSources.count) return;
    NSThread *reader = [[NSThread alloc] initWithBlock:^{
        unsigned char msg[1024];
        for (;;) {
            int portID = 0;
            int len = isim_midi_host_receive(msg, sizeof msg, &portID, 0.5);
            if (len <= 0) continue;
            _MIDIObject *src = hostSources[@(portID)];
            if (src) _MIDIReceivedMessages(src, _MIDIMessagesFromBytes([NSData dataWithBytes:msg length:len], 0));
        }
    }];
    reader.name = @"isim.coremidi.host";
    reader.qualityOfService = NSQualityOfServiceUserInteractive;
    [reader start];
}

void _MIDIHostSend(_MIDIObject *dest, NSData *bytes) {
    NSNumber *portID = dest.props[@"isim.hostPort"];
    if (portID && bytes.length) isim_midi_host_send(portID.intValue, bytes.bytes, (int)bytes.length);
}
