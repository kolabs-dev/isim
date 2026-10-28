# ReplayKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [ReplayKit](https://developer.apple.com/documentation/replaykit) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Approach:** adapted, a Swift overlay (`isim/swift/overlays/ReplayKit`):
  - **Frames:** the app's windows are drawn 15 times a second at one pixel per point. Like iOS, system UI is not included.
  - **Recordings:** the frames are encoded to an H.264 `.mp4` with isim's AVAssetWriter.
  - **Capture:** the frames are handed to the capture handler as sample buffers. The microphone is isim's simulated microphone.
  - **Clip buffering:** the last 15 seconds are kept as 5-second movie segments, and a clip is exported by composing them.
  - **Consent:** the first recording or capture shows iOS's alert ("Allow screen recording in “App”?"). The answer is remembered for 8 minutes. `ISIM_REPLAYKIT_PERMISSION=allow|deny` answers it without the alert, and scripts can tap its buttons. `ISIM_REPLAYKIT_AVAILABLE=0` makes recording unavailable.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/ReplayKit` over the Swift classes. `CMSampleBufferRef` (`CoreMedia/CMSampleBuffer.h`) is Swift's sample buffer.
- **Versus Apple's Simulator:**
  - Recordings work, at points rather than pixels.
  - The app's own audio is not captured, and recordings have no sound track.
  - Broadcasting needs another app's broadcast upload extension, which isim cannot install. The broadcast sheet and the system picker say that no service is available, and `RPBroadcastController` cannot start.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `RPScreenRecorder`: `startRecording`, `stopRecording(handler:)`, `stopRecording(withOutput:)`, `discardRecording`, `isAvailable`, `isRecording`, `isMicrophoneEnabled`, `delegate` | ✅ | ≤17 | adapted: the app's windows, H.264 at the screen's size in points, 15 frames a second; video only; the consent alert; errors in `RPRecordingErrorDomain` with Apple's codes (`userDeclined`, `attemptToStopNonRecording`, …); tested (HelloReplayKit: `test_replaykit.py`; ReplayKitTest: `test_replaykit_objc.py`) |
| `RPScreenRecorder.isCameraEnabled`, `cameraPosition`, `cameraPreviewView` | ✅ | ≤17 | adapted: a preview view over isim's simulated camera (`ISIM_CAMERA_FRONT` / `ISIM_CAMERA`) that the app adds to its views; tested (HelloReplayKit) |
| `RPScreenRecorder.startCapture`, `stopCapture`, `RPSampleBufferType` | ✅ | ≤17 | adapted: `.video` buffers (BGRA pixel buffers) and, with the microphone enabled, `.audioMic` (48 kHz stereo float); no `.audioApp`; tested (HelloReplayKit) |
| `RPScreenRecorder.startClipBuffering`, `stopClipBuffering`, `exportClip(to:duration:)` | ✅ | ≤17 | adapted: the last 15 seconds in movie segments, a clip composed with AVFoundation; tested (HelloReplayKit: a 1-second clip) |
| `RPPreviewViewController`, `RPPreviewViewControllerDelegate`, `mode` | ✅ | ≤17 | adapted: isim's sheet plays the recording; Save writes it to Photos (`com.apple.UIKit.activity.SaveToCameraRoll`), Cancel finishes; buttons with accessibility identifiers `RPPreview.save` / `RPPreview.cancel`; tested (HelloReplayKit) |
| `RPBroadcastActivityViewController`, `RPSystemBroadcastPickerView`, `RPBroadcastController` and their delegates | 🟡 | ≤17 | adapted: no broadcast services on isim; the sheet and the picker say so, `startBroadcast` fails with `broadcastInvalidSession`; tested (HelloReplayKit, ReplayKitTest) |
| `RPBroadcastHandler`, `RPBroadcastSampleHandler`, `RPBroadcastMP4ClipHandler`, `RPBroadcastConfiguration` | 🟡 | ≤17 | stub: an extension's classes exist so it compiles; isim never runs broadcast upload extensions; `RPBroadcastConfiguration` supports secure coding (tested: ReplayKitTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
