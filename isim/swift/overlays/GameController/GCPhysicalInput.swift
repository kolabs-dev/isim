// isim GameController: the iOS 17 physical input API — GCController.input (GCControllerLiveInput), element
// collections by name (GCButtonElementName, GCDirectionPadElementName, ...), the element and input protocols
// (GCButtonElement, GCDirectionPadElement, GCLinearInput, GCPressedStateInput, GCAxisInput, GCAxis2DInput, ...),
// captured input states and the input state queue — and GCEventInteraction. Self-authored, iOS API names.
// Adapted: the elements wrap the controller's GCPhysicalInputProfile elements (the same values and timing); the input
// state queue gets a snapshot after each element change; GCEventInteraction keeps its settings (isim sends no game
// controller events to UIKit, so there is nothing to route).
import UIKit

// MARK: - names

public struct GCPhysicalInputElementName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let shifter = GCPhysicalInputElementName("Shifter")
}
public struct GCButtonElementName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let a = GCButtonElementName(GCInputButtonA), b = GCButtonElementName(GCInputButtonB)
    public static let x = GCButtonElementName(GCInputButtonX), y = GCButtonElementName(GCInputButtonY)
    public static let leftShoulder = GCButtonElementName(GCInputLeftShoulder), rightShoulder = GCButtonElementName(GCInputRightShoulder)
    public static let leftBumper = GCButtonElementName("Left Bumper"), rightBumper = GCButtonElementName("Right Bumper")
    public static let leftTrigger = GCButtonElementName(GCInputLeftTrigger), rightTrigger = GCButtonElementName(GCInputRightTrigger)
    public static let trigger = GCButtonElementName("Trigger"), thumbstickButton = GCButtonElementName("Thumbstick Button")
    public static let leftThumbstickButton = GCButtonElementName(GCInputLeftThumbstickButton)
    public static let rightThumbstickButton = GCButtonElementName(GCInputRightThumbstickButton)
    public static let menu = GCButtonElementName(GCInputButtonMenu), options = GCButtonElementName(GCInputButtonOptions)
    public static let home = GCButtonElementName(GCInputButtonHome), share = GCButtonElementName(GCInputButtonShare)
    public static let grip = GCButtonElementName("Grip")
    public static let leftSideButton = GCButtonElementName("Left Side Button"), rightSideButton = GCButtonElementName("Right Side Button")
    public static func arcadeButton(row: Int, column: Int) -> GCButtonElementName { GCButtonElementName("Arcade Button \(row) \(column)") }
    public static func backLeftButton(position: Int) -> GCButtonElementName { GCButtonElementName("Back Left Button \(position)") }
    public static func backRightButton(position: Int) -> GCButtonElementName { GCButtonElementName("Back Right Button \(position)") }
}
public struct GCAxisElementName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let steeringWheel = GCAxisElementName("Steering Wheel")
}
public struct GCDirectionPadElementName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let directionPad = GCDirectionPadElementName(GCInputDirectionPad)
    public static let leftThumbstick = GCDirectionPadElementName(GCInputLeftThumbstick)
    public static let rightThumbstick = GCDirectionPadElementName(GCInputRightThumbstick)
    public static let thumbstick = GCDirectionPadElementName("Thumbstick")
}
public struct GCSwitchElementName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct GCPoint2: Sendable, Equatable {
    public var x: Float, y: Float
    public init() { x = 0; y = 0 }
    public init(x: Float, y: Float) { self.x = x; self.y = y }
}

// MARK: - protocols

