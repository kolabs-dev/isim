// isim AVFoundation photo capture (self-authored, iOS API names): AVCapturePhotoOutput, AVCapturePhotoSettings,
// AVCapturePhotoBracketSettings, AVCaptureResolvedPhotoSettings and AVCapturePhoto.
// A photo is the newest frame of the connected camera (adapted: isim's simulated camera). Its file data is HEIC
// (when the host's ffmpeg has libx265; isim writes the HEIF container itself) or JPEG; RAW photos are 14-bit Bayer
// (RGGB) pixel buffers and DNG files made from the frame (linearized sRGB, so the colours round-trip); a flash or the
// torch brightens the picture (the front camera's Retina Flash lights the screen white); Live Photos keep 1.5 s of
// frames and sound before and after the shot and write them as a QuickTime movie; depth comes from the simulated
// scene (ISIM_CAMERA_DEPTH). Photos carry Exif / TIFF metadata as a dictionary (not embedded in the file data).
import UIKit
import AudioToolbox
import isim_host

public struct AVVideoCodecType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let h264 = AVVideoCodecType(rawValue: "avc1")
    public static let hevc = AVVideoCodecType(rawValue: "hvc1")
    public static let hevcWithAlpha = AVVideoCodecType(rawValue: "muxa")
    public static let jpeg = AVVideoCodecType(rawValue: "jpeg")
    public static let proRes422 = AVVideoCodecType(rawValue: "apcn")
    public static let proRes4444 = AVVideoCodecType(rawValue: "ap4h")
}

// MARK: - settings

open class AVCapturePhotoSettings: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static var _next: Int64 = 1
    public let uniqueID: Int64
    public let format: [String: Any]?
    var _raw: OSType = 0, _rawFileType: AVFileType?, _processedFileType: AVFileType?
    public var rawPhotoPixelFormatType: OSType { _raw }
    public var rawFileType: AVFileType? { _rawFileType }
    public var processedFileType: AVFileType? { _processedFileType }
    open var flashMode: AVCaptureDevice.FlashMode = .off
    open var isHighResolutionPhotoEnabled = false
    open var isAutoStillImageStabilizationEnabled = true
    open var photoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .balanced
    open var maxPhotoDimensions = CMVideoDimensions(width: 0, height: 0)
    open var previewPhotoFormat: [String: Any]?
    open var embeddedThumbnailPhotoFormat: [String: Any]?
    open var rawEmbeddedThumbnailPhotoFormat: [String: Any]?
    open var isDepthDataDeliveryEnabled = false
    open var isDepthDataFiltered = true
    open var embedsDepthDataInPhoto = true
    open var isPortraitEffectsMatteDeliveryEnabled = false
    open var embedsPortraitEffectsMatteInPhoto = true
    open var isCameraCalibrationDataDeliveryEnabled = false
    open var isAutoRedEyeReductionEnabled = true
    open var isAutoVirtualDeviceFusionEnabled = true
    open var isAutoDualCameraFusionEnabled = true
    open var isAutoContentAwareDistortionCorrectionEnabled = false
    open var isShutterSoundSuppressionEnabled = false
    open var metadata: [String: Any] = [:]
    /// Live Photos: where the movie goes (nil: a still photo)
    open var livePhotoMovieFileURL: URL?
    open var livePhotoVideoCodecType: AVVideoCodecType = .h264
    public override init() { uniqueID = AVCapturePhotoSettings._next; AVCapturePhotoSettings._next += 1; format = nil; super.init() }
    public init(format: [String: Any]?) { uniqueID = AVCapturePhotoSettings._next; AVCapturePhotoSettings._next += 1; self.format = format; super.init() }
    convenience init(format: [String: Any]?, raw: OSType, rawFileType: AVFileType?, processedFileType: AVFileType?) {
        self.init(format: format)
        _raw = raw; _rawFileType = rawFileType; _processedFileType = processedFileType
    }
    public convenience init(rawPixelFormatType: OSType) { self.init(format: nil, raw: rawPixelFormatType, rawFileType: .dng, processedFileType: nil) }
    public convenience init(rawPixelFormatType: OSType, processedFormat: [String: Any]?) {
        self.init(format: processedFormat, raw: rawPixelFormatType, rawFileType: .dng, processedFileType: nil)
    }
    public convenience init(rawPixelFormatType: OSType, rawFileType: AVFileType?, processedFormat: [String: Any]?, processedFileType: AVFileType?) {
        self.init(format: processedFormat, raw: rawPixelFormatType, rawFileType: rawFileType ?? .dng, processedFileType: processedFileType)
    }
    public convenience init(from settings: AVCapturePhotoSettings) {
        self.init(format: settings.format, raw: settings.rawPhotoPixelFormatType, rawFileType: settings.rawFileType, processedFileType: settings.processedFileType)
        flashMode = settings.flashMode; photoQualityPrioritization = settings.photoQualityPrioritization; maxPhotoDimensions = settings.maxPhotoDimensions
        previewPhotoFormat = settings.previewPhotoFormat; embeddedThumbnailPhotoFormat = settings.embeddedThumbnailPhotoFormat
        isDepthDataDeliveryEnabled = settings.isDepthDataDeliveryEnabled; isDepthDataFiltered = settings.isDepthDataFiltered
        isShutterSoundSuppressionEnabled = settings.isShutterSoundSuppressionEnabled; metadata = settings.metadata
        livePhotoVideoCodecType = settings.livePhotoVideoCodecType      // the movie URL is per capture (iOS clears it)
    }
    /// HEVC (HEIC files) unless asked otherwise, like iOS
    var _codec: AVVideoCodecType {
        (format?[AVVideoCodecKey] as? String).map(AVVideoCodecType.init(rawValue:)) ?? (format?[AVVideoCodecKey] as? AVVideoCodecType)
            ?? (format?[kCVPixelBufferPixelFormatTypeKey as String] != nil ? AVVideoCodecType(rawValue: "") : .hevc)
    }
    var _pixelFormat: OSType? {
        guard let f = format?[kCVPixelBufferPixelFormatTypeKey as String] else { return nil }
        return (f as? NSNumber).map { OSType(truncatingIfNeeded: $0.int64Value) } ?? (f as? UInt32) ?? (f as? Int).map { OSType(truncatingIfNeeded: $0) }
    }
    open var availablePreviewPhotoPixelFormatTypes: [OSType] { [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] }
    open var availableEmbeddedThumbnailPhotoCodecTypes: [AVVideoCodecType] { [.jpeg] }
    open var availableRawEmbeddedThumbnailPhotoCodecTypes: [AVVideoCodecType] { [] }
    var _isProcessed: Bool { rawPhotoPixelFormatType == 0 || format != nil }
}

