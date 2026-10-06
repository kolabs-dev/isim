// isim GameController, self-authored: GCController with the extended / micro gamepad profiles, GCKeyboard driven by
// the host keyboard (key presses and releases reach the app as USB HID usages), and GCVirtualController drawn over
// the app's window. Physical game controllers on the host are not forwarded (isim has no gamepad events yet).
@_exported import Foundation
@_exported import UIKit
import isim_host

// MARK: - Notifications

extension NSNotification.Name {
    public static let GCControllerDidConnect: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCControllerDidConnectNotification") }()
    public static let GCControllerDidDisconnect: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCControllerDidDisconnectNotification") }()
    public static let GCControllerDidBecomeCurrent: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCControllerDidBecomeCurrentNotification") }()
    public static let GCControllerDidStopBeingCurrent: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCControllerDidStopBeingCurrentNotification") }()
    public static let GCKeyboardDidConnect: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCKeyboardDidConnectNotification") }()
    public static let GCKeyboardDidDisconnect: NSNotification.Name = { _GCSystem.start(); return NSNotification.Name("GCKeyboardDidDisconnectNotification") }()
    public static let GCMouseDidConnect = NSNotification.Name("GCMouseDidConnectNotification")
    public static let GCMouseDidDisconnect = NSNotification.Name("GCMouseDidDisconnectNotification")
}
public let GCControllerDidConnectNotification = "GCControllerDidConnectNotification"
public let GCControllerDidDisconnectNotification = "GCControllerDidDisconnectNotification"
public let GCKeyboardDidConnectNotification = "GCKeyboardDidConnectNotification"
public let GCKeyboardDidDisconnectNotification = "GCKeyboardDidDisconnectNotification"

// input element names (GCInputNames)
public let GCInputButtonA = "Button A"
public let GCInputButtonB = "Button B"
public let GCInputButtonX = "Button X"
public let GCInputButtonY = "Button Y"
public let GCInputDirectionPad = "Direction Pad"
public let GCInputLeftThumbstick = "Left Thumbstick"
public let GCInputRightThumbstick = "Right Thumbstick"
public let GCInputLeftShoulder = "Left Shoulder"
public let GCInputRightShoulder = "Right Shoulder"
public let GCInputLeftTrigger = "Left Trigger"
public let GCInputRightTrigger = "Right Trigger"
public let GCInputLeftThumbstickButton = "Left Thumbstick Button"
public let GCInputRightThumbstickButton = "Right Thumbstick Button"
public let GCInputButtonHome = "Button Home"
public let GCInputButtonMenu = "Button Menu"
public let GCInputButtonOptions = "Button Options"
public let GCProductCategoryKeyboard = "Keyboard"
public let GCProductCategoryMouse = "Mouse"

/// Connects the host keyboard once anything in GameController is used.
@MainActor enum _GCSystem {
    nonisolated(unsafe) static var started = false
    nonisolated static func start() {
        guard !started else { return }
        started = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let kb = GCKeyboard.shared
                NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimHardwareKey"), object: nil, queue: nil) { n in
                    guard let u = n.userInfo?["usage"] as? Int, let down = n.userInfo?["down"] as? Bool else { return }
                    MainActor.assumeIsolated { kb.input.key(GCKeyCode(rawValue: u), down: down) }
                }
                NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                    MainActor.assumeIsolated { kb.input.releaseAll() }
                }
                NotificationCenter.default.post(name: NSNotification.Name(GCKeyboardDidConnectNotification), object: kb)
            }
        }
    }
}

// MARK: - Elements

open class GCControllerElement: NSObject {
    open internal(set) weak var collection: GCControllerElement?
    open internal(set) var isAnalog = false
    open var localizedName: String?
    open var unmappedLocalizedName: String?
    open var sfSymbolsName: String?
    open var unmappedSfSymbolsName: String?
    open internal(set) var aliases: Set<String> = []
    open var isBoundToSystemGesture = false
    open var preferredSystemGestureState: Int = 0
    weak var profile: GCPhysicalInputProfile?
    init(name: String?, analog: Bool = false) { localizedName = name; isAnalog = analog; if let name { aliases = [name] } }
    func changed() { profile?.elementChanged(self) }
}