public protocol GCPhysicalInputElement: NSObjectProtocol {
    var localizedName: String? { get }
    var sfSymbolsName: String? { get }
    var aliases: Set<String> { get }
}
@objc public enum GCPhysicalInputSourceDirection: UInt, Sendable { case notApplicable = 0, up = 1, right = 2, down = 4, left = 8 }
public protocol GCPhysicalInputSource: NSObjectProtocol {
    var elementLocalizedName: String? { get }
    var sfSymbolsName: String? { get }
    var elementAliases: Set<String> { get }
    var direction: GCPhysicalInputSourceDirection { get }
}
public protocol GCLinearInput: NSObjectProtocol {
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCLinearInput, Float) -> Void)? { get set }
    var value: Float { get }
    var isAnalog: Bool { get }
    var canWrap: Bool { get }
    var lastValueTimestamp: TimeInterval { get }
    var lastValueLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCPressedStateInput: NSObjectProtocol {
    var pressedDidChangeHandler: ((any GCPhysicalInputElement, any GCPressedStateInput, Bool) -> Void)? { get set }
    var isPressed: Bool { get }
    var lastPressedStateTimestamp: TimeInterval { get }
    var lastPressedStateLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCTouchedStateInput: NSObjectProtocol {
    var touchedDidChangeHandler: ((any GCPhysicalInputElement, any GCTouchedStateInput, Bool) -> Void)? { get set }
    var isTouched: Bool { get }
    var lastTouchedStateTimestamp: TimeInterval { get }
    var lastTouchedStateLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCAxisInput: NSObjectProtocol {
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCAxisInput, Float) -> Void)? { get set }
    var value: Float { get }
    var isAnalog: Bool { get }
    var canWrap: Bool { get }
    var lastValueTimestamp: TimeInterval { get }
    var lastValueLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCAxis2DInput: NSObjectProtocol {
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCAxis2DInput, GCPoint2) -> Void)? { get set }
    var value: GCPoint2 { get }
    var isAnalog: Bool { get }
    var canWrap: Bool { get }
    var lastValueTimestamp: TimeInterval { get }
    var lastValueLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCRelativeInput: NSObjectProtocol {
    var deltaDidChangeHandler: ((any GCPhysicalInputElement, any GCRelativeInput, Float) -> Void)? { get set }
    var delta: Float { get }
    var isAnalog: Bool { get }
    var lastDeltaTimestamp: TimeInterval { get }
    var lastDeltaLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCSwitchPositionInput: NSObjectProtocol {
    var positionDidChangeHandler: ((any GCPhysicalInputElement, any GCSwitchPositionInput, Int) -> Void)? { get set }
    var position: Int { get }
    var positionRange: NSRange { get }
    var isSequential: Bool { get }
    var canWrap: Bool { get }
    var lastPositionTimestamp: TimeInterval { get }
    var lastPositionLatency: TimeInterval { get }
    var sources: Set<AnyHashable> { get }
}
public protocol GCButtonElement: GCPhysicalInputElement {
    var pressedInput: any GCLinearInput & GCPressedStateInput { get }
    var touchedInput: (any GCTouchedStateInput)? { get }
    var forceInput: (any GCLinearInput)? { get }
}
public protocol GCAxisElement: GCPhysicalInputElement {
    var absoluteInput: (any GCAxisInput)? { get }
    var relativeInput: any GCRelativeInput { get }
}
public protocol GCDirectionPadElement: GCPhysicalInputElement {
    var xAxis: any GCAxisInput { get }
    var yAxis: any GCAxisInput { get }
    var xyAxes: any GCAxis2DInput { get }
    var up: any GCLinearInput & GCPressedStateInput { get }
    var down: any GCLinearInput & GCPressedStateInput { get }
    var left: any GCLinearInput & GCPressedStateInput { get }
    var right: any GCLinearInput & GCPressedStateInput { get }
}
public protocol GCSwitchElement: GCPhysicalInputElement {
    var positionInput: any GCSwitchPositionInput { get }
}

/// Elements of an input state, by name.
public struct GCPhysicalInputElementCollection<T>: Sequence {
    let _items: [(String, T)]
    init(_ items: [(String, T)]) { _items = items.sorted { $0.0 < $1.0 } }
    public var count: Int { _items.count }
    public var isEmpty: Bool { _items.isEmpty }
    public func makeIterator() -> IndexingIterator<[T]> { _items.map { $0.1 }.makeIterator() }
    public subscript(_ name: String) -> T? { _items.first { $0.0 == name }?.1 }
    public subscript(_ name: GCButtonElementName) -> T? { self[name.rawValue] }
    public subscript(_ name: GCAxisElementName) -> T? { self[name.rawValue] }
    public subscript(_ name: GCDirectionPadElementName) -> T? { self[name.rawValue] }
    public subscript(_ name: GCSwitchElementName) -> T? { self[name.rawValue] }
    public subscript(_ name: GCPhysicalInputElementName) -> T? { self[name.rawValue] }
}

@objc public enum GCDevicePhysicalInputElementChange: Int, Sendable { case unknownChange = -1, noChange = 0, changed = 1 }

public protocol GCDevicePhysicalInputState: NSObjectProtocol {
    var device: (any GCDevice)? { get }
    var lastEventTimestamp: TimeInterval { get }
    var lastEventLatency: TimeInterval { get }
    var elements: GCPhysicalInputElementCollection<any GCPhysicalInputElement> { get }
    var buttons: GCPhysicalInputElementCollection<any GCButtonElement> { get }
    var axes: GCPhysicalInputElementCollection<any GCAxisElement> { get }
    var switches: GCPhysicalInputElementCollection<any GCSwitchElement> { get }
    var dpads: GCPhysicalInputElementCollection<any GCDirectionPadElement> { get }
    subscript(_ elementName: String) -> (any GCPhysicalInputElement)? { get }
}
public protocol GCDevicePhysicalInputStateDiff: NSObjectProtocol {
    func change(for element: any GCPhysicalInputElement) -> GCDevicePhysicalInputElementChange
    func changedElements() -> NSEnumerator?
}
public protocol GCDevicePhysicalInput: GCDevicePhysicalInputState {
    var queue: DispatchQueue? { get set }
    var elementValueDidChangeHandler: ((any GCDevicePhysicalInput, any GCPhysicalInputElement) -> Void)? { get set }
    func capture() -> any GCDevicePhysicalInputState
    var inputStateAvailableHandler: ((any GCDevicePhysicalInput) -> Void)? { get set }
    var inputStateQueueDepth: Int { get set }
    func nextInputState() -> (any GCDevicePhysicalInputState & GCDevicePhysicalInputStateDiff)?
}

// MARK: - wrappers over the profile's elements

/// a button, axis or d-pad direction's value (live, or frozen at a capture)
class _GCValueInput: NSObject {
    weak var element: (any GCPhysicalInputElement)?
    let source: GCControllerElement
    var frozen: Float?
    var stamp: TimeInterval = 0
    init(_ e: GCControllerElement, frozen: Float? = nil) { source = e; self.frozen = frozen }
    var _live: Float { (source as? GCControllerButtonInput)?.value ?? (source as? GCControllerAxisInput)?.value ?? 0 }
    var value: Float { frozen ?? _live }
    var isAnalog: Bool { source.isAnalog }
    var canWrap: Bool { false }
    var lastValueTimestamp: TimeInterval { stamp }
    var lastValueLatency: TimeInterval { 0 }
    var sources: Set<AnyHashable> { [] }
}

/// a button or d-pad direction as the iOS 17 inputs
final class _GCLinearPressed: _GCValueInput, GCLinearInput, GCPressedStateInput, GCTouchedStateInput {
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCLinearInput, Float) -> Void)?
    var pressedDidChangeHandler: ((any GCPhysicalInputElement, any GCPressedStateInput, Bool) -> Void)?
    var touchedDidChangeHandler: ((any GCPhysicalInputElement, any GCTouchedStateInput, Bool) -> Void)?
    var isPressed: Bool { (source as? GCControllerButtonInput).map { b in frozen.map { $0 > 0.5 } ?? b.isPressed } ?? false }
    var isTouched: Bool { isPressed }
    var lastPressedStateTimestamp: TimeInterval { stamp }
    var lastPressedStateLatency: TimeInterval { 0 }
    var lastTouchedStateTimestamp: TimeInterval { stamp }
    var lastTouchedStateLatency: TimeInterval { 0 }
    var _lastPressed = false
    func fire() {
        guard frozen == nil, let e = element else { return }
        stamp = ProcessInfo.processInfo.systemUptime
        valueDidChangeHandler?(e, self, value)
        let p = isPressed
        if p != _lastPressed { _lastPressed = p; pressedDidChangeHandler?(e, self, p); touchedDidChangeHandler?(e, self, p) }
    }
}