open class AVCaptureBracketedStillImageSettings: NSObject, @unchecked Sendable {
    /// brightness of this exposure relative to the scene
    var _gain: Double { 1 }
}
open class AVCaptureManualExposureBracketedStillImageSettings: AVCaptureBracketedStillImageSettings, @unchecked Sendable {
    public let exposureDuration: CMTime
    public let iso: Float
    init(duration: CMTime, iso: Float) { exposureDuration = duration; self.iso = iso }
    open class func manualExposureSettings(exposureDuration: CMTime, iso: Float) -> Self {
        AVCaptureManualExposureBracketedStillImageSettings(duration: exposureDuration, iso: iso) as! Self
    }
    override var _gain: Double {
        let d = exposureDuration.isNumeric ? exposureDuration.seconds : 1.0 / 60, i = iso > 0 ? Double(iso) : 100
        return max(0.05, min(16, i / 100 * d * 60))
    }
}
open class AVCaptureAutoExposureBracketedStillImageSettings: AVCaptureBracketedStillImageSettings, @unchecked Sendable {
    public let exposureTargetBias: Float
    init(bias: Float) { exposureTargetBias = bias }
    open class func autoExposureSettings(exposureTargetBias: Float) -> Self { AVCaptureAutoExposureBracketedStillImageSettings(bias: exposureTargetBias) as! Self }
    override var _gain: Double { pow(2, Double(exposureTargetBias == AVCaptureDevice.currentExposureTargetBias ? 0 : exposureTargetBias)) }
}
/// Several exposures of one moment, delivered as separate photos (sequenceCount 1, 2, ...).
open class AVCapturePhotoBracketSettings: AVCapturePhotoSettings, @unchecked Sendable {
    public let bracketedSettings: [AVCaptureBracketedStillImageSettings]
    open var isLensStabilizationEnabled = false
    public init(rawPixelFormatType: OSType, processedFormat: [String: Any]?, bracketedSettings: [AVCaptureBracketedStillImageSettings]) {
        self.bracketedSettings = bracketedSettings
        super.init(format: processedFormat)
        _raw = rawPixelFormatType; _rawFileType = rawPixelFormatType != 0 ? .dng : nil
    }
    public init(rawPixelFormatType: OSType, rawFileType: AVFileType?, processedFormat: [String: Any]?, processedFileType: AVFileType?,
                bracketedSettings: [AVCaptureBracketedStillImageSettings]) {
        self.bracketedSettings = bracketedSettings
        super.init(format: processedFormat)
        _raw = rawPixelFormatType; _rawFileType = rawFileType; _processedFileType = processedFileType
    }
}

