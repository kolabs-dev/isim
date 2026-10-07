// isim AVFoundation capture (self-authored, iOS API names): AVCaptureSession, AVCaptureDevice, AVCaptureDeviceInput,
// AVCaptureVideoPreviewLayer, AVCapturePhotoOutput, AVCaptureVideoDataOutput, AVCaptureMetadataOutput (QR codes and
// barcodes) and AVCaptureMovieFileOutput.
//
// Like the iOS Simulator there is no camera by default: AVCaptureDevice.default(for: .video) is nil. isim adds a
// simulated camera when ISIM_CAMERA is set (adapted):
//   ISIM_CAMERA=<image file>    the picture, delivered as a live 30 fps feed
//   ISIM_CAMERA=<video file>    the video, looped, in real time
//   ISIM_CAMERA=webcam[:/dev/videoN]   the host webcam through ffmpeg's v4l2 input (opened only when asked)
// Both a back and a front camera are offered; they show the same feed, upright as in the source (no sensor rotation).
// Frames are decoded by the host's ffmpeg (host_capture.c), at most 1280 px on the longest side.
// The camera permission alert is the shared privacy prompt (remembered per app; ISIM_CAMERA_PERMISSION = allow|deny);
// no frames are delivered until access is granted. Metadata (QR/barcode) detection uses the host's libzbar when present.
// No microphone capture device (AVAudioRecorder/AVAudioEngine read ISIM_AUDIO_INPUT instead), no depth, no RAW/Live Photos.
import UIKit
import isim_host

extension AVMediaType {
    public static let depthData = AVMediaType("dpth")     /* the rest: AVAsset.swift */
}

@objc public enum AVAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized }

public struct AVError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = -11800, outOfMemory = -11801, sessionNotRunning = -11803, noDataCaptured = -11805, maximumDurationReached = -11810,
             deviceNotConnected = -11814, exportFailed = -11820, invalidSourceMedia = -11822, fileAlreadyExists = -11823,
             fileFormatNotRecognized = -11828, decoderNotFound = -11833, encoderNotFound = -11834,
             applicationIsNotAuthorizedToUseDevice = -11852, operationNotAllowed = -11862
    }
    public let code: Code
    let _info: [String: String]
    public init(_ code: Code) { self.code = code; _info = [:] }
    public init(_ code: Code, reason: String) { self.code = code; _info = [NSLocalizedFailureReasonErrorKey: reason] }
    public static var errorDomain: String { AVFoundationErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        var u: [String: Any] = _info
        u[NSLocalizedDescriptionKey] = errorDescription
        return u
    }
    public var errorDescription: String? {
        switch code {
        case .deviceNotConnected: return "Cannot Record"
        case .applicationIsNotAuthorizedToUseDevice: return "Not authorized to use the camera"
        case .exportFailed: return "Cannot Export"
        case .fileAlreadyExists: return "File Already Exists"
        case .encoderNotFound, .decoderNotFound: return "Cannot Encode"
        default: return "The operation could not be completed"
        }
    }
    public var failureReason: String? { _info[NSLocalizedFailureReasonErrorKey] }
}

/// The simulated camera source (ISIM_CAMERA).
enum _CameraSource {
    static var kind: Int32 { isim_camera_source(nil, 0) }
    static var available: Bool { kind != 0 }
    /// frame size the host will deliver (probed once, like host_capture.c's bounding)
    nonisolated(unsafe) static var _size: CGSize?
    static var size: CGSize {
        if let s = _size { return s }
        var s = CGSize(width: 1280, height: 720)
        var buf = [CChar](repeating: 0, count: 1024)
        if isim_camera_source(&buf, 1024) != 3 {
            var i = isim_media_info()
            if isim_media_probe(String(cString: buf), &i) != 0, i.width > 0, i.height > 0 {
                let sc = max(i.width, i.height) > 1280 ? 1280 / max(i.width, i.height) : 1
                s = CGSize(width: (i.width * sc / 2).rounded() * 2, height: (i.height * sc / 2).rounded() * 2)
            }
        }
        _size = s
        return s
    }
}

/// Owns a host image handle for CGImages made from pixels (frees it with the last CGImage).
final class _ISIMImageOwner: NSObject {
    let handle: Int32
    init(_ h: Int32) { handle = h }
    deinit { isim_image_free(handle) }
}
/// A CGImage of tightly packed premultiplied BGRA pixels. Call on the main thread (host images are UI-thread objects).
func _cgImageFromBGRA(_ px: UnsafeRawPointer, width w: Int, height h: Int) -> CGImage? {
    let hd = isim_image_create_bgra(Int32(w), Int32(h))
    guard hd > 0 else { return nil }
    isim_image_update_bgra(hd, px.assumingMemoryBound(to: UInt8.self), Int32(w), Int32(h))
    let owner = _ISIMImageOwner(hd)
    return isim_cg_image_create(hd, CGRect(x: 0, y: 0, width: w, height: h), Unmanaged.passUnretained(owner).toOpaque())
}
func _onMainSync<T>(_ body: () -> T) -> T {
    if Thread.isMainThread { return body() }
    return DispatchQueue.main.sync(execute: body)
}

