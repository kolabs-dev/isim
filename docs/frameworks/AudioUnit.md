# AudioUnit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 1, exact) · **Rows:** 2: 2 ✅ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [Audio Unit](https://developer.apple.com/documentation/audiounit) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** the Audio Unit API (AudioComponent, AudioUnit, AUGraph, isim's units on its mixer) is implemented in isim's AudioToolbox overlay; `import AudioUnit` is a module that re-exports it (`isim/swift/overlays/AudioUnit.swift`). Rows: [AudioToolbox](AudioToolbox.md).
- **Objective-C / C interface:** `<AudioUnit/AudioUnit.h>` (`isim/sdk-src/Frameworks/AudioUnit`) includes AudioToolbox's Audio Unit headers (`<AudioToolbox/AudioUnit.h>`: types, constants and the functions `AudioComponentFindNext`, `AudioUnitSetProperty`, `AudioUnitRender`, …), and `AudioUnit.framework` re-exports `AudioToolbox.framework`, as on iOS.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `import AudioUnit` | ✅ | 2.0 | adapted: re-exports AudioToolbox. Tested (HelloAudioModules: a RemoteIO unit's stream format) |
| `#import <AudioUnit/AudioUnit.h>`, `-framework AudioUnit`: `AudioComponentDescription`, `AudioUnit`, `AURenderCallbackStruct`, `kAudioUnitType_…`, `kAudioUnitSubType_…`, `kAudioUnitScope_…`, `kAudioUnitProperty_…`, `kAudioUnitErr_…` | ✅ | 2.0 | types and constants with Apple's values and layouts; the functions are AudioToolbox's C interface (re-exported). Tested (AudioHeadersTest, AudioToolboxCTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
1 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var AUDIO_UNIT_VERSION: Int32`](https://developer.apple.com/documentation/audiounit/audio_unit_version)

</details>
<!-- /generated:missing -->
