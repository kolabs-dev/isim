// isim AVFoundation capture outputs (self-authored, iOS API names): AVCaptureOutput, AVCaptureVideoDataOutput,
// AVCaptureAudioDataOutput, AVCaptureMetadataOutput (codes, faces, bodies), AVCaptureFileOutput /
// AVCaptureMovieFileOutput (video and sound), AVCaptureDepthDataOutput and AVCaptureDataOutputSynchronizer.
// The session (Capture.swift) hands every camera frame and every run of microphone audio to the outputs connected to
// that camera / the microphone.
import UIKit
import AudioToolbox
import isim_host

open class AVCaptureOutput: NSObject, @unchecked Sendable {
    @objc public enum DataDroppedReason: Int, Sendable { case none = 0, lateData, outOfBuffers, discontinuity }
    weak var _session: AVCaptureSession?
    var _connections: [AVCaptureConnection] = []
    var _noConnections = false
    weak var _synchronizer: AVCaptureDataOutputSynchronizer?
    /// the media types this output takes from inputs
    var _accepts: [AVMediaType] { [.video] }
    open var connections: [AVCaptureConnection] { _connections }
    open func connection(with mediaType: AVMediaType) -> AVCaptureConnection? {
        _connections.first { c in c.inputPorts.contains { $0.mediaType == mediaType } }
    }
    var _connection: AVCaptureConnection? { connection(with: .video) ?? _connections.first }
    func _attached() {}
    /// a camera frame for one of this output's connections (camera thread); returns its synchronized data when synchronized
    func _frame(_ f: _Frame, connection: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? { nil }
    /// microphone audio for one of this output's connections (main thread): mono 16-bit samples at 48 kHz
    func _audio(_ samples: [Int16], time: CMTime, connection: AVCaptureConnection) {}
    open func transformedMetadataObject(for metadataObject: AVMetadataObject, connection: AVCaptureConnection) -> AVMetadataObject? { metadataObject }
    var _outputSize: CGSize {
        guard let d = _connection?._device else { return _CameraSource.size }
        let s = d.activeFormat.formatDescription.dimensions
        return CGSize(width: Int(s.width), height: Int(s.height))
    }
    /// output (pixel) coordinates -> metadata coordinates (normalized over the frame)
    open func metadataOutputRectConverted(fromOutputRect r: CGRect) -> CGRect {
        let s = _outputSize
        return CGRect(x: r.minX / s.width, y: r.minY / s.height, width: r.width / s.width, height: r.height / s.height)
    }
    open func outputRectConverted(fromMetadataOutputRect r: CGRect) -> CGRect {
        let s = _outputSize
        return CGRect(x: r.minX * s.width, y: r.minY * s.height, width: r.width * s.width, height: r.height * s.height)
    }
}

// MARK: - video data output

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
    open var deliversPreviewSizedOutputBuffers = false
    open var automaticallyConfiguresOutputBufferDimensions = true
    open var recommendedMediaTimeScaleForAssetWriter: CMTimeScale { 30 }
    open func setSampleBufferDelegate(_ d: AVCaptureVideoDataOutputSampleBufferDelegate?, queue: DispatchQueue?) {
        sampleBufferDelegate = d; sampleBufferCallbackQueue = queue
    }
    open func recommendedVideoSettingsForAssetWriter(writingTo outputFileType: AVFileType) -> [String: Any]? {
        recommendedVideoSettings(forVideoCodecType: .h264, assetWriterOutputFileType: outputFileType)
    }
    open func recommendedVideoSettings(forVideoCodecType codec: AVVideoCodecType, assetWriterOutputFileType: AVFileType) -> [String: Any]? {
        let s = _outputSize
        return [AVVideoCodecKey: codec.rawValue, AVVideoWidthKey: Int(s.width), AVVideoHeightKey: Int(s.height)]
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
    override func _frame(_ f: _Frame, connection conn: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard conn._carries(.video) else { return nil }
        let d = sampleBufferDelegate
        guard synchronized || d != nil else { return nil }
        _lock.lock(); let busy = _busy; if !busy && !synchronized { _busy = true }; _lock.unlock()
        let (px, w, h) = _transformBGRA(f.px, f.w, f.h, angle: conn.videoRotationAngle, mirror: conn.isVideoMirrored)
        guard let pb = px.withUnsafeBufferPointer({ _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: _pixelFormat) }) else { return nil }
        let sb = CMSampleBuffer(_imageBuffer: pb, presentationTime: f.time, duration: CMTime(value: 1, timescale: 30))
        if synchronized { return AVCaptureSynchronizedSampleBufferData(timestamp: f.time, sampleBuffer: sb, dropped: false, reason: .none) }
        guard let d else { return nil }
        if busy && alwaysDiscardsLateVideoFrames {
            (sampleBufferCallbackQueue ?? .main).async { d.captureOutput(self, didDrop: sb, from: conn) }
            return nil
        }
        (sampleBufferCallbackQueue ?? .main).async {
            d.captureOutput(self, didOutput: sb, from: conn)
            self._lock.lock(); self._busy = false; self._lock.unlock()
        }
        return nil
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

// MARK: - microphone and audio data output

/// The session's microphone: the simulated audio input (ISIM_AUDIO_INPUT; silence without it or without access),
/// mixed to mono 16-bit PCM at 48 kHz like an iPhone's built-in microphone, in buffers of 1024 frames.
final class _MicrophoneCapture: @unchecked Sendable {
    static let asbd = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
                                                  mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                  mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
    weak var session: AVCaptureSession?
    var frames: Int64 = 0
    var base: Double?
    var pending: [Int16] = []
    init(session: AVCaptureSession) { self.session = session }
    func start() { _IsimAudioInput.subscribe(self) { [weak self] x in self?.receive(x) } }
    func stop() { _IsimAudioInput.unsubscribe(self) }
    func receive(_ x: [Float]) {
        guard let session, session.isRunning else { return }
        let n = x.count / 2
        guard n > 0 else { return }
        var mono = [Int16](repeating: 0, count: n)
        var sum: Float = 0, peak: Float = 0
        for i in 0..<n {
            let v = max(-1, min(1, (x[2 * i] + x[2 * i + 1]) / 2))
            mono[i] = Int16((v * 32767).rounded())
            sum += v * v; peak = max(peak, abs(v))
        }
        let now = _captureHostTime()
        if base == nil { base = now - Double(n) / 48000 }
        // levels of every audio connection (dBFS; the peak is held for a second)
        let avg = Float(10 * log10(Double(max(1e-16, sum / Float(n))))), pk = Float(20 * log10(Double(max(1e-8, peak))))
        for o in session.outputs { for c in o._connections { for ch in c.audioChannels {
            ch.averagePowerLevel = max(-160, avg)
            if pk >= ch.peakHoldLevel || now - ch._peakTime > 1 { ch.peakHoldLevel = max(-160, pk); ch._peakTime = now }
        } } }
        pending += mono
        while pending.count >= 1024 {
            let chunk = Array(pending[0..<1024])
            pending.removeFirst(1024)
            let t = _captureTime(base! + Double(frames) / 48000)
            frames += 1024
            session._deliverAudio(chunk, time: t)
        }
    }
}
func _audioSampleBuffer(_ s: [Int16], time: CMTime) -> CMSampleBuffer {
    let bytes = s.withUnsafeBytes { Array($0) }
    return CMSampleBuffer(_audio: bytes, format: _MicrophoneCapture.asbd, presentationTime: time)
}

public protocol AVCaptureAudioDataOutputSampleBufferDelegate: NSObjectProtocol {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}
extension AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {}
}
/// Microphone audio as sample buffers: 1024 frames of mono 16-bit linear PCM at 48 kHz each.
open class AVCaptureAudioDataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    override var _accepts: [AVMediaType] { [.audio] }
    open private(set) weak var sampleBufferDelegate: AVCaptureAudioDataOutputSampleBufferDelegate?
    open private(set) var sampleBufferCallbackQueue: DispatchQueue?
    open func setSampleBufferDelegate(_ d: AVCaptureAudioDataOutputSampleBufferDelegate?, queue: DispatchQueue?) {
        sampleBufferDelegate = d; sampleBufferCallbackQueue = queue
    }
    open func recommendedAudioSettingsForAssetWriter(writingTo outputFileType: AVFileType) -> [String: Any]? {
        [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000]
    }
    override func _audio(_ samples: [Int16], time: CMTime, connection: AVCaptureConnection) {
        guard let d = sampleBufferDelegate else { return }
        let sb = _audioSampleBuffer(samples, time: time)
        (sampleBufferCallbackQueue ?? .main).async { d.captureOutput(self, didOutput: sb, from: connection) }
    }
}

