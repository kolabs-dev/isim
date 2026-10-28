// isim ReplayKit: recording and capturing the app's screen (RPScreenRecorder), the preview sheet
// (RPPreviewViewController), clip buffering, and the broadcast types.
// - Adapted: the app's windows are drawn 15 times a second at one pixel per point (isim's renderer, not the
//   display's composited frames; system UI is not included, like on iOS) and encoded to an H.264 .mp4 with isim's
//   AVAssetWriter. The microphone (isim's simulated microphone, 48 kHz stereo) reaches startCapture's handler as
//   .audioMic buffers; recordings are video only, and the app's own audio (.audioApp) is not captured.
// - Consent: the first recording or capture asks with iOS's alert ("Allow screen recording in “App”?"), remembered
//   for 8 minutes like iOS; ISIM_REPLAYKIT_PERMISSION=allow|deny answers it without showing it.
// - Clip buffering keeps the last 15 seconds in 5-second movie segments and exports a clip by composing them.
// - Broadcasting needs another app's broadcast upload extension, which isim cannot install: the broadcast sheet and
//   the system broadcast picker report that no broadcast service is available.
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo
import AudioToolbox

public let RPRecordingErrorDomain = "com.apple.ReplayKit.RPRecordingErrorDomain"
public let SCStreamErrorDomain = "com.apple.ScreenCaptureKit.SCStreamErrorDomain"
public let RPVideoSampleOrientationKey = "RPVideoSampleOrientationKey"
public let RPApplicationInfoBundleIdentifierKey = "RPApplicationInfoBundleIdentifierKey"

/// Apple's values (RPError.h)
@objc public enum RPRecordingErrorCode: Int, Sendable {
    case unknown = -5800, userDeclined = -5801, disabled = -5802, failedToStart = -5803, failed = -5804, insufficientStorage = -5805
    case interrupted = -5806, contentResize = -5807, broadcastInvalidSession = -5808, systemDormancy = -5809, entitlements = -5810
    case activePhoneCall = -5811, failedToSave = -5812, carPlay = -5813, failedApplicationConnectionInvalid = -5814
    case failedApplicationConnectionInterrupted = -5815, failedNoMatchingApplicationContext = -5816, failedMediaServicesFailure = -5817
    case videoMixingFailure = -5818, broadcastSetupFailed = -5819, failedToObtainURL = -5820, failedIncorrectTimeStamps = -5821
    case failedToProcessFirstSample = -5822, failedAssetWriterFailedToSave = -5823, failedNoAssetWriter = -5824
    case failedAssetWriterInWrongState = -5825, failedAssetWriterExportFailed = -5826, failedToRemoveFile = -5827
    case failedAssetWriterExportCanceled = -5828, attemptToStopNonRecording = -5829, attemptToStartInRecordingState = -5830
    case photoFailure = -5831, recordingInvalidSession = -5832, failedToStartCaptureStack = -5833, invalidParameter = -5834
    case filePermissions = -5835, exportClipToURLInProgress = -5836, codeSuccessful = 0
}
func _rpError(_ code: RPRecordingErrorCode, _ text: String) -> NSError {
    NSError(domain: RPRecordingErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: text])
}

@objc public enum RPSampleBufferType: Int, Sendable { case video = 1, audioApp = 2, audioMic = 3 }
@objc public enum RPCameraPosition: Int, Sendable { case front = 1, back = 2 }
@objc public enum RPPreviewViewControllerMode: Int, Sendable { case preview = 0, share = 1 }

@objc public protocol RPScreenRecorderDelegate: NSObjectProtocol {
    @objc(screenRecorder:didStopRecordingWithPreviewViewController:error:)
    optional func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?)
    @objc optional func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?)
    @objc optional func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder)
}

// MARK: - frames

