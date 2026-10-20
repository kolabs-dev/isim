// isim GameController: the product profiles of host pads (from SDL3's pad type: Xbox, DualShock 4, DualSense) with
// their extra inputs — touchpads, paddles, the share button — and the DualSense's adaptive triggers. Self-authored,
// iOS API names. Passthrough: the inputs are SDL's; trigger modes go to the pad as DualSense effect reports.
import Foundation
import isim_host

public let GCInputButtonShare = "Button Share"
public let GCInputXboxPaddleOne = "Paddle 1"
public let GCInputXboxPaddleTwo = "Paddle 2"
public let GCInputXboxPaddleThree = "Paddle 3"
public let GCInputXboxPaddleFour = "Paddle 4"
public let GCInputDualShockTouchpadOne = "Touchpad 1"
public let GCInputDualShockTouchpadTwo = "Touchpad 2"
public let GCInputDualShockTouchpadButton = "Touchpad Button"

// MARK: - touchpads

public typealias GCControllerTouchpadHandler = (GCControllerTouchpad, Float, Float, Float, Bool) -> Void

/// A touch surface with a button (DualShock 4 / DualSense): one finger's position, -1...1 (y up).
open class GCControllerTouchpad: GCControllerElement {
    @objc public enum TouchState: Int, Sendable { case up = 0, down = 1, moving = 2 }
    public let button = GCControllerButtonInput(name: "Button")
    public let touchSurface = GCControllerDirectionPad(name: "Touch Surface", analog: true)
    open var touchDown: GCControllerTouchpadHandler?
    open var touchMoved: GCControllerTouchpadHandler?
    open var touchUp: GCControllerTouchpadHandler?
    open internal(set) var touchState: TouchState = .up
    /// isim reports absolute positions (iOS's default for these pads)
    open var reportsAbsoluteTouchSurfaceValues = true
    override init(name: String?, analog: Bool = false) {
        super.init(name: name, analog: true)
        button.collection = self; touchSurface.collection = self
    }
    open func setValueForXAxis(_ xAxis: Float, yAxis: Float, touchDown: Bool, buttonValue: Float) {
        let was = touchState
        touchSurface.setValueForXAxis(touchDown ? xAxis : 0, yAxis: touchDown ? yAxis : 0)
        if button.value != buttonValue { button.setValue(buttonValue) }
        let pressed = buttonValue > 0.5
        switch (was, touchDown) {
        case (.up, true): touchState = .down; self.touchDown?(self, xAxis, yAxis, buttonValue, pressed)
        case (_, true): touchState = .moving; touchMoved?(self, xAxis, yAxis, buttonValue, pressed)
        case (.down, false), (.moving, false): touchState = .up; touchUp?(self, xAxis, yAxis, buttonValue, pressed)
        default: break
        }
        changed()
    }
}

extension GCPhysicalInputProfile {
    /// the profile's touchpads (DualShock 4, DualSense), by name
    public var touchpads: [String: GCControllerTouchpad] { (self as? _GCTouchpadProfile)?._touchpads ?? [:] }
    public var allTouchpads: Set<GCControllerTouchpad> { Set(touchpads.values) }
}
protocol _GCTouchpadProfile { var _touchpads: [String: GCControllerTouchpad] { get } }

// MARK: - Xbox

open class GCXboxGamepad: GCExtendedGamepad {
    /// Elite paddles (nil on pads without them)
    open internal(set) var paddleButton1: GCControllerButtonInput?
    open internal(set) var paddleButton2: GCControllerButtonInput?
    open internal(set) var paddleButton3: GCControllerButtonInput?
    open internal(set) var paddleButton4: GCControllerButtonInput?
    /// the Series X|S share button
    open internal(set) var buttonShare: GCControllerButtonInput?
    public override init() { super.init() }
    /// isim: the inputs this pad has (SDL's button bits)
    func _configure(hasButtons has: UInt32) {
        func make(_ bit: UInt32, _ name: String) -> GCControllerButtonInput? {
            guard has & (1 << bit) != 0 else { return nil }
            let b = GCControllerButtonInput(name: name); register(b, name); return b
        }
        buttonShare = make(15, GCInputButtonShare)
        paddleButton1 = make(16, GCInputXboxPaddleOne)        // SDL: right paddle 1 is P1, right paddle 2 P2,
        paddleButton2 = make(18, GCInputXboxPaddleTwo)        // left paddle 1 P3, left paddle 2 P4
        paddleButton3 = make(17, GCInputXboxPaddleThree)
        paddleButton4 = make(19, GCInputXboxPaddleFour)
    }
    override func _hostUpdate(_ p: isim_gamepad, bit: (Int) -> Float) {
        buttonShare?.setValue(bit(15))
        paddleButton1?.setValue(bit(16)); paddleButton2?.setValue(bit(18)); paddleButton3?.setValue(bit(17)); paddleButton4?.setValue(bit(19))
    }
}

