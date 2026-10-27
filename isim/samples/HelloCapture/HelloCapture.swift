// Sample: the full capture pipeline on isim's simulated camera and microphone — device discovery (cameras, virtual and
// depth cameras, the microphone), a session with a camera and the microphone, photos (HEIC, flash, RAW + DNG, Live
// Photos, depth, exposure brackets), video and audio data outputs, metadata (faces, bodies, Aztec, Data Matrix),
// movies with sound, zoom and torch, a depth data output with a data output synchronizer, a multi-cam session (back
// and front at once) and interruptions; the Camera Control's controls (on iPhone 16 / 17 / Air), capture events from
// the volume buttons and the Camera Control, system pressure, portrait and semantic mattes and calibration data.
// Each feature is a button; the results are logged.
import UIKit
import AVFoundation
import AVKit
import SwiftUI

/// SwiftUI's onCameraCaptureEvent (off until the "SwiftUI events" button turns it on, so the UIKit interaction gets the
/// events first)
final class SwiftUICapture: ObservableObject { @Published var enabled = false }
struct SwiftUICaptureView: View {
    @ObservedObject var model: SwiftUICapture
    var body: some View {
        if #available(iOS 18.0, *) {
            Color.clear.onCameraCaptureEvent(isEnabled: model.enabled) { e in
                log("swiftui capture event \(e.phase == .began ? "began" : e.phase == .ended ? "ended" : "cancelled")")
            }
        } else { Color.clear }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CaptureViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloCapture: %@", s) }
func f2(_ v: Double) -> String { String(format: "%.2f", v) }
/// colour name and luminance (0...1) of a BGRA pixel
func describe(_ p: UnsafePointer<UInt8>) -> (String, Double) {
    let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])
    let lum = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
    if r > 150 && g < 90 && b < 90 { return ("red", lum) }
    if g > 150 && r < 90 && b < 90 { return ("green", lum) }
    if b > 150 && r < 90 && g < 90 { return ("blue", lum) }
    if r > 150 && g > 150 && b < 90 { return ("yellow", lum) }
    if abs(r - g) < 20 && abs(g - b) < 20 { return ("gray", lum) }
    return ("rgb(\(r),\(g),\(b))", lum)
}
func pixel(_ pb: CVPixelBuffer, _ x: Int, _ y: Int) -> (String, Double) {
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
    return describe(base + y * CVPixelBufferGetBytesPerRow(pb) + x * 4)
}
func pixel(_ img: CGImage, _ x: Int, _ y: Int) -> (String, Double) {
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
    return px.withUnsafeBufferPointer { describe($0.baseAddress!) }
}