open class AVCaptureDevice: NSObject, @unchecked Sendable {
    public struct DeviceType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let builtInWideAngleCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInWideAngleCamera")
        public static let builtInUltraWideCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInUltraWideCamera")
        public static let builtInTelephotoCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInTelephotoCamera")
        public static let builtInDualCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInDualCamera")
        public static let builtInDualWideCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInDualWideCamera")
        public static let builtInTripleCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInTripleCamera")
        public static let builtInTrueDepthCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInTrueDepthCamera")
        public static let builtInLiDARDepthCamera = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInLiDARDepthCamera")
        public static let microphone = DeviceType(rawValue: "AVCaptureDeviceTypeMicrophone")
        public static let continuityCamera = DeviceType(rawValue: "AVCaptureDeviceTypeContinuityCamera")
        public static let external = DeviceType(rawValue: "AVCaptureDeviceTypeExternal")
    }
    @objc public enum Position: Int, Sendable { case unspecified = 0, back = 1, front = 2 }
    @objc public enum FocusMode: Int, Sendable { case locked = 0, autoFocus, continuousAutoFocus }
    @objc public enum ExposureMode: Int, Sendable { case locked = 0, autoExpose, continuousAutoExposure, custom }
    @objc public enum WhiteBalanceMode: Int, Sendable { case locked = 0, autoWhiteBalance, continuousAutoWhiteBalance }
    @objc public enum FlashMode: Int, Sendable { case off = 0, on, auto }
    @objc public enum TorchMode: Int, Sendable { case off = 0, on, auto }

    /// A capture format (isim: one per camera, the simulated feed's size at 30 fps).
    public final class Format: NSObject, @unchecked Sendable {
        public let formatDescription: CMFormatDescription
        public let videoSupportedFrameRateRanges: [FrameRateRange]
        public var highResolutionStillImageDimensions: CMVideoDimensions { formatDescription.dimensions }
        public var supportedMaxPhotoDimensions: [CMVideoDimensions] { [formatDescription.dimensions] }
        public var videoMaxZoomFactor: CGFloat { 4 }
        public var videoFieldOfView: Float { 69.4 }
        public var isVideoHDRSupported: Bool { false }
        public var mediaType: AVMediaType { .video }
        init(size: CGSize) {
            formatDescription = CMFormatDescription(_video: Int(size.width), height: Int(size.height), pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            videoSupportedFrameRateRanges = [FrameRateRange(min: 1, max: 30)]
        }
    }
    public final class FrameRateRange: NSObject, @unchecked Sendable {
        public let minFrameRate: Float64, maxFrameRate: Float64
        init(min: Double, max: Double) { minFrameRate = min; maxFrameRate = max }
        public var minFrameDuration: CMTime { CMTime(value: 1, timescale: Int32(maxFrameRate)) }
        public var maxFrameDuration: CMTime { CMTime(value: 1, timescale: Int32(minFrameRate)) }
    }

    public final class DiscoverySession: NSObject, @unchecked Sendable {
        public let devices: [AVCaptureDevice]
        public init(deviceTypes: [DeviceType], mediaType: AVMediaType?, position: Position) {
            devices = (mediaType == nil || mediaType == .video) && deviceTypes.contains(.builtInWideAngleCamera)
                ? AVCaptureDevice._cameras.filter { position == .unspecified || $0.position == position } : []
        }
        public var supportedMultiCamDeviceSets: [Set<AVCaptureDevice>] { [] }
    }

    // MARK: the simulated cameras
    let _position: Position
    init(position: Position) { _position = position; super.init() }
    nonisolated(unsafe) static var _cache: [AVCaptureDevice]?
    static var _cameras: [AVCaptureDevice] {
        guard _CameraSource.available else { return [] }
        if let c = _cache { return c }
        let c = [AVCaptureDevice(position: .back), AVCaptureDevice(position: .front)]
        _cache = c
        return c
    }

    open class func `default`(for mediaType: AVMediaType) -> AVCaptureDevice? { mediaType == .video ? _cameras.first : nil }
    open class func `default`(_ deviceType: DeviceType, for mediaType: AVMediaType?, position: Position) -> AVCaptureDevice? {
        guard deviceType == .builtInWideAngleCamera, mediaType == nil || mediaType == .video else { return nil }
        return _cameras.first { position == .unspecified || $0.position == position }
    }
    open class func device(withUniqueID deviceUniqueID: String) -> AVCaptureDevice? { _cameras.first { $0.uniqueID == deviceUniqueID } }
    @available(*, deprecated) open class func devices(for mediaType: AVMediaType) -> [AVCaptureDevice] { mediaType == .video ? _cameras : [] }
    @available(*, deprecated) open class func devices() -> [AVCaptureDevice] { _cameras }
    open class var systemPreferredCamera: AVCaptureDevice? { _cameras.first }
    open class var userPreferredCamera: AVCaptureDevice? { get { _cameras.first } set {} }

    open var uniqueID: String { _position == .front ? "isim.camera.front" : "isim.camera.back" }
    open var modelID: String { "isim Simulated Camera" }
    open var manufacturer: String { "isim" }
    open var localizedName: String { _position == .front ? "Front Camera" : "Back Camera" }
    open var position: Position { _position }
    open var deviceType: DeviceType { .builtInWideAngleCamera }
    open var isConnected: Bool { _CameraSource.available }
    open var isSuspended: Bool { false }
    open var hasTorch: Bool { false }
    open var hasFlash: Bool { false }
    open var isTorchAvailable: Bool { false }
    open var isFlashAvailable: Bool { false }
    open func hasMediaType(_ mediaType: AVMediaType) -> Bool { mediaType == .video }
    open var formats: [Format] { [activeFormat] }
    open lazy var activeFormat: Format = Format(size: _CameraSource.size)
    open var activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
    open var activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
    // configuration (stored; the simulated feed does not change)
    open var focusMode: FocusMode = .continuousAutoFocus
    open var exposureMode: ExposureMode = .continuousAutoExposure
    open var whiteBalanceMode: WhiteBalanceMode = .continuousAutoWhiteBalance
    open var torchMode: TorchMode = .off
    open var flashMode: FlashMode = .off
    open var focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
    open var exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
    open var isFocusPointOfInterestSupported: Bool { true }
    open var isExposurePointOfInterestSupported: Bool { true }
    open var isSmoothAutoFocusEnabled = false
    open var isSubjectAreaChangeMonitoringEnabled = false
    open var videoZoomFactor: CGFloat = 1
    open var minAvailableVideoZoomFactor: CGFloat { 1 }
    open var maxAvailableVideoZoomFactor: CGFloat { 4 }
    open var isAdjustingFocus: Bool { false }
    open var isAdjustingExposure: Bool { false }
    open var lensPosition: Float { 0.5 }
    open func isFocusModeSupported(_ m: FocusMode) -> Bool { true }
    open func isExposureModeSupported(_ m: ExposureMode) -> Bool { m != .custom }
    open func isWhiteBalanceModeSupported(_ m: WhiteBalanceMode) -> Bool { true }
    open func isTorchModeSupported(_ m: TorchMode) -> Bool { m == .off }
    open func ramp(toVideoZoomFactor factor: CGFloat, withRate rate: Float) { videoZoomFactor = factor }
    open func cancelVideoZoomRamp() {}
    open func setTorchModeOn(level: Float) throws { throw AVError(.operationNotAllowed, reason: "the simulated camera has no torch") }
    var _locked = false
    open func lockForConfiguration() throws {
        guard isConnected else { throw AVError(.deviceNotConnected) }
        _locked = true
    }
    open func unlockForConfiguration() { _locked = false }

    // MARK: permission
    static func key(_ m: AVMediaType) -> String { m == .audio ? "microphone" : "camera" }
    open class func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        _Privacy.stored(key(mediaType)).flatMap { AVAuthorizationStatus(rawValue: $0) } ?? .notDetermined
    }
    open class func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping @Sendable (Bool) -> Void) {
        let s = authorizationStatus(for: mediaType)
        if s != .notDetermined { _Privacy.reply { handler(s == .authorized) }; return }
        let audio = mediaType == .audio
        guard let purpose = _Privacy.usage(audio ? "NSMicrophoneUsageDescription" : "NSCameraUsageDescription", "AVFoundation") else {
            _Privacy.reply { handler(false) }; return
        }
        _Privacy.onMain {
            if _pendingAccess[key(mediaType)] != nil { _pendingAccess[key(mediaType)]!.append(handler); return }
            _pendingAccess[key(mediaType)] = [handler]
            func answer(_ ok: Bool) {
                _Privacy.store(key(mediaType), (ok ? AVAuthorizationStatus.authorized : .denied).rawValue)
                NSLog("isim AVFoundation: %@ access %@ for %@", audio ? "microphone" : "camera", ok ? "allowed" : "denied", _Privacy.appName)
                let waiting = _pendingAccess.removeValue(forKey: key(mediaType)) ?? []
                for h in waiting { _Privacy.reply { h(ok) } }
            }
            if let sc = _Privacy.scripted(audio ? "MICROPHONE" : "CAMERA") { answer(!(sc == "deny" || sc == "denied" || sc == "no" || sc == "0")); return }
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access the \(audio ? "Microphone" : "Camera")", purpose,
                           [("Don’t Allow", .default), (_Privacy.osMajor >= 17 ? "Allow" : "OK", .default)]) { answer($0 == 1) }
        }
    }
    nonisolated(unsafe) static var _pendingAccess: [String: [@Sendable (Bool) -> Void]] = [:]
    open class func requestAccess(for mediaType: AVMediaType) async -> Bool {
        await withCheckedContinuation { k in requestAccess(for: mediaType) { k.resume(returning: $0) } }
    }
}