open class AVCaptureResolvedPhotoSettings: NSObject, @unchecked Sendable {
    public let uniqueID: Int64
    public let photoDimensions: CMVideoDimensions
    public let rawPhotoDimensions: CMVideoDimensions
    public let previewDimensions: CMVideoDimensions
    public let embeddedThumbnailDimensions: CMVideoDimensions
    public let livePhotoMovieDimensions: CMVideoDimensions
    let _flash: Bool, _count: Int
    public var isFlashEnabled: Bool { _flash }
    public var expectedPhotoCount: Int { _count }
    public var isRedEyeReductionEnabled: Bool { false }
    public var isStillImageStabilizationEnabled: Bool { false }
    public var isVirtualDeviceFusionEnabled: Bool { false }
    public var isDualCameraFusionEnabled: Bool { false }
    public var isContentAwareDistortionCorrectionEnabled: Bool { false }
    public var isFastCapturePrioritizationEnabled: Bool { false }
    public var portraitEffectsMatteDimensions: CMVideoDimensions { CMVideoDimensions(width: 0, height: 0) }
    public var deferredPhotoProxyDimensions: CMVideoDimensions { CMVideoDimensions(width: 0, height: 0) }
    public var photoProcessingTimeRange: CMTimeRange { CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 10)) }
    convenience init(_ s: AVCapturePhotoSettings, _ size: CGSize) {
        self.init(s, size, flash: false, live: .zero, count: 1)
    }
    init(_ s: AVCapturePhotoSettings, _ size: CGSize, flash: Bool, live: CGSize, count: Int) {
        uniqueID = s.uniqueID
        let d = CMVideoDimensions(width: Int32(size.width), height: Int32(size.height)), none = CMVideoDimensions(width: 0, height: 0)
        photoDimensions = s._isProcessed ? d : none
        rawPhotoDimensions = s.rawPhotoPixelFormatType != 0 ? d : none
        previewDimensions = _previewSize(s.previewPhotoFormat, size).map { CMVideoDimensions(width: Int32($0.width), height: Int32($0.height)) } ?? none
        embeddedThumbnailDimensions = _previewSize(s.embeddedThumbnailPhotoFormat, size).map { CMVideoDimensions(width: Int32($0.width), height: Int32($0.height)) } ?? none
        livePhotoMovieDimensions = CMVideoDimensions(width: Int32(live.width), height: Int32(live.height))
        _flash = flash
        _count = count
    }
}
/// the size a preview / thumbnail format asks for (kCVPixelBufferWidthKey / HeightKey, aspect kept), else a 1/4 size
func _previewSize(_ f: [String: Any]?, _ size: CGSize) -> CGSize? {
    guard let f else { return nil }
    let w = (f[kCVPixelBufferWidthKey as String] as? NSNumber)?.doubleValue ?? (f[kCVPixelBufferWidthKey as String] as? Int).map(Double.init)
    let h = (f[kCVPixelBufferHeightKey as String] as? NSNumber)?.doubleValue ?? (f[kCVPixelBufferHeightKey as String] as? Int).map(Double.init)
    let sc = min((w ?? size.width / 4) / size.width, (h ?? size.height / 4) / size.height)
    return CGSize(width: max(1, (size.width * sc).rounded()), height: max(1, (size.height * sc).rounded()))
}

// MARK: - photo

open class AVCapturePhoto: NSObject, @unchecked Sendable {
    @objc public enum LensStabilizationStatus: Int, Sendable { case unsupported = 0, off, active, outOfRange, unavailable }
    public let timestamp: CMTime
    public let resolvedSettings: AVCaptureResolvedPhotoSettings
    public let pixelBuffer: CVPixelBuffer?
    let _cg: CGImage?
    let _data: Data?
    let _raw: Bool
    let _preview: CVPixelBuffer?
    let _depth: AVDepthData?
    let _metadata: [String: Any]
    let _sequence: Int
    let _bracket: AVCaptureBracketedStillImageSettings?
    let _device: AVCaptureDevice.DeviceType?
    init(time: CMTime, settings: AVCaptureResolvedPhotoSettings, pixels: CVPixelBuffer?, image: CGImage?, jpeg: Data?) {
        timestamp = time; resolvedSettings = settings; pixelBuffer = pixels; _cg = image; _data = jpeg
        _raw = false; _preview = nil; _depth = nil; _metadata = [:]; _sequence = 1; _bracket = nil; _device = nil
    }
    init(time: CMTime, settings: AVCaptureResolvedPhotoSettings, pixels: CVPixelBuffer?, image: CGImage?, data: Data?, raw: Bool,
         preview: CVPixelBuffer?, depth: AVDepthData?, metadata: [String: Any], sequence: Int, bracket: AVCaptureBracketedStillImageSettings?,
         device: AVCaptureDevice.DeviceType?) {
        timestamp = time; resolvedSettings = settings; pixelBuffer = pixels; _cg = image; _data = data; _raw = raw
        _preview = preview; _depth = depth; _metadata = metadata; _sequence = sequence; _bracket = bracket; _device = device
    }
    public var photoCount: Int { _sequence }
    public var sequenceCount: Int { _sequence }
    public var isRawPhoto: Bool { _raw }
    public var metadata: [String: Any] { _metadata.isEmpty ? ["{Exif}": ["LensModel": "isim Simulated Camera"], "Orientation": 1] : _metadata }
    public var previewPixelBuffer: CVPixelBuffer? { _preview }
    public var embeddedThumbnailPhotoFormat: [String: Any]? { nil }
    public var depthData: AVDepthData? { _depth }
    public var cameraCalibrationData: AnyObject? { nil }
    public var sourceDeviceType: AVCaptureDevice.DeviceType? { _device }
    public var bracketSettings: AVCaptureBracketedStillImageSettings? { _bracket }
    public var lensStabilizationStatus: LensStabilizationStatus { _bracket != nil ? .off : .unsupported }
    /// HEIC, JPEG or (RAW) DNG data; nil for an uncompressed processed photo, like iOS
    open func fileDataRepresentation() -> Data? { _data }
    open func cgImageRepresentation() -> CGImage? { _cg }
    open func previewCGImageRepresentation() -> CGImage? {
        guard let p = _preview else { return _cg }
        let px = p._bgra()
        return _onMainSync { px.withUnsafeBytes { _cgImageFromBGRA($0.baseAddress!, width: p._width, height: p._height) } }
    }
}