/// a d-pad or thumbstick axis as the iOS 17 input
final class _GCAxis: _GCValueInput, GCAxisInput {
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCAxisInput, Float) -> Void)?
    var _last: Float = 0
    func fire() {
        guard frozen == nil, let e = element, value != _last else { return }
        _last = value
        stamp = ProcessInfo.processInfo.systemUptime
        valueDidChangeHandler?(e, self, value)
    }
}

final class _GCButtonElement: NSObject, GCButtonElement {
    let button: GCControllerButtonInput, input: _GCLinearPressed
    init(_ b: GCControllerButtonInput, frozen: Bool = false) {
        button = b; input = _GCLinearPressed(b, frozen: frozen ? b.value : nil)
        super.init()
        input.element = self
    }
    var localizedName: String? { button.localizedName }
    var sfSymbolsName: String? { button.sfSymbolsName }
    var aliases: Set<String> { button.aliases }
    var pressedInput: any GCLinearInput & GCPressedStateInput { input }
    var touchedInput: (any GCTouchedStateInput)? { nil }
    var forceInput: (any GCLinearInput)? { button.isAnalog ? input : nil }
}

final class _GCAxis2D: NSObject, GCAxis2DInput {
    weak var element: (any GCPhysicalInputElement)?
    let pad: GCControllerDirectionPad
    var frozen: GCPoint2?
    var stamp: TimeInterval = 0
    init(_ p: GCControllerDirectionPad, frozen: GCPoint2?) { pad = p; self.frozen = frozen }
    var valueDidChangeHandler: ((any GCPhysicalInputElement, any GCAxis2DInput, GCPoint2) -> Void)?
    var value: GCPoint2 { frozen ?? GCPoint2(x: pad.xAxis.value, y: pad.yAxis.value) }
    var isAnalog: Bool { pad.isAnalog }
    var canWrap: Bool { false }
    var lastValueTimestamp: TimeInterval { stamp }
    var lastValueLatency: TimeInterval { 0 }
    var sources: Set<AnyHashable> { [] }
}

