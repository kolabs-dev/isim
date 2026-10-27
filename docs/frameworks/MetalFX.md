# MetalFX

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [GPU](../COVERAGE.md#gpu) · **Apple:** [MetalFX](https://developer.apple.com/documentation/metalfx) · **Issues:** [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

## How isim implements it

- **Approach:** isim's own upscalers, on the CPU (`isim/frameworks/MetalFX/MetalFX.m`). Encoding adds the work to
  isim's Metal command buffer.
  - **Spatial scaler:** after AMD FSR 1.
    - An edge-adaptive Lanczos-2 upscale over a 4x4 neighborhood (EASU). The kernel narrows across the luminance
      gradient and widens along it, and the result is clamped to the four nearest pixels.
    - Then contrast-adaptive sharpening (RCAS, sharpness 0.8).
    - HDR colors go through a reversible tonemap.
  - **Temporal scaler:** each frame is upscaled at its jitter offset. It is blended (10%) into the previous output,
    reprojected through the motion vectors (scaled by `motionVectorScaleX/Y` to input pixels; a vector points from the
    pixel to where it was in the previous frame) and clamped to the frame's 3x3 neighborhood. `reset` starts over.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/MetalFX`, with Apple's Swift names.
- **Versus Apple's Simulator:**
  - The images are isim's upscales, not Apple's.
  - The temporal scaler does not use depth, exposure or the reactive mask.
  - The iOS 26 frame interpolator, the temporal denoised scaler and the Metal 4 forms are not implemented yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MTLFXSpatialScalerDescriptor` (formats, sizes, `colorProcessingMode`, `makeSpatialScaler(device:)`, `supportsDevice`), `MTLFXSpatialScaler` / `MTLFXSpatialScalerBase` (textures, content size, usages, fence, `encode(commandBuffer:)`) | ✅ | ≤17 | adapted: after FSR 1 (EASU + RCAS); tested (MPSTest, test_mps; HelloMetal, test_metal) |
| `MTLFXTemporalScalerDescriptor` (formats, sizes, content scales, auto exposure, reactive mask and motion vector options, `makeTemporalScaler(device:)`, `supportsDevice`, supported scales), `MTLFXTemporalScaler` / `MTLFXTemporalScalerBase` (color, depth, motion, exposure and reactive textures, content offsets, jitter, motion vector scale, `reset`, `isDepthReversed`, `preExposure`, `encode(commandBuffer:)`) | 🟡 | ≤17 | adapted: depth, exposure and the reactive mask are accepted but not used; tested (MPSTest) |
| `MTLFXFrameInterpolator`, `MTLFXTemporalDenoisedScaler`, `MTL4FX*` | ❌ | 26.0 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