public protocol AVCapturePhotoCaptureDelegate: NSObjectProtocol {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?)
}
extension AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime,
                            resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {}
}

// MARK: - output

open class AVCapturePhotoOutput: AVCaptureOutput, @unchecked Sendable {
    @objc public enum QualityPrioritization: Int, Sendable { case speed = 1, balanced, quality }
    @objc public enum CaptureReadiness: Int, Sendable { case sessionNotRunning = 0, ready, notReadyMomentarily, notReadyWaitingForCapture, notReadyWaitingForProcessing }
    public override init() { super.init() }
    open var isHighResolutionCaptureEnabled = false
    open var maxPhotoQualityPrioritization: QualityPrioritization = .balanced
    // isim ABI: until 0.5 this property was typed Int; keep its getter/setter entry points for apps built then
    @usableFromInline @_silgen_name("$s12AVFoundation20AVCapturePhotoOutputC03maxC21QualityPrioritizationSivgTj")
    final func _abi_maxPhotoQualityPrioritizationInt() -> Int { maxPhotoQualityPrioritization.rawValue }
    @usableFromInline @_silgen_name("$s12AVFoundation20AVCapturePhotoOutputC03maxC21QualityPrioritizationSivsTj")
    final func _abi_setMaxPhotoQualityPrioritizationInt(_ v: Int) { maxPhotoQualityPrioritization = QualityPrioritization(rawValue: v) ?? .balanced }
    open var maxPhotoDimensions = CMVideoDimensions(width: 0, height: 0)
    var _device: AVCaptureDevice? { connection(with: .video)?._device }
    open var availablePhotoCodecTypes: [AVVideoCodecType] { isim_heif_can_encode() != 0 ? [.hevc, .jpeg] : [.jpeg] }
    open var availablePhotoPixelFormatTypes: [OSType] { [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] }
    open var availablePhotoFileTypes: [AVFileType] { (isim_heif_can_encode() != 0 ? [.heic] : []) + [.jpg, .dng] }
    open var availableRawPhotoPixelFormatTypes: [OSType] { _device == nil ? [] : [kCVPixelFormatType_14Bayer_RGGB] }
    open var availableRawPhotoFileTypes: [AVFileType] { _device == nil ? [] : [.dng] }
    open var isAppleProRAWSupported: Bool { false }
    open var isAppleProRAWEnabled = false
    open class func isBayerRAWPixelFormat(_ f: OSType) -> Bool { [kCVPixelFormatType_14Bayer_RGGB, kCVPixelFormatType_14Bayer_GRBG, kCVPixelFormatType_14Bayer_GBRG, kCVPixelFormatType_14Bayer_BGGR].contains(f) }
    open class func isAppleProRAWPixelFormat(_ f: OSType) -> Bool { false }
    open var supportedFlashModes: [AVCaptureDevice.FlashMode] { _device?.hasFlash == true ? [.off, .on, .auto] : [.off] }
    open var isLivePhotoCaptureSupported: Bool { _device != nil }
    open var isLivePhotoCaptureEnabled = false
    open var isLivePhotoCaptureSuspended = false
    open var isLivePhotoAutoTrimmingEnabled = true
    open var availableLivePhotoVideoCodecTypes: [AVVideoCodecType] { _FFmpeg.hasHEVC ? [.hevc, .h264] : [.h264] }
    open var isDepthDataDeliverySupported: Bool { _device?._depth == true }
    open var isDepthDataDeliveryEnabled = false
    open var isPortraitEffectsMatteDeliverySupported: Bool { false }
    open var isPortraitEffectsMatteDeliveryEnabled = false
    open var isCameraCalibrationDataDeliverySupported: Bool { false }
    open var isStillImageStabilizationSupported: Bool { false }
    open var isVirtualDeviceFusionSupported: Bool { false }
    open var isDualCameraFusionSupported: Bool { false }
    open var isContentAwareDistortionCorrectionSupported: Bool { false }
    open var isContentAwareDistortionCorrectionEnabled = false
    open var maxBracketedCapturePhotoCount: Int { 3 }
    open var isLensStabilizationDuringBracketedCaptureSupported: Bool { false }
    open var isZeroShutterLagSupported: Bool { true }
    open var isZeroShutterLagEnabled = true
    open var isResponsiveCaptureSupported: Bool { true }
    open var isResponsiveCaptureEnabled = false
    open var isFastCapturePrioritizationSupported: Bool { true }
    open var isFastCapturePrioritizationEnabled = false
    open var isAutoDeferredPhotoDeliverySupported: Bool { false }
    open var isAutoDeferredPhotoDeliveryEnabled = false
    open var isShutterSoundSuppressionSupported: Bool { true }
    open var captureReadiness: CaptureReadiness { _session?.isRunning == true ? (_inFlight > 0 && _inFlight >= 3 ? .notReadyWaitingForCapture : .ready) : .sessionNotRunning }
    open var photoSettingsForSceneMonitoring: AVCapturePhotoSettings?
    /// with photoSettingsForSceneMonitoring's flash mode auto: whether the scene is dark enough for the flash (KVO)
    @objc open private(set) var isFlashScene = false
    @objc open private(set) var isStillImageStabilizationScene = false
    open private(set) var preparedPhotoSettingsArray: [AVCapturePhotoSettings] = []
    open func setPreparedPhotoSettingsArray(_ a: [AVCapturePhotoSettings], completionHandler: ((Bool, Error?) -> Void)? = nil) {
        preparedPhotoSettingsArray = a
        if let h = completionHandler { DispatchQueue.main.async { h(true, nil) } }
    }
    open func supportedPhotoCodecTypes(for fileType: AVFileType) -> [AVVideoCodecType] {
        fileType == .heic || fileType == .heif ? availablePhotoCodecTypes.filter { $0 == .hevc } : fileType == .jpg ? [.jpeg] : []
    }
    open func supportedPhotoPixelFormatTypes(for fileType: AVFileType) -> [OSType] { fileType == .tif ? [kCVPixelFormatType_32BGRA] : [] }
    open func supportedRawPhotoPixelFormatTypes(for fileType: AVFileType) -> [OSType] { fileType == .dng ? availableRawPhotoPixelFormatTypes : [] }
    var _inFlight = 0
    var _frames = 0