final class _GCDirectionPadElement: NSObject, GCDirectionPadElement {
    let pad: GCControllerDirectionPad
    let x: _GCAxis, y: _GCAxis, xy: _GCAxis2D
    let u: _GCLinearPressed, d: _GCLinearPressed, l: _GCLinearPressed, r: _GCLinearPressed
    init(_ p: GCControllerDirectionPad, frozen: Bool = false) {
        pad = p
        func lp(_ e: GCControllerButtonInput) -> _GCLinearPressed { _GCLinearPressed(e, frozen: frozen ? e.value : nil) }
        x = _GCAxis(p.xAxis, frozen: frozen ? p.xAxis.value : nil); y = _GCAxis(p.yAxis, frozen: frozen ? p.yAxis.value : nil)
        u = lp(p.up); d = lp(p.down); l = lp(p.left); r = lp(p.right)
        xy = _GCAxis2D(p, frozen: frozen ? GCPoint2(x: p.xAxis.value, y: p.yAxis.value) : nil)
        super.init()
        for i in [x, y, u, d, l, r] as [_GCValueInput] { i.element = self }
        xy.element = self
    }
    var localizedName: String? { pad.localizedName }
    var sfSymbolsName: String? { pad.sfSymbolsName }
    var aliases: Set<String> { pad.aliases }
    var xAxis: any GCAxisInput { x }
    var yAxis: any GCAxisInput { y }
    var xyAxes: any GCAxis2DInput { xy }
    var up: any GCLinearInput & GCPressedStateInput { u }
    var down: any GCLinearInput & GCPressedStateInput { d }
    var left: any GCLinearInput & GCPressedStateInput { l }
    var right: any GCLinearInput & GCPressedStateInput { r }
    func fire() {
        x.fire(); y.fire()
        for i in [u, d, l, r] { i.fire() }
        xy.stamp = ProcessInfo.processInfo.systemUptime
        xy.valueDidChangeHandler?(self, xy, xy.value)
    }
}

