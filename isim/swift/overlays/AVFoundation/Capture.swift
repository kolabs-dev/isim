// isim AVFoundation capture (self-authored, iOS API names): devices, inputs, connections, AVCaptureSession,
// AVCaptureMultiCamSession and AVCaptureVideoPreviewLayer. The outputs are in CaptureOutputs.swift (video and audio
// data, metadata, movie file, depth, synchronizer) and CapturePhoto.swift (photos, RAW, Live Photos, depth).
//
// Like the iOS Simulator there is no camera by default: AVCaptureDevice.default(for: .video) is nil. isim adds a
// simulated camera when ISIM_CAMERA is set (adapted):
//   ISIM_CAMERA=<image file>    the picture, delivered as a live 30 fps feed
//   ISIM_CAMERA=<video file>    the video, looped, in real time
//   ISIM_CAMERA=webcam[:/dev/videoN]   the host webcam through ffmpeg's v4l2 input (opened only when asked)
//   ISIM_CAMERA_FRONT=...       a different source for the front cameras (else they show ISIM_CAMERA)
//   ISIM_CAMERA_DEPTH=<image>   the scene's depth for depth-capable cameras: grey levels from black (5 m) to white
//                               (0.5 m), linear in disparity; without it the scene is a flat wall 1 m away
//   ISIM_CAMERA_OBJECTS=face:x,y,w,h;humanBody:...  what is in the picture (normalized rectangles), for the faces,
//                               bodies and salient objects AVCaptureMetadataOutput reports (no detector on the host)
// The cameras are those of a dual-camera iPhone: back wide-angle, ultra wide and the virtual dual wide camera (depth),
// front wide-angle and the TrueDepth camera (depth). They show the source upright (no sensor rotation); cameras on the
// same side share a feed. Zoom, torch, flash and exposure bias change the picture (digital zoom, brightness); focus and
// white balance are stored only. Frames are decoded by the host's ffmpeg (host_capture.c), at most 1280 px on the
// longest side (less for smaller session presets).
// The microphone is always there: AVCaptureDevice.default(for: .audio) records what ISIM_AUDIO_INPUT plays into it
// (silence without it), shared with AVAudioRecorder / AVAudioEngine / Audio Queues.
// Camera and microphone access go through the shared privacy prompt (remembered per app; ISIM_CAMERA_PERMISSION /
// ISIM_MICROPHONE_PERMISSION = allow|deny); nothing is delivered until access is granted.
import UIKit
import AudioToolbox
import isim_host

extension AVMediaType {
    public static let depthData = AVMediaType("dpth")     /* the rest: AVAsset.swift */
    public static let metadataObject = AVMediaType("mobj")
}

@objc public enum AVAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized }

public let AVErrorRecordingSuccessfullyFinishedKey = "AVErrorRecordingSuccessfullyFinishedKey"
public let AVErrorDeviceKey = "AVErrorDeviceKey"
public let AVErrorTimeKey = "AVErrorTimeKey"
public let AVErrorFileSizeKey = "AVErrorFileSizeKey"

public struct AVError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = -11800, outOfMemory = -11801, sessionNotRunning = -11803, deviceAlreadyUsedByAnotherSession = -11804,
             noDataCaptured = -11805, sessionConfigurationChanged = -11806, diskFull = -11807, deviceWasDisconnected = -11808,
             mediaChanged = -11809, maximumDurationReached = -11810, maximumFileSizeReached = -11811, mediaDiscontinuity = -11812,
             maximumNumberOfSamplesForFileFormatReached = -11813, deviceNotConnected = -11814, deviceInUseByAnotherApplication = -11815,
             deviceLockedForConfigurationByAnotherProcess = -11817, sessionWasInterrupted = -11818, mediaServicesWereReset = -11819,
             exportFailed = -11820, decodeFailed = -11821, invalidSourceMedia = -11822, fileAlreadyExists = -11823,
             fileFormatNotRecognized = -11828, fileFailedToParse = -11829, maximumStillImageCaptureRequestsExceeded = -11830,
             noImageAtTime = -11832, decoderNotFound = -11833, encoderNotFound = -11834, applicationIsNotAuthorizedToUseDevice = -11852,
             recordingAlreadyInProgress = -11859, unsupportedOutputSettings = -11861, operationNotAllowed = -11862,
             invalidVideoComposition = -11841, videoCompositorFailed = -11845, formatUnsupported = -11864, malformedDepth = -11865, sessionHardwareCostOverage = -11872
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
        case .maximumDurationReached: return "Recording Stopped"
        case .maximumFileSizeReached: return "Recording Stopped"
        case .sessionWasInterrupted: return "Recording Interrupted"
        default: return "The operation could not be completed"
        }
    }
    public var failureReason: String? { _info[NSLocalizedFailureReasonErrorKey] }
}

/// The capture clock: seconds of the host time clock (CLOCK_MONOTONIC, like CMClockGetHostTimeClock).
func _captureHostTime() -> Double { ProcessInfo.processInfo.systemUptime }
func _captureTime(_ seconds: Double) -> CMTime { CMTime(value: Int64((seconds * 1e9).rounded()), timescale: 1_000_000_000) }

