# VideoToolbox

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [VideoToolbox](https://developer.apple.com/documentation/videotoolbox) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Approach:** *passthrough* to the host's libavcodec, loaded on demand (`isim/runtime/host_codec.c`): `isim_vcodec_*`
  decodes H.264 and HEVC, `isim_venc_*` encodes them with libx264 / libx265. The sessions themselves are *adapted*
  (`isim/swift/overlays/VideoToolbox`): frames are decoded and encoded synchronously in the calling thread and come
  out in presentation order; the encoder makes no B-frames.
- **Objective-C / C interface:** none yet (Swift only): VideoToolbox's C headers need CoreMedia's C interface first (#383).
- **Versus Apple's Simulator:** software codecs, like the Simulator's; output callbacks are Swift closures (Apple's are
  C function pointers, so closures that capture nothing work the same way).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `VTDecompressionSession`: `VTDecompressionSessionCreate`, `DecodeFrame` (callback record and output handler), `FinishDelayedFrames`, `WaitForAsynchronousFrames`, `CanAcceptFormatDescription`, `CopyBlackPixelBuffer`, `Invalidate` | ✅ | ≤17 | passthrough: H.264 and HEVC decoded by the host's libavcodec (8-bit, BT.601); output in the pixel format the image buffer attributes ask for (32BGRA, 32ARGB, 32RGBA, 420v, 420f; 420v by default) at the stream's size; refcons and timestamps kept; without libavcodec the session cannot be created (`kVTCouldNotFindVideoDecoderErr`); tested (VideoToolboxTest, HelloSampleBuffers) |
| `VTCompressionSession`: `VTCompressionSessionCreate`, `EncodeFrame` (callback and output handler), `CompleteFrames`, `PrepareToEncodeFrames`, `GetPixelBufferPool`, `Invalidate`; `kVTCompressionPropertyKey_RealTime`, `AverageBitRate`, `MaxKeyFrameInterval` (`Duration`), `ExpectedFrameRate`, `ProfileLevel`; `kVTEncodeFrameOptionKey_ForceKeyFrame` | ✅ | ≤17 | passthrough: libx264 (H.264) or libx265 (HEVC) through libavcodec; sample buffers in AVCC with the parameter sets in the format description and `NotSync` on non-key frames; frames are scaled to the session's size; no frame reordering (`AllowFrameReordering` is not applied), `DataRateLimits`, `Quality` and the entropy mode are stored but not applied; tested (VideoToolboxTest: key frames every 10 and forced, timestamps, refcons, round trip) |
| `VTPixelTransferSession` (`Create`, `TransferImage`, `Invalidate`), `kVTPixelTransferPropertyKey_ScalingMode` (`Normal`, `CropSourceToCleanAperture`, `Letterbox`, `Trim`) | ✅ | ≤17 | adapted: any of isim's pixel formats in, BGRA / ARGB / RGBA / 420v / 420f out, scaled bilinearly; letterbox fills with black; tested (VideoToolboxTest) |
| `VTCreateCGImageFromCVPixelBuffer` | ✅ | ≤17 | adapted: a CGImage of the buffer's pixels (premultiplied BGRA); tested (VideoToolboxTest) |
| `VTSessionSetProperty`, `VTSessionSetProperties`, `VTSessionCopyProperty`, `VTIsHardwareDecodeSupported`, the `kVT…Err` codes and flags | ✅ | ≤17 | properties are kept per session; `UsingHardwareAccelerated…` reads false; `VTIsHardwareDecodeSupported` is true for H.264 and HEVC; tested (VideoToolboxTest) |
| Multi-pass encoding, frame silos, `VTFrameProcessor` (iOS 26), motion estimation, HDR and ProRes, RAW processing | ❌ | ≤17 | not there yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
