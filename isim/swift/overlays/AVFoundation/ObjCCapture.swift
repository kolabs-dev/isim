// isim AVFoundation for Objective-C (issue #707): capture. The classes carry Apple's Objective-C names (OBJC_NAMES in
// buildlib/swift.py) and these members Apple's selectors. A CMTime crosses as a pointer to its C struct (same layout as
// Swift's), a CMSampleBufferRef / CVPixelBufferRef as the Swift object's opaque pointer. Objective-C delegates are
// wrapped in Swift adapters that forward by selector.
import Foundation
import UIKit
import CoreMedia
import CoreVideo

// MARK: helpers

extension CMTime {
    init(_isimRaw p: UnsafeRawPointer) { self = p.load(as: CMTime.self) }
    func _isimStore(_ p: UnsafeMutableRawPointer) { p.storeBytes(of: self, as: CMTime.self) }
}
func _isimOpaque(_ o: AnyObject?) -> UnsafeMutableRawPointer? { o.map { Unmanaged.passUnretained($0).toOpaque() } }

/// calls an Objective-C method on `target` with object or pointer arguments, when it responds
@discardableResult
func _isimSend(_ target: NSObject?, _ name: String, _ args: [Any?]) -> Bool {
    guard let target else { return false }
    let sel = NSSelectorFromString(name)
    guard target.responds(to: sel) else { return false }
    let imp = target.method(for: sel)
    let a: [UnsafeMutableRawPointer?] = args.map { v in
        switch v {
        case nil: return nil
        case let p as UnsafeMutableRawPointer: return p
        case let o as AnyObject: return Unmanaged.passUnretained(o).toOpaque()
        default: return nil
        }
    }
    typealias F1 = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?) -> Void
    typealias F2 = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    typealias F3 = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    typealias F4 = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    switch a.count {
    case 1: unsafeBitCast(imp, to: F1.self)(target, sel, a[0])
    case 2: unsafeBitCast(imp, to: F2.self)(target, sel, a[0], a[1])
    case 3: unsafeBitCast(imp, to: F3.self)(target, sel, a[0], a[1], a[2])
    case 4: unsafeBitCast(imp, to: F4.self)(target, sel, a[0], a[1], a[2], a[3])
    default: return false
    }
    return true
}
private let _isimAdapterKeys = UnsafeMutableRawPointer.allocate(byteCount: 2, alignment: 1)
func _isimKeep(_ owner: AnyObject, _ adapter: AnyObject?, second: Bool = false) {
    objc_setAssociatedObject(owner, _isimAdapterKeys + (second ? 1 : 0), adapter, .OBJC_ASSOCIATION_RETAIN)
}
/// runs `body` on a C dispatch queue (retained by the caller's adapter), or right away without one
func _isimOn(_ q: dispatch_queue_t?, _ body: @escaping () -> Void) {
    if let q { dispatch_async(q, body) } else { body() }
}

// MARK: delegate adapters

final class _ObjCPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let target: NSObject
    init(_ t: NSObject) { target = t }
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor s: AVCaptureResolvedPhotoSettings) {
        _isimSend(target, "captureOutput:willBeginCaptureForResolvedSettings:", [output, s])
    }
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor s: AVCaptureResolvedPhotoSettings) {
        _isimSend(target, "captureOutput:willCapturePhotoForResolvedSettings:", [output, s])
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor s: AVCaptureResolvedPhotoSettings) {
        _isimSend(target, "captureOutput:didCapturePhotoForResolvedSettings:", [output, s])
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        _isimSend(target, "captureOutput:didFinishProcessingPhoto:error:", [output, photo, error.map { $0 as NSError }])
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor s: AVCaptureResolvedPhotoSettings, error: Error?) {
        _isimSend(target, "captureOutput:didFinishCaptureForResolvedSettings:error:", [output, s, error.map { $0 as NSError }])
    }
}

/// the Objective-C delegate and its queue (a dispatch_queue_t, retained here)
class _ObjCQueuedDelegate: NSObject {
    weak var target: NSObject?
    let queue: dispatch_queue_t?
    init(_ t: NSObject, _ q: dispatch_queue_t?) {
        target = t; queue = q
        if let q { dispatch_retain(UnsafeMutableRawPointer(q)) }
    }
    deinit { if let queue { dispatch_release(UnsafeMutableRawPointer(queue)) } }
}
final class _ObjCSampleBufferDelegate: _ObjCQueuedDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        _isimOn(queue) { [weak self] in _isimSend(self?.target, "captureOutput:didOutputSampleBuffer:fromConnection:", [output, _isimOpaque(sampleBuffer), connection]) }
    }
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        _isimOn(queue) { [weak self] in _isimSend(self?.target, "captureOutput:didDropSampleBuffer:fromConnection:", [output, _isimOpaque(sampleBuffer), connection]) }
    }
}

