// AVCaptureDevice: the rest of the device API (issue #876, part 1). Rectangles of interest, reaction effects, video
// effects state (Center Stage, Studio Light, background replacement, Edge Light), exposure signals, lens aperture
// control, dynamic aspect ratios, lens smudge detection, cinematic video focus, Smart Framing, constituent device
// switching and the format's capability flags.
//
// Adapted over isim's simulated cameras: settings are stored and reported back, the simulated picture is not changed
// by them (no reaction animations, no background replacement), and the user-controlled video effects (Control Center)
// are off unless set by the `videoeffect` script command. Formats report what a recent iPhone's wide camera supports.
import Foundation
import CoreMedia
import CoreGraphics
import UIKit

// MARK: - types used by the device

/// a reaction effect (iOS 17): a gesture or performEffect(for:) shows its animation over the video
public struct AVCaptureReactionType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let thumbsUp = AVCaptureReactionType(rawValue: "thumbsUp.fill")
    public static let thumbsDown = AVCaptureReactionType(rawValue: "thumbsDown.fill")
    public static let balloons = AVCaptureReactionType(rawValue: "balloons")
    public static let heart = AVCaptureReactionType(rawValue: "heart")
    public static let fireworks = AVCaptureReactionType(rawValue: "fireworks")
    public static let rain = AVCaptureReactionType(rawValue: "rain")
    public static let confetti = AVCaptureReactionType(rawValue: "confetti")
    public static let lasers = AVCaptureReactionType(rawValue: "lasers")
    /// the SF Symbol that shows the reaction
    public var systemImageName: String {
        switch self {
        case .thumbsUp: return "hand.thumbsup.fill"
        case .thumbsDown: return "hand.thumbsdown.fill"
        case .balloons: return "balloon.2.fill"
        case .heart: return "heart.fill"
        case .fireworks: return "fireworks"
        case .rain: return "cloud.rain.fill"
        case .confetti: return "party.popper.fill"
        case .lasers: return "laser.burst"
        default: return "questionmark"
        }
    }
    static let all: [AVCaptureReactionType] = [.thumbsUp, .thumbsDown, .balloons, .heart, .fireworks, .rain, .confetti, .lasers]
}

/// a reaction effect in progress: its type and when it started and ends (an invalid end while it is still running)
@objc(AVCaptureReactionEffectState) public final class AVCaptureReactionEffectState: NSObject, @unchecked Sendable {
    public let reactionType: AVCaptureReactionType
    public let startTime: CMTime
    public internal(set) var endTime: CMTime
    init(_ type: AVCaptureReactionType, start: CMTime, end: CMTime) { reactionType = type; startTime = start; endTime = end }
}

/// what the camera's auto exposure takes into account (iOS 27)
@available(iOS 27.0, *)
public struct AVCaptureDeviceExposureSignal: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let subjectMotion = AVCaptureDeviceExposureSignal(rawValue: "AVCaptureDeviceExposureSignalSubjectMotion")
    public static let flicker = AVCaptureDeviceExposureSignal(rawValue: "AVCaptureDeviceExposureSignalFlicker")
    public static let groupPhoto = AVCaptureDeviceExposureSignal(rawValue: "AVCaptureDeviceExposureSignalGroupPhoto")
    public static let document = AVCaptureDeviceExposureSignal(rawValue: "AVCaptureDeviceExposureSignalDocument")
    public static let starburst = AVCaptureDeviceExposureSignal(rawValue: "AVCaptureDeviceExposureSignalStarburst")
}

/// whether the lens is smudged (iOS 26)
@available(iOS 26.0, *)
@objc public enum AVCaptureCameraLensSmudgeDetectionStatus: Int, Sendable { case disabled = 0, smudgeNotDetected, smudged, unknown }

/// why the scene is unsuited to a capture mode (iOS 26)
@available(iOS 26.0, *)
public struct AVCaptureSceneMonitoringStatus: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let notEnoughLight = AVCaptureSceneMonitoringStatus(rawValue: "AVCaptureSceneMonitoringStatusNotEnoughLight")
}

/// why a spatial video would be uncomfortable to watch (iOS 18)
@available(iOS 18.0, *)
public struct AVSpatialCaptureDiscomfortReason: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let notEnoughLight = AVSpatialCaptureDiscomfortReason(rawValue: "AVSpatialCaptureDiscomfortReasonNotEnoughLight")
    public static let subjectTooClose = AVSpatialCaptureDiscomfortReason(rawValue: "AVSpatialCaptureDiscomfortReasonSubjectTooClose")
}