/// draws the app's windows into BGRA pixel buffers (points, even sizes for H.264)
@MainActor enum _RPFrames {
    static var size: CGSize {
        let s = UIScreen.main.bounds.size
        return CGSize(width: (Int(s.width) / 2) * 2, height: (Int(s.height) / 2) * 2)
    }
    static func frame() -> CVPixelBuffer? {
        let s = size, w = Int(s.width), h = Int(s.height)
        var pb: CVPixelBuffer?
        guard CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb) == kCVReturnSuccess, let b = pb else { return nil }
        UIGraphicsBeginImageContextWithOptions(s, true, 1)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.black.cgColor); ctx.fill(CGRect(origin: .zero, size: s))
        for win in UIApplication.shared.windows.sorted(by: { $0.windowLevel.rawValue < $1.windowLevel.rawValue }) where !win.isHidden && !(win is _RPCameraWindow) {
            win.layoutIfNeeded()
            _ = win.drawHierarchy(in: win.frame, afterScreenUpdates: false)
        }
        guard let image = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(b, [])
        defer { CVPixelBufferUnlockBaseAddress(b, []) }
        guard let out = CGContext(data: CVPixelBufferGetBaseAddress(b), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(b),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        out.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return b
    }
}
final class _RPCameraWindow: UIWindow {}

/// an H.264 movie of frames
final class _RPMovieWriter: @unchecked Sendable {
    let url: URL
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let start: CFTimeInterval
    var frames = 0
    init?(url: URL, size: CGSize, start: CFTimeInterval) {
        try? FileManager.default.removeItem(at: url)
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let i = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width),
                                                                      AVVideoHeightKey: Int(size.height)])
        i.expectsMediaDataInRealTime = true
        let a = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: i, sourcePixelBufferAttributes: nil)
        w.add(i)
        guard w.startWriting() else { return nil }
        w.startSession(atSourceTime: .zero)
        self.url = url; writer = w; input = i; adaptor = a; self.start = start
    }
    func append(_ b: CVPixelBuffer, at t: CFTimeInterval) {
        guard input.isReadyForMoreMediaData else { return }
        if adaptor.append(b, withPresentationTime: CMTime(seconds: max(0, t - start), preferredTimescale: 600)) { frames += 1 }
    }
    func finish(_ done: @escaping (Error?) -> Void) {
        input.markAsFinished()
        writer.finishWriting { [writer] in done(writer.status == .completed ? nil : (writer.error ?? _rpError(.failedAssetWriterFailedToSave, "the recording could not be written"))) }
    }
    func cancel() { writer.cancelWriting(); try? FileManager.default.removeItem(at: url) }
}

// MARK: - RPScreenRecorder

/// records or captures the app's screen
@objc(RPScreenRecorder) open class RPScreenRecorder: NSObject, @unchecked Sendable {
    static let _shared = RPScreenRecorder()
    @objc(sharedRecorder) open class func shared() -> RPScreenRecorder { _shared }
    @objc open weak var delegate: RPScreenRecorderDelegate?
    /// isim can always record (ISIM_REPLAYKIT_AVAILABLE=0 makes it unavailable, like a device under a restriction)
    @objc open var isAvailable: Bool { ProcessInfo.processInfo.environment["ISIM_REPLAYKIT_AVAILABLE"] != "0" }
    @objc open private(set) dynamic var isRecording = false
    @objc open var isMicrophoneEnabled: Bool {
        @objc(isMicrophoneEnabled) get { _microphone }
        @objc(setMicrophoneEnabled:) set { _microphone = newValue }
    }
    @objc open var isCameraEnabled: Bool {
        @objc(isCameraEnabled) get { _camera }
        @objc(setCameraEnabled:) set { _camera = newValue }
    }
    var _microphone = false, _camera = false
    @objc open var cameraPosition: RPCameraPosition = .front { didSet { if camera != nil { _Privacy.onMain { [self] in _startCamera() } } } }
    /// the camera's preview while recording with the camera enabled (the app adds it to its views)
    @objc open private(set) var cameraPreviewView: UIView?

    enum Mode { case none, recording, capture }
    var mode = Mode.none
    var timer: Timer?
    var writer: _RPMovieWriter?
    var captureHandler: ((CMSampleBuffer, RPSampleBufferType, Error?) -> Void)?
    var started: CFTimeInterval = 0
    var camera: AVCaptureSession?
    var clips: _RPClipBuffer?
    let queue = DispatchQueue(label: "isim.replaykit")

    // MARK: consent