final class _ObjCRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    let target: NSObject
    init(_ t: NSObject) { target = t }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        _isimSend(target, "captureOutput:didStartRecordingToOutputFileAtURL:fromConnections:", [output, fileURL as NSURL, connections as NSArray])
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        _isimSend(target, "captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:",
                  [output, url as NSURL, connections as NSArray, error.map { $0 as NSError }])
    }
}

final class _ObjCMetadataDelegate: _ObjCQueuedDelegate, AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        _isimOn(queue) { [weak self] in _isimSend(self?.target, "captureOutput:didOutputMetadataObjects:fromConnection:", [output, objects as NSArray, connection]) }
    }
}

// MARK: devices

extension AVCaptureDevice {
    @objc(defaultDeviceWithMediaType:) class func _objc_default(_ type: String) -> AVCaptureDevice? { self.default(for: AVMediaType(rawValue: type)) }
    @objc(defaultDeviceWithDeviceType:mediaType:position:) class func _objc_default(_ dt: String, _ type: String?, _ pos: Position) -> AVCaptureDevice? {
        self.default(DeviceType(rawValue: dt), for: type.map { AVMediaType(rawValue: $0) }, position: pos)
    }
    @objc(deviceWithUniqueID:) class func _objc_device(_ id: String) -> AVCaptureDevice? { device(withUniqueID: id) }
    @objc(authorizationStatusForMediaType:) class func _objc_status(_ type: String) -> AVAuthorizationStatus { authorizationStatus(for: AVMediaType(rawValue: type)) }
    @objc(requestAccessForMediaType:completionHandler:) class func _objc_request(_ type: String, _ h: @escaping @Sendable (Bool) -> Void) {
        requestAccess(for: AVMediaType(rawValue: type), completionHandler: h)
    }
    @objc(systemPreferredCamera) class var _objc_systemPreferred: AVCaptureDevice? { systemPreferredCamera }
    @objc(uniqueID) var _objc_uniqueID: String { uniqueID }
    @objc(modelID) var _objc_modelID: String { modelID }
    @objc(manufacturer) var _objc_manufacturer: String { manufacturer }
    @objc(localizedName) var _objc_localizedName: String { localizedName }
    @objc(position) var _objc_position: Position { position }
    @objc(deviceType) var _objc_deviceType: String { deviceType.rawValue }
    @objc(isConnected) var _objc_connected: Bool { isConnected }
    @objc(isVirtualDevice) var _objc_virtual: Bool { isVirtualDevice }
    @objc(constituentDevices) var _objc_constituents: [AVCaptureDevice] { constituentDevices }
    @objc(hasMediaType:) func _objc_has(_ type: String) -> Bool { hasMediaType(AVMediaType(rawValue: type)) }
    @objc(hasTorch) var _objc_hasTorch: Bool { hasTorch }
    @objc(hasFlash) var _objc_hasFlash: Bool { hasFlash }
    @objc(isTorchAvailable) var _objc_torchAvailable: Bool { isTorchAvailable }
    @objc(isTorchActive) var _objc_torchActive: Bool { isTorchActive }
    @objc(torchLevel) var _objc_torchLevel: Float { torchLevel }
    @objc(torchMode) var _objc_torchMode: TorchMode { get { torchMode } set { torchMode = newValue } }
    @objc(isTorchModeSupported:) func _objc_torchSupported(_ m: TorchMode) -> Bool { isTorchModeSupported(m) }
    @objc(setTorchModeOnWithLevel:error:) func _objc_torchOn(_ level: Float) throws { try setTorchModeOn(level: level) }
    @objc(focusMode) var _objc_focusMode: FocusMode { get { focusMode } set { focusMode = newValue } }
    @objc(isFocusModeSupported:) func _objc_focusSupported(_ m: FocusMode) -> Bool { isFocusModeSupported(m) }
    @objc(exposureMode) var _objc_exposureMode: ExposureMode { get { exposureMode } set { exposureMode = newValue } }
    @objc(isExposureModeSupported:) func _objc_exposureSupported(_ m: ExposureMode) -> Bool { isExposureModeSupported(m) }
    @objc(whiteBalanceMode) var _objc_wbMode: WhiteBalanceMode { get { whiteBalanceMode } set { whiteBalanceMode = newValue } }
    @objc(isWhiteBalanceModeSupported:) func _objc_wbSupported(_ m: WhiteBalanceMode) -> Bool { isWhiteBalanceModeSupported(m) }
    @objc(focusPointOfInterest) var _objc_focusPoint: CGPoint { get { focusPointOfInterest } set { focusPointOfInterest = newValue } }
    @objc(exposurePointOfInterest) var _objc_exposurePoint: CGPoint { get { exposurePointOfInterest } set { exposurePointOfInterest = newValue } }
    @objc(isFocusPointOfInterestSupported) var _objc_focusPointSupported: Bool { isFocusPointOfInterestSupported }
    @objc(isExposurePointOfInterestSupported) var _objc_exposurePointSupported: Bool { isExposurePointOfInterestSupported }
    @objc(isSubjectAreaChangeMonitoringEnabled) var _objc_subjectArea: Bool { get { isSubjectAreaChangeMonitoringEnabled } set { isSubjectAreaChangeMonitoringEnabled = newValue } }
    @objc(videoZoomFactor) var _objc_zoom: CGFloat { get { videoZoomFactor } set { videoZoomFactor = newValue } }
    @objc(minAvailableVideoZoomFactor) var _objc_minZoom: CGFloat { minAvailableVideoZoomFactor }
    @objc(maxAvailableVideoZoomFactor) var _objc_maxZoom: CGFloat { maxAvailableVideoZoomFactor }
    @objc(rampToVideoZoomFactor:withRate:) func _objc_ramp(_ f: CGFloat, _ r: Float) { ramp(toVideoZoomFactor: f, withRate: r) }
    @objc(cancelVideoZoomRamp) func _objc_cancelRamp() { cancelVideoZoomRamp() }
    @objc(isRampingVideoZoom) var _objc_ramping: Bool { isRampingVideoZoom }
    @objc(lensAperture) var _objc_aperture: Float { lensAperture }
    @objc(ISO) var _objc_iso: Float { iso }
    @objc(lensPosition) var _objc_lensPosition: Float { lensPosition }
    @objc(exposureTargetBias) var _objc_bias: Float { exposureTargetBias }
    @objc(minExposureTargetBias) var _objc_minBias: Float { minExposureTargetBias }
    @objc(maxExposureTargetBias) var _objc_maxBias: Float { maxExposureTargetBias }
    @objc(isAdjustingFocus) var _objc_adjustingFocus: Bool { isAdjustingFocus }
    @objc(isAdjustingExposure) var _objc_adjustingExposure: Bool { isAdjustingExposure }
    @objc(isAdjustingWhiteBalance) var _objc_adjustingWB: Bool { isAdjustingWhiteBalance }
    @objc(activeFormat) var _objc_activeFormat: Format { get { activeFormat } set { activeFormat = newValue } }
    @objc(formats) var _objc_formats: [Format] { formats }
    @objc(lockForConfiguration:) func _objc_lock() throws { try lockForConfiguration() }
    @objc(unlockForConfiguration) func _objc_unlock() { unlockForConfiguration() }
    @objc(_isim_getTime:out:) func _isimGetTime(_ which: Int, _ out: UnsafeMutableRawPointer) {
        [activeVideoMinFrameDuration, activeVideoMaxFrameDuration, exposureDuration, activeMaxExposureDuration][which]._isimStore(out)
    }
    @objc(_isim_setTime:value:) func _isimSetTime(_ which: Int, _ p: UnsafeRawPointer) {
        let t = CMTime(_isimRaw: p)
        switch which { case 0: activeVideoMinFrameDuration = t; case 1: activeVideoMaxFrameDuration = t; default: activeMaxExposureDuration = t }
    }
    @objc(_isim_setExposureBias:completion:) func _isimSetBias(_ b: Float, _ h: ((UnsafeRawPointer) -> Void)?) {
        setExposureTargetBias(b) { t in withUnsafePointer(to: t) { h?(UnsafeRawPointer($0)) } }
    }
    @objc(_isim_setFocusLocked:completion:) func _isimSetFocus(_ p: Float, _ h: ((UnsafeRawPointer) -> Void)?) {
        setFocusModeLocked(lensPosition: p) { t in withUnsafePointer(to: t) { h?(UnsafeRawPointer($0)) } }
    }
}
extension AVCaptureDevice.Format {
    @objc(mediaType) var _objc_mediaType: String { mediaType.rawValue }
    @objc(videoMaxZoomFactor) var _objc_maxZoom: CGFloat { videoMaxZoomFactor }
    @objc(videoFieldOfView) var _objc_fov: Float { videoFieldOfView }
    @objc(minISO) var _objc_minISO: Float { minISO }
    @objc(maxISO) var _objc_maxISO: Float { maxISO }
    @objc(isVideoHDRSupported) var _objc_hdr: Bool { isVideoHDRSupported }
    @objc(isMultiCamSupported) var _objc_multiCam: Bool { isMultiCamSupported }
    @objc(supportedDepthDataFormats) var _objc_depthFormats: [AVCaptureDevice.Format] { supportedDepthDataFormats }
    @objc(_isim_width) var _isimWidth: Int32 { formatDescription.dimensions.width }
    @objc(_isim_height) var _isimHeight: Int32 { formatDescription.dimensions.height }
}
extension AVCaptureDevice.DiscoverySession {
    @objc(discoverySessionWithDeviceTypes:mediaType:position:) class func _objc_make(_ types: [String], _ media: String?, _ pos: AVCaptureDevice.Position)
        -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(deviceTypes: types.map { AVCaptureDevice.DeviceType(rawValue: $0) }, mediaType: media.map { AVMediaType(rawValue: $0) },
                                         position: pos)
    }
    @objc(devices) var _objc_devices: [AVCaptureDevice] { devices }
}

