// isim AVKit: capture events (issue #382). AVCaptureEventInteraction takes the hardware buttons a camera app uses:
// while one is enabled in a view on screen and a capture session runs, the volume buttons (the bezel's, or the
// `volume up|down` script command) and the Camera Control (`cameracontrol press|down|up`, the bezel's button) send
// it began / ended events instead of changing the volume, like iOS. The volume down button and the Camera Control are
// primary, the volume up button secondary. SwiftUI's onCameraCaptureEvent installs one under the view.
import UIKit
import SwiftUI
import AudioToolbox
import isim_host

public enum AVCaptureEventPhase: UInt, @unchecked Sendable {
    case began = 0, ended = 1, cancelled = 2
}

/// A sound a capture event can play (iOS 26).
@available(iOS 26.0, *)
public final class AVCaptureEventSound: NSObject, @unchecked Sendable {
    let _id: SystemSoundID
    let _name: String
    init(id: SystemSoundID, name: String) { _id = id; _name = name }
    public convenience init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile, userInfo: [NSURLErrorKey: url]) }
        var id: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: url]) }
        self.init(id: id, name: url.lastPathComponent)
    }
    public convenience init(URL url: URL) throws { try self.init(url: url) }
    public class var cameraShutter: AVCaptureEventSound { AVCaptureEventSound(id: 1108, name: "cameraShutter") }
    public class var beginVideoRecording: AVCaptureEventSound { AVCaptureEventSound(id: 1117, name: "beginVideoRecording") }
    public class var endVideoRecording: AVCaptureEventSound { AVCaptureEventSound(id: 1118, name: "endVideoRecording") }
}

/// One press of a capture button: its phase.
public final class AVCaptureEvent: NSObject, @unchecked Sendable {
    public let phase: AVCaptureEventPhase
    let _button: String
    init(phase: AVCaptureEventPhase, button: String) { self.phase = phase; _button = button }
    /// iOS 26: false when the interaction's default capture sound is disabled (play(_:) then plays nothing)
    @available(iOS 26.0, *) public var shouldPlaySound: Bool { !AVCaptureEventInteraction.defaultCaptureSoundDisabled }
    @available(iOS 26.0, *) public func play(_ sound: AVCaptureEventSound) -> Bool {
        guard shouldPlaySound else { return false }
        AudioServicesPlaySystemSound(sound._id)
        NSLog("isim: capture event sound %@", sound._name)
        return true
    }
}

/// Takes the volume buttons and the Camera Control for capture while enabled in a view on screen.
public final class AVCaptureEventInteraction: NSObject, UIInteraction, @unchecked Sendable {
    let _primary: (AVCaptureEvent) -> Void
    let _secondary: ((AVCaptureEvent) -> Void)?
    public private(set) weak var view: UIView?
    public var isEnabled = true { didSet { _AVCaptureButtons.update() } }
    /// iOS 26: the events' shouldPlaySound is false
    @available(iOS 26.0, *) nonisolated(unsafe) public static var defaultCaptureSoundDisabled = false
    public init(handler: @escaping (AVCaptureEvent) -> Void) { _primary = handler; _secondary = nil; super.init() }
    public init(primary: @escaping (AVCaptureEvent) -> Void, secondary: @escaping (AVCaptureEvent) -> Void) {
        _primary = primary; _secondary = secondary; super.init()
    }
    public convenience init(eventHandler handler: @escaping (AVCaptureEvent) -> Void) { self.init(handler: handler) }
    public convenience init(primaryEventHandler primary: @escaping (AVCaptureEvent) -> Void, secondaryEventHandler secondary: @escaping (AVCaptureEvent) -> Void) {
        self.init(primary: primary, secondary: secondary)
    }
    public func willMove(to view: UIView?) {}
    public func didMove(to view: UIView?) {
        self.view = view
        if view != nil { _AVCaptureButtons.add(self) }
        _AVCaptureButtons.update()
    }
    func _deliver(_ e: AVCaptureEvent) {
        if e._button == "volumeup", let s = _secondary { s(e) } else { _primary(e) }
    }
}

