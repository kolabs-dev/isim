// isim AVFoundation capture (self-authored, iOS API names). Like the iOS Simulator there are no cameras:
// AVCaptureDevice.default(for: .video) is nil and discovery sessions find nothing; the camera/microphone permission
// prompts still work (remembered per app; ISIM_CAMERA_PERMISSION / ISIM_MICROPHONE_PERMISSION = allow|deny).
// Adapted: isim has no microphone capture either (the Simulator uses the Mac's microphone).
// Sessions accept configuration and run without inputs; nothing is ever delivered.
import UIKit

extension AVMediaType {
    public static let depthData = AVMediaType("dpth")     /* the rest: AVAsset.swift */
}

@objc public enum AVAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized }

public struct AVError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable { case unknown = -11800, deviceNotConnected = -11814, applicationIsNotAuthorizedToUseDevice = -11852, sessionNotRunning = -11803 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { AVFoundationErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorDescription: String? { code == .deviceNotConnected ? "Cannot Record" : "The operation could not be completed" }
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
    @objc public enum FlashMode: Int, Sendable { case off = 0, on, auto }
    @objc public enum TorchMode: Int, Sendable { case off = 0, on, auto }

    public final class DiscoverySession: NSObject, @unchecked Sendable {
        public init(deviceTypes: [DeviceType], mediaType: AVMediaType?, position: Position) {}
        public var devices: [AVCaptureDevice] { [] }
        public var supportedMultiCamDeviceSets: [Set<AVCaptureDevice>] { [] }
    }

    open class func `default`(for mediaType: AVMediaType) -> AVCaptureDevice? { nil }
    open class func `default`(_ deviceType: DeviceType, for mediaType: AVMediaType?, position: Position) -> AVCaptureDevice? { nil }
    open class func device(withUniqueID deviceUniqueID: String) -> AVCaptureDevice? { nil }
    @available(*, deprecated) open class func devices(for mediaType: AVMediaType) -> [AVCaptureDevice] { [] }
    @available(*, deprecated) open class func devices() -> [AVCaptureDevice] { [] }

    open var uniqueID: String { "" }
    open var localizedName: String { "" }
    open var position: Position { .unspecified }
    open var deviceType: DeviceType { .builtInWideAngleCamera }
    open var isConnected: Bool { false }
    open var hasTorch: Bool { false }
    open var hasFlash: Bool { false }
    open func hasMediaType(_ mediaType: AVMediaType) -> Bool { false }
    open func lockForConfiguration() throws { throw AVError(.deviceNotConnected) }
    open func unlockForConfiguration() {}

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
            func answer(_ ok: Bool) {
                _Privacy.store(key(mediaType), (ok ? AVAuthorizationStatus.authorized : .denied).rawValue)
                NSLog("isim AVFoundation: %@ access %@ for %@", audio ? "microphone" : "camera", ok ? "allowed" : "denied", _Privacy.appName)
                _Privacy.reply { handler(ok) }
            }
            if let sc = _Privacy.scripted(audio ? "MICROPHONE" : "CAMERA") { answer(!(sc == "deny" || sc == "denied" || sc == "no" || sc == "0")); return }
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access the \(audio ? "Microphone" : "Camera")", purpose,
                           [("Don’t Allow", .default), (_Privacy.osMajor >= 17 ? "Allow" : "OK", .default)]) { answer($0 == 1) }
        }
    }
    open class func requestAccess(for mediaType: AVMediaType) async -> Bool {
        await withCheckedContinuation { k in requestAccess(for: mediaType) { k.resume(returning: $0) } }
    }
}

open class AVCaptureInput: NSObject, @unchecked Sendable {}
open class AVCaptureDeviceInput: AVCaptureInput, @unchecked Sendable {
    public let device: AVCaptureDevice
    public init(device: AVCaptureDevice) throws { self.device = device; super.init(); throw AVError(.deviceNotConnected) }
}
open class AVCaptureOutput: NSObject, @unchecked Sendable {}
open class AVCapturePhotoOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var isHighResolutionCaptureEnabled = false
    open var maxPhotoQualityPrioritization: Int = 0
}
open class AVCaptureVideoDataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var alwaysDiscardsLateVideoFrames = true
    open var videoSettings: [String: Any]! = [:]
}
open class AVCaptureMovieFileOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var isRecording: Bool { false }
}
public protocol AVCaptureMetadataOutputObjectsDelegate: NSObjectProtocol {}
open class AVMetadataObject: NSObject, @unchecked Sendable {
    public struct ObjectType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let qr = ObjectType(rawValue: "org.iso.QRCode")
        public static let ean13 = ObjectType(rawValue: "org.gs1.EAN-13")
        public static let ean8 = ObjectType(rawValue: "org.gs1.EAN-8")
        public static let code128 = ObjectType(rawValue: "com.intermec.Code128")
        public static let code39 = ObjectType(rawValue: "org.iso.Code39")
        public static let upce = ObjectType(rawValue: "org.gs1.UPC-E")
        public static let pdf417 = ObjectType(rawValue: "org.iso.PDF417")
        public static let aztec = ObjectType(rawValue: "org.iso.Aztec")
        public static let dataMatrix = ObjectType(rawValue: "org.iso.DataMatrix")
        public static let face = ObjectType(rawValue: "face")
    }
    open var type: ObjectType { .qr }
    open var bounds: CGRect { .zero }
}
open class AVMetadataMachineReadableCodeObject: AVMetadataObject, @unchecked Sendable { open var stringValue: String? { nil } }
open class AVCaptureMetadataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    open var availableMetadataObjectTypes: [AVMetadataObject.ObjectType] { [] }
    open var metadataObjectTypes: [AVMetadataObject.ObjectType]! = []
    open var rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    open func setMetadataObjectsDelegate(_ objectsDelegate: AVCaptureMetadataOutputObjectsDelegate?, queue objectsCallbackQueue: DispatchQueue?) {}
}

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
        public static let inputPriority = Preset(rawValue: "AVCaptureSessionPresetInputPriority")
    }
    open var sessionPreset: Preset = .high
    open private(set) var inputs: [AVCaptureInput] = []
    open private(set) var outputs: [AVCaptureOutput] = []
    open private(set) var isRunning = false
    open var isInterrupted: Bool { false }
    public override init() { super.init() }
    open func canSetSessionPreset(_ preset: Preset) -> Bool { true }
    open func canAddInput(_ input: AVCaptureInput) -> Bool { false }
    open func addInput(_ input: AVCaptureInput) { NSLog("isim AVFoundation: -[AVCaptureSession addInput:] cannot add an input (no capture devices; iOS raises an exception)") }
    open func removeInput(_ input: AVCaptureInput) {}
    open func canAddOutput(_ output: AVCaptureOutput) -> Bool { !outputs.contains(output) }
    open func addOutput(_ output: AVCaptureOutput) { if canAddOutput(output) { outputs.append(output) } }
    open func removeOutput(_ output: AVCaptureOutput) { outputs.removeAll { $0 === output } }
    open func beginConfiguration() {}
    open func commitConfiguration() {}
    open func startRunning() {
        isRunning = true
        NSLog("isim AVFoundation: capture session started with no inputs (no cameras on this device, like the Simulator)")
    }
    open func stopRunning() { isRunning = false }
}