// MARK: inputs, connections, sessions

extension AVCaptureInput {
    @objc(ports) var _objc_ports: [Port] { ports }
}
extension AVCaptureInput.Port {
    @objc(mediaType) var _objc_mediaType: String { mediaType.rawValue }
    @objc(isEnabled) var _objc_enabled: Bool { get { isEnabled } set { isEnabled = newValue } }
}
extension AVCaptureDeviceInput {
    @objc(deviceInputWithDevice:error:) class func _objc_input(_ d: AVCaptureDevice) throws -> AVCaptureDeviceInput { try AVCaptureDeviceInput(device: d) }
    @objc(initWithDevice:error:) convenience init(_objcDevice d: AVCaptureDevice) throws { try self.init(device: d) }
    @objc(device) var _objc_device: AVCaptureDevice { device }
}
extension AVCaptureConnection {
    @objc(inputPorts) var _objc_inputPorts: [AVCaptureInput.Port] { inputPorts }
    @objc(output) var _objc_output: AVCaptureOutput? { output }
    @objc(videoPreviewLayer) var _objc_layer: AVCaptureVideoPreviewLayer? { videoPreviewLayer }
    @objc(isEnabled) var _objc_enabled: Bool { get { isEnabled } set { isEnabled = newValue } }
    @objc(isActive) var _objc_active: Bool { isActive }
    @objc(videoOrientation) var _objc_orientation: AVCaptureVideoOrientation { get { videoOrientation } set { videoOrientation = newValue } }
    @objc(isVideoOrientationSupported) var _objc_orientationSupported: Bool { isVideoOrientationSupported }
    @objc(videoRotationAngle) var _objc_rotation: CGFloat { get { videoRotationAngle } set { videoRotationAngle = newValue } }
    @objc(isVideoRotationAngleSupported:) func _objc_rotationSupported(_ a: CGFloat) -> Bool { isVideoRotationAngleSupported(a) }
    @objc(isVideoMirrored) var _objc_mirrored: Bool { get { isVideoMirrored } set { isVideoMirrored = newValue } }
    @objc(isVideoMirroringSupported) var _objc_mirroringSupported: Bool { isVideoMirroringSupported }
    @objc(automaticallyAdjustsVideoMirroring) var _objc_autoMirror: Bool { get { automaticallyAdjustsVideoMirroring } set { automaticallyAdjustsVideoMirroring = newValue } }
    @objc(preferredVideoStabilizationMode) var _objc_stab: AVCaptureVideoStabilizationMode { get { preferredVideoStabilizationMode } set { preferredVideoStabilizationMode = newValue } }
    @objc(isVideoStabilizationSupported) var _objc_stabSupported: Bool { isVideoStabilizationSupported }
}
extension AVCaptureSession {
    @objc(sessionPreset) var _objc_preset: String { get { sessionPreset.rawValue } set { sessionPreset = Preset(rawValue: newValue) } }
    @objc(canSetSessionPreset:) func _objc_canSet(_ p: String) -> Bool { canSetSessionPreset(Preset(rawValue: p)) }
    @objc(inputs) var _objc_inputs: [AVCaptureInput] { inputs }
    @objc(outputs) var _objc_outputs: [AVCaptureOutput] { outputs }
    @objc(connections) var _objc_connections: [AVCaptureConnection] { connections }
    @objc(canAddInput:) func _objc_canAddInput(_ i: AVCaptureInput) -> Bool { canAddInput(i) }
    @objc(addInput:) func _objc_addInput(_ i: AVCaptureInput) { addInput(i) }
    @objc(removeInput:) func _objc_removeInput(_ i: AVCaptureInput) { removeInput(i) }
    @objc(canAddOutput:) func _objc_canAddOutput(_ o: AVCaptureOutput) -> Bool { canAddOutput(o) }
    @objc(addOutput:) func _objc_addOutput(_ o: AVCaptureOutput) { addOutput(o) }
    @objc(removeOutput:) func _objc_removeOutput(_ o: AVCaptureOutput) { removeOutput(o) }
    @objc(addInputWithNoConnections:) func _objc_addInputNC(_ i: AVCaptureInput) { addInputWithNoConnections(i) }
    @objc(addOutputWithNoConnections:) func _objc_addOutputNC(_ o: AVCaptureOutput) { addOutputWithNoConnections(o) }
    @objc(canAddConnection:) func _objc_canAddConnection(_ c: AVCaptureConnection) -> Bool { canAddConnection(c) }
    @objc(addConnection:) func _objc_addConnection(_ c: AVCaptureConnection) { addConnection(c) }
    @objc(removeConnection:) func _objc_removeConnection(_ c: AVCaptureConnection) { removeConnection(c) }
    @objc(beginConfiguration) func _objc_begin() { beginConfiguration() }
    @objc(commitConfiguration) func _objc_commit() { commitConfiguration() }
    @objc(startRunning) func _objc_start() { startRunning() }
    @objc(stopRunning) func _objc_stop() { stopRunning() }
    @objc(isRunning) var _objc_running: Bool { isRunning }
    @objc(isInterrupted) var _objc_interrupted: Bool { isInterrupted }
    @objc(automaticallyConfiguresApplicationAudioSession) var _objc_autoAudio: Bool {
        get { automaticallyConfiguresApplicationAudioSession } set { automaticallyConfiguresApplicationAudioSession = newValue }
    }
    @objc(hardwareCost) var _objc_hardwareCost: Float { hardwareCost }
}
extension AVCaptureMultiCamSession {
    @objc(isMultiCamSupported) class var _objc_supported: Bool { isMultiCamSupported }
    @objc(systemPressureCost) var _objc_pressure: Float { systemPressureCost }
}
extension AVCaptureVideoPreviewLayer {
    @objc(layerWithSession:) class func _objc_layer(_ s: AVCaptureSession) -> AVCaptureVideoPreviewLayer { AVCaptureVideoPreviewLayer(session: s) }
    @objc(initWithSession:) convenience init(_objcSession s: AVCaptureSession) { self.init(session: s) }
    @objc(session) var _objc_session: AVCaptureSession? { get { session } set { session = newValue } }
    @objc(connection) var _objc_connection: AVCaptureConnection? { connection }
    @objc(videoGravity) var _objc_gravity: String { get { videoGravity.rawValue } set { videoGravity = AVLayerVideoGravity(rawValue: newValue) } }
    @objc(isPreviewing) var _objc_previewing: Bool { isPreviewing }
    @objc(captureDevicePointOfInterestForPoint:) func _objc_devicePoint(_ p: CGPoint) -> CGPoint { captureDevicePointConverted(fromLayerPoint: p) }
    @objc(pointForCaptureDevicePointOfInterest:) func _objc_layerPoint(_ p: CGPoint) -> CGPoint { layerPointConverted(fromCaptureDevicePoint: p) }
    @objc(transformedMetadataObjectForMetadataObject:) func _objc_transformed(_ o: AVMetadataObject) -> AVMetadataObject? { transformedMetadataObject(for: o) }
}