// MARK: - DualShock 4 / DualSense

open class GCDualShockGamepad: GCExtendedGamepad, _GCTouchpadProfile {
    let _tb = GCControllerButtonInput(name: GCInputDualShockTouchpadButton)
    let _tp = GCControllerDirectionPad(name: GCInputDualShockTouchpadOne, analog: true)
    let _ts = GCControllerDirectionPad(name: GCInputDualShockTouchpadTwo, analog: true)
    open var touchpadButton: GCControllerButtonInput! { _tb }
    /// the first and second finger on the touchpad, -1...1 (y up)
    open var touchpadPrimary: GCControllerDirectionPad! { _tp }
    open var touchpadSecondary: GCControllerDirectionPad! { _ts }
    let _touchpad = GCControllerTouchpad(name: "Touchpad")
    var _touchpads: [String: GCControllerTouchpad] { [GCInputDualShockTouchpadOne: _touchpad] }
    public override init() { super.init(); _registerTouchpad() }
    func _registerTouchpad() {
        register(_tb, GCInputDualShockTouchpadButton)
        register(_tp, GCInputDualShockTouchpadOne); register(_ts, GCInputDualShockTouchpadTwo)
        _touchpad.profile = self
    }
    override func _hostUpdate(_ p: isim_gamepad, bit: (Int) -> Float) { _GCTouch.update(p, bit(20), _tb, _tp, _ts, _touchpad) }
}

open class GCDualSenseGamepad: GCExtendedGamepad, _GCTouchpadProfile {
    public let touchpadButton = GCControllerButtonInput(name: GCInputDualShockTouchpadButton)
    public let touchpadPrimary = GCControllerDirectionPad(name: GCInputDualShockTouchpadOne, analog: true)
    public let touchpadSecondary = GCControllerDirectionPad(name: GCInputDualShockTouchpadTwo, analog: true)
    let _touchpad = GCControllerTouchpad(name: "Touchpad")
    var _touchpads: [String: GCControllerTouchpad] { [GCInputDualShockTouchpadOne: _touchpad] }
    open override var leftTrigger: GCDualSenseAdaptiveTrigger { _leftTrigger as! GCDualSenseAdaptiveTrigger }
    open override var rightTrigger: GCDualSenseAdaptiveTrigger { _rightTrigger as! GCDualSenseAdaptiveTrigger }
    public override init() {
        super.init(_leftTrigger: GCDualSenseAdaptiveTrigger(name: GCInputLeftTrigger, left: true),
                   rightTrigger: GCDualSenseAdaptiveTrigger(name: GCInputRightTrigger, left: false))
        register(touchpadButton, GCInputDualShockTouchpadButton)
        register(touchpadPrimary, GCInputDualShockTouchpadOne); register(touchpadSecondary, GCInputDualShockTouchpadTwo)
        _touchpad.profile = self
        leftTrigger._owner = self; rightTrigger._owner = self
    }
    override func _hostUpdate(_ p: isim_gamepad, bit: (Int) -> Float) { _GCTouch.update(p, bit(20), touchpadButton, touchpadPrimary, touchpadSecondary, _touchpad) }
    /// both triggers' modes as one DualSense effect report (SDL's DS5 effects layout)
    func _sendTriggerEffects() {
        guard let pad = controller?._hostPadID else { return }
        var report = [UInt8](repeating: 0, count: 47)
        report[0] = 0x04 | 0x08                                // enable the right and left trigger effects
        let r = rightTrigger._effect, l = leftTrigger._effect
        for i in 0..<min(11, r.count) { report[10 + i] = r[i] }
        for i in 0..<min(11, l.count) { report[21 + i] = l[i] }
        _ = report.withUnsafeBytes { isim_gamepad_effect(pad, $0.baseAddress, Int32($0.count)) }
    }
}