    override func _frame(_ f: _Frame, connection conn: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard conn._carries(.video) else { return nil }
        _frames += 1
        if _frames % 15 == 0, let s = photoSettingsForSceneMonitoring {
            let dark = s.flashMode == .auto && supportedFlashModes.contains(.auto) && feed.mean < 0.25
            if dark != isFlashScene { DispatchQueue.main.async { self.willChangeValue(forKey: "isFlashScene"); self.isFlashScene = dark; self.didChangeValue(forKey: "isFlashScene") } }
        }
        return nil
    }

    /// Captures the newest frame of the connected camera (see the file comment for what each kind of photo holds).
    open func capturePhoto(with settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate) {
        let conn = connection(with: .video)
        let session = _session
        let feed = session?._feed(for: conn)
        let size = feed.map { CGSize(width: $0.width, height: $0.height) } ?? _CameraSource.size
        let device = conn?._device
        let turned = Int(((conn?.videoRotationAngle ?? 0) / 90).rounded()) % 2 != 0
        let photoSize = turned ? CGSize(width: size.height, height: size.width) : size
        let flash: Bool = {
            guard let d = device, d.hasFlash, settings.flashMode != .off else { return false }
            return settings.flashMode == .on || (feed?.mean ?? 0.5) < 0.25
        }()
        let live = settings.livePhotoMovieFileURL != nil && isLivePhotoCaptureEnabled && feed != nil
        let liveSize: CGSize = live ? (size.width > 960 ? CGSize(width: Double(Int(size.width / 2) & ~1), height: Double(Int(size.height / 2) & ~1)) : size) : .zero
        let brackets = (settings as? AVCapturePhotoBracketSettings)?.bracketedSettings ?? []
        let perShot = (settings._isProcessed ? 1 : 0) + (settings.rawPhotoPixelFormatType != 0 ? 1 : 0)
        let resolved = AVCaptureResolvedPhotoSettings(settings, photoSize, flash: flash, live: liveSize, count: max(1, brackets.count) * perShot)
        _inFlight += 1
        let mirror = conn?.isVideoMirrored ?? false, angle = conn?.videoRotationAngle ?? 0
        DispatchQueue.main.async { [self] in
            delegate.photoOutput(self, willBeginCaptureFor: resolved)
            guard let s = session, s.isRunning, let feed, s._authorized, feed.latest() != nil else {
                let e = AVError(.sessionNotRunning)
                delegate.photoOutput(self, willCapturePhotoFor: resolved)
                delegate.photoOutput(self, didFinishProcessingPhoto: AVCapturePhoto(time: .zero, settings: resolved, pixels: nil, image: nil, jpeg: nil), error: e)
                delegate.photoOutput(self, didFinishCaptureFor: resolved, error: e)
                _inFlight -= 1
                return
            }
            if flash && device?.position == .front { _retinaFlash() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (flash && device?.position == .front ? 0.2 : 0)) { [self] in
                delegate.photoOutput(self, willCapturePhotoFor: resolved)
                if !settings.isShutterSoundSuppressionEnabled { AudioServicesPlaySystemSound(1108) }      // the camera shutter
                guard let frame = feed.latest() else { return }
                feed.lock.lock(); let before = feed.history, audioBefore = feed.audioHistory; feed.lock.unlock()
                delegate.photoOutput(self, didCapturePhotoFor: resolved)
                if flash { NSLog("isim AVFoundation: flash fired") }
                let flashGain = flash ? (device?.position == .front ? 1.3 : 1.6) : 1
                var (px, w, h) = _transformBGRA(frame.px, frame.w, frame.h, angle: angle, mirror: mirror)
                let liveID = live ? UUID().uuidString : nil
                let shots: [(Double, AVCaptureBracketedStillImageSettings?)] = brackets.isEmpty ? [(1, nil)] : brackets.map { ($0._gain, $0) }
                for (i, (gain, bracket)) in shots.enumerated() {
                    var shot = px
                    if gain * flashGain != 1 { _brighten(&shot, gain * flashGain) }
                    let meta = _photoMetadata(settings: settings, device: device, size: CGSize(width: w, height: h), flash: flash, liveID: liveID)
                    let depth = settings.isDepthDataDeliveryEnabled && isDepthDataDeliveryEnabled && device?._depth == true
                        ? device?.activeDepthDataFormat.flatMap { f -> AVDepthData? in
                            let d = f.formatDescription.dimensions
                            let ds = turned ? CGSize(width: Int(d.height), height: Int(d.width)) : CGSize(width: Int(d.width), height: Int(d.height))
                            return _DepthScene.map(size: ds, type: f.formatDescription.mediaSubType, mirrored: mirror).map { AVDepthData(map: $0, filtered: settings.isDepthDataFiltered, accuracy: .absolute) }
                        } : nil
                    if settings._isProcessed {
                        let photo = _processedPhoto(shot, w, h, settings: settings, resolved: resolved, time: frame.time, depth: depth, meta: meta, sequence: i + 1, bracket: bracket, device: device)
                        delegate.photoOutput(self, didFinishProcessingPhoto: photo, error: nil)
                    }
                    if settings.rawPhotoPixelFormatType != 0 {
                        let bayer = _bayer(shot, w, h)
                        let pb = CVBuffer(_width: w, height: h, format: kCVPixelFormatType_14Bayer_RGGB)
                        if let pb { let base = CVPixelBufferGetBaseAddress(pb)!, bpr = CVPixelBufferGetBytesPerRow(pb)
                            bayer.withUnsafeBytes { s in for y in 0..<h { (base + y * bpr).copyMemory(from: s.baseAddress! + y * w * 2, byteCount: w * 2) } } }
                        let raw = AVCapturePhoto(time: frame.time, settings: resolved, pixels: pb, image: nil, data: _dng(bayer, w, h), raw: true,
                                                 preview: nil, depth: nil, metadata: meta, sequence: i + 1, bracket: bracket, device: device?.deviceType)
                        delegate.photoOutput(self, didFinishProcessingPhoto: raw, error: nil)
                    }
                }
                _ = (px, w, h)
                px = []
                guard live, let url = settings.livePhotoMovieFileURL else {
                    delegate.photoOutput(self, didFinishCaptureFor: resolved, error: nil)
                    _inFlight -= 1
                    return
                }
                // Live Photo: 1.5 s after the shot, then the movie
                var after: [_Frame] = [], audioAfter: [Int16] = []
                let end = frame.host + 1.5
                feed.listenAudio { s in audioAfter += s; return _captureHostTime() < end }
                feed.listen { f in
                    after.append(f.reduced())
                    guard f.host >= end else { return true }
                    DispatchQueue.main.async { [self] in
                        delegate.photoOutput(self, didFinishRecordingLivePhotoMovieForEventualFileAt: url, resolvedSettings: resolved)
                        let frames = before + after
                        let codec = availableLivePhotoVideoCodecTypes.contains(settings.livePhotoVideoCodecType) ? settings.livePhotoVideoCodecType : .h264
                        let hasMic = s._micInputs.isEmpty == false
                        DispatchQueue.global().async { [self] in
                            let sink = frames.first.map { _RawVideoSink(width: $0.w, height: $0.h) }
                            let t0 = frames.first?.host ?? frame.host
                            for f in frames where f.w == sink?.width && f.h == sink?.height {
                                let (fp, _, _) = _transformBGRA(f.px, f.w, f.h, angle: angle, mirror: mirror)
                                fp.withUnsafeBufferPointer { sink?.append($0.baseAddress!, time: f.host - t0) }
                            }
                            let audio = hasMic ? Array(audioBefore.suffix(Int((frame.host - t0) * 48000))) + audioAfter : nil
                            let err = _writeMovie(video: sink, fps: sink.map { $0.times.count > 1 ? $0.fps : 30 } ?? 30, audio: audio, to: url, codec: codec, fileType: .mov)
                            let duration = CMTime(seconds: (frames.last?.host ?? end) - t0, preferredTimescale: 600)
                            let display = CMTime(seconds: frame.host - t0, preferredTimescale: 600)
                            NSLog("isim AVFoundation: Live Photo movie %@ (%d frames, content identifier %@)", url.lastPathComponent, frames.count, liveID ?? "")
                            DispatchQueue.main.async { [self] in
                                delegate.photoOutput(self, didFinishProcessingLivePhotoToMovieFileAt: url, duration: duration, photoDisplayTime: display, resolvedSettings: resolved, error: err)
                                delegate.photoOutput(self, didFinishCaptureFor: resolved, error: nil)
                                _inFlight -= 1
                            }
                        }
                    }
                    return false
                }
            }
        }
    }