    static var consentUntil: Date?
    static func consent(microphone: Bool, _ done: @escaping @MainActor (Bool) -> Void) {
        _Privacy.onMain {
            if let until = consentUntil, until > Date() { done(true); return }
            @MainActor func answer(_ ok: Bool) {
                if ok { consentUntil = Date().addingTimeInterval(8 * 60) }
                NSLog("isim ReplayKit: screen recording %@ for %@", ok ? "allowed" : "declined", _Privacy.appName)
                done(ok)
            }
            if let s = _Privacy.scripted("REPLAYKIT") { answer(!(s == "deny" || s == "denied" || s == "no" || s == "0")); return }
            let title = "Allow screen recording in “\(_Privacy.appName)”?"
            let message = "Screen recordings may capture anything shown on the screen, including notifications."
            if microphone {
                _Privacy.alert(title, message, [("Record Screen & Microphone", .default), ("Record Screen Only", .default), ("Don’t Allow", .cancel)]) { i in
                    if i == 1 { RPScreenRecorder._shared.isMicrophoneEnabled = false }
                    answer(i == 0 || i == 1)
                }
            } else {
                _Privacy.alert(title, message, [("Record Screen", .default), ("Don’t Allow", .cancel)]) { answer($0 == 0) }
            }
        }
    }