public typealias GCControllerButtonValueChangedHandler = (GCControllerButtonInput, Float, Bool) -> Void
public typealias GCControllerButtonTouchedChangedHandler = (GCControllerButtonInput, Float, Bool, Bool) -> Void
public typealias GCControllerAxisValueChangedHandler = (GCControllerAxisInput, Float) -> Void
public typealias GCControllerDirectionPadValueChangedHandler = (GCControllerDirectionPad, Float, Float) -> Void

open class GCControllerButtonInput: GCControllerElement {
    open var valueChangedHandler: GCControllerButtonValueChangedHandler?
    open var pressedChangedHandler: GCControllerButtonValueChangedHandler?
    open var touchedChangedHandler: GCControllerButtonTouchedChangedHandler?
    open private(set) var value: Float = 0
    open private(set) var isPressed = false
    open private(set) var isTouched = false
    /// sets the value (0...1); pressed above 0.5 for analog buttons, above 0 otherwise
    open func setValue(_ v: Float) {
        let nv = max(0, min(1, v))
        let pressed = isAnalog ? nv > 0.5 : nv > 0
        guard nv != value || pressed != isPressed else { return }
        value = nv
        let pressChanged = pressed != isPressed
        isPressed = pressed; isTouched = pressed
        valueChangedHandler?(self, value, isPressed)
        if pressChanged { pressedChangedHandler?(self, value, isPressed); touchedChangedHandler?(self, value, isPressed, isTouched) }
        (collection as? GCControllerDirectionPad)?.childChanged()
        changed()
    }
}

open class GCControllerAxisInput: GCControllerElement {
    open var valueChangedHandler: GCControllerAxisValueChangedHandler?
    open private(set) var value: Float = 0
    open func setValue(_ v: Float) {
        let nv = max(-1, min(1, v))
        guard nv != value else { return }
        value = nv
        valueChangedHandler?(self, value)
        changed()
    }
}

open class GCControllerDirectionPad: GCControllerElement {
    open var valueChangedHandler: GCControllerDirectionPadValueChangedHandler?
    public let xAxis = GCControllerAxisInput(name: nil, analog: true)
    public let yAxis = GCControllerAxisInput(name: nil, analog: true)
    public let up = GCControllerButtonInput(name: "Up")
    public let down = GCControllerButtonInput(name: "Down")
    public let left = GCControllerButtonInput(name: "Left")
    public let right = GCControllerButtonInput(name: "Right")
    var settingBoth = false
    override init(name: String?, analog: Bool = false) {
        super.init(name: name, analog: analog)
        for e in [xAxis, yAxis, up, down, left, right] as [GCControllerElement] { e.collection = self }
        for b in [up, down, left, right] { b.isAnalog = analog }
    }
    /// sets both axes (-1...1) and the four direction buttons
    open func setValueForXAxis(_ x: Float, yAxis y: Float) {
        settingBoth = true
        xAxis.setValue(x); yAxis.setValue(y)
        right.setValue(max(0, x)); left.setValue(max(0, -x)); up.setValue(max(0, y)); down.setValue(max(0, -y))
        settingBoth = false
        valueChangedHandler?(self, xAxis.value, yAxis.value)
        changed()
    }
    func childChanged() {
        guard !settingBoth else { return }
        // a direction button set alone (keyboard, d-pad buttons): derive the axes
        settingBoth = true
        xAxis.setValue(right.value - left.value); yAxis.setValue(up.value - down.value)
        settingBoth = false
        valueChangedHandler?(self, xAxis.value, yAxis.value)
    }
}

// MARK: - Profiles

open class GCPhysicalInputProfile: NSObject {
    open internal(set) weak var device: GCDevice?
    open internal(set) var lastEventTimestamp: TimeInterval = 0
    open var hasRemappedElements = false
    open var valueDidChangeHandler: ((GCPhysicalInputProfile, GCControllerElement) -> Void)?
    open internal(set) var elements: [String: GCControllerElement] = [:]
    open var buttons: [String: GCControllerButtonInput] { elements.compactMapValues { $0 as? GCControllerButtonInput } }
    open var axes: [String: GCControllerAxisInput] { elements.compactMapValues { $0 as? GCControllerAxisInput } }
    open var dpads: [String: GCControllerDirectionPad] { elements.compactMapValues { $0 as? GCControllerDirectionPad } }
    open var allElements: Set<GCControllerElement> { Set(elements.values) }
    open var allButtons: Set<GCControllerButtonInput> { Set(buttons.values) }
    open var allAxes: Set<GCControllerAxisInput> { Set(axes.values) }
    open var allDpads: Set<GCControllerDirectionPad> { Set(dpads.values) }
    open subscript(key: String) -> GCControllerElement? { elements[key] }
    open func capture() -> Self { self }
    open func mappedElementAlias(forPhysicalInputName name: String) -> String { name }
    open func mappedPhysicalInputNames(forElementAlias alias: String) -> Set<String> { [alias] }

