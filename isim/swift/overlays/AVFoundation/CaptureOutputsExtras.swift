// Capture inputs, connections, sessions and outputs: the rest of their API (issue #876, part 2). Deferred start,
// recording pause / resume callbacks, movie output metadata and per-recording camera switching, photo output and
// settings flags (constant color, virtual-device constituent photos, sensor orientation compensation), the photo
// output readiness coordinator, deferred photo proxies, the file data customizer, the metadata input, wind noise
// removal and multichannel audio modes.
//
// Adapted over isim's simulated capture pipeline: settings are stored and reported back; features the simulated
// devices lack (constant color, spatial and cinematic video, ProRes storage, external sync, audio zoom, first-order
// ambisonics) are reported unsupported.
import Foundation
import CoreMedia
import CoreGraphics
import AudioToolbox
import ImageIO

/// the channel layout a microphone input records (iOS 18)
@objc public enum AVCaptureMultichannelAudioMode: Int, Sendable { case none = 0, stereo = 1, firstOrderAmbisonics = 2 }

/// Called around a session's deferred start (iOS 26): the outputs that opted in start after the first frames reach
/// the preview, so the camera appears sooner.
public protocol AVCaptureSessionDeferredStartDelegate: NSObjectProtocol {
    func sessionWillRunDeferredStart(_ session: AVCaptureSession)
    func sessionDidRunDeferredStart(_ session: AVCaptureSession)
}

/// Tracks capture requests to tell the app when the shutter can be pressed again (iOS 17).
public protocol AVCapturePhotoOutputReadinessCoordinatorDelegate: NSObjectProtocol {
    func readinessCoordinator(_ coordinator: AVCapturePhotoOutputReadinessCoordinator, captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness)
}
extension AVCapturePhotoOutputReadinessCoordinatorDelegate {
    public func readinessCoordinator(_ coordinator: AVCapturePhotoOutputReadinessCoordinator, captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness) {}
}
@objc(AVCapturePhotoOutputReadinessCoordinator) open class AVCapturePhotoOutputReadinessCoordinator: NSObject, @unchecked Sendable {
    weak var _output: AVCapturePhotoOutput?
    var _tracked: Set<Int64> = []
    var _last: AVCapturePhotoOutput.CaptureReadiness
    public weak var delegate: (any AVCapturePhotoOutputReadinessCoordinatorDelegate)?
    public init(photoOutput: AVCapturePhotoOutput) {
        _output = photoOutput
        _last = photoOutput.captureReadiness
        super.init()
    }
    /// the output's readiness, held at notReadyWaitingForCapture while a tracked request has not reached the output
    open var captureReadiness: AVCapturePhotoOutput.CaptureReadiness {
        guard let o = _output else { return .sessionNotRunning }
        let r = o.captureReadiness
        return r == .ready && !_tracked.isEmpty ? .notReadyMomentarily : r
    }
    open func startTrackingCaptureRequest(using settings: AVCapturePhotoSettings) { _tracked.insert(settings.uniqueID); _report() }
    open func stopTrackingCaptureRequest(using settingsUniqueID: Int64) { _tracked.remove(settingsUniqueID); _report() }
    func _report() {
        let r = captureReadiness
        guard r != _last else { return }
        _last = r
        let d = delegate
        DispatchQueue.main.async { d?.readinessCoordinator(self, captureReadinessDidChange: r) }
    }
}

/// A photo whose processing is deferred (iOS 17). isim processes every photo at once, so none is delivered; the class
/// and the delegate method exist for code that handles them.
@objc(AVCaptureDeferredPhotoProxy) open class AVCaptureDeferredPhotoProxy: AVCapturePhoto, @unchecked Sendable {}