final class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate,
                                    AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate,
                                    AVCaptureDataOutputSynchronizerDelegate, AVCaptureSessionControlsDelegate {
    let session = AVCaptureSession()
    let preview = UIView(), frontPreview = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    let metadataOutput = AVCaptureMetadataOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let depthOutput = AVCaptureDepthDataOutput()
    let syncVideoOutput = AVCaptureVideoDataOutput()
    var synchronizer: AVCaptureDataOutputSynchronizer?
    let sessionQueue = DispatchQueue(label: "session"), videoQueue = DispatchQueue(label: "video"), audioQueue = DispatchQueue(label: "audio")
    var camera: AVCaptureDevice?
    var frames = 0, audioBuffers = 0, audioPeak = 0.0
    var lastCorner = "", lastLum = -1.0
    var seenMetadata = Set<String>()
    var photoNote = ""
    var bracketLums: [String] = []
    var syncLogged = false
    // multi-cam
    var multi: AVCaptureMultiCamSession?
    let backOutput = AVCaptureVideoDataOutput(), frontOutput = AVCaptureVideoDataOutput()
    var multiColors: [String: String] = [:]
    var pressureObservation: NSKeyValueObservation?
    let swiftUICapture = SwiftUICapture()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Capture"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 60, width: 300, height: 41); view.addSubview(title)
        preview.frame = CGRect(x: 20, y: 110, width: 240, height: 180); preview.backgroundColor = .black; preview.accessibilityIdentifier = "preview"
        previewLayer.frame = preview.bounds; previewLayer.videoGravity = .resizeAspect
        preview.layer.addSublayer(previewLayer); view.addSubview(preview)
        frontPreview.frame = CGRect(x: 270, y: 110, width: 112, height: 84); frontPreview.backgroundColor = .black; frontPreview.accessibilityIdentifier = "front-preview"
        view.addSubview(frontPreview)
        let buttons: [(String, String, Selector)] = [
            ("HEIC", "photo-heic", #selector(photoHEIC)), ("Flash", "photo-flash", #selector(photoFlash)), ("RAW", "photo-raw", #selector(photoRAW)),
            ("Live", "photo-live", #selector(photoLive)), ("Depth", "photo-depth", #selector(photoDepth)), ("Bracket", "photo-bracket", #selector(photoBracket)),
            ("Record", "record", #selector(record)), ("Zoom", "zoom", #selector(zoom)), ("Torch", "torch", #selector(torch)),
            ("Sync", "sync", #selector(sync)), ("Multi-cam", "multicam", #selector(multicam)), ("Stop", "stop", #selector(stop)),
            ("Matte", "photo-matte", #selector(photoMatte)), ("SwiftUI events", "swiftui-events", #selector(swiftUIEvents))]
        for (i, (t, id, sel)) in buttons.enumerated() {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.frame = CGRect(x: 20 + CGFloat(i % 3) * 122, y: 310 + CGFloat(i / 3) * 44, width: 110, height: 40)
            b.addTarget(self, action: sel, for: .touchUpInside)
            view.addSubview(b)
        }
        // discovery
        let all = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInDualWideCamera, .builtInTrueDepthCamera, .microphone],
                                                   mediaType: nil, position: .unspecified)
        log("devices \(all.devices.map(\.localizedName).joined(separator: ","))")
        let depth = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera, .builtInTrueDepthCamera], mediaType: .depthData, position: .unspecified)
        log("depth cameras \(depth.devices.map(\.localizedName).joined(separator: ","))")
        let mic = AVCaptureDevice.default(for: .audio)
        log("microphone \(mic?.localizedName ?? "none") type=\(mic?.deviceType == .microphone ? "microphone" : "other") audio=\(mic?.hasMediaType(.audio) ?? false)")
        log("multicam supported=\(AVCaptureMultiCamSession.isMultiCamSupported) sets=\(all.supportedMultiCamDeviceSets.count)")
        camera = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
        if let c = camera { log("camera \(c.localizedName) virtual=\(c.isVirtualDevice) constituents=\(c.constituentDevices.map(\.localizedName).joined(separator: "+")) depthFormats=\(c.activeFormat.supportedDepthDataFormats.count)") }
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: nil, queue: .main) { n in
            log("interrupted reason=\(n.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int ?? 0)")
        }
        nc.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: nil, queue: .main) { _ in log("interruption ended") }
        // capture events: the volume buttons and the Camera Control take photos in camera apps
        func phase(_ e: AVCaptureEvent) -> String { e.phase == .began ? "began" : e.phase == .ended ? "ended" : "cancelled" }
        view.addInteraction(AVCaptureEventInteraction(primary: { e in
            log("capture event primary \(phase(e))")
            if #available(iOS 26.0, *), e.phase == .ended { log("capture sound played=\(e.play(.cameraShutter))") }
        }, secondary: { e in log("capture event secondary \(phase(e))") }))
        let host = UIHostingController(rootView: SwiftUICaptureView(model: swiftUICapture))
        host.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1); host.view.backgroundColor = .clear
        addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
        if #available(iOS 27.1, *) {
            let map = AVCaptureDeviceDirectionCoordinator(view: view, deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera], changeHandler: nil).deviceDirections
            log("directions forward=\(map.forwardFacingDeviceDescriptors.map(\.localizedName).joined(separator: ",")) backward=\(map.backwardFacingDeviceDescriptors.map(\.localizedName).joined(separator: ","))")
        }
        pressureObservation = camera?.observe(\.systemPressureState, options: [.new]) { d, _ in
            log("pressure \(d.systemPressureState.level.rawValue) factors=\(d.systemPressureState.factors.rawValue)")
        }
    }
    var configured = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !configured else { return }
        configured = true
        let c = camera
        sessionQueue.async { self.configure(c) }
    }

    nonisolated func configure(_ camera: AVCaptureDevice?) {
        guard let camera, let mic = AVCaptureDevice.default(for: .audio) else { log("no camera"); return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            for d in [camera, mic] { let i = try AVCaptureDeviceInput(device: d); if session.canAddInput(i) { session.addInput(i) } }
        } catch { log("input error \(error)"); session.commitConfiguration(); return }
        for o in [photoOutput, videoOutput, audioOutput, metadataOutput, movieOutput, depthOutput, syncVideoOutput] as [AVCaptureOutput] where session.canAddOutput(o) { session.addOutput(o) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        syncVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        let wanted: [AVMetadataObject.ObjectType] = [.face, .humanBody, .aztec, .dataMatrix]
        metadataOutput.metadataObjectTypes = wanted.filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
        photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
        photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
        let settings = AVCapturePhotoSettings(); settings.flashMode = .auto
        photoOutput.photoSettingsForSceneMonitoring = settings
        if #available(iOS 18.0, *) { setUpControls(camera) }
        session.commitConfiguration()
        let audioConn = audioOutput.connection(with: .audio)
        log("outputs=\(session.outputs.count) metadata=\(metadataOutput.metadataObjectTypes.map(\.rawValue).joined(separator: ",")) audioChannels=\(audioConn?.audioChannels.count ?? 0) live=\(photoOutput.isLivePhotoCaptureEnabled) depth=\(photoOutput.isDepthDataDeliveryEnabled) codecs=\(photoOutput.availablePhotoCodecTypes.map(\.rawValue).joined(separator: ",")) raw=\(photoOutput.availableRawPhotoPixelFormatTypes.count) flash=\(photoOutput.supportedFlashModes.count)")
        session.startRunning()
        log("running=\(session.isRunning)")
        DispatchQueue.main.async { self.previewLayer.session = self.session }
    }

    // MARK: the Camera Control
    @available(iOS 18.0, *)
    nonisolated func setUpControls(_ camera: AVCaptureDevice) {
        log("controls supported=\(session.supportsControls) max=\(session.maxControlsCount)")
        guard session.supportsControls else { return }
        session.setControlsDelegate(self, queue: .main)
        let zoom = AVCaptureSystemZoomSlider(device: camera) { log("zoom slider \(f2(Double($0)))") }
        let bias = AVCaptureSystemExposureBiasSlider(device: camera)
        let intensity = AVCaptureSlider("Intensity", symbolName: "dial.medium", in: 0...10, step: 1)
        intensity.setActionQueue(.main) { log("intensity \(Int($0))") }
        let titles = ["Natural", "Vivid", "Mono"]
        let style = AVCaptureIndexPicker("Style", symbolName: "camera.filters", localizedIndexTitles: titles)
        style.setActionQueue(.main) { log("style \(titles[$0])") }
        for c in [zoom, bias, intensity, style] as [AVCaptureControl] where session.canAddControl(c) { session.addControl(c) }
        log("controls count=\(session.controls.count)")
    }
    nonisolated func sessionControlsDidBecomeActive(_ session: AVCaptureSession) { log("controls active") }
    nonisolated func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) { log("controls fullscreen") }
    nonisolated func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) { log("controls exit fullscreen") }
    nonisolated func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) { log("controls inactive") }

    // MARK: data outputs
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput { audio(sampleBuffer, connection); return }
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if output === backOutput || output === frontOutput {
            let key = output === backOutput ? "back" : "front"
            let (c, _) = pixel(pb, 4, CVPixelBufferGetHeight(pb) / 2)
            DispatchQueue.main.async {
                guard self.multiColors[key] != c else { return }
                self.multiColors[key] = c
                if self.multiColors.count == 2 { log("multicam back=\(self.multiColors["back"]!) front=\(self.multiColors["front"]!)") }
            }
            return
        }
        frames += 1
        guard frames == 1 || frames % 5 == 0 else { return }
        let (corner, lum) = pixel(pb, 4, 4)
        if frames == 1 { log("first frame \(CVPixelBufferGetWidth(pb))x\(CVPixelBufferGetHeight(pb))") }
        if corner != lastCorner || abs(lum - lastLum) > 0.08 {
            lastCorner = corner; lastLum = lum
            log("frame corner=\(corner) lum=\(f2(lum))")
        }
    }
    func audio(_ sb: CMSampleBuffer, _ connection: AVCaptureConnection) {
        audioBuffers += 1
        guard let asbd = sb.formatDescription?.audioStreamBasicDescription, let block = sb.dataBuffer else { return }
        let n = CMSampleBufferGetNumSamples(sb)
        var samples = [Int16](repeating: 0, count: n)
        _ = samples.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: min($0.count, CMBlockBufferGetDataLength(block)), destination: $0.baseAddress!) }
        audioPeak = max(audioPeak, Double(samples.map { abs(Int($0)) }.max() ?? 0) / 32767)
        if audioBuffers == 1 { log("audio \(asbd.mChannelsPerFrame)ch \(Int(asbd.mSampleRate))Hz \(asbd.mBitsPerChannel)bit frames=\(n)") }
        if audioBuffers == 60 {
            let level = connection.audioChannels.first?.averagePowerLevel ?? -160
            log("audio buffers=\(audioBuffers) peak=\(f2(audioPeak)) level=\(Int(level.rounded()))dB")
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for o in metadataObjects {
            let key: String
            if let f = o as? AVMetadataFaceObject { key = "face id=\(f.faceID) x=\(f2(f.bounds.minX))" }
            else if let b = o as? AVMetadataHumanBodyObject { key = "body id=\(b.bodyID)" }
            else if let c = o as? AVMetadataMachineReadableCodeObject { key = "\(c.type == .aztec ? "aztec" : c.type == .dataMatrix ? "datamatrix" : c.type.rawValue) '\(c.stringValue ?? "")' corners=\(c.corners.count)" }
            else { key = o.type.rawValue }
            if seenMetadata.insert(key).inserted { log("metadata \(key)") }
        }
    }
    func dataOutputSynchronizer(_ s: AVCaptureDataOutputSynchronizer, didOutput c: AVCaptureSynchronizedDataCollection) {
        guard !syncLogged else { return }
        let v = c[syncVideoOutput] as? AVCaptureSynchronizedSampleBufferData, d = c[depthOutput] as? AVCaptureSynchronizedDepthData
        guard let v, let d else { return }
        syncLogged = true
        let map = d.depthData.depthDataMap
        log("sync video=\(CMSampleBufferGetImageBuffer(v.sampleBuffer) != nil) depth=\(CVPixelBufferGetWidth(map))x\(CVPixelBufferGetHeight(map)) sameTime=\(v.timestamp == d.timestamp) left=\(f2(Double(disparity(d.depthData, 0.25)))) right=\(f2(Double(disparity(d.depthData, 0.75))))")
    }
    func disparity(_ d: AVDepthData, _ fx: Double) -> Float {
        let dd = d.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let m = dd.depthDataMap
        CVPixelBufferLockBaseAddress(m, .readOnly); defer { CVPixelBufferUnlockBaseAddress(m, .readOnly) }
        let w = CVPixelBufferGetWidth(m), h = CVPixelBufferGetHeight(m)
        let row = CVPixelBufferGetBaseAddress(m)! + (h / 2) * CVPixelBufferGetBytesPerRow(m)
        return row.load(fromByteOffset: Int(Double(w) * fx) * 4, as: Float.self)
    }

    // MARK: photos
    func capture(_ s: AVCapturePhotoSettings, _ note: String) { photoNote = note; bracketLums = []; photoOutput.capturePhoto(with: s, delegate: self) }
    @objc func photoHEIC() { capture(AVCapturePhotoSettings(), "heic") }
    @objc func photoFlash() { let s = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]); s.flashMode = .on; capture(s, "flash") }
    @objc func photoRAW() {
        capture(AVCapturePhotoSettings(rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg]), "raw")
    }
    @objc func photoLive() {
        let s = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("live.mov")
        try? FileManager.default.removeItem(at: url)
        s.livePhotoMovieFileURL = url
        capture(s, "live")
    }
    @objc func photoDepth() { let s = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]); s.isDepthDataDeliveryEnabled = true; capture(s, "depth") }
    @objc func swiftUIEvents() { swiftUICapture.enabled = true; log("swiftui events on") }
    @objc func photoMatte() {
        let s = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        s.isDepthDataDeliveryEnabled = true; s.isPortraitEffectsMatteDeliveryEnabled = true; s.isCameraCalibrationDataDeliveryEnabled = true
        s.enabledSemanticSegmentationMatteTypes = [.hair, .skin]
        capture(s, "matte")
    }
    @objc func photoBracket() {
        let b = [-1, 0, 1].map { AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: Float($0)) }
        capture(AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg], bracketedSettings: b), "bracket")
    }
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        log("will capture \(photoNote) flash=\(resolvedSettings.isFlashEnabled) expected=\(resolvedSettings.expectedPhotoCount)")
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { log("photo error \(error)"); return }
        let data = photo.fileDataRepresentation() ?? Data()
        if photo.isRawPhoto {
            guard let pb = photo.pixelBuffer else { log("raw without pixels"); return }
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            let base = CVPixelBufferGetBaseAddress(pb)!, bpr = CVPixelBufferGetBytesPerRow(pb)
            let r = base.load(as: UInt16.self), g = base.load(fromByteOffset: 2, as: UInt16.self), b = (base + bpr).load(fromByteOffset: 2, as: UInt16.self)
            CVPixelBufferUnlockBaseAddress(pb, .readOnly)
            let dng = String(decoding: data.prefix(3), as: UTF8.self)
            log("raw \(CVPixelBufferGetWidth(pb))x\(CVPixelBufferGetHeight(pb)) format=\(CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_14Bayer_RGGB ? "rggb" : "other") dng=\(dng) bytes=\(data.count) rggb=\(r),\(g),\(b)")
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("photo.dng")
            try? data.write(to: url)
            return
        }
        let brand = data.count > 12 ? String(decoding: data[4..<12], as: UTF8.self) : ""
        let kind = brand.hasPrefix("ftypheic") ? "heic" : data.prefix(2) == Data([0xff, 0xd8]) ? "jpeg" : "none"
        let img = UIImage(data: data)
        let cg = photo.cgImageRepresentation()
        let (corner, lum) = cg.map { pixel($0, 4, 4) } ?? ("none", 0)
        let exif = photo.metadata["{Exif}"] as? [String: Any]
        switch photoNote {
        case "bracket":
            bracketLums.append(f2(lum))
            if bracketLums.count == 3 { log("bracket lums=\(bracketLums.joined(separator: ",")) sequence=\(photo.sequenceCount)") }
        case "depth":
            if let d = photo.depthData {
                log("photo depth type=\(d.depthDataType == kCVPixelFormatType_DisparityFloat16 ? "hdis" : "\(d.depthDataType)") accuracy=\(d.depthDataAccuracy == .absolute ? "absolute" : "relative") left=\(f2(Double(disparity(d, 0.25)))) right=\(f2(Double(disparity(d, 0.75))))")
            } else { log("photo depth none") }
        case "matte":
            func value(_ b: CVPixelBuffer, _ fx: Double) -> Int {
                CVPixelBufferLockBaseAddress(b, .readOnly); defer { CVPixelBufferUnlockBaseAddress(b, .readOnly) }
                let p = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self)
                return Int(p[CVPixelBufferGetHeight(b) / 2 * CVPixelBufferGetBytesPerRow(b) + Int(Double(CVPixelBufferGetWidth(b)) * fx)])
            }
            if let m = photo.portraitEffectsMatte {
                let b = m.mattingImage
                log("photo matte \(CVPixelBufferGetWidth(b))x\(CVPixelBufferGetHeight(b)) left=\(value(b, 0.25)) right=\(value(b, 0.75)) format=\(m.pixelFormatType == kCVPixelFormatType_OneComponent8 ? "L008" : "other")")
            } else { log("photo matte none") }
            let hair = photo.semanticSegmentationMatte(for: .hair), teeth = photo.semanticSegmentationMatte(for: .teeth)
            log("photo semantic hair=\(hair.map { "\(value($0.mattingImage, 0.25))" } ?? "none") teeth=\(teeth == nil ? "none" : "some")")
            if let c = photo.cameraCalibrationData {
                log("photo calibration fx=\(Int(c.intrinsicMatrix.columns.0.x)) cx=\(Int(c.intrinsicMatrix.columns.2.x)) reference=\(Int(c.intrinsicMatrixReferenceDimensions.width))x\(Int(c.intrinsicMatrixReferenceDimensions.height)) depth=\(photo.depthData?.cameraCalibrationData != nil)")
            } else { log("photo calibration none") }
        default:
            log("photo \(photoNote) \(kind) image=\(Int(img?.size.width ?? 0))x\(Int(img?.size.height ?? 0)) corner=\(corner) lum=\(f2(lum)) exifFlash=\(exif?["Flash"] as? Int ?? -1) live=\((photo.metadata["{MakerApple}"] as? [String: Any])?["17"] != nil)")
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        log("live movie recorded \(outputFileURL.lastPathComponent) dims=\(resolvedSettings.livePhotoMovieDimensions.width)x\(resolvedSettings.livePhotoMovieDimensions.height)")
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let a = AVURLAsset(url: outputFileURL)
        log("live movie error=\(error == nil ? "none" : "\(error!)") duration=\(f2(duration.seconds)) display=\(f2(photoDisplayTime.seconds)) file=\(f2(a.duration.seconds)) video=\(a.tracks(withMediaType: .video).count) audio=\(a.tracks(withMediaType: .audio).count)")
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        log("capture finished \(photoNote)")
    }

    // MARK: movie, zoom, torch
    @objc func record() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("movie.mov")
        try? FileManager.default.removeItem(at: url)
        movieOutput.maxRecordedDuration = CMTime(value: 1, timescale: 1)
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let a = AVURLAsset(url: outputFileURL)
        let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        log("movie finished=\(finished) duration=\(f2(a.duration.seconds)) video=\(a.tracks(withMediaType: .video).count) audio=\(a.tracks(withMediaType: .audio).count) connections=\(connections.count)")
    }
    @objc func zoom() {
        guard let c = camera else { return }
        try? c.lockForConfiguration(); c.videoZoomFactor = c.videoZoomFactor > 1 ? 1 : 2; c.unlockForConfiguration()
        log("zoom \(f2(c.videoZoomFactor))")
    }
    @objc func torch() {
        guard let c = camera else { return }
        try? c.lockForConfiguration()
        if c.torchMode == .on { c.torchMode = .off } else { try? c.setTorchModeOn(level: 1) }
        c.unlockForConfiguration()
        log("torch \(c.torchMode == .on ? "on" : "off") active=\(c.isTorchActive)")
    }
    @objc func sync() {
        sessionQueue.async {
            self.depthOutput.isFilteringEnabled = true
            let s = AVCaptureDataOutputSynchronizer(dataOutputs: [self.syncVideoOutput, self.depthOutput])
            s.setDelegate(self, queue: self.videoQueue)
            self.synchronizer = s
            log("synchronizer outputs=\(s.dataOutputs.count) depthConnection=\(self.depthOutput.connection(with: .depthData) != nil)")
        }
    }

    // MARK: multi-cam
    @objc func multicam() {
        sessionQueue.async {
            self.session.stopRunning()
            let m = AVCaptureMultiCamSession()
            guard let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let bi = try? AVCaptureDeviceInput(device: back), let fi = try? AVCaptureDeviceInput(device: front) else { log("multicam: no cameras"); return }
            m.beginConfiguration()
            m.addInputWithNoConnections(bi); m.addInputWithNoConnections(fi)
            for (o, i) in [(self.backOutput, bi), (self.frontOutput, fi)] {
                m.addOutputWithNoConnections(o)
                o.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                o.setSampleBufferDelegate(self, queue: self.videoQueue)
                let port = i.ports(for: .video, sourceDeviceType: i.device.deviceType, sourceDevicePosition: i.device.position)[0]
                m.addConnection(AVCaptureConnection(inputPorts: [port], output: o))
            }
            m.commitConfiguration()
            DispatchQueue.main.sync {
                let backLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: m), frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: m)
                backLayer.frame = self.preview.bounds; frontLayer.frame = self.frontPreview.bounds
                self.previewLayer.removeFromSuperlayer()
                self.preview.layer.addSublayer(backLayer); self.frontPreview.layer.addSublayer(frontLayer)
                let fp = fi.ports(for: .video, sourceDeviceType: front.deviceType, sourceDevicePosition: .front)[0]
                let bp = bi.ports(for: .video, sourceDeviceType: back.deviceType, sourceDevicePosition: .back)[0]
                m.addConnection(AVCaptureConnection(inputPort: bp, videoPreviewLayer: backLayer))
                let fc = AVCaptureConnection(inputPort: fp, videoPreviewLayer: frontLayer)
                m.addConnection(fc)
                log("multicam connections=\(m.connections.count) frontMirrored=\(fc.isVideoMirrored) cost=\(f2(Double(m.hardwareCost)))")
            }
            m.startRunning()
            self.multi = m
            log("multicam running=\(m.isRunning)")
        }
    }
    @objc func stop() {
        sessionQueue.async {
            self.session.stopRunning(); self.multi?.stopRunning()
            log("stopped running=\(self.session.isRunning)")
        }
    }
}
