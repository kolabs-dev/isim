# CoreHaptics

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 68.0% of Apple's iOS API (170 of 250, exact) · **Rows:** 5: 4 ✅ 1 🟡 · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [Core Haptics](https://developer.apple.com/documentation/corehaptics) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** a fully modelled engine (patterns, players, parameter curves, AHAP files). `supportsHaptics` is false, like the Simulator: the device's haptic events are shown as UIKit's feedback ring and logged; a gamepad's engine (`GCController.haptics`) drives the pad's rumble motors ([GameController](GameController.md)). Audio events play through isim's audio output. Rows: [UIKit](UIKit.md) (Haptics & feedback).
- **Objective-C / C interface:** none yet (Swift only; #548).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CHHapticEngine` (`start`, `stop`, `capabilitiesForHardware()`, `makePlayer` / `makeAdvancedPlayer`, `notifyWhenPlayersFinished`, `playPattern(from:)`, `isMutedForAudio` / `isMutedForHaptics`, `playsHapticsOnly` / `playsAudioOnly`, stopped / reset handlers) | ✅ | ≤17 | adapted: `supportsHaptics` false (no Taptic Engine, like the Simulator), `supportsAudio` true; each haptic event of the device's engine is shown as UIKit's feedback ring at mid-screen and logged (`CoreHaptics: transient intensity …`); a gamepad's engine rumbles the pad instead; tested (HelloCoreAnimation, test_coreanimation) |
| `CHHapticEvent`, `CHHapticEventParameter`, `CHHapticPattern` (events, dynamic parameters, parameter curves, AHAP dictionaries and files, `exportDictionary`) | ✅ | ≤17 | patterns are validated and timed as on iOS (a transient lasts about 22 ms); tested (HelloCoreAnimation) |
| Players: `CHHapticPatternPlayer`, `CHHapticAdvancedPatternPlayer` (start / stop / pause / resume / seek, loops, `playbackRate`, `isMuted`, completion), `sendParameters` | 🟡 | ≤17 | adapted: each event fires at its time; `hapticIntensityControl` and `audioVolumeControl` scale the events that follow; parameter curves are accepted but not applied |
| Audio events: `audioContinuous`, `audioCustom` with `registerAudioResource(_:options:)` / `unregisterAudioResource`, `CHHapticAudioResourceKey` (`useVolumeEnvelope`, `loopEnabled`) | ✅ | ≤17 | adapted: audioContinuous is a synthesised tone around 440 Hz (`AudioPitch` an octave down or up, `AudioBrightness` adds odd harmonics, attack and release times shape it); audioCustom plays the resource (any file AVAudioFile reads) with `AudioVolume`, `AudioPitch` (speed) and `AudioPan`, looped with `loopEnabled`, cut to the event's duration; mixed into isim's audio output; tested (HelloCoreAnimation, test_coreanimation: 440 Hz then 880 Hz on the mixed output) |
| `CHHapticError` (codes), `CHHapticErrorDomain` | ✅ | ≤17 | `com.apple.CoreHaptics`; tested (HelloCoreAnimation) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
80 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`let CHHapticAudioResourceKeyLoopEnabled: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyloopenabled)
- [`let CHHapticAudioResourceKeyLoopEnabled: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyloopenabled)
- [`let CHHapticAudioResourceKeyUseVolumeEnvelope: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyusevolumeenvelope)
- [`let CHHapticAudioResourceKeyUseVolumeEnvelope: String`](https://developer.apple.com/documentation/corehaptics/chhapticaudioresourcekeyusevolumeenvelope)
- [`static let audioAttackTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audioattacktimecontrol)
- [`static let audioBrightnessControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audiobrightnesscontrol)
- [`static let audioDecayTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audiodecaytimecontrol)
- [`static let audioPanControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audiopancontrol)
- [`static let audioPitchControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audiopitchcontrol)
- [`static let audioReleaseTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audioreleasetimecontrol)
- [`static let audioVolumeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/audiovolumecontrol)
- [`static let hapticAttackTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/hapticattacktimecontrol)
- [`static let hapticDecayTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/hapticdecaytimecontrol)
- [`static let hapticIntensityControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/hapticintensitycontrol)
- [`static let hapticReleaseTimeControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/hapticreleasetimecontrol)
- [`static let hapticSharpnessControl: CHHapticDynamicParameter.ID`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/hapticsharpnesscontrol)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corehaptics/chhapticdynamicparameter/id/init(rawvalue:))
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
- [`static let audioContinuous: CHHapticEvent.EventType`](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/audiocontinuous)
- [`static let audioCustom: CHHapticEvent.EventType`](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/audiocustom)
- [`static let hapticContinuous: CHHapticEvent.EventType`](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/hapticcontinuous)
- [`static let hapticTransient: CHHapticEvent.EventType`](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/haptictransient)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/init(rawvalue:))
- [`static let attackTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/attacktime)
- [`static let attackTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/attacktime)
- [`static let audioBrightness: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiobrightness)
- [`static let audioBrightness: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiobrightness)
- [`static let audioPan: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiopan)
- [`static let audioPan: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiopan)
- [`static let audioPitch: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiopitch)
- [`static let audioPitch: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiopitch)
- [`static let audioVolume: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiovolume)
- [`static let audioVolume: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/audiovolume)
- [`static let decayTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/decaytime)
- [`static let decayTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/decaytime)
- [`static let hapticIntensity: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticintensity)
- [`static let hapticIntensity: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticintensity)
- [`static let hapticSharpness: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticsharpness)
- [`static let hapticSharpness: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticsharpness)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/init(rawvalue:))
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/init(rawvalue:))
- [`static let releaseTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/releasetime)
- [`static let releaseTime: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/releasetime)
- [`static let sustained: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/sustained)
- [`static let sustained: CHHapticEvent.ParameterID`](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/sustained)
- [`static let event: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/event)
- [`static let eventDuration: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventduration)
- [`static let eventParameters: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventparameters)
- [`static let eventType: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventtype)
- [`static let eventWaveformLoopEnabled: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventwaveformloopenabled)
- [`static let eventWaveformPath: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventwaveformpath)
- [`static let eventWaveformUseVolumeEnvelope: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/eventwaveformusevolumeenvelope)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/init(rawvalue:))
- [`static let parameter: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/parameter)
- [`static let parameterCurve: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/parametercurve)
- [`static let parameterCurveControlPoints: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/parametercurvecontrolpoints)
- [`static let parameterID: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/parameterid)
- [`static let parameterValue: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/parametervalue)
- [`static let pattern: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/pattern)
- [`static let time: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/time)
- [`static let version: CHHapticPattern.Key`](https://developer.apple.com/documentation/corehaptics/chhapticpattern/key/version)
- [`let CoreHapticsErrorDomain: String`](https://developer.apple.com/documentation/corehaptics/corehapticserrordomain)

</details>
<!-- /generated:missing -->