    func _processedPhoto(_ px: [UInt8], _ w: Int, _ h: Int, settings: AVCapturePhotoSettings, resolved: AVCaptureResolvedPhotoSettings, time: CMTime,
                         depth: AVDepthData?, meta: [String: Any], sequence: Int, bracket: AVCaptureBracketedStillImageSettings?, device: AVCaptureDevice?) -> AVCapturePhoto {
        let cg = px.withUnsafeBytes { _cgImageFromBGRA($0.baseAddress!, width: w, height: h) }
        var data: Data?
        var pb: CVPixelBuffer?
        if let fmt = settings._pixelFormat {
            pb = px.withUnsafeBufferPointer { _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: fmt) }
        } else if let cg {
            var rect = CGRect.zero
            let hd = isim_cg_image_handle(cg, &rect)
            let heic = settings._codec == .hevc && isim_heif_can_encode() != 0
            var out: UnsafeMutablePointer<UInt8>? = nil
            let n = isim_image_encode(hd, heic ? 3 : 1, 0.9, &out)
            if n > 0, let o = out { data = Data(bytes: o, count: n); isim_image_bytes_free(o) }
        }
        var preview: CVPixelBuffer?
        if let ps = _previewSize(settings.previewPhotoFormat, CGSize(width: w, height: h)) {
            let pw = Int(ps.width), ph = Int(ps.height)
            var small = [UInt8](repeating: 0, count: pw * ph * 4)
            for y in 0..<ph { for x in 0..<pw {
                let sx = x * w / pw, sy = y * h / ph
                for k in 0..<4 { small[(y * pw + x) * 4 + k] = px[(sy * w + sx) * 4 + k] }
            } }
            let f = (settings.previewPhotoFormat?[kCVPixelBufferPixelFormatTypeKey as String] as? NSNumber).map { OSType(truncatingIfNeeded: $0.int64Value) } ?? kCVPixelFormatType_32BGRA
            preview = small.withUnsafeBufferPointer { _pixelBuffer(fromBGRA: $0.baseAddress!, width: pw, height: ph, format: f) }
        }
        return AVCapturePhoto(time: time, settings: resolved, pixels: pb, image: cg, data: data, raw: false, preview: preview, depth: depth,
                              metadata: meta, sequence: sequence, bracket: bracket, device: device?.deviceType)
    }
}

