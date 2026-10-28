# MetalFX

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 37.5% of Apple's iOS API (100 of 267, exact) · **Rows:** 3: 1 ✅ 1 🟡 1 ❌ · **iOS:** 16.0+
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
167 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`MTL4FXFrameInterpolator`](https://developer.apple.com/documentation/metalfx/mtl4fxframeinterpolator)
- [`func encode(commandBuffer: any MTL4CommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtl4fxframeinterpolator/encode(commandbuffer:))
- [`MTL4FXSpatialScaler`](https://developer.apple.com/documentation/metalfx/mtl4fxspatialscaler)
- [`func encode(commandBuffer: any MTL4CommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtl4fxspatialscaler/encode(commandbuffer:))
- [`MTL4FXTemporalDenoisedScaler`](https://developer.apple.com/documentation/metalfx/mtl4fxtemporaldenoisedscaler)
- [`func encode(commandBuffer: any MTL4CommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtl4fxtemporaldenoisedscaler/encode(commandbuffer:))
- [`MTL4FXTemporalScaler`](https://developer.apple.com/documentation/metalfx/mtl4fxtemporalscaler)
- [`func encode(commandBuffer: any MTL4CommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtl4fxtemporalscaler/encode(commandbuffer:))
- [`MTLFXFrameInterpolatableScaler`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatablescaler)
- [`MTLFXFrameInterpolator`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolator)
- [`func encode(commandBuffer: any MTLCommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolator/encode(commandbuffer:))
- [`MTLFXFrameInterpolatorBase`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase)
- [`var aspectRatio: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/aspectratio)
- [`var colorTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/colortexture)
- [`var colorTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/colortextureformat)
- [`var colorTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/colortextureusage)
- [`var contentHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/contentheight)
- [`var contentWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/contentwidth)
- [`var deltaTime: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/deltatime)
- [`var depthContentOffsetX: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/depthcontentoffsetx)
- [`var depthContentOffsetY: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/depthcontentoffsety)
- [`var depthTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/depthtexture)
- [`var depthTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/depthtextureformat)
- [`var depthTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/depthtextureusage)
- [`var distortionHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/distortionheight)
- [`var distortionOffsetX: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/distortionoffsetx)
- [`var distortionOffsetY: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/distortionoffsety)
- [`var distortionTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/distortiontexture)
- [`var distortionWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/distortionwidth)
- [`var farPlane: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/farplane)
- [`var fence: (any MTLFence)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/fence)
- [`var fieldOfView: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/fieldofview)
- [`var inputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/inputheight)
- [`var inputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/inputwidth)
- [`var isDepthReversed: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/isdepthreversed)
- [`var isUITextureComposited: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/isuitexturecomposited)
- [`var jitterOffsetX: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/jitteroffsetx)
- [`var jitterOffsetY: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/jitteroffsety)
- [`var motionContentOffsetX: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motioncontentoffsetx)
- [`var motionContentOffsetY: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motioncontentoffsety)
- [`var motionTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motiontexture)
- [`var motionTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motiontextureformat)
- [`var motionTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motiontextureusage)
- [`var motionVectorScaleX: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motionvectorscalex)
- [`var motionVectorScaleY: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/motionvectorscaley)
- [`var nearPlane: Float`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/nearplane)
- [`var outputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputheight)
- [`var outputOffsetX: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputoffsetx)
- [`var outputOffsetY: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputoffsety)
- [`var outputTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputtexture)
- [`var outputTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputtextureformat)
- [`var outputTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputtextureusage)
- [`var outputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/outputwidth)
- [`var prevColorTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/prevcolortexture)
- [`var shouldResetHistory: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/shouldresethistory)
- [`var uiTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/uitexture)
- [`var uiTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/uitextureformat)
- [`var uiTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/uitextureusage)
- [`var viewToClipMatrix: simd_float4x4`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/viewtoclipmatrix)
- [`var worldToViewMatrix: simd_float4x4`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatorbase/worldtoviewmatrix)
- [`MTLFXFrameInterpolatorDescriptor`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor)
- [`var colorTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/colortextureformat)
- [`var depthTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/depthtextureformat)
- [`var inputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/inputheight)
- [`var inputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/inputwidth)
- [`var isDistortionTextureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/isdistortiontextureenabled)
- [`func makeFrameInterpolator(device: any MTLDevice) -> (any MTLFXFrameInterpolator)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/makeframeinterpolator(device:))
- [`func makeFrameInterpolator(device: any MTLDevice, compiler: any MTL4Compiler) -> (any MTL4FXFrameInterpolator)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/makeframeinterpolator(device:compiler:))
- [`var motionTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/motiontextureformat)
- [`var outputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/outputheight)
- [`var outputTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/outputtextureformat)
- [`var outputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/outputwidth)
- [`var requiresPrevColorTexture: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/requiresprevcolortexture)
- [`var scaler: (any MTLFXFrameInterpolatableScaler)?`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/scaler)
- [`class func supportsDevice(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/supportsdevice(_:))
- [`class func supportsMetal4FX(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/supportsmetal4fx(_:))
- [`var uiTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor/uitextureformat)
- [`func makeSpatialScaler(device: any MTLDevice, compiler: any MTL4Compiler) -> (any MTL4FXSpatialScaler)?`](https://developer.apple.com/documentation/metalfx/mtlfxspatialscalerdescriptor/makespatialscaler(device:compiler:))
- [`class func supportsMetal4FX(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxspatialscalerdescriptor/supportsmetal4fx(_:))
- [`MTLFXTemporalDenoisedScaler`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscaler)
- [`func encode(commandBuffer: any MTLCommandBuffer)`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscaler/encode(commandbuffer:))
- [`MTLFXTemporalDenoisedScalerBase`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase)
- [`var colorTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/colortexture)
- [`var colorTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/colortextureformat)
- [`var colorTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/colortextureusage)
- [`var denoiseStrengthMaskTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/denoisestrengthmasktexture)
- [`var denoiseStrengthMaskTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/denoisestrengthmasktextureformat)
- [`var denoiseStrengthMaskTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/denoisestrengthmasktextureusage)
- [`var depthTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/depthtexture)
- [`var depthTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/depthtextureformat)
- [`var depthTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/depthtextureusage)
- [`var diffuseAlbedoTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/diffusealbedotexture)
- [`var diffuseAlbedoTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/diffusealbedotextureformat)
- [`var diffuseAlbedoTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/diffusealbedotextureusage)
- [`var exposureTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/exposuretexture)
- [`var fence: (any MTLFence)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/fence)
- [`var inputContentMaxScale: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/inputcontentmaxscale)
- [`var inputContentMinScale: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/inputcontentminscale)
- [`var inputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/inputheight)
- [`var inputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/inputwidth)
- [`var isDepthReversed: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/isdepthreversed)
- [`var jitterOffsetX: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/jitteroffsetx)
- [`var jitterOffsetY: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/jitteroffsety)
- [`var motionTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/motiontexture)
- [`var motionTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/motiontextureformat)
- [`var motionTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/motiontextureusage)
- [`var motionVectorScaleX: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/motionvectorscalex)
- [`var motionVectorScaleY: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/motionvectorscaley)
- [`var normalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/normaltexture)
- [`var normalTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/normaltextureformat)
- [`var normalTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/normaltextureusage)
- [`var outputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/outputheight)
- [`var outputTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/outputtexture)
- [`var outputTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/outputtextureformat)
- [`var outputTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/outputtextureusage)
- [`var outputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/outputwidth)
- [`var preExposure: Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/preexposure)
- [`var reactiveMaskTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/reactivemasktexture)
- [`var reactiveMaskTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/reactivemasktextureformat)
- [`var reactiveMaskTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/reactivemasktextureusage)
- [`var reactiveTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/reactivetextureusage)
- [`var roughnessTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/roughnesstexture)
- [`var roughnessTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/roughnesstextureformat)
- [`var roughnessTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/roughnesstextureusage)
- [`var shouldResetHistory: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/shouldresethistory)
- [`var specularAlbedoTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularalbedotexture)
- [`var specularAlbedoTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularalbedotextureformat)
- [`var specularAlbedoTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularalbedotextureusage)
- [`var specularHitDistanceTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularhitdistancetexture)
- [`var specularHitDistanceTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularhitdistancetextureformat)
- [`var specularHitDistanceTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/specularhitdistancetextureusage)
- [`var transparencyOverlayTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/transparencyoverlaytexture)
- [`var transparencyOverlayTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/transparencyoverlaytextureformat)
- [`var transparencyOverlayTextureUsage: MTLTextureUsage`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/transparencyoverlaytextureusage)
- [`var viewToClipMatrix: simd_float4x4`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/viewtoclipmatrix)
- [`var worldToViewMatrix: simd_float4x4`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerbase/worldtoviewmatrix)
- [`MTLFXTemporalDenoisedScalerDescriptor`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor)
- [`var colorTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/colortextureformat)
- [`var denoiseStrengthMaskTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/denoisestrengthmasktextureformat)
- [`var depthTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/depthtextureformat)
- [`var diffuseAlbedoTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/diffusealbedotextureformat)
- [`var inputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/inputheight)
- [`var inputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/inputwidth)
- [`var isAutoExposureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/isautoexposureenabled)
- [`var isDenoiseStrengthMaskTextureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/isdenoisestrengthmasktextureenabled)
- [`var isReactiveMaskTextureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/isreactivemasktextureenabled)
- [`var isSpecularHitDistanceTextureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/isspecularhitdistancetextureenabled)
- [`var isTransparencyOverlayTextureEnabled: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/istransparencyoverlaytextureenabled)
- [`func makeTemporalDenoisedScaler(device: any MTLDevice) -> (any MTLFXTemporalDenoisedScaler)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/maketemporaldenoisedscaler(device:))
- [`func makeTemporalDenoisedScaler(device: any MTLDevice, compiler: any MTL4Compiler) -> (any MTL4FXTemporalDenoisedScaler)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/maketemporaldenoisedscaler(device:compiler:))
- [`var motionTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/motiontextureformat)
- [`var normalTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/normaltextureformat)
- [`var outputHeight: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/outputheight)
- [`var outputTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/outputtextureformat)
- [`var outputWidth: Int`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/outputwidth)
- [`var reactiveMaskTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/reactivemasktextureformat)
- [`var requiresSynchronousInitialization: Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/requiressynchronousinitialization)
- [`var roughnessTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/roughnesstextureformat)
- [`var specularAlbedoTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/specularalbedotextureformat)
- [`var specularHitDistanceTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/specularhitdistancetextureformat)
- [`class func supportedInputContentMaxScale(device: any MTLDevice) -> Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/supportedinputcontentmaxscale(device:))
- [`class func supportedInputContentMinScale(device: any MTLDevice) -> Float`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/supportedinputcontentminscale(device:))
- [`class func supportsDevice(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/supportsdevice(_:))
- [`class func supportsMetal4FX(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/supportsmetal4fx(_:))
- [`var transparencyOverlayTextureFormat: MTLPixelFormat`](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/transparencyoverlaytextureformat)
- [`func makeTemporalScaler(device: any MTLDevice, compiler: any MTL4Compiler) -> (any MTL4FXTemporalScaler)?`](https://developer.apple.com/documentation/metalfx/mtlfxtemporalscalerdescriptor/maketemporalscaler(device:compiler:))
- [`class func supportsMetal4FX(any MTLDevice) -> Bool`](https://developer.apple.com/documentation/metalfx/mtlfxtemporalscalerdescriptor/supportsmetal4fx(_:))

</details>
<!-- /generated:missing -->
