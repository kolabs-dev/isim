// isim GameController: what host pads report besides their buttons — battery, light bar and motion sensors (SDL3's
// gamepad power info, LED and sensor API) — and the host pointer as GCMouse. Self-authored, iOS API names.
// - GCDeviceBattery: SDL's power state and percentage, read when asked (passthrough).
// - GCDeviceLight: the colour goes to the pad's light bar (DualShock 4 / DualSense; passthrough).
// - GCMotion: the pad's accelerometer and gyroscope (passthrough), read at 60 Hz while active; like iOS for
//   DualShock / DualSense, the sensors need manual activation and there is no gravity / user-acceleration split.
// - GCMouse: the pointer over the device window (relative motion, buttons, scroll wheel), adapted: always the same
//   mouse; `mouse` script commands drive it in tests.
import Foundation
import isim_host

// MARK: - battery

open class GCDeviceBattery: NSObject {
    @objc public enum State: Int, Sendable { case unknown = -1, discharging = 0, charging = 1, full = 2 }
    let pad: Int32
    init(pad: Int32) { self.pad = pad; super.init() }
    var _read: (Int32, Int32) { var pct: Int32 = -1; let st = isim_gamepad_battery(pad, &pct); return (st, pct) }
    /// 0...1 (0 when the pad does not report it)
    open var batteryLevel: Float { let (_, pct) = _read; return pct >= 0 ? Float(pct) / 100 : 0 }
    open var batteryState: State {
        switch _read.0 { case 1: return .discharging; case 2: return .charging; case 3: return .full; default: return .unknown }
    }
}

// MARK: - light

open class GCColor: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let red: Float, green: Float, blue: Float
    public init(red: Float, green: Float, blue: Float) { self.red = red; self.green = green; self.blue = blue }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(red, forKey: "red"); coder.encode(green, forKey: "green"); coder.encode(blue, forKey: "blue") }
    public required init?(coder: NSCoder) {
        red = coder.decodeFloat(forKey: "red"); green = coder.decodeFloat(forKey: "green"); blue = coder.decodeFloat(forKey: "blue")
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? GCColor else { return false }
        return o.red == red && o.green == green && o.blue == blue
    }
    open override var hash: Int { Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) }
}

/// The light bar of a pad that has one; setting the colour lights it.
open class GCDeviceLight: NSObject {
    let pad: Int32
    init(pad: Int32) { self.pad = pad; super.init() }
    open var color = GCColor(red: 0, green: 0, blue: 1) {
        didSet { _ = isim_gamepad_set_light(pad, Double(color.red), Double(color.green), Double(color.blue)) }
    }
}

// MARK: - motion