enum _GCTouch {
    static func update(_ p: isim_gamepad, _ button: Float, _ tb: GCControllerButtonInput, _ primary: GCControllerDirectionPad,
                       _ secondary: GCControllerDirectionPad, _ pad: GCControllerTouchpad) {
        tb.setValue(button)
        let f = [p.touch.0, p.touch.1]
        func xy(_ t: (Float, Float, Float)) -> (Float, Float) { t.0 != 0 ? (t.1 * 2 - 1, 1 - t.2 * 2) : (0, 0) }
        let (x0, y0) = xy(f[0]), (x1, y1) = xy(f[1])
        if x0 != primary.xAxis.value || y0 != primary.yAxis.value { primary.setValueForXAxis(x0, yAxis: y0) }
        if x1 != secondary.xAxis.value || y1 != secondary.yAxis.value { secondary.setValueForXAxis(x1, yAxis: y1) }
        let down = f[0].0 != 0
        if down || pad.touchState != .up || button != pad.button.value {
            if !(down && pad.touchState != .up && x0 == pad.touchSurface.xAxis.value && y0 == pad.touchSurface.yAxis.value && button == pad.button.value) {
                pad.setValueForXAxis(x0, yAxis: y0, touchDown: down, buttonValue: button)
            }
        }
    }
}

/// A DualSense trigger with resistance and vibration modes (sent to the pad as effect reports).
open class GCDualSenseAdaptiveTrigger: GCControllerButtonInput {
    @objc public enum Mode: Int, Sendable { case off = 0, feedback = 1, weapon = 2, vibration = 3, slopeFeedback = 4 }
    @objc public enum Status: Int, Sendable {
        case unknown = -1, feedbackNoLoad = 0, feedbackLoadApplied = 1, weaponReady = 2, weaponFiring = 3, weaponFired = 4
        case vibrationNotVibrating = 5, vibrationIsVibrating = 6, slopeFeedbackReady = 7, slopeFeedbackApplyingLoad = 8, slopeFeedbackFinished = 9
    }
    /// ten zones along the trigger's travel
    public struct PositionalAmplitudes: Sendable {
        public var values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)
        public init() { values = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0) }
        public init(values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)) { self.values = values }
    }
    public struct PositionalResistiveStrengths: Sendable {
        public var values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)
        public init() { values = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0) }
        public init(values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)) { self.values = values }
    }
    /// the number of zones of the positional modes
    open class var discretePositionCount: Int { 10 }
    weak var _owner: GCDualSenseGamepad?
    let _left: Bool
    var _effect: [UInt8] = [0x05]
    init(name: String, left: Bool) { _left = left; super.init(name: name, analog: true) }
    open internal(set) var mode: Mode = .off
    /// isim cannot read the trigger's state back from the pad (SDL does not report it)
    open var status: Status { .unknown }
    /// the trigger's travel (isim: its value)
    open var armPosition: Float { value }
    func _set(_ m: Mode, _ bytes: [UInt8]) { mode = m; _effect = bytes; _owner?._sendTriggerEffects() }
    static func u8(_ v: Float) -> UInt8 { UInt8(max(0, min(1, v)) * 255) }
    open func setModeOff() { _set(.off, [0x05]) }
    open func setModeFeedbackWithStartPosition(_ startPosition: Float, resistiveStrength: Float) {
        _set(.feedback, [0x01, Self.u8(startPosition), Self.u8(resistiveStrength)])
    }
    open func setModeWeaponWithStartPosition(_ startPosition: Float, endPosition: Float, resistiveStrength: Float) {
        _set(.weapon, [0x02, Self.u8(startPosition), Self.u8(endPosition), Self.u8(resistiveStrength)])
    }
    open func setModeVibrationWithStartPosition(_ startPosition: Float, amplitude: Float, frequency: Float) {
        _set(.vibration, [0x06, Self.u8(frequency), Self.u8(amplitude), Self.u8(startPosition)])
    }
    /// positional modes: the strongest position's resistance from the first zone that has one (adapted: one zone)
    open func setModeFeedback(resistiveStrengths: PositionalResistiveStrengths) {
        let v = Mirror(reflecting: resistiveStrengths.values).children.compactMap { $0.value as? Float }
        let start = v.firstIndex { $0 > 0 } ?? 0
        _set(.feedback, [0x01, Self.u8(Float(start) / 9), Self.u8(v.max() ?? 0)])
    }
    open func setModeVibration(amplitudes: PositionalAmplitudes, frequency: Float) {
        let v = Mirror(reflecting: amplitudes.values).children.compactMap { $0.value as? Float }
        let start = v.firstIndex { $0 > 0 } ?? 0
        _set(.vibration, [0x06, Self.u8(frequency), Self.u8(v.max() ?? 0), Self.u8(Float(start) / 9)])
    }
    open func setModeSlopeFeedback(startPosition: Float, endPosition: Float, startStrength: Float, endStrength: Float) {
        _set(.slopeFeedback, [0x01, Self.u8(startPosition), Self.u8(max(startStrength, endStrength))])
    }
}

// MARK: - directional gamepads

/// A micro gamepad with a d-pad (Siri Remote style); isim's host pads are extended gamepads, so none appear.
open class GCDirectionalGamepad: GCMicroGamepad {
    public override init() { super.init() }
}