// MARK: - inputs, outputs, connections

open class AVCaptureInput: NSObject, @unchecked Sendable {
    public final class Port: NSObject, @unchecked Sendable {
        public let mediaType: AVMediaType
        public unowned let input: AVCaptureInput
        public var isEnabled = true
        init(_ t: AVMediaType, _ i: AVCaptureInput) { mediaType = t; input = i }
    }
    open var ports: [Port] { [] }
}
open class AVCaptureDeviceInput: AVCaptureInput, @unchecked Sendable {
    public let device: AVCaptureDevice
    lazy var _port = Port(.video, self)
    /// iOS: creating an input asks for camera access the first time (the session shows black until it is granted);
    /// a denied app gets AVError.applicationIsNotAuthorizedToUseDevice.
    public init(device: AVCaptureDevice) throws {
        self.device = device
        super.init()
        guard device.isConnected else { throw AVError(.deviceNotConnected) }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: throw AVError(.applicationIsNotAuthorizedToUseDevice)
        case .notDetermined: AVCaptureDevice.requestAccess(for: .video) { _ in }
        case .authorized: break
        }
    }
    open override var ports: [Port] { [_port] }
}

public final class AVCaptureConnection: NSObject, @unchecked Sendable {
    public let inputPorts: [AVCaptureInput.Port]
    public weak var output: AVCaptureOutput?
    public weak var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    public var isEnabled = true
    public var isActive: Bool { true }
    public var videoOrientation: AVCaptureVideoOrientation = .portrait
    public var isVideoOrientationSupported: Bool { true }
    public var videoRotationAngle: CGFloat = 0
    public func isVideoRotationAngleSupported(_ a: CGFloat) -> Bool { [0, 90, 180, 270].contains(a) }
    public var isVideoMirrored = false
    public var isVideoMirroringSupported: Bool { true }
    public var automaticallyAdjustsVideoMirroring = true
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off
    public var activeVideoStabilizationMode: AVCaptureVideoStabilizationMode { .off }
    public var isVideoStabilizationSupported: Bool { false }
    init(ports: [AVCaptureInput.Port], output: AVCaptureOutput?) { inputPorts = ports; self.output = output }
}
@objc public enum AVCaptureVideoOrientation: Int, Sendable { case portrait = 1, portraitUpsideDown, landscapeRight, landscapeLeft }
@objc public enum AVCaptureVideoStabilizationMode: Int, Sendable { case off = 0, standard, cinematic, cinematicExtended, auto = -1 }

open class AVCaptureOutput: NSObject, @unchecked Sendable {
    weak var _session: AVCaptureSession?
    var _connection: AVCaptureConnection?
    open var connections: [AVCaptureConnection] { _connection.map { [$0] } ?? [] }
    open func connection(with mediaType: AVMediaType) -> AVCaptureConnection? { mediaType == .video ? _connection : nil }
    func _attached() {}
}

// MARK: video data output

public protocol AVCaptureVideoDataOutputSampleBufferDelegate: NSObjectProtocol {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}
extension AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {}
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {}
}

open class AVCaptureVideoDataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var alwaysDiscardsLateVideoFrames = true
    open var videoSettings: [String: Any]! = [:]
    open var availableVideoPixelFormatTypes: [OSType] { [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_32BGRA] }
    open var availableVideoCodecTypes: [AVVideoCodecType] { [.h264, .hevc, .jpeg] }
    open private(set) weak var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    open private(set) var sampleBufferCallbackQueue: DispatchQueue?
    open func setSampleBufferDelegate(_ d: AVCaptureVideoDataOutputSampleBufferDelegate?, queue: DispatchQueue?) {
        sampleBufferDelegate = d; sampleBufferCallbackQueue = queue
    }
    open func recommendedVideoSettingsForAssetWriter(writingTo outputFileType: AVFileType) -> [String: Any]? {
        let s = _CameraSource.size
        return [AVVideoCodecKey: AVVideoCodecType.h264.rawValue, AVVideoWidthKey: Int(s.width), AVVideoHeightKey: Int(s.height)]
    }
    var _busy = false
    let _lock = NSLock()
    var _pixelFormat: OSType {
        let v = videoSettings?[kCVPixelBufferPixelFormatTypeKey as String]
        if let n = v as? NSNumber { return OSType(truncatingIfNeeded: n.int64Value) }
        if let u = v as? UInt32 { return u }
        if let i = v as? Int { return OSType(truncatingIfNeeded: i) }
        return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange     // the iOS default
    }
}

