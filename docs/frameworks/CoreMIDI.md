# CoreMIDI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 98.6% of Apple's iOS API (986 of 1000, exact) · **Rows:** 19: 13 ✅ 6 🟡 · **iOS:** 4.2+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [CoreMIDI](https://developer.apple.com/documentation/coremidi) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Approach:** adapted, isim's own MIDI server in the app's process (`isim/frameworks/CoreMIDI`, a C and Objective-C framework), with a Swift overlay (`isim/swift/overlays/CoreMIDI`) for Apple's Swift additions:
  - **Objects:** clients, ports, devices, entities, endpoints and thru connections, named by `MIDIObjectRef`s, with properties and Apple's errors.
  - **Delivery:** messages go through a serial, high-priority delivery queue at their time stamps (host time, `mach_absolute_time`).
  - **Conversions:** between MIDI 1.0 bytes, MIDI 1.0 Universal MIDI Packets and MIDI 2.0 channel voice messages, with the specification's default translation (min-center-max scaling up, bit shifts down, a note on with velocity 0 as a note off).
  - **The simulated device:** "isim MIDI" has a source and a destination. The `midi` script command sends notes and bytes from its source and takes it offline or online ([SCRIPTING.md](../SCRIPTING.md)); what apps send to its destination is logged (`CoreMIDI: isim MIDI received 90 3C 64`).
  - **Host ports** (passthrough, *proposed*: no CI machine has a sequencer): with the host's ALSA sequencer (libasound, `/dev/snd/seq`), its ports appear as devices and messages are bridged both ways (`isim/runtime/host_midi.c`). `ISIM_MIDI_HOST=0` turns it off ([SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)).