    func _begin(_ m: Mode, _ handler: ((Error?) -> Void)?) {
        guard isAvailable else { DispatchQueue.main.async { handler?(_rpError(.disabled, "screen recording is not available")) }; return }
        guard mode == .none else {
            DispatchQueue.main.async { handler?(_rpError(.attemptToStartInRecordingState, "a recording or capture is already running")) }
            return
        }
        mode = m
        RPScreenRecorder.consent(microphone: isMicrophoneEnabled) { [self] ok in
            guard ok else { mode = .none; handler?(_rpError(.userDeclined, "the user declined screen recording")); return }
            started = CACurrentMediaTime()
            if m == .recording {
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ReplayKit-\(UUID().uuidString).mp4")
                guard let w = _RPMovieWriter(url: url, size: _RPFrames.size, start: started) else {
                    mode = .none; handler?(_rpError(.failedNoAssetWriter, "the recording could not be started")); return
                }
                writer = w
            }
            if m == .capture && isMicrophoneEnabled { _startMicrophone() }
            if isCameraEnabled { _startCamera() }
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?._tick() } }
            RunLoop.main.add(timer!, forMode: .common)
            _tick()
            isRecording = true
            NSLog("isim ReplayKit: %@ started (%@)", m == .recording ? "recording" : "capture", isMicrophoneEnabled ? "screen and microphone" : "screen")
            handler?(nil)
        }
    }
    @MainActor func _tick() {
        guard let b = _RPFrames.frame() else { return }
        let t = CACurrentMediaTime()
        if let writer { writer.append(b, at: t) }
        if let captureHandler {
            let sb = CMSampleBuffer(_imageBuffer: b, presentationTime: CMTime(seconds: t, preferredTimescale: 1_000_000_000), duration: CMTime(value: 1, timescale: 15))
            queue.async { captureHandler(sb, .video, nil) }
        }
        clips?.append(b, at: t)
    }
    func _endFrames() {
        if clips == nil { timer?.invalidate(); timer = nil }       // clip buffering keeps drawing
        _stopCamera()
        _IsimAudioInput.unsubscribe(self)
        isRecording = false
    }

    // MARK: recording

    @objc open func startRecording(handler: ((Error?) -> Void)? = nil) { _begin(.recording, handler) }
    @available(iOS, deprecated: 10.0, message: "Use microphoneEnabled property")
    @objc open func startRecording(withMicrophoneEnabled microphoneEnabled: Bool, handler: ((Error?) -> Void)? = nil) {
        isMicrophoneEnabled = microphoneEnabled
        startRecording(handler: handler)
    }
    /// ends the recording; the preview controller plays it and lets the user save it to Photos
    @objc open func stopRecording(handler: ((RPPreviewViewController?, Error?) -> Void)? = nil) {
        _finish { url, error in
            DispatchQueue.main.async { handler?(url.map { RPPreviewViewController(_movie: $0) }, error) }
        }
    }
    /// ends the recording and writes the movie to `url` (iOS 14)
    @objc(stopRecordingWithOutputURL:completionHandler:) open func stopRecording(withOutput url: URL, completionHandler: ((Error?) -> Void)? = nil) {
        _finish { movie, error in
            var e = error
            if let movie {
                do {
                    try? FileManager.default.removeItem(at: url)
                    try FileManager.default.moveItem(at: movie, to: url)
                } catch { e = _rpError(.failedToSave, "the recording could not be written to \(url.path): \(error.localizedDescription)") }
            }
            DispatchQueue.main.async { completionHandler?(e) }
        }
    }
    func _finish(_ done: @escaping (URL?, Error?) -> Void) {
        DispatchQueue.main.async { [self] in
            guard mode == .recording, let w = writer else { done(nil, _rpError(.attemptToStopNonRecording, "no recording is running")); return }
            mode = .none; writer = nil
            _endFrames()
            NSLog("isim ReplayKit: recording stopped (%d frames)", w.frames)
            w.finish { error in done(error == nil ? w.url : nil, error) }
        }
    }
    /// deletes the last recording (the preview's movie)
    @objc open func discardRecording(handler: @escaping () -> Void) {
        DispatchQueue.main.async {
            if let last = RPPreviewViewController._last { try? FileManager.default.removeItem(at: last); RPPreviewViewController._last = nil }
            handler()
        }
    }

    // MARK: capture (iOS 11)

    open func startCapture(handler captureHandler: ((CMSampleBuffer, RPSampleBufferType, Error?) -> Void)?, completionHandler: ((Error?) -> Void)? = nil) {
        self.captureHandler = captureHandler
        _begin(.capture) { [self] e in if e != nil { self.captureHandler = nil }; completionHandler?(e) }
    }
    /// Objective-C: the CMSampleBufferRef is the Swift sample buffer (valid during the call; CFRetain to keep it)
    @objc(startCaptureWithHandler:completionHandler:)
    func _objc_startCapture(_ handler: ((UnsafeRawPointer, RPSampleBufferType, Error?) -> Void)?, completionHandler: ((Error?) -> Void)?) {
        startCapture(handler: handler.map { h in { sb, type, e in h(UnsafeRawPointer(Unmanaged.passUnretained(sb).toOpaque()), type, e) } },
                     completionHandler: completionHandler)
    }
    @objc open func stopCapture(handler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { [self] in
            guard mode == .capture else { handler?(_rpError(.attemptToStopNonRecording, "no capture is running")); return }
            mode = .none
            _endFrames()
            queue.async { [self] in captureHandler = nil; DispatchQueue.main.async { handler?(nil) } }
        }
    }
    func _startMicrophone() {
        let asbd = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
        var frames: Int64 = 0
        _IsimAudioInput.subscribe(self) { [weak self] pcm in
            guard let self, let handler = captureHandler, !pcm.isEmpty else { return }
            let bytes = pcm.withUnsafeBytes { Array($0) }
            let sb = CMSampleBuffer(_audio: bytes, format: asbd, presentationTime: CMTime(value: frames, timescale: 48000))
            frames += Int64(pcm.count / 2)
            queue.async { handler(sb, .audioMic, nil) }
        }
    }
    @MainActor func _startCamera() {
        _stopCamera()
        let position: AVCaptureDevice.Position = cameraPosition == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { NSLog("isim ReplayKit: no camera for the preview"); return }
        let session = AVCaptureSession()
        if session.canAddInput(input) { session.addInput(input) }
        let view = _RPCameraPreview(frame: CGRect(x: 0, y: 0, width: 120, height: 160))
        view.preview.session = session
        view.accessibilityIdentifier = "RPCameraPreview"
        camera = session; cameraPreviewView = view
        DispatchQueue.global().async { session.startRunning() }
    }
    func _stopCamera() {
        if let c = camera { DispatchQueue.global().async { c.stopRunning() } }
        camera = nil; cameraPreviewView = nil
    }

    // MARK: clip buffering (iOS 15)

    @objc open func startClipBuffering(completionHandler: ((Error?) -> Void)? = nil) {
        RPScreenRecorder.consent(microphone: false) { [self] ok in
            guard ok else { completionHandler?(_rpError(.userDeclined, "the user declined screen recording")); return }
            guard clips == nil else { completionHandler?(_rpError(.attemptToStartInRecordingState, "clip buffering is already on")); return }
            clips = _RPClipBuffer()
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?._tick() } }
                RunLoop.main.add(timer!, forMode: .common)
            }
            NSLog("isim ReplayKit: clip buffering started")
            completionHandler?(nil)
        }
    }
    @objc open func stopClipBuffering(completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { [self] in
            guard let c = clips else { completionHandler?(_rpError(.attemptToStopNonRecording, "clip buffering is off")); return }
            clips = nil
            if mode == .none { timer?.invalidate(); timer = nil }
            c.discard()
            completionHandler?(nil)
        }
    }
    /// writes the last `duration` seconds (at most 15) to `url`
    @objc open func exportClip(to url: URL, duration: TimeInterval, completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { [self] in
            guard let c = clips else { completionHandler?(_rpError(.attemptToStopNonRecording, "clip buffering is off")); return }
            guard duration > 0 else { completionHandler?(_rpError(.invalidParameter, "the clip duration must be positive")); return }
            c.export(to: url, duration: min(duration, 15)) { e in DispatchQueue.main.async { completionHandler?(e) } }
        }
    }
}