/// Replaces parts of a photo's file data (iOS 12)
public protocol AVCapturePhotoFileDataRepresentationCustomizer: AnyObject {
    func replacementMetadata(for photo: AVCapturePhoto) -> [String: Any]?
    func replacementEmbeddedThumbnailPixelBuffer(withPhotoFormat replacementEmbeddedThumbnailPhotoFormatOut: AutoreleasingUnsafeMutablePointer<NSDictionary?>,
                                                 for photo: AVCapturePhoto) -> Unmanaged<CVPixelBuffer>?
    func replacementDepthData(for photo: AVCapturePhoto) -> AVDepthData?
    func replacementPortraitEffectsMatte(for photo: AVCapturePhoto) -> AVPortraitEffectsMatte?
    func replacementSemanticSegmentationMatte(ofType semanticSegmentationMatteType: AVSemanticSegmentationMatte.MatteType, for photo: AVCapturePhoto) -> AVSemanticSegmentationMatte?
    func replacementAppleProRAWCompressionSettings(for photo: AVCapturePhoto, defaultSettings: [String: Any], maximumBitDepth: Int) -> [String: Any]
}
extension AVCapturePhotoFileDataRepresentationCustomizer {
    public func replacementMetadata(for photo: AVCapturePhoto) -> [String: Any]? { nil }
    public func replacementEmbeddedThumbnailPixelBuffer(withPhotoFormat replacementEmbeddedThumbnailPhotoFormatOut: AutoreleasingUnsafeMutablePointer<NSDictionary?>,
                                                        for photo: AVCapturePhoto) -> Unmanaged<CVPixelBuffer>? { nil }
    public func replacementDepthData(for photo: AVCapturePhoto) -> AVDepthData? { photo.depthData }
    public func replacementPortraitEffectsMatte(for photo: AVCapturePhoto) -> AVPortraitEffectsMatte? { photo.portraitEffectsMatte }
    public func replacementSemanticSegmentationMatte(ofType t: AVSemanticSegmentationMatte.MatteType, for photo: AVCapturePhoto) -> AVSemanticSegmentationMatte? {
        photo.semanticSegmentationMatte(for: t)
    }
    public func replacementAppleProRAWCompressionSettings(for photo: AVCapturePhoto, defaultSettings: [String: Any], maximumBitDepth: Int) -> [String: Any] { defaultSettings }
}

/// Feeds timed metadata into a session (iOS 9): a movie output records the groups appended while it records
@objc(AVCaptureMetadataInput) open class AVCaptureMetadataInput: AVCaptureInput, @unchecked Sendable {
    public let formatDescription: CMMetadataFormatDescription
    public let clock: CMClock
    var _groups: [AVTimedMetadataGroup] = []
    lazy var _ports: [Port] = [Port(.metadata, self)]
    public init(formatDescription desc: CMMetadataFormatDescription, clock: CMClock) {
        formatDescription = desc; self.clock = clock
        super.init()
    }
    open override var ports: [Port] { _ports }
    /// appends a group of timed metadata; fails when the group's time range is invalid
    open func append(_ metadata: AVTimedMetadataGroup) throws {
        guard metadata.timeRange.start.isValid else { throw AVError(.invalidSourceMedia, reason: "the metadata group has no valid time range") }
        _groups.append(metadata)
    }
}

// MARK: - per-object state

final class _AVCaptureInputExtras: @unchecked Sendable {
    var windNoiseRemoval = true
    var multichannel = AVCaptureMultichannelAudioMode.none
    var simulatedAperture: Float = 0
    var cinematic = false
    var audioZoom = false
}
final class _AVCaptureSessionExtras: @unchecked Sendable {
    var automaticallyRunsDeferredStart = true
    weak var deferredDelegate: (any AVCaptureSessionDeferredStartDelegate)?
    var deferredQueue: DispatchQueue?
    var deferredRan = false
    var mixWithOthers = false
    var bluetoothHighQuality = false
}

extension AVCaptureInput.Port {
    public static let formatDescriptionDidChangeNotification = Notification.Name("AVCaptureInputPortFormatDescriptionDidChangeNotification")
}

// MARK: - device inputs (microphone modes, iOS 18; cinematic and audio zoom, iOS 26)