    func register(_ e: GCControllerElement, _ name: String) {
        elements[name] = e
        e.profile = self
        if let d = e as? GCControllerDirectionPad { for c in [d.xAxis, d.yAxis, d.up, d.down, d.left, d.right] as [GCControllerElement] { c.profile = self } }
    }
    func elementChanged(_ e: GCControllerElement) {
        lastEventTimestamp = ProcessInfo.processInfo.systemUptime
        valueDidChangeHandler?(self, e)
        profileChanged(e)
    }
    func profileChanged(_ e: GCControllerElement) {}
}

public typealias GCExtendedGamepadValueChangedHandler = (GCExtendedGamepad, GCControllerElement) -> Void
public typealias GCMicroGamepadValueChangedHandler = (GCMicroGamepad, GCControllerElement) -> Void

open class GCExtendedGamepad: GCPhysicalInputProfile {
    open internal(set) weak var controller: GCController?
    open var valueChangedHandler: GCExtendedGamepadValueChangedHandler?
    public let dpad = GCControllerDirectionPad(name: GCInputDirectionPad)
    public let buttonA = GCControllerButtonInput(name: GCInputButtonA)
    public let buttonB = GCControllerButtonInput(name: GCInputButtonB)
    public let buttonX = GCControllerButtonInput(name: GCInputButtonX)
    public let buttonY = GCControllerButtonInput(name: GCInputButtonY)
    public let leftShoulder = GCControllerButtonInput(name: GCInputLeftShoulder)
    public let rightShoulder = GCControllerButtonInput(name: GCInputRightShoulder)
    public let leftTrigger = GCControllerButtonInput(name: GCInputLeftTrigger, analog: true)
    public let rightTrigger = GCControllerButtonInput(name: GCInputRightTrigger, analog: true)
    public let leftThumbstick = GCControllerDirectionPad(name: GCInputLeftThumbstick, analog: true)
    public let rightThumbstick = GCControllerDirectionPad(name: GCInputRightThumbstick, analog: true)
    public let buttonMenu = GCControllerButtonInput(name: GCInputButtonMenu)
    public let buttonOptions: GCControllerButtonInput? = GCControllerButtonInput(name: GCInputButtonOptions)
    public let buttonHome: GCControllerButtonInput? = GCControllerButtonInput(name: GCInputButtonHome)
    public let leftThumbstickButton: GCControllerButtonInput? = GCControllerButtonInput(name: GCInputLeftThumbstickButton)
    public let rightThumbstickButton: GCControllerButtonInput? = GCControllerButtonInput(name: GCInputRightThumbstickButton)

    public override init() {
        super.init()
        let all: [(GCControllerElement, String)] = [(dpad, GCInputDirectionPad), (buttonA, GCInputButtonA), (buttonB, GCInputButtonB), (buttonX, GCInputButtonX),
            (buttonY, GCInputButtonY), (leftShoulder, GCInputLeftShoulder), (rightShoulder, GCInputRightShoulder), (leftTrigger, GCInputLeftTrigger),
            (rightTrigger, GCInputRightTrigger), (leftThumbstick, GCInputLeftThumbstick), (rightThumbstick, GCInputRightThumbstick),
            (buttonMenu, GCInputButtonMenu), (buttonOptions!, GCInputButtonOptions), (buttonHome!, GCInputButtonHome),
            (leftThumbstickButton!, GCInputLeftThumbstickButton), (rightThumbstickButton!, GCInputRightThumbstickButton)]
        for (e, n) in all { register(e, n) }
    }
    override func profileChanged(_ e: GCControllerElement) {
        var top = e
        while let c = top.collection { top = c }
        valueChangedHandler?(self, top)
    }
    open func saveSnapshot() -> GCExtendedGamepad { self }
    open func setStateFromExtendedGamepad(_ other: GCExtendedGamepad) {
        dpad.setValueForXAxis(other.dpad.xAxis.value, yAxis: other.dpad.yAxis.value)
        leftThumbstick.setValueForXAxis(other.leftThumbstick.xAxis.value, yAxis: other.leftThumbstick.yAxis.value)
        rightThumbstick.setValueForXAxis(other.rightThumbstick.xAxis.value, yAxis: other.rightThumbstick.yAxis.value)
        for (a, b) in [(buttonA, other.buttonA), (buttonB, other.buttonB), (buttonX, other.buttonX), (buttonY, other.buttonY),
                       (leftShoulder, other.leftShoulder), (rightShoulder, other.rightShoulder), (leftTrigger, other.leftTrigger),
                       (rightTrigger, other.rightTrigger), (buttonMenu, other.buttonMenu)] { a.setValue(b.value) }
    }
}