/// A pixel buffer in `format` made from tightly packed BGRA (BT.601 for the 4:2:0 formats).
func _pixelBuffer(fromBGRA px: UnsafePointer<UInt8>, width w: Int, height h: Int, format: OSType) -> CVPixelBuffer? {
    let f = [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange].contains(format) ? format : kCVPixelFormatType_32BGRA
    guard let b = CVBuffer(_width: w, height: h, format: f) else { return nil }
    if f == kCVPixelFormatType_32BGRA { b._setBGRA(px); return b }
    let full = f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    let yp = CVPixelBufferGetBaseAddressOfPlane(b, 0)!.assumingMemoryBound(to: UInt8.self), ybpr = CVPixelBufferGetBytesPerRowOfPlane(b, 0)
    let cp = CVPixelBufferGetBaseAddressOfPlane(b, 1)!.assumingMemoryBound(to: UInt8.self), cbpr = CVPixelBufferGetBytesPerRowOfPlane(b, 1)
    for y in 0..<h {
        for x in 0..<w {
            let p = px + (y * w + x) * 4
            let r = Double(p[2]), g = Double(p[1]), bl = Double(p[0])
            let l = 0.299 * r + 0.587 * g + 0.114 * bl
            yp[y * ybpr + x] = UInt8(max(0, min(255, (full ? l : 16 + l * 219 / 255).rounded())))
            if y % 2 == 0 && x % 2 == 0 {
                let cb = 128 + (bl - l) / 1.772 * (full ? 1 : 224.0 / 255), cr = 128 + (r - l) / 1.402 * (full ? 1 : 224.0 / 255)
                cp[(y / 2) * cbpr + (x / 2) * 2] = UInt8(max(0, min(255, cb.rounded())))
                cp[(y / 2) * cbpr + (x / 2) * 2 + 1] = UInt8(max(0, min(255, cr.rounded())))
            }
        }
    }
    return b
}

// MARK: photo output

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

open class AVCapturePhotoSettings: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static var _next: Int64 = 1
    public let uniqueID: Int64
    public let format: [String: Any]?
    open var flashMode: AVCaptureDevice.FlashMode = .off
    open var isHighResolutionPhotoEnabled = false
    open var isAutoStillImageStabilizationEnabled = true
    open var photoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .balanced
    open var maxPhotoDimensions = CMVideoDimensions(width: 0, height: 0)
    open var previewPhotoFormat: [String: Any]?
    open var isDepthDataDeliveryEnabled = false
    public override init() { uniqueID = AVCapturePhotoSettings._next; AVCapturePhotoSettings._next += 1; format = nil; super.init() }
    public init(format: [String: Any]?) { uniqueID = AVCapturePhotoSettings._next; AVCapturePhotoSettings._next += 1; self.format = format; super.init() }
    public convenience init(from settings: AVCapturePhotoSettings) { self.init(format: settings.format); flashMode = settings.flashMode }
    var _codec: AVVideoCodecType { (format?[AVVideoCodecKey] as? String).map(AVVideoCodecType.init(rawValue:)) ?? (format?[AVVideoCodecKey] as? AVVideoCodecType) ?? .hevc }
}
open class AVCaptureResolvedPhotoSettings: NSObject, @unchecked Sendable {
    public let uniqueID: Int64
    public let photoDimensions: CMVideoDimensions
    public var isFlashEnabled: Bool { false }
    public var expectedPhotoCount: Int { 1 }
    init(_ s: AVCapturePhotoSettings, _ size: CGSize) { uniqueID = s.uniqueID; photoDimensions = CMVideoDimensions(width: Int32(size.width), height: Int32(size.height)) }
}
open class AVCapturePhoto: NSObject, @unchecked Sendable {
    public let timestamp: CMTime
    public let resolvedSettings: AVCaptureResolvedPhotoSettings
    public let pixelBuffer: CVPixelBuffer?
    let _cg: CGImage?
    let _jpeg: Data?
    public var photoCount: Int { 1 }
    public var isRawPhoto: Bool { false }
    public var metadata: [String: Any] { ["{Exif}": ["LensModel": "isim Simulated Camera"], "Orientation": 1] }
    public var previewPixelBuffer: CVPixelBuffer? { nil }
    init(time: CMTime, settings: AVCaptureResolvedPhotoSettings, pixels: CVPixelBuffer?, image: CGImage?, jpeg: Data?) {
        timestamp = time; resolvedSettings = settings; pixelBuffer = pixels; _cg = image; _jpeg = jpeg
    }
    /// isim: JPEG data whatever codec was requested (adapted: no HEIF encoder).
    open func fileDataRepresentation() -> Data? { _jpeg }
    open func cgImageRepresentation() -> CGImage? { _cg }
    open func previewCGImageRepresentation() -> CGImage? { _cg }
}
public protocol AVCapturePhotoCaptureDelegate: NSObjectProtocol {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?)
}
extension AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {}
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {}
}

open class AVCapturePhotoOutput: AVCaptureOutput, @unchecked Sendable {
    @objc public enum QualityPrioritization: Int, Sendable { case speed = 1, balanced, quality }
    public override init() { super.init() }
    open var isHighResolutionCaptureEnabled = false
    open var maxPhotoQualityPrioritization: QualityPrioritization = .balanced
    // isim ABI: until 0.5 this property was typed Int; keep its getter/setter entry points for apps built then
    @usableFromInline @_silgen_name("$s12AVFoundation20AVCapturePhotoOutputC03maxC21QualityPrioritizationSivgTj")
    final func _abi_maxPhotoQualityPrioritizationInt() -> Int { maxPhotoQualityPrioritization.rawValue }
    @usableFromInline @_silgen_name("$s12AVFoundation20AVCapturePhotoOutputC03maxC21QualityPrioritizationSivsTj")
    final func _abi_setMaxPhotoQualityPrioritizationInt(_ v: Int) { maxPhotoQualityPrioritization = QualityPrioritization(rawValue: v) ?? .balanced }
    open var maxPhotoDimensions = CMVideoDimensions(width: 0, height: 0)
    open var availablePhotoCodecTypes: [AVVideoCodecType] { [.hevc, .jpeg] }
    open var availablePhotoPixelFormatTypes: [OSType] { [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] }
    open var supportedFlashModes: [AVCaptureDevice.FlashMode] { [.off] }
    open var isLivePhotoCaptureSupported: Bool { false }
    open var isLivePhotoCaptureEnabled = false
    open var isDepthDataDeliverySupported: Bool { false }
    open var isDepthDataDeliveryEnabled = false
    open var photoSettingsForSceneMonitoring: AVCapturePhotoSettings?
    open func supportedPhotoCodecTypes(for fileType: AVFileType) -> [AVVideoCodecType] { [.jpeg] }