extension AVCaptureDeviceInput {
    /// the microphone records mono: stereo and first-order ambisonics are not supported
    @available(iOS 18.0, *) public func isMultichannelAudioModeSupported(_ mode: AVCaptureMultichannelAudioMode) -> Bool { device._isMicrophone && mode == .none }
    @available(iOS 18.0, *) public var isWindNoiseRemovalSupported: Bool { device._isMicrophone }
    @available(iOS 18.0, *) public var isWindNoiseRemovalEnabled: Bool {
        get { isWindNoiseRemovalSupported && _inputEx.windNoiseRemoval } set { _inputEx.windNoiseRemoval = newValue }
    }
    @available(iOS 26.0, *) public var simulatedAperture: Float { get { _inputEx.simulatedAperture } set { _inputEx.simulatedAperture = newValue } }
    @available(iOS 26.0, *) public var isCinematicVideoCaptureSupported: Bool { device.activeFormat.isCinematicVideoCaptureSupported }
    @available(iOS 26.0, *) public var isCinematicVideoCaptureEnabled: Bool {
        get { _inputEx.cinematic } set { _inputEx.cinematic = newValue && isCinematicVideoCaptureSupported }
    }
    @available(iOS 26.0, *) public var isLockedVideoFrameDurationSupported: Bool { false }
    @available(iOS 26.0, *) public var activeLockedVideoFrameDuration: CMTime { .invalid }
    @available(iOS 26.0, *) public var isExternalSyncSupported: Bool { false }
    @available(iOS 26.0, *) public var activeExternalSyncVideoFrameDuration: CMTime { .invalid }
    @available(iOS 26.0, *) public func unfollowExternalSyncDevice() {}
    @available(iOS 26.4, *) public var isAudioZoomSupported: Bool { false }
    @available(iOS 26.4, *) public var isAudioZoomEnabled: Bool { get { _inputEx.audioZoom && isAudioZoomSupported } set { _inputEx.audioZoom = newValue } }
}

// MARK: - connections (iOS 27)

extension AVCaptureConnection {
    @available(iOS 27.0, *) public var isLowLightVideoNoiseReductionSupported: Bool { _device?.activeFormat.isLowLightVideoNoiseReductionSupported ?? false }
    @available(iOS 27.0, *) public var isLowLightVideoNoiseReductionEnabled: Bool { false }
    @available(iOS 27.0, *) public var automaticallyEnablesLowLightVideoNoiseReduction: Bool {
        get { _lowLightAuto } set { _lowLightAuto = newValue }
    }
}

// MARK: - sessions: deferred start (iOS 26), application audio session options

extension AVCaptureSession {
    @available(iOS 18.0, *) public var configuresApplicationAudioSessionToMixWithOthers: Bool {
        get { _sessionEx.mixWithOthers } set { _sessionEx.mixWithOthers = newValue }
    }
    @available(iOS 26.0, *) public var configuresApplicationAudioSessionForBluetoothHighQualityRecording: Bool {
        get { _sessionEx.bluetoothHighQuality } set { _sessionEx.bluetoothHighQuality = newValue }
    }
    @available(iOS 26.0, *) public var isManualDeferredStartSupported: Bool { true }
    /// on (the default): the session starts the deferred outputs itself once the first frame is shown; off: the
    /// app calls runDeferredStartWhenNeeded()
    @available(iOS 26.0, *) public var automaticallyRunsDeferredStart: Bool {
        get { _sessionEx.automaticallyRunsDeferredStart } set { _sessionEx.automaticallyRunsDeferredStart = newValue }
    }
    @available(iOS 26.0, *) public var deferredStartDelegate: (any AVCaptureSessionDeferredStartDelegate)? { _sessionEx.deferredDelegate }
    @available(iOS 26.0, *) public var deferredStartDelegateCallbackQueue: DispatchQueue? { _sessionEx.deferredQueue }
    @available(iOS 26.0, *) public func setDeferredStartDelegate(_ delegate: (any AVCaptureSessionDeferredStartDelegate)?, deferredStartDelegateCallbackQueue queue: DispatchQueue?) {
        _sessionEx.deferredDelegate = delegate; _sessionEx.deferredQueue = delegate == nil ? nil : queue
    }
    /// runs the deferred start now when the session runs and has outputs waiting for it (once per run)
    @available(iOS 26.0, *) public func runDeferredStartWhenNeeded() { _runDeferredStart() }
    func _runDeferredStart() {
        guard isRunning, !_sessionEx.deferredRan else { return }
        let deferred = outputs.filter { $0._deferredStart }
        guard !deferred.isEmpty else { return }
        _sessionEx.deferredRan = true
        let d = _sessionEx.deferredDelegate, q = _sessionEx.deferredQueue ?? .main
        q.async {
            d?.sessionWillRunDeferredStart(self)
            NSLog("isim AVFoundation: deferred start of %ld outputs", deferred.count)
            d?.sessionDidRunDeferredStart(self)
        }
    }
    /// startRunning: a new run defers again; the automatic deferred start follows the first frames (about 0.1 s)
    func _deferredStartAfterRunning() {
        _sessionEx.deferredRan = false
        guard _sessionEx.automaticallyRunsDeferredStart else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in self?._runDeferredStart() }
    }
}