/// the front camera's Retina Flash: the screen turns white for a moment
@MainActor func _retinaFlash() {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: UIScreen.main.bounds)
    w.frame = UIScreen.main.bounds
    w.windowLevel = UIWindow.Level(rawValue: 10_000)
    w.backgroundColor = .white
    w.accessibilityIdentifier = "retina-flash"
    w.isHidden = false
    _RetinaFlash.window = w
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { _RetinaFlash.window?.isHidden = true; _RetinaFlash.window = nil }
}
enum _RetinaFlash { nonisolated(unsafe) static var window: UIWindow? }

func _brighten(_ px: inout [UInt8], _ gain: Double) {
    let g = Int(gain * 256)
    px.withUnsafeMutableBufferPointer { p in
        var i = 0
        while i < p.count { for k in 0..<3 { p[i + k] = UInt8(min(255, (Int(p[i + k]) * g) >> 8)) }; i += 4 }
    }
}

/// Exif / TIFF metadata of a simulated photo
func _photoMetadata(settings: AVCapturePhotoSettings, device: AVCaptureDevice?, size: CGSize, flash: Bool, liveID: String?) -> [String: Any] {
    let df = DateFormatter(); df.dateFormat = "yyyy:MM:dd HH:mm:ss"; df.locale = Locale(identifier: "en_US_POSIX")
    let now = df.string(from: Date())
    var exif: [String: Any] = ["ExposureTime": device?.exposureDuration.seconds ?? 1.0 / 60, "ISOSpeedRatings": [Int(device?.iso ?? 100)],
                               "FNumber": Double(device?.lensAperture ?? 1.6), "FocalLength": device?.position == .front ? 2.7 : 6.0,
                               "LensModel": "isim Simulated Camera \(device?.localizedName ?? "")", "Flash": flash ? 25 : 16,
                               "PixelXDimension": Int(size.width), "PixelYDimension": Int(size.height),
                               "DateTimeOriginal": now, "DateTimeDigitized": now, "ExposureBiasValue": Double(device?.exposureTargetBias ?? 0)]
    if settings.photoQualityPrioritization == .quality { exif["CompositeImage"] = 1 }
    var m: [String: Any] = ["{Exif}": exif, "{TIFF}": ["Make": "isim", "Model": "isim Simulated Camera", "Software": "isim", "DateTime": now],
                            "Orientation": 1, "PixelWidth": Int(size.width), "PixelHeight": Int(size.height)]
    if let id = liveID { m["{MakerApple}"] = ["17": id] }
    for (k, v) in settings.metadata { m[k] = v }
    return m
}