// MARK: outputs

extension AVCaptureOutput {
    @objc(connections) var _objc_connections: [AVCaptureConnection] { connections }
    @objc(connectionWithMediaType:) func _objc_connection(_ type: String) -> AVCaptureConnection? { connection(with: AVMediaType(rawValue: type)) }
}
extension AVCaptureVideoDataOutput {
    @objc(setSampleBufferDelegate:queue:) func _objc_setDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCSampleBufferDelegate($0, q) }
        _isimKeep(self, a)
        setSampleBufferDelegate(a, queue: nil)
    }
    @objc(sampleBufferDelegate) var _objc_delegate: NSObject? { (sampleBufferDelegate as? _ObjCSampleBufferDelegate)?.target }
    @objc(sampleBufferCallbackQueue) var _objc_queue: dispatch_queue_t? { (sampleBufferDelegate as? _ObjCSampleBufferDelegate)?.queue }
    @objc(videoSettings) var _objc_settings: [String: Any]? { get { videoSettings } set { videoSettings = newValue ?? [:] } }
    @objc(alwaysDiscardsLateVideoFrames) var _objc_discards: Bool { get { alwaysDiscardsLateVideoFrames } set { alwaysDiscardsLateVideoFrames = newValue } }
    @objc(availableVideoCVPixelFormatTypes) var _objc_formats: [NSNumber] { availableVideoPixelFormatTypes.map { NSNumber(value: $0) } }
    @objc(recommendedVideoSettingsForAssetWriterWithOutputFileType:) func _objc_recommended(_ ft: String) -> [String: Any]? {
        recommendedVideoSettingsForAssetWriter(writingTo: AVFileType(rawValue: ft))
    }
}
extension AVCaptureAudioDataOutput {
    @objc(setSampleBufferDelegate:queue:) func _objc_setDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCSampleBufferDelegate($0, q) }
        _isimKeep(self, a)
        setSampleBufferDelegate(a, queue: nil)
    }
}
extension AVCaptureMetadataOutput {
    @objc(setMetadataObjectsDelegate:queue:) func _objc_setDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCMetadataDelegate($0, q) }
        _isimKeep(self, a)
        setMetadataObjectsDelegate(a, queue: nil)
    }
    @objc(availableMetadataObjectTypes) var _objc_available: [String] { availableMetadataObjectTypes.map(\.rawValue) }
    @objc(metadataObjectTypes) var _objc_types: [String] {
        get { metadataObjectTypes.map(\.rawValue) } set { metadataObjectTypes = newValue.map { AVMetadataObject.ObjectType(rawValue: $0) } }
    }
    @objc(rectOfInterest) var _objc_rect: CGRect { get { rectOfInterest } set { rectOfInterest = newValue } }
}
extension AVMetadataObject {
    @objc(type) var _objc_type: String { type.rawValue }
    @objc(bounds) var _objc_bounds: CGRect { bounds }
}
extension AVMetadataMachineReadableCodeObject {
    @objc(stringValue) var _objc_string: String? { stringValue }
    @objc(corners) var _objc_corners: [NSDictionary] { corners.map { ["X": $0.x, "Y": $0.y] as NSDictionary } }
}
extension AVCaptureFileOutput {
    @objc(startRecordingToOutputFileURL:recordingDelegate:) func _objc_start(_ url: URL, _ d: NSObject) {
        let a = _ObjCRecordingDelegate(d)
        _isimKeep(self, a)                                   // the output holds its delegate weakly
        startRecording(to: url, recordingDelegate: a)
    }
    @objc(stopRecording) func _objc_stop() { stopRecording() }
    @objc(outputFileURL) var _objc_url: URL? { outputFileURL }
    @objc(isRecordingPaused) var _objc_paused: Bool { isRecordingPaused }
    @objc(pauseRecording) func _objc_pause() { pauseRecording() }
    @objc(resumeRecording) func _objc_resume() { resumeRecording() }
    @objc(recordedFileSize) var _objc_size: Int64 { recordedFileSize }
    @objc(maxRecordedFileSize) var _objc_maxSize: Int64 { get { maxRecordedFileSize } set { maxRecordedFileSize = newValue } }
    @objc(_isim_recordedDuration:) func _isimRecorded(_ out: UnsafeMutableRawPointer) { recordedDuration._isimStore(out) }
    @objc(_isim_maxRecordedDuration:) func _isimMax(_ out: UnsafeMutableRawPointer) { maxRecordedDuration._isimStore(out) }
    @objc(_isim_setMaxRecordedDuration:) func _isimSetMax(_ p: UnsafeRawPointer) { maxRecordedDuration = CMTime(_isimRaw: p) }
}
extension AVCaptureMovieFileOutput {
    @objc(isRecording) var _objc_recording: Bool { isRecording }
    @objc(availableVideoCodecTypes) var _objc_codecs: [String] { availableVideoCodecTypes.map(\.rawValue) }
    @objc(outputSettingsForConnection:) func _objc_settings(_ c: AVCaptureConnection) -> [String: Any] { outputSettings(for: c) }
    @objc(setOutputSettings:forConnection:) func _objc_setSettings(_ s: [String: Any]?, _ c: AVCaptureConnection) { setOutputSettings(s, for: c) }
}

