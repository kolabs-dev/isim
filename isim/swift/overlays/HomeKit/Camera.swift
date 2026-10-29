// isim HomeKit: cameras (accessories with a camera stream management service). isim's simulated cameras have no
// video: a stream and a snapshot show a drawn picture of the camera's scene with its name and the time (adapted).
import Foundation
import UIKit
import SwiftUI

@objc(HMCameraProfile)
open class HMCameraProfile: HMAccessoryProfile {
    private func control<T: NSObject>(_ key: String, _ make: () -> T) -> T { _HMObjects.shared.object("\(_services.first ?? _accessory)-\(key)", make) }
    private func characteristic(_ service: String, _ type: String) -> HMCharacteristic? {
        let svc = _HMStore.shared.accessory(_accessory)?.services.first { $0.type == _HMTypes.service(service) }
        return svc?.characteristics.first { $0.type == _HMTypes.characteristic(type) }.map { _HMObjects.shared.characteristic($0.id) }
    }
    @objc public var streamControl: HMCameraStreamControl? { control("stream") { HMCameraStreamControl(_accessory: _accessory) } }
    @objc public var snapshotControl: HMCameraSnapshotControl? { control("snapshot") { HMCameraSnapshotControl(_accessory: _accessory) } }
    @objc public var settingsControl: HMCameraSettingsControl? {
        guard _HMStore.shared.accessory(_accessory)?.services.contains(where: { $0.type == _HMTypes.service("CameraControl") }) == true else { return nil }
        return control("settings") { HMCameraSettingsControl(_profile: self) }
    }
    @objc public var speakerControl: HMCameraAudioControl? {
        guard characteristic("Speaker", "Mute") != nil else { return nil }
        return control("speaker") { HMCameraAudioControl(mute: self.characteristic("Speaker", "Mute"), volume: self.characteristic("Speaker", "Volume")) }
    }
    @objc public var microphoneControl: HMCameraAudioControl? {
        guard characteristic("Microphone", "Mute") != nil else { return nil }
        return control("microphone") { HMCameraAudioControl(mute: self.characteristic("Microphone", "Mute"), volume: self.characteristic("Microphone", "Volume")) }
    }
    func _settings(_ type: String) -> HMCharacteristic? { characteristic("CameraControl", type) }
}

@objc(HMCameraControl)
open class HMCameraControl: NSObject {
    @available(*, unavailable) @objc public override init() { fatalError() }
    init(_internal: Void) { super.init() }
}

@objc(HMCameraSettingsControl)
open class HMCameraSettingsControl: HMCameraControl {
    private weak var _profile: HMCameraProfile?
    init(_profile: HMCameraProfile) { self._profile = _profile; super.init(_internal: ()) }
    @objc public var currentHorizontalTilt: HMCharacteristic? { _profile?._settings("CurrentHorizontalTilt") }
    @objc public var targetHorizontalTilt: HMCharacteristic? { _profile?._settings("TargetHorizontalTilt") }
    @objc public var currentVerticalTilt: HMCharacteristic? { _profile?._settings("CurrentVerticalTilt") }
    @objc public var targetVerticalTilt: HMCharacteristic? { _profile?._settings("TargetVerticalTilt") }
    @objc public var opticalZoom: HMCharacteristic? { _profile?._settings("OpticalZoom") }
    @objc public var digitalZoom: HMCharacteristic? { _profile?._settings("DigitalZoom") }
    @objc public var imageRotation: HMCharacteristic? { _profile?._settings("ImageRotation") }
    @objc public var imageMirroring: HMCharacteristic? { _profile?._settings("ImageMirroring") }
    @objc public var nightVision: HMCharacteristic? { _profile?._settings("NightVision") }
}

@objc(HMCameraAudioControl)
open class HMCameraAudioControl: HMCameraControl {
    let _mute: HMCharacteristic?, _volume: HMCharacteristic?
    init(mute: HMCharacteristic?, volume: HMCharacteristic?) { _mute = mute; _volume = volume; super.init(_internal: ()) }
    @objc public var mute: HMCharacteristic? { _mute }
    @objc public var volume: HMCharacteristic? { _volume }
}