    /// Captures the newest frame of the running session: JPEG data, a CGImage and (for pixel-format settings) a pixel buffer.
    open func capturePhoto(with settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate) {
        let size = _CameraSource.size
        let resolved = AVCaptureResolvedPhotoSettings(settings, size)
        let session = _session
        DispatchQueue.main.async {
            delegate.photoOutput(self, willBeginCaptureFor: resolved)
            delegate.photoOutput(self, willCapturePhotoFor: resolved)
            guard let s = session, s.isRunning, s._camera > 0, AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  let frame = s._newestFrame() else {
                let e = AVError(.sessionNotRunning)
                delegate.photoOutput(self, didFinishProcessingPhoto: AVCapturePhoto(time: .zero, settings: resolved, pixels: nil, image: nil, jpeg: nil), error: e)
                delegate.photoOutput(self, didFinishCaptureFor: resolved, error: e)
                return
            }
            delegate.photoOutput(self, didCapturePhotoFor: resolved)
            let (px, w, h, t) = frame
            let cg = px.withUnsafeBytes { _cgImageFromBGRA($0.baseAddress!, width: w, height: h) }
            var jpeg: Data?
            if let cg {
                var rect = CGRect.zero
                let hd = isim_cg_image_handle(cg, &rect)
                var out: UnsafeMutablePointer<UInt8>? = nil
                let n = isim_image_encode(hd, 1, 0.9, &out)
                if n > 0, let o = out { jpeg = Data(bytes: o, count: n); isim_image_bytes_free(o) }
            }
            var pb: CVPixelBuffer?
            if let f = settings.format?[kCVPixelBufferPixelFormatTypeKey as String] {
                let fmt = (f as? NSNumber).map { OSType(truncatingIfNeeded: $0.int64Value) } ?? (f as? UInt32) ?? kCVPixelFormatType_32BGRA
                pb = px.withUnsafeBufferPointer { _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: fmt) }
            }
            let photo = AVCapturePhoto(time: t, settings: resolved, pixels: pb, image: cg, jpeg: jpeg)
            delegate.photoOutput(self, didFinishProcessingPhoto: photo, error: nil)
            delegate.photoOutput(self, didFinishCaptureFor: resolved, error: nil)
        }
    }
}

// MARK: metadata output (QR codes, barcodes)

public protocol AVCaptureMetadataOutputObjectsDelegate: NSObjectProtocol {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection)
}
extension AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {}
}
open class AVMetadataObject: NSObject, @unchecked Sendable {
    public struct ObjectType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let qr = ObjectType(rawValue: "org.iso.QRCode")
        public static let ean13 = ObjectType(rawValue: "org.gs1.EAN-13")
        public static let ean8 = ObjectType(rawValue: "org.gs1.EAN-8")
        public static let upce = ObjectType(rawValue: "org.gs1.UPC-E")
        public static let code128 = ObjectType(rawValue: "com.intermec.Code128")
        public static let code39 = ObjectType(rawValue: "org.iso.Code39")
        public static let code39Mod43 = ObjectType(rawValue: "org.iso.Code39Mod43")
        public static let code93 = ObjectType(rawValue: "com.intermec.Code93")
        public static let interleaved2of5 = ObjectType(rawValue: "org.ansi.Interleaved2of5")
        public static let itf14 = ObjectType(rawValue: "org.gs1.ITF14")
        public static let codabar = ObjectType(rawValue: "org.iso.Codabar")
        public static let gs1DataBar = ObjectType(rawValue: "org.gs1.GS1DataBar")
        public static let pdf417 = ObjectType(rawValue: "org.iso.PDF417")
        public static let aztec = ObjectType(rawValue: "org.iso.Aztec")
        public static let dataMatrix = ObjectType(rawValue: "org.iso.DataMatrix")
        public static let microQR = ObjectType(rawValue: "org.iso.MicroQR")
        public static let face = ObjectType(rawValue: "face")
        public static let humanBody = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-human-body")
    }
    let _type: ObjectType
    var _bounds: CGRect
    public let time: CMTime
    public let duration: CMTime
    init(type: ObjectType, bounds: CGRect, time: CMTime) { _type = type; _bounds = bounds; self.time = time; duration = .invalid }
    public override init() { _type = .qr; _bounds = .zero; time = .invalid; duration = .invalid; super.init() }
    open var type: ObjectType { _type }
    open var bounds: CGRect { _bounds }
}
open class AVMetadataMachineReadableCodeObject: AVMetadataObject, @unchecked Sendable {
    let _string: String?
    var _corners: [CGPoint]
    init(type: ObjectType, bounds: CGRect, corners: [CGPoint], string: String?, time: CMTime) {
        _string = string; _corners = corners
        super.init(type: type, bounds: bounds, time: time)
    }
    public override init() { _string = nil; _corners = []; super.init() }
    open var stringValue: String? { _string }
    open var corners: [CGPoint] { _corners }
}

/// zbar symbology names -> AVFoundation / Vision types
enum _Symbology {
    static let table: [(String, AVMetadataObject.ObjectType)] = [
        ("QR-Code", .qr), ("EAN-13", .ean13), ("EAN-8", .ean8), ("UPC-E", .upce), ("UPC-A", .ean13), ("ISBN-13", .ean13), ("ISBN-10", .ean13),
        ("CODE-128", .code128), ("CODE-39", .code39), ("CODE-93", .code93), ("I2/5", .interleaved2of5), ("Codabar", .codabar),
        ("DataBar", .gs1DataBar), ("DataBar-Exp", .gs1DataBar), ("PDF417", .pdf417)]
    static func type(_ zbar: String) -> AVMetadataObject.ObjectType? { table.first { $0.0 == zbar }?.1 }
    static var supported: [AVMetadataObject.ObjectType] {
        isim_vision_available(1) != 0 ? [.qr, .ean13, .ean8, .upce, .code128, .code39, .code39Mod43, .code93, .interleaved2of5, .itf14, .codabar, .gs1DataBar, .pdf417] : []
    }
}
/// A barcode found by the host's zbar: pixel corner points and the decoded bytes.
public struct _ISIMBarcode: Sendable {
    public let symbology: String
    public let points: [CGPoint]
    public let payload: [UInt8]
    public var string: String? { String(validatingUTF8: payload.map { CChar(bitPattern: $0) } + [0]) ?? String(decoding: payload, as: UTF8.self) }
    /// scans tightly packed BGRA pixels; nil when the host has no zbar
    public static func scan(_ bgra: UnsafePointer<UInt8>, width: Int, height: Int) -> [_ISIMBarcode]? {
        guard let raw = isim_vision_barcodes(bgra, Int32(width), Int32(height), Int32(width * 4)) else { return nil }
        defer { isim_media_free(raw) }
        var out: [_ISIMBarcode] = []
        for line in String(cString: raw).split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard f.count >= 4 else { continue }
            let pts = f[2].split(separator: ";").compactMap { p -> CGPoint? in
                let xy = p.split(separator: ",").compactMap { Double($0) }
                return xy.count == 2 ? CGPoint(x: xy[0], y: xy[1]) : nil
            }
            var bytes: [UInt8] = []
            let hex = Array(f[3].utf8)
            var i = 0
            while i + 1 < hex.count {
                func v(_ c: UInt8) -> UInt8 { c >= 97 ? c - 87 : c - 48 }
                bytes.append(v(hex[i]) << 4 | v(hex[i + 1])); i += 2
            }
            out.append(_ISIMBarcode(symbology: String(f[0]), points: pts, payload: bytes))
        }
        return out
    }
}