extension AVCaptureOutput {
    /// data and file outputs can start after the preview (photo outputs too); a session's deferred start starts them
    @available(iOS 26.0, *) public var isDeferredStartSupported: Bool { true }
    @available(iOS 26.0, *) public var isDeferredStartEnabled: Bool { get { _deferredStart } set { _deferredStart = newValue && isDeferredStartSupported } }
}
extension AVCaptureVideoPreviewLayer {
    /// the preview is what a deferred start waits for, so it is never deferred itself
    @available(iOS 26.0, *) public var isDeferredStartSupported: Bool { false }
    @available(iOS 26.0, *) public var isDeferredStartEnabled: Bool { get { false } set {} }
}

// MARK: - video and audio data outputs

extension AVCaptureVideoDataOutput {
    public func availableVideoCodecTypesForAssetWriter(writingTo outputFileType: AVFileType) -> [AVVideoCodecType] {
        _FFmpeg.hasHEVC ? [.hevc, .h264] : [.h264]
    }
    @available(iOS 26.0, *)
    public func recommendedMovieMetadata(forVideoCodecType videoCodecType: AVVideoCodecType, assetWriterOutputFileType outputFileType: AVFileType) -> [AVMetadataItem]? { [] }
    @available(iOS 26.0, *) public var preservesDynamicHDRMetadata: Bool { get { _preservesHDR } set { _preservesHDR = newValue } }
    @available(iOS 26.0, *) public var preparesCellularRadioForNetworkConnection: Bool { get { _preparesRadio } set { _preparesRadio = newValue } }
}
extension AVCaptureAudioDataOutput {
    /// the layout of spatial audio (iOS 26): isim's microphone is mono
    @available(iOS 26.0, *) public var spatialAudioChannelLayoutTag: AudioChannelLayoutTag {
        get { _spatialTag } set { _spatialTag = newValue }
    }
}

// MARK: - file and movie outputs

extension AVCaptureMovieFileOutput {
    /// metadata written into the movie (stored: isim's movies carry ffmpeg's defaults)
    public var metadata: [AVMetadataItem]? { get { _metadata } set { _metadata = newValue } }
    @available(iOS 18.0, *) public var isSpatialVideoCaptureSupported: Bool { false }
    @available(iOS 18.0, *) public var isSpatialVideoCaptureEnabled: Bool { get { false } set {} }
    @available(iOS 27.0, *) public var isCinematicVideoMetadataCaptureSupported: Bool { false }
    @available(iOS 27.0, *) public var isCinematicVideoMetadataCaptureEnabled: Bool { get { false } set {} }
    @available(iOS 27.0, *) public var automaticallyAdjustsCinematicVideoMetadataCaptureEnabled: Bool {
        get { _adjustsCinematicMetadata } set { _adjustsCinematicMetadata = newValue }
    }
    @available(iOS 27.0, *) public var isProVideoStorageSupported: Bool { false }
    @available(iOS 27.0, *) public var usesProVideoStorage: Bool { get { false } set {} }
    /// how a virtual camera may switch cameras while recording (the session's behavior otherwise)
    public var primaryConstituentDeviceSwitchingBehaviorForRecording: AVCaptureDevice.PrimaryConstituentDeviceSwitchingBehavior { _switching.0 }
    public var primaryConstituentDeviceRestrictedSwitchingBehaviorConditionsForRecording: AVCaptureDevice.PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions {
        AVCaptureDevice.PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions(rawValue: _switching.1)
    }
    public func setPrimaryConstituentDeviceSwitchingBehaviorForRecording(_ behavior: AVCaptureDevice.PrimaryConstituentDeviceSwitchingBehavior,
                                                                         restrictedSwitchingBehaviorConditions c: AVCaptureDevice.PrimaryConstituentDeviceRestrictedSwitchingBehaviorConditions) {
        _switching = (behavior, behavior == .restricted ? c.rawValue : 0)
    }
    /// isim's movies keep their orientation in the track transform: the setting is stored
    public func recordsVideoOrientationAndMirroringChangesAsMetadataTrack(for connection: AVCaptureConnection) -> Bool {
        _orientationTracks.contains(ObjectIdentifier(connection))
    }
    public func setRecordsVideoOrientationAndMirroringChangesAsMetadataTrack(_ doRecord: Bool, for connection: AVCaptureConnection) {
        guard connection._carries(.video) else { return }
        if doRecord { _orientationTracks.insert(ObjectIdentifier(connection)) } else { _orientationTracks.remove(ObjectIdentifier(connection)) }
    }
}