/// The simulated camera sources (ISIM_CAMERA, ISIM_CAMERA_FRONT).
enum _CameraSource {
    static var kind: Int32 { isim_camera_source(nil, 0) }
    static var available: Bool { kind != 0 }
    static func available(_ p: AVCaptureDevice.Position) -> Bool { isim_camera_source_at(p == .front ? 1 : 0, nil, 0) != 0 }
    /// frame size the host will deliver for a source and longest side (probed once each, like host_capture.c's bounding)
    nonisolated(unsafe) static var _sizes: [String: CGSize] = [:]
    static let _lock = NSLock()
    static func size(_ p: AVCaptureDevice.Position = .back, maxSide: Int = 1280) -> CGSize {
        let key = "\(p.rawValue)/\(maxSide)"
        _lock.lock(); defer { _lock.unlock() }
        if let s = _sizes[key] { return s }
        let m = Double(maxSide)
        var s = CGSize(width: min(1280, m), height: (min(1280, m) * 9 / 16 / 2).rounded() * 2)
        var buf = [CChar](repeating: 0, count: 1024)
        if isim_camera_source_at(p == .front ? 1 : 0, &buf, 1024) != 3 {
            var i = isim_media_info()
            if isim_media_probe(String(cString: buf), &i) != 0, i.width > 0, i.height > 0 {
                let sc = max(i.width, i.height) > m ? m / max(i.width, i.height) : 1
                s = CGSize(width: max(2, (i.width * sc / 2).rounded() * 2), height: max(2, (i.height * sc / 2).rounded() * 2))
            }
        }
        _sizes[key] = s
        return s
    }
    static var size: CGSize { size(.back) }
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

/// Rotates (clockwise, in quarter turns) and mirrors tightly packed BGRA pixels.
func _transformBGRA(_ px: [UInt8], _ w: Int, _ h: Int, angle: CGFloat, mirror: Bool) -> ([UInt8], Int, Int) {
    let turns = ((Int((angle / 90).rounded()) % 4) + 4) % 4
    if turns == 0 && !mirror { return (px, w, h) }
    let ow = turns % 2 == 1 ? h : w, oh = turns % 2 == 1 ? w : h
    var out = [UInt8](repeating: 0, count: px.count)
    px.withUnsafeBytes { s in
        out.withUnsafeMutableBytes { d in
            let src = s.bindMemory(to: UInt32.self), dst = d.bindMemory(to: UInt32.self)
            for y in 0..<h {
                for x in 0..<w {
                    let sx = mirror ? w - 1 - x : x
                    let (dx, dy): (Int, Int)
                    switch turns {
                    case 1: (dx, dy) = (h - 1 - y, x)
                    case 2: (dx, dy) = (w - 1 - x, h - 1 - y)
                    case 3: (dx, dy) = (y, w - 1 - x)
                    default: (dx, dy) = (x, y)
                    }
                    dst[dy * ow + dx] = src[y * w + sx]
                }
            }
        }
    }
    return (out, ow, oh)
}

// MARK: - devices

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
        @available(*, deprecated, renamed: "microphone")
        public static let builtInMicrophone = DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInMicrophone")
        public static let continuityCamera = DeviceType(rawValue: "AVCaptureDeviceTypeContinuityCamera")
        public static let external = DeviceType(rawValue: "AVCaptureDeviceTypeExternal")
    }
    @objc public enum Position: Int, Sendable { case unspecified = 0, back = 1, front = 2 }
    @objc public enum FocusMode: Int, Sendable { case locked = 0, autoFocus, continuousAutoFocus }
    @objc public enum ExposureMode: Int, Sendable { case locked = 0, autoExpose, continuousAutoExposure, custom }
    @objc public enum WhiteBalanceMode: Int, Sendable { case locked = 0, autoWhiteBalance, continuousAutoWhiteBalance }
    @objc public enum FlashMode: Int, Sendable { case off = 0, on, auto }
    @objc public enum TorchMode: Int, Sendable { case off = 0, on, auto }
    @objc public enum AutoFocusRangeRestriction: Int, Sendable { case none = 0, near, far }
    @objc public enum AutoFocusSystem: Int, Sendable { case none = 0, contrastDetection, phaseDetection }
    @objc public enum MicrophoneMode: Int, Sendable { case standard = 0, wideSpectrum, voiceIsolation }
    @objc public enum CenterStageControlMode: Int, Sendable { case user = 0, app, cooperative }
    @objc public enum PrimaryConstituentDeviceSwitchingBehavior: Int, Sendable { case unsupported = 0, auto, restricted, locked }
    public struct WhiteBalanceGains: Equatable, Sendable {
        public var redGain: Float, greenGain: Float, blueGain: Float
        public init(redGain: Float, greenGain: Float, blueGain: Float) { self.redGain = redGain; self.greenGain = greenGain; self.blueGain = blueGain }
        public init() { self.init(redGain: 1, greenGain: 1, blueGain: 1) }
    }
    public struct WhiteBalanceTemperatureAndTintValues: Equatable, Sendable {
        public var temperature: Float, tint: Float
        public init(temperature: Float, tint: Float) { self.temperature = temperature; self.tint = tint }
    }
    public struct WhiteBalanceChromaticityValues: Equatable, Sendable {
        public var x: Float, y: Float
        public init(x: Float, y: Float) { self.x = x; self.y = y }
    }
    public static let currentExposureDuration = CMTime(value: 0, timescale: 0)
    public static let currentISO: Float = 0
    public static let currentExposureTargetBias: Float = .greatestFiniteMagnitude
    public static let currentLensPosition: Float = -1
    public static let currentWhiteBalanceGains = WhiteBalanceGains(redGain: -1, greenGain: -1, blueGain: -1)
    public static let wasConnectedNotification = Notification.Name("AVCaptureDeviceWasConnectedNotification")
    public static let wasDisconnectedNotification = Notification.Name("AVCaptureDeviceWasDisconnectedNotification")
    public static let subjectAreaDidChangeNotification = Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification")

    /// A capture format: the simulated feed's size at 30 fps (video), its depth formats, or the microphone's PCM.
    public final class Format: NSObject, @unchecked Sendable {
        public let formatDescription: CMFormatDescription
        public let videoSupportedFrameRateRanges: [FrameRateRange]
        let _depthFormats: [Format]
        public var highResolutionStillImageDimensions: CMVideoDimensions { formatDescription.dimensions }
        public var supportedMaxPhotoDimensions: [CMVideoDimensions] { [formatDescription.dimensions] }
        public var videoMaxZoomFactor: CGFloat { 4 }
        public var videoFieldOfView: Float { 69.4 }
        public var isVideoHDRSupported: Bool { false }
        public var mediaType: AVMediaType { formatDescription.mediaType == kCMMediaType_Audio ? .audio : _isDepth ? .depthData : .video }
        var _isDepth: Bool { [kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32, kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DisparityFloat32].contains(formatDescription.mediaSubType) }
        public var supportedDepthDataFormats: [Format] { _depthFormats }
        /// mattes come with depth (CaptureMattes.swift)
        public var isPortraitEffectsMatteStillImageDeliverySupported: Bool { !_depthFormats.isEmpty }
        public var isMultiCamSupported: Bool { formatDescription.mediaType == kCMMediaType_Video && !_isDepth }
        public var isVideoBinned: Bool { false }
        public var minISO: Float { 34 }
        public var maxISO: Float { 3264 }
        public var minExposureDuration: CMTime { CMTime(value: 14, timescale: 1_000_000) }
        public var maxExposureDuration: CMTime { CMTime(value: 1, timescale: 3) }
        public var isHighestPhotoQualitySupported: Bool { true }
        public var isPortraitEffectSupported: Bool { false }
        public var isCenterStageSupported: Bool { false }
        public var autoFocusSystem: AutoFocusSystem { .phaseDetection }
        public var videoMinZoomFactorForDepthDataDelivery: CGFloat { 1 }
        public var videoMaxZoomFactorForDepthDataDelivery: CGFloat { 4 }
        public var geometricDistortionCorrectedVideoFieldOfView: Float { videoFieldOfView }
        public var supportedVideoZoomFactorsForDepthDataDelivery: [CGFloat] { [1] }
        init(size: CGSize) {
            formatDescription = CMFormatDescription(_video: Int(size.width), height: Int(size.height), pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            videoSupportedFrameRateRanges = [FrameRateRange(min: 1, max: 30)]
            _depthFormats = []
        }
        init(size: CGSize, depth: Bool) {
            formatDescription = CMFormatDescription(_video: Int(size.width), height: Int(size.height), pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            videoSupportedFrameRateRanges = [FrameRateRange(min: 1, max: 30)]
            let ds = _DepthScene.size(for: size)
            _depthFormats = depth ? [kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32]
                .map { Format(depth: ds, type: $0) } : []
        }
        init(depth size: CGSize, type: OSType) {
            formatDescription = CMFormatDescription(_video: Int(size.width), height: Int(size.height), pixelFormat: type)
            videoSupportedFrameRateRanges = [FrameRateRange(min: 1, max: 30)]
            _depthFormats = []
        }
        init(audio asbd: AudioStreamBasicDescription) {
            formatDescription = CMFormatDescription(_audio: asbd)
            videoSupportedFrameRateRanges = []
            _depthFormats = []
        }
    }
    public final class FrameRateRange: NSObject, @unchecked Sendable {
        public let minFrameRate: Float64, maxFrameRate: Float64
        init(min: Double, max: Double) { minFrameRate = min; maxFrameRate = max }
        public var minFrameDuration: CMTime { CMTime(value: 1, timescale: Int32(maxFrameRate)) }
        public var maxFrameDuration: CMTime { CMTime(value: 1, timescale: Int32(minFrameRate)) }
    }
    public final class SystemPressureState: NSObject, @unchecked Sendable {
        public struct Level: RawRepresentable, Hashable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }
            public static let nominal = Level(rawValue: "nominal"), fair = Level(rawValue: "fair"), serious = Level(rawValue: "serious"),
                              critical = Level(rawValue: "critical"), shutdown = Level(rawValue: "shutdown")
        }
        public struct Factors: OptionSet, Sendable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
            public static let systemTemperature = Factors(rawValue: 1), peakPower = Factors(rawValue: 2), depthModuleTemperature = Factors(rawValue: 4),
                              cameraTemperature = Factors(rawValue: 8)
            @available(iOS 27.0, *) public static var batteryStress: Factors { Factors(rawValue: 16) }
        }
        let _level: Level, _factors: Factors
        init(level: Level = .nominal, factors: Factors = []) { _level = level; _factors = factors }
        /// isim: set by the `camerapressure LEVEL [factors]` script command (CaptureControls.swift)
        public var level: Level { _level }
        public var factors: Factors { _factors }
    }

    public final class DiscoverySession: NSObject, @unchecked Sendable {
        public let devices: [AVCaptureDevice]
        public init(deviceTypes: [DeviceType], mediaType: AVMediaType?, position: Position) {
            devices = AVCaptureDevice._all.filter { d in
                deviceTypes.contains { $0 == d.deviceType || ($0 == DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInMicrophone") && d._isMicrophone) }
                    && (mediaType == nil || d.hasMediaType(mediaType!)) && (position == .unspecified || d.position == position)
            }
        }
        /// sets of cameras a multi-cam session can run together: one back and one front camera, or two back cameras
        public var supportedMultiCamDeviceSets: [Set<AVCaptureDevice>] {
            let cams = devices.filter { !$0._isMicrophone }
            var sets: [Set<AVCaptureDevice>] = []
            for a in cams where a.position == .back { for b in cams where b.position == .front { sets.append([a, b]) } }
            let physicalBack = cams.filter { $0.position == .back && !$0.isVirtualDevice }
            if physicalBack.count >= 2 { sets.append(Set(physicalBack.prefix(2))) }
            return sets
        }
    }

    // MARK: the simulated devices
    let _position: Position
    let _type: DeviceType
    let _id: String, _name: String
    let _depth: Bool
    let _constituentIDs: [String]
    var _isMicrophone: Bool { _type == .microphone }
    init(position: Position) {
        _position = position; _type = .builtInWideAngleCamera
        _id = position == .front ? "isim.camera.front" : "isim.camera.back"
        _name = position == .front ? "Front Camera" : "Back Camera"
        _depth = false; _constituentIDs = []
        super.init()
    }
    init(_ type: DeviceType, _ position: Position, id: String, name: String, depth: Bool, constituents: [String] = []) {
        _position = position; _type = type; _id = id; _name = name; _depth = depth; _constituentIDs = constituents
        super.init()
    }
    nonisolated(unsafe) static var _cache: [String: [AVCaptureDevice]] = [:]
    static let _cacheLock = NSLock()
    /// every device of this simulated iPhone: the cameras whose source exists, and the microphone
    static var _all: [AVCaptureDevice] {
        _AVCaptureEvents.install()
        let back = _CameraSource.available(.back), front = _CameraSource.available(.front)
        let key = "\(back)\(front)"
        _cacheLock.lock(); defer { _cacheLock.unlock() }
        if let c = _cache[key] { return c }
        var c: [AVCaptureDevice] = []
        if back {
            c += [AVCaptureDevice(position: .back),
                  AVCaptureDevice(.builtInUltraWideCamera, .back, id: "isim.camera.back.ultrawide", name: "Back Ultra Wide Camera", depth: false),
                  AVCaptureDevice(.builtInDualWideCamera, .back, id: "isim.camera.back.dualwide", name: "Back Dual Wide Camera", depth: true,
                                  constituents: ["isim.camera.back.ultrawide", "isim.camera.back"])]
        }
        if front {
            c += [AVCaptureDevice(position: .front),
                  AVCaptureDevice(.builtInTrueDepthCamera, .front, id: "isim.camera.front.truedepth", name: "Front TrueDepth Camera", depth: true,
                                  constituents: ["isim.camera.front"])]
        }
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        c.append(AVCaptureDevice(.microphone, .unspecified, id: "isim.microphone", name: pad ? "iPad Microphone" : "iPhone Microphone", depth: false))
        _cache[key] = c
        return c
    }
    static var _cameras: [AVCaptureDevice] { _all.filter { !$0._isMicrophone } }

    open class func `default`(for mediaType: AVMediaType) -> AVCaptureDevice? {
        switch mediaType {
        case .video: return _cameras.first { $0.deviceType == .builtInWideAngleCamera && $0.position == .back } ?? _cameras.first
        case .audio: return _all.first { $0._isMicrophone }
        case .depthData: return _cameras.first { $0._depth }
        default: return nil
        }
    }
    open class func `default`(_ deviceType: DeviceType, for mediaType: AVMediaType?, position: Position) -> AVCaptureDevice? {
        DiscoverySession(deviceTypes: [deviceType], mediaType: mediaType, position: position).devices.first
    }
    open class func device(withUniqueID deviceUniqueID: String) -> AVCaptureDevice? { _all.first { $0.uniqueID == deviceUniqueID } }
    @available(*, deprecated) open class func devices(for mediaType: AVMediaType) -> [AVCaptureDevice] {
        _all.filter { $0.hasMediaType(mediaType) && ($0.deviceType == .builtInWideAngleCamera || $0._isMicrophone) }
    }
    @available(*, deprecated) open class func devices() -> [AVCaptureDevice] { _all.filter { $0.deviceType == .builtInWideAngleCamera || $0._isMicrophone } }
    open class var systemPreferredCamera: AVCaptureDevice? { _userPreferred ?? self.default(for: .video) }
    nonisolated(unsafe) static var _userPreferred: AVCaptureDevice?
    open class var userPreferredCamera: AVCaptureDevice? { get { _userPreferred ?? self.default(for: .video) } set { _userPreferred = newValue } }
    // iOS 15 microphone modes and Center Stage: a person chooses them in Control Center (stored here)
    nonisolated(unsafe) public static var preferredMicrophoneMode: MicrophoneMode = .standard
    open class var activeMicrophoneMode: MicrophoneMode { preferredMicrophoneMode }
    nonisolated(unsafe) public static var isCenterStageEnabled = false
    nonisolated(unsafe) public static var centerStageControlMode: CenterStageControlMode = .user
    open class var isPortraitEffectEnabled: Bool { false }

    open var uniqueID: String { _id }
    open var modelID: String { _isMicrophone ? "isim Simulated Microphone" : "isim Simulated Camera" }
    open var manufacturer: String { "isim" }
    open var localizedName: String { _name }
    open var position: Position { _position }
    open var deviceType: DeviceType {
        _isMicrophone && _Privacy.osMajor < 17 ? DeviceType(rawValue: "AVCaptureDeviceTypeBuiltInMicrophone") : _type
    }
    open var isConnected: Bool { _isMicrophone || _CameraSource.available(_position) }
    open var isSuspended: Bool { false }
    open var isVirtualDevice: Bool { !_constituentIDs.isEmpty }
    open var constituentDevices: [AVCaptureDevice] { _constituentIDs.compactMap { AVCaptureDevice.device(withUniqueID: $0) } }
    open var virtualDeviceSwitchOverVideoZoomFactors: [NSNumber] { _type == .builtInDualWideCamera ? [2] : [] }
    open var activePrimaryConstituent: AVCaptureDevice? { constituentDevices.last }
    open var primaryConstituentDeviceSwitchingBehavior: PrimaryConstituentDeviceSwitchingBehavior { isVirtualDevice && _type != .builtInTrueDepthCamera ? .auto : .unsupported }
    open func setPrimaryConstituentDeviceSwitchingBehavior(_ b: PrimaryConstituentDeviceSwitchingBehavior, restrictedSwitchingBehaviorConditions: UInt) {}
    open var displayVideoZoomFactorMultiplier: CGFloat { _type == .builtInDualWideCamera ? 0.5 : 1 }
    @objc open dynamic var systemPressureState: SystemPressureState { _isMicrophone ? SystemPressureState() : _CameraPressure.state }
    open var hasTorch: Bool { _position == .back }
    open var hasFlash: Bool { !_isMicrophone }                 // the front camera's is the Retina Flash (the screen)
    open var isTorchAvailable: Bool { hasTorch }
    open var isFlashAvailable: Bool { hasFlash }
    open var isTorchActive: Bool { torchMode == .on || (torchMode == .auto && _sceneIsDark) }
    open var maxAvailableTorchLevel: Float { 1 }
    open private(set) var torchLevel: Float = 0
    open var isLowLightBoostSupported: Bool { false }
    open var isLowLightBoostEnabled: Bool { false }
    open var automaticallyEnablesLowLightBoostWhenAvailable = false
    open var isCenterStageActive: Bool { false }
    open var isPortraitEffectActive: Bool { false }
    open var isGeometricDistortionCorrectionSupported: Bool { _type == .builtInUltraWideCamera || _type == .builtInDualWideCamera }
    open var isGeometricDistortionCorrectionEnabled = true
    open func hasMediaType(_ mediaType: AVMediaType) -> Bool {
        _isMicrophone ? mediaType == .audio : mediaType == .video || (mediaType == .depthData && _depth)
    }
    open var formats: [Format] { [activeFormat] }
    open lazy var activeFormat: Format = _isMicrophone ? Format(audio: _MicrophoneCapture.asbd) : Format(size: _CameraSource.size(_position), depth: _depth)
    open var activeDepthDataFormat: Format? {
        get { _depthFormat ?? activeFormat.supportedDepthDataFormats.first }
        set { _depthFormat = newValue }
    }
    var _depthFormat: Format?
    open var activeDepthDataMinFrameDuration = CMTime(value: 1, timescale: 30)
    open var activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
    open var activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
    open var activeColorSpace: AVCaptureColorSpace = .sRGB
    // configuration: focus and white balance are stored (the simulated feed does not change); zoom, torch and exposure
    // bias change the picture
    open var focusMode: FocusMode = .continuousAutoFocus { didSet { _adjust("adjustingFocus") } }
    open var exposureMode: ExposureMode = .continuousAutoExposure { didSet { _adjust("adjustingExposure"); _effectsChanged() } }
    open var whiteBalanceMode: WhiteBalanceMode = .continuousAutoWhiteBalance { didSet { _adjust("adjustingWhiteBalance") } }
    open var torchMode: TorchMode = .off {
        didSet { torchLevel = torchMode == .off ? 0 : (torchLevel > 0 ? torchLevel : 1); _effectsChanged() }
    }
    open var flashMode: FlashMode = .off
    open var focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) { didSet { _adjust("adjustingFocus") } }
    open var exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) { didSet { _adjust("adjustingExposure") } }
    open var isFocusPointOfInterestSupported: Bool { !_isMicrophone }
    open var isExposurePointOfInterestSupported: Bool { !_isMicrophone }
    open var autoFocusRangeRestriction: AutoFocusRangeRestriction = .none
    open var isAutoFocusRangeRestrictionSupported: Bool { true }
    open var isSmoothAutoFocusSupported: Bool { true }
    open var isSmoothAutoFocusEnabled = false
    open var automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
    open var isFaceDrivenAutoFocusEnabled = true
    open var automaticallyAdjustsVideoHDREnabled = true
    open var isVideoHDREnabled = false
    open var isSubjectAreaChangeMonitoringEnabled = false
    open var isLockingFocusWithCustomLensPositionSupported: Bool { true }
    open var isLockingWhiteBalanceWithCustomDeviceGainsSupported: Bool { true }
    open var minimumFocusDistance: Int { 120 }
    open var videoZoomFactor: CGFloat = 1 { didSet { _effectsChanged() } }
    open var minAvailableVideoZoomFactor: CGFloat { 1 }
    open var maxAvailableVideoZoomFactor: CGFloat { activeFormat.videoMaxZoomFactor }
    open private(set) var isRampingVideoZoom = false
    open private(set) var isAdjustingFocus = false
    open private(set) var isAdjustingExposure = false
    open private(set) var isAdjustingWhiteBalance = false
    open private(set) var lensPosition: Float = 0.5
    open private(set) var exposureDuration = CMTime(value: 1, timescale: 60)
    open private(set) var iso: Float = 100
    open private(set) var exposureTargetBias: Float = 0
    open var minExposureTargetBias: Float { -8 }
    open var maxExposureTargetBias: Float { 8 }
    open var exposureTargetOffset: Float { 0 }
    open var lensAperture: Float { _position == .front ? 1.9 : 1.6 }
    open var activeMaxExposureDuration = CMTime(value: 1, timescale: 3)
    open private(set) var deviceWhiteBalanceGains = WhiteBalanceGains()
    open var grayWorldDeviceWhiteBalanceGains: WhiteBalanceGains { WhiteBalanceGains() }
    open var maxWhiteBalanceGain: Float { 4 }
    open func isFocusModeSupported(_ m: FocusMode) -> Bool { !_isMicrophone }
    open func isExposureModeSupported(_ m: ExposureMode) -> Bool { !_isMicrophone }
    open func isWhiteBalanceModeSupported(_ m: WhiteBalanceMode) -> Bool { !_isMicrophone }
    open func isTorchModeSupported(_ m: TorchMode) -> Bool { m == .off || hasTorch }
    open func isFlashModeSupported(_ m: FlashMode) -> Bool { m == .off || hasFlash }
    open func ramp(toVideoZoomFactor factor: CGFloat, withRate rate: Float) {
        let target = max(minAvailableVideoZoomFactor, min(maxAvailableVideoZoomFactor, factor))
        _rampTimer?.invalidate()
        isRampingVideoZoom = true
        let step = pow(2, Double(max(0.1, rate)) / 30)                    // rate: powers of two per second
        DispatchQueue.main.async {
            self._rampTimer = Timer._isimScheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                let z = Double(self.videoZoomFactor)
                let next = target > z ? min(Double(target), z * step) : max(Double(target), z / step)
                self.videoZoomFactor = CGFloat(next)
                if next == Double(target) { t.invalidate(); self.isRampingVideoZoom = false }
            }
        }
    }
    var _rampTimer: Timer?
    open func cancelVideoZoomRamp() { _rampTimer?.invalidate(); _rampTimer = nil; isRampingVideoZoom = false }
    open func setTorchModeOn(level: Float) throws {
        guard hasTorch else { throw AVError(.operationNotAllowed, reason: "this camera has no torch") }
        guard level > 0, level <= 1 || level == Float.greatestFiniteMagnitude else { throw AVError(.operationNotAllowed, reason: "torch level must be in (0, 1]") }
        torchLevel = min(1, level)
        torchMode = .on
    }
    open func setExposureModeCustom(duration: CMTime, iso: Float, completionHandler handler: ((CMTime) -> Void)? = nil) {
        if duration != AVCaptureDevice.currentExposureDuration, duration.isNumeric {
            exposureDuration = CMTimeClampToRange(duration, range: CMTimeRange(start: activeFormat.minExposureDuration, end: activeFormat.maxExposureDuration))
        }
        if iso != AVCaptureDevice.currentISO { self.iso = max(activeFormat.minISO, min(activeFormat.maxISO, iso)) }
        exposureMode = .custom
        _completeAfterAdjustment(handler)
    }
    open func setExposureTargetBias(_ bias: Float, completionHandler handler: ((CMTime) -> Void)? = nil) {
        if bias != AVCaptureDevice.currentExposureTargetBias { exposureTargetBias = max(minExposureTargetBias, min(maxExposureTargetBias, bias)) }
        _effectsChanged()
        _completeAfterAdjustment(handler)
    }
    open func setFocusModeLocked(lensPosition: Float, completionHandler handler: ((CMTime) -> Void)? = nil) {
        if lensPosition != AVCaptureDevice.currentLensPosition { self.lensPosition = max(0, min(1, lensPosition)) }
        focusMode = .locked
        _completeAfterAdjustment(handler)
    }
    open func setWhiteBalanceModeLocked(with gains: WhiteBalanceGains, completionHandler handler: ((CMTime) -> Void)? = nil) {
        if gains != AVCaptureDevice.currentWhiteBalanceGains { deviceWhiteBalanceGains = gains }
        whiteBalanceMode = .locked
        _completeAfterAdjustment(handler)
    }
    open func chromaticityValues(for gains: WhiteBalanceGains) -> WhiteBalanceChromaticityValues { WhiteBalanceChromaticityValues(x: 0.3127, y: 0.329) }
    open func deviceWhiteBalanceGains(for v: WhiteBalanceChromaticityValues) -> WhiteBalanceGains { WhiteBalanceGains() }
    open func temperatureAndTintValues(for gains: WhiteBalanceGains) -> WhiteBalanceTemperatureAndTintValues { WhiteBalanceTemperatureAndTintValues(temperature: 6500, tint: 0) }
    open func deviceWhiteBalanceGains(for v: WhiteBalanceTemperatureAndTintValues) -> WhiteBalanceGains { WhiteBalanceGains() }
    /// the completion handlers run on the main queue with the time of the first frame with the new settings
    func _completeAfterAdjustment(_ handler: ((CMTime) -> Void)?) {
        guard let handler else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 30) { handler(_captureTime(_captureHostTime())) }
    }
    /// the brief focus / exposure / white balance adjustment a real camera makes (KVO-observable)
    func _adjust(_ key: String) {
        guard !_isMicrophone else { return }
        func set(_ v: Bool) {
            willChangeValue(forKey: key)
            switch key { case "adjustingFocus": isAdjustingFocus = v; case "adjustingExposure": isAdjustingExposure = v; default: isAdjustingWhiteBalance = v }
            didChangeValue(forKey: key)
        }
        set(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { set(false) }
    }
    /// brightness of the simulated picture: torch, exposure bias, custom exposure
    var _gain: Double {
        var g = pow(2, Double(exposureTargetBias))
        if exposureMode == .custom { g *= max(0.1, min(8, Double(iso) / 100 * exposureDuration.seconds * 60)) }
        if isTorchActive { g *= 1 + 0.6 * Double(max(torchLevel, 0.5)) }
        return g
    }
    var _sceneIsDark: Bool { _CameraFeed.luminance(_position) < 0.25 }
    func _effectsChanged() { _CameraFeed.updateEffects(for: self) }

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

    /// iOS 17: the rotation that keeps the horizon level. isim's simulated camera turns with the device (its picture
    /// is always upright), so both angles are 0 whatever the device orientation.
    open class RotationCoordinator: NSObject, @unchecked Sendable {
        public let device: AVCaptureDevice?
        public private(set) weak var previewLayer: CALayer?
        public init(device: AVCaptureDevice, previewLayer: CALayer?) { self.device = device; self.previewLayer = previewLayer }
        open var videoRotationAngleForHorizonLevelPreview: CGFloat { 0 }
        open var videoRotationAngleForHorizonLevelCapture: CGFloat { 0 }
    }
}
@objc public enum AVCaptureColorSpace: Int, Sendable { case sRGB = 0, P3_D65, HLG_BT2020, appleLog }