// MARK: - metadata output (codes, faces, bodies)

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
        public static let gs1DataBarExpanded = ObjectType(rawValue: "org.gs1.GS1DataBarExpanded")
        public static let gs1DataBarLimited = ObjectType(rawValue: "org.gs1.GS1DataBarLimited")
        public static let pdf417 = ObjectType(rawValue: "org.iso.PDF417")
        public static let aztec = ObjectType(rawValue: "org.iso.Aztec")
        public static let dataMatrix = ObjectType(rawValue: "org.iso.DataMatrix")
        public static let microQR = ObjectType(rawValue: "org.iso.MicroQR")
        public static let microPDF417 = ObjectType(rawValue: "org.iso.MicroPDF417")
        public static let face = ObjectType(rawValue: "face")
        public static let humanBody = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-human-body")
        public static let humanFullBody = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-human-full-body")
        public static let catBody = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-cat-body")
        public static let dogBody = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-dog-body")
        public static let catHead = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-cat-head")
        public static let dogHead = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-dog-head")
        public static let salientObject = ObjectType(rawValue: "mdta/com.apple.quicktime.detected-salient-object")
    }
    let _type: ObjectType
    var _bounds: CGRect
    public let time: CMTime
    public let duration: CMTime
    init(type: ObjectType, bounds: CGRect, time: CMTime) { _type = type; _bounds = bounds; self.time = time; duration = .invalid }
    public override init() { _type = .qr; _bounds = .zero; time = .invalid; duration = .invalid; super.init() }
    open var type: ObjectType { _type }
    open var bounds: CGRect { _bounds }
    /// the same object with other bounds (preview-layer / output coordinate conversion)
    func _copy(bounds b: CGRect) -> AVMetadataObject { AVMetadataObject(type: _type, bounds: b, time: time) }
}
open class AVMetadataMachineReadableCodeObject: AVMetadataObject, @unchecked Sendable {
    let _string: String?
    var _corners: [CGPoint]
    let _descriptor: Data?
    init(type: ObjectType, bounds: CGRect, corners: [CGPoint], string: String?, time: CMTime, payload: Data? = nil) {
        _string = string; _corners = corners; _descriptor = payload
        super.init(type: type, bounds: bounds, time: time)
    }
    public override init() { _string = nil; _corners = []; _descriptor = nil; super.init() }
    open var stringValue: String? { _string }
    open var corners: [CGPoint] { _corners }
}
open class AVMetadataFaceObject: AVMetadataObject, @unchecked Sendable {
    public let faceID: Int
    public let hasRollAngle: Bool, rollAngle: CGFloat, hasYawAngle: Bool, yawAngle: CGFloat
    init(faceID: Int, bounds: CGRect, time: CMTime) {
        self.faceID = faceID; hasRollAngle = true; rollAngle = 0; hasYawAngle = true; yawAngle = 0
        super.init(type: .face, bounds: bounds, time: time)
    }
    override func _copy(bounds b: CGRect) -> AVMetadataObject { AVMetadataFaceObject(faceID: faceID, bounds: b, time: time) }
}
open class AVMetadataBodyObject: AVMetadataObject, @unchecked Sendable {
    public let bodyID: Int
    init(type: ObjectType, bodyID: Int, bounds: CGRect, time: CMTime) { self.bodyID = bodyID; super.init(type: type, bounds: bounds, time: time) }
    override func _copy(bounds b: CGRect) -> AVMetadataObject { Self._make(type, bodyID, b, time) }
    static func _make(_ t: ObjectType, _ id: Int, _ b: CGRect, _ time: CMTime) -> AVMetadataBodyObject {
        switch t {
        case .humanBody: return AVMetadataHumanBodyObject(type: t, bodyID: id, bounds: b, time: time)
        case .humanFullBody: return AVMetadataHumanFullBodyObject(type: t, bodyID: id, bounds: b, time: time)
        case .catBody: return AVMetadataCatBodyObject(type: t, bodyID: id, bounds: b, time: time)
        case .dogBody: return AVMetadataDogBodyObject(type: t, bodyID: id, bounds: b, time: time)
        case .catHead: return AVMetadataCatHeadObject(type: t, bodyID: id, bounds: b, time: time)
        default: return AVMetadataDogHeadObject(type: t, bodyID: id, bounds: b, time: time)
        }
    }
}
open class AVMetadataHumanBodyObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataHumanFullBodyObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataCatBodyObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataDogBodyObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataCatHeadObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataDogHeadObject: AVMetadataBodyObject, @unchecked Sendable {}
open class AVMetadataSalientObject: AVMetadataObject, @unchecked Sendable {
    public let objectID: Int
    init(objectID: Int, bounds: CGRect, time: CMTime) { self.objectID = objectID; super.init(type: .salientObject, bounds: bounds, time: time) }
    override func _copy(bounds b: CGRect) -> AVMetadataObject { AVMetadataSalientObject(objectID: objectID, bounds: b, time: time) }
}