/// a profile's buttons and d-pads as iOS 17 elements, keyed by name
struct _GCElementSet {
    var buttons: [(String, _GCButtonElement)] = []
    var dpads: [(String, _GCDirectionPadElement)] = []
    init(_ profile: GCPhysicalInputProfile, frozen: Bool) {
        for (name, e) in profile.elements {
            if let b = e as? GCControllerButtonInput { buttons.append((name, _GCButtonElement(b, frozen: frozen))) }
            else if let p = e as? GCControllerDirectionPad { dpads.append((name, _GCDirectionPadElement(p, frozen: frozen))) }
        }
    }
    var all: [(String, any GCPhysicalInputElement)] { buttons.map { ($0.0, $0.1 as any GCPhysicalInputElement) } + dpads.map { ($0.0, $0.1 as any GCPhysicalInputElement) } }
}

// MARK: - states

/// A snapshot of a controller's input.
open class GCControllerInputState: NSObject, GCDevicePhysicalInputState, @unchecked Sendable {
    let _set: _GCElementSet
    weak var _device: (any GCDevice)?
    let _stamp: TimeInterval
    init(_ set: _GCElementSet, device: (any GCDevice)?, stamp: TimeInterval) { _set = set; _device = device; _stamp = stamp }
    open var device: (any GCDevice)? { _device }
    open var lastEventTimestamp: TimeInterval { _stamp }
    open var lastEventLatency: TimeInterval { 0 }
    open var elements: GCPhysicalInputElementCollection<any GCPhysicalInputElement> { GCPhysicalInputElementCollection(_set.all) }
    open var buttons: GCPhysicalInputElementCollection<any GCButtonElement> { GCPhysicalInputElementCollection(_set.buttons.map { ($0.0, $0.1 as any GCButtonElement) }) }
    open var axes: GCPhysicalInputElementCollection<any GCAxisElement> { GCPhysicalInputElementCollection([]) }
    open var switches: GCPhysicalInputElementCollection<any GCSwitchElement> { GCPhysicalInputElementCollection([]) }
    open var dpads: GCPhysicalInputElementCollection<any GCDirectionPadElement> { GCPhysicalInputElementCollection(_set.dpads.map { ($0.0, $0.1 as any GCDirectionPadElement) }) }
    open subscript(_ elementName: String) -> (any GCPhysicalInputElement)? { _set.all.first { $0.0 == elementName }?.1 }
}

/// a queued state with the names of the elements that changed since the previous one
final class _GCControllerInputStateDiff: GCControllerInputState, GCDevicePhysicalInputStateDiff, @unchecked Sendable {
    let changed: Set<String>
    init(_ set: _GCElementSet, device: (any GCDevice)?, stamp: TimeInterval, changed: Set<String>) {
        self.changed = changed
        super.init(set, device: device, stamp: stamp)
    }
    func change(for element: any GCPhysicalInputElement) -> GCDevicePhysicalInputElementChange {
        guard let name = _set.all.first(where: { $0.1 === element })?.0 else { return .unknownChange }
        return changed.contains(name) ? .changed : .noChange
    }
    func changedElements() -> NSEnumerator? {
        (_set.all.filter { changed.contains($0.0) }.map { $0.1 } as NSArray).objectEnumerator()
    }
}