// MARK: - inputs, ports, connections

open class AVCaptureInput: NSObject, @unchecked Sendable {
    public final class Port: NSObject, @unchecked Sendable {
        public let mediaType: AVMediaType
        public unowned let input: AVCaptureInput
        public var isEnabled = true
        init(_ t: AVMediaType, _ i: AVCaptureInput) { mediaType = t; input = i }
        var _device: AVCaptureDevice? { (input as? AVCaptureDeviceInput)?.device }
        public var sourceDeviceType: AVCaptureDevice.DeviceType? { _device?.deviceType }
        public var sourceDevicePosition: AVCaptureDevice.Position { _device?.position ?? .unspecified }
        public var clock: CMClock? { .hostTimeClock }
        public var formatDescription: CMFormatDescription? {
            guard let d = _device else { return nil }
            return mediaType == .depthData ? d.activeDepthDataFormat?.formatDescription : mediaType == .metadataObject ? nil : d.activeFormat.formatDescription
        }
    }
    open var ports: [Port] { [] }
    var _noConnections = false
}
open class AVCaptureDeviceInput: AVCaptureInput, @unchecked Sendable {
    public let device: AVCaptureDevice
    lazy var _ports: [Port] = device._isMicrophone ? [Port(.audio, self)]
        : [Port(.video, self), Port(.metadataObject, self)] + (device._depth ? [Port(.depthData, self)] : [])
    /// iOS: creating an input asks for camera (microphone) access the first time (the session shows black / records
    /// silence until it is granted); a denied app gets AVError.applicationIsNotAuthorizedToUseDevice.
    public init(device: AVCaptureDevice) throws {
        self.device = device
        super.init()
        guard device.isConnected else { throw AVError(.deviceNotConnected) }
        let media: AVMediaType = device._isMicrophone ? .audio : .video
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .denied, .restricted: throw AVError(.applicationIsNotAuthorizedToUseDevice)
        case .notDetermined: AVCaptureDevice.requestAccess(for: media) { _ in }
        case .authorized: break
        }
    }
    public convenience init(_ device: AVCaptureDevice) throws { try self.init(device: device) }
    open override var ports: [Port] { _ports }
    open func ports(for mediaType: AVMediaType?, sourceDeviceType: AVCaptureDevice.DeviceType?, sourceDevicePosition: AVCaptureDevice.Position) -> [Port] {
        _ports.filter { p in (mediaType == nil || p.mediaType == mediaType) && (sourceDeviceType == nil || sourceDeviceType == device.deviceType || device.constituentDevices.contains { $0.deviceType == sourceDeviceType })
                             && (sourceDevicePosition == .unspecified || sourceDevicePosition == device.position) }
    }
    open var unifiedAutoExposureDefaultsEnabled = false
    open var videoMinFrameDurationOverride = CMTime.invalid
    open var multichannelAudioMode: Int = 0
}