open class AVCaptureMetadataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    /// isim: what the host can detect (needs libzbar), once the output is in a session with a camera input
    open var availableMetadataObjectTypes: [AVMetadataObject.ObjectType] { _session?._hasCamera == true ? _Symbology.supported : [] }
    open var metadataObjectTypes: [AVMetadataObject.ObjectType]! = [] {
        didSet {
            let bad = (metadataObjectTypes ?? []).filter { !availableMetadataObjectTypes.contains($0) }
            if !bad.isEmpty {
                NSLog("isim AVFoundation: unsupported metadata object types %@ (iOS raises NSInvalidArgumentException; available: %@)",
                      bad.map(\.rawValue).joined(separator: ", "), availableMetadataObjectTypes.map(\.rawValue).joined(separator: ", "))
            }
        }
    }
    open var rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    open private(set) weak var metadataObjectsDelegate: AVCaptureMetadataOutputObjectsDelegate?
    open private(set) var metadataObjectsCallbackQueue: DispatchQueue?
    open func setMetadataObjectsDelegate(_ objectsDelegate: AVCaptureMetadataOutputObjectsDelegate?, queue objectsCallbackQueue: DispatchQueue?) {
        metadataObjectsDelegate = objectsDelegate; metadataObjectsCallbackQueue = objectsCallbackQueue
    }
    var _lastCount = 0
    /// session thread: scans a frame and reports what it found (and once more when codes disappear)
    func _scan(_ px: UnsafePointer<UInt8>, _ w: Int, _ h: Int, _ t: CMTime) {
        guard let d = metadataObjectsDelegate, let types = metadataObjectTypes, !types.isEmpty, let conn = _connection else { return }
        guard let found = _ISIMBarcode.scan(px, width: w, height: h) else { return }
        var objs: [AVMetadataObject] = []
        for b in found {
            guard let type = _Symbology.type(b.symbology), types.contains(type) else { continue }
            let xs = b.points.map(\.x), ys = b.points.map(\.y)
            guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { continue }
            let bounds = CGRect(x: x0 / Double(w), y: y0 / Double(h), width: max(1, x1 - x0) / Double(w), height: max(1, y1 - y0) / Double(h))
            guard rectOfInterest.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { continue }
            let corners = b.points.count == 4 ? b.points.map { CGPoint(x: $0.x / Double(w), y: $0.y / Double(h)) }
                                              : [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.minY)]
            objs.append(AVMetadataMachineReadableCodeObject(type: type, bounds: bounds, corners: corners, string: b.string, time: t))
        }
        if objs.isEmpty && _lastCount == 0 { return }
        _lastCount = objs.count
        (metadataObjectsCallbackQueue ?? .main).async { d.metadataOutput(self, didOutput: objs, from: conn) }
    }
}

// MARK: movie file output

public protocol AVCaptureFileOutputRecordingDelegate: NSObjectProtocol {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection])
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?)
}
extension AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}
}
open class AVCaptureFileOutput: AVCaptureOutput, @unchecked Sendable {
    open var maxRecordedDuration: CMTime = .invalid
    open internal(set) var outputFileURL: URL?
    var _isRecording: Bool { _sink != nil }
    open var recordedDuration: CMTime { CMTime(seconds: Double(_frames) / 30, preferredTimescale: 600) }
    var _sink: _RawVideoSink?
    var _frames = 0
    weak var _delegate: AVCaptureFileOutputRecordingDelegate?
    open func startRecording(to outputFileURL: URL, recordingDelegate delegate: AVCaptureFileOutputRecordingDelegate) {
        guard _sink == nil else { return }
        let s = _CameraSource.size
        self.outputFileURL = outputFileURL; _delegate = delegate; _frames = 0
        _sink = _RawVideoSink(width: Int(s.width), height: Int(s.height))
        let conns = connections
        DispatchQueue.main.async { delegate.fileOutput(self, didStartRecordingTo: outputFileURL, from: conns) }
    }
    open func stopRecording() {
        guard let sink = _sink, let url = outputFileURL else { return }
        _sink = nil
        let d = _delegate, conns = connections
        DispatchQueue.global().async {
            let err = sink.finish(to: url, fileType: url.pathExtension.lowercased() == "mov" ? .mov : .mp4, fps: 30)
            DispatchQueue.main.async { d?.fileOutput(self, didFinishRecordingTo: url, from: conns, error: err) }
        }
    }
    func _record(_ px: UnsafePointer<UInt8>) {
        guard let s = _sink else { return }
        s.append(px, time: Double(_frames) / 30)
        _frames += 1
        if maxRecordedDuration.isNumeric, recordedDuration >= maxRecordedDuration { DispatchQueue.main.async { self.stopRecording() } }
    }
}
open class AVCaptureMovieFileOutput: AVCaptureFileOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var availableVideoCodecTypes: [AVVideoCodecType] { [.h264, .hevc] }
    /// isim ABI: declared here since isim 0.2.0 (on iOS it comes from AVCaptureFileOutput)
    open var isRecording: Bool { _isRecording }
}

// MARK: - session