open class GCMicroGamepad: GCPhysicalInputProfile {
    open internal(set) weak var controller: GCController?
    open var valueChangedHandler: GCMicroGamepadValueChangedHandler?
    public let dpad = GCControllerDirectionPad(name: GCInputDirectionPad, analog: true)
    public let buttonA = GCControllerButtonInput(name: GCInputButtonA)
    public let buttonX = GCControllerButtonInput(name: GCInputButtonX)
    public let buttonMenu = GCControllerButtonInput(name: GCInputButtonMenu)
    open var reportsAbsoluteDpadValues = false
    open var allowsRotation = false
    public override init() {
        super.init()
        register(dpad, GCInputDirectionPad); register(buttonA, GCInputButtonA); register(buttonX, GCInputButtonX); register(buttonMenu, GCInputButtonMenu)
    }
    override func profileChanged(_ e: GCControllerElement) {
        var top = e
        while let c = top.collection { top = c }
        valueChangedHandler?(self, top)
    }
}

// MARK: - Devices

public protocol GCDevice: NSObjectProtocol {
    var handlerQueue: DispatchQueue { get set }
    var vendorName: String? { get }
    var productCategory: String { get }
    var physicalInputProfile: GCPhysicalInputProfile { get }
}

public enum GCControllerPlayerIndex: Int, Sendable { case indexUnset = -1, index1 = 0, index2 = 1, index3 = 2, index4 = 3 }

open class GCController: NSObject, GCDevice {
    nonisolated(unsafe) static var connected: [GCController] = []
    nonisolated(unsafe) static var _current: GCController?
    open class func controllers() -> [GCController] { _GCSystem.start(); return connected }
    open class var current: GCController? { _current }
    nonisolated(unsafe) open class var shouldMonitorBackgroundEvents: Bool { get { false } set {} }
    /// no wireless controllers can be discovered on isim; completes immediately
    open class func startWirelessControllerDiscovery(completionHandler: (() -> Void)? = nil) {
        _GCSystem.start()
        DispatchQueue.main.async { completionHandler?() }
    }
    open class func stopWirelessControllerDiscovery() {}
    open class func withExtendedGamepad() -> GCController { let c = GCController(extended: true); c.isSnapshot = true; return c }
    open class func withMicroGamepad() -> GCController { let c = GCController(extended: false); c.isSnapshot = true; return c }

    open var handlerQueue: DispatchQueue = .main
    open var controllerPausedHandler: ((GCController) -> Void)?
    open internal(set) var vendorName: String?
    open internal(set) var productCategory: String = "Generic"
    open internal(set) var isAttachedToDevice = false
    open internal(set) var isSnapshot = false
    open var playerIndex: GCControllerPlayerIndex = .indexUnset
    open internal(set) var extendedGamepad: GCExtendedGamepad?
    open internal(set) var microGamepad: GCMicroGamepad?
    open var physicalInputProfile: GCPhysicalInputProfile { extendedGamepad ?? microGamepad ?? GCPhysicalInputProfile() }
    open var battery: AnyObject? { nil }
    open var light: AnyObject? { nil }
    open var haptics: AnyObject? { nil }
    open var motion: AnyObject? { nil }

    init(extended: Bool) {
        super.init()
        if extended { let g = GCExtendedGamepad(); g.controller = self; g.device = self; extendedGamepad = g }
        let m = GCMicroGamepad(); m.controller = self; m.device = self; microGamepad = m
    }
    open func capture() -> GCController { self }

