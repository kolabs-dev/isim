# CoreHaptics

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 88.0% of Apple's iOS API (183 of 208, exact) · **Rows:** 6: 5 ✅ 1 🟡 · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [Core Haptics](https://developer.apple.com/documentation/corehaptics) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** a fully modelled engine (patterns, players, parameter curves, AHAP files). `supportsHaptics` is false, like the Simulator: the device's haptic events are shown as UIKit's feedback ring and logged; a gamepad's engine (`GCController.haptics`) drives the pad's rumble motors ([GameController](GameController.md)). Audio events play through isim's audio output. Rows: [UIKit](UIKit.md) (Haptics & feedback).
- **Objective-C / C interface:** `#import <CoreHaptics/CoreHaptics.h>` and `-framework CoreHaptics` (`isim/sdk-src/Frameworks/CoreHaptics`) reach the Swift overlay's classes under their Objective-C names; `isim/swift/overlays/CoreHaptics/ObjC.swift` has the entry points for the Swift-only types (the ID / type / key structs are `NSString`s in Objective-C) and `isim/frameworks/CoreHaptics/CoreHaptics.m` the constants.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| CoreHaptics' Objective-C interface: `CHHapticEngine` (`capabilitiesForHardware`, `initAndReturnError:`, handlers, `startAndReturnError:`, `createPlayerWithPattern:error:`, `createAdvancedPlayerWithPattern:error:`, `notifyWhenPlayersFinished:`, `playPatternFromURL:` / `FromData:`, audio resources), `CHHapticPattern` (events, parameters, curves, `initWithDictionary:error:`, `initWithContentsOfURL:error:`, `exportDictionaryAndReturnError:`), `CHHapticEvent`, `CHHapticEventParameter`, `CHHapticDynamicParameter`, `CHHapticParameterCurve`(`ControlPoint`), the `CHHapticPatternPlayer` / `CHHapticAdvancedPatternPlayer` / `CHHapticDeviceCapability` / `CHHapticParameterAttributes` protocols, the `CHHapticEventParameterID…`, `CHHapticDynamicParameterID…`, `CHHapticEventType…`, `CHHapticPatternKey…` and `CHHapticAudioResourceKey…` constants, `CHHapticErrorDomain` / `CHHapticErrorCode` | ✅ | ≤17 | adapted: as the Swift engine; the players are isim objects answering the protocols' selectors; the classes are not subclassable from Objective-C. Tested (tests/games-objc: capability, patterns from events, a curve and a dictionary, a refused pattern, both players with completion, the finished handler, AHAP data) |
| `CHHapticEngine` (`start`, `stop`, `capabilitiesForHardware()`, `makePlayer` / `makeAdvancedPlayer`, `notifyWhenPlayersFinished`, `playPattern(from:)`, `isMutedForAudio` / `isMutedForHaptics`, `playsHapticsOnly` / `playsAudioOnly`, stopped / reset handlers) | ✅ | ≤17 | adapted: `supportsHaptics` false (no Taptic Engine, like the Simulator), `supportsAudio` true; each haptic event of the device's engine is shown as UIKit's feedback ring at mid-screen and logged (`CoreHaptics: transient intensity …`); a gamepad's engine rumbles the pad instead; tested (HelloCoreAnimation, test_coreanimation) |
| `CHHapticEvent`, `CHHapticEventParameter`, `CHHapticPattern` (events, dynamic parameters, parameter curves, AHAP dictionaries and files, `exportDictionary`) | ✅ | ≤17 | patterns are validated and timed as on iOS (a transient lasts about 22 ms); tested (HelloCoreAnimation) |
| Players: `CHHapticPatternPlayer`, `CHHapticAdvancedPatternPlayer` (start / stop / pause / resume / seek, loops, `playbackRate`, `isMuted`, completion), `sendParameters` | 🟡 | ≤17 | adapted: each event fires at its time; `hapticIntensityControl` and `audioVolumeControl` scale the events that follow; parameter curves are accepted but not applied |
| Audio events: `audioContinuous`, `audioCustom` with `registerAudioResource(_:options:)` / `unregisterAudioResource`, `CHHapticAudioResourceKey` (`useVolumeEnvelope`, `loopEnabled`) | ✅ | ≤17 | adapted: audioContinuous is a synthesised tone around 440 Hz (`AudioPitch` an octave down or up, `AudioBrightness` adds odd harmonics, attack and release times shape it); audioCustom plays the resource (any file AVAudioFile reads) with `AudioVolume`, `AudioPitch` (speed) and `AudioPan`, looped with `loopEnabled`, cut to the event's duration; mixed into isim's audio output; tested (HelloCoreAnimation, test_coreanimation: 440 Hz then 880 Hz on the mixed output) |
| `CHHapticError` (codes), `CHHapticErrorDomain` | ✅ | ≤17 | `com.apple.CoreHaptics`; tested (HelloCoreAnimation) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
25 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`let CHHapticAudioResourceKeyLoopEnabled: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyloopenabled)
- [`let CHHapticAudioResourceKeyUseVolumeEnvelope: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyusevolumeenvelope)
- [`init(andReturnError: ()) throws`](https://developer.apple.com/documentation/corehaptics/chhapticengine/init(andreturnerror:))
- [`static var badEventEntry: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/badevententry)
- [`static var badParameterEntry: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/badparameterentry)
- [`static var engineStartTimeout: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/enginestarttimeout)
- [`static var fileNotFound: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/filenotfound)
- [`static var insufficientPower: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/insufficientpower)
- [`static var invalidAudioResource: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalidaudioresource)
- [`static var invalidAudioSession: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalidaudiosession)
- [`static var invalidEngineParameter: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalidengineparameter)
- [`static var invalidEventDuration: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalideventduration)
- [`static var invalidEventType: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalideventtype)
- [`static var invalidParameterType: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalidparametertype)
- [`static var invalidTime: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/invalidtime)
- [`static var memoryError: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/memoryerror)
- [`static var notSupported: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/notsupported)
- [`static var operationNotPermitted: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/operationnotpermitted)
- [`static var resourceNotAvailable: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/resourcenotavailable)
- [`static var serverInitFailed: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/serverinitfailed)
- [`static var serverInterrupted: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/serverinterrupted)
- [`static var unknownError: CHHapticError.Code`](https://developer.apple.com/documentation/corehaptics/chhapticerror/unknownerror)
- [`init(contentsOfURL: URL) throws`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/init(contentsofurl:))
- [`static let eventWaveformLoopEnabled: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventwaveformloopenabled)
- [`let CoreHapticsErrorDomain: String`](https://developer.apple.com/documentation/corehaptics/corehapticserrordomain)

</details>
<!-- /generated:missing -->