@objc(HMCameraSource)
open class HMCameraSource: NSObject {
    let _accessory: String
    init(_accessory: String) { self._accessory = _accessory; super.init() }
    @available(*, unavailable) @objc public override init() { fatalError() }
    @objc public var aspectRatio: Double { 16.0 / 9.0 }
    var _name: String { _HMStore.shared.accessory(_accessory)?.name ?? "Camera" }
}

@objc(HMCameraStream)
open class HMCameraStream: HMCameraSource {
    var _audio: HMCameraAudioStreamSetting = .muted
    @objc public var audioStreamSetting: HMCameraAudioStreamSetting { _audio }
    @objc(updateAudioStreamSetting:completionHandler:)
    open func updateAudioStreamSetting(_ audioStreamSetting: HMCameraAudioStreamSetting, completionHandler completion: @escaping (Error?) -> Void) {
        _audio = audioStreamSetting
        _hmReply { completion(nil) }
    }
    @available(iOS, introduced: 10.0, deprecated: 10.0, message: "Use updateAudioStreamSetting(_:completionHandler:)")
    @objc(setAudioStreamSetting:)
    open func setAudioStreamSetting(_ audioStreamSetting: HMCameraAudioStreamSetting) { _audio = audioStreamSetting }
}

@objc(HMCameraSnapshot)
open class HMCameraSnapshot: HMCameraSource {
    let _date: Date
    init(_accessory: String, date: Date) { _date = date; super.init(_accessory: _accessory) }
    @objc public var captureDate: Date { _date }
}

@objc(HMCameraStreamControlDelegate)
public protocol HMCameraStreamControlDelegate: NSObjectProtocol {
    @objc(cameraStreamControlDidStartStream:) optional func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl)
    @objc(cameraStreamControl:didStopStreamWithError:) optional func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?)
}

@objc(HMCameraStreamControl)
open class HMCameraStreamControl: HMCameraControl {
    let _accessory: String
    var _state: HMCameraStreamState = .notStreaming
    var _stream: HMCameraStream?
    init(_accessory: String) { self._accessory = _accessory; super.init(_internal: ()) }
    @objc public weak var delegate: (any HMCameraStreamControlDelegate)?
    @objc public var streamState: HMCameraStreamState { _state }
    @objc public var cameraStream: HMCameraStream? { _stream }

    @objc open func startStream() {
        guard _state == .notStreaming else { return }
        guard _HMStore.shared.accessory(_accessory)?.reachable ?? true else {
            _hmReply { self.delegate?.cameraStreamControl?(self, didStopStreamWithError: _hmErr(.accessoryNotReachable)) }; return
        }
        _state = .starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self._state == .starting else { return }
            self._stream = HMCameraStream(_accessory: self._accessory)
            self._state = .streaming
            NSLog("isim HomeKit: %@ is streaming", self._stream!._name)
            self.delegate?.cameraStreamControlDidStartStream?(self)
        }
    }
    @objc open func stopStream() {
        guard _state == .streaming || _state == .starting else { return }
        _state = .stopping
        _hmReply {
            self._state = .notStreaming
            self._stream = nil
            self.delegate?.cameraStreamControl?(self, didStopStreamWithError: nil)
        }
    }
}

@objc(HMCameraSnapshotControlDelegate)
public protocol HMCameraSnapshotControlDelegate: NSObjectProtocol {
    @objc(cameraSnapshotControl:didTakeSnapshot:error:) optional func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?)
    @objc(cameraSnapshotControlDidUpdateMostRecentSnapshot:) optional func cameraSnapshotControlDidUpdateMostRecentSnapshot(_ cameraSnapshotControl: HMCameraSnapshotControl)
}