final class _RPCameraPreview: UIView {
    let preview = AVCaptureVideoPreviewLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview); layer.cornerRadius = 12; clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); preview.frame = bounds }
}

/// the last 15 seconds, as 5-second movie segments
final class _RPClipBuffer: @unchecked Sendable {
    struct Segment { let url: URL; let start: CFTimeInterval; var end: CFTimeInterval }
    var segments: [Segment] = []
    var current: _RPMovieWriter?
    var currentStart: CFTimeInterval = 0
    var exporting = false
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ReplayKitClips-\(UUID().uuidString)")
    init() { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }

    @MainActor func append(_ b: CVPixelBuffer, at t: CFTimeInterval) {
        if current == nil || t - currentStart >= 5 { roll(at: t) }
        current?.append(b, at: t)
        if !segments.isEmpty { segments[segments.count - 1].end = t }
    }
    @MainActor func roll(at t: CFTimeInterval) {
        if let w = current { w.finish { _ in } }
        let url = dir.appendingPathComponent("segment-\(Int(t * 1000)).mp4")
        current = _RPMovieWriter(url: url, size: _RPFrames.size, start: t)
        currentStart = t
        segments.append(Segment(url: url, start: t, end: t))
        // keep what covers the last 15 seconds
        while segments.count > 4, let first = segments.first, t - first.end > 15 {
            try? FileManager.default.removeItem(at: first.url); segments.removeFirst()
        }
    }
    @MainActor func export(to url: URL, duration: TimeInterval, _ done: @escaping (Error?) -> Void) {
        guard !exporting else { done(_rpError(.exportClipToURLInProgress, "a clip is already being exported")); return }
        exporting = true
        let now = CACurrentMediaTime()
        let finished = current, parts = segments
        current = nil
        let group = DispatchGroup()
        if let finished { group.enter(); finished.finish { _ in group.leave() } }
        group.notify(queue: .main) { [self] in
            let from = now - duration
            let composition = AVMutableComposition()
            var at = CMTime.zero
            let out = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            for s in parts where s.end > from {
                let asset = AVURLAsset(url: s.url)
                guard let track = asset.tracks(withMediaType: .video).first else { continue }
                let skip = max(0, from - s.start)
                let range = CMTimeRange(start: CMTime(seconds: skip, preferredTimescale: 600),
                                        end: CMTimeMinimum(asset.duration, CMTime(seconds: s.end - s.start, preferredTimescale: 600)))
                guard range.duration.seconds > 0 else { continue }
                try? out?.insertTimeRange(range, of: track, at: at)
                at = at + range.duration
            }
            guard at.seconds > 0, let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                exporting = false; done(_rpError(.failedAssetWriterExportFailed, "nothing was buffered yet")); return
            }
            try? FileManager.default.removeItem(at: url)
            session.outputURL = url; session.outputFileType = .mp4
            session.exportAsynchronously { [self] in
                DispatchQueue.main.async { self.exporting = false }
                done(session.status == .completed ? nil : (session.error ?? _rpError(.failedAssetWriterExportFailed, "the clip could not be exported")))
            }
        }
    }
    func discard() { current?.cancel(); current = nil; try? FileManager.default.removeItem(at: dir) }
}

// MARK: - RPPreviewViewController

@objc public protocol RPPreviewViewControllerDelegate: NSObjectProtocol {
    @objc optional func previewControllerDidFinish(_ previewController: RPPreviewViewController)
    @objc optional func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>)
}