    static func connect(_ c: GCController) {
        guard !connected.contains(where: { $0 === c }) else { return }
        connected.append(c)
        if c.playerIndex == .indexUnset { c.playerIndex = GCControllerPlayerIndex(rawValue: connected.count - 1) ?? .indexUnset }
        NotificationCenter.default.post(name: NSNotification.Name(GCControllerDidConnectNotification), object: c)
        if _current == nil { _current = c; NotificationCenter.default.post(name: NSNotification.Name("GCControllerDidBecomeCurrentNotification"), object: c) }
    }
    static func disconnect(_ c: GCController) {
        guard connected.contains(where: { $0 === c }) else { return }
        connected.removeAll { $0 === c }
        if _current === c {
            NotificationCenter.default.post(name: NSNotification.Name("GCControllerDidStopBeingCurrentNotification"), object: c)
            _current = connected.first
        }
        NotificationCenter.default.post(name: NSNotification.Name(GCControllerDidDisconnectNotification), object: c)
    }
}

// MARK: - Keyboard

public struct GCKeyCode: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ rawValue: Int) { self.rawValue = rawValue }
    public static let keyA = GCKeyCode(4), keyB = GCKeyCode(5), keyC = GCKeyCode(6), keyD = GCKeyCode(7), keyE = GCKeyCode(8)
    public static let keyF = GCKeyCode(9), keyG = GCKeyCode(10), keyH = GCKeyCode(11), keyI = GCKeyCode(12), keyJ = GCKeyCode(13)
    public static let keyK = GCKeyCode(14), keyL = GCKeyCode(15), keyM = GCKeyCode(16), keyN = GCKeyCode(17), keyO = GCKeyCode(18)
    public static let keyP = GCKeyCode(19), keyQ = GCKeyCode(20), keyR = GCKeyCode(21), keyS = GCKeyCode(22), keyT = GCKeyCode(23)
    public static let keyU = GCKeyCode(24), keyV = GCKeyCode(25), keyW = GCKeyCode(26), keyX = GCKeyCode(27), keyY = GCKeyCode(28), keyZ = GCKeyCode(29)
    public static let one = GCKeyCode(30), two = GCKeyCode(31), three = GCKeyCode(32), four = GCKeyCode(33), five = GCKeyCode(34)
    public static let six = GCKeyCode(35), seven = GCKeyCode(36), eight = GCKeyCode(37), nine = GCKeyCode(38), zero = GCKeyCode(39)
    public static let returnOrEnter = GCKeyCode(40), escape = GCKeyCode(41), deleteOrBackspace = GCKeyCode(42), tab = GCKeyCode(43), spacebar = GCKeyCode(44)
    public static let hyphen = GCKeyCode(45), equalSign = GCKeyCode(46), openBracket = GCKeyCode(47), closeBracket = GCKeyCode(48), backslash = GCKeyCode(49)
    public static let nonUSPound = GCKeyCode(50), semicolon = GCKeyCode(51), quote = GCKeyCode(52), graveAccentAndTilde = GCKeyCode(53)
    public static let comma = GCKeyCode(54), period = GCKeyCode(55), slash = GCKeyCode(56), capsLock = GCKeyCode(57)
    public static let F1 = GCKeyCode(58), F2 = GCKeyCode(59), F3 = GCKeyCode(60), F4 = GCKeyCode(61), F5 = GCKeyCode(62), F6 = GCKeyCode(63)
    public static let F7 = GCKeyCode(64), F8 = GCKeyCode(65), F9 = GCKeyCode(66), F10 = GCKeyCode(67), F11 = GCKeyCode(68), F12 = GCKeyCode(69)
    public static let printScreen = GCKeyCode(70), scrollLock = GCKeyCode(71), pause = GCKeyCode(72), insert = GCKeyCode(73), home = GCKeyCode(74)
    public static let pageUp = GCKeyCode(75), deleteForward = GCKeyCode(76), end = GCKeyCode(77), pageDown = GCKeyCode(78)
    public static let rightArrow = GCKeyCode(79), leftArrow = GCKeyCode(80), downArrow = GCKeyCode(81), upArrow = GCKeyCode(82)
    public static let keypadNumLock = GCKeyCode(83), keypadSlash = GCKeyCode(84), keypadAsterisk = GCKeyCode(85), keypadHyphen = GCKeyCode(86)
    public static let keypadPlus = GCKeyCode(87), keypadEnter = GCKeyCode(88), keypad1 = GCKeyCode(89), keypad2 = GCKeyCode(90), keypad3 = GCKeyCode(91)
    public static let keypad4 = GCKeyCode(92), keypad5 = GCKeyCode(93), keypad6 = GCKeyCode(94), keypad7 = GCKeyCode(95), keypad8 = GCKeyCode(96)
    public static let keypad9 = GCKeyCode(97), keypad0 = GCKeyCode(98), keypadPeriod = GCKeyCode(99), keypadEqualSign = GCKeyCode(103)
    public static let application = GCKeyCode(101), power = GCKeyCode(102)
    public static let leftControl = GCKeyCode(224), leftShift = GCKeyCode(225), leftAlt = GCKeyCode(226), leftGUI = GCKeyCode(227)
    public static let rightControl = GCKeyCode(228), rightShift = GCKeyCode(229), rightAlt = GCKeyCode(230), rightGUI = GCKeyCode(231)
}