// MARK: photos

extension AVCapturePhotoSettings {
    @objc(photoSettings) class func _objc_settings() -> AVCapturePhotoSettings { AVCapturePhotoSettings() }
    @objc(photoSettingsWithFormat:) class func _objc_settings(_ f: [String: Any]?) -> AVCapturePhotoSettings { AVCapturePhotoSettings(format: f) }
    @objc(photoSettingsWithRawPixelFormatType:) class func _objc_raw(_ t: OSType) -> AVCapturePhotoSettings { AVCapturePhotoSettings(rawPixelFormatType: t) }
    @objc(photoSettingsFromPhotoSettings:) class func _objc_from(_ s: AVCapturePhotoSettings) -> AVCapturePhotoSettings { AVCapturePhotoSettings(from: s) }
    @objc(uniqueID) var _objc_id: Int64 { uniqueID }
    @objc(format) var _objc_format: [String: Any]? { format }
    @objc(rawPhotoPixelFormatType) var _objc_raw: OSType { rawPhotoPixelFormatType }
    @objc(flashMode) var _objc_flash: AVCaptureDevice.FlashMode { get { flashMode } set { flashMode = newValue } }
    @objc(photoQualityPrioritization) var _objc_quality: AVCapturePhotoOutput.QualityPrioritization {
        get { photoQualityPrioritization } set { photoQualityPrioritization = newValue }
    }
    @objc(isDepthDataDeliveryEnabled) var _objc_depth: Bool { get { isDepthDataDeliveryEnabled } set { isDepthDataDeliveryEnabled = newValue } }
    @objc(isPortraitEffectsMatteDeliveryEnabled) var _objc_matte: Bool { get { isPortraitEffectsMatteDeliveryEnabled } set { isPortraitEffectsMatteDeliveryEnabled = newValue } }
    @objc(isCameraCalibrationDataDeliveryEnabled) var _objc_calibration: Bool {
        get { isCameraCalibrationDataDeliveryEnabled } set { isCameraCalibrationDataDeliveryEnabled = newValue }
    }
    @objc(enabledSemanticSegmentationMatteTypes) var _objc_semantic: [String] {
        get { enabledSemanticSegmentationMatteTypes.map(\.rawValue) } set { enabledSemanticSegmentationMatteTypes = newValue.map { .init(rawValue: $0) } }
    }
    @objc(previewPhotoFormat) var _objc_preview: [String: Any]? { get { previewPhotoFormat } set { previewPhotoFormat = newValue } }
    @objc(metadata) var _objc_metadata: [String: Any] { get { metadata } set { metadata = newValue } }
    @objc(livePhotoMovieFileURL) var _objc_live: URL? { get { livePhotoMovieFileURL } set { livePhotoMovieFileURL = newValue } }
    @objc(isShutterSoundSuppressionEnabled) var _objc_shutter: Bool { get { isShutterSoundSuppressionEnabled } set { isShutterSoundSuppressionEnabled = newValue } }
    @objc(_isim_maxPhotoWidth) var _isimMaxW: Int32 { maxPhotoDimensions.width }
    @objc(_isim_maxPhotoHeight) var _isimMaxH: Int32 { maxPhotoDimensions.height }
    @objc(_isim_setMaxPhotoWidth:height:) func _isimSetMax(_ w: Int32, _ h: Int32) { maxPhotoDimensions = CMVideoDimensions(width: w, height: h) }
}
extension AVCaptureResolvedPhotoSettings {
    @objc(uniqueID) var _objc_id: Int64 { uniqueID }
    @objc(isFlashEnabled) var _objc_flash: Bool { isFlashEnabled }
    @objc(expectedPhotoCount) var _objc_count: Int { expectedPhotoCount }
    @objc(_isim_photoWidth) var _isimW: Int32 { photoDimensions.width }
    @objc(_isim_photoHeight) var _isimH: Int32 { photoDimensions.height }
}
extension AVCapturePhoto {
    @objc(_isim_timestamp:) func _isimTimestamp(_ out: UnsafeMutableRawPointer) { timestamp._isimStore(out) }
    @objc(resolvedSettings) var _objc_resolved: AVCaptureResolvedPhotoSettings { resolvedSettings }
    @objc(_isim_pixelBuffer) var _isimPixelBuffer: UnsafeMutableRawPointer? { _isimOpaque(pixelBuffer) }
    @objc(_isim_previewPixelBuffer) var _isimPreview: UnsafeMutableRawPointer? { _isimOpaque(previewPixelBuffer) }
    @objc(photoCount) var _objc_count: Int { photoCount }
    @objc(isRawPhoto) var _objc_raw: Bool { isRawPhoto }
    @objc(metadata) var _objc_metadata: [String: Any] { metadata }
    @objc(depthData) var _objc_depth: AVDepthData? { depthData }
    @objc(portraitEffectsMatte) var _objc_matte: AVPortraitEffectsMatte? { portraitEffectsMatte }
    @objc(semanticSegmentationMatteForType:) func _objc_semantic(_ t: String) -> AVSemanticSegmentationMatte? { semanticSegmentationMatte(for: .init(rawValue: t)) }
    @objc(cameraCalibrationData) var _objc_calibration: AVCameraCalibrationData? { cameraCalibrationData }
    @objc(fileDataRepresentation) func _objc_data() -> Data? { fileDataRepresentation() }
    @objc(CGImageRepresentation) func _objc_cg() -> CGImage? { cgImageRepresentation() }
    @objc(previewCGImageRepresentation) func _objc_previewCG() -> CGImage? { previewCGImageRepresentation() }
}
extension AVCapturePhotoOutput {
    @objc(capturePhotoWithSettings:delegate:) func _objc_capture(_ s: AVCapturePhotoSettings, _ d: NSObject) { capturePhoto(with: s, delegate: _ObjCPhotoDelegate(d)) }
    @objc(availablePhotoCodecTypes) var _objc_codecs: [String] { availablePhotoCodecTypes.map(\.rawValue) }
    @objc(availablePhotoPixelFormatTypes) var _objc_pixelFormats: [NSNumber] { availablePhotoPixelFormatTypes.map { NSNumber(value: $0) } }
    @objc(availablePhotoFileTypes) var _objc_fileTypes: [String] { availablePhotoFileTypes.map(\.rawValue) }
    @objc(supportedFlashModes) var _objc_flash: [NSNumber] { supportedFlashModes.map { NSNumber(value: $0.rawValue) } }
    @objc(maxPhotoQualityPrioritization) var _objc_quality: QualityPrioritization { get { maxPhotoQualityPrioritization } set { maxPhotoQualityPrioritization = newValue } }
    @objc(isLivePhotoCaptureSupported) var _objc_liveSupported: Bool { isLivePhotoCaptureSupported }
    @objc(isLivePhotoCaptureEnabled) var _objc_live: Bool { get { isLivePhotoCaptureEnabled } set { isLivePhotoCaptureEnabled = newValue } }
    @objc(isDepthDataDeliverySupported) var _objc_depthSupported: Bool { isDepthDataDeliverySupported }
    @objc(isDepthDataDeliveryEnabled) var _objc_depth: Bool { get { isDepthDataDeliveryEnabled } set { isDepthDataDeliveryEnabled = newValue } }
    @objc(isPortraitEffectsMatteDeliverySupported) var _objc_matteSupported: Bool { isPortraitEffectsMatteDeliverySupported }
    @objc(isPortraitEffectsMatteDeliveryEnabled) var _objc_matte: Bool { get { isPortraitEffectsMatteDeliveryEnabled } set { isPortraitEffectsMatteDeliveryEnabled = newValue } }
    @objc(isCameraCalibrationDataDeliverySupported) var _objc_calibrationSupported: Bool { isCameraCalibrationDataDeliverySupported }
    @objc(availableSemanticSegmentationMatteTypes) var _objc_semanticAvailable: [String] { availableSemanticSegmentationMatteTypes.map(\.rawValue) }
    @objc(enabledSemanticSegmentationMatteTypes) var _objc_semantic: [String] {
        get { enabledSemanticSegmentationMatteTypes.map(\.rawValue) } set { enabledSemanticSegmentationMatteTypes = newValue.map { .init(rawValue: $0) } }
    }
    @objc(captureReadiness) var _objc_readiness: CaptureReadiness { captureReadiness }
    @objc(maxBracketedCapturePhotoCount) var _objc_maxBracket: Int { maxBracketedCapturePhotoCount }
    @objc(isZeroShutterLagEnabled) var _objc_zsl: Bool { get { isZeroShutterLagEnabled } set { isZeroShutterLagEnabled = newValue } }
    @objc(_isim_maxPhotoWidth) var _isimMaxW: Int32 { maxPhotoDimensions.width }
    @objc(_isim_maxPhotoHeight) var _isimMaxH: Int32 { maxPhotoDimensions.height }
    @objc(_isim_setMaxPhotoWidth:height:) func _isimSetMax(_ w: Int32, _ h: Int32) { maxPhotoDimensions = CMVideoDimensions(width: w, height: h) }
}

// MARK: mattes and calibration

extension AVPortraitEffectsMatte {
    @objc(_isim_mattingImage) var _isimImage: UnsafeMutableRawPointer? { _isimOpaque(mattingImage) }
    @objc(pixelFormatType) var _objc_format: OSType { pixelFormatType }
}
extension AVSemanticSegmentationMatte {
    @objc(matteType) var _objc_type: String { matteType.rawValue }
    @objc(_isim_mattingImage) var _isimImage: UnsafeMutableRawPointer? { _isimOpaque(mattingImage) }
    @objc(pixelFormatType) var _objc_format: OSType { pixelFormatType }
}
extension AVCameraCalibrationData {
    @objc(pixelSize) var _objc_pixelSize: Float { pixelSize }
    @objc(intrinsicMatrixReferenceDimensions) var _objc_refDims: CGSize { intrinsicMatrixReferenceDimensions }
    @objc(lensDistortionCenter) var _objc_center: CGPoint { lensDistortionCenter }
    @objc(lensDistortionLookupTable) var _objc_lut: Data? { lensDistortionLookupTable }
    @objc(inverseLensDistortionLookupTable) var _objc_invLut: Data? { inverseLensDistortionLookupTable }
}