/// zbar / zxing symbology names -> AVFoundation / Vision types
enum _Symbology {
    static let table: [(String, AVMetadataObject.ObjectType)] = [
        ("QR-Code", .qr), ("EAN-13", .ean13), ("EAN-8", .ean8), ("UPC-E", .upce), ("UPC-A", .ean13), ("ISBN-13", .ean13), ("ISBN-10", .ean13),
        ("CODE-128", .code128), ("CODE-39", .code39), ("CODE-93", .code93), ("I2/5", .interleaved2of5), ("Codabar", .codabar),
        ("DataBar", .gs1DataBar), ("DataBar-Exp", .gs1DataBarExpanded), ("PDF417", .pdf417),
        ("Aztec", .aztec), ("DataMatrix", .dataMatrix), ("MicroQR", .microQR)]
    static func type(_ name: String) -> AVMetadataObject.ObjectType? { table.first { $0.0 == name }?.1 }
    static let extended: [AVMetadataObject.ObjectType] = [.aztec, .dataMatrix, .microQR]
    static var supported: [AVMetadataObject.ObjectType] {
        (isim_vision_available(1) != 0 ? [.qr, .ean13, .ean8, .upce, .code128, .code39, .code39Mod43, .code93, .interleaved2of5, .itf14, .codabar,
                                          .gs1DataBar, .gs1DataBarExpanded, .pdf417] : [])
            + (isim_vision_available(3) != 0 ? extended : [])
    }
}
/// A barcode found by the host's zbar (or zxing-cpp): pixel corner points and the decoded bytes.
public struct _ISIMBarcode: Sendable {
    public let symbology: String
    public let points: [CGPoint]
    public let payload: [UInt8]
    public var string: String? { String(validatingUTF8: payload.map { CChar(bitPattern: $0) } + [0]) ?? String(decoding: payload, as: UTF8.self) }
    public static func scan(_ bgra: UnsafePointer<UInt8>, width: Int, height: Int) -> [_ISIMBarcode]? { scan(bgra, width: width, height: height, extended: false) }
    /// scans tightly packed BGRA pixels; nil when the host has no zbar (or, extended, no zxing either)
    public static func scan(_ bgra: UnsafePointer<UInt8>, width: Int, height: Int, extended: Bool) -> [_ISIMBarcode]? {
        guard let raw = isim_vision_barcodes_ex(bgra, Int32(width), Int32(height), Int32(width * 4), extended ? 1 : 0) else { return nil }
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

/// What is in the simulated camera's picture besides codes (ISIM_CAMERA_OBJECTS): faces, bodies, salient objects as
/// normalized rectangles, e.g. "face:0.3,0.2,0.2,0.25;humanBody:0.2,0.15,0.4,0.8".
enum _SceneObjects {
    static let names: [String: AVMetadataObject.ObjectType] = ["face": .face, "humanBody": .humanBody, "humanFullBody": .humanFullBody,
        "catBody": .catBody, "dogBody": .dogBody, "catHead": .catHead, "dogHead": .dogHead, "salientObject": .salientObject]
    static let declared: [(AVMetadataObject.ObjectType, CGRect)] = {
        guard let s = ProcessInfo.processInfo.environment["ISIM_CAMERA_OBJECTS"] else { return [] }
        return s.split(separator: ";").compactMap { item in
            let kv = item.split(separator: ":", maxSplits: 1)
            guard kv.count == 2, let t = names[kv[0].trimmingCharacters(in: .whitespaces)] else { return nil }
            let v = kv[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            return v.count == 4 ? (t, CGRect(x: v[0], y: v[1], width: v[2], height: v[3])) : nil
        }
    }()
    static var types: [AVMetadataObject.ObjectType] { [.face, .humanBody, .humanFullBody, .catBody, .dogBody, .catHead, .dogHead, .salientObject] }
    static func objects(_ wanted: [AVMetadataObject.ObjectType], time: CMTime, mirrored: Bool) -> [AVMetadataObject] {
        var ids: [AVMetadataObject.ObjectType: Int] = [:]
        return declared.compactMap { t, r0 in
            let id = (ids[t] ?? 0) + 1; ids[t] = id
            guard wanted.contains(t) else { return nil }
            let r = mirrored ? CGRect(x: 1 - r0.maxX, y: r0.minY, width: r0.width, height: r0.height) : r0
            switch t {
            case .face: return AVMetadataFaceObject(faceID: id, bounds: r, time: time)
            case .salientObject: return AVMetadataSalientObject(objectID: id, bounds: r, time: time)
            default: return AVMetadataBodyObject._make(t, id, r, time)
            }
        }
    }
}

open class AVCaptureMetadataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    override var _accepts: [AVMediaType] { [.metadataObject] }
    /// isim: what the host can detect (codes: libzbar, plus Aztec / Data Matrix / Micro QR with zxing-cpp's tools;
    /// faces, bodies and salient objects: the scene ISIM_CAMERA_OBJECTS declares), once a camera is connected
    open var availableMetadataObjectTypes: [AVMetadataObject.ObjectType] { _session?._hasCamera == true ? _Symbology.supported + _SceneObjects.types : [] }
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
    open var requiredMetadataObjectTypesForCinematicVideoCapture: [AVMetadataObject.ObjectType] { [] }
    open private(set) weak var metadataObjectsDelegate: AVCaptureMetadataOutputObjectsDelegate?
    open private(set) var metadataObjectsCallbackQueue: DispatchQueue?
    open func setMetadataObjectsDelegate(_ objectsDelegate: AVCaptureMetadataOutputObjectsDelegate?, queue objectsCallbackQueue: DispatchQueue?) {
        metadataObjectsDelegate = objectsDelegate; metadataObjectsCallbackQueue = objectsCallbackQueue
    }
    var _lastCount = 0
    var _frames = 0
    var _codes: [AVMetadataObject] = []
    var _scanning = false
    let _scanLock = NSLock()
    let _scanQueue = DispatchQueue(label: "isim.metadata-scan")
    var _latest: [AVMetadataObject] = []
    override func _frame(_ f: _Frame, connection conn: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard conn._carries(.metadataObject) || conn._carries(.video) else { return nil }
        guard let types = metadataObjectTypes, !types.isEmpty, synchronized || metadataObjectsDelegate != nil else { return nil }
        _frames += 1
        // codes: zbar about ten times a second; Aztec / Data Matrix / Micro QR (a zxing process each) three times
        let codes = types.contains { t in _Symbology.table.contains { $0.1 == t } }
        let extended = types.contains { _Symbology.extended.contains($0) } && _frames % 9 == 1
        _scanLock.lock(); let busy = _scanning; let scan = codes && !busy && (_frames % 3 == 1 || extended); if scan { _scanning = true }; _scanLock.unlock()
        if scan {
            _scanQueue.async { [self] in
                let found = f.px.withUnsafeBufferPointer { _ISIMBarcode.scan($0.baseAddress!, width: f.w, height: f.h, extended: extended) } ?? []
                var objs: [AVMetadataObject] = []
                for b in found {
                    guard let type = _Symbology.type(b.symbology), types.contains(type) else { continue }
                    let xs = b.points.map(\.x), ys = b.points.map(\.y)
                    guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { continue }
                    let w = Double(f.w), h = Double(f.h)
                    let bounds = CGRect(x: x0 / w, y: y0 / h, width: max(1, x1 - x0) / w, height: max(1, y1 - y0) / h)
                    guard rectOfInterest.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { continue }
                    let corners = b.points.count == 4 ? b.points.map { CGPoint(x: $0.x / w, y: $0.y / h) }
                                                      : [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.minY)]
                    objs.append(AVMetadataMachineReadableCodeObject(type: type, bounds: bounds, corners: corners, string: b.string, time: f.time, payload: Data(b.payload)))
                }
                _scanLock.lock()
                // a frame without the extended scan keeps the Aztec / Data Matrix / Micro QR codes the last one found
                if !extended { objs += _codes.filter { _Symbology.extended.contains($0.type) } }
                _codes = objs; _scanning = false
                _scanLock.unlock()
            }
        }
        guard _frames % 3 == 1 || synchronized else { return nil }
        let scene = _SceneObjects.objects(types, time: f.time, mirrored: false).filter { rectOfInterest.intersects($0.bounds) }
        _scanLock.lock(); let all = scene + _codes; _scanLock.unlock()
        _latest = all
        if synchronized { return AVCaptureSynchronizedMetadataObjectData(timestamp: f.time, objects: all) }
        if all.isEmpty && _lastCount == 0 { return nil }
        _lastCount = all.count
        if let d = metadataObjectsDelegate { (metadataObjectsCallbackQueue ?? .main).async { d.metadataOutput(self, didOutput: all, from: conn) } }
        return nil
    }
}

// MARK: - file outputs

public protocol AVCaptureFileOutputRecordingDelegate: NSObjectProtocol {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection])
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?)
}
extension AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}
}
/// Records the connected camera and microphone. Frames are spooled and encoded with the sound (AAC) by ffmpeg when the
/// recording stops (H.264 or HEVC; a microphone-only recording is an audio-only movie).
open class AVCaptureFileOutput: AVCaptureOutput, @unchecked Sendable {
    override var _accepts: [AVMediaType] { [.video, .audio] }
    open var maxRecordedDuration: CMTime = .invalid
    open var maxRecordedFileSize: Int64 = 0
    open var minFreeDiskSpaceLimit: Int64 = 0
    open internal(set) var outputFileURL: URL?
    var _isRecording: Bool { _recording }
    var _recording = false
    var _sink: _RawVideoSink?
    var _frames = 0
    var _audioSamples: [Int16] = []
    var _start = 0.0, _pausedAt: Double?, _pausedTotal = 0.0
    let _recLock = NSLock()
    weak var _delegate: AVCaptureFileOutputRecordingDelegate?
    /// time recorded so far (host time since the start, less pauses)
    open var recordedDuration: CMTime {
        guard _recording || _start > 0 else { return .zero }
        let end = _pausedAt ?? (_recording ? _captureHostTime() : _start + _lastDuration)
        return CMTime(seconds: max(0, end - _start - _pausedTotal), preferredTimescale: 600)
    }
    var _lastDuration = 0.0
    /// an estimate while recording (the movie is encoded when it stops): 10 Mbit/s of video, 128 kbit/s of sound
    open var recordedFileSize: Int64 {
        let s = recordedDuration.seconds
        return Int64(s * ((_sink != nil ? 10_000_000 : 0) + 128_000) / 8)
    }
    open var isRecordingPaused: Bool { _pausedAt != nil }
    open func pauseRecording() { _recLock.lock(); if _recording && _pausedAt == nil { _pausedAt = _captureHostTime() }; _recLock.unlock() }
    open func resumeRecording() {
        _recLock.lock(); if let p = _pausedAt { _pausedTotal += _captureHostTime() - p; _pausedAt = nil }; _recLock.unlock()
    }
    open func startRecording(to outputFileURL: URL, recordingDelegate delegate: AVCaptureFileOutputRecordingDelegate) {
        guard !_recording else {
            NSLog("isim AVFoundation: startRecording while already recording (iOS raises NSInvalidArgumentException)"); return
        }
        _recLock.lock()
        self.outputFileURL = outputFileURL; _delegate = delegate; _frames = 0; _audioSamples = []
        _start = _captureHostTime(); _pausedAt = nil; _pausedTotal = 0; _lastDuration = 0
        if let c = connection(with: .video), let d = c._device {
            let s = _session?._feed(for: c).map { CGSize(width: $0.width, height: $0.height) } ?? _CameraSource.size(d.position)
            let turned = Int((c.videoRotationAngle / 90).rounded()) % 2 != 0
            _sink = _RawVideoSink(width: Int(turned ? s.height : s.width), height: Int(turned ? s.width : s.height))
        } else { _sink = nil }
        _recording = true
        _recLock.unlock()
        let conns = connections
        DispatchQueue.main.async { delegate.fileOutput(self, didStartRecordingTo: outputFileURL, from: conns) }
    }
    open func stopRecording() { _stop(error: nil) }
    func _stop(error: NSError?) {
        _recLock.lock()
        guard _recording, let url = outputFileURL else { _recLock.unlock(); return }
        _recording = false
        _lastDuration = (_pausedAt ?? _captureHostTime()) - _start - _pausedTotal
        let sink = _sink, audio = _audioSamples, hasMic = connection(with: .audio) != nil
        _sink = nil; _audioSamples = []
        _recLock.unlock()
        let d = _delegate, conns = connections
        let codec = _codec, fps = sink.map { $0.times.count > 1 ? $0.fps : 30 } ?? 30
        DispatchQueue.global().async {
            let err = _writeMovie(video: sink, fps: fps, audio: hasMic ? audio : nil, to: url, codec: codec) ?? error
            DispatchQueue.main.async { d?.fileOutput(self, didFinishRecordingTo: url, from: conns, error: err) }
        }
    }
    var _codec: AVVideoCodecType { .h264 }
    override func _frame(_ f: _Frame, connection conn: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard conn._carries(.video) else { return nil }
        _recLock.lock()
        guard _recording, _pausedAt == nil, let s = _sink else { _recLock.unlock(); return nil }
        let t = f.host - _start - _pausedTotal
        _recLock.unlock()
        let (px, w, h) = _transformBGRA(f.px, f.w, f.h, angle: conn.videoRotationAngle, mirror: conn.isVideoMirrored)
        guard w == s.width, h == s.height else { return nil }
        px.withUnsafeBufferPointer { s.append($0.baseAddress!, time: t) }
        _frames += 1
        _checkLimits()
        return nil
    }
    override func _audio(_ samples: [Int16], time: CMTime, connection: AVCaptureConnection) {
        _recLock.lock()
        if _recording && _pausedAt == nil { _audioSamples += samples }
        _recLock.unlock()
        if _sink == nil { _checkLimits() }
    }
    func _checkLimits() {
        if maxRecordedDuration.isNumeric, maxRecordedDuration.seconds > 0, recordedDuration >= maxRecordedDuration {
            DispatchQueue.main.async { self._stop(error: _recordingLimitError(.maximumDurationReached)) }
        } else if maxRecordedFileSize > 0, recordedFileSize >= maxRecordedFileSize {
            DispatchQueue.main.async { self._stop(error: _recordingLimitError(.maximumFileSizeReached)) }
        }
    }
}
/// iOS ends a recording at its limit with this error; the movie is complete (AVErrorRecordingSuccessfullyFinishedKey)
func _recordingLimitError(_ code: AVError.Code) -> NSError {
    NSError(domain: AVFoundationErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: AVError(code).errorDescription ?? "Recording Stopped",
                                                                             AVErrorRecordingSuccessfullyFinishedKey: true])
}
/// Encodes spooled frames and microphone audio (mono 16-bit, 48 kHz) into a movie with ffmpeg.
func _writeMovie(video: _RawVideoSink?, fps: Double, audio: [Int16]?, to url: URL, codec: AVVideoCodecType, fileType: AVFileType? = nil) -> NSError? {
    try? FileManager.default.removeItem(at: url)
    var args = ["-y"]
    let hasVideo = (video?.times.count ?? 0) > 0
    if hasVideo, let v = video { args += v.inputArgs(fps: fps) }
    let apath = NSTemporaryDirectory() + "isim-mic-\(UUID().uuidString).raw"
    defer { try? FileManager.default.removeItem(atPath: apath) }
    let hasAudio = audio.map { !$0.isEmpty } ?? false
    if let a = audio, hasAudio {
        FileManager.default.createFile(atPath: apath, contents: a.withUnsafeBytes { Data($0) })
        args += ["-f", "s16le", "-ar", "48000", "-ac", "1", "-i", apath]
    }
    guard hasVideo || hasAudio else { return _avNSError(.noDataCaptured, "nothing was captured") }
    if hasVideo { args += _FFmpeg.videoCodecArgs(codec, bitrate: nil) }
    if hasAudio { args += ["-c:a", "aac", "-b:a", "128k"] }
    let type = fileType ?? (url.pathExtension.lowercased() == "mp4" ? .mp4 : url.pathExtension.lowercased() == "m4a" ? .m4a : .mov)
    args += ["-f", type._muxer.0, _path(url)]
    return _FFmpeg.run(args)
}
open class AVCaptureMovieFileOutput: AVCaptureFileOutput, @unchecked Sendable {
    public override init() { super.init() }
    /// HEVC when the host's ffmpeg has libx265 (like iPhones), else H.264
    open var availableVideoCodecTypes: [AVVideoCodecType] { _FFmpeg.hasHEVC ? [.hevc, .h264] : [.h264] }
    /// isim ABI: declared here since isim 0.2.0 (on iOS it comes from AVCaptureFileOutput)
    open var isRecording: Bool { _isRecording }
    open var movieFragmentInterval = CMTime(value: 10, timescale: 1)
    var _settings: [ObjectIdentifier: [String: Any]] = [:]
    open func outputSettings(for connection: AVCaptureConnection) -> [String: Any] {
        _settings[ObjectIdentifier(connection)] ?? (connection._carries(.audio) ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1]
                                                                           : [AVVideoCodecKey: (availableVideoCodecTypes.first ?? .h264).rawValue])
    }
    open func setOutputSettings(_ settings: [String: Any]?, for connection: AVCaptureConnection) { _settings[ObjectIdentifier(connection)] = settings }
    open func supportedOutputSettingsKeys(for connection: AVCaptureConnection) -> [String] {
        connection._carries(.audio) ? [AVFormatIDKey, AVSampleRateKey, AVNumberOfChannelsKey, AVEncoderBitRateKey] : [AVVideoCodecKey, AVVideoCompressionPropertiesKey]
    }
    open var isPrimaryConstituentDeviceSwitchingBehaviorForRecordingEnabled = true
    override var _codec: AVVideoCodecType {
        guard let c = connection(with: .video) else { return .h264 }
        let v = outputSettings(for: c)[AVVideoCodecKey]
        return (v as? String).map(AVVideoCodecType.init(rawValue:)) ?? (v as? AVVideoCodecType) ?? .h264
    }
}