/// The interactions and the buttons they take (the host sends the volume buttons as capture buttons while any is enabled).
enum _AVCaptureButtons {
    final class Weak { weak var i: AVCaptureEventInteraction?; init(_ i: AVCaptureEventInteraction) { self.i = i } }
    nonisolated(unsafe) static var list: [Weak] = []
    nonisolated(unsafe) static var installed = false
    nonisolated(unsafe) static var taking = false
    static func add(_ i: AVCaptureEventInteraction) {
        install()
        list.removeAll { $0.i == nil || $0.i === i }
        list.append(Weak(i))
    }
    static var enabled: [AVCaptureEventInteraction] { list.compactMap(\.i).filter { $0.isEnabled && $0.view != nil } }
    static func update() {
        let on = !enabled.isEmpty
        guard on != taking else { return }
        taking = on
        isim_capture_buttons(on ? 1 : 0)
    }
    static func install() {
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: nil) { n in
            guard let t = n.object as? String else { return }
            let p = t.split(separator: " ").map(String.init)
            if p.first == "capturebutton", p.count >= 3 { press(p[1], p[2]) }
            else if p.first == "cameracontrol", p.count >= 2, ["press", "down", "up"].contains(p[1]) { press("cameracontrol", p[1]) }
        }
    }
    static var hasCameraControl: Bool {
        let d = ProcessInfo.processInfo.environment["ISIM_DEVICE"] ?? ""
        return (d.hasPrefix("iphone16") && d != "iphone16e") || d.hasPrefix("iphone17") || d == "iphoneair"
    }
    /// a button's press, down or up: to the newest enabled interaction on screen, while a capture session runs
    static func press(_ button: String, _ how: String) {
        if button == "cameracontrol" && !hasCameraControl {
            NSLog("isim: cameracontrol: %@ has no Camera Control", ProcessInfo.processInfo.environment["ISIM_DEVICE"] ?? "this device"); return
        }
        typealias Running = @convention(c) () -> Int32
        let running = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_av_capture_running").map { unsafeBitCast($0, to: Running.self)() != 0 } ?? false
        guard let i = enabled.last(where: { $0.view?.window != nil }), running else {
            if button == "cameracontrol" {
                NSLog("isim: cameracontrol %@: no capture event interaction on screen with a running capture session (iOS would open the Camera app)", how)
            } else if how != "up" {
                // the buttons change the volume as usual
                let v = max(0, min(1, ((isim_device_volume() * 16).rounded() + (button == "volumeup" ? 1 : -1)) / 16))
                isim_device_volume_set(v, 1)
                typealias Event = @convention(c) (UnsafePointer<CChar>) -> Void
                if let f = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_sys_event") { unsafeBitCast(f, to: Event.self)(String(format: "volume %.4f", v)) }
                NSLog("isim: volume %d%%", Int((v * 100).rounded()))
            }
            return
        }
        let phases: [AVCaptureEventPhase] = how == "down" ? [.began] : how == "up" ? [.ended] : [.began, .ended]
        for ph in phases {
            NSLog("isim: capture event %@ %@ (%@)", button, ph == .began ? "began" : "ended", button == "volumeup" && i._secondary != nil ? "secondary" : "primary")
            i._deliver(AVCaptureEvent(phase: ph, button: button))
        }
    }
}

// MARK: - SwiftUI