/// A channel of an audio connection: levels of what the microphone hears (dBFS, updated as audio arrives).
public final class AVCaptureAudioChannel: NSObject, @unchecked Sendable {
    public internal(set) var averagePowerLevel: Float = -160
    public internal(set) var peakHoldLevel: Float = -160
    public var volume: Float = 1
    public var isEnabled = true
    var _peakTime = 0.0
}

public final class AVCaptureConnection: NSObject, @unchecked Sendable {
    public let inputPorts: [AVCaptureInput.Port]
    public weak var output: AVCaptureOutput?
    public weak var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    public var isEnabled = true
    public var isActive: Bool { inputPorts.allSatisfy { $0.isEnabled } && isEnabled }
    public var videoOrientation: AVCaptureVideoOrientation = .portrait
    public var isVideoOrientationSupported: Bool { _isVideo }
    public var videoRotationAngle: CGFloat = 0
    public func isVideoRotationAngleSupported(_ a: CGFloat) -> Bool { _isVideo && [0, 90, 180, 270].contains(a) }
    /// iOS mirrors a front camera's preview by default (automaticallyAdjustsVideoMirroring); data outputs are not mirrored
    public var isVideoMirrored: Bool {
        get { automaticallyAdjustsVideoMirroring && videoPreviewLayer != nil ? _device?.position == .front : _mirrored }
        set { _mirrored = newValue }
    }
    var _mirrored = false
    public var isVideoMirroringSupported: Bool { _isVideo }
    public var automaticallyAdjustsVideoMirroring = true
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off
    public var activeVideoStabilizationMode: AVCaptureVideoStabilizationMode { .off }
    public var isVideoStabilizationSupported: Bool { false }
    public var isCameraIntrinsicMatrixDeliverySupported: Bool { false }
    public var isCameraIntrinsicMatrixDeliveryEnabled = false
    public var videoMaxScaleAndCropFactor: CGFloat { 1 }
    public var videoScaleAndCropFactor: CGFloat = 1
    public let audioChannels: [AVCaptureAudioChannel]
    init(ports: [AVCaptureInput.Port], output: AVCaptureOutput?) {
        inputPorts = ports; self.output = output
        audioChannels = ports.contains { $0.mediaType == .audio } ? [AVCaptureAudioChannel()] : []
    }
    public convenience init(inputPorts ports: [AVCaptureInput.Port], output: AVCaptureOutput) { self.init(ports: ports, output: output) }
    public convenience init(inputPort port: AVCaptureInput.Port, videoPreviewLayer layer: AVCaptureVideoPreviewLayer) {
        self.init(ports: [port], output: nil)
        videoPreviewLayer = layer
    }
    var _device: AVCaptureDevice? { inputPorts.lazy.compactMap(\._device).first }
    var _isVideo: Bool { inputPorts.contains { $0.mediaType == .video || $0.mediaType == .depthData } }
    func _carries(_ m: AVMediaType) -> Bool { inputPorts.contains { $0.mediaType == m && $0.isEnabled } }
}
@objc public enum AVCaptureVideoOrientation: Int, Sendable { case portrait = 1, portraitUpsideDown, landscapeRight, landscapeLeft }
@objc public enum AVCaptureVideoStabilizationMode: Int, Sendable { case off = 0, standard, cinematic, cinematicExtended, previewOptimized, cinematicExtendedEnhanced, auto = -1 }