/// 14-bit RGGB Bayer samples from BGRA: the sRGB values linearized, one colour per site
func _bayer(_ px: [UInt8], _ w: Int, _ h: Int) -> [UInt16] {
    var lut = [UInt16](repeating: 0, count: 256)
    for i in 0..<256 {
        let c = Double(i) / 255
        let l = c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        lut[i] = UInt16((l * 16383).rounded())
    }
    var out = [UInt16](repeating: 0, count: w * h)
    for y in 0..<h {
        for x in 0..<w {
            let p = (y * w + x) * 4
            let k = y % 2 == 0 ? (x % 2 == 0 ? 2 : 1) : (x % 2 == 0 ? 1 : 0)       // BGRA offsets: R, G, B
            out[y * w + x] = lut[Int(px[p + k])]
        }
    }
    return out
}

/// A DNG (TIFF/EP) file of a 14-bit RGGB mosaic: the colour matrix maps XYZ to the camera's (linear sRGB) space.
func _dng(_ bayer: [UInt16], _ w: Int, _ h: Int) -> Data {
    struct Entry { let tag: UInt16, type: UInt16, count: UInt32, value: [UInt8] }
    func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8)] }
    func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8 & 255), UInt8(v >> 16 & 255), UInt8(v >> 24)] }
    func ascii(_ s: String) -> [UInt8] { Array(s.utf8) + [0] }
    func srational(_ v: [Double]) -> [UInt8] { v.flatMap { le32(UInt32(bitPattern: Int32(($0 * 10000).rounded()))) + le32(10000) } }
    let model = "isim Simulated Camera"
    let dataOffset: UInt32 = 8
    let dataSize = UInt32(w * h * 2)
    var entries: [Entry] = [
        Entry(tag: 254, type: 4, count: 1, value: le32(0)),
        Entry(tag: 256, type: 4, count: 1, value: le32(UInt32(w))),
        Entry(tag: 257, type: 4, count: 1, value: le32(UInt32(h))),
        Entry(tag: 258, type: 3, count: 1, value: le16(16)),
        Entry(tag: 259, type: 3, count: 1, value: le16(1)),
        Entry(tag: 262, type: 3, count: 1, value: le16(32803)),           // CFA
        Entry(tag: 271, type: 2, count: UInt32(ascii("isim").count), value: ascii("isim")),
        Entry(tag: 272, type: 2, count: UInt32(ascii(model).count), value: ascii(model)),
        Entry(tag: 273, type: 4, count: 1, value: le32(dataOffset)),
        Entry(tag: 274, type: 3, count: 1, value: le16(1)),
        Entry(tag: 277, type: 3, count: 1, value: le16(1)),
        Entry(tag: 278, type: 4, count: 1, value: le32(UInt32(h))),
        Entry(tag: 279, type: 4, count: 1, value: le32(dataSize)),
        Entry(tag: 284, type: 3, count: 1, value: le16(1)),
        Entry(tag: 305, type: 2, count: UInt32(ascii("isim").count), value: ascii("isim")),
        Entry(tag: 33421, type: 3, count: 2, value: le16(2) + le16(2)),    // CFARepeatPatternDim
        Entry(tag: 33422, type: 1, count: 4, value: [0, 1, 1, 2]),         // CFAPattern: R G / G B
        Entry(tag: 50706, type: 1, count: 4, value: [1, 4, 0, 0]),         // DNGVersion
        Entry(tag: 50707, type: 1, count: 4, value: [1, 1, 0, 0]),
        Entry(tag: 50708, type: 2, count: UInt32(ascii(model).count), value: ascii(model)),
        Entry(tag: 50714, type: 4, count: 1, value: le32(0)),              // BlackLevel
        Entry(tag: 50717, type: 4, count: 1, value: le32(16383)),          // WhiteLevel
        Entry(tag: 50721, type: 10, count: 9, value: srational([3.2406, -1.5372, -0.4986, -0.9689, 1.8758, 0.0415, 0.0557, -0.2040, 1.0570])),
        Entry(tag: 50728, type: 5, count: 3, value: (0..<3).flatMap { _ in le32(1) + le32(1) }),   // AsShotNeutral
        Entry(tag: 50778, type: 3, count: 1, value: le16(21)),             // CalibrationIlluminant1: D65
    ]
    entries.sort { $0.tag < $1.tag }
    var out = Data([0x49, 0x49, 42, 0])
    let ifdOffset = dataOffset + dataSize
    out.append(contentsOf: le32(ifdOffset))
    bayer.withUnsafeBytes { out.append(contentsOf: $0) }                   // little-endian 16-bit samples
    var extra = Data()
    let extraBase = ifdOffset + 2 + UInt32(entries.count) * 12 + 4
    var ifd = Data(le16(UInt16(entries.count)))
    for e in entries {
        ifd.append(contentsOf: le16(e.tag) + le16(e.type) + le32(e.count))
        if e.value.count <= 4 { ifd.append(contentsOf: e.value + [UInt8](repeating: 0, count: 4 - e.value.count)) }
        else {
            ifd.append(contentsOf: le32(extraBase + UInt32(extra.count)))
            extra.append(contentsOf: e.value)
            if extra.count % 2 == 1 { extra.append(0) }
        }
    }
    ifd.append(contentsOf: le32(0))
    out.append(ifd)
    out.append(extra)
    return out
}

extension AVFileType {
    public static let dng = AVFileType("com.adobe.raw-image")
    public static let heif = AVFileType("public.heif")
    public static let tif = AVFileType("public.tiff")
}
