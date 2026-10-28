// isim AVFoundation: the Camera Control (iOS 18) and camera system pressure (issue #382).
// The iPhone 16 (not 16e), 17 and Air presets have a Camera Control. A capture session's controls (sliders, index
// pickers, the system zoom and exposure bias sliders) are driven by the `cameracontrol` script command (adapted: like
// a light press, a swipe along the button, a choice between controls): the selected control's value changes and its
// action runs on its queue, and the session's controls delegate hears when the controls become active and enter or
// leave their full-screen appearance. `camerapressure LEVEL [factors]` sets the cameras' system pressure state
// (KVO-observable); at shutdown running sessions are interrupted. Press, down and up go to AVKit's
// AVCaptureEventInteraction.
import UIKit
import isim_host

// MARK: - controls

/// A control the Camera Control shows for a running capture session.
open class AVCaptureControl: NSObject, @unchecked Sendable {
    open var isEnabled = true
    weak var _session: AVCaptureSession?
    override init() { super.init() }
    var _title: String { "" }
    var _symbol: String { "" }
    /// the value as the overlay shows it
    var _display: String { "" }
    /// where the value sits on the overlay's scale, 0...1 (nil: no scale)
    var _fraction: Double? { nil }
    /// a picker's choices, which the overlay lists instead of a scale
    var _choices: [String]? { nil }
    /// moves the control `n` detents (a swipe), or to `v` (nil: the detents)
    func _change(by n: Int, to v: Double?) {}
}

/// A slider over a range, with steps or over set values.
open class AVCaptureSlider: AVCaptureControl, @unchecked Sendable {
    public let localizedTitle: String
    public let symbolName: String
    let _range: ClosedRange<Float>
    let _step: Float?
    let _values: [Float]?
    var _value: Float
    var _action: ((Float) -> Void)?
    var _queue: DispatchQueue?
    open var prominentValues: [Float] = []
    open var localizedValueFormat: String?
    open var accessibilityIdentifier: String?
    init(title: String, symbol: String, range: ClosedRange<Float>, step: Float?, values: [Float]?) {
        localizedTitle = title; symbolName = symbol; _range = range; _step = step; _values = values?.sorted()
        _value = values?.sorted().first ?? range.lowerBound
        super.init()
    }
    public convenience init(_ localizedTitle: String, symbolName: String, in range: ClosedRange<Float>) {
        self.init(title: localizedTitle, symbol: symbolName, range: range, step: nil, values: nil)
    }
    public convenience init(_ localizedTitle: String, symbolName: String, in range: ClosedRange<Float>, step: Float) {
        self.init(title: localizedTitle, symbol: symbolName, range: range, step: step > 0 ? step : nil, values: nil)
    }
    public convenience init(_ localizedTitle: String, symbolName: String, values: [Float]) {
        let v = values.isEmpty ? [0] : values
        self.init(title: localizedTitle, symbol: symbolName, range: (v.min() ?? 0)...(v.max() ?? 0), step: nil, values: v)
    }
    /// the value, kept in the range (on a step or one of the values)
    open var value: Float {
        get { _value }
        set { _value = _snap(newValue) }
    }
    func _snap(_ v: Float) -> Float {
        if let vs = _values { return vs.min { abs($0 - v) < abs($1 - v) } ?? v }
        var x = min(_range.upperBound, max(_range.lowerBound, v))
        if let s = _step { x = min(_range.upperBound, _range.lowerBound + ((x - _range.lowerBound) / s).rounded() * s) }
        return x
    }
    /// `action` runs on `actionQueue` when the person changes the value with the Camera Control
    open func setActionQueue(_ actionQueue: DispatchQueue, action: @escaping @Sendable (Float) -> ()) { _queue = actionQueue; _action = action }
    override var _title: String { localizedTitle }
    override var _symbol: String { symbolName }
    override var _fraction: Double? {
        let span = Double(_range.upperBound - _range.lowerBound)
        return span > 0 ? Double(_value - _range.lowerBound) / span : 0.5
    }
    override var _display: String {
        if let f = localizedValueFormat, f.contains("%") { return String(format: f.replacingOccurrences(of: "%@", with: "%g"), Double(_value)) }
        return String(format: "%g", Double(_value))
    }
    override func _change(by n: Int, to v: Double?) {
        let old = _value
        if let v { _value = _snap(Float(v)) }
        else if let vs = _values, let i = vs.firstIndex(of: _value) { _value = vs[max(0, min(vs.count - 1, i + n))] }
        else if let s = _step { _value = _snap(_value + Float(n) * s) }
        else { _value = _snap(_value + Float(n) * (_range.upperBound - _range.lowerBound) / 20) }
        guard _value != old else { return }
        _report(_value)
    }
    func _report(_ v: Float) {
        guard let a = _action else { return }
        (_queue ?? .main).async { a(v) }
    }
}