open class AVCaptureSession: NSObject, @unchecked Sendable {
    public struct Preset: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let photo = Preset(rawValue: "AVCaptureSessionPresetPhoto")
        public static let high = Preset(rawValue: "AVCaptureSessionPresetHigh")
        public static let medium = Preset(rawValue: "AVCaptureSessionPresetMedium")
        public static let low = Preset(rawValue: "AVCaptureSessionPresetLow")
        public static let hd1280x720 = Preset(rawValue: "AVCaptureSessionPreset1280x720")
        public static let hd1920x1080 = Preset(rawValue: "AVCaptureSessionPreset1920x1080")
        public static let hd4K3840x2160 = Preset(rawValue: "AVCaptureSessionPreset3840x2160")
        public static let vga640x480 = Preset(rawValue: "AVCaptureSessionPreset640x480")
        public static let cif352x288 = Preset(rawValue: "AVCaptureSessionPreset352x288")
        public static let inputPriority = Preset(rawValue: "AVCaptureSessionPresetInputPriority")
    }
    public static let didStartRunningNotification = Notification.Name("AVCaptureSessionDidStartRunningNotification")
    public static let didStopRunningNotification = Notification.Name("AVCaptureSessionDidStopRunningNotification")
    public static let wasInterruptedNotification = Notification.Name("AVCaptureSessionWasInterruptedNotification")
    public static let interruptionEndedNotification = Notification.Name("AVCaptureSessionInterruptionEndedNotification")
    public static let runtimeErrorNotification = Notification.Name("AVCaptureSessionRuntimeErrorNotification")

    open var sessionPreset: Preset = .high
    open private(set) var inputs: [AVCaptureInput] = []
    open private(set) var outputs: [AVCaptureOutput] = []
    open private(set) var isRunning = false
    open var isInterrupted: Bool { false }
    open var automaticallyConfiguresApplicationAudioSession = true
    open var isMultitaskingCameraAccessSupported: Bool { false }
    open var isMultitaskingCameraAccessEnabled = false
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { key != "isRunning" && key != "running" }
    public override init() { super.init() }
    open func canSetSessionPreset(_ preset: Preset) -> Bool { preset != .hd4K3840x2160 }
    var _hasCamera: Bool { inputs.contains { $0 is AVCaptureDeviceInput } }
    open func canAddInput(_ input: AVCaptureInput) -> Bool { (input as? AVCaptureDeviceInput)?.device.isConnected == true && !_hasCamera }
    open func addInput(_ input: AVCaptureInput) {
        guard canAddInput(input) else {
            NSLog("isim AVFoundation: -[AVCaptureSession addInput:] cannot add this input (iOS raises an exception)"); return
        }
        inputs.append(input)
        _connectOutputs()
    }
    open func removeInput(_ input: AVCaptureInput) { inputs.removeAll { $0 === input }; _connectOutputs() }
    open func canAddOutput(_ output: AVCaptureOutput) -> Bool { !outputs.contains(output) }
    open func addOutput(_ output: AVCaptureOutput) {
        guard canAddOutput(output) else { return }
        outputs.append(output); output._session = self
        _connectOutputs()
    }
    open func removeOutput(_ output: AVCaptureOutput) { outputs.removeAll { $0 === output }; output._session = nil; output._connection = nil }
    open func addInputWithNoConnections(_ input: AVCaptureInput) { addInput(input) }
    open func addOutputWithNoConnections(_ output: AVCaptureOutput) { addOutput(output) }
    open func addConnection(_ c: AVCaptureConnection) {}
    open func canAddConnection(_ c: AVCaptureConnection) -> Bool { false }
    open var connections: [AVCaptureConnection] { outputs.compactMap(\._connection) }
    func _connectOutputs() {
        let ports = inputs.flatMap(\.ports)
        for o in outputs { o._connection = ports.isEmpty ? nil : AVCaptureConnection(ports: ports, output: o) }
    }
    open func beginConfiguration() {}
    open func commitConfiguration() {}

    // MARK: running
    var _camera: Int32 = 0
    var _width = 0, _height = 0
    var _generation = 0
    var _start = 0.0
    let _frameLock = NSLock()
    var _latest: [UInt8] = []
    var _latestTime = CMTime.zero
    weak var _previewLayer: AVCaptureVideoPreviewLayer?

    /// Starts the camera feed (blocking briefly, like iOS: call it off the main thread).
    open func startRunning() {
        guard !isRunning else { return }
        if _hasCamera {
            var w: Int32 = 0, h: Int32 = 0
            _camera = isim_camera_open(1280, 30, &w, &h)
            _width = Int(w); _height = Int(h)
            if _camera == 0 { NSLog("isim AVFoundation: the simulated camera could not start (see ISIM_CAMERA; needs ffmpeg)") }
        } else {
            NSLog("isim AVFoundation: capture session started with no inputs (no cameras on this device, like the Simulator; set ISIM_CAMERA for a simulated camera)")
        }
        willChangeValue(forKey: "running"); willChangeValue(forKey: "isRunning")
        isRunning = true
        didChangeValue(forKey: "running"); didChangeValue(forKey: "isRunning")
        _generation += 1
        _start = Date().timeIntervalSince1970
        if _camera > 0 {
            let gen = _generation
            Thread.detachNewThread { [weak self] in self?._loop(gen) }
        }
        NotificationCenter.default.post(name: AVCaptureSession.didStartRunningNotification, object: self)
    }
    open func stopRunning() {
        guard isRunning else { return }
        _generation += 1
        willChangeValue(forKey: "running"); willChangeValue(forKey: "isRunning")
        isRunning = false
        didChangeValue(forKey: "running"); didChangeValue(forKey: "isRunning")
        let cam = _camera
        _camera = 0
        if cam > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { isim_camera_close(cam) } }   // after the loop's last read
        for case let o as AVCaptureFileOutput in outputs where o._isRecording { o.stopRecording() }
        NotificationCenter.default.post(name: AVCaptureSession.didStopRunningNotification, object: self)
    }
    /// the newest frame, if the session has one (BGRA, width, height, time)
    func _newestFrame() -> ([UInt8], Int, Int, CMTime)? {
        _frameLock.lock(); defer { _frameLock.unlock() }
        return _latest.isEmpty ? nil : (_latest, _width, _height, _latestTime)
    }
    var _authorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    func _loop(_ gen: Int) {
        let cam = _camera, w = _width, h = _height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        var seq = 0, frames = 0, authorized = false
        while _generation == gen {
            let s = buf.withUnsafeMutableBufferPointer { isim_camera_frame(cam, $0.baseAddress, seq, 0.2) }
            guard s > 0 else { continue }
            seq = s
            if frames % 15 == 0 || !authorized { authorized = _authorized }
            guard authorized, _generation == gen else { continue }      // black (no frames) until access is granted
            let t = CMTime(seconds: Date().timeIntervalSince1970 - _start, preferredTimescale: 1_000_000_000)
            _frameLock.lock(); _latest = buf; _latestTime = t; _frameLock.unlock()
            frames += 1
            for o in outputs {
                if let v = o as? AVCaptureVideoDataOutput, let d = v.sampleBufferDelegate, let conn = v._connection, conn.isEnabled {
                    v._lock.lock(); let busy = v._busy; if !busy { v._busy = true }; v._lock.unlock()
                    guard let pb = buf.withUnsafeBufferPointer({ _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: v._pixelFormat) }) else { continue }
                    let sb = CMSampleBuffer(_imageBuffer: pb, presentationTime: t, duration: CMTime(value: 1, timescale: 30))
                    if busy && v.alwaysDiscardsLateVideoFrames {
                        (v.sampleBufferCallbackQueue ?? .main).async { d.captureOutput(v, didDrop: sb, from: conn) }
                        continue
                    }
                    (v.sampleBufferCallbackQueue ?? .main).async {
                        d.captureOutput(v, didOutput: sb, from: conn)
                        v._lock.lock(); v._busy = false; v._lock.unlock()
                    }
                } else if let m = o as? AVCaptureMetadataOutput, frames % 3 == 1 {          // ~10 scans a second
                    buf.withUnsafeBufferPointer { m._scan($0.baseAddress!, w, h, t) }
                } else if let f = o as? AVCaptureFileOutput, f._isRecording {
                    buf.withUnsafeBufferPointer { f._record($0.baseAddress!) }
                }
            }
        }
    }
}

