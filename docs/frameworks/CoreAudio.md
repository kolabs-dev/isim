# CoreAudio

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 12.5% of Apple's iOS API (9 of 72, exact) · **Rows:** 2: 2 ✅ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [Core Audio](https://developer.apple.com/documentation/coreaudio) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** on iOS, Core Audio is the audio data types (the hardware abstraction layer is macOS only). `import CoreAudio` is a module that re-exports AudioToolbox (`isim/swift/overlays/CoreAudio.swift`), where isim keeps the types' Swift side; the C structs are the CoreAudioTypes module. Rows: [CoreAudioTypes](CoreAudioTypes.md), [AudioToolbox](AudioToolbox.md).
- **Objective-C / C interface:** `<CoreAudio/CoreAudio.h>` and `<CoreAudio/CoreAudioTypes.h>` (`isim/sdk-src/Frameworks/CoreAudio`): the structs plus the format IDs and linear PCM flags.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `import CoreAudio`, `import CoreAudioTypes` | ✅ | 2.0 | adapted: CoreAudio re-exports AudioToolbox; CoreAudioTypes is the C module of the structs. Tested (HelloAudioModules) |
| `#import <CoreAudio/CoreAudioTypes.h>`, `-framework CoreAudio`: `AudioStreamBasicDescription`, `AudioBufferList`, `AudioTimeStamp`, `kAudioFormat…` IDs, `kAudioFormatFlag…` / `kLinearPCMFormatFlag…` | ✅ | 2.0 | Apple's values and layouts. Tested (AudioHeadersTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
63 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func AudioConvertHostTimeToNanos(UInt64) -> UInt64`](https://developer.apple.com/documentation/coreaudio/audioconverthosttimetonanos(_:))
- [`func AudioConvertNanosToHostTime(UInt64) -> UInt64`](https://developer.apple.com/documentation/coreaudio/audioconvertnanostohosttime(_:))
- [`func AudioDeviceCreateIOProcID(AudioObjectID, AudioDeviceIOProc, UnsafeMutableRawPointer?, UnsafeMutablePointer<AudioDeviceIOProcID?>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicecreateioprocid(_:_:_:_:))
- [`func AudioDeviceCreateIOProcIDWithBlock(UnsafeMutablePointer<AudioDeviceIOProcID?>, AudioObjectID, dispatch_queue_t?, AudioDeviceIOBlock) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicecreateioprocidwithblock(_:_:_:_:))
- [`func AudioDeviceDestroyIOProcID(AudioObjectID, AudioDeviceIOProcID) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicedestroyioprocid(_:_:))
- [`func AudioDeviceGetCurrentTime(AudioObjectID, UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicegetcurrenttime(_:_:))
- [`func AudioDeviceGetNearestStartTime(AudioObjectID, UnsafeMutablePointer<AudioTimeStamp>, UInt32) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicegetneareststarttime(_:_:_:))
- [`func AudioDeviceStart(AudioObjectID, AudioDeviceIOProcID?) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicestart(_:_:))
- [`func AudioDeviceStartAtTime(AudioObjectID, AudioDeviceIOProcID?, UnsafeMutablePointer<AudioTimeStamp>, UInt32) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicestartattime(_:_:_:_:))
- [`func AudioDeviceStop(AudioObjectID, AudioDeviceIOProcID?) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicestop(_:_:))
- [`func AudioDeviceTranslateTime(AudioObjectID, UnsafePointer<AudioTimeStamp>, UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiodevicetranslatetime(_:_:_:))
- [`func AudioGetCurrentHostTime() -> UInt64`](https://developer.apple.com/documentation/coreaudio/audiogetcurrenthosttime())
- [`func AudioGetHostClockFrequency() -> Float64`](https://developer.apple.com/documentation/coreaudio/audiogethostclockfrequency())
- [`func AudioGetHostClockMinimumTimeDelta() -> UInt32`](https://developer.apple.com/documentation/coreaudio/audiogethostclockminimumtimedelta())
- [`func AudioHardwareCreateAggregateDevice(CFDictionary, UnsafeMutablePointer<AudioObjectID>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiohardwarecreateaggregatedevice(_:_:))
- [`func AudioHardwareDestroyAggregateDevice(AudioObjectID) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiohardwaredestroyaggregatedevice(_:))
- [`func AudioHardwareUnload() -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audiohardwareunload())
- [`func AudioObjectAddPropertyListener(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, AudioObjectPropertyListenerProc, UnsafeMutableRawPointer?) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectaddpropertylistener(_:_:_:_:))
- [`func AudioObjectAddPropertyListenerBlock(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, dispatch_queue_t?, AudioObjectPropertyListenerBlock) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectaddpropertylistenerblock(_:_:_:_:))
- [`func AudioObjectGetPropertyData(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, UInt32, UnsafeRawPointer?, UnsafeMutablePointer<UInt32>, UnsafeMutableRawPointer) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectgetpropertydata(_:_:_:_:_:_:))
- [`func AudioObjectGetPropertyDataSize(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, UInt32, UnsafeRawPointer?, UnsafeMutablePointer<UInt32>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectgetpropertydatasize(_:_:_:_:_:))
- [`func AudioObjectHasProperty(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>) -> Bool`](https://developer.apple.com/documentation/coreaudio/audioobjecthasproperty(_:_:))
- [`func AudioObjectIsPropertySettable(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, UnsafeMutablePointer<DarwinBoolean>) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectispropertysettable(_:_:_:))
- [`func AudioObjectRemovePropertyListener(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, AudioObjectPropertyListenerProc, UnsafeMutableRawPointer?) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectremovepropertylistener(_:_:_:_:))
- [`func AudioObjectRemovePropertyListenerBlock(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, dispatch_queue_t?, AudioObjectPropertyListenerBlock) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectremovepropertylistenerblock(_:_:_:_:))
- [`func AudioObjectSetPropertyData(AudioObjectID, UnsafePointer<AudioObjectPropertyAddress>, UInt32, UnsafeRawPointer?, UInt32, UnsafeRawPointer) -> OSStatus`](https://developer.apple.com/documentation/coreaudio/audioobjectsetpropertydata(_:_:_:_:_:_:))
- [`func AudioObjectShow(AudioObjectID)`](https://developer.apple.com/documentation/coreaudio/audioobjectshow(_:))
- [`CATapDescription`](https://developer.apple.com/documentation/coreaudio/catapdescription)
- [`var bundleIDs: [String]`](https://developer.apple.com/documentation/coreaudio/catapdescription/bundleids)
- [`var deviceUID: String?`](https://developer.apple.com/documentation/coreaudio/catapdescription/deviceuid)
- [`init()`](https://developer.apple.com/documentation/coreaudio/catapdescription/init())
- [`var isExclusive: Bool`](https://developer.apple.com/documentation/coreaudio/catapdescription/isexclusive)
- [`var isMixdown: Bool`](https://developer.apple.com/documentation/coreaudio/catapdescription/ismixdown)
- [`var isMono: Bool`](https://developer.apple.com/documentation/coreaudio/catapdescription/ismono)
- [`var isPrivate: Bool`](https://developer.apple.com/documentation/coreaudio/catapdescription/isprivate)
- [`var isProcessRestoreEnabled: Bool`](https://developer.apple.com/documentation/coreaudio/catapdescription/isprocessrestoreenabled)
- [`var muteBehavior: CATapMuteBehavior`](https://developer.apple.com/documentation/coreaudio/catapdescription/mutebehavior)
- [`var name: String`](https://developer.apple.com/documentation/coreaudio/catapdescription/name)
- [`var uuid: UUID`](https://developer.apple.com/documentation/coreaudio/catapdescription/uuid)
- [`CATapMuteBehavior`](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/init(rawvalue:))
- [`case muted`](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/muted)
- [`case mutedWhenTapped`](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/mutedwhentapped)
- [`case unmuted`](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/unmuted)
- [`var kAudioSubDeviceDriftCompensationHighQuality: UInt32`](https://developer.apple.com/documentation/coreaudio/kaudiosubdevicedriftcompensationhighquality)
- [`var kAudioSubDeviceDriftCompensationLowQuality: UInt32`](https://developer.apple.com/documentation/coreaudio/kaudiosubdevicedriftcompensationlowquality)
- [`var kAudioSubDeviceDriftCompensationMaxQuality: UInt32`](https://developer.apple.com/documentation/coreaudio/kaudiosubdevicedriftcompensationmaxquality)
- [`var kAudioSubDeviceDriftCompensationMediumQuality: UInt32`](https://developer.apple.com/documentation/coreaudio/kaudiosubdevicedriftcompensationmediumquality)
- [`var kAudioSubDeviceDriftCompensationMinQuality: UInt32`](https://developer.apple.com/documentation/coreaudio/kaudiosubdevicedriftcompensationminquality)
- [`ManagedAudioChannelLayout`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout)
- [`var bitmap: AudioChannelBitmap`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/bitmap)
- [`var channelDescriptions: ManagedAudioChannelLayout.ChannelDescriptions`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/channeldescriptions-swift.property)
- [`ManagedAudioChannelLayout.ChannelDescriptions`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/channeldescriptions-swift.struct)
- [`init(audioChannelLayoutPointer: AudioChannelLayout.UnsafePointer, deallocator: (AudioChannelLayout.UnsafePointer) -> Void)`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/init(audiochannellayoutpointer:deallocator:))
- [`init(channelDescriptions: [AudioChannelDescription])`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/init(channeldescriptions:))
- [`init(maximumDescriptions: Int)`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/init(maximumdescriptions:))
- [`init(tag: AudioChannelLayoutTag)`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/init(tag:))
- [`var numberOfChannels: Int`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/numberofchannels)
- [`func setAllToUnknown()`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/setalltounknown())
- [`var sizeInBytes: Int`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/sizeinbytes)
- [`var tag: AudioChannelLayoutTag`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/tag)
- [`func withUnsafeMutablePointer<Result>((UnsafeMutablePointer<AudioChannelLayout>) throws -> Result) rethrows -> Result`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/withunsafemutablepointer(_:))
- [`func withUnsafePointer<Result>((UnsafePointer<AudioChannelLayout>) throws -> Result) rethrows -> Result`](https://developer.apple.com/documentation/coreaudio/managedaudiochannellayout/withunsafepointer(_:))

</details>
<!-- /generated:missing -->