/// The system zoom slider: the Camera Control sets the device's zoom factor (in steps of 10%).
open class AVCaptureSystemZoomSlider: AVCaptureControl, @unchecked Sendable {
    let _device: AVCaptureDevice
    let _action: ((CGFloat) -> Void)?
    public init(device: AVCaptureDevice) { _device = device; _action = nil; super.init() }
    public init(device: AVCaptureDevice, action: @escaping @Sendable (CGFloat) -> Void) { _device = device; _action = action; super.init() }
    override var _title: String { "Zoom" }
    override var _symbol: String { "plus.magnifyingglass" }
    override var _display: String { String(format: "%.1fx", Double(_device.videoZoomFactor * _device.displayVideoZoomFactorMultiplier)) }
    override var _fraction: Double? {         /* zoom moves on a logarithmic scale, as the system zoom does */
        let lo = Double(_device.minAvailableVideoZoomFactor), hi = Double(_device.maxAvailableVideoZoomFactor), z = Double(_device.videoZoomFactor)
        return hi > lo && lo > 0 ? log(z / lo) / log(hi / lo) : 0
    }
    override func _change(by n: Int, to v: Double?) {
        let d = _device
        let target = v.map { CGFloat($0) / d.displayVideoZoomFactorMultiplier } ?? d.videoZoomFactor * pow(1.1, CGFloat(n))
        let z = max(d.minAvailableVideoZoomFactor, min(d.maxAvailableVideoZoomFactor, target))
        guard z != d.videoZoomFactor else { return }
        d.willChangeValue(forKey: "videoZoomFactor")
        d.videoZoomFactor = z
        d.didChangeValue(forKey: "videoZoomFactor")
        if let a = _action { let shown = z * d.displayVideoZoomFactorMultiplier; DispatchQueue.main.async { a(shown) } }
    }
}

/// The system exposure bias slider: the Camera Control sets the device's exposure target bias (in steps of 1/3 EV).
open class AVCaptureSystemExposureBiasSlider: AVCaptureControl, @unchecked Sendable {
    let _device: AVCaptureDevice
    let _action: ((Float) -> Void)?
    public init(device: AVCaptureDevice) { _device = device; _action = nil; super.init() }
    public init(device: AVCaptureDevice, action: @escaping @Sendable (Float) -> Void) { _device = device; _action = action; super.init() }
    override var _title: String { "Exposure" }
    override var _symbol: String { "plusminus.circle" }
    override var _display: String { String(format: "%+.1f", Double(_device.exposureTargetBias)) }
    override var _fraction: Double? {
        let lo = Double(_device.minExposureTargetBias), hi = Double(_device.maxExposureTargetBias)
        return hi > lo ? (Double(_device.exposureTargetBias) - lo) / (hi - lo) : 0.5
    }
    override func _change(by n: Int, to v: Double?) {
        let d = _device
        let b = max(d.minExposureTargetBias, min(d.maxExposureTargetBias, v.map { Float($0) } ?? d.exposureTargetBias + Float(n) / 3))
        guard b != d.exposureTargetBias else { return }
        d.willChangeValue(forKey: "exposureTargetBias")
        d.setExposureTargetBias(b, completionHandler: nil)
        d.didChangeValue(forKey: "exposureTargetBias")
        if let a = _action { DispatchQueue.main.async { a(b) } }
    }
}