/// plays a recording: Cancel, or Save to the photo library; the delegate dismisses it
@objc(RPPreviewViewController) open class RPPreviewViewController: UIViewController {
    @objc open weak var previewControllerDelegate: RPPreviewViewControllerDelegate?
    @objc open var mode: RPPreviewViewControllerMode = .preview
    nonisolated(unsafe) static var _last: URL?
    let movie: URL
    var player: AVPlayer?
    let playerLayer = AVPlayerLayer()
    init(_movie url: URL) {
        movie = url
        RPPreviewViewController._last = url
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required public init?(coder: NSCoder) { fatalError("RPPreviewViewController is made by RPScreenRecorder") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.accessibilityIdentifier = "RPPreviewViewController"
        view.layer.addSublayer(playerLayer)
        let bar = UIView()
        bar.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        bar.tag = 1
        view.addSubview(bar)
        let cancel = UIButton(type: .system), save = UIButton(type: .system), title = UILabel()
        cancel.setTitle("Cancel", for: .normal); cancel.accessibilityIdentifier = "RPPreview.cancel"
        save.setTitle("Save", for: .normal); save.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold); save.accessibilityIdentifier = "RPPreview.save"
        title.text = "Preview"; title.textColor = .white; title.font = .systemFont(ofSize: 17, weight: .semibold); title.textAlignment = .center
        cancel.addTarget(self, action: #selector(_cancel), for: .touchUpInside)
        save.addTarget(self, action: #selector(_save), for: .touchUpInside)
        for (i, v) in [cancel, title, save].enumerated() { v.tag = 10 + i; bar.addSubview(v) }
        let p = AVPlayer(url: movie)
        playerLayer.player = p; player = p
    }
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top, w = view.bounds.width
        if let bar = view.viewWithTag(1) {
            bar.frame = CGRect(x: 0, y: 0, width: w, height: top + 44)
            bar.viewWithTag(10)?.frame = CGRect(x: 8, y: top, width: 80, height: 44)
            bar.viewWithTag(11)?.frame = CGRect(x: 90, y: top, width: w - 180, height: 44)
            bar.viewWithTag(12)?.frame = CGRect(x: w - 88, y: top, width: 80, height: 44)
        }
        playerLayer.frame = view.bounds.inset(by: UIEdgeInsets(top: top + 44, left: 0, bottom: view.safeAreaInsets.bottom, right: 0))
    }
    open override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); player?.play() }
    open override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); player?.pause() }

    @objc func _cancel() {
        NSLog("isim ReplayKit: preview cancelled")
        previewControllerDelegate?.previewController?(self, didFinishWithActivityTypes: [])
        previewControllerDelegate?.previewControllerDidFinish?(self)
    }
    @objc func _save() {
        UISaveVideoAtPathToSavedPhotosAlbum(movie.path, self, #selector(_saved(_:error:context:)), nil)
    }
    @objc func _saved(_ path: String, error: NSError?, context: UnsafeMutableRawPointer?) {
        NSLog("isim ReplayKit: recording %@", error == nil ? "saved to Photos" : "not saved: \(error!.localizedDescription)")
        previewControllerDelegate?.previewController?(self, didFinishWithActivityTypes: error == nil ? ["com.apple.UIKit.activity.SaveToCameraRoll"] : [])
        previewControllerDelegate?.previewControllerDidFinish?(self)
    }
}

// MARK: - broadcasting

@objc public protocol RPBroadcastControllerDelegate: NSObjectProtocol {
    @objc optional func broadcastController(_ broadcastController: RPBroadcastController, didFinishWithError error: Error?)
    @objc optional func broadcastController(_ broadcastController: RPBroadcastController, didUpdateServiceInfo serviceInfo: [String: NSCoding & NSObjectProtocol])
    @objc(broadcastController:didUpdateBroadcastURL:) optional func broadcastController(_ broadcastController: RPBroadcastController, didUpdateBroadcast broadcastURL: URL)
}

/// a broadcast through a service's extension (none on isim: they cannot start)
@objc(RPBroadcastController) open class RPBroadcastController: NSObject, @unchecked Sendable {
    @objc open weak var delegate: RPBroadcastControllerDelegate?
    @objc open private(set) var isBroadcasting = false
    @objc open private(set) var isPaused = false
    @objc open private(set) var broadcastURL = URL(string: "about:blank")!
    @objc open private(set) var serviceInfo: [String: NSCoding & NSObjectProtocol]?
    @objc open private(set) var broadcastExtensionBundleID: String?
    override init() { super.init() }
    @objc open func startBroadcast(handler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { handler(_rpError(.broadcastInvalidSession, "isim has no broadcast upload extension to broadcast with")) }
    }
    @objc open func pauseBroadcast() {}
    @objc open func resumeBroadcast() {}
    @objc open func finishBroadcast(handler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { handler(_rpError(.broadcastInvalidSession, "no broadcast is running")) }
    }
}