// MARK: - preview layer

/// Shows the session's camera feed (redrawn every display frame while the session runs).
open class AVCaptureVideoPreviewLayer: CALayer {
    public override init() { super.init() }
    public convenience init(session: AVCaptureSession) { self.init(); self.session = session }
    public convenience init(sessionWithNoConnection session: AVCaptureSession) { self.init(session: session) }
    open var session: AVCaptureSession? {
        didSet {
            session?._previewLayer = self
            _connection = AVCaptureConnection(ports: session?.inputs.flatMap(\.ports) ?? [], output: nil)
            _connection?.videoPreviewLayer = self
            _CaptureTicker.shared.add(self)
        }
    }
    var _connection: AVCaptureConnection?
    open var connection: AVCaptureConnection? { _connection }
    open var videoGravity: AVLayerVideoGravity = .resizeAspect { didSet { setNeedsDisplay() } }
    open var isPreviewing: Bool { session?.isRunning == true && session!._camera > 0 }
    open func setSessionWithNoConnection(_ s: AVCaptureSession) { session = s }
    var _videoRect: CGRect {
        guard let s = session, s._width > 0 else { return .zero }
        return AVMakeRect(aspectRatio: CGSize(width: s._width, height: s._height), gravity: videoGravity, in: bounds)
    }
    open override func draw(in ctx: CGContext) {
        guard let s = session, s.isRunning, s._camera > 0, s._authorized else { return }
        let img = isim_camera_preview(s._camera)
        guard img > 0 else { return }
        let r = _videoRect, b = bounds
        isim_gfx_save()
        isim_gfx_clip_rounded(b.minX, b.minY, b.width, b.height, 0)
        if _connection?.isVideoMirrored == true { isim_gfx_translate(r.midX * 2, 0); isim_gfx_scale(-1, 1) }
        isim_image_draw(img, r.minX, r.minY, r.width, r.height, nil, 1)
        isim_gfx_restore()
    }
    // coordinate conversion: capture device / metadata coordinates are normalized (0...1) over the camera frame
    open func layerPointConverted(fromCaptureDevicePoint p: CGPoint) -> CGPoint {
        let r = _videoRect; return CGPoint(x: r.minX + p.x * r.width, y: r.minY + p.y * r.height)
    }
    open func captureDevicePointConverted(fromLayerPoint p: CGPoint) -> CGPoint {
        let r = _videoRect; guard r.width > 0, r.height > 0 else { return .zero }
        return CGPoint(x: (p.x - r.minX) / r.width, y: (p.y - r.minY) / r.height)
    }
    open func layerRectConverted(fromMetadataOutputRect r: CGRect) -> CGRect {
        let a = layerPointConverted(fromCaptureDevicePoint: r.origin), b = layerPointConverted(fromCaptureDevicePoint: CGPoint(x: r.maxX, y: r.maxY))
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }
    open func metadataOutputRectConverted(fromLayerRect r: CGRect) -> CGRect {
        let a = captureDevicePointConverted(fromLayerPoint: r.origin), b = captureDevicePointConverted(fromLayerPoint: CGPoint(x: r.maxX, y: r.maxY))
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }
    open func transformedMetadataObject(for o: AVMetadataObject) -> AVMetadataObject? {
        let b = layerRectConverted(fromMetadataOutputRect: o.bounds)
        if let c = o as? AVMetadataMachineReadableCodeObject {
            return AVMetadataMachineReadableCodeObject(type: c.type, bounds: b, corners: c.corners.map { layerPointConverted(fromCaptureDevicePoint: $0) }, string: c.stringValue, time: c.time)
        }
        return AVMetadataObject(type: o.type, bounds: b, time: o.time)
    }
}

/// Redraws preview layers once per display frame.
final class _CaptureTicker: NSObject {
    nonisolated(unsafe) static let shared = _CaptureTicker()
    final class Weak { weak var layer: AVCaptureVideoPreviewLayer?; init(_ l: AVCaptureVideoPreviewLayer) { layer = l } }
    var layers: [Weak] = []
    var link: CADisplayLink?
    func add(_ l: AVCaptureVideoPreviewLayer) {
        _onMainSync {
            layers.removeAll { $0.layer == nil || $0.layer === l }
            layers.append(Weak(l))
            if link == nil {
                let k = CADisplayLink(target: self, selector: #selector(tick))
                k.add(to: RunLoop.main, forMode: RunLoop.Mode.common.rawValue)
                link = k
            }
        }
    }
    @objc func tick() {
        layers.removeAll { $0.layer == nil }
        for w in layers where w.layer?.isPreviewing == true { w.layer?.setNeedsDisplay() }
        if layers.isEmpty { link?.invalidate(); link = nil }
    }
}