/// a framing Smart Framing can recommend: an aspect ratio and a zoom factor (iOS 26)
@available(iOS 26.0, *)
@objc(AVCaptureFraming) public final class AVCaptureFraming: NSObject, @unchecked Sendable {
    public let aspectRatio: AVCaptureDevice.AspectRatio
    public let zoomFactor: Float
    init(_ ratio: AVCaptureDevice.AspectRatio, _ zoom: Float) { aspectRatio = ratio; zoomFactor = zoom }
    public override func isEqual(_ o: Any?) -> Bool { (o as? AVCaptureFraming).map { $0.aspectRatio == aspectRatio && $0.zoomFactor == zoomFactor } ?? false }
    public override var hash: Int { aspectRatio.hashValue ^ zoomFactor.hashValue }
}

/// recommends a framing for the people in view (iOS 26). isim's simulated scene declares its people
/// (ISIM_CAMERA_OBJECTS): one face or body recommends the widest supported framing at 1x, more people zoom out.
@available(iOS 26.0, *)
@objc(AVCaptureSmartFramingMonitor) public final class AVCaptureSmartFramingMonitor: NSObject, @unchecked Sendable {
    weak var _device: AVCaptureDevice?
    init(_ d: AVCaptureDevice) { _device = d }
    public var supportedFramings: [AVCaptureFraming] {
        [AVCaptureFraming(.ratio16x9, 1), AVCaptureFraming(.ratio4x3, 1), AVCaptureFraming(.ratio1x1, 1), AVCaptureFraming(.ratio4x3, 0.5)]
    }
    public var enabledFramings: [AVCaptureFraming] = []
    @objc public private(set) dynamic var isMonitoring = false
    @objc public private(set) dynamic var recommendedFraming: AVCaptureFraming?
    public func startMonitoring() throws {
        guard _device?.activeFormat.isSmartFramingSupported == true else {
            throw AVError(.operationNotAllowed, reason: "the active format does not support Smart Framing")
        }
        isMonitoring = true
        let choices = enabledFramings.isEmpty ? supportedFramings : enabledFramings
        let people = _SceneObjects.declared.filter { $0.0 == .face || $0.0 == .humanBody }.count
        recommendedFraming = people > 1 ? choices.min { $0.zoomFactor < $1.zoomFactor } : choices.first
    }
    public func stopMonitoring() { isMonitoring = false }
}

// MARK: - per-device state

final class _AVCaptureDeviceExtras: @unchecked Sendable {
    var focusRect: CGRect?, exposureRect: CGRect?
    var centerStageRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var reactions: [AVCaptureReactionEffectState] = []
    var faceDrivenAutoExposure = true, adjustsFaceDrivenAutoExposure = true
    var globalToneMapping = false
    var autoVideoFrameRate = false
    var restrictedConditions: UInt = 0
    var fallbackConstituents: [AVCaptureDevice] = []
    var lockedConstituent: AVCaptureDevice?
    var smudgeEnabled = false, smudgeInterval = CMTime.zero
    var dynamicAspectRatio: String?
    var cinematicFocus: (CGPoint, Int)?
    var smartFraming: AnyObject?
    var exposureSignals: Set<String> = [], autoExposureSignals = true
    var adjustsISO = true, adjustsDuration = true, adjustsAperture = true, apertureRateLimit: Float = 0
    var aperture: Float?
    var continuousTracking = false, trackingBias: Float = 0
}

// isim: the video effects the person turns on in Control Center (the `videoeffect NAME on|off` script command)
enum _VideoEffects {
    nonisolated(unsafe) static var enabled: Set<String> = ["reactions", "gestures"]
    static let names = ["reactions", "gestures", "studioLight", "backgroundReplacement", "edgeLight"]
    static func on(_ name: String) -> Bool { enabled.contains(name) }
    /// `videoeffect NAME on|off`
    static func command(_ args: String) {
        let a = args.split(separator: " ").map(String.init)
        guard a.count == 2, names.contains(a[0]), a[1] == "on" || a[1] == "off" else {
            NSLog("isim: videoeffect %@ on|off (on: %@)", names.joined(separator: "|"), enabled.sorted().joined(separator: ","))
            return
        }
        if a[1] == "on" { enabled.insert(a[0]) } else { enabled.remove(a[0]) }
        NSLog("isim: videoeffect %@ %@", a[0], a[1])
    }
}