@objc public protocol RPBroadcastActivityViewControllerDelegate: NSObjectProtocol {
    @objc(broadcastActivityViewController:didFinishWithBroadcastController:error:)
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController,
                                               didFinishWith broadcastController: RPBroadcastController?, error: Error?)
}

/// the sheet of broadcast services: on isim, a sheet saying there are none
@objc(RPBroadcastActivityViewController) open class RPBroadcastActivityViewController: UIViewController {
    @objc open weak var delegate: RPBroadcastActivityViewControllerDelegate?
    var preferred: String?
    init(_preferred: String?) { preferred = _preferred; super.init(nibName: nil, bundle: nil) }
    required public init?(coder: NSCoder) { fatalError("use RPBroadcastActivityViewController.load(handler:)") }
    @objc(loadBroadcastActivityViewControllerWithHandler:) open class func load(handler: @escaping (RPBroadcastActivityViewController?, Error?) -> Void) { load(withPreferredExtension: nil, handler: handler) }
    @objc(loadBroadcastActivityViewControllerWithPreferredExtension:handler:) open class func load(withPreferredExtension preferredExtension: String?, handler: @escaping (RPBroadcastActivityViewController?, Error?) -> Void) {
        DispatchQueue.main.async { handler(RPBroadcastActivityViewController(_preferred: preferredExtension), nil) }
    }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "RPBroadcastActivityViewController"
        let title = UILabel(), text = UILabel(), cancel = UIButton(type: .system)
        title.text = "Broadcast"; title.font = .systemFont(ofSize: 20, weight: .semibold); title.textAlignment = .center
        text.text = preferred.map { "“\($0)” is not installed. isim cannot install broadcast upload extensions." }
            ?? "No broadcast services are available. isim cannot install broadcast upload extensions."
        text.numberOfLines = 0; text.textAlignment = .center; text.textColor = .secondaryLabel
        cancel.setTitle("Cancel", for: .normal); cancel.accessibilityIdentifier = "RPBroadcast.cancel"
        cancel.addTarget(self, action: #selector(_cancel), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, text, cancel])
        stack.axis = .vertical; stack.spacing = 16
        stack.frame = view.bounds.insetBy(dx: 24, dy: 120); stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stack)
    }
    @objc func _cancel() {
        delegate?.broadcastActivityViewController(self, didFinishWith: nil, error: _rpError(.userDeclined, "the user cancelled the broadcast"))
    }
}

