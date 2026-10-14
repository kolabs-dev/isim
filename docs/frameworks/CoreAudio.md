# CoreAudio

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
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
<!-- /generated:missing -->
