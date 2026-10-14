# CoreImage

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 95.3% of Apple's iOS API (2868 of 3010, exact) · **Rows:** 75% (14: 8 ✅ 5 🟡 1 🧩) · **iOS:** 5.0+
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
| Core Image `CIContext` (options, `createCGImage`, `render(_:toBitmap:)`, `draw`, PNG / JPEG / TIFF / HEIF / OpenEXR representations and writers, `CIRenderDestination` and tasks) | ✅ | ≤17 | every context renders on the CPU (no Metal / OpenGL contexts); HEIF through isim's writer (the host's ffmpeg libx265); TIFF and OpenEXR written by Core Image itself. Tested (`test_coreimage.py`) |
| Core Image filters: the 236 built-in filters (`CIFilter(name:)`, `CIFilterBuiltins`, categories, attributes) | ✅ | ≤17 | all implemented by isim (adapted: CPU versions that follow Apple's documented behaviour, not Apple's code); every filter is rendered by a test, gallery pages are checked in screenshots. CIPDF417BarcodeGenerator reads the PDF417 codeword table from the host's zxing-cpp library. Tested (`test_coreimage.py`, `test_coreimage_pages.py`) |
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
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CIAreaAverageMaximumRed`, `CIAreaBoundsRed`, `CIBlurredRoundedRectangleGenerator`, `CIConvertLab`, `CIMaximumScaleTransform`, `CIMedian`, `CIRoundedQRCodeGenerator`, `CISystemToneMap` (8 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
142 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`CIAreaAverageMaximumRed`](https://developer.apple.com/documentation/coreimage/ciareaaveragemaximumred)
- [`CIAreaBoundsRed`](https://developer.apple.com/documentation/coreimage/ciareaboundsred)
- [`CIBlurredRoundedRectangleGenerator`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator)
- [`var color: CIColor`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator/color)
- [`var extent: CGRect`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator/extent)
- [`var radius: Float`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator/radius)
- [`var sigma: Float`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator/sigma)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciblurredroundedrectanglegenerator/smoothness)
- [`func calculateHDRStats(for: CGImage) -> CGImage`](https://developer.apple.com/documentation/coreimage/cicontext/calculatehdrstats(for:)-3ia7r)
- [`func calculateHDRStats(for: IOSurfaceRef)`](https://developer.apple.com/documentation/coreimage/cicontext/calculatehdrstats(for:)-6lwmz)
- [`func calculateHDRStats(for: CVPixelBuffer)`](https://developer.apple.com/documentation/coreimage/cicontext/calculatehdrstats(for:)-7bcki)
- [`func calculateHDRStats(for: CIImage) -> CIImage?`](https://developer.apple.com/documentation/coreimage/cicontext/calculatehdrstats(for:)-l1rj)
- [`func estimateRender(CIImage, from: CGRect, to: CIRenderDestination, at: CGPoint) throws -> CIRenderTask`](https://developer.apple.com/documentation/coreimage/cicontext/estimaterender(_:from:to:at:))
- [`static let cvMetalTextureCache: CIContextOption`](https://developer.apple.com/documentation/coreimage/cicontextoption/cvmetaltexturecache)
- [`static let memoryTarget: CIContextOption`](https://developer.apple.com/documentation/coreimage/cicontextoption/memorytarget)
- [`CIConvertLab`](https://developer.apple.com/documentation/coreimage/ciconvertlab)
- [`CIConvertLab`](https://developer.apple.com/documentation/coreimage/ciconvertlab)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/ciconvertlab/inputimage)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/ciconvertlab/inputimage)
- [`var normalize: Bool`](https://developer.apple.com/documentation/coreimage/ciconvertlab/normalize)
- [`var normalize: Bool`](https://developer.apple.com/documentation/coreimage/ciconvertlab/normalize)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/init(rawvalue:))
- [`case v000`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v000)
- [`case v050`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v050)
- [`case v080`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v080)
- [`case v100`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v100)
- [`case v140`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v140)
- [`case v200`](https://developer.apple.com/documentation/coreimage/cidatamatrixcodedescriptor/eccversion-swift.enum/v200)
- [`CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption)
- [`static let constrainedHigh: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/constrainedhigh)
- [`static let constrainedHigh: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/constrainedhigh)
- [`static let high: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/high)
- [`static let high: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/high)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/init(rawvalue:))
- [`static let standard: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/standard)
- [`static let standard: CIDynamicRangeOption`](https://developer.apple.com/documentation/coreimage/cidynamicrangeoption/standard)
- [`class func areaAlphaWeightedHistogram() -> any CIFilter & CIAreaHistogram`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaalphaweightedhistogram())
- [`class func areaAverageMaximumRed() -> any CIFilter & CIAreaAverageMaximumRed`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaaveragemaximumred())
- [`class func areaBoundsRed() -> any CIFilter & CIAreaBoundsRed`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaboundsred())
- [`class func blurredRoundedRectangleGenerator() -> any CIFilter & CIBlurredRoundedRectangleGenerator`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/blurredroundedrectanglegenerator())
- [`class func maximumScaleTransform() -> any CIFilter & CIMaximumScaleTransform`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/maximumscaletransform())
- [`class func roundedQRCodeGenerator() -> any CIFilter & CIRoundedQRCodeGenerator`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/roundedqrcodegenerator())
- [`class func systemToneMap() -> any CIFilter & CISystemToneMap`](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/systemtonemap())
- [`static let RGB10: CIFormat`](https://developer.apple.com/documentation/coreimage/ciformat/rgb10)
- [`static let RGBX8: CIFormat`](https://developer.apple.com/documentation/coreimage/ciformat/rgbx8)
- [`var contentAverageLightLevel: Float`](https://developer.apple.com/documentation/coreimage/ciimage/contentaveragelightlevel)
- [`func convertingLabToWorkingSpace() -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimage/convertinglabtoworkingspace())
- [`func convertingWorkingSpaceToLab() -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimage/convertingworkingspacetolab())
- [`var depthData: AVDepthData?`](https://developer.apple.com/documentation/coreimage/ciimage/depthdata)
- [`func insertingTiledIntermediate() -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimage/insertingtiledintermediate())
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimage/metaltexture)
- [`var portraitEffectsMatte: AVPortraitEffectsMatte?`](https://developer.apple.com/documentation/coreimage/ciimage/portraiteffectsmatte)
- [`var semanticSegmentationMatte: AVSemanticSegmentationMatte?`](https://developer.apple.com/documentation/coreimage/ciimage/semanticsegmentationmatte)
- [`func settingContentAverageLightLevel(Float) -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimage/settingcontentaveragelightlevel(_:))
- [`func settingContentHeadroom(Float) -> CIImage`](https://developer.apple.com/documentation/coreimage/ciimage/settingcontentheadroom(_:))
- [`static let applyCleanAperture: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/applycleanaperture)
- [`static let contentAverageLightLevel: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/contentaveragelightlevel)
- [`static let providerTileSize: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/providertilesize)
- [`static let providerUserInfo: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/provideruserinfo)
- [`static let subsampleFactor: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/subsamplefactor)
- [`static let typeIdentifierHint: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/typeidentifierhint)
- [`static let useHardwareAcceleration: CIImageOption`](https://developer.apple.com/documentation/coreimage/ciimageoption/usehardwareacceleration)
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessorinput/metaltexture)
- [`var surface: IOSurfaceRef`](https://developer.apple.com/documentation/coreimage/ciimageprocessorinput/surface)
- [`var metalCommandBuffer: (any MTLCommandBuffer)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/metalcommandbuffer)
- [`var metalTexture: (any MTLTexture)?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/metaltexture)
- [`var surface: IOSurfaceRef`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/surface)
- [`func temporaryPixelBuffer(identifier: String, format: OSType, width: Int, height: Int, attributes: [AnyHashable : Any]?) -> CVPixelBuffer?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/temporarypixelbuffer(identifier:format:width:height:attributes:))
- [`func temporarySurface(identifier: String, format: OSType, width: Int, height: Int) -> IOSurface?`](https://developer.apple.com/documentation/coreimage/ciimageprocessoroutput/temporarysurface(identifier:format:width:height:))
- [`static let hdrGainMapAsRGB: CIImageRepresentationOption`](https://developer.apple.com/documentation/coreimage/ciimagerepresentationoption/hdrgainmapasrgb)
- [`var inputMeans: CIImage?`](https://developer.apple.com/documentation/coreimage/cikmeans/inputmeans)
- [`var inputMeans: CIImage?`](https://developer.apple.com/documentation/coreimage/cikmeans/inputmeans)
- [`CIMaximumScaleTransform`](https://developer.apple.com/documentation/coreimage/cimaximumscaletransform)
- [`var aspectRatio: Float`](https://developer.apple.com/documentation/coreimage/cimaximumscaletransform/aspectratio)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/cimaximumscaletransform/inputimage)
- [`var scale: Float`](https://developer.apple.com/documentation/coreimage/cimaximumscaletransform/scale)
- [`CIMedian`](https://developer.apple.com/documentation/coreimage/cimedian)
- [`CIMedian`](https://developer.apple.com/documentation/coreimage/cimedian)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/cimedian/inputimage)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/cimedian/inputimage)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coreimage/ciqrcodedescriptor/errorcorrectionlevel-swift.enum/init(rawvalue:))
- [`case levelH`](https://developer.apple.com/documentation/coreimage/ciqrcodedescriptor/errorcorrectionlevel-swift.enum/levelh)
- [`case levelL`](https://developer.apple.com/documentation/coreimage/ciqrcodedescriptor/errorcorrectionlevel-swift.enum/levell)
- [`case levelM`](https://developer.apple.com/documentation/coreimage/ciqrcodedescriptor/errorcorrectionlevel-swift.enum/levelm)
- [`case levelQ`](https://developer.apple.com/documentation/coreimage/ciqrcodedescriptor/errorcorrectionlevel-swift.enum/levelq)
- [`static let version9: CIRAWDecoderVersion`](https://developer.apple.com/documentation/coreimage/cirawdecoderversion/version9)
- [`static let version9DNG: CIRAWDecoderVersion`](https://developer.apple.com/documentation/coreimage/cirawdecoderversion/version9dng)
- [`var despeckleAmount: Float`](https://developer.apple.com/documentation/coreimage/cirawfilter/despeckleamount)
- [`class func downloadAllResources(timeout: TimeInterval, completionHandler: ((any Error)?) -> Void) -> Progress`](https://developer.apple.com/documentation/coreimage/cirawfilter/downloadallresources(timeout:completionhandler:))
- [`func downloadResources(timeout: TimeInterval, completionHandler: ((any Error)?) -> Void) -> Progress`](https://developer.apple.com/documentation/coreimage/cirawfilter/downloadresources(timeout:completionhandler:))
- [`var isDespeckleSupported: Bool`](https://developer.apple.com/documentation/coreimage/cirawfilter/isdespecklesupported)
- [`static let boostAmount: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/boostamount)
- [`static let boostAmount: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/boostamount)
- [`static let ciInputEnableEDRModeKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/ciinputenableedrmodekey)
- [`static let ciInputLocalToneMapAmountKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/ciinputlocaltonemapamountkey)
- [`static let disableGamutMap: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/disablegamutmap)
- [`static let disableGamutMap: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/disablegamutmap)
- [`static let propertiesKey: CIRAWFilterOption`](https://developer.apple.com/documentation/coreimage/cirawfilteroption/propertieskey)
- [`var plannedPassCount: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpasscount)
- [`var plannedPeakMemory: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpeakmemory)
- [`var plannedPixelsOverdrawn: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpixelsoverdrawn)
- [`var plannedPixelsProcessed: Int`](https://developer.apple.com/documentation/coreimage/cirendertask/plannedpixelsprocessed)
- [`CIRoundedQRCodeGenerator`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator)
- [`var centerSpaceSize: Float`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/centerspacesize)
- [`var color0: CIColor`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/color0)
- [`var color1: CIColor`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/color1)
- [`var correctionLevel: String`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/correctionlevel)
- [`var message: Data`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/message)
- [`var roundedData: Bool`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/roundeddata)
- [`var roundedMarkers: Int`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/roundedmarkers)
- [`var scale: Float`](https://developer.apple.com/documentation/coreimage/ciroundedqrcodegenerator/scale)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglegenerator/smoothness)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglegenerator/smoothness)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglestrokegenerator/smoothness)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglestrokegenerator/smoothness)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglestrokegenerator/smoothness)
- [`var smoothness: Float`](https://developer.apple.com/documentation/coreimage/ciroundedrectanglestrokegenerator/smoothness)
- [`CISystemToneMap`](https://developer.apple.com/documentation/coreimage/cisystemtonemap)
- [`CISystemToneMap`](https://developer.apple.com/documentation/coreimage/cisystemtonemap)
- [`var displayHeadroom: Float`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/displayheadroom)
- [`var displayHeadroom: Float`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/displayheadroom)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/inputimage)
- [`var inputImage: CIImage?`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/inputimage)
- [`var preferredDynamicRange: CIDynamicRangeOption?`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/preferreddynamicrange)
- [`var preferredDynamicRange: CIDynamicRangeOption?`](https://developer.apple.com/documentation/coreimage/cisystemtonemap/preferreddynamicrange)
- [`var COREIMAGE_SUPPORTS_IOSURFACE: Int32`](https://developer.apple.com/documentation/coreimage/coreimage_supports_iosurface)
- [`var COREIMAGE_SUPPORTS_OPENGLES: Int32`](https://developer.apple.com/documentation/coreimage/coreimage_supports_opengles)
- [`let kCIInputBacksideImageKey: String`](https://developer.apple.com/documentation/coreimage/kciinputbacksideimagekey)
- [`let kCIInputBiasVectorKey: String`](https://developer.apple.com/documentation/coreimage/kciinputbiasvectorkey)
- [`let kCIInputColor0Key: String`](https://developer.apple.com/documentation/coreimage/kciinputcolor0key)
- [`let kCIInputColor1Key: String`](https://developer.apple.com/documentation/coreimage/kciinputcolor1key)
- [`let kCIInputColorSpaceKey: String`](https://developer.apple.com/documentation/coreimage/kciinputcolorspacekey)
- [`let kCIInputCountKey: String`](https://developer.apple.com/documentation/coreimage/kciinputcountkey)
- [`let kCIInputExtrapolateKey: String`](https://developer.apple.com/documentation/coreimage/kciinputextrapolatekey)
- [`let kCIInputPaletteImageKey: String`](https://developer.apple.com/documentation/coreimage/kciinputpaletteimagekey)
- [`let kCIInputPerceptualKey: String`](https://developer.apple.com/documentation/coreimage/kciinputperceptualkey)
- [`let kCIInputPoint0Key: String`](https://developer.apple.com/documentation/coreimage/kciinputpoint0key)
- [`let kCIInputPoint1Key: String`](https://developer.apple.com/documentation/coreimage/kciinputpoint1key)
- [`let kCIInputRadius0Key: String`](https://developer.apple.com/documentation/coreimage/kciinputradius0key)
- [`let kCIInputRadius1Key: String`](https://developer.apple.com/documentation/coreimage/kciinputradius1key)
- [`let kCIInputThresholdKey: String`](https://developer.apple.com/documentation/coreimage/kciinputthresholdkey)
- [`var UNIFIED_CORE_IMAGE: Int32`](https://developer.apple.com/documentation/coreimage/unified_core_image)

</details>
<!-- /generated:missing -->