extension AVCaptureDevice {
    /// the system's camera user interfaces an app can open (iOS 15)
    @objc public enum SystemUserInterface: Int, Sendable { case videoEffects = 1, microphoneModes = 2 }
    /// whether lens stabilization took part in a capture (iOS 11)
    @objc public enum LensStabilizationStatus: Int, Sendable { case unsupported = 0, off, active, outOfRange, unavailable }
    /// a frame's aspect ratio (iOS 26)
    @available(iOS 26.0, *)
    public struct AspectRatio: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let ratio1x1 = AspectRatio(rawValue: "AVCaptureAspectRatio1x1")
        public static let ratio16x9 = AspectRatio(rawValue: "AVCaptureAspectRatio16x9")
        public static let ratio9x16 = AspectRatio(rawValue: "AVCaptureAspectRatio9x16")
        public static let ratio4x3 = AspectRatio(rawValue: "AVCaptureAspectRatio4x3")
        public static let ratio3x4 = AspectRatio(rawValue: "AVCaptureAspectRatio3x4")
        var _ratio: Double {
            switch self { case .ratio1x1: return 1; case .ratio16x9: return 16.0 / 9; case .ratio9x16: return 9.0 / 16; case .ratio3x4: return 3.0 / 4; default: return 4.0 / 3 }
        }
    }
    /// how strongly cinematic video holds focus on its subject (iOS 26)
    @available(iOS 26.0, *)
    @objc public enum CinematicVideoFocusMode: Int, Sendable { case none = 0, strong, weak }
    /// what may make a restricted virtual device switch cameras (iOS 15)
    public struct PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var videoZoomChanged: Self { Self(rawValue: 1) }
        public static var focusModeChanged: Self { Self(rawValue: 2) }
        public static var exposureModeChanged: Self { Self(rawValue: 4) }
    }

    // MARK: constants (isim's sentinel values: they leave a setting to the camera)
    @available(iOS 27.0, *) public static let autoISO: Float = -2
    @available(iOS 27.0, *) public static let autoExposureDuration = CMTime(value: -2, timescale: 1)
    @available(iOS 27.0, *) public static let autoLensAperture: Float = -2
    @available(iOS 27.0, *) public static let currentLensAperture: Float = 0

    // MARK: lookup and presets
    public func supportsSessionPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        if _isMicrophone { return false }
        if preset == .hd4K3840x2160 { return false }
        let size = _CameraSource.size(_position)
        switch preset {
        case .hd1920x1080: return size.width >= 1920 || size.height >= 1920
        case .hd1280x720, .iFrame1280x720: return size.width >= 1280 || size.height >= 1280
        default: return true
        }
    }
    /// the transform from one camera's coordinates to another's (both on the same side): a translation by their
    /// distance on the phone (isim: 10 mm between back cameras), as a 4x3 matrix of Float32, column-major
    public class func extrinsicMatrix(from fromDevice: AVCaptureDevice, to toDevice: AVCaptureDevice) -> Data? {
        guard !fromDevice._isMicrophone, !toDevice._isMicrophone, fromDevice.position == toDevice.position else { return nil }
        let dx: Float = fromDevice.uniqueID == toDevice.uniqueID ? 0 : (fromDevice._type == .builtInUltraWideCamera ? 10 : -10)
        var m: [Float] = [1, 0, 0, 0, 1, 0, 0, 0, 1, dx, 0, 0]
        return Data(bytes: &m, count: m.count * 4)
    }
    /// opens the system's video effects or microphone modes view in Control Center (isim: logged)
    public class func showSystemUserInterface(_ ui: SystemUserInterface) {
        NSLog("isim AVFoundation: system user interface %@", ui == .videoEffects ? "videoEffects" : "microphoneModes")
    }
    public var isContinuityCamera: Bool { _type == DeviceType(rawValue: "AVCaptureDeviceTypeContinuityCamera") }
    public var companionDeskViewCamera: AVCaptureDevice? { nil }
    @available(iOS 26.0, *) public var nominalFocalLengthIn35mmFilm: Float {
        _type == .builtInUltraWideCamera ? 13 : _position == .front ? 23 : 24
    }

    // MARK: rectangles of interest (iOS 26), Center Stage's (iOS 16.4)
    @available(iOS 26.0, *) public var isFocusRectOfInterestSupported: Bool { !_isMicrophone }
    @available(iOS 26.0, *) public var isExposureRectOfInterestSupported: Bool { !_isMicrophone }
    @available(iOS 26.0, *) public var minFocusRectOfInterestSize: CGSize { CGSize(width: 0.05, height: 0.05) }
    @available(iOS 26.0, *) public var minExposureRectOfInterestSize: CGSize { CGSize(width: 0.05, height: 0.05) }
    @available(iOS 26.0, *) public func defaultRectForFocusPoint(ofInterest p: CGPoint) -> CGRect { _defaultRect(p, minFocusRectOfInterestSize) }
    @available(iOS 26.0, *) public func defaultRectForExposurePoint(ofInterest p: CGPoint) -> CGRect { _defaultRect(p, minExposureRectOfInterestSize) }
    func _defaultRect(_ p: CGPoint, _ minSize: CGSize) -> CGRect {
        let side = max(0.2, minSize.width)
        let x = min(max(0, p.x - side / 2), 1 - side), y = min(max(0, p.y - side / 2), 1 - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }
    func _clampRect(_ r: CGRect, _ minSize: CGSize) -> CGRect {
        let u = r.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return CGRect(x: u.minX, y: u.minY, width: max(minSize.width, u.width), height: max(minSize.height, u.height))
    }
    /// setting one moves the point of interest to its middle (and the point's setter resets the rectangle)
    @available(iOS 26.0, *) public var focusRectOfInterest: CGRect {
        get { _ex.focusRect ?? defaultRectForFocusPoint(ofInterest: focusPointOfInterest) }
        set { let r = _clampRect(newValue, minFocusRectOfInterestSize); focusPointOfInterest = CGPoint(x: r.midX, y: r.midY); _ex.focusRect = r }
    }
    @available(iOS 26.0, *) public var exposureRectOfInterest: CGRect {
        get { _ex.exposureRect ?? defaultRectForExposurePoint(ofInterest: exposurePointOfInterest) }
        set { let r = _clampRect(newValue, minExposureRectOfInterestSize); exposurePointOfInterest = CGPoint(x: r.midX, y: r.midY); _ex.exposureRect = r }
    }
    @available(iOS 16.4, *) public var centerStageRectOfInterest: CGRect {
        get { _ex.centerStageRect }
        set { _ex.centerStageRect = _clampRect(newValue, CGSize(width: 0.1, height: 0.1)) }
    }
    public var isFaceDrivenAutoExposureEnabled: Bool { get { _ex.faceDrivenAutoExposure } set { _ex.faceDrivenAutoExposure = newValue } }
    public var automaticallyAdjustsFaceDrivenAutoExposureEnabled: Bool {
        get { _ex.adjustsFaceDrivenAutoExposure } set { _ex.adjustsFaceDrivenAutoExposure = newValue }
    }
    public var isGlobalToneMappingEnabled: Bool { get { _ex.globalToneMapping } set { _ex.globalToneMapping = newValue && activeFormat.isGlobalToneMappingSupported } }
    @available(iOS 18.0, *) public var isAutoVideoFrameRateEnabled: Bool {
        get { _ex.autoVideoFrameRate } set { _ex.autoVideoFrameRate = newValue && activeFormat.isAutoVideoFrameRateSupported }
    }

    // MARK: reaction effects (iOS 17)
    public class var reactionEffectsEnabled: Bool { _VideoEffects.on("reactions") }
    public class var reactionEffectGesturesEnabled: Bool { _VideoEffects.on("gestures") }
    public var canPerformReactionEffects: Bool { AVCaptureDevice.reactionEffectsEnabled && activeFormat.reactionEffectsSupported }
    public var availableReactionTypes: Set<AVCaptureReactionType> { canPerformReactionEffects ? Set(AVCaptureReactionType.all) : [] }
    /// starts a reaction (isim: about two seconds, recorded, not drawn over the simulated picture)
    public func performEffect(for reactionType: AVCaptureReactionType) {
        guard canPerformReactionEffects else { return }
        let now = _captureHostTime()
        willChangeValue(forKey: "reactionEffectsInProgress")
        _ex.reactions.append(AVCaptureReactionEffectState(reactionType, start: _captureTime(now), end: _captureTime(now + 2)))
        didChangeValue(forKey: "reactionEffectsInProgress")
        NSLog("isim AVFoundation: reaction %@", reactionType.rawValue)
    }
    public var reactionEffectsInProgress: [AVCaptureReactionEffectState] {
        let now = _captureTime(_captureHostTime())
        _ex.reactions.removeAll { $0.endTime < now }
        return _ex.reactions
    }

    // MARK: video effects the person controls (Studio Light, background replacement, Edge Light)
    public class var isStudioLightEnabled: Bool { _VideoEffects.on("studioLight") }
    public var isStudioLightActive: Bool { AVCaptureDevice.isStudioLightEnabled && activeFormat.isStudioLightSupported }
    @available(iOS 18.0, *) public class var isBackgroundReplacementEnabled: Bool { _VideoEffects.on("backgroundReplacement") }
    @available(iOS 18.0, *) public var isBackgroundReplacementActive: Bool { AVCaptureDevice.isBackgroundReplacementEnabled && activeFormat.isBackgroundReplacementSupported }
    @available(iOS 26.2, *) public class var isEdgeLightEnabled: Bool { _VideoEffects.on("edgeLight") }
    @available(iOS 26.2, *) public class var isEdgeLightActive: Bool { isEdgeLightEnabled }
    @available(iOS 18.0, *) public var spatialCaptureDiscomfortReasons: Set<AVSpatialCaptureDiscomfortReason> {
        _sceneIsDark ? [.notEnoughLight] : []
    }

    // MARK: virtual devices: switching between constituents (iOS 15, iOS 27)
    public var activePrimaryConstituentDeviceSwitchingBehavior: PrimaryConstituentDeviceSwitchingBehavior { primaryConstituentDeviceSwitchingBehavior }
    public var primaryConstituentDeviceRestrictedSwitchingBehaviorConditions: PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions {
        PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions(rawValue: _ex.restrictedConditions)
    }
    public var activePrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions: PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions {
        primaryConstituentDeviceRestrictedSwitchingBehaviorConditions
    }
    public func setPrimaryConstituentDeviceSwitchingBehavior(_ b: PrimaryConstituentDeviceSwitchingBehavior,
                                                           restrictedSwitchingBehaviorConditions c: PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions) {
        _ex.restrictedConditions = b == .restricted ? c.rawValue : 0
    }
    public var supportedFallbackPrimaryConstituentDevices: [AVCaptureDevice] { isVirtualDevice ? constituentDevices : [] }
    public var fallbackPrimaryConstituentDevices: [AVCaptureDevice] {
        get { _ex.fallbackConstituents }
        set { _ex.fallbackConstituents = newValue.filter { d in supportedFallbackPrimaryConstituentDevices.contains { $0 === d } } }
    }
    @available(iOS 27.0, *) public var isPrimaryConstituentDeviceSwitchingBehaviorLockedWithDeviceSupported: Bool { isVirtualDevice }
    /// iOS 27: keeps the virtual device on one constituent camera
    @available(iOS 27.0, *) public func setPrimaryConstituentDeviceSwitchingBehaviorLockedWith(_ device: AVCaptureDevice) {
        guard constituentDevices.contains(where: { $0 === device }) else { return }
        _ex.lockedConstituent = device
    }

    // MARK: lens smudge detection (iOS 26)
    @available(iOS 26.0, *) public var isCameraLensSmudgeDetectionEnabled: Bool { _ex.smudgeEnabled }
    @available(iOS 26.0, *) public var cameraLensSmudgeDetectionInterval: CMTime { _ex.smudgeInterval }
    @available(iOS 26.0, *) public func setCameraLensSmudgeDetectionEnabled(_ enabled: Bool, detectionInterval: CMTime) {
        _ex.smudgeEnabled = enabled && activeFormat.isCameraLensSmudgeDetectionSupported
        _ex.smudgeInterval = enabled ? detectionInterval : .zero
    }
    /// isim's lens is never smudged (the `camerasmudge` scenario is not simulated)
    @available(iOS 26.0, *) public var cameraLensSmudgeDetectionStatus: AVCaptureCameraLensSmudgeDetectionStatus {
        _ex.smudgeEnabled ? .smudgeNotDetected : .disabled
    }

    // MARK: dynamic aspect ratio (iOS 26)
    @available(iOS 26.0, *) public var dynamicAspectRatio: AspectRatio? { _ex.dynamicAspectRatio.map(AspectRatio.init) }
    /// the active format's dimensions cropped to the dynamic aspect ratio
    @available(iOS 26.0, *) public var dynamicDimensions: CMVideoDimensions {
        let d = activeFormat.formatDescription.dimensions
        guard let r = dynamicAspectRatio?._ratio, d.width > 0, d.height > 0 else { return d }
        let w = Double(d.width), h = Double(d.height)
        return w / h > r ? CMVideoDimensions(width: Int32((h * r).rounded()), height: d.height) : CMVideoDimensions(width: d.width, height: Int32((w / r).rounded()))
    }
    @available(iOS 26.0, *) public func setDynamicAspectRatio(_ ratio: AspectRatio, completionHandler handler: ((CMTime, (any Error)?) -> Void)? = nil) {
        guard activeFormat.supportedDynamicAspectRatios.contains(ratio) else {
            handler.map { h in DispatchQueue.main.async { h(.invalid, AVError(.operationNotAllowed, reason: "the active format does not support this aspect ratio")) } }
            return
        }
        _ex.dynamicAspectRatio = ratio.rawValue
        _completeAfterAdjustment(handler.map { h in { h($0, nil) } })
    }

    // MARK: cinematic video (iOS 26)
    @available(iOS 26.0, *) public var cinematicVideoCaptureSceneMonitoringStatuses: Set<AVCaptureSceneMonitoringStatus> { _sceneIsDark ? [.notEnoughLight] : [] }
    @available(iOS 26.0, *) public func setCinematicVideoTrackingFocus(detectedObjectID: Int, focusMode: CinematicVideoFocusMode) {
        _ex.cinematicFocus = (focusPointOfInterest, focusMode.rawValue)
    }
    @available(iOS 26.0, *) public func setCinematicVideoTrackingFocus(at point: CGPoint, focusMode: CinematicVideoFocusMode) {
        _ex.cinematicFocus = (point, focusMode.rawValue); focusPointOfInterest = point
    }
    @available(iOS 26.0, *) public func setCinematicVideoFixedFocus(at point: CGPoint, focusMode: CinematicVideoFocusMode) {
        _ex.cinematicFocus = (point, focusMode.rawValue); focusPointOfInterest = point; self.focusMode = .locked
    }

    // MARK: Smart Framing (iOS 26)
    @available(iOS 26.0, *) public var smartFramingMonitor: AVCaptureSmartFramingMonitor? {
        guard activeFormat.isSmartFramingSupported else { return nil }
        if let m = _ex.smartFraming as? AVCaptureSmartFramingMonitor { return m }
        let m = AVCaptureSmartFramingMonitor(self); _ex.smartFraming = m; return m
    }

    // MARK: external sync and locked frame durations (iOS 26): isim's cameras have no sync input
    @available(iOS 26.0, *) public var isVideoFrameDurationLocked: Bool { activeVideoMinFrameDuration == activeVideoMaxFrameDuration && activeVideoMinFrameDuration.isNumeric }
    @available(iOS 26.0, *) public var minSupportedLockedVideoFrameDuration: CMTime { CMTime(value: 1, timescale: 30) }
    @available(iOS 26.0, *) public var isFollowingExternalSyncDevice: Bool { false }
    @available(iOS 26.0, *) public var minSupportedExternalSyncFrameDuration: CMTime { .invalid }
    @available(iOS 27.0, *) public var isAdjustingSignalCompensationDelayWhileRunningSupported: Bool { false }

    // MARK: white balance presets (iOS 26)
    @available(iOS 26.0, *) public func setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues v: WhiteBalanceTemperatureAndTintValues,
                                                                handler: ((CMTime) -> Void)? = nil) {
        setWhiteBalanceModeLocked(with: deviceWhiteBalanceGains(for: v), completionHandler: handler)
    }

    // MARK: exposure signals and lens aperture (iOS 27)
    @available(iOS 27.0, *) public var supportedExposureSignals: Set<AVCaptureDeviceExposureSignal> {
        _isMicrophone ? [] : [.subjectMotion, .flicker, .groupPhoto, .document, .starburst]
    }
    @available(iOS 27.0, *) public var automaticallyEnablesExposureSignals: Bool { get { _ex.autoExposureSignals } set { _ex.autoExposureSignals = newValue } }
    @available(iOS 27.0, *) public var enabledExposureSignals: Set<AVCaptureDeviceExposureSignal> {
        get { automaticallyEnablesExposureSignals ? supportedExposureSignals : Set(_ex.exposureSignals.map(AVCaptureDeviceExposureSignal.init)) }
        set { _ex.exposureSignals = Set(newValue.intersection(supportedExposureSignals).map(\.rawValue)) }
    }
    /// the signals the simulated scene raises: the declared people (one is a subject, several a group)
    @available(iOS 27.0, *) public var activeExposureSignals: Set<AVCaptureDeviceExposureSignal> {
        let people = _SceneObjects.declared.filter { $0.0 == .face }.count
        return enabledExposureSignals.intersection(people > 2 ? [.groupPhoto] : [])
    }
    @available(iOS 27.0, *) public var automaticallyAdjustsISO: Bool { get { _ex.adjustsISO } set { _ex.adjustsISO = newValue } }
    @available(iOS 27.0, *) public var automaticallyAdjustsExposureDuration: Bool { get { _ex.adjustsDuration } set { _ex.adjustsDuration = newValue } }
    @available(iOS 27.0, *) public var automaticallyAdjustsLensAperture: Bool { get { _ex.adjustsAperture } set { _ex.adjustsAperture = newValue } }
    @available(iOS 27.0, *) public var autoExposureLensApertureRateLimit: Float { get { _ex.apertureRateLimit } set { _ex.apertureRateLimit = max(0, newValue) } }
    /// iOS 27: a custom exposure that also sets the lens aperture (the simulated lens keeps a fixed aperture but
    /// reports the one set); auto values leave that part to the camera
    @available(iOS 27.0, *) public func setExposureModeCustom(lensAperture: Float, duration: CMTime, iso: Float, completionHandler handler: ((CMTime) -> Void)? = nil) {
        if lensAperture != AVCaptureDevice.currentLensAperture {
            _ex.aperture = lensAperture == AVCaptureDevice.autoLensAperture ? nil
                : max(activeFormat.minLensAperture, min(activeFormat.maxLensAperture, lensAperture))
        }
        let d = duration == AVCaptureDevice.autoExposureDuration ? AVCaptureDevice.currentExposureDuration : duration
        setExposureModeCustom(duration: d, iso: iso == AVCaptureDevice.autoISO ? AVCaptureDevice.currentISO : iso, completionHandler: handler)
    }
    @available(iOS 27.0, *) public var isContinuousAutoFocusTrackingEnabled: Bool {
        get { _ex.continuousTracking } set { _ex.continuousTracking = newValue && activeFormat.isContinuousAutoFocusTrackingSupported }
    }
    @available(iOS 27.0, *) public var isContinuousAutoFocusTrackingSubjectAcquired: Bool {
        _ex.continuousTracking && _SceneObjects.declared.contains { $0.0 == .face || $0.0 == .humanBody }
    }
    @available(iOS 27.0, *) public var continuousAutoFocusTrackingLensPositionBias: Float {
        get { _ex.trackingBias } set { _ex.trackingBias = max(-1, min(1, newValue)) }
    }
}