/// A picker between named (or numbered) choices.
open class AVCaptureIndexPicker: AVCaptureControl, @unchecked Sendable {
    public let localizedTitle: String
    public let symbolName: String
    public let numberOfIndexes: Int
    public let localizedIndexTitles: [String]
    var _index = 0
    var _action: ((Int) -> Void)?
    var _queue: DispatchQueue?
    open var accessibilityIdentifier: String?
    init(title: String, symbol: String, titles: [String]) {
        localizedTitle = title; symbolName = symbol; numberOfIndexes = titles.count; localizedIndexTitles = titles
        super.init()
    }
    public convenience init(_ localizedTitle: String, symbolName: String, numberOfIndexes: Int) {
        self.init(title: localizedTitle, symbol: symbolName, titles: (0..<max(0, numberOfIndexes)).map { "\($0 + 1)" })
    }
    public convenience init(_ localizedTitle: String, symbolName: String, numberOfIndexes: Int, localizedTitleTransform: @escaping @Sendable (Int) -> String) {
        self.init(title: localizedTitle, symbol: symbolName, titles: (0..<max(0, numberOfIndexes)).map(localizedTitleTransform))
    }
    public convenience init(_ localizedTitle: String, symbolName: String, localizedIndexTitles: [String]) {
        self.init(title: localizedTitle, symbol: symbolName, titles: localizedIndexTitles)
    }
    public convenience init(localizedTitle: String, symbolName: String, numberOfIndexes: Int) {
        self.init(localizedTitle, symbolName: symbolName, numberOfIndexes: numberOfIndexes)
    }
    public convenience init(localizedTitle: String, symbolName: String, numberOfIndexes: Int, localizedTitleTransform: @escaping @Sendable (Int) -> String) {
        self.init(localizedTitle, symbolName: symbolName, numberOfIndexes: numberOfIndexes, localizedTitleTransform: localizedTitleTransform)
    }
    public convenience init(localizedTitle: String, symbolName: String, localizedIndexTitles: [String]) {
        self.init(localizedTitle, symbolName: symbolName, localizedIndexTitles: localizedIndexTitles)
    }
    open var selectedIndex: Int {
        get { _index }
        set { _index = max(0, min(max(0, numberOfIndexes - 1), newValue)) }
    }
    open func setActionQueue(_ actionQueue: DispatchQueue, action: @escaping @Sendable (Int) -> ()) { _queue = actionQueue; _action = action }
    override var _title: String { localizedTitle }
    override var _symbol: String { symbolName }
    override var _display: String { _index < localizedIndexTitles.count ? localizedIndexTitles[_index] : "\(_index)" }
    override var _choices: [String]? { (0..<numberOfIndexes).map { $0 < localizedIndexTitles.count ? localizedIndexTitles[$0] : "\($0)" } }
    override func _change(by n: Int, to v: Double?) {
        let old = _index
        selectedIndex = v.map { Int($0) } ?? _index + n
        guard _index != old, let a = _action else { return }
        let i = _index
        (_queue ?? .main).async { a(i) }
    }
}

public protocol AVCaptureSessionControlsDelegate: NSObjectProtocol {
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession)
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession)
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession)
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession)
}

extension AVCaptureSession {
    /// the device has a Camera Control (iPhone 16 except 16e, iPhone 17, iPhone Air)
    @available(iOS 18.0, *) public var supportsControls: Bool { _CameraControl.hasHardware }
    @available(iOS 18.0, *) public var maxControlsCount: Int { 6 }
    @available(iOS 18.0, *) public var controls: [AVCaptureControl] { _controls }
    @available(iOS 18.0, *) public func canAddControl(_ control: AVCaptureControl) -> Bool {
        guard _CameraControl.hasHardware, _controls.count < 6, control._session == nil else { return false }
        if let z = control as? AVCaptureSystemZoomSlider { return _cameraInputs.contains { $0.device === z._device } }
        if let e = control as? AVCaptureSystemExposureBiasSlider { return _cameraInputs.contains { $0.device === e._device } }
        return true
    }
    @available(iOS 18.0, *) public func addControl(_ control: AVCaptureControl) {
        guard canAddControl(control) else {
            NSLog("isim AVFoundation: addControl: the control cannot be added (iOS raises an exception; check canAddControl, supportsControls and maxControlsCount)")
            return
        }
        control._session = self
        _controls.append(control)
    }
    @available(iOS 18.0, *) public func removeControl(_ control: AVCaptureControl) {
        guard let i = _controls.firstIndex(where: { $0 === control }) else { return }
        _controls.remove(at: i)
        control._session = nil
        if _CameraControl.selected >= _controls.count { _CameraControl.selected = max(0, _controls.count - 1) }
    }
    @available(iOS 18.0, *) public func setControlsDelegate(_ controlsDelegate: (any AVCaptureSessionControlsDelegate)?, queue controlsDelegateCallbackQueue: DispatchQueue?) {
        _controlsDelegate = controlsDelegate; _controlsQueue = controlsDelegate == nil ? nil : controlsDelegateCallbackQueue
    }
    @available(iOS 18.0, *) public var controlsDelegate: (any AVCaptureSessionControlsDelegate)? { _controlsDelegate }
    @available(iOS 18.0, *) public var controlsDelegateCallbackQueue: DispatchQueue? { _controlsQueue }
}