// MARK: - depth

/// The simulated scene's depth (ISIM_CAMERA_DEPTH, else a flat wall at 1 m), as disparity (1/m) at a depth map size.
enum _DepthScene {
    static func size(for video: CGSize) -> CGSize {
        let sc = 320 / max(video.width, video.height)
        return CGSize(width: max(2, (video.width * sc).rounded()), height: max(2, (video.height * sc).rounded()))
    }
    nonisolated(unsafe) static var _source: (w: Int, h: Int, disparity: [Float])?
    nonisolated(unsafe) static var _loaded = false
    static let lock = NSLock()
    /// disparity from a grey level: white 2.0 (0.5 m) ... black 0.2 (5 m)
    static func disparity(_ v: UInt8) -> Float { 0.2 + Float(v) / 255 * 1.8 }
    static func source() -> (w: Int, h: Int, disparity: [Float])? {
        lock.lock(); defer { lock.unlock() }
        if _loaded { return _source }
        _loaded = true
        guard let path = ProcessInfo.processInfo.environment["ISIM_CAMERA_DEPTH"], !path.isEmpty else { return nil }
        let r: (w: Int, h: Int, disparity: [Float])? = _onMainSync {
            var fw = 0.0, fh = 0.0
            let hd = isim_image_load(path, &fw, &fh)
            guard hd > 0, fw >= 1, fh >= 1 else { NSLog("isim AVFoundation: cannot read ISIM_CAMERA_DEPTH=%@", path); return nil }
            defer { isim_image_free(hd) }
            let w = Int(fw), h = Int(fh)
            var px = [UInt8](repeating: 0, count: w * h * 4)
            _ = isim_image_read_bgra(hd, 0, 0, Int32(w), Int32(h), &px)
            var d = [Float](repeating: 1, count: w * h)
            for i in 0..<(w * h) { d[i] = disparity(UInt8((Int(px[i * 4]) * 29 + Int(px[i * 4 + 1]) * 150 + Int(px[i * 4 + 2]) * 77) >> 8)) }
            return (w, h, d)
        }
        _source = r
        return r
    }
    /// a depth map of `type` at `size` (mirrored for a mirrored connection)
    static func map(size: CGSize, type: OSType, mirrored: Bool) -> CVPixelBuffer? {
        let w = Int(size.width), h = Int(size.height)
        guard let b = CVBuffer(_width: w, height: h, format: type) else { return nil }
        let src = source()
        let depth = type == kCVPixelFormatType_DepthFloat16 || type == kCVPixelFormatType_DepthFloat32
        let half = type == kCVPixelFormatType_DepthFloat16 || type == kCVPixelFormatType_DisparityFloat16
        let base = CVPixelBufferGetBaseAddress(b)!, bpr = CVPixelBufferGetBytesPerRow(b)
        for y in 0..<h {
            for x in 0..<w {
                var disp: Float = 1
                if let s = src {
                    let sx = min(s.w - 1, (mirrored ? w - 1 - x : x) * s.w / w), sy = min(s.h - 1, y * s.h / h)
                    disp = s.disparity[sy * s.w + sx]
                }
                let v = depth ? 1 / disp : disp
                if half { (base + y * bpr + x * 2).storeBytes(of: _isimHalf(v), as: UInt16.self) }
                else { (base + y * bpr + x * 4).storeBytes(of: v, as: Float.self) }
            }
        }
        return b
    }
}

