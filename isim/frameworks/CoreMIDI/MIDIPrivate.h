// isim CoreMIDI: what the framework's files share (not a public header).
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

enum { _MIDIKindClient = 1, _MIDIKindPort, _MIDIKindDevice, _MIDIKindEntity, _MIDIKindEndpoint, _MIDIKindThru, _MIDIKindDeviceList };

/* an object of the MIDI server */
@interface _MIDIObject : NSObject
@property (nonatomic) MIDIObjectRef ref;
@property (nonatomic) int kind;
@property (nonatomic) MIDIObjectType type;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *props;
@property (nonatomic) MIDIObjectRef parent;               // entity of an endpoint, device of an entity
@property (nonatomic, strong) NSMutableArray<_MIDIObject *> *children;
@property (nonatomic) MIDIClientRef client;               // the client of a port or virtual endpoint
@property (nonatomic) MIDIProtocolID protocol;
@property (nonatomic) BOOL input, disposed;
@property (nonatomic) uint64_t flushGeneration;
@property (nonatomic) MIDIDriverRef driver;
// a client's notifications
@property (nonatomic) MIDINotifyProc notifyProc;
@property (nonatomic) void *notifyRefCon;
@property (nonatomic, copy) MIDINotifyBlock notifyBlock;
@property (nonatomic) CFRunLoopRef runLoop;
// an input port's or virtual destination's reader
@property (nonatomic) MIDIReadProc readProc;
@property (nonatomic) void *readRefCon;
@property (nonatomic, copy) MIDIReadBlock readBlock;
@property (nonatomic, copy) MIDIReceiveBlock receiveBlock;
@property (nonatomic) MIDIProtocolID receiveProtocol;
@property (nonatomic) void *refCon1, *refCon2;
// a source's input ports: port ref -> connection refCon (NSValue)
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *connections;
// a thru connection
@property (nonatomic, strong) NSData *thruParams;
@property (nonatomic, copy) NSString *thruOwner;
@end

/* one message: MIDI 1.0 bytes (a whole message, or a piece of a system-exclusive one), or one Universal MIDI Packet */
@interface _MIDIMessage : NSObject
@property (nonatomic) MIDITimeStamp timeStamp;
@property (nonatomic, strong) NSData *bytes;
@property (nonatomic, strong) NSData *words;              // UInt32s
@end

_MIDIObject *_MIDILookup(MIDIObjectRef ref, int kind);
_MIDIObject *_MIDINew(int kind, MIDIObjectType type, NSString *name);
NSRecursiveLock *_MIDILock(void);
uint64_t _MIDINow(void);
void _MIDINotifyAddRemove(BOOL added, _MIDIObject *parent, _MIDIObject *child);
void _MIDINotifySetupChanged(void);
void _MIDINotifyThruChanged(void);
void _MIDIReceivedMessages(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs);
void _MIDISendMessages(_MIDIObject *dest, NSArray<_MIDIMessage *> *msgs);

/* MIDIConvert.m */
NSArray<_MIDIMessage *> *_MIDIMessagesFromPacketList(const MIDIPacketList *list);
NSArray<_MIDIMessage *> *_MIDIMessagesFromEventList(const MIDIEventList *list);
NSArray<_MIDIMessage *> *_MIDIMessagesFromBytes(NSData *bytes, MIDITimeStamp t);
NSArray<_MIDIMessage *> *_MIDIMessagesFromWords(const UInt32 *words, UInt32 count, MIDITimeStamp t);
NSData *_MIDIPacketListFromMessages(NSArray<_MIDIMessage *> *msgs);
NSData *_MIDIEventListFromMessages(NSArray<_MIDIMessage *> *msgs, MIDIProtocolID protocol);
NSData *_MIDIBytesFromWords(NSData *words);
NSArray<NSData *> *_MIDIWordsForProtocol(_MIDIMessage *m, MIDIProtocolID protocol);

/* MIDIThruConnection.m */
void _MIDIThruDeliver(_MIDIObject *src, NSArray<_MIDIMessage *> *msgs);

/* MIDIHost.m: the host's ALSA sequencer */
void _MIDIHostStart(void);
void _MIDIHostSend(_MIDIObject *dest, NSData *bytes);