/// The Camera Control's state: which running session it shows, whether its controls are up, which one is selected.
enum _CameraControl {
    static var hasHardware: Bool {
        let d = ProcessInfo.processInfo.environment["ISIM_DEVICE"] ?? ""
        return (d.hasPrefix("iphone16") && d != "iphone16e") || d.hasPrefix("iphone17") || d == "iphoneair"
    }
    nonisolated(unsafe) static weak var session: AVCaptureSession?
    nonisolated(unsafe) static var active = false
    nonisolated(unsafe) static var selected = 0
    /// a second light press: the overlay lists every control to choose from
    nonisolated(unsafe) static var choosing = false
    static func started(_ s: AVCaptureSession) { session = s }
    static func stopped(_ s: AVCaptureSession) {
        DispatchQueue.main.async {
            guard session === s else { return }
            if active { setActive(false) }
            session = nil
        }
    }
    static func notify(_ s: AVCaptureSession, _ f: @escaping (any AVCaptureSessionControlsDelegate) -> Void) {
        guard let d = s._controlsDelegate else { return }
        (s._controlsQueue ?? .main).async { f(d) }
    }
    static func setActive(_ on: Bool) {
        guard let s = session, on != active else { return }
        active = on
        if !on { choosing = false }
        DispatchQueue.main.async { MainActor.assumeIsolated { _CameraControlOverlay.update() } }
        if on {
            notify(s) { $0.sessionControlsDidBecomeActive(s) }
            notify(s) { $0.sessionControlsWillEnterFullscreenAppearance(s) }
        } else {
            notify(s) { $0.sessionControlsWillExitFullscreenAppearance(s) }
            notify(s) { $0.sessionControlsDidBecomeInactive(s) }
        }
    }
    static var enabled: [AVCaptureControl] { session?._controls.filter(\.isEnabled) ?? [] }
    /// the state as text: `cameracontrol controls=N active=0|1 selected=I` and each control's title and value
    static func state() -> String {
        let cs = enabled
        var line = "isim: cameracontrol controls=\(cs.count) active=\(active ? 1 : 0) selected=\(min(selected, max(0, cs.count - 1)))" + (choosing ? " choosing=1" : "")
        for (i, c) in cs.enumerated() { line += " [\(i)] \(c._title)=\(c._display)" }
        return line
    }
    static func command(_ args: String) {
        let p = args.split(separator: " ").map(String.init)
        let verb = p.first ?? ""
        if ["press", "down", "up"].contains(verb) { return }       // capture events: AVKit (AVCaptureEventInteraction)
        guard hasHardware else {
            NSLog("isim: cameracontrol: %@ has no Camera Control", ProcessInfo.processInfo.environment["ISIM_DEVICE"] ?? "this device"); return
        }
        if verb.isEmpty { NSLog("%@", state()); return }
        guard session?.isRunning == true, !enabled.isEmpty else {
            NSLog("isim: cameracontrol %@: no running capture session with controls", args); return
        }
        let cs = enabled
        switch verb {
        case "lightpress": if active { choosing = true } else { setActive(true) }      // a second light press: choose a control
        case "dismiss": setActive(false)
        case "select":
            setActive(true)
            choosing = false
            selected = max(0, min(cs.count - 1, Int(p.count > 1 ? p[1] : "0") ?? 0))
        case "swipe", "set":
            setActive(true)
            choosing = false
            selected = min(selected, cs.count - 1)
            let n = p.count > 1 ? Double(p[1]) : nil
            if verb == "swipe" { cs[selected]._change(by: Int(n ?? 1), to: nil) } else if let n { cs[selected]._change(by: 0, to: n) }
        default:
            NSLog("isim: cameracontrol [press|down|up|lightpress|select I|swipe N|set V|dismiss]"); return
        }
        NSLog("%@", state())
        DispatchQueue.main.async { MainActor.assumeIsolated { _CameraControlOverlay.update() } }
    }
}