// MARK: - photos

extension AVCapturePhotoOutput {
    @available(iOS 18.0, *) public var availableRawPhotoCodecTypes: [AVVideoCodecType] { [] }
    @available(iOS 18.0, *) public func supportedRawPhotoCodecTypes(forRawPhotoPixelFormatType pixelFormatType: OSType, fileType: AVFileType) -> [AVVideoCodecType] { [] }
    public var isAutoRedEyeReductionSupported: Bool { false }
    @available(iOS 18.0, *) public var isConstantColorSupported: Bool { false }
    @available(iOS 18.0, *) public var isConstantColorEnabled: Bool { get { false } set {} }
    @available(iOS 26.0, *) public var isCameraSensorOrientationCompensationSupported: Bool { false }
    @available(iOS 26.0, *) public var isCameraSensorOrientationCompensationEnabled: Bool { get { false } set {} }
    /// a virtual camera can deliver one photo per constituent camera
    public var isVirtualDeviceConstituentPhotoDeliverySupported: Bool { _device?.isVirtualDevice == true }
    public var isVirtualDeviceConstituentPhotoDeliveryEnabled: Bool {
        get { _constituentDelivery } set { _constituentDelivery = newValue && isVirtualDeviceConstituentPhotoDeliverySupported }
    }
    public var preservesLivePhotoCaptureSuspendedOnSessionStop: Bool { get { _preservesSuspended } set { _preservesSuspended = newValue } }
}
extension AVCapturePhotoSettings {
    /// a copy of other settings with a new uniqueID (Apple's Swift name; init(from:) is isim's older spelling)
    public convenience init(fromPhotoSettings photoSettings: AVCapturePhotoSettings) { self.init(from: photoSettings) }
    @available(iOS 18.0, *) public var isConstantColorEnabled: Bool { get { _settingsEx.constantColor } set { _settingsEx.constantColor = newValue } }
    @available(iOS 18.0, *) public var isConstantColorFallbackPhotoDeliveryEnabled: Bool {
        get { _settingsEx.constantColorFallback } set { _settingsEx.constantColorFallback = newValue }
    }
    public var livePhotoMovieMetadata: [AVMetadataItem]! { get { _settingsEx.liveMetadata } set { _settingsEx.liveMetadata = newValue ?? [] } }
    @available(iOS 18.0, *) public var rawFileFormat: [String: Any]? { get { _settingsEx.rawFileFormat } set { _settingsEx.rawFileFormat = newValue } }
    public var virtualDeviceConstituentPhotoDeliveryEnabledDevices: [AVCaptureDevice] {
        get { _settingsEx.constituents } set { _settingsEx.constituents = newValue }
    }
}
struct _AVCapturePhotoSettingsExtras {
    var constantColor = false, constantColorFallback = false
    var liveMetadata: [AVMetadataItem] = []
    var rawFileFormat: [String: Any]?
    var constituents: [AVCaptureDevice] = []
}
extension AVCaptureResolvedPhotoSettings {
    /// isim's RAW (DNG) files have no embedded thumbnail
    public var rawEmbeddedThumbnailDimensions: CMVideoDimensions { CMVideoDimensions(width: 0, height: 0) }
}
extension AVCapturePhoto {
    @available(iOS 18.0, *) public var isConstantColorFallbackPhoto: Bool { false }
    @available(iOS 18.0, *) public var constantColorConfidenceMap: CVPixelBuffer? { nil }
    @available(iOS 18.0, *) public var constantColorCenterWeightedMeanConfidenceLevel: Float { 0 }
    /// the file data with the customizer's replacement metadata merged in (JPEG / HEIC re-encoded through ImageIO);
    /// its other replacements (thumbnail, depth, mattes) are asked for but the photo's own are kept
    public func fileDataRepresentation(with customizer: any AVCapturePhotoFileDataRepresentationCustomizer) -> Data? {
        guard let data = fileDataRepresentation() else { return nil }
        _ = customizer.replacementDepthData(for: self); _ = customizer.replacementPortraitEffectsMatte(for: self)
        guard let meta = customizer.replacementMetadata(for: self),
              let src = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(src) else { return data }
        let out = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(out as CFMutableData, type, 1, nil) else { return data }
        CGImageDestinationAddImageFromSource(dst, src, 0, meta as CFDictionary)
        return CGImageDestinationFinalize(dst) ? out as Data : data
    }
}