- **Objective-C / C interface:** Apple's C API and classes, headers in `isim/sdk-src/Frameworks/CoreMIDI`.
- **Versus Apple's Simulator:**
  - The simulator has no MIDI devices; isim has the simulated device and the host's ports.
  - The MIDI server is per app: virtual endpoints of one app are not seen by other apps, and thru connections do not persist across launches.
  - There is no network MIDI (RTP-MIDI), no Bluetooth MIDI and no MIDI-CI device, as in the Simulator.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MIDIClientCreate`, `MIDIClientCreateWithBlock`, `MIDIClientDispose`, `MIDINotification` and its messages (`kMIDIMsgObjectAdded`, `kMIDIMsgSetupChanged`, `kMIDIMsgPropertyChanged`, `kMIDIMsgThruConnectionsChanged`, …) | ✅ | ≤17 | adapted: notifications arrive on the run loop of the thread that created the client; tested (HelloMIDI: `test_coremidi.py`; CoreMIDITest: `test_coremidi_objc.py`) |
| `MIDIInputPortCreateWithProtocol`, `MIDIInputPortCreate`, `MIDIInputPortCreateWithBlock`, `MIDIOutputPortCreate`, `MIDIPortDispose`, `MIDIPortConnectSource`, `MIDIPortDisconnectSource` | ✅ | ≤17 | adapted: a port hears its connected sources in its protocol (event lists) or as packet lists, with the connection's refCon; tested (HelloMIDI, CoreMIDITest) |
| `MIDISourceCreateWithProtocol`, `MIDIDestinationCreateWithProtocol`, `MIDISourceCreate`, `MIDIDestinationCreate`, `MIDIDestinationCreateWithBlock`, `MIDIEndpointDispose`, `MIDIEndpointSetRefCons` / `GetRefCons` | ✅ | ≤17 | adapted: virtual endpoints of the app's MIDI server; tested (HelloMIDI, CoreMIDITest) |
| `MIDIGetNumberOfSources` / `Destinations` / `Devices` / `ExternalDevices`, `MIDIGetSource`, `MIDIGetDestination`, `MIDIGetDevice`, `MIDIDeviceGetEntity`, `MIDIEntityGetSource` / `Destination` / `Device`, `MIDIEndpointGetEntity` | ✅ | ≤17 | adapted: offline devices' endpoints are not listed; tested (HelloMIDI, CoreMIDITest) |
| `MIDISend`, `MIDISendEventList`, `MIDIReceived`, `MIDIReceivedEventList`, `MIDIFlushOutput`, `MIDIRestart` | ✅ | ≤17 | adapted: delivered at their time stamps, converted to each receiver's format and protocol; flushing drops scheduled messages; tested (HelloMIDI, CoreMIDITest) |
| `MIDISendSysex`, `MIDISendUMPSysex`, `MIDISendUMPSysex8`, `MIDISysexSendRequest`, `MIDISysexSendRequestUMP`, `MIDIEventPacketSysexBytesForGroup` | ✅ | ≤17 | adapted: sent in the background at MIDI 1.0's rate, cancelled by setting `complete`; tested (HelloMIDI, CoreMIDITest) |
| `MIDIPacketList`, `MIDIEventList`, `MIDIPacketListInit` / `Add`, `MIDIEventListInit` / `Add`, `MIDIPacketNext`, `MIDIEventPacketNext`, `MIDIEventListForEachEvent`, `MIDIUniversalMessage` | ✅ | ≤17 | adapted: Apple's rules for sharing a packet (same time stamp, no system-exclusive); decoding of every message type; tested (CoreMIDITest) |
| Swift: `MIDIPacketList.Builder`, `MIDIEventList.Builder`, `MIDIPacket.Builder`, `MIDIEventPacket.Builder`, `ByteCollection`, `WordCollection`, `UnsafeSequence`, `UnsafeMutableMIDIPacketListPointer`, `UnsafeMutableMIDIEventListPointer` and the packet pointers, `unsafeSequence()`, `bytes()`, `words()` | ✅ | ≤17 | adapted: the overlay over the C lists; tested (HelloMIDI) |
| `MIDIMessages.h`: `MIDI1UP…` and `MIDI2…` message constructors, utility, flex data and UMP stream messages, `MIDIMessageTypeForUPWord`, `MIDICVStatus`, `MIDISystemStatus`, `MIDISysExStatus`, `MIDIUtilityStatus`, `UMPStreamMessageStatus` | ✅ | ≤17 | adapted: inline, the specification's words; tested (CoreMIDITest) |
| `MIDIObjectGet…Property`, `MIDIObjectSet…Property`, `MIDIObjectGetProperties`, `MIDIObjectRemoveProperty`, `MIDIObjectFindByUniqueID`, the `kMIDIProperty…` keys | ✅ | ≤17 | adapted: endpoints and entities inherit their device's properties; `kMIDIPropertyDisplayName` is computed; unique IDs are unique (`kMIDIIDNotUnique`); tested (HelloMIDI, CoreMIDITest) |
| `MIDIThruConnectionCreate`, `Dispose`, `GetParams`, `SetParams`, `Find`, `MIDIThruConnectionParams`, `MIDIThruConnectionParamsInitialize` / `Size`, `MIDITransform`, `MIDIControlTransform`, `MIDIValueMap` | ✅ | ≤17 | adapted: filters, channel map, note and velocity ranges, value transforms and maps, 7-bit control transforms; connections last as long as the app's process; tested (HelloMIDI, CoreMIDITest) |
| `MIDISetup…`, `MIDIExternalDeviceCreate`, `MIDIDeviceNewEntity`, `MIDIDeviceAddEntity`, `MIDIDeviceRemoveEntity`, `MIDIEntityAddOrRemoveEndpoints` | ✅ | ≤17 | adapted: the app's MIDI setup; tested (CoreMIDITest) |
| `MIDIDriverInterface`, `MIDIDeviceCreate`, `MIDIDeviceDispose`, `MIDIDeviceList…`, `MIDIGetDriverDeviceList`, `MIDIGetDriverIORunLoop`, `MIDIDriverEnableMonitoring` | 🟡 | ≤17 | stub: iOS apps load no MIDI drivers; the device and device-list functions work on the app's setup, monitoring is `kMIDINotPermitted` |
| Host MIDI ports | 🟡 | ≤17 | passthrough: the ALSA sequencer's ports as devices (proposed: not verified on CI, which has no sequencer) |
| `MIDINetworkSession`, `MIDINetworkHost`, `MIDINetworkConnection` | 🟡 | ≤17 | stub: the session's device, contacts and connections are kept; no RTP-MIDI session is opened; tested (HelloMIDI, CoreMIDITest) |
| `MIDIBluetoothDriverActivateAllConnections`, `MIDIBluetoothDriverDisconnect` | 🟡 | ≤17 | stub: no Bluetooth MIDI peripherals, as in the Simulator |
| `MIDICIDiscoveryManager`, `MIDICISession`, `MIDICIResponder`, `MIDICIProfile`, `MIDICIProfileState`, `MIDICIDeviceInfo`, `MIDICIDiscoveredNode` | 🟡 | ≤17 | stub: no MIDI-CI device answers: discovery finds no node; profiles, states and device info are values with secure coding; tested (CoreMIDITest) |
| `MIDIUMPMutableEndpoint`, `MIDIUMPMutableFunctionBlock`, `MIDIUMPEndpoint`, `MIDIUMPFunctionBlock`, `MIDIUMPEndpointManager`, `MIDI2DeviceInfo` | ✅ | 18.0 | adapted: an enabled endpoint is a virtual source and destination pair of the app's server; static function blocks are locked; tested (HelloMIDI, CoreMIDITest) |
| `MIDICIDeviceManager`, `MIDICIDevice`, `MIDIUMPCIProfile` | 🟡 | 18.0 | stub: no MIDI-CI devices are discovered; tested (CoreMIDITest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
14 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var kMIDINoteAttributeManufacturerSpecific: Int`](https://developer.apple.com/documentation/coremidi/kmidinoteattributemanufacturerspecific)
- [`var kMIDINoteAttributeNone: Int`](https://developer.apple.com/documentation/coremidi/kmidinoteattributenone)
- [`var kMIDINoteAttributePitch: Int`](https://developer.apple.com/documentation/coremidi/kmidinoteattributepitch)
- [`var kMIDINoteAttributeProfileSpecific: Int`](https://developer.apple.com/documentation/coremidi/kmidinoteattributeprofilespecific)
- [`static let deviceObject: MIDICIDeviceManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midicidevicemanager/dictionarykey/deviceobject)
- [`static let deviceObject: MIDICIDeviceManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midicidevicemanager/dictionarykey/deviceobject)
- [`static let profileObject: MIDICIDeviceManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midicidevicemanager/dictionarykey/profileobject)
- [`static let profileObject: MIDICIDeviceManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midicidevicemanager/dictionarykey/profileobject)
- [`case midiNAK`](https://developer.apple.com/documentation/coremidi/midicimanagementmessagetype/midinak)
- [`case invalid`](https://developer.apple.com/documentation/coremidi/midimessagetype/invalid)
- [`init(version: UInt32, numSources: UInt32, sources: (MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint), numDestinations: UInt32, destinations: (MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint, MIDIThruConnectionEndpoint), channelMap: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8), lowVelocity: UInt8, highVelocity: UInt8, lowNote: UInt8, highNote: UInt8, noteNumber: MIDITransform, velocity: MIDITransform, keyPressure: MIDITransform, channelPressure: MIDITransform, programChange: MIDITransform, pitchBend: MIDITransform, filterOutSysEx: UInt8, filterOutMTC: UInt8, filterOutBeatClock: UInt8, filterOutTuneRequest: UInt8, reserved2: (UInt8, UInt8, UInt8), filterOutAllControls: UInt8, numControlTransforms: UInt16, numMaps: UInt16, reserved3: (UInt16, UInt16, UInt16, UInt16))`](https://developer.apple.com/documentation/coremidi/midithruconnectionparams/init(version:numsources:sources:numdestinations:destinations:channelmap:lowvelocity:highvelocity:lownote:highnote:notenumber:velocity:keypressure:channelpressure:programchange:pitchbend:filteroutsysex:filteroutmtc:filteroutbeatclock:filtero-6y1ig)
- [`static let endpointObject: MIDIUMPEndpointManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midiumpendpointmanager/dictionarykey/endpointobject)
- [`static let functionBlockObject: MIDIUMPEndpointManager.DictionaryKey`](https://developer.apple.com/documentation/coremidi/midiumpendpointmanager/dictionarykey/functionblockobject)
- [`func reconfigure(firstGroup: MIDIUMPGroupNumber, direction: MIDIUMPFunctionBlockDirection, MIDI1Info: MIDIUMPFunctionBlockMIDI1Info, UIHint: MIDIUMPFunctionBlockUIHint) throws`](https://developer.apple.com/documentation/coremidi/midiumpmutablefunctionblock/reconfigure(firstgroup:direction:midi1info:uihint:))

</details>
<!-- /generated:missing -->