/// Depth (meters) or disparity (1/meters) for a frame, as a depth-capable camera measures it.
open class AVDepthData: NSObject, @unchecked Sendable {
    @objc public enum Accuracy: Int, Sendable { case relative = 0, absolute = 1 }
    @objc public enum Quality: Int, Sendable { case low = 0, high = 1 }
    public let depthDataMap: CVPixelBuffer
    public let isDepthDataFiltered: Bool
    public let depthDataAccuracy: Accuracy
    public let depthDataQuality: Quality
    init(map: CVPixelBuffer, filtered: Bool, accuracy: Accuracy = .relative, quality: Quality = .high) {
        depthDataMap = map; isDepthDataFiltered = filtered; depthDataAccuracy = accuracy; depthDataQuality = quality
    }
    open var depthDataType: OSType { depthDataMap._format }
    open var availableDepthDataTypes: [OSType] { [kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32] }
    open var cameraCalibrationData: AnyObject? { nil }
    func _value(_ x: Int, _ y: Int) -> Float {
        let base = CVPixelBufferGetBaseAddress(depthDataMap)!, bpr = CVPixelBufferGetBytesPerRow(depthDataMap)
        switch depthDataType {
        case kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DisparityFloat16:
            return _isimFloat((base + y * bpr + x * 2).load(as: UInt16.self))
        default: return (base + y * bpr + x * 4).load(as: Float.self)
        }
    }
    /// the same data as depth or disparity, 16- or 32-bit
    open func converting(toDepthDataType type: OSType) -> AVDepthData {
        guard availableDepthDataTypes.contains(type) else { return self }
        let w = CVPixelBufferGetWidth(depthDataMap), h = CVPixelBufferGetHeight(depthDataMap)
        guard type != depthDataType, let b = CVBuffer(_width: w, height: h, format: type) else { return self }
        let fromDepth = depthDataType == kCVPixelFormatType_DepthFloat16 || depthDataType == kCVPixelFormatType_DepthFloat32
        let toDepth = type == kCVPixelFormatType_DepthFloat16 || type == kCVPixelFormatType_DepthFloat32
        let half = type == kCVPixelFormatType_DepthFloat16 || type == kCVPixelFormatType_DisparityFloat16
        let base = CVPixelBufferGetBaseAddress(b)!, bpr = CVPixelBufferGetBytesPerRow(b)
        for y in 0..<h {
            for x in 0..<w {
                var v = _value(x, y)
                if fromDepth != toDepth { v = v > 0 ? 1 / v : 0 }
                if half { (base + y * bpr + x * 2).storeBytes(of: _isimHalf(v), as: UInt16.self) }
                else { (base + y * bpr + x * 4).storeBytes(of: v, as: Float.self) }
            }
        }
        return AVDepthData(map: b, filtered: isDepthDataFiltered, accuracy: depthDataAccuracy, quality: depthDataQuality)
    }
    open func replacingDepthDataMap(with map: CVPixelBuffer) throws -> AVDepthData {
        guard availableDepthDataTypes.contains(map._format) else { throw AVError(.malformedDepth, reason: "not a depth or disparity pixel format") }
        return AVDepthData(map: map, filtered: isDepthDataFiltered, accuracy: depthDataAccuracy, quality: depthDataQuality)
    }
    /// isim: the auxiliary-image dictionary (kCGImageAuxiliaryDataInfo*) with the map's bytes
    open func dictionaryRepresentation(forAuxiliaryDataType outAuxDataType: AutoreleasingUnsafeMutablePointer<NSString?>?) -> [AnyHashable: Any]? {
        outAuxDataType?.pointee = (depthDataType == kCVPixelFormatType_DepthFloat16 || depthDataType == kCVPixelFormatType_DepthFloat32 ? "kCGImageAuxiliaryDataTypeDepth" : "kCGImageAuxiliaryDataTypeDisparity") as NSString
        let w = CVPixelBufferGetWidth(depthDataMap), h = CVPixelBufferGetHeight(depthDataMap), bpr = CVPixelBufferGetBytesPerRow(depthDataMap)
        let data = Data(bytes: CVPixelBufferGetBaseAddress(depthDataMap)!, count: bpr * h)
        return ["kCGImageAuxiliaryDataInfoData": data,
                "kCGImageAuxiliaryDataInfoDataDescription": ["Width": w, "Height": h, "BytesPerRow": bpr, "PixelFormat": Int(depthDataType)]]
    }
    public convenience init(fromDictionaryRepresentation d: [AnyHashable: Any]) throws {
        guard let data = d["kCGImageAuxiliaryDataInfoData"] as? Data, let desc = d["kCGImageAuxiliaryDataInfoDataDescription"] as? [String: Any],
              let w = desc["Width"] as? Int, let h = desc["Height"] as? Int, let bpr = desc["BytesPerRow"] as? Int, let f = desc["PixelFormat"] as? Int,
              let b = CVBuffer(_width: w, height: h, format: OSType(f)), data.count >= bpr * h else { throw AVError(.malformedDepth) }
        let dst = CVPixelBufferGetBaseAddress(b)!, dbpr = CVPixelBufferGetBytesPerRow(b)
        data.withUnsafeBytes { s in for y in 0..<h { (dst + y * dbpr).copyMemory(from: s.baseAddress! + y * bpr, byteCount: min(bpr, dbpr)) } }
        self.init(map: b, filtered: true)
    }
}

