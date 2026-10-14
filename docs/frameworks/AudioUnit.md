# AudioUnit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [Audio Unit](https://developer.apple.com/documentation/audiounit) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** the Audio Unit API (AudioComponent, AudioUnit, AUGraph, isim's units on its mixer) is implemented in isim's AudioToolbox overlay; `import AudioUnit` is a module that re-exports it (`isim/swift/overlays/AudioUnit.swift`). Rows: [AudioToolbox](AudioToolbox.md).
- **Objective-C / C interface:** `<AudioUnit/AudioUnit.h>` (`isim/sdk-src/Frameworks/AudioUnit`) has the types and constants (component descriptions, unit types and subtypes, scopes, property IDs, errors). The C functions (`AudioComponentFindNext`, `AudioUnitSetProperty`, `AudioUnitRender`, …) are not in C yet: [#286](https://github.com/kolabs-dev/isim/issues/286).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `import AudioUnit` | ✅ | 2.0 | adapted: re-exports AudioToolbox. Tested (HelloAudioModules: a RemoteIO unit's stream format) |
| `#import <AudioUnit/AudioUnit.h>`, `-framework AudioUnit`: `AudioComponentDescription`, `AudioUnit`, `AURenderCallbackStruct`, `kAudioUnitType_…`, `kAudioUnitSubType_…`, `kAudioUnitScope_…`, `kAudioUnitProperty_…`, `kAudioUnitErr_…` | 🟡 | 2.0 | types and constants with Apple's values and layouts; no C functions yet (#286). Tested (AudioHeadersTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