// MARK: - session

public let AVCaptureSessionInterruptionReasonKey = "AVCaptureSessionInterruptionReasonKey"
public let AVCaptureSessionErrorKey = "AVCaptureSessionErrorKey"

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
        public static let iFrame960x540 = Preset(rawValue: "AVCaptureSessionPresetiFrame960x540")
        public static let iFrame1280x720 = Preset(rawValue: "AVCaptureSessionPresetiFrame1280x720")
        public static let inputPriority = Preset(rawValue: "AVCaptureSessionPresetInputPriority")
        /// the longest side of the simulated feed for this preset (never more than the source)
        var _maxSide: Int {
            switch self {
            case .low: return 192
            case .cif352x288: return 352
            case .medium: return 480
            case .vga640x480: return 640
            case .iFrame960x540: return 960
            case .hd1920x1080, .hd4K3840x2160: return 1920
            default: return 1280
            }
        }
    }
    @objc public enum InterruptionReason: Int, Sendable {
        case videoDeviceNotAvailableInBackground = 1, audioDeviceInUseByAnotherClient, videoDeviceInUseByAnotherClient,
             videoDeviceNotAvailableWithMultipleForegroundApps, videoDeviceNotAvailableDueToSystemPressure, sensitiveContentMitigationActivated
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
    open private(set) var isInterrupted = false
    open var automaticallyConfiguresApplicationAudioSession = true
    open var usesApplicationAudioSession = true
    open var automaticallyConfiguresCaptureDeviceForWideColor = true
    open var isMultitaskingCameraAccessSupported: Bool { false }
    open var isMultitaskingCameraAccessEnabled = false
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
        !["isRunning", "running", "isInterrupted", "interrupted"].contains(key)
    }
    /// the Camera Control's controls (CaptureControls.swift)
    var _controls: [AVCaptureControl] = []
    weak var _controlsDelegate: (any AVCaptureSessionControlsDelegate)?
    var _controlsQueue: DispatchQueue?
    var _pressureInterrupted = false
    public override init() {
        super.init()
        _AVCaptureEvents.install(); _AVCaptureEvents.track(self)
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(_isimBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(_isimForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    open func canSetSessionPreset(_ preset: Preset) -> Bool { preset != .hd4K3840x2160 }
    /// the clock of the capture timestamps: the host time clock
    open var synchronizationClock: CMClock? { .hostTimeClock }
    @available(*, deprecated, renamed: "synchronizationClock") open var masterClock: CMClock? { .hostTimeClock }

    var _maxCameras: Int { 1 }
    var _cameraInputs: [AVCaptureDeviceInput] { inputs.compactMap { $0 as? AVCaptureDeviceInput }.filter { !$0.device._isMicrophone } }
    var _micInputs: [AVCaptureDeviceInput] { inputs.compactMap { $0 as? AVCaptureDeviceInput }.filter { $0.device._isMicrophone } }
    var _hasCamera: Bool { !_cameraInputs.isEmpty }
    open func canAddInput(_ input: AVCaptureInput) -> Bool {
        guard let d = (input as? AVCaptureDeviceInput)?.device, d.isConnected, !inputs.contains(input) else { return false }
        if d._isMicrophone { return _micInputs.isEmpty }
        return _cameraInputs.count < _maxCameras && !_cameraInputs.contains { $0.device === d }
    }
    open func addInput(_ input: AVCaptureInput) {
        guard canAddInput(input) else {
            NSLog("isim AVFoundation: -[AVCaptureSession addInput:] cannot add this input (iOS raises an exception)"); return
        }
        inputs.append(input)
        _connectOutputs()
    }
    open func removeInput(_ input: AVCaptureInput) {
        inputs.removeAll { $0 === input }
        _manual.removeAll { c in c.inputPorts.contains { $0.input === input } }
        _connectOutputs()
    }
    open func canAddOutput(_ output: AVCaptureOutput) -> Bool { !outputs.contains(output) && output._session == nil }
    open func addOutput(_ output: AVCaptureOutput) {
        guard canAddOutput(output) else { return }
        outputs.append(output); output._session = self
        _connectOutputs()
    }
    open func removeOutput(_ output: AVCaptureOutput) {
        outputs.removeAll { $0 === output }; output._session = nil; output._connections = []
        _manual.removeAll { $0.output === output }
    }
    open func addInputWithNoConnections(_ input: AVCaptureInput) {
        guard canAddInput(input) else { NSLog("isim AVFoundation: -[AVCaptureSession addInputWithNoConnections:] cannot add this input"); return }
        input._noConnections = true
        inputs.append(input)
    }
    open func addOutputWithNoConnections(_ output: AVCaptureOutput) {
        guard canAddOutput(output) else { return }
        output._noConnections = true
        outputs.append(output); output._session = self
    }
    /// explicit connections (multi-cam): an input's ports to an output, or a camera port to a preview layer
    var _manual: [AVCaptureConnection] = []
    open func canAddConnection(_ c: AVCaptureConnection) -> Bool {
        guard c.inputPorts.allSatisfy({ p in inputs.contains { $0 === p.input } }) else { return false }
        if let o = c.output { return outputs.contains(o) && !o._connections.contains { $0 === c } && c.inputPorts.allSatisfy { o._accepts.contains($0.mediaType) } }
        return c.videoPreviewLayer != nil && c.inputPorts.allSatisfy { $0.mediaType == .video }
    }
    open func addConnection(_ c: AVCaptureConnection) {
        guard canAddConnection(c) else { NSLog("isim AVFoundation: -[AVCaptureSession addConnection:] cannot add this connection (iOS raises an exception)"); return }
        _manual.append(c)
        if let o = c.output { o._connections.append(c) }
        if let l = c.videoPreviewLayer { l._connection = c; l._attach(self) }
    }
    open func removeConnection(_ c: AVCaptureConnection) {
        _manual.removeAll { $0 === c }
        c.output?._connections.removeAll { $0 === c }
        if let l = c.videoPreviewLayer, l._connection === c { l._connection = nil }
    }
    open var connections: [AVCaptureConnection] { outputs.flatMap(\._connections) + _manual.filter { $0.videoPreviewLayer != nil } }
    /// implicit connections: each output gets the first port of every media type it takes
    func _connectOutputs() {
        let ports = inputs.filter { !$0._noConnections }.flatMap(\.ports)
        for o in outputs where !o._noConnections {
            let manual = o._connections.filter { c in _manual.contains { $0 === c } }
            var conns = manual
            for m in o._accepts {
                guard let p = ports.first(where: { $0.mediaType == m }) else { continue }
                if let old = o._connections.first(where: { c in !manual.contains { $0 === c } && c.inputPorts.first === p }) { conns.append(old) }
                else { conns.append(AVCaptureConnection(ports: [p], output: o)) }
            }
            o._connections = conns
        }
        _previewLayer?._reconnect()
    }
    open func beginConfiguration() {}
    open func commitConfiguration() { _connectOutputs() }
    /// iOS 16: the cost of the configured cameras (1.0 is the most a multi-cam session may use)
    open var hardwareCost: Float { Float(_cameraInputs.count) * (sessionPreset == .hd1920x1080 ? 0.45 : 0.35) }

    // MARK: running
    var _feeds: [_CameraFeed] = []
    var _generation = 0
    weak var _previewLayer: AVCaptureVideoPreviewLayer?
    var _audio: _MicrophoneCapture?
    /// isim ABI-internal: the back (or only) camera feed handle for the preview / photo paths
    var _camera: Int32 { _feeds.first?.handle ?? 0 }
    var _width: Int { _feeds.first?.width ?? 0 }
    var _height: Int { _feeds.first?.height ?? 0 }

    /// Starts the camera feeds and the microphone (blocking briefly, like iOS: call it off the main thread).
    open func startRunning() {
        guard !isRunning else { return }
        _generation += 1
        let gen = _generation
        var positions: [AVCaptureDevice.Position] = []
        for i in _cameraInputs where !positions.contains(i.device.position) { positions.append(i.device.position) }
        for p in positions {
            let device = _cameraInputs.first { $0.device.position == p }!.device
            let feed = _CameraFeed(position: p, device: device, session: self)
            if feed.open(maxSide: sessionPreset._maxSide) { _feeds.append(feed) }
            else { NSLog("isim AVFoundation: the simulated camera could not start (see ISIM_CAMERA; needs ffmpeg)") }
        }
        if !_micInputs.isEmpty { _audio = _MicrophoneCapture(session: self); _audio?.start() }
        if inputs.isEmpty {
            NSLog("isim AVFoundation: capture session started with no inputs (no cameras on this device, like the Simulator; set ISIM_CAMERA for a simulated camera)")
        }
        willChangeValue(forKey: "running"); willChangeValue(forKey: "isRunning")
        isRunning = true
        didChangeValue(forKey: "running"); didChangeValue(forKey: "isRunning")
        for f in _feeds { f.start(gen) }
        _CameraControl.started(self)
        NotificationCenter.default.post(name: AVCaptureSession.didStartRunningNotification, object: self)
        if _CameraPressure.state.level == .shutdown { _pressureChanged() }
    }
    open func stopRunning() {
        guard isRunning else { return }
        _generation += 1
        willChangeValue(forKey: "running"); willChangeValue(forKey: "isRunning")
        isRunning = false
        didChangeValue(forKey: "running"); didChangeValue(forKey: "isRunning")
        let feeds = _feeds
        _feeds = []
        for f in feeds { f.stop() }
        _audio?.stop(); _audio = nil
        for case let o as AVCaptureFileOutput in outputs where o._isRecording { o.stopRecording() }
        _CameraControl.stopped(self)
        NotificationCenter.default.post(name: AVCaptureSession.didStopRunningNotification, object: self)
    }
    /// the newest frame of the camera an output's connection uses (BGRA, width, height, time)
    func _newestFrame(for c: AVCaptureConnection? = nil) -> ([UInt8], Int, Int, CMTime)? {
        let pos = c?._device?.position
        guard let f = _feeds.first(where: { pos == nil || $0.position == pos }), let fr = f.latest() else { return nil }
        return (fr.px, fr.w, fr.h, fr.time)
    }
    func _feed(for c: AVCaptureConnection?) -> _CameraFeed? {
        let pos = c?._device?.position
        return _feeds.first { pos == nil || $0.position == pos }
    }
    var _authorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    // MARK: interruptions (the app in the background cannot use the camera)
    @objc func _isimBackground() {
        guard isRunning, _hasCamera, !isInterrupted else { return }
        willChangeValue(forKey: "interrupted"); willChangeValue(forKey: "isInterrupted")
        isInterrupted = true
        didChangeValue(forKey: "interrupted"); didChangeValue(forKey: "isInterrupted")
        for f in _feeds { f.paused = true }
        NSLog("isim AVFoundation: capture session interrupted (app in the background)")
        NotificationCenter.default.post(name: AVCaptureSession.wasInterruptedNotification, object: self,
                                        userInfo: [AVCaptureSessionInterruptionReasonKey: InterruptionReason.videoDeviceNotAvailableInBackground.rawValue])
        for case let o as AVCaptureFileOutput in outputs where o._isRecording { o._stop(error: _avNSError(.sessionWasInterrupted, "the app went to the background")) }
    }
    /// system pressure at shutdown interrupts the camera until the pressure eases (like iOS)
    func _pressureChanged() {
        let shutdown = _CameraPressure.state.level == .shutdown
        if shutdown, isRunning, _hasCamera, !isInterrupted {
            _pressureInterrupted = true
            willChangeValue(forKey: "interrupted"); willChangeValue(forKey: "isInterrupted")
            isInterrupted = true
            didChangeValue(forKey: "interrupted"); didChangeValue(forKey: "isInterrupted")
            for f in _feeds { f.paused = true }
            NSLog("isim AVFoundation: capture session interrupted (system pressure)")
            NotificationCenter.default.post(name: AVCaptureSession.wasInterruptedNotification, object: self,
                                            userInfo: [AVCaptureSessionInterruptionReasonKey: InterruptionReason.videoDeviceNotAvailableDueToSystemPressure.rawValue,
                                                       AVCaptureSessionInterruptionSystemPressureStateKey: _CameraPressure.state])
            for case let o as AVCaptureFileOutput in outputs where o._isRecording { o._stop(error: _avNSError(.sessionWasInterrupted, "system pressure")) }
        } else if !shutdown, _pressureInterrupted {
            _pressureInterrupted = false
            _isimForeground()
        }
    }
    @objc func _isimForeground() {
        guard isInterrupted, !_pressureInterrupted else { return }
        willChangeValue(forKey: "interrupted"); willChangeValue(forKey: "isInterrupted")
        isInterrupted = false
        didChangeValue(forKey: "interrupted"); didChangeValue(forKey: "isInterrupted")
        for f in _feeds { f.paused = false }
        NotificationCenter.default.post(name: AVCaptureSession.interruptionEndedNotification, object: self)
    }

    // MARK: frame delivery (camera feed threads)
    func _deliver(_ frame: _Frame, from feed: _CameraFeed) {
        var synced: [ObjectIdentifier: (AVCaptureDataOutputSynchronizer, [AVCaptureOutput: AVCaptureSynchronizedData])] = [:]
        for o in outputs {
            for c in o._connections where c.isActive && c._device?.position == feed.position {
                let item = o._frame(frame, connection: c, feed: feed, synchronized: o._synchronizer != nil)
                if let s = o._synchronizer, let item {
                    var e = synced[ObjectIdentifier(s)] ?? (s, [:])
                    e.1[o] = item
                    synced[ObjectIdentifier(s)] = e
                }
            }
        }
        for (_, (s, items)) in synced { s._deliver(items, time: frame.time) }
    }
    /// microphone audio (main thread): mono Int16 at 48 kHz starting at `time`
    func _deliverAudio(_ samples: [Int16], time: CMTime) {
        for o in outputs {
            for c in o._connections where c.isActive && c._carries(.audio) { o._audio(samples, time: time, connection: c) }
        }
        for f in _feeds { f.keepAudio(samples) }
    }
}

/// iOS 13: a session that runs several cameras at once (here: one back and one front, or two back cameras; cameras on
/// the same side share a feed). Connections are made by the app (addInputWithNoConnections, addConnection).
open class AVCaptureMultiCamSession: AVCaptureSession, @unchecked Sendable {
    open class var isMultiCamSupported: Bool { true }
    public override init() { super.init() }
    override var _maxCameras: Int { 3 }
    open var systemPressureCost: Float { Float(_cameraInputs.count) * 0.3 }
    open override var hardwareCost: Float { Float(_cameraInputs.count) * 0.4 }
}

// MARK: - camera feeds

/// One decoded frame of a camera feed.
final class _Frame: @unchecked Sendable {
    let px: [UInt8], w: Int, h: Int, time: CMTime, host: Double
    init(px: [UInt8], w: Int, h: Int, time: CMTime, host: Double) { self.px = px; self.w = w; self.h = h; self.time = time; self.host = host }
    /// half size (box filter) when wider than 960 px: Live Photo history (even dimensions, for 4:2:0 video)
    func reduced() -> _Frame {
        guard w > 960 else { return self }
        let ow = (w / 2) & ~1, oh = (h / 2) & ~1
        var out = [UInt8](repeating: 0, count: ow * oh * 4)
        px.withUnsafeBufferPointer { s in
            for y in 0..<oh {
                let r0 = 2 * y * w * 4, r1 = r0 + w * 4
                for x in 0..<ow {
                    let c = 8 * x, o = (y * ow + x) * 4
                    for k in 0..<4 {
                        let a = Int(s[r0 + c + k]) + Int(s[r0 + c + 4 + k])
                        let b = Int(s[r1 + c + k]) + Int(s[r1 + c + 4 + k])
                        out[o + k] = UInt8((a + b) / 4)
                    }
                }
            }
        }
        return _Frame(px: out, w: ow, h: oh, time: time, host: host)
    }
}

/// A running simulated camera (one per side of the device in use by a session).
final class _CameraFeed: @unchecked Sendable {
    let position: AVCaptureDevice.Position
    let device: AVCaptureDevice
    weak var session: AVCaptureSession?
    var handle: Int32 = 0, width = 0, height = 0
    var generation = 0
    var paused = false
    let lock = NSLock()
    var _latest: _Frame?
    /// Live Photos: the last 1.5 s of frames and audio while a photo output wants them
    var history: [_Frame] = []
    var audioHistory: [Int16] = []
    var keepHistory = false
    var listeners: [(_Frame) -> Bool] = []
    var audioListeners: [([Int16]) -> Bool] = []
    var mean: Double = 0.5
    init(position: AVCaptureDevice.Position, device: AVCaptureDevice, session: AVCaptureSession) {
        self.position = position; self.device = device; self.session = session
    }
    nonisolated(unsafe) static var running: [_CameraFeed] = []
    static let runningLock = NSLock()

    func open(maxSide: Int) -> Bool {
        var w: Int32 = 0, h: Int32 = 0
        handle = isim_camera_open_at(position == .front ? 1 : 0, Int32(maxSide), 30, &w, &h)
        width = Int(w); height = Int(h)
        guard handle > 0 else { return false }
        _CameraFeed.runningLock.lock(); _CameraFeed.running.append(self); _CameraFeed.runningLock.unlock()
        applyEffects()
        return true
    }
    func start(_ gen: Int) {
        generation = gen
        Thread.detachNewThread { [self] in loop(gen) }
    }
    func stop() {
        generation = -1
        _CameraFeed.runningLock.lock(); _CameraFeed.running.removeAll { $0 === self }; _CameraFeed.runningLock.unlock()
        let h = handle
        if h > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { isim_camera_close(h) } }   // after the loop's last read
    }
    func latest() -> _Frame? { lock.lock(); defer { lock.unlock() }; return _latest }
    func applyEffects() { if handle > 0 { isim_camera_set_effects(handle, Double(max(1, device.videoZoomFactor)), device._gain) } }
    static func updateEffects(for d: AVCaptureDevice) {
        runningLock.lock(); let feeds = running.filter { $0.position == d.position }; runningLock.unlock()
        for f in feeds where f.device === d || d.constituentDevices.contains(where: { $0 === f.device }) || f.device.constituentDevices.contains(where: { $0 === d }) {
            isim_camera_set_effects(f.handle, Double(max(1, d.videoZoomFactor)), d._gain)
        }
    }
    /// mean brightness (0...1) of a running camera's picture: auto flash and torch
    static func luminance(_ p: AVCaptureDevice.Position) -> Double {
        runningLock.lock(); defer { runningLock.unlock() }
        return running.first { $0.position == p }?.mean ?? 0.5
    }
    /// waits for frames: `f` returns false when it wants no more
    func listen(_ f: @escaping (_Frame) -> Bool) { lock.lock(); listeners.append(f); lock.unlock() }
    func listenAudio(_ f: @escaping ([Int16]) -> Bool) { lock.lock(); audioListeners.append(f); lock.unlock() }
    func keepAudio(_ s: [Int16]) {
        lock.lock()
        if keepHistory { audioHistory += s; if audioHistory.count > 72000 { audioHistory.removeFirst(audioHistory.count - 72000) } }
        let ls = audioListeners
        lock.unlock()
        let keep = ls.map { $0(s) }
        lock.lock(); audioListeners = zip(ls, keep).filter { $0.1 }.map(\.0) + audioListeners.dropFirst(ls.count); lock.unlock()
    }

    func loop(_ gen: Int) {
        let cam = handle, w = width, h = height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        var seq = 0, frames = 0, authorized = false
        while generation == gen {
            let s = buf.withUnsafeMutableBufferPointer { isim_camera_frame(cam, $0.baseAddress, seq, 0.2) }
            guard s > 0 else { continue }
            seq = s
            if frames % 15 == 0 || !authorized { authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
            guard authorized, generation == gen, !paused, let session else { continue }      // black (no frames) until access is granted
            let host = _captureHostTime()
            let frame = _Frame(px: buf, w: w, h: h, time: _captureTime(host), host: host)
            frames += 1
            if frames % 15 == 1 {
                var sum = 0, n = 0
                buf.withUnsafeBufferPointer { p in var i = 0; while i + 2 < p.count { sum += Int(p[i]) * 29 + Int(p[i + 1]) * 150 + Int(p[i + 2]) * 77; n += 1; i += 4 * 97 } }
                mean = Double(sum) / Double(max(1, n)) / 256 / 255
            }
            lock.lock()
            _latest = frame
            keepHistory = session.outputs.contains { ($0 as? AVCapturePhotoOutput)?.isLivePhotoCaptureEnabled == true }
            if keepHistory { history.append(frame.reduced()); if history.count > 45 { history.removeFirst(history.count - 45) } }
            else if !history.isEmpty { history = []; audioHistory = [] }
            let ls = listeners
            lock.unlock()
            if !ls.isEmpty {
                let keep = ls.map { $0(frame) }
                lock.lock(); listeners = zip(ls, keep).filter { $0.1 }.map(\.0) + listeners.dropFirst(ls.count); lock.unlock()
            }
            session._deliver(frame, from: self)
        }
    }
}

// MARK: - preview layer

/// Shows the session's camera feed (redrawn every display frame while the session runs).
open class AVCaptureVideoPreviewLayer: CALayer {
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public override init(layer: Any) { super.init(layer: layer) }
    public convenience init(session: AVCaptureSession) { self.init(); self.session = session }
    public convenience init(sessionWithNoConnection session: AVCaptureSession) {
        self.init()
        _noConnection = true
        self.session = session
    }
    var _noConnection = false
    open var session: AVCaptureSession? {
        didSet {
            session?._previewLayer = self
            _reconnect()
            _CaptureTicker.shared.add(self)
        }
    }
    func _attach(_ s: AVCaptureSession) {
        if session !== s { _noConnection = true; session = s }
    }
    func _reconnect() {
        guard !_noConnection else { return }
        let port = session?._cameraInputs.first?.ports.first { $0.mediaType == .video }
        if let c = _connection, c.inputPorts.first === port, port != nil { return }
        _connection = AVCaptureConnection(ports: port.map { [$0] } ?? [], output: nil)
        _connection?.videoPreviewLayer = self
    }
    var _connection: AVCaptureConnection?
    open var connection: AVCaptureConnection? { _connection }
    open var videoGravity: AVLayerVideoGravity = .resizeAspect { didSet { setNeedsDisplay() } }
    var _feed: _CameraFeed? { session?._feed(for: _connection) }
    open var isPreviewing: Bool { session?.isRunning == true && _feed != nil && _connection?.isEnabled != false }
    open func setSessionWithNoConnection(_ s: AVCaptureSession) { _noConnection = true; session = s }
    var _videoRect: CGRect {
        guard let f = _feed, f.width > 0 else { return .zero }
        return AVMakeRect(aspectRatio: CGSize(width: f.width, height: f.height), gravity: videoGravity, in: bounds)
    }
    open override func draw(in ctx: CGContext) {
        guard let s = session, s.isRunning, !s.isInterrupted, let f = _feed, s._authorized, _connection?.isEnabled != false else { return }
        let img = isim_camera_preview(f.handle)
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
        return o._copy(bounds: b)
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
                let k = CADisplayLink(_isimWeakTarget: self, selector: #selector(tick))
                k.add(to: RunLoop.main, forMode: .common)
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