extension AVCaptureDevice.WhiteBalanceTemperatureAndTintValues {
    public init() { self.init(temperature: 0, tint: 0) }
    @available(iOS 26.0, *) public static let daylight = Self(temperature: 5500, tint: 0)
    @available(iOS 26.0, *) public static let cloudy = Self(temperature: 6500, tint: 0)
    @available(iOS 26.0, *) public static let tungsten = Self(temperature: 3200, tint: 0)
    @available(iOS 26.0, *) public static let fluorescent = Self(temperature: 4000, tint: 0)
    @available(iOS 26.0, *) public static let shadow = Self(temperature: 7500, tint: 0)
}
extension AVCaptureDevice.WhiteBalanceChromaticityValues {
    public init() { self.init(x: 0, y: 0) }
}

extension AVCaptureDevice.RotationCoordinator {
    /// iOS 27: the angle that turns a frame upright for a device orientation (the simulated picture is always upright
    /// in the device's own orientation, so this is the turn from portrait)
    @available(iOS 27.0, *)
    public func videoRotationAngleRelative(toDeviceOrientation orientation: AVCaptureVideoOrientation) -> CGFloat {
        switch orientation { case .portrait: return 0; case .landscapeRight: return 270; case .portraitUpsideDown: return 180; case .landscapeLeft: return 90 }
    }
}

