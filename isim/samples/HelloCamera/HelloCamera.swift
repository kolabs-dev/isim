// Sample: the camera on isim — AVCaptureDevice discovery and permission, AVCaptureSession with a device input,
// AVCaptureVideoPreviewLayer, AVCapturePhotoOutput, AVCaptureVideoDataOutput (BGRA sample buffers),
// AVCaptureMetadataOutput (QR codes) and AVCaptureMovieFileOutput. isim's simulated camera shows ISIM_CAMERA (an image,
// a video, or the host webcam); without it there is no camera, like the Simulator.
import UIKit
import AVFoundation

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CameraViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloCamera: %@", s) }
func color(_ p: UnsafePointer<UInt8>) -> String {      // BGRA
    let b = p[0], g = p[1], r = p[2]
    if r > 180 && g < 80 && b < 80 { return "red" }
    if g > 180 && r < 80 && b < 80 { return "green" }
    if b > 180 && r < 80 && g < 80 { return "blue" }
    return "rgb(\(r),\(g),\(b))"
}

final class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate,
                                  AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    let preview = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer()
    let codeLabel = UILabel(), frameLabel = UILabel()
    let photoView = UIImageView()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    let metadataOutput = AVCaptureMetadataOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let sessionQueue = DispatchQueue(label: "session")
    let videoQueue = DispatchQueue(label: "video")
    var frames = 0
    var colors: [String] = []
    var lastCode = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Camera"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        preview.frame = CGRect(x: 20, y: 120, width: 362, height: 272)
        preview.backgroundColor = .black; preview.accessibilityIdentifier = "preview"
        previewLayer.frame = preview.bounds
        previewLayer.videoGravity = .resizeAspect
        preview.layer.addSublayer(previewLayer)
        view.addSubview(preview)
        codeLabel.frame = CGRect(x: 20, y: 400, width: 362, height: 22); codeLabel.accessibilityIdentifier = "code"
        frameLabel.frame = CGRect(x: 20, y: 424, width: 362, height: 22); frameLabel.accessibilityIdentifier = "frames"
        view.addSubview(codeLabel); view.addSubview(frameLabel)
        photoView.frame = CGRect(x: 20, y: 500, width: 160, height: 120); photoView.backgroundColor = .lightGray
        photoView.accessibilityIdentifier = "photo"; view.addSubview(photoView)
        for (i, (t, id, sel)) in [("Photo", "takephoto", #selector(takePhoto)), ("Record 1 s", "record", #selector(record)), ("Stop", "stop", #selector(stop))].enumerated() {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.frame = CGRect(x: 20 + 120 * i, y: 452, width: 110, height: 40); b.addTarget(self, action: sel, for: .touchUpInside)
            view.addSubview(b)
        }

        let device = AVCaptureDevice.default(for: .video)
        let found = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices
        log("device \(device?.localizedName ?? "none") position=\(device?.position.rawValue ?? 0) discovered=\(found.map(\.localizedName).joined(separator: ",")) status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
        if let d = device {
            let dims = d.activeFormat.formatDescription.dimensions
            log("format \(dims.width)x\(dims.height) fps=\(Int(d.activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0))")
            do { try d.lockForConfiguration(); d.focusMode = .continuousAutoFocus; d.unlockForConfiguration(); log("configured focus") } catch { log("lock error \(error)") }
        }
        self.device = device
    }
    var device: AVCaptureDevice?
    var asked = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !asked else { return }
        asked = true
        let device = self.device
        AVCaptureDevice.requestAccess(for: .video) { ok in
            log("access \(ok)")
            self.sessionQueue.async { self.configure(device) }
        }
    }

    func configure(_ device: AVCaptureDevice?) {
        guard let device else { log("no camera"); return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            log("input error \((error as NSError).code) \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }
        for o in [photoOutput, videoOutput, metadataOutput, movieOutput] as [AVCaptureOutput] where session.canAddOutput(o) { session.addOutput(o) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        log("metadata types available qr=\(metadataOutput.availableMetadataObjectTypes.contains(.qr))")
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) { metadataOutput.metadataObjectTypes = [.qr, .ean13] }
        session.commitConfiguration()
        session.startRunning()
        log("session running=\(session.isRunning) inputs=\(session.inputs.count) outputs=\(session.outputs.count)")
        DispatchQueue.main.async { self.previewLayer.session = self.session }
    }

    // MARK: delegates
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frames += 1
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if frames == 1 || frames % 15 == 0 {
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
            let c = color(base + 4 * 4 + 4 * CVPixelBufferGetBytesPerRow(pb))
            if frames == 1 { log("first frame \(CVPixelBufferGetWidth(pb))x\(CVPixelBufferGetHeight(pb)) format=\(CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_32BGRA ? "BGRA" : "other") corner=\(c)") }
            if colors.last != c { colors.append(c); log("frame colors \(colors.joined(separator: ","))") }
            CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        }
        if frames % 30 == 0 { let n = frames; DispatchQueue.main.async { self.frameLabel.text = "\(n) frames" } }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let s = code.stringValue, s != lastCode else { return }
        lastCode = s
        codeLabel.text = s
        let r = previewLayer.transformedMetadataObject(for: code)?.bounds ?? .zero
        log("metadata \(code.type == .qr ? "qr" : code.type.rawValue) '\(s)' corners=\(code.corners.count) inPreview=\(previewLayer.bounds.contains(r)) center=\(Int(r.midX)),\(Int(r.midY))")
    }
    @objc func takePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { log("photo error \(error)"); return }
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { log("photo has no data"); return }
        photoView.image = img
        log("photo \(Int(img.size.width))x\(Int(img.size.height)) jpeg=\(data.prefix(2).map { String(format: "%02x", $0) }.joined()) cg=\(photo.cgImageRepresentation()?.width ?? 0)")
    }
    @objc func record() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip.mov")
        try? FileManager.default.removeItem(at: url)
        movieOutput.maxRecordedDuration = CMTime(value: 1, timescale: 1)
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) { log("recording started") }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let a = AVURLAsset(url: outputFileURL)
        let size = a.tracks(withMediaType: .video).first?.naturalSize ?? .zero
        log("recorded error=\(error == nil ? "none" : "\(error!)") duration=\(String(format: "%.1f", a.duration.seconds)) size=\(Int(size.width))x\(Int(size.height))")
    }
    @objc func stop() {
        sessionQueue.async {
            self.session.stopRunning()
            log("session stopped running=\(self.session.isRunning)")
        }
    }
}