/// A controller's live input (iOS 17): its elements by name, change handlers, captures and a queue of states.
open class GCControllerLiveInput: GCControllerInputState, GCDevicePhysicalInput, @unchecked Sendable {
    weak var _controller: GCController?
    var _states: [_GCControllerInputStateDiff] = []
    var _pending: Set<String> = []
    init(controller: GCController) {
        _controller = controller
        let profile = controller.physicalInputProfile
        super.init(_GCElementSet(profile, frozen: false), device: controller, stamp: profile.lastEventTimestamp)
        for (name, b) in _set.buttons { b.button._observers.append { [weak self, weak b] _ in guard let self, let b else { return }; b.input.fire(); self._changed(name, b) } }
        for (name, p) in _set.dpads { p.pad._observers.append { [weak self, weak p] _ in guard let self, let p else { return }; p.fire(); self._changed(name, p) } }
    }
    open var queue: DispatchQueue?
    open var elementValueDidChangeHandler: ((any GCDevicePhysicalInput, any GCPhysicalInputElement) -> Void)?
    open var inputStateAvailableHandler: ((any GCDevicePhysicalInput) -> Void)?
    /// how many states the queue keeps (older ones are dropped)
    open var inputStateQueueDepth = 1 { didSet { if _states.count > inputStateQueueDepth { _states.removeFirst(_states.count - inputStateQueueDepth) } } }
    /// iOS 17.4: the input without the system's remapping (isim does not remap)
    open var unmapped: GCControllerLiveInput? { self }
    open override var lastEventTimestamp: TimeInterval { _controller?.physicalInputProfile.lastEventTimestamp ?? 0 }
    open func capture() -> GCControllerInputState {
        guard let c = _controller else { return GCControllerInputState(_GCElementSet(GCPhysicalInputProfile(), frozen: true), device: nil, stamp: 0) }
        return GCControllerInputState(_GCElementSet(c.physicalInputProfile, frozen: true), device: c, stamp: lastEventTimestamp)
    }
    @_disfavoredOverload open func capture() -> any GCDevicePhysicalInputState { capture() as GCControllerInputState }
    open func nextInputState() -> (GCControllerInputState & GCDevicePhysicalInputStateDiff)? {
        _states.isEmpty ? nil : _states.removeFirst()
    }
    @_disfavoredOverload open func nextInputState() -> (any GCDevicePhysicalInputState & GCDevicePhysicalInputStateDiff)? {
        _states.isEmpty ? nil : _states.removeFirst()
    }
    func _changed(_ name: String, _ e: any GCPhysicalInputElement) {
        let run = { [weak self] in
            guard let self else { return }
            self.elementValueDidChangeHandler?(self, e)
        }
        if let q = queue, q !== DispatchQueue.main { q.async(execute: run) } else { run() }
        // one state per change, holding what changed since the previous state
        guard inputStateQueueDepth > 0, let c = _controller else { return }
        _pending.insert(name)
        let state = _GCControllerInputStateDiff(_GCElementSet(c.physicalInputProfile, frozen: true), device: c, stamp: lastEventTimestamp, changed: _pending)
        _pending = []
        _states.append(state)
        if _states.count > inputStateQueueDepth { _states.removeFirst(_states.count - inputStateQueueDepth) }
        let h = inputStateAvailableHandler
        if let h { if let q = queue, q !== DispatchQueue.main { q.async { h(self) } } else { h(self) } }
    }
}

extension GCController {
    /// iOS 17: the controller's input by element name (GCButtonElementName, GCDirectionPadElementName)
    public var input: GCControllerLiveInput {
        if let i = _liveInput { return i }
        let i = GCControllerLiveInput(controller: self)
        _liveInput = i
        return i
    }
}

// MARK: - UIKit interaction

public struct GCUIEventTypes: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var gamepad: GCUIEventTypes { GCUIEventTypes(rawValue: 1) }
    public static var stylus: GCUIEventTypes { GCUIEventTypes(rawValue: 2) }
}

/// Lets a view's controller events reach the game instead of the system (iOS 17). Adapted: isim routes no game
/// controller input to UIKit, so the interaction only keeps its settings; GameController delivers the input as usual.
@MainActor open class GCEventInteraction: NSObject, UIInteraction {
    public override init() { super.init() }
    open var handledEventTypes: GCUIEventTypes = []
    open var receivesEventsInView = true
    open private(set) weak var view: UIView?
    open func willMove(to view: UIView?) {}
    open func didMove(to view: UIView?) { self.view = view }
}

/// A view controller whose controller input goes to the game rather than UIKit's focus and menus. Adapted: isim
/// sends no controller events to UIKit, so the setting is kept and has no other effect.
@MainActor open class GCEventViewController: UIViewController {
    open var controllerUserInteractionEnabled = false
}