// MARK: - formats

extension AVCaptureDevice.Format {
    var _isVideoFormat: Bool { mediaType == .video }
    public func isVideoStabilizationModeSupported(_ mode: AVCaptureVideoStabilizationMode) -> Bool { mode == .off }
    public var supportedColorSpaces: [AVCaptureColorSpace] { _isVideoFormat ? [.sRGB, .P3_D65] : [] }
    public var videoZoomFactorUpscaleThreshold: CGFloat { 1 }
    public var unsupportedCaptureOutputClasses: [AnyClass] { [] }
    public var isGlobalToneMappingSupported: Bool { _isVideoFormat }
    public var isHighPhotoQualitySupported: Bool { _isVideoFormat }
    public var videoFrameRateRangeForCenterStage: AVCaptureDevice.FrameRateRange? { nil }
    public var videoMinZoomFactorForCenterStage: CGFloat { 1 }
    public var videoMaxZoomFactorForCenterStage: CGFloat { 1 }
    public var videoFrameRateRangeForPortraitEffect: AVCaptureDevice.FrameRateRange? { nil }
    public var isStudioLightSupported: Bool { false }
    public var videoFrameRateRangeForStudioLight: AVCaptureDevice.FrameRateRange? { nil }
    public var secondaryNativeResolutionZoomFactors: [CGFloat] { _isVideoFormat ? [2] : [] }
    public var reactionEffectsSupported: Bool { _isVideoFormat }
    public var videoFrameRateRangeForReactionEffectsInProgress: AVCaptureDevice.FrameRateRange? { _isVideoFormat ? AVCaptureDevice.FrameRateRange(min: 1, max: 30) : nil }
    @available(iOS 17.2, *) public var supportedVideoZoomRangesForDepthDataDelivery: [ClosedRange<CGFloat>] {
        _depthFormats.isEmpty ? [] : [videoMinZoomFactorForDepthDataDelivery...videoMaxZoomFactorForDepthDataDelivery]
    }
    @available(iOS 17.2, *) public var zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported: Bool { false }
    @available(iOS 18.0, *) public var isAutoVideoFrameRateSupported: Bool { _isVideoFormat }
    @available(iOS 18.0, *) public var isBackgroundReplacementSupported: Bool { false }
    @available(iOS 18.0, *) public var videoFrameRateRangeForBackgroundReplacement: AVCaptureDevice.FrameRateRange? { nil }
    @available(iOS 18.0, *) public var isSpatialVideoCaptureSupported: Bool { false }
    @available(iOS 18.0, *) public var systemRecommendedVideoZoomRange: ClosedRange<CGFloat>? { _isVideoFormat ? 1...videoMaxZoomFactor : nil }
    @available(iOS 18.0, *) public var systemRecommendedExposureBiasRange: ClosedRange<Float>? { _isVideoFormat ? -2...2 : nil }
    @available(iOS 26.0, *) public var supportedDynamicAspectRatios: [AVCaptureDevice.AspectRatio] {
        _isVideoFormat ? [.ratio4x3, .ratio3x4, .ratio16x9, .ratio9x16, .ratio1x1] : []
    }
    /// the horizontal field of view of a frame cropped to an aspect ratio
    @available(iOS 26.0, *) public func videoFieldOfView(for aspectRatio: AVCaptureDevice.AspectRatio, geometricDistortionCorrected: Bool) -> Float {
        let fov = Double(geometricDistortionCorrected ? geometricDistortionCorrectedVideoFieldOfView : videoFieldOfView) * .pi / 180
        let d = formatDescription.dimensions
        guard d.width > 0, d.height > 0 else { return videoFieldOfView }
        let native = Double(d.width) / Double(d.height), r = aspectRatio._ratio
        let scale = r >= native ? 1 : r / native                    // narrower ratios crop the width
        return Float(2 * atan(tan(fov / 2) * scale) * 180 / .pi)
    }
    @available(iOS 26.0, *) public var isCameraLensSmudgeDetectionSupported: Bool { _isVideoFormat }
    @available(iOS 26.0, *) public var isSmartFramingSupported: Bool { false }
    @available(iOS 26.0, *) public var isCinematicVideoCaptureSupported: Bool { false }
    @available(iOS 26.0, *) public var videoFrameRateRangeForCinematicVideo: AVCaptureDevice.FrameRateRange? { nil }
    @available(iOS 26.0, *) public var videoMinZoomFactorForCinematicVideo: CGFloat { 1 }
    @available(iOS 26.0, *) public var videoMaxZoomFactorForCinematicVideo: CGFloat { 1 }
    @available(iOS 26.0, *) public var defaultSimulatedAperture: Float { 0 }
    @available(iOS 26.0, *) public var minSimulatedAperture: Float { 0 }
    @available(iOS 26.0, *) public var maxSimulatedAperture: Float { 0 }
    @available(iOS 26.2, *) public var isEdgeLightSupported: Bool { false }
    @available(iOS 27.0, *) public var isCinematicVideoMetadataCaptureSupported: Bool { false }
    @available(iOS 27.0, *) public var isContinuousAutoFocusTrackingSupported: Bool { _isVideoFormat }
    @available(iOS 27.0, *) public var isLowLightVideoNoiseReductionSupported: Bool { false }
    /// iOS 27: the simulated lens has a fixed aperture, so the range is that one value
    @available(iOS 27.0, *) public var defaultLensAperture: Float { 1.6 }
    @available(iOS 27.0, *) public var minLensAperture: Float { defaultLensAperture }
    @available(iOS 27.0, *) public var maxLensAperture: Float { defaultLensAperture }
    @available(iOS 27.0, *) public var recommendedLensApertureStops: [Float] { [defaultLensAperture] }
    @available(iOS 27.0, *) public func supportsExposureModeCustom(lensAperture: Float, duration: CMTime, iso: Float) -> Bool {
        let a = lensAperture == AVCaptureDevice.autoLensAperture || lensAperture == AVCaptureDevice.currentLensAperture
            || (minLensAperture...maxLensAperture).contains(lensAperture)
        let d = duration == AVCaptureDevice.autoExposureDuration || duration == AVCaptureDevice.currentExposureDuration
            || (duration >= minExposureDuration && duration <= maxExposureDuration)
        let i = iso == AVCaptureDevice.autoISO || iso == AVCaptureDevice.currentISO || (minISO...maxISO).contains(iso)
        return _isVideoFormat && a && d && i
    }
}
