# CoreImage

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 97.7% of Apple's iOS API (2918 of 2986, exact) · **Rows:** 17: 11 ✅ 5 🟡 1 🧩 · **iOS:** 5.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [CoreImage](https://developer.apple.com/documentation/coreimage) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted:** a CPU renderer (`isim/frameworks/CoreImage`).
- The kernel language is interpreted by `CIKernelLang.c`.
- Detectors use OpenCV Haar cascades, zbar / zxing-cpp and tesseract; RAW files use LibRaw; HEIF uses ffmpeg.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Core Image `CIImage` (bitmaps, CGImage, files, colors, transforms, crops, clamping, compositing, color matching, sampling modes, intermediates, orientation, auxiliary images, gain maps, auto adjustment) | ✅ | ≤17 | CPU renderer (adapted): parallel bands of premultiplied float pixels in the context's working space (linear sRGB, or none with `NSNull`), as on iOS; 30 `CIFormat`s; auto adjustment returns isim's choice of tone filters (adapted). Tested (HelloCoreImage: `test_coreimage.py`, HelloImaging) |
| Core Image `CIContext` (options, `createCGImage`, `render(_:toBitmap:)`, `draw`, PNG / JPEG / TIFF / HEIF / OpenEXR representations and writers, `CIRenderDestination` and tasks, `init(mtlDevice:)`, `init(mtlCommandQueue:)`) | ✅ | ≤17 | every context renders on the CPU, a Metal device's too (isim's Metal is on the CPU, #328; no Metal textures as sources or destinations, no OpenGL contexts); HEIF through isim's writer (the host's ffmpeg libx265); TIFF and OpenEXR written by Core Image itself. Tested (`test_coreimage.py`) |
| Core Image filters: the 243 built-in filters (`CIFilter(name:)`, `CIFilterBuiltins`, categories, attributes) | ✅ | ≤17 | all implemented by isim (adapted: CPU versions that follow Apple's documented behaviour, not Apple's code); every filter is rendered by a test, gallery pages are checked in screenshots. CIPDF417BarcodeGenerator reads the PDF417 codeword table from the host's zxing-cpp library. Tested (`test_coreimage.py`, `test_coreimage_pages.py`) |
| Core Image ML filters: `CISaliencyMapFilter` | 🟡 | ≤17 | adapted: spectral residual saliency (Hou & Zhang) instead of Apple's model; tested (rendered) |
| Core Image ML filters: `CIPersonSegmentation`, `CICoreMLModelFilter` | 🧩 | ≤17 | stub: they need Apple's models / Core ML runtime; the output is nil and the reason is logged |
| `CIFilter` subclasses, `registerName(_:constructor:classAttributes:)`, XMP serialization, `NSSecureCoding` | ✅ | ≤17 | XMP uses isim's own namespace (not readable by Apple's Photos); tested (`test_coreimage.py`) |
| Core Image kernels: `CIColorKernel`, `CIWarpKernel`, `CIBlendKernel`, `CIKernel` (Core Image Kernel Language, Metal source / `default.metallib`) | 🟡 | ≤17 | adapted: isim interprets the kernel source on the CPU (a subset of each language: scalar / vector math, swizzles, control flow, the Core Image and common math functions); `isim build` stores `.metal` sources in `default.metallib`; Xcode-compiled metallibs (GPU code) are refused with an error. Tested (`test_coreimage.py`) |
| `CIImageProcessorKernel` (single and multiple outputs), `CIImageAccumulator`, `CISampler`, `CIFilterShape` | ✅ | ≤17 | processor inputs and outputs are main-memory bitmaps (`baseAddress`); `pixelBuffer` and Metal textures are nil. Tested (`test_coreimage.py`) |
| `CIDetector` faces (`CIFaceFeature`) | 🟡 | ≤17 | adapted: OpenCV's Haar cascades (the host's opencv-data) evaluated by isim: bounds, eyes, mouth, smile and blink estimates, face angle; tracking IDs are per detector. Needs opencv-data. Tested (`test_coreimage.py`) |
| `CIDetector` rectangles, QR codes, text (`CIRectangleFeature`, `CIQRCodeFeature`, `CITextFeature`) | 🟡 | ≤17 | rectangles: isim's own quadrilateral finder; QR codes through the host's zbar / zxing-cpp (the `symbolDescriptor` is the message encoded again at level M: isim does not read the symbol's own codewords); text through tesseract. Tested (`test_coreimage.py`) |
| `CIBarcodeDescriptor` (QR, Aztec, PDF417, Data Matrix) and `CIBarcodeGenerator`, QR / Aztec / Code 128 / PDF417 generators | ✅ | ≤17 | isim's encoders; the generated symbols decode with zxing-cpp (tested: `test_coreimage_pages.py`) |
| `CIRAWFilter` (and the iOS 10 `CIFilter(imageURL:options:)` RAW API) | 🟡 | ≤17 | adapted: decoded by the host's LibRaw tools (libraw-bin), then isim's processing (white balance, exposure, boost, noise, sharpness, contrast, detail, moire, local tone map, EDR headroom, orientation, scale); lens correction unsupported, semantic mattes nil (stub), preview is a draft rendering. Tested on a generated DNG (`test_coreimage.py`) |
| Core Image CVPixelBuffer APIs (`CIImage(cvPixelBuffer:)`, `CIContext.render(_:to:)`, `CIRenderDestination(pixelBuffer:)`, `CIImage.pixelBuffer`) | ✅ | ≤17 | Swift overlay (isim's CoreVideo is Swift-only); pixels are copied (no IOSurface sharing); BGRA / ARGB / RGBA, one-component, depth and 4:2:0 formats. Tested (`test_coreimage.py`) |
| `UIImage(ciImage:)`, `CIImage(image:)`, `CIColor(color:)` | ✅ | ≤17 | adapted: `UIImage(ciImage:)` renders at once, so its `cgImage` is non-nil (iOS leaves it nil). Tested (`test_coreimage.py`, HelloImaging) |
| Core Image iOS 18/26 filters: `CIAreaBoundsRed`, `CIAreaAverageMaximumRed`, `CIAreaAlphaWeightedHistogram`, `CIMaximumScaleTransform`, `CIBlurredRoundedRectangleGenerator`, `CIRoundedQRCodeGenerator`, `CISystemToneMap`; `smoothness` of the rounded rectangle generators; the `CIMedian` / `CIConvertLab` protocols, `CIKMeans.inputMeans` | ✅ | 18.0 | adapted (isim's CPU versions): bounds red gives (x, y, width, height) of the pixels whose red is above zero; average-maximum red (average, maximum, 0, 1); the alpha-weighted histogram counts each pixel by its alpha; the maximum scale transform keeps the maximum of the source pixels each output pixel covers; the blurred rounded rectangle is the shape blurred by `sigma`; the rounded QR code draws dots, rounded finder patterns (`roundedMarkers` 0-3) and an optional clear center, `color0` on `color1`, one module of margin (decodes with zbar); the system tone map rolls highlights off to 1 (standard), up to 2 (constrainedHigh) or the display's headroom (high) from the image's content headroom; smoothness widens the corners into a superellipse (continuous corners). Tested (CoreImageHDRTest: test_coreimage_hdr, iOS 26) |
| Core Image HDR metadata (iOS 26): `CIDynamicRangeOption`, `settingContentHeadroom(_:)`, `contentAverageLightLevel` / `settingContentAverageLightLevel(_:)`, `CIContext.calculateHDRStats(for:)` (CIImage), `CIImageOption.contentAverageLightLevel`; `convertingWorkingSpaceToLab()` / `convertingLabToWorkingSpace()`, `insertingTiledIntermediate()`; `CIFormat.RGBX8`; the iOS 26 `kCIInput…Key` constants; `CIQRCodeDescriptor.ErrorCorrectionLevel`, `CIDataMatrixCodeDescriptor.ECCVersion` | ✅ | 26.0 | the stats are measured by rendering in extended linear sRGB: headroom = the brightest value (at least 1), average light level = the mean luminance over SDR white; a tiled intermediate is an intermediate (isim renders in bands); `CIContextOption.memoryTarget` is accepted and ignored. Not done: the CGImage, CVPixelBuffer and IOSurface `calculateHDRStats` variants, Metal textures and IOSurfaces, `CIFormat.RGB10`. Tested (CoreImageHDRTest) |
| `CIImage(depthData:)`, `CIImage(depthData:options:)`, `CIImage.depthData` | ✅ | ≤17 | the depth / disparity map as a one-channel float image; the image keeps its `AVDepthData` (declared in isim's AVFoundation overlay, where `AVDepthData` is; Swift only). Tested (CoreImageHDRTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
68 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func createCGImage(CIImage, from: CGRect, format: CIFormat, colorSpace: CGColorSpace?, deferred: Bool, calculateHDRStats: Bool) -> CGImage?`](https://developer.apple.com/documentation/coreimage/cicontext/createcgimage(_:from:format:colorspace:deferred:calculatehdrstats:))
- [`func estimateRender(CIImage, from: CGRect, to: CIRenderDestination, at: CGPoint) throws -> CIRenderTask`](https://developer.apple.com/documentation/coreimage/cicontext/estimaterender(_:from:to:at:))
- [`func render(CIImage, to: any MTLTexture, commandBuffer: (any MTLCommandBuffer)?, bounds: CGRect, colorSpace: CGColorSpace)`](https://developer.apple.com/documentation/coreimage/cicontext/render(_:to:commandbuffer:bounds:colorspace:))
- [`static let cvMetalTextureCache: CIContextOption`](https://developer.apple.com/documentation/coreimage/cicontextoption/cvmetaltexturecache)
- [`init!(cvPixelBuffer: CVPixelBuffer!, properties: [AnyHashable : Any]!, options: [CIRAWFilterOption : Any]!)`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/init(cvpixelbuffer:properties:options:)-69695)
- [`init!(CVPixelBuffer: CVPixelBuffer!, properties: [AnyHashable : Any]!, options: [CIRAWFilterOption : Any]!)`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/init(cvpixelbuffer:properties:options:)-7qpsv)
- [`init!(CVPixelBuffer: CVPixelBuffer!, properties: [AnyHashable : Any]!, options: [CIRAWFilterOption : Any]!)`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/init(cvpixelbuffer:properties:options:)-7qpsv)
- [`init?(name: String, withInputParameters: [String : Any]?)`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/init(name:withinputparameters:))
- [`init?(name: String, withInputParameters: [String : Any]?)`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/init(name:withinputparameters:))
- [`static let RGB10: CIFormat`](https://developer.apple.com/documentation/coreimage/ciformat/rgb10)
- [`init(ioSurface: IOSurfaceRef)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:)-5e9yc)
- [`init(IOSurface: IOSurfaceRef)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:)-72me3)
- [`init(IOSurface: IOSurfaceRef)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:)-7dwj8)
- [`init(ioSurface: IOSurfaceRef, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:options:)-48cta)
- [`init(IOSurface: IOSurfaceRef, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:options:)-4dwl5)
- [`init(IOSurface: IOSurfaceRef, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(iosurface:options:)-7qdsg)
- [`init?(MTLTexture: any MTLTexture, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(mtltexture:options:)-510vm)
- [`init?(MTLTexture: any MTLTexture, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(mtltexture:options:)-5ou1j)
- [`init?(mtlTexture: any MTLTexture, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(mtltexture:options:)-67uvj)
- [`init?(portaitEffectsMatte: AVPortraitEffectsMatte)`](https://developer.apple.com/documentation/coreimage/ciimage/init(portaiteffectsmatte:))
- [`init?(portaitEffectsMatte: AVPortraitEffectsMatte, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(portaiteffectsmatte:options:))
- [`init?(semanticSegmentationMatte: AVSemanticSegmentationMatte)`](https://developer.apple.com/documentation/coreimage/ciimage/init(semanticsegmentationmatte:))
- [`init?(semanticSegmentationMatte: AVSemanticSegmentationMatte, options: [CIImageOption : Any]?)`](https://developer.apple.com/documentation/coreimage/ciimage/init(semanticsegmentationmatte:options:))
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimage/metaltexture)
- [`var portraitEffectsMatte: AVPortraitEffectsMatte?`](https://developer.apple.com/documentation/coreimage/ciimage/portraiteffectsmatte)
- [`var semanticSegmentationMatte: AVSemanticSegmentationMatte?`](https://developer.apple.com/documentation/coreimage/ciimage/semanticsegmentationmatte)
- [`static let subsampleFactor: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/subsamplefactor)
- [`static let typeIdentifierHint: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/typeidentifierhint)
- [`static let useHardwareAcceleration: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/usehardwareacceleration)
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessorinput/metaltexture)
- [`var surface: IOSurfaceRef`](https://developer.apple.com/documentation/coreimage/ciimageprocessorinput/surface)
- [`class func apply(tiledExtent: [CIVector], inputs: [CIImage]?, arguments: [String : Any]?) throws -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimageprocessorkernel/apply(tiledextent:inputs:arguments:))
- [`var metalCommandBuffer: (any MTLCommandBuffer)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/metalcommandbuffer)
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/metaltexture)
- [`var surface: IOSurfaceRef`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/surface)
- [`func temporaryPixelBuffer(identifier: String, format: OSType, width: Int, height: Int, attributes: [AnyHashable : Any]?) -> CVPixelBuffer?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/temporarypixelbuffer(identifier:format:width:height:attributes:))
- [`func temporarySurface(identifier: String, format: OSType, width: Int, height: Int) -> IOSurface?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/temporarysurface(identifier:format:width:height:))
- [`static let hdrGainMapAsRGB: CIImageRepresentationOption`](https://developer.apple.com/documentation/coreimage/ciimagerepresentationoption/hdrgainmapasrgb)
- [`static let version9: CIRAWDecoderVersion`](https://developer.apple.com/documentation/coreimage/cirawdecoderversion/version9)
- [`static let version9DNG: CIRAWDecoderVersion`](https://developer.apple.com/documentation/coreimage/cirawdecoderversion/version9dng)
- [`var despeckleAmount: Float`](https://developer.apple.com/documentation/coreimage/cirawfilter/despeckleamount)
- [`class func downloadAllResources(timeout: TimeInterval, completionHandler: ((any Error)?) -> Void) -> Progress`](https://developer.apple.com/documentation/coreimage/cirawfilter/downloadallresources(timeout:completionhandler:))
- [`func downloadResources(timeout: TimeInterval, completionHandler: ((any Error)?) -> Void) -> Progress`](https://developer.apple.com/documentation/coreimage/cirawfilter/downloadresources(timeout:completionhandler:))
- [`convenience init?(cvPixelBuffer: CVPixelBuffer, properties: [AnyHashable : Any])`](https://developer.apple.com/documentation/coreimage/cirawfilter/init(cvpixelbuffer:properties:)-6209q)
- [`convenience init?(CVPixelBuffer: CVPixelBuffer, properties: [AnyHashable : Any])`](https://developer.apple.com/documentation/coreimage/cirawfilter/init(cvpixelbuffer:properties:)-6321o)
- [`var isDespeckleSupported: Bool`](https://developer.apple.com/documentation/coreimage/cirawfilter/isdespecklesupported)
- [`class func supportedCameraModels(with: CIRAWDecoderVersion) -> [String]`](https://developer.apple.com/documentation/coreimage/cirawfilter/supportedcameramodels(with:))
- [`static let boostAmount: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/boostamount)
- [`static let boostAmount: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/boostamount)
- [`static let ciInputEnableEDRModeKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/ciinputenableedrmodekey)
- [`static let ciInputLocalToneMapAmountKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/ciinputlocaltonemapamountkey)
- [`static let disableGamutMap: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/disablegamutmap)
- [`static let disableGamutMap: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/disablegamutmap)
- [`static let propertiesKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/propertieskey)
- [`init(GLTexture: UInt32, target: UInt32, width: Int, height: Int)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(gltexture:target:width:height:)-6dbtl)
- [`init(glTexture: UInt32, target: UInt32, width: Int, height: Int)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(gltexture:target:width:height:)-9ci8e)
- [`init(ioSurface: IOSurface)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(iosurface:)-1hfcq)
- [`init(IOSurface: IOSurface)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(iosurface:)-5t5jd)
- [`init(mtlTexture: any MTLTexture, commandBuffer: (any MTLCommandBuffer)?)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(mtltexture:commandbuffer:)-2iu5i)
- [`init(MTLTexture: any MTLTexture, commandBuffer: (any MTLCommandBuffer)?)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(mtltexture:commandbuffer:)-5iasd)
- [`init(width: Int, height: Int, pixelFormat: MTLPixelFormat, commandBuffer: (any MTLCommandBuffer)?, mtlTextureProvider: (() -> any MTLTexture)?)`](https://developer.apple.com/documentation/coreimage/cirenderdestination/init(width:height:pixelformat:commandbuffer:mtltextureprovider:))
- [`var plannedPassCount: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpasscount)
- [`var plannedPeakMemory: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpeakmemory)
- [`var plannedPixelsOverdrawn: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpixelsoverdrawn)
- [`var plannedPixelsProcessed: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpixelsprocessed)
- [`var COREIMAGE_SUPPORTS_IOSURFACE: Int32`](https://developer.apple.com/documentation/coreimage/coreimage_supports_iosurface)
- [`var COREIMAGE_SUPPORTS_OPENGLES: Int32`](https://developer.apple.com/documentation/coreimage/coreimage_supports_opengles)
- [`var UNIFIED_CORE_IMAGE: Int32`](https://developer.apple.com/documentation/coreimage/unified_core_image)

</details>
<!-- /generated:missing -->