public typealias GCKeyboardValueChangedHandler = (GCKeyboardInput, GCControllerButtonInput, GCKeyCode, Bool) -> Void

open class GCKeyboardInput: GCPhysicalInputProfile {
    open var keyChangedHandler: GCKeyboardValueChangedHandler?
    var keys: [Int: GCControllerButtonInput] = [:]
    open var isAnyKeyPressed: Bool { keys.values.contains { $0.isPressed } }
    open func button(forKeyCode code: GCKeyCode) -> GCControllerButtonInput? {
        guard code.rawValue > 0, code.rawValue < 256 else { return nil }
        if let b = keys[code.rawValue] { return b }
        let b = GCControllerButtonInput(name: "Key \(code.rawValue)")
        keys[code.rawValue] = b
        register(b, "Key \(code.rawValue)")
        return b
    }
    func key(_ code: GCKeyCode, down: Bool) {
        guard let b = button(forKeyCode: code), b.isPressed != down else { return }
        b.setValue(down ? 1 : 0)
        keyChangedHandler?(self, b, code, down)
    }
    func releaseAll() { for (k, b) in keys where b.isPressed { key(GCKeyCode(k), down: false) } }
}

open class GCKeyboard: NSObject, GCDevice {
    nonisolated(unsafe) static let shared = GCKeyboard()
    let input = GCKeyboardInput()
    /// the hardware keyboard (on isim: the host keyboard, always connected)
    open class var coalesced: GCKeyboard? { _GCSystem.start(); return shared }
    open var keyboardInput: GCKeyboardInput? { input }
    open var handlerQueue: DispatchQueue = .main
    open var vendorName: String? { "isim host keyboard" }
    open var productCategory: String { GCProductCategoryKeyboard }
    open var physicalInputProfile: GCPhysicalInputProfile { input }
    override init() { super.init(); input.device = self }
}

open class GCMouse: NSObject {
    open class var current: GCMouse? { nil }
    open class func mice() -> [GCMouse] { [] }
}

// MARK: - Virtual controller

open class GCVirtualController: NSObject {
    open class Configuration: NSObject {
        open var elements: Set<String> = []
        open var isHidden = false
        public override init() { super.init() }
    }
    open class ElementConfiguration: NSObject {
        open var isHidden = false
        open var path: UIBezierPath?
        open var actsAsTouchpad = false
        public override init() { super.init() }
    }
    public let configuration: Configuration
    open private(set) var controller: GCController?
    var overlay: _GCVirtualControllerView?
    var hidden: Set<String> = []

    public init(configuration: Configuration) { self.configuration = configuration; super.init(); _GCSystem.start() }

    /// Shows the on-screen controller and connects its GCController.
    open func connect(replyHandler: ((Error?) -> Void)? = nil) {
        if controller == nil {
            let c = GCController(extended: true)
            c.vendorName = "Virtual Controller"; c.productCategory = "Virtual Controller"
            controller = c
        }
        attach(tries: 20) { [weak self] ok in
            guard let self, let c = self.controller else { return }
            GCController.connect(c)
            replyHandler?(ok ? nil : NSError(domain: "GCVirtualControllerErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "no window to show the virtual controller in"]))
        }
    }
    open func connect() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            connect { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func disconnect() {
        overlay?.removeFromSuperview(); overlay = nil
        if let c = controller { GCController.disconnect(c) }
    }
    open func updateConfiguration(forElement element: String, configuration: (ElementConfiguration) -> ElementConfiguration) {
        let e = configuration(ElementConfiguration())
        if e.isHidden { hidden.insert(element) } else { hidden.remove(element) }
        overlay?.hiddenElements = hidden
        overlay?.setNeedsDisplay()
    }
    func attach(tries: Int, done: @escaping (Bool) -> Void) {
        let app = UIApplication.shared
        if let w = app.windows.first(where: { $0.isKeyWindow }) ?? app.windows.first {
            let v = _GCVirtualControllerView(frame: w.bounds, controller: self)
            v.hiddenElements = hidden
            v.isHidden = configuration.isHidden
            w.addSubview(v)
            overlay = v
            done(true)
        } else if tries > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.attach(tries: tries - 1, done: done) }
        } else { done(false) }
    }
}

/// The on-screen controls: thumbsticks / d-pad on the left, face buttons on the right, shoulders above them.
final class _GCVirtualControllerView: UIView {
    weak var vc: GCVirtualController?
    var hiddenElements: Set<String> = []
    var active: [ObjectIdentifier: String] = [:]
    var stickOffset: [String: CGPoint] = [:]
    var keepOnTop: Timer?