public protocol AVCaptureDepthDataOutputDelegate: NSObjectProtocol {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection)
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason)
}
extension AVCaptureDepthDataOutputDelegate {
    public func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {}
    public func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {}
}
/// Depth maps of a depth-capable camera (dual wide, TrueDepth) at the frame rate of its video.
open class AVCaptureDepthDataOutput: AVCaptureOutput, @unchecked Sendable {
    public override init() { super.init() }
    override var _accepts: [AVMediaType] { [.depthData] }
    open var alwaysDiscardsLateDepthData = true
    open var isFilteringEnabled = true
    open private(set) weak var delegate: AVCaptureDepthDataOutputDelegate?
    open private(set) var delegateCallbackQueue: DispatchQueue?
    open func setDelegate(_ d: AVCaptureDepthDataOutputDelegate?, callbackQueue: DispatchQueue?) { delegate = d; delegateCallbackQueue = callbackQueue }
    var _busy = false
    let _lock = NSLock()
    override func _frame(_ f: _Frame, connection conn: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard conn._carries(.depthData), let dev = conn._device, let fmt = dev.activeDepthDataFormat else { return nil }
        guard synchronized || delegate != nil else { return nil }
        let dims = fmt.formatDescription.dimensions
        guard let map = _DepthScene.map(size: CGSize(width: Int(dims.width), height: Int(dims.height)), type: fmt.formatDescription.mediaSubType, mirrored: conn.isVideoMirrored) else { return nil }
        let data = AVDepthData(map: map, filtered: isFilteringEnabled)
        if synchronized { return AVCaptureSynchronizedDepthData(timestamp: f.time, depthData: data, dropped: false, reason: .none) }
        guard let d = delegate else { return nil }
        _lock.lock(); let busy = _busy; if !busy { _busy = true }; _lock.unlock()
        if busy && alwaysDiscardsLateDepthData {
            (delegateCallbackQueue ?? .main).async { d.depthDataOutput(self, didDrop: data, timestamp: f.time, connection: conn, reason: .lateData) }
            return nil
        }
        (delegateCallbackQueue ?? .main).async {
            d.depthDataOutput(self, didOutput: data, timestamp: f.time, connection: conn)
            self._lock.lock(); self._busy = false; self._lock.unlock()
        }
        return nil
    }
}