// MARK: - system pressure

/// the pressure state in a system-pressure interruption's user info
public let AVCaptureSessionInterruptionSystemPressureStateKey = "AVCaptureSessionInterruptionSystemPressureStateKey"

enum _CameraPressure {
    nonisolated(unsafe) static var state = AVCaptureDevice.SystemPressureState()
    static func command(_ args: String) {
        let p = args.split(separator: " ").map(String.init)
        guard let l = p.first, ["nominal", "fair", "serious", "critical", "shutdown"].contains(l) else {
            NSLog("isim: camerapressure nominal|fair|serious|critical|shutdown [temperature,power,depth,camera,battery] (now %@)", state.level.rawValue); return
        }
        var f: AVCaptureDevice.SystemPressureState.Factors = []
        for name in (p.count > 1 ? p[1] : "").split(separator: ",") {
            switch name {
            case "temperature": f.insert(.systemTemperature)
            case "power": f.insert(.peakPower)
            case "depth": f.insert(.depthModuleTemperature)
            case "camera": f.insert(.cameraTemperature)
            case "battery": f.insert(AVCaptureDevice.SystemPressureState.Factors(rawValue: 16))
            default: break
            }
        }
        if l != "nominal" && f.isEmpty { f = .systemTemperature }
        let devices = AVCaptureDevice._all.filter { !$0._isMicrophone }
        for d in devices { d.willChangeValue(forKey: "systemPressureState") }
        state = AVCaptureDevice.SystemPressureState(level: AVCaptureDevice.SystemPressureState.Level(rawValue: l), factors: f)
        for d in devices { d.didChangeValue(forKey: "systemPressureState") }
        NSLog("isim: camerapressure %@ factors=%lu", l, f.rawValue)
        _AVCaptureEvents.sessions.forEach { $0._pressureChanged() }
    }
}

// MARK: - the script events

/// `cameracontrol …` and `camerapressure …` from the script (UIKit posts them as `_IsimSystemEvent`)
enum _AVCaptureEvents {
    nonisolated(unsafe) static var installed = false
    nonisolated(unsafe) static var _sessions: [Weak] = []
    final class Weak { weak var s: AVCaptureSession?; init(_ s: AVCaptureSession) { self.s = s } }
    static var sessions: [AVCaptureSession] { _sessions.compactMap(\.s) }
    static func install() {
        if !installed {
            installed = true
            NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: nil) { n in
                guard let t = n.object as? String else { return }
                let verb = t.prefix { $0 != " " }, args = t.dropFirst(verb.count).trimmingCharacters(in: .whitespaces)
                if verb == "cameracontrol" { _CameraControl.command(args) }
                else if verb == "camerapressure" { _CameraPressure.command(args) }
            }
        }
    }
    static func track(_ s: AVCaptureSession) { _sessions.removeAll { $0.s == nil }; _sessions.append(Weak(s)) }
}

/// UIKit reports script commands to apps without AVFoundation capture loaded
@_cdecl("isim_av_capture_loaded") public func _isimAVCaptureLoaded() -> Int32 { _AVCaptureEvents.installed ? 1 : 0 }
/// AVKit: a running capture session (capture events are delivered only while one runs, like iOS)
@_cdecl("isim_av_capture_running") public func _isimAVCaptureRunning() -> Int32 { _AVCaptureEvents.sessions.contains { $0.isRunning } ? 1 : 0 }