    init(frame: CGRect, controller: GCVirtualController) {
        vc = controller
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        accessibilityIdentifier = "GCVirtualController"
        keepOnTop = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let s = self.superview else { return }
                if s.subviews.last !== self { s.bringSubviewToFront(self) }
                if self.frame != s.bounds { self.frame = s.bounds }
            }
        }
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    deinit { keepOnTop?.invalidate() }

    var elements: Set<String> { (vc?.configuration.elements ?? []).subtracting(hiddenElements) }
    var gamepad: GCExtendedGamepad? { vc?.controller?.extendedGamepad }

    /// control centers and radii (points, view coordinates)
    func layout() -> [(String, CGPoint, CGFloat)] {
        let W = bounds.width, H = bounds.height
        let bottom = H - 120
        var out: [(String, CGPoint, CGFloat)] = []
        let e = elements
        let leftCenter = CGPoint(x: 92, y: bottom)
        if e.contains(GCInputLeftThumbstick) { out.append((GCInputLeftThumbstick, leftCenter, 58)) }
        else if e.contains(GCInputDirectionPad) { out.append((GCInputDirectionPad, leftCenter, 58)) }
        if e.contains(GCInputDirectionPad) && e.contains(GCInputLeftThumbstick) { out.append((GCInputDirectionPad, CGPoint(x: 92, y: bottom - 150), 44)) }
        if e.contains(GCInputRightThumbstick) { out.append((GCInputRightThumbstick, CGPoint(x: W - 92, y: bottom - 150), 44)) }
        let fc = CGPoint(x: W - 92, y: bottom)
        let face: [(String, CGPoint)] = [(GCInputButtonA, CGPoint(x: fc.x, y: fc.y + 40)), (GCInputButtonB, CGPoint(x: fc.x + 40, y: fc.y)),
                                         (GCInputButtonX, CGPoint(x: fc.x - 40, y: fc.y)), (GCInputButtonY, CGPoint(x: fc.x, y: fc.y - 40))]
        for (n, p) in face where e.contains(n) { out.append((n, p, 22)) }
        let shoulders: [(String, CGPoint)] = [(GCInputLeftShoulder, CGPoint(x: 60, y: bottom - 90)), (GCInputLeftTrigger, CGPoint(x: 120, y: bottom - 90)),
                                              (GCInputRightShoulder, CGPoint(x: W - 60, y: bottom - 90)), (GCInputRightTrigger, CGPoint(x: W - 120, y: bottom - 90))]
        for (n, p) in shoulders where e.contains(n) { out.append((n, p, 20)) }
        if e.contains(GCInputButtonMenu) { out.append((GCInputButtonMenu, CGPoint(x: W / 2 + 30, y: bottom + 50), 14)) }
        if e.contains(GCInputButtonOptions) { out.append((GCInputButtonOptions, CGPoint(x: W / 2 - 30, y: bottom + 50), 14)) }
        return out
    }
    func control(at p: CGPoint) -> String? {
        layout().first { (_, c, r) in hypot(p.x - c.x, p.y - c.y) <= r + 14 }?.0
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { !isHidden && control(at: point) != nil }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { self.point(inside: point, with: event) ? self : nil }

    func button(_ name: String) -> GCControllerButtonInput? {
        guard let g = gamepad else { return nil }
        switch name {
        case GCInputButtonA: return g.buttonA
        case GCInputButtonB: return g.buttonB
        case GCInputButtonX: return g.buttonX
        case GCInputButtonY: return g.buttonY
        case GCInputLeftShoulder: return g.leftShoulder
        case GCInputRightShoulder: return g.rightShoulder
        case GCInputLeftTrigger: return g.leftTrigger
        case GCInputRightTrigger: return g.rightTrigger
        case GCInputButtonMenu: return g.buttonMenu
        case GCInputButtonOptions: return g.buttonOptions
        default: return nil
        }
    }
    func pad(_ name: String) -> GCControllerDirectionPad? {
        switch name {
        case GCInputLeftThumbstick: return gamepad?.leftThumbstick
        case GCInputRightThumbstick: return gamepad?.rightThumbstick
        case GCInputDirectionPad: return gamepad?.dpad
        default: return nil
        }
    }
    func move(_ name: String, to p: CGPoint) {
        guard let (_, c, r) = layout().first(where: { $0.0 == name }), let pad = pad(name) else { return }
        var dx = (p.x - c.x) / r, dy = (c.y - p.y) / r
        let l = hypot(dx, dy)
        if l > 1 { dx /= l; dy /= l }
        if name == GCInputDirectionPad {   // digital: the dominant direction(s)
            dx = abs(dx) > 0.35 ? (dx > 0 ? 1 : -1) : 0
            dy = abs(dy) > 0.35 ? (dy > 0 ? 1 : -1) : 0
        }
        stickOffset[name] = CGPoint(x: dx * r, y: -dy * r)
        pad.setValueForXAxis(Float(dx), yAxis: Float(dy))
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            guard let name = control(at: p) else { continue }
            active[ObjectIdentifier(t)] = name
            if let b = button(name) { b.setValue(1) } else { move(name, to: p) }
        }
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { if let name = active[ObjectIdentifier(t)], pad(name) != nil { move(name, to: t.location(in: self)) } }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let name = active.removeValue(forKey: ObjectIdentifier(t)) else { continue }
            if let b = button(name) { b.setValue(0) }
            if let p = pad(name) { p.setValueForXAxis(0, yAxis: 0); stickOffset[name] = .zero }
        }
        setNeedsDisplay()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }

    override func draw(_ rect: CGRect) {
        let base: [Double] = [0.5, 0.5, 0.5, 0.35], knob: [Double] = [0.95, 0.95, 0.95, 0.6], pressed: [Double] = [1, 1, 1, 0.75]
        let label: [Double] = [0.1, 0.1, 0.1, 0.8]
        for (name, c, r) in layout() {
            if let b = button(name) {
                (b.isPressed ? pressed : base).withUnsafeBufferPointer { isim_gfx_fill_ellipse(c.x - r, c.y - r, 2 * r, 2 * r, $0.baseAddress) }
                let text: String
                switch name {
                case GCInputButtonA: text = "A"; case GCInputButtonB: text = "B"; case GCInputButtonX: text = "X"; case GCInputButtonY: text = "Y"
                case GCInputLeftShoulder: text = "L1"; case GCInputRightShoulder: text = "R1"; case GCInputLeftTrigger: text = "L2"
                case GCInputRightTrigger: text = "R2"; case GCInputButtonMenu: text = "≡"; default: text = "•"
                }
                label.withUnsafeBufferPointer { isim_text_draw(text, c.x - r, c.y - 9, 2 * r, 15, 0.4, 0, 1, 1, $0.baseAddress) }
            } else {
                base.withUnsafeBufferPointer { isim_gfx_fill_ellipse(c.x - r, c.y - r, 2 * r, 2 * r, $0.baseAddress) }
                let o = stickOffset[name] ?? .zero, k = r * 0.45
                if name == GCInputDirectionPad {
                    let arm: [Double] = [0.9, 0.9, 0.9, 0.45]
                    arm.withUnsafeBufferPointer {
                        isim_gfx_fill_rounded(c.x - r * 0.25, c.y - r * 0.8, r * 0.5, r * 1.6, 4, $0.baseAddress)
                        isim_gfx_fill_rounded(c.x - r * 0.8, c.y - r * 0.25, r * 1.6, r * 0.5, 4, $0.baseAddress)
                    }
                    if o != .zero { pressed.withUnsafeBufferPointer { isim_gfx_fill_ellipse(c.x + o.x * 0.6 - 8, c.y + o.y * 0.6 - 8, 16, 16, $0.baseAddress) } }
                } else {
                    knob.withUnsafeBufferPointer { isim_gfx_fill_ellipse(c.x + o.x - k, c.y + o.y - k, 2 * k, 2 * k, $0.baseAddress) }
                }
            }
        }
    }
}