// MARK: - synchronizer

public protocol AVCaptureDataOutputSynchronizerDelegate: NSObjectProtocol {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection)
}
/// Delivers the data of several outputs (video, depth, metadata) for the same frame together; the outputs' own
/// delegates are not called.
open class AVCaptureDataOutputSynchronizer: NSObject, @unchecked Sendable {
    public let dataOutputs: [AVCaptureOutput]
    public init(dataOutputs: [AVCaptureOutput]) {
        self.dataOutputs = dataOutputs
        super.init()
        for o in dataOutputs { o._synchronizer = self }
    }
    open private(set) weak var delegate: AVCaptureDataOutputSynchronizerDelegate?
    open private(set) var delegateCallbackQueue: DispatchQueue?
    open func setDelegate(_ d: AVCaptureDataOutputSynchronizerDelegate?, queue: DispatchQueue?) { delegate = d; delegateCallbackQueue = queue }
    func _deliver(_ items: [AVCaptureOutput: AVCaptureSynchronizedData], time: CMTime) {
        guard let d = delegate else { return }
        let c = AVCaptureSynchronizedDataCollection(items: items, order: dataOutputs)
        (delegateCallbackQueue ?? .main).async { d.dataOutputSynchronizer(self, didOutput: c) }
    }
}
open class AVCaptureSynchronizedDataCollection: NSObject, Sequence, @unchecked Sendable {
    let _items: [AVCaptureOutput: AVCaptureSynchronizedData]
    let _order: [AVCaptureOutput]
    init(items: [AVCaptureOutput: AVCaptureSynchronizedData], order: [AVCaptureOutput]) { _items = items; _order = order.filter { items[$0] != nil } }
    open subscript(key: AVCaptureOutput) -> AVCaptureSynchronizedData? { _items[key] }
    open func synchronizedData(for captureOutput: AVCaptureOutput) -> AVCaptureSynchronizedData? { _items[captureOutput] }
    open var count: Int { _items.count }
    public func makeIterator() -> IndexingIterator<[AVCaptureOutput]> { _order.makeIterator() }
}
open class AVCaptureSynchronizedData: NSObject, @unchecked Sendable {
    public let timestamp: CMTime
    init(timestamp: CMTime) { self.timestamp = timestamp }
}
open class AVCaptureSynchronizedSampleBufferData: AVCaptureSynchronizedData, @unchecked Sendable {
    public let sampleBuffer: CMSampleBuffer
    public let sampleBufferWasDropped: Bool
    public let droppedReason: AVCaptureOutput.DataDroppedReason
    init(timestamp: CMTime, sampleBuffer: CMSampleBuffer, dropped: Bool, reason: AVCaptureOutput.DataDroppedReason) {
        self.sampleBuffer = sampleBuffer; sampleBufferWasDropped = dropped; droppedReason = reason
        super.init(timestamp: timestamp)
    }
}
open class AVCaptureSynchronizedDepthData: AVCaptureSynchronizedData, @unchecked Sendable {
    public let depthData: AVDepthData
    public let depthDataWasDropped: Bool
    public let droppedReason: AVCaptureOutput.DataDroppedReason
    init(timestamp: CMTime, depthData: AVDepthData, dropped: Bool, reason: AVCaptureOutput.DataDroppedReason) {
        self.depthData = depthData; depthDataWasDropped = dropped; droppedReason = reason
        super.init(timestamp: timestamp)
    }
}
open class AVCaptureSynchronizedMetadataObjectData: AVCaptureSynchronizedData, @unchecked Sendable {
    public let metadataObjects: [AVMetadataObject]
    init(timestamp: CMTime, objects: [AVMetadataObject]) { metadataObjects = objects; super.init(timestamp: timestamp) }
}