@objc(HMCameraSnapshotControl)
open class HMCameraSnapshotControl: HMCameraControl {
    let _accessory: String
    var _recent: HMCameraSnapshot?
    init(_accessory: String) { self._accessory = _accessory; super.init(_internal: ()) }
    @objc public weak var delegate: (any HMCameraSnapshotControlDelegate)?
    @objc public var mostRecentSnapshot: HMCameraSnapshot? { _recent }
    @objc open func takeSnapshot() {
        guard _HMStore.shared.accessory(_accessory)?.reachable ?? true else {
            _hmReply { self.delegate?.cameraSnapshotControl?(self, didTake: nil, error: _hmErr(.accessoryNotReachable)) }; return
        }
        let s = HMCameraSnapshot(_accessory: _accessory, date: Date())
        _hmReply {
            self._recent = s
            self.delegate?.cameraSnapshotControl?(self, didTake: s, error: nil)
            self.delegate?.cameraSnapshotControlDidUpdateMostRecentSnapshot?(self)
        }
    }
}

/// shows a camera stream or snapshot: isim's simulated picture (a porch at dusk, the camera's name and the time)
@objc(HMCameraView)
open class HMCameraView: UIView {
    private var timer: Timer?
    @objc public var cameraSource: HMCameraSource? {
        didSet {
            timer?.invalidate()
            timer = nil
            if cameraSource is HMCameraStream {
                let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.setNeedsDisplay() }
                RunLoop.main.add(t, forMode: .common)
                timer = t
            }
            setNeedsDisplay()
        }
    }
    public override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .black; contentMode = .redraw }
    @objc public convenience init() { self.init(frame: .zero) }
    public required init?(coder: NSCoder) { super.init(coder: coder); backgroundColor = .black }
    deinit { timer?.invalidate() }

    open override func draw(_ rect: CGRect) {
        guard let src = cameraSource, let ctx = UIGraphicsGetCurrentContext() else { return }
        // the picture, letterboxed to the source's aspect ratio
        var pic = bounds
        if bounds.width / max(bounds.height, 1) > src.aspectRatio {
            pic.size.width = bounds.height * src.aspectRatio; pic.origin.x = (bounds.width - pic.width) / 2
        } else {
            pic.size.height = bounds.width / src.aspectRatio; pic.origin.y = (bounds.height - pic.height) / 2
        }
        let colors = [UIColor(red: 0.22, green: 0.28, blue: 0.42, alpha: 1).cgColor, UIColor(red: 0.62, green: 0.52, blue: 0.48, alpha: 1).cgColor]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            ctx.saveGState(); ctx.clip(to: pic)
            ctx.drawLinearGradient(g, start: CGPoint(x: pic.midX, y: pic.minY), end: CGPoint(x: pic.midX, y: pic.maxY), options: [])
            ctx.restoreGState()
        }
        // a door and the path to it
        UIColor(red: 0.35, green: 0.25, blue: 0.2, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: pic.midX - pic.width * 0.08, y: pic.minY + pic.height * 0.3, width: pic.width * 0.16, height: pic.height * 0.5)).fill()
        UIColor(white: 0.55, alpha: 1).setFill()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: pic.midX - pic.width * 0.08, y: pic.minY + pic.height * 0.8))
        path.addLine(to: CGPoint(x: pic.midX + pic.width * 0.08, y: pic.minY + pic.height * 0.8))
        path.addLine(to: CGPoint(x: pic.midX + pic.width * 0.2, y: pic.maxY))
        path.addLine(to: CGPoint(x: pic.midX - pic.width * 0.2, y: pic.maxY))
        path.close(); path.fill()
        let date = (src as? HMCameraSnapshot)?.captureDate ?? Date()
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        let text = "\(src._name)  \(f.string(from: date))\(src is HMCameraStream ? "  LIVE" : "")" as NSString
        text.draw(at: CGPoint(x: pic.minX + 8, y: pic.minY + 6), withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                                                                                    .foregroundColor: UIColor.white])
    }
}

/// a SwiftUI view of a camera stream or snapshot
public struct CameraView: UIViewRepresentable {
    let source: HMCameraSource
    public init(source: HMCameraSource) { self.source = source }
    public func makeUIView(context: Context) -> HMCameraView { let v = HMCameraView(); v.cameraSource = source; return v }
    public func updateUIView(_ view: HMCameraView, context: Context) { if view.cameraSource !== source { view.cameraSource = source } }
}