public struct GCAcceleration: Sendable, Equatable {
    public var x: Double, y: Double, z: Double
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
}
public struct GCRotationRate: Sendable, Equatable {
    public var x: Double, y: Double, z: Double
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
}
public struct GCQuaternion: Sendable, Equatable {
    public var x: Double, y: Double, z: Double, w: Double
    public init() { x = 0; y = 0; z = 0; w = 1 }
    public init(x: Double, y: Double, z: Double, w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
}
public typealias GCMotionValueChangedHandler = (GCMotion) -> Void

/// A pad's motion sensors. Values: acceleration in g (gravity included), rotation rate in radians per second, in
/// the controller's frame (x right, y up, z towards the player, like iOS); SDL's axes are mapped to it.
open class GCMotion: NSObject {
    open internal(set) weak var controller: GCController?
    open var valueChangedHandler: GCMotionValueChangedHandler?
    let pad: Int32
    let _has: Int32
    init(pad: Int32, controller: GCController) {
        self.pad = pad; self.controller = controller
        _has = isim_gamepad_motion(pad, -1, nil, nil)
        super.init()
    }
    /// pads' sensors stay off until the app turns them on (they drain the battery), as on iOS
    open var sensorsRequireManualActivation: Bool { true }
    open var sensorsActive = false {
        didSet {
            guard sensorsActive != oldValue else { return }
            _ = isim_gamepad_motion(pad, sensorsActive ? 1 : 0, nil, nil)
            if sensorsActive { _GCHostPads.activeMotion.append(self) } else { _GCHostPads.activeMotion.removeAll { $0 === self } }
        }
    }
    open var hasGravityAndUserAcceleration: Bool { false }
    open var hasAttitude: Bool { false }
    open var hasRotationRate: Bool { _has & 2 != 0 }
    open var hasAttitudeAndRotationRate: Bool { false }
    open internal(set) var acceleration = GCAcceleration()
    open internal(set) var gravity = GCAcceleration()
    open internal(set) var userAcceleration = GCAcceleration()
    open internal(set) var attitude = GCQuaternion()
    open internal(set) var rotationRate = GCRotationRate()
    open func setGravity(_ gravity: GCAcceleration) { self.gravity = gravity }
    open func setUserAcceleration(_ userAcceleration: GCAcceleration) { self.userAcceleration = userAcceleration }
    open func setAcceleration(_ acceleration: GCAcceleration) { self.acceleration = acceleration }
    open func setAttitude(_ attitude: GCQuaternion) { self.attitude = attitude }
    open func setRotationRate(_ rotationRate: GCRotationRate) { self.rotationRate = rotationRate }
    open func setState(fromMotion motion: GCMotion) {
        acceleration = motion.acceleration; gravity = motion.gravity; userAcceleration = motion.userAcceleration
        attitude = motion.attitude; rotationRate = motion.rotationRate
    }
    /// reads the host's sensors; calls the handler when they changed
    func _poll() {
        var a = [Float](repeating: 0, count: 3), g = [Float](repeating: 0, count: 3)
        _ = isim_gamepad_motion(pad, -1, &a, &g)
        // SDL: x right, y up, z towards the player, m/s²
        let acc = GCAcceleration(x: Double(a[0]) / 9.80665, y: Double(a[1]) / 9.80665, z: Double(a[2]) / 9.80665)
        let rot = GCRotationRate(x: Double(g[0]), y: Double(g[1]), z: Double(g[2]))
        guard acc != acceleration || rot != rotationRate else { return }
        acceleration = acc; rotationRate = rot
        let h = valueChangedHandler
        if let h, let c = controller { c.handlerQueue.async { h(self) } } else { h?(self) }
    }
}

// MARK: - mouse

public typealias GCMouseMoved = (GCMouseInput, Float, Float) -> Void

/// A scroll wheel: a direction pad whose values are the scroll since the last change.
open class GCDeviceCursor: GCControllerDirectionPad {
    override init(name: String?, analog: Bool = false) {
        super.init(name: name, analog: true)
        xAxis._unclamped = true; yAxis._unclamped = true
    }
}

open class GCMouseInput: GCPhysicalInputProfile {
    open var mouseMovedHandler: GCMouseMoved?
    public let scroll = GCDeviceCursor(name: "Scroll")
    public let leftButton = GCControllerButtonInput(name: "Left Button")
    open internal(set) var rightButton: GCControllerButtonInput? = GCControllerButtonInput(name: "Right Button")
    open internal(set) var middleButton: GCControllerButtonInput? = GCControllerButtonInput(name: "Middle Button")
    open internal(set) var auxiliaryButtons: [GCControllerButtonInput]? = [GCControllerButtonInput(name: "Button 4"), GCControllerButtonInput(name: "Button 5")]
    override init() {
        super.init()
        register(scroll, "Scroll"); register(leftButton, "Left Button")
        if let r = rightButton { register(r, "Right Button") }
        if let m = middleButton { register(m, "Middle Button") }
        for b in auxiliaryButtons ?? [] { register(b, b.localizedName ?? "") }
    }
}

open class GCMouse: NSObject, GCDevice {
    nonisolated(unsafe) static var _shared: GCMouse?
    nonisolated(unsafe) static var _connected = false
    let input = GCMouseInput()
    public override init() { super.init(); input.device = self }
    /// the host's pointer, once it moved over the device (or a `mouse` script command ran)
    open class var current: GCMouse? { _GCSystem.start(); return _connected ? _shared : nil }
    open class func mice() -> [GCMouse] { _GCSystem.start(); return _connected ? [_shared].compactMap { $0 } : [] }
    open var mouseInput: GCMouseInput? { input }
    open var handlerQueue: DispatchQueue = .main
    open var vendorName: String? { "isim host mouse" }
    open var productCategory: String { GCProductCategoryMouse }
    open var physicalInputProfile: GCPhysicalInputProfile { input }

    /// polled with the pads: moves, buttons and scrolls since the last poll
    static func _poll() {
        var dx = 0.0, dy = 0.0, sx = 0.0, sy = 0.0
        var buttons: UInt32 = 0
        guard isim_mouse_poll(&dx, &dy, &sx, &sy, &buttons) != 0 else { return }
        let m = _shared ?? { let m = GCMouse(); _shared = m; return m }()
        if !_connected {
            _connected = true
            NotificationCenter.default.post(name: .GCMouseDidConnect, object: m)
            NotificationCenter.default.post(name: .GCMouseDidBecomeCurrent, object: m)
        }
        let i = m.input
        if dx != 0 || dy != 0 { i.mouseMovedHandler?(i, Float(dx), Float(-dy)) }          // y up, like iOS
        func set(_ b: GCControllerButtonInput?, _ bit: UInt32) {
            guard let b else { return }
            let v: Float = buttons & bit != 0 ? 1 : 0
            if b.value != v { b.setValue(v) }
        }
        set(i.leftButton, 1); set(i.rightButton, 2); set(i.middleButton, 4)
        set(i.auxiliaryButtons?.first, 8); set(i.auxiliaryButtons?.last, 16)
        if sx != 0 || sy != 0 { i.scroll.setValueForXAxis(Float(sx), yAxis: Float(sy)); i.scroll.setValueForXAxis(0, yAxis: 0) }
    }
}
extension NSNotification.Name {
    public static let GCMouseDidBecomeCurrent = NSNotification.Name("GCMouseDidBecomeCurrentNotification")
    public static let GCMouseDidStopBeingCurrent = NSNotification.Name("GCMouseDidStopBeingCurrentNotification")
}
public let GCMouseDidConnectNotification = "GCMouseDidConnectNotification"
public let GCMouseDidDisconnectNotification = "GCMouseDidDisconnectNotification"
public let GCMouseDidBecomeCurrentNotification = "GCMouseDidBecomeCurrentNotification"
public let GCMouseDidStopBeingCurrentNotification = "GCMouseDidStopBeingCurrentNotification"