final class _AVCaptureEventHostView: UIView {
    var interaction: AVCaptureEventInteraction?
}
struct _AVCaptureEventHost: UIViewRepresentable {
    let isEnabled: Bool
    let soundDisabled: Bool?
    let primary: (AVCaptureEvent) -> Void
    let secondary: ((AVCaptureEvent) -> Void)?
    final class Coordinator { var primary: (AVCaptureEvent) -> Void = { _ in }; var secondary: ((AVCaptureEvent) -> Void)? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> _AVCaptureEventHostView {
        let v = _AVCaptureEventHostView()
        v.isUserInteractionEnabled = false
        let c = context.coordinator
        c.primary = primary; c.secondary = secondary
        let i = secondary == nil ? AVCaptureEventInteraction { e in c.primary(e) }
                                 : AVCaptureEventInteraction(primary: { e in c.primary(e) }, secondary: { e in (c.secondary ?? c.primary)(e) })
        v.interaction = i
        v.addInteraction(i)
        return v
    }
    func updateUIView(_ v: _AVCaptureEventHostView, context: Context) {
        context.coordinator.primary = primary; context.coordinator.secondary = secondary
        v.interaction?.isEnabled = isEnabled
        if #available(iOS 26.0, *), let s = soundDisabled { AVCaptureEventInteraction.defaultCaptureSoundDisabled = s }
    }
}

extension View {
    /// the volume buttons and the Camera Control run `action` (began and ended) while the view is on screen
    @available(iOS 18.0, *)
    public func onCameraCaptureEvent(isEnabled: Bool = true, action: @escaping (AVCaptureEvent) -> Void) -> some View {
        background(_AVCaptureEventHost(isEnabled: isEnabled, soundDisabled: nil, primary: action, secondary: nil))
    }
    @available(iOS 18.0, *)
    public func onCameraCaptureEvent(isEnabled: Bool = true, primaryAction: @escaping (AVCaptureEvent) -> Void,
                                     secondaryAction: @escaping (AVCaptureEvent) -> Void) -> some View {
        background(_AVCaptureEventHost(isEnabled: isEnabled, soundDisabled: nil, primary: primaryAction, secondary: secondaryAction))
    }
    @available(iOS 26.0, *)
    public func onCameraCaptureEvent(isEnabled: Bool = true, defaultSoundDisabled: Bool, action: @escaping (AVCaptureEvent) -> Void) -> some View {
        background(_AVCaptureEventHost(isEnabled: isEnabled, soundDisabled: defaultSoundDisabled, primary: action, secondary: nil))
    }
    @available(iOS 26.0, *)
    public func onCameraCaptureEvent(isEnabled: Bool = true, defaultSoundDisabled: Bool, primaryAction: @escaping (AVCaptureEvent) -> Void,
                                     secondaryAction: @escaping (AVCaptureEvent) -> Void) -> some View {
        background(_AVCaptureEventHost(isEnabled: isEnabled, soundDisabled: defaultSoundDisabled, primary: primaryAction, secondary: secondaryAction))
    }
}

// MARK: - device directions (iOS 27.1)

/// A camera, described without opening it.
@available(iOS 27.1, *)
public final class AVCaptureDeviceDescriptor: NSObject, @unchecked Sendable {
    public let uniqueID: String
    public let localizedName: String
    public let deviceType: AVCaptureDevice.DeviceType
    public let mediaTypes: Set<AVMediaType>
    public let position: AVCaptureDevice.Position
    init(_ d: AVCaptureDevice) {
        uniqueID = d.uniqueID; localizedName = d.localizedName; deviceType = d.deviceType; position = d.position
        mediaTypes = Set([AVMediaType.video, .depthData].filter { d.hasMediaType($0) })
    }
}
/// The cameras that face forward (away from the person holding the device) and backward (toward them).
@available(iOS 27.1, *)
public final class AVCaptureDeviceDirectionMap: NSObject, @unchecked Sendable {
    public let forwardFacingDeviceDescriptors: [AVCaptureDeviceDescriptor]
    public let backwardFacingDeviceDescriptors: [AVCaptureDeviceDescriptor]
    init(forward: [AVCaptureDeviceDescriptor], backward: [AVCaptureDeviceDescriptor]) {
        forwardFacingDeviceDescriptors = forward; backwardFacingDeviceDescriptors = backward
    }
}
/// The direction each camera faces for a view (isim: a phone or iPad on its own: the back cameras face forward,
/// the front cameras backward, whatever the orientation; the map does not change, so changeHandler is not called).
@available(iOS 27.1, *)
public final class AVCaptureDeviceDirectionCoordinator: NSObject, @unchecked Sendable {
    weak var _view: UIView?
    let _types: [AVCaptureDevice.DeviceType]
    let _handler: ((AVCaptureDeviceDirectionMap) -> Void)?
    public init(view: UIView, deviceTypes: [AVCaptureDevice.DeviceType], changeHandler: ((AVCaptureDeviceDirectionMap) -> Void)?) {
        _view = view; _types = deviceTypes; _handler = changeHandler
        super.init()
    }
    public var deviceDirections: AVCaptureDeviceDirectionMap {
        let ds = AVCaptureDevice.DiscoverySession(deviceTypes: _types, mediaType: .video, position: .unspecified).devices
        return AVCaptureDeviceDirectionMap(forward: ds.filter { $0.position == .back }.map(AVCaptureDeviceDescriptor.init),
                                           backward: ds.filter { $0.position == .front }.map(AVCaptureDeviceDescriptor.init))
    }
}