/// the system's broadcast button (Control Center's picker): on isim it reports that no broadcast service is available
@objc(RPSystemBroadcastPickerView) open class RPSystemBroadcastPickerView: UIView {
    @objc open var preferredExtension: String?
    @objc open var showsMicrophoneButton = true
    let button = UIButton(type: .system)
    public override init(frame: CGRect) {
        super.init(frame: frame)
        button.setImage(UIImage(systemName: "record.circle"), for: .normal)
        button.accessibilityIdentifier = "RPSystemBroadcastPickerView"
        button.accessibilityLabel = "Screen Broadcast"
        button.addTarget(self, action: #selector(_tap), for: .touchUpInside)
        addSubview(button)
    }
    required public init?(coder: NSCoder) { super.init(coder: coder) }
    open override func layoutSubviews() { super.layoutSubviews(); button.frame = bounds }
    @objc func _tap() {
        NSLog("isim ReplayKit: broadcast picker opened (preferred extension %@)", preferredExtension ?? "none")
        let a = UIAlertController(title: "Screen Broadcast",
                                  message: "No broadcast services are available. isim cannot install broadcast upload extensions.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        _Privacy.topController()?.present(a, animated: true)
    }
}

/// a broadcast upload extension's principal class: isim never runs one
@objc(RPBroadcastHandler) open class RPBroadcastHandler: NSObject {
    @objc open func updateServiceInfo(_ serviceInfo: [String: NSCoding & NSObjectProtocol]) {}
    @objc(updateBroadcastURL:) open func updateBroadcast(_ broadcastURL: URL) {}
}
@objc(RPBroadcastSampleHandler) open class RPBroadcastSampleHandler: RPBroadcastHandler {
    @objc open func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {}
    @objc open func broadcastPaused() {}
    @objc open func broadcastResumed() {}
    @objc open func broadcastFinished() {}
    @objc open func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable: Any]) {}
    open func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {}
    @objc(processSampleBuffer:withType:) func _objc_processSampleBuffer(_ sampleBuffer: UnsafeRawPointer, withType type: RPSampleBufferType) {
        processSampleBuffer(Unmanaged<CMSampleBuffer>.fromOpaque(sampleBuffer).takeUnretainedValue(), with: type)
    }
    @objc open func finishBroadcastWithError(_ error: Error) {}
}
@objc(RPBroadcastMP4ClipHandler) open class RPBroadcastMP4ClipHandler: RPBroadcastHandler {
    @objc(processMP4ClipWithURL:setupInfo:finished:) open func processMP4Clip(with mp4ClipURL: URL?, setupInfo: [String: NSObject]?, finished: Bool) {}
    @objc open func finishedProcessingMP4Clip(withUpdatedBroadcastConfiguration broadcastConfiguration: RPBroadcastConfiguration?, error: Error?) {}
}
@objc(RPBroadcastConfiguration) open class RPBroadcastConfiguration: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
    @objc open var clipDuration: TimeInterval = 5
    @objc open var videoCompressionProperties: [String: NSSecureCoding & NSObjectProtocol]?
    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        clipDuration = coder.decodeDouble(forKey: "clipDuration")
        super.init()
    }
    public func encode(with coder: NSCoder) { coder.encode(clipDuration, forKey: "clipDuration") }
}

// MARK: - async forms (Apple's Swift imports of the completion-handler methods)

extension RPScreenRecorder {
    private static func _await(_ start: (@escaping (Error?) -> Void) -> Void) async throws {
        let e: Error? = await withCheckedContinuation { k in start { k.resume(returning: $0) } }
        if let e { throw e }
    }
    public func startRecording() async throws { try await Self._await { startRecording(handler: $0) } }
    public func stopRecording() async throws -> RPPreviewViewController {
        try await withCheckedThrowingContinuation { k in
            stopRecording { p, e in if let p { k.resume(returning: p) } else { k.resume(throwing: e ?? _rpError(.unknown, "no recording")) } }
        }
    }
    public func stopRecording(withOutput url: URL) async throws { try await Self._await { stopRecording(withOutput: url, completionHandler: $0) } }
    public func discardRecording() async { await withCheckedContinuation { k in discardRecording { k.resume() } } }
    public func startCapture(handler captureHandler: ((CMSampleBuffer, RPSampleBufferType, Error?) -> Void)?) async throws {
        try await Self._await { startCapture(handler: captureHandler, completionHandler: $0) }
    }
    public func stopCapture() async throws { try await Self._await { stopCapture(handler: $0) } }
    public func startClipBuffering() async throws { try await Self._await { startClipBuffering(completionHandler: $0) } }
    public func stopClipBuffering() async throws { try await Self._await { stopClipBuffering(completionHandler: $0) } }
    public func exportClip(to url: URL, duration: TimeInterval) async throws { try await Self._await { exportClip(to: url, duration: duration, completionHandler: $0) } }
}
extension RPBroadcastController {
    public func startBroadcast() async throws {
        let e: Error? = await withCheckedContinuation { k in startBroadcast { k.resume(returning: $0) } }
        if let e { throw e }
    }
    public func finishBroadcast() async throws {
        let e: Error? = await withCheckedContinuation { k in finishBroadcast { k.resume(returning: $0) } }
        if let e { throw e }
    }
}
extension RPBroadcastActivityViewController {
    public class func load() async throws -> RPBroadcastActivityViewController { try await load(withPreferredExtension: nil) }
    public class func load(withPreferredExtension preferredExtension: String?) async throws -> RPBroadcastActivityViewController {
        try await withCheckedThrowingContinuation { k in
            load(withPreferredExtension: preferredExtension) { vc, e in
                if let vc { k.resume(returning: vc) } else { k.resume(throwing: e ?? _rpError(.broadcastSetupFailed, "no broadcast sheet")) }
            }
        }
    }
}
