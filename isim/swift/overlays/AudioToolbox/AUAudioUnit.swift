// isim AudioToolbox (issue #856): Audio Unit version 3: AUAudioUnit and its busses, presets and parameter trees.
// - AUAudioUnit(componentDescription:) of one of isim's components (or AUAudioUnit.instantiate) is an
//   AUAudioUnitV2Bridge over the version 2 Audio Unit: its busses are the unit's elements, its parameter tree comes
//   from the unit's ParameterList and ParameterInfo, and its render block renders the unit.
// - Subclasses (the app's own Audio Units) provide internalRenderBlock, busses and a parameter tree;
//   registerSubclass(_:as:name:version:) makes the subclass a component: AudioComponentFindNext finds it, and its
//   version 2 instances (AudioComponentInstanceNew, AUGraph) render through it.
// - The members that take AVAudioFormat or UIViewController (AUAudioUnitBus's format, shouldChange(to:for:),
//   requestViewController) are AVFoundation's extension (AVFoundation/AUAudioUnitFormats.swift): isim's AudioToolbox
//   sits below AVFoundation and UIKit, so Swift code sees them once it imports AVFoundation (as it must to make an
//   AVAudioFormat).
// Objective-C: sdk-src/Frameworks/AudioToolbox/AUAudioUnit.h and AUParameters.h declare these classes.
import Foundation
import Dispatch
import CoreMIDI
import ObjectiveC

// MARK: - block types that use the classes (the others are C typedefs of <_AudioToolboxTypes/AudioToolboxDecls.h>)

public typealias AUImplementorValueObserver = (AUParameter, AUValue) -> Void
public typealias AUImplementorValueProvider = (AUParameter) -> AUValue
public typealias AUImplementorStringFromValueCallback = (AUParameter, UnsafePointer<AUValue>?) -> String
public typealias AUImplementorValueFromStringCallback = (AUParameter, String) -> AUValue
public typealias AUImplementorDisplayNameWithLengthCallback = (AUParameterNode, Int) -> String

// MARK: - parameter trees

/// A node of a parameter tree: a parameter or a group. Observers and implementor callbacks set on a node apply to
/// the parameters under it.
@objc(AUParameterNode) open class AUParameterNode: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc public internal(set) var identifier: String
    @objc public internal(set) var displayName: String
    weak var parent: AUParameterGroup?
    @objc open var keyPath: String { parent.map { $0.parent == nil ? identifier : $0.keyPath + "." + identifier } ?? identifier }
    init(identifier: String, name: String) { self.identifier = identifier; displayName = name; super.init() }

    @objc open func displayName(withLength maximumLength: Int) -> String {
        if let cb = _implementor(\._displayNameCallback) { return cb(self, maximumLength) }
        return String(displayName.prefix(max(0, maximumLength)))
    }

    // implementor callbacks: the audio unit's side, found on this node or the nearest group above it
    var _valueObserver: AUImplementorValueObserver?
    var _valueProvider: AUImplementorValueProvider?
    var _stringFromValue: AUImplementorStringFromValueCallback?
    var _valueFromString: AUImplementorValueFromStringCallback?
    var _displayNameCallback: AUImplementorDisplayNameWithLengthCallback?
    func _implementor<T>(_ k: KeyPath<AUParameterNode, T?>) -> T? {
        var n: AUParameterNode? = self
        while let x = n { if let v = x[keyPath: k] { return v }; n = x.parent }
        return nil
    }
    @objc open var implementorValueObserver: AUImplementorValueObserver {
        get { _implementor(\._valueObserver) ?? { _, _ in } }
        set { _valueObserver = newValue }
    }
    @objc open var implementorValueProvider: AUImplementorValueProvider {
        get { _implementor(\._valueProvider) ?? { $0._value } }
        set { _valueProvider = newValue }
    }
    @objc open var implementorStringFromValueCallback: AUImplementorStringFromValueCallback {
        get { _implementor(\._stringFromValue) ?? { p, v in p._defaultString(v?.pointee ?? p._value) } }
        set { _stringFromValue = newValue }
    }
    @objc open var implementorValueFromStringCallback: AUImplementorValueFromStringCallback {
        get { _implementor(\._valueFromString) ?? { p, s in p._defaultValue(s) } }
        set { _valueFromString = newValue }
    }
    @objc open var implementorDisplayNameWithLengthCallback: AUImplementorDisplayNameWithLengthCallback {
        get { _implementor(\._displayNameCallback) ?? { n, l in String(n.displayName.prefix(max(0, l))) } }
        set { _displayNameCallback = newValue }
    }

    // observers: the host's side
    final class Observer {
        let parameter: AUParameterObserver?, recording: AUParameterRecordingObserver?, automation: AUParameterAutomationObserver?
        init(parameter: AUParameterObserver? = nil, recording: AUParameterRecordingObserver? = nil, automation: AUParameterAutomationObserver? = nil) {
            self.parameter = parameter; self.recording = recording; self.automation = automation
        }
        var token: AUParameterObserverToken { Unmanaged.passUnretained(self).toOpaque() }
    }
    var _observers: [Observer] = []
    static let _lock = NSRecursiveLock()
    @objc open func token(byAddingParameterObserver observer: @escaping AUParameterObserver) -> AUParameterObserverToken {
        _add(Observer(parameter: observer))
    }
    @objc open func token(byAddingParameterRecordingObserver observer: @escaping AUParameterRecordingObserver) -> AUParameterObserverToken {
        _add(Observer(recording: observer))
    }
    @objc open func token(byAddingParameterAutomationObserver observer: @escaping AUParameterAutomationObserver) -> AUParameterObserverToken {
        _add(Observer(automation: observer))
    }
    func _add(_ o: Observer) -> AUParameterObserverToken {
        AUParameterNode._lock.lock(); _observers.append(o); AUParameterNode._lock.unlock()
        return o.token
    }
    @objc open func removeParameterObserver(_ token: AUParameterObserverToken) {
        AUParameterNode._lock.lock(); _observers.removeAll { $0.token == token }; AUParameterNode._lock.unlock()
    }
    /// the observers of this node and the groups above it
    var _allObservers: [Observer] {
        AUParameterNode._lock.lock(); defer { AUParameterNode._lock.unlock() }
        var out: [Observer] = [], n: AUParameterNode? = self
        while let x = n { out += x._observers; n = x.parent }
        return out
    }

    public class var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(identifier as NSString, forKey: "identifier"); coder.encode(displayName as NSString, forKey: "name")
    }
    @objc public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: NSString.self, forKey: "identifier") as String?,
              let n = coder.decodeObject(of: NSString.self, forKey: "name") as String? else { return nil }
        identifier = i; displayName = n
        super.init()
    }
}

/// A parameter: its address, range, unit and value. Setting the value tells the audio unit (implementorValueObserver)
/// and the observers other than the originator, on the setting thread.
@objc(AUParameter) open class AUParameter: AUParameterNode, @unchecked Sendable {
    @objc public internal(set) var address: AUParameterAddress
    @objc public internal(set) var minValue: AUValue
    @objc public internal(set) var maxValue: AUValue
    @objc public internal(set) var unit: AudioUnitParameterUnit
    @objc public internal(set) var unitName: String?
    @objc public internal(set) var flags: AudioUnitParameterOptions
    @objc public internal(set) var valueStrings: [String]?
    @objc public internal(set) var dependentParameters: [NSNumber]?
    var _value: AUValue = 0
    /// a version 2 unit's parameter (AUAudioUnitV2Bridge): its ID, scope and element
    var _v2: (id: AudioUnitParameterID, scope: AudioUnitScope, element: AudioUnitElement)?
    init(identifier: String, name: String, address: AUParameterAddress, min: AUValue, max: AUValue, unit: AudioUnitParameterUnit,
         unitName: String?, flags: AudioUnitParameterOptions, valueStrings: [String]?, dependentParameters: [NSNumber]?) {
        self.address = address; minValue = min; maxValue = max; self.unit = unit; self.unitName = unitName; self.flags = flags
        self.valueStrings = valueStrings; self.dependentParameters = dependentParameters
        _value = min
        super.init(identifier: identifier, name: name)
    }
    @objc open var value: AUValue {
        get { _implementor(\._valueProvider).map { $0(self) } ?? _value }
        set { setValue(newValue, originator: nil) }
    }
    @objc(setValue:originator:) open func setValue(_ value: AUValue, originator: AUParameterObserverToken?) {
        setValue(value, originator: originator, atHostTime: 0, eventType: .value)
    }
    @objc(setValue:originator:atHostTime:) open func setValue(_ value: AUValue, originator: AUParameterObserverToken?, atHostTime hostTime: UInt64) {
        setValue(value, originator: originator, atHostTime: hostTime, eventType: .value)
    }
    @objc(setValue:originator:atHostTime:eventType:)
    open func setValue(_ value: AUValue, originator: AUParameterObserverToken?, atHostTime hostTime: UInt64, eventType: AUParameterAutomationEventType) {
        if eventType == .value {
            _value = value
            _implementor(\._valueObserver)?(self, value)
        }
        for o in _allObservers where o.token != originator {
            if eventType == .value { o.parameter?(address, value) }
            if eventType == .value, let r = o.recording {
                var e = AURecordedParameterEvent(hostTime: hostTime, address: address, value: value)
                r(1, &e)
            }
            if let a = o.automation {
                var e = AUParameterAutomationEvent(hostTime: hostTime, address: address, value: value, eventType: eventType, reserved: 0)
                a(1, &e)
            }
        }
    }
    /// The value as text; nil means the current value (the implementor callback gets a pointer to it).
    @objc(stringFromValue:) open func string(fromValue value: UnsafePointer<AUValue>?) -> String {
        if let value { return implementorStringFromValueCallback(self, value) }
        var v = self.value
        return implementorStringFromValueCallback(self, &v)
    }
    @objc(valueFromString:) open func value(from string: String) -> AUValue { implementorValueFromStringCallback(self, string) }
    func _defaultString(_ v: AUValue) -> String {
        if let s = valueStrings, unit == .indexed, Int(v) >= 0, Int(v) < s.count { return s[Int(v)] }
        if unit == .boolean { return v != 0 ? "On" : "Off" }
        return String(format: "%.2f", v)
    }
    func _defaultValue(_ s: String) -> AUValue {
        if let strings = valueStrings, let i = strings.firstIndex(of: s) { return AUValue(i) }
        return AUValue(s.trimmingCharacters(in: .whitespaces)) ?? _value
    }
    @objc open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(Int64(bitPattern: address), forKey: "address"); coder.encode(minValue, forKey: "min"); coder.encode(maxValue, forKey: "max")
        coder.encode(Int64(unit.rawValue), forKey: "unit"); coder.encode(Int64(flags.rawValue), forKey: "flags"); coder.encode(_value, forKey: "value")
        if let u = unitName { coder.encode(u as NSString, forKey: "unitName") }
        if let v = valueStrings { coder.encode(v as NSArray, forKey: "valueStrings") }
        if let d = dependentParameters { coder.encode(d as NSArray, forKey: "dependentParameters") }
    }
    @objc public required init?(coder: NSCoder) {
        address = UInt64(bitPattern: coder.decodeInt64(forKey: "address"))
        minValue = coder.decodeFloat(forKey: "min"); maxValue = coder.decodeFloat(forKey: "max")
        unit = AudioUnitParameterUnit(rawValue: UInt32(truncatingIfNeeded: coder.decodeInt64(forKey: "unit"))) ?? .generic
        flags = AudioUnitParameterOptions(rawValue: UInt32(truncatingIfNeeded: coder.decodeInt64(forKey: "flags")))
        _value = coder.decodeFloat(forKey: "value")
        unitName = coder.decodeObject(of: NSString.self, forKey: "unitName") as String?
        valueStrings = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "valueStrings") as? [String]
        dependentParameters = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "dependentParameters") as? [NSNumber]
        super.init(coder: coder)
    }
    func _copy(offset: AUParameterAddress) -> AUParameter {
        let p = AUParameter(identifier: identifier, name: displayName, address: address + offset, min: minValue, max: maxValue, unit: unit,
                            unitName: unitName, flags: flags, valueStrings: valueStrings, dependentParameters: dependentParameters)
        p._value = _value
        return p
    }
}

@objc(AUParameterGroup) open class AUParameterGroup: AUParameterNode, @unchecked Sendable {
    @objc public internal(set) var children: [AUParameterNode]
    init(identifier: String, name: String, children: [AUParameterNode]) {
        self.children = children
        super.init(identifier: identifier, name: name)
        for c in children { c.parent = self }
    }
    @objc open var allParameters: [AUParameter] {
        children.flatMap { c -> [AUParameter] in
            if let p = c as? AUParameter { return [p] }
            return (c as? AUParameterGroup)?.allParameters ?? []
        }
    }
    @objc open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(children as NSArray, forKey: "children")
    }
    @objc public required init?(coder: NSCoder) {
        children = coder.decodeObject(of: [NSArray.self, AUParameter.self, AUParameterGroup.self], forKey: "children") as? [AUParameterNode] ?? []
        super.init(coder: coder)
        for c in children { c.parent = self }
    }
    func _copy(identifier: String, name: String, offset: AUParameterAddress) -> AUParameterGroup {
        AUParameterGroup(identifier: identifier, name: name, children: children.map {
            if let p = $0 as? AUParameter { return p._copy(offset: offset) }
            let g = $0 as! AUParameterGroup
            return g._copy(identifier: g.identifier, name: g.displayName, offset: offset)
        })
    }
}

/// The root of a parameter tree.
@objc(AUParameterTree) open class AUParameterTree: AUParameterGroup, @unchecked Sendable {
    init(children: [AUParameterNode]) { super.init(identifier: "", name: "", children: children) }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
    @objc open func parameter(withAddress address: AUParameterAddress) -> AUParameter? { allParameters.first { $0.address == address } }
    @objc open func parameter(withID paramID: AudioUnitParameterID, scope: AudioUnitScope, element: AudioUnitElement) -> AUParameter? {
        allParameters.first { p in
            if let v = p._v2 { return v.id == paramID && v.scope == scope && v.element == element }
            return scope == kAudioUnitScope_Global && element == 0 && p.address == AUParameterAddress(paramID)
        }
    }
    @objc(createParameterWithIdentifier:name:address:min:max:unit:unitName:flags:valueStrings:dependentParameters:)
    open class func createParameter(withIdentifier identifier: String, name: String, address: AUParameterAddress, min: AUValue, max: AUValue,
                                    unit: AudioUnitParameterUnit, unitName: String?, flags: AudioUnitParameterOptions = [], valueStrings: [String]?,
                                    dependentParameters: [NSNumber]?) -> AUParameter {
        AUParameter(identifier: identifier, name: name, address: address, min: min, max: max, unit: unit, unitName: unitName, flags: flags,
                    valueStrings: valueStrings, dependentParameters: dependentParameters)
    }
    @objc(createGroupWithIdentifier:name:children:)
    open class func createGroup(withIdentifier identifier: String, name: String, children: [AUParameterNode]) -> AUParameterGroup {
        AUParameterGroup(identifier: identifier, name: name, children: children)
    }
    @objc(createGroupTemplate:) open class func createGroupTemplate(_ children: [AUParameterNode]) -> AUParameterGroup {
        AUParameterGroup(identifier: "", name: "", children: children)
    }
    @objc(createGroupFromTemplate:identifier:name:addressOffset:)
    open class func createGroup(fromTemplate templateGroup: AUParameterGroup, identifier: String, name: String,
                                addressOffset: AUParameterAddress) -> AUParameterGroup {
        templateGroup._copy(identifier: identifier, name: name, offset: addressOffset)
    }
    @objc(createTreeWithChildren:) open class func createTree(withChildren children: [AUParameterNode]) -> AUParameterTree {
        AUParameterTree(children: children)
    }
}

// MARK: - presets, busses

@objc(AUAudioUnitPreset) open class AUAudioUnitPreset: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc open var number: Int = 0
    @objc open var name: String = ""
    @objc public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(number, forKey: "number"); coder.encode(name as NSString, forKey: "name") }
    @objc public required init?(coder: NSCoder) {
        number = coder.decodeInteger(forKey: "number")
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String? ?? ""
        super.init()
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? AUAudioUnitPreset).map { $0.number == number && $0.name == name } ?? false }
    open override var hash: Int { number.hashValue ^ name.hashValue }
}

/// One input or output of an audio unit, with its format (AVFoundation's `format`, `init(format:)`, `setFormat(_:)`).
@objc(AUAudioUnitBus) open class AUAudioUnitBus: NSObject, @unchecked Sendable {
    /// the format: as a stream description, and the AVAudioFormat it came from (made by AVFoundation when nil)
    @objc public var _asbd = AudioStreamBasicDescription()
    @objc public var _formatObject: AnyObject?
    @objc(isEnabled) open var isEnabled: Bool {
        get { _enabled }
        @objc(setEnabled:) set { _enabled = newValue }
    }
    var _enabled = true
    @objc open var name: String?
    @objc public internal(set) var index: Int = 0
    @objc public internal(set) var busType: AUAudioUnitBusType = .output
    @objc public internal(set) unowned(unsafe) var ownerAudioUnit: AUAudioUnit
    @objc open var supportedChannelLayoutTags: [NSNumber]?
    @objc open var shouldAllocateBuffer = true
    @objc open var contextPresentationLatency: TimeInterval = 0
    @objc open var supportedChannelCounts: [NSNumber]?
    @objc open var maximumChannelCount: AUAudioChannelCount = UInt32.max
    /// isim: a bus with a stream description (AVFoundation's init(format:) calls it with the format's)
    @objc public init(_streamDescription asbd: AudioStreamBasicDescription, formatObject: AnyObject?) {
        _asbd = asbd; _formatObject = formatObject
        ownerAudioUnit = AUAudioUnit._placeholder
        super.init()
    }
    /// isim: changes the format, if the owner accepts it (AVFoundation's setFormat(_:) calls it)
    @objc public func _setStreamDescription(_ asbd: AudioStreamBasicDescription, formatObject: AnyObject?) throws {
        guard _PCM.valid(asbd), asbd.mChannelsPerFrame <= maximumChannelCount else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        if ownerAudioUnit !== AUAudioUnit._placeholder {
            guard ownerAudioUnit._acceptsFormat(asbd, formatObject, self) else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported)) }
            if ownerAudioUnit.renderResourcesAllocated { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_Initialized)) }
        }
        willChangeValue(forKey: "format")
        _asbd = asbd; _formatObject = formatObject
        didChangeValue(forKey: "format")
        ownerAudioUnit._busFormatChanged(self)
    }
}

@objc(AUAudioUnitBusArray) open class AUAudioUnitBusArray: NSObject, NSFastEnumeration, @unchecked Sendable {
    @objc public internal(set) unowned(unsafe) var ownerAudioUnit: AUAudioUnit
    @objc public internal(set) var busType: AUAudioUnitBusType
    var _busses: [AUAudioUnitBus]
    @objc(initWithAudioUnit:busType:busses:) public init(audioUnit owner: AUAudioUnit, busType: AUAudioUnitBusType, busses: [AUAudioUnitBus]) {
        ownerAudioUnit = owner; self.busType = busType; _busses = []
        super.init()
        replaceBusses(busses)
    }
    @objc(initWithAudioUnit:busType:) public convenience init(audioUnit owner: AUAudioUnit, busType: AUAudioUnitBusType) {
        self.init(audioUnit: owner, busType: busType, busses: [])
    }
    @objc open var count: Int { _busses.count }
    @objc open subscript(index: Int) -> AUAudioUnitBus { _busses[index] }
    /// a version 2 unit's element count can change (mixers' inputs); a subclass's busses cannot unless it says so
    @objc open var isCountChangeable: Bool { ownerAudioUnit._busCountChangeable(busType) }
    @objc(setBusCount:error:) open func setBusCount(_ count: Int) throws {
        guard isCountChangeable else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_PropertyNotWritable)) }
        try ownerAudioUnit._setBusCount(count, busType)
    }
    @objc(addObserverToAllBusses:forKeyPath:options:context:)
    open func addObserver(toAllBusses observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions = [], context: UnsafeMutableRawPointer?) {
        for b in _busses { b.addObserver(observer, forKeyPath: keyPath, options: options, context: context) }
    }
    @objc(removeObserverFromAllBusses:forKeyPath:context:)
    open func removeObserver(fromAllBusses observer: NSObject, forKeyPath keyPath: String, context: UnsafeMutableRawPointer?) {
        for b in _busses { b.removeObserver(observer, forKeyPath: keyPath, context: context) }
    }
    @objc(replaceBusses:) open func replaceBusses(_ busArray: [AUAudioUnitBus]) {
        _busses = busArray
        for (i, b) in busArray.enumerated() { b.index = i; b.busType = busType; b.ownerAudioUnit = ownerAudioUnit }
    }
    public func countByEnumerating(with state: UnsafeMutablePointer<NSFastEnumerationState>, objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                                   count len: Int) -> Int {
        (_busses as NSArray).countByEnumerating(with: state, objects: buffer, count: len)
    }
}
extension AUAudioUnitBusArray: Sequence {
    public func makeIterator() -> IndexingIterator<[AUAudioUnitBus]> { _busses.makeIterator() }
}

// MARK: - the audio unit

/// invalidComponentID: no component matches the description
let _invalidComponentID: OSStatus = -3000

/// Audio Unit version 3. See the top of the file.
@objc(AUAudioUnit) open class AUAudioUnit: NSObject {
    @objc public internal(set) var componentDescription: AudioComponentDescription
    var _component: _AUComponent?
    @objc open var component: AudioComponent { _component?.handle ?? AudioComponent(bitPattern: 1)! }
    @objc open var componentName: String? { _component?.name }
    @objc open var audioUnitName: String? { componentName.map { n in n.firstIndex(of: ":").map { String(n[n.index($0, offsetBy: 1)...]).trimmingCharacters(in: .whitespaces) } ?? n } }
    @objc open var manufacturerName: String? { componentName.flatMap { n in n.firstIndex(of: ":").map { String(n[..<$0]) } } }
    @objc open var audioUnitShortName: String? { audioUnitName.map { String($0.prefix(16)) } }
    @objc open var componentVersion: UInt32 { _component?.version ?? 0x0001_0000 }

    static let _placeholder = AUAudioUnit(_placeholder: ())
    private init(_placeholder: ()) { componentDescription = AudioComponentDescription(); super.init() }

    public init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        self.componentDescription = componentDescription
        var d = componentDescription
        _component = AudioComponentFindNext(nil, &d).flatMap(AudioToolbox._component)
        super.init()
        if type(of: self) == AUAudioUnit.self || type(of: self) == AUAudioUnitV2Bridge.self {
            // isim's own components and the registered plug-ins: through the version 2 unit
            guard let c = _component, c.auClass == nil, !c.isCodec else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(_invalidComponentID)) }
            var u: AudioComponentInstance? = nil
            let st = AudioComponentInstanceNew(c.handle, &u)
            guard st == noErr_, let u else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(st)) }
            _v2 = u
            _v2Setup()
        }
    }
    @objc(initWithComponentDescription:error:) public convenience init(componentDescription: AudioComponentDescription) throws {
        try self.init(componentDescription: componentDescription, options: [])
    }
    /// Objective-C's initializer (AudioComponentInstantiationOptions is a Swift option set in isim)
    @objc(initWithComponentDescription:options:error:)
    public convenience init(_objcComponentDescription componentDescription: AudioComponentDescription, options: UInt32) throws {
        try self.init(componentDescription: componentDescription, options: AudioComponentInstantiationOptions(rawValue: options))
    }
    /// an instance of a registered class, made the Objective-C way so that its own initializer runs
    static func _instantiate(_ cls: AUAudioUnit.Type, _ d: AudioComponentDescription, _ o: AudioComponentInstantiationOptions) throws -> AUAudioUnit {
        typealias Alloc = @convention(c) (AnyClass, Selector) -> UnsafeMutableRawPointer?
        typealias Init = @convention(c) (UnsafeMutableRawPointer, Selector, AudioComponentDescription, UInt32,
                                         UnsafeMutablePointer<Unmanaged<NSError>?>?) -> UnsafeMutableRawPointer?
        let allocSel = sel_registerName("alloc"), initSel = sel_registerName("initWithComponentDescription:options:error:")
        guard let meta = object_getClass(cls), let a = class_getMethodImplementation(meta, allocSel), let i = class_getMethodImplementation(cls, initSel),
              let obj = unsafeBitCast(a, to: Alloc.self)(cls, allocSel) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization))
        }
        var err: Unmanaged<NSError>? = nil
        guard let r = unsafeBitCast(i, to: Init.self)(obj, initSel, d, o.rawValue, &err) else {
            throw err?.takeUnretainedValue() ?? NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization))
        }
        return Unmanaged<AUAudioUnit>.fromOpaque(r).takeRetainedValue()
    }
    /// isim: the version 3 view of an existing version 2 unit (AVAudioUnit.auAudioUnit); the unit stays its owner's
    init(_wrapping u: AudioUnit) {
        let iu = _IsimAudioUnit.from(u)
        componentDescription = iu?.component.desc ?? AudioComponentDescription()
        _component = iu?.component
        super.init()
        _v2 = u; _ownsV2 = false
        _v2Setup()
    }
    /// isim: AVFoundation's AVAudioUnit.auAudioUnit
    public static func _bridge(_ u: AudioUnit) -> AUAudioUnit { AUAudioUnitV2Bridge(_wrapping: u) }
    deinit {
        if let u = _v2, _ownsV2 { _ = AudioComponentInstanceDispose(u) }
        if let b = _bridgeBox { b.release() }
    }

    /// Makes the audio unit of a component: a registered subclass's instance, or an AUAudioUnitV2Bridge.
    @objc(instantiateWithComponentDescription:options:completionHandler:)
    open class func _objcInstantiate(with componentDescription: AudioComponentDescription, options: UInt32,
                                     completionHandler: @escaping (AUAudioUnit?, Error?) -> Void) {
        instantiate(with: componentDescription, options: AudioComponentInstantiationOptions(rawValue: options), completionHandler: completionHandler)
    }
    @nonobjc open class func instantiate(with componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = [],
                                completionHandler: @escaping (AUAudioUnit?, Error?) -> Void) {
        let r: Result<AUAudioUnit, Error> = Result { try AUAudioUnit._make(componentDescription, options) }
        DispatchQueue.main.async {
            switch r { case .success(let u): completionHandler(u, nil); case .failure(let e): completionHandler(nil, e) }
        }
    }
    @nonobjc open class func instantiate(with componentDescription: AudioComponentDescription,
                                         options: AudioComponentInstantiationOptions = []) async throws -> AUAudioUnit {
        try AUAudioUnit._make(componentDescription, options)
    }
    static func _make(_ d: AudioComponentDescription, _ options: AudioComponentInstantiationOptions) throws -> AUAudioUnit {
        var desc = d
        guard let c = AudioComponentFindNext(nil, &desc).flatMap(AudioToolbox._component) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(_invalidComponentID))
        }
        if let cls = c.auClass { return try _instantiate(cls, c.desc, options) }
        return try AUAudioUnitV2Bridge(componentDescription: c.desc, options: options)
    }
    /// Registers an AUAudioUnit subclass as a component: AUAudioUnit.instantiate makes it, and version 2 hosts
    /// (AudioComponentInstanceNew, AUGraph) get a version 2 unit that renders through it.
    @objc(registerSubclass:asComponentDescription:name:version:)
    open class func registerSubclass(_ cls: AnyClass, as componentDescription: AudioComponentDescription, name: String, version: UInt32) {
        guard let au = cls as? AUAudioUnit.Type else { return }
        let c = _AUComponent(desc: componentDescription, name: name, version: version, factory: nil)
        c.auClass = au
        _AUComponent.lock.lock(); _AUComponent.all.append(c); _AUComponent.lock.unlock()
    }

    // MARK: busses
    @objc open dynamic var inputBusses: AUAudioUnitBusArray { _inputBusses }
    @objc open dynamic var outputBusses: AUAudioUnitBusArray { _outputBusses }
    lazy var _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: _v2Busses(.input))
    lazy var _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: _v2Busses(.output))
    /// isim: whether the unit takes a format: its shouldChange(to:for:) (AVFoundation's extension, which a subclass may
    /// override) when the format is an AVAudioFormat
    func _acceptsFormat(_ asbd: AudioStreamBasicDescription, _ formatObject: AnyObject?, _ bus: AUAudioUnitBus) -> Bool {
        let sel = sel_registerName("shouldChangeToFormat:forBus:")
        guard let f = formatObject, let imp = class_getMethodImplementation(object_getClass(self), sel), responds(to: sel) else { return true }
        typealias Should = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> ObjCBool
        return unsafeBitCast(imp, to: Should.self)(self, sel, f, bus).boolValue
    }
    func _busFormatChanged(_ bus: AUAudioUnitBus) {
        guard let u = _v2 else { return }
        var f = bus._asbd
        _ = AudioUnitSetProperty(u, kAudioUnitProperty_StreamFormat, bus.busType == .input ? kAudioUnitScope_Input : kAudioUnitScope_Output,
                                 AudioUnitElement(bus.index), &f, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
    }
    func _busCountChangeable(_ t: AUAudioUnitBusType) -> Bool {
        _v2 != nil && t == .input && componentDescription.componentSubType == kAudioUnitSubType_MultiChannelMixer
    }
    func _setBusCount(_ n: Int, _ t: AUAudioUnitBusType) throws {
        guard let u = _v2 else { return }
        var c = UInt32(n)
        let st = AudioUnitSetProperty(u, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &c, 4)
        guard st == noErr_ else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(st)) }
        _inputBusses.replaceBusses(_v2Busses(.input))
    }

    // MARK: render resources
    @objc open dynamic var maximumFramesToRender: AUAudioFrameCount = 512 {
        didSet {
            if let u = _v2 { var n = maximumFramesToRender; _ = AudioUnitSetProperty(u, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &n, 4) }
        }
    }
    var _allocated = false
    @objc open dynamic var renderResourcesAllocated: Bool { _allocated }
    @objc(setRenderResourcesAllocated:) open func setRenderResourcesAllocated(_ flag: Bool) { _allocated = flag }
    @objc(allocateRenderResourcesAndReturnError:) open dynamic func allocateRenderResources() throws {
        for b in _outputBusses where !_PCM.valid(b._asbd) { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported)) }
        if let u = _v2 {
            let st = AudioUnitInitialize(u)
            guard st == noErr_ else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(st)) }
        }
        _allocated = true
    }
    @objc open dynamic func deallocateRenderResources() {
        if let u = _v2 { _ = AudioUnitUninitialize(u) }
        _allocated = false
        _eventLock.lock(); _events = []; _eventLock.unlock()
    }
    @objc open dynamic func reset() {
        if let u = _v2 { _ = AudioUnitReset(u, kAudioUnitScope_Global, 0) }
        _eventLock.lock(); _events = []; _eventLock.unlock()
    }

    // MARK: rendering
    /// isim's scheduled events, waiting for the render cycle that holds their sample time
    enum _Event { case parameter(AUEventSampleTime, AUAudioFrameCount, AUParameterAddress, AUValue); case midi(AUEventSampleTime, UInt8, [UInt8]) }
    var _events: [_Event] = []
    let _eventLock = NSLock()
    var _renderObservers: [(Int, AURenderObserver)] = []
    var _nextObserver = 1
    /// The block the host renders with: scheduled events, render observers, then internalRenderBlock.
    @objc open var renderBlock: AURenderBlock {
        return { [unowned self] flags, ts, frames, bus, data, pull in
            guard self.renderResourcesAllocated else { return kAudioUnitErr_Uninitialized }
            guard frames <= self.maximumFramesToRender else { return kAudioUnitErr_TooManyFramesToProcess }
            let observers = self._renderObservers
            for (_, o) in observers { o(.unitRenderAction_PreRender, ts, frames, bus) }
            let start = AUEventSampleTime(ts.pointee.mSampleTime), end = start + AUEventSampleTime(frames)
            self._eventLock.lock()
            let due = self._events.filter { e in
                switch e { case .parameter(let t, _, _, _), .midi(let t, _, _): return t < end || t == AUEventSampleTimeImmediate }
            }
            self._events.removeAll { e in
                switch e { case .parameter(let t, _, _, _), .midi(let t, _, _): return t < end || t == AUEventSampleTimeImmediate }
            }
            self._eventLock.unlock()
            let st = AUAudioUnit._withEventList(due, start: start) { head in
                self.internalRenderBlock(flags, ts, frames, bus, data, head, pull)
            }
            var post = flags.pointee; post.insert(.unitRenderAction_PostRender)
            for (_, o) in observers { o(post, ts, frames, bus) }
            return st
        }
    }
    /// the events as Apple's AURenderEvent list, in time order (immediate ones at the start of the cycle)
    static func _withEventList(_ events: [_Event], start: AUEventSampleTime, _ body: (UnsafePointer<AURenderEvent>?) -> AUAudioUnitStatus) -> AUAudioUnitStatus {
        guard !events.isEmpty else { return body(nil) }
        let list = UnsafeMutablePointer<AURenderEvent>.allocate(capacity: events.count)
        defer { list.deallocate() }
        func time(_ e: _Event) -> AUEventSampleTime {
            switch e { case .parameter(let t, _, _, _), .midi(let t, _, _): return t == AUEventSampleTimeImmediate ? start : max(start, t) }
        }
        let sorted = events.sorted { time($0) < time($1) }
        for (i, e) in sorted.enumerated() {
            var r = AURenderEvent()
            switch e {
            case .parameter(_, let ramp, let addr, let v):
                r.parameter = AUParameterEvent(next: nil, eventSampleTime: time(e), eventType: ramp > 0 ? .parameterRamp : .parameter,
                                               reserved: (0, 0, 0), rampDurationSampleFrames: ramp, parameterAddress: addr, value: v)
            case .midi(_, let cable, let bytes):
                var m = AUMIDIEvent()
                m.eventSampleTime = time(e); m.eventType = .MIDI; m.cable = cable; m.length = UInt16(min(3, bytes.count))
                withUnsafeMutableBytes(of: &m.data) { b in for (k, x) in bytes.prefix(3).enumerated() { b[k] = x } }
                r.MIDI = m
            }
            list[i] = r
        }
        for i in 0..<sorted.count - 1 { list[i].head.next = list + i + 1 }
        return body(list)
    }
    /// What a subclass renders with; isim's version 2 bridge renders its unit. The base class has nothing to render.
    @objc open dynamic var internalRenderBlock: AUInternalRenderBlock {
        guard _v2 != nil else { return { _, _, _, _, _, _, _ in kAudioUnitErr_Uninitialized } }
        return _v2RenderBlock
    }
    @objc(tokenByAddingRenderObserver:) open dynamic func token(byAddingRenderObserver observer: @escaping AURenderObserver) -> Int {
        let t = _nextObserver; _nextObserver += 1
        _renderObservers.append((t, observer))
        return t
    }
    @objc open func removeRenderObserver(_ token: Int) { _renderObservers.removeAll { $0.0 == token } }
    @objc open var scheduleParameterBlock: AUScheduleParameterBlock {
        return { [unowned self] t, ramp, addr, v in
            self._eventLock.lock(); self._events.append(.parameter(t, ramp, addr, v)); self._eventLock.unlock()
        }
    }
    @objc open dynamic var scheduleMIDIEventBlock: AUScheduleMIDIEventBlock? {
        guard _acceptsMIDI else { return nil }
        return { [unowned self] t, cable, length, bytes in
            let b = Array(UnsafeBufferPointer(start: bytes, count: length))
            self._eventLock.lock(); self._events.append(.midi(t, cable, b)); self._eventLock.unlock()
        }
    }
    @objc open dynamic var scheduleMIDIEventListBlock: AUMIDIEventListBlock? {
        guard _acceptsMIDI else { return nil }
        return { [unowned self] t, cable, list in
            // MIDI 1.0 channel voice messages of the list's universal packets, as MIDI events
            var p = list.pointee.packet
            for _ in 0..<list.pointee.numPackets {
                let words = withUnsafeBytes(of: p.words) { Array($0.bindMemory(to: UInt32.self).prefix(Int(p.wordCount))) }
                for w in words where w >> 28 == 2 {
                    let status = UInt8((w >> 16) & 0xFF), d1 = UInt8((w >> 8) & 0x7F), d2 = UInt8(w & 0x7F)
                    let bytes = status & 0xF0 == 0xC0 || status & 0xF0 == 0xD0 ? [status, d1] : [status, d1, d2]
                    self._eventLock.lock(); self._events.append(.midi(t, cable, bytes)); self._eventLock.unlock()
                }
                p = MIDIEventPacketNext(&p).pointee
            }
            return noErr_
        }
    }
    var _acceptsMIDI: Bool {
        let t = componentDescription.componentType
        return t == kAudioUnitType_MusicDevice || t == kAudioUnitType_MusicEffect || t == kAudioUnitType_MIDIProcessor
    }
    @objc(MIDIOutputNames) open dynamic var midiOutputNames: [String] { [] }
    @objc(MIDIOutputEventBlock) open var midiOutputEventBlock: AUMIDIOutputEventBlock?
    @objc(MIDIOutputEventListBlock) open var midiOutputEventListBlock: AUMIDIEventListBlock?
    @objc(MIDIOutputBufferSizeHint) open var midiOutputBufferSizeHint: Int = 0
    @objc(AudioUnitMIDIProtocol) open dynamic var audioUnitMIDIProtocol: MIDIProtocolID { ._1_0 }
    @objc open var hostMIDIProtocol: MIDIProtocolID = ._1_0
    @objc open dynamic var providesUserInterface: Bool { false }
    @objc open dynamic var isMusicDeviceOrEffect: Bool { _acceptsMIDI }
    @objc open dynamic var virtualMIDICableCount: Int { _acceptsMIDI ? 1 : 0 }
    @objc open dynamic var supportsMPE: Bool { false }
    @objc open var musicalContextBlock: AUHostMusicalContextBlock?
    @objc open var transportStateBlock: AUHostTransportStateBlock?

    // MARK: parameters, state, presets
    @objc open dynamic var parameterTree: AUParameterTree? {
        get { _parameterTree ?? _v2Tree }
        set { _parameterTree = newValue }
    }
    var _parameterTree: AUParameterTree?
    lazy var _v2Tree: AUParameterTree? = _v2ParameterTree()
    @objc(parametersForOverviewWithCount:) open dynamic func parametersForOverview(withCount count: Int) -> [NSNumber] {
        (parameterTree?.allParameters ?? []).prefix(count).map { NSNumber(value: $0.address) }
    }
    @objc open dynamic var allParameterValues: Bool { false }
    /// The parameter values (by address) and the current preset, as a property list.
    @objc open dynamic var fullState: [String: Any]? {
        get {
            var values: [String: Any] = [:]
            for p in parameterTree?.allParameters ?? [] { values[String(p.address)] = NSNumber(value: p.value) }
            var d: [String: Any] = ["type": NSNumber(value: componentDescription.componentType), "subtype": NSNumber(value: componentDescription.componentSubType),
                                    "manufacturer": NSNumber(value: componentDescription.componentManufacturer), "version": NSNumber(value: componentVersion),
                                    "data": values]
            if let p = currentPreset { d["name"] = p.name; d["preset-number"] = NSNumber(value: p.number) }
            return d
        }
        set {
            guard let s = newValue else { return }
            if let values = s["data"] as? [String: Any] {
                for (k, v) in values { if let a = UInt64(k), let n = v as? NSNumber { parameterTree?.parameter(withAddress: a)?.value = n.floatValue } }
            }
            if let n = s["name"] as? String { let p = AUAudioUnitPreset(); p.name = n; p.number = (s["preset-number"] as? NSNumber).map { Int($0.intValue) } ?? -1; _currentPreset = p }
        }
    }
    @objc open dynamic var fullStateForDocument: [String: Any]? {
        get { fullState }
        set { fullState = newValue }
    }
    @objc open dynamic var factoryPresets: [AUAudioUnitPreset]? { nil }
    var _currentPreset: AUAudioUnitPreset?
    @objc open dynamic var currentPreset: AUAudioUnitPreset? {
        get { _currentPreset }
        set {
            _currentPreset = newValue
            if let p = newValue, p.number < 0, let s = try? presetState(for: p) { fullState = s }
        }
    }
    // user presets: property lists in the app's Library/Audio/Presets/<manufacturer>/<unit name>/
    var _presetDirectory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return lib.appendingPathComponent("Audio/Presets/\(manufacturerName ?? "isim")/\(audioUnitName ?? "AudioUnit")", isDirectory: true)
    }
    @objc open dynamic var supportsUserPresets: Bool { false }
    @objc open dynamic var userPresets: [AUAudioUnitPreset] {
        let files = (try? FileManager.default.contentsOfDirectory(at: _presetDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "aupreset" }.compactMap { u in
            guard let d = NSDictionary(contentsOfFile: u.path) as? [String: Any] else { return nil }
            let p = AUAudioUnitPreset(); p.name = d["name"] as? String ?? u.deletingPathExtension().lastPathComponent
            p.number = (d["preset-number"] as? NSNumber).map { Int($0.intValue) } ?? -1
            return p
        }.sorted { $0.number > $1.number }
    }
    func _presetURL(_ p: AUAudioUnitPreset) -> URL { _presetDirectory.appendingPathComponent(p.name + ".aupreset") }
    @objc(saveUserPreset:error:) open dynamic func saveUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        guard supportsUserPresets else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidProperty)) }
        guard userPreset.number < 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidPropertyValue)) }
        try FileManager.default.createDirectory(at: _presetDirectory, withIntermediateDirectories: true)
        var s = fullState ?? [:]
        s["name"] = userPreset.name; s["preset-number"] = NSNumber(value: userPreset.number)
        guard (s as NSDictionary).write(toFile: _presetURL(userPreset).path, atomically: true) else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError) }
    }
    @objc(deleteUserPreset:error:) open dynamic func deleteUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        guard supportsUserPresets else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidProperty)) }
        try FileManager.default.removeItem(at: _presetURL(userPreset))
    }
    @objc(presetStateFor:error:) open dynamic func presetState(for userPreset: AUAudioUnitPreset) throws -> [String: Any] {
        guard let d = NSDictionary(contentsOfFile: _presetURL(userPreset).path) as? [String: Any] else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidPropertyValue))
        }
        return d
    }

    // MARK: properties
    @objc open dynamic var latency: TimeInterval { _v2Double(kAudioUnitProperty_Latency) }
    @objc open dynamic var tailTime: TimeInterval { _v2Double(kAudioUnitProperty_TailTime) }
    @objc open dynamic var renderQuality: Int = 127
    @objc open dynamic var shouldBypassEffect: Bool = false {
        didSet { if let u = _v2 { var v: UInt32 = shouldBypassEffect ? 1 : 0; _ = AudioUnitSetProperty(u, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &v, 4) } }
    }
    @objc open dynamic var canProcessInPlace: Bool { false }
    @objc(isRenderingOffline) open var isRenderingOffline: Bool {
        get { _renderingOffline }
        @objc(setRenderingOffline:) set { _renderingOffline = newValue }
    }
    var _renderingOffline = false
    @objc open dynamic var channelCapabilities: [NSNumber]? { nil }
    @objc open dynamic var contextName: String?
    @objc open dynamic var migrateFromPlugin: [Any] { [] }
    @objc open dynamic var channelMap: [NSNumber]?
    // views: isim's audio units have none (AVFoundation's requestViewController answers nil)
    @objc(supportedViewConfigurations:) open dynamic func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        IndexSet(integersIn: 0..<availableViewConfigurations.count)
    }
    @objc(selectViewConfiguration:) open dynamic func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {}
    @objc(messageChannelFor:) open dynamic func messageChannel(for channelName: String) -> AUMessageChannel { _AUMessageChannel(self, channelName) }

    // MARK: input and output units (AUAudioInputOutputUnit)
    @objc open dynamic var canPerformInput: Bool { _isIO }
    @objc open dynamic var canPerformOutput: Bool { _isIO }
    var _isIO: Bool { componentDescription.componentType == kAudioUnitType_Output && componentDescription.componentSubType != kAudioUnitSubType_GenericOutput }
    @objc(isInputEnabled) open var isInputEnabled: Bool {
        get { _v2UInt32(kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1) != 0 }
        @objc(setInputEnabled:) set { if let u = _v2 { var v: UInt32 = newValue ? 1 : 0; _ = AudioUnitSetProperty(u, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &v, 4) } }
    }
    @objc(isOutputEnabled) open var isOutputEnabled: Bool {
        get { _isIO ? _v2UInt32(kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0) != 0 : false }
        @objc(setOutputEnabled:) set { if let u = _v2 { var v: UInt32 = newValue ? 1 : 0; _ = AudioUnitSetProperty(u, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &v, 4) } }
    }
    /// What the output unit plays: called for each slice of its output (bus 0's format).
    @objc open var outputProvider: AURenderPullInputBlock? { didSet { _v2InstallIOCallbacks() } }
    /// Told when the input unit has captured audio; render bus 1 with renderBlock to fetch it.
    @objc open var inputHandler: AUInputHandler? { didSet { _v2InstallIOCallbacks() } }
    @objc(isRunning) open var isRunning: Bool { _v2UInt32(kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0) != 0 }
    @objc(startHardwareAndReturnError:) open dynamic func startHardware() throws {
        guard let u = _v2, _isIO else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidProperty)) }
        if !renderResourcesAllocated { try allocateRenderResources() }
        let st = AudioOutputUnitStart(u)
        guard st == noErr_ else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(st)) }
    }
    @objc open dynamic func stopHardware() { if let u = _v2 { _ = AudioOutputUnitStop(u) } }

    // MARK: the version 2 unit behind isim's own components
    var _v2: AudioUnit?
    var _ownsV2 = true
    var _pull: AURenderPullInputBlock?
    var _bridgeBox: Unmanaged<AUAudioUnit>?
    func _v2Setup() {
        guard let u = _v2 else { return }
        var n: UInt32 = 0, size: UInt32 = 4
        if AudioUnitGetProperty(u, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &n, &size) == noErr_ { maximumFramesToRender = n }
        // the inputs come from the pull block of the render call in progress
        let box = Unmanaged.passUnretained(self)
        let ins = _IsimAudioUnit.from(u)?.inputBusCount ?? 0
        for b in 0..<ins where !_isIO || b == 0 {
            var cb = AURenderCallbackStruct(inputProc: { ref, flags, ts, bus, frames, data in
                let au = Unmanaged<AUAudioUnit>.fromOpaque(ref).takeUnretainedValue()
                if au._isIO, let p = au.outputProvider { return p(flags, ts, frames, Int(bus), data!) }
                guard let pull = au._pull else { return kAudioUnitErr_NoConnection }
                return pull(flags, ts, frames, Int(bus), data!)
            }, inputProcRefCon: box.toOpaque())
            if !_isIO { _ = AudioUnitSetProperty(u, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, b, &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size)) }
        }
    }
    func _v2InstallIOCallbacks() {
        guard let u = _v2, _isIO else { return }
        let ref = Unmanaged.passUnretained(self).toOpaque()
        var out = AURenderCallbackStruct(inputProc: outputProvider == nil ? nil : { ref, flags, ts, bus, frames, data in
            let au = Unmanaged<AUAudioUnit>.fromOpaque(ref).takeUnretainedValue()
            guard let p = au.outputProvider, let data else { return kAudioUnitErr_NoConnection }
            return p(flags, ts, frames, Int(bus), data)
        }, inputProcRefCon: ref)
        _ = AudioUnitSetProperty(u, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &out, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        var input = AURenderCallbackStruct(inputProc: inputHandler == nil ? nil : { ref, flags, ts, bus, frames, _ in
            let au = Unmanaged<AUAudioUnit>.fromOpaque(ref).takeUnretainedValue()
            au.inputHandler?(flags, ts, frames, Int(bus))
            return noErr_
        }, inputProcRefCon: ref)
        _ = AudioUnitSetProperty(u, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &input, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
    }
    var _v2RenderBlock: AUInternalRenderBlock {
        return { [unowned self] flags, ts, frames, bus, data, events, pull in
            guard let u = self._v2 else { return kAudioUnitErr_Uninitialized }
            // parameter events: at the start of the slice (isim's version 2 units take one value per slice)
            var e = events
            while let ev = e {
                switch ev.pointee.head.eventType {
                case .parameter, .parameterRamp:
                    let p = ev.pointee.parameter
                    if let param = self.parameterTree?.parameter(withAddress: p.parameterAddress) { param.setValue(p.value, originator: nil) }
                case .MIDI:
                    let m = ev.pointee.MIDI
                    let b = withUnsafeBytes(of: m.data) { Array($0) }
                    _ = MusicDeviceMIDIEvent(u, UInt32(b[0]), UInt32(b[1]), UInt32(b[2]), 0)
                default: break
                }
                e = ev.pointee.head.next.map { UnsafePointer($0) }
            }
            self._pull = pull
            defer { self._pull = nil }
            return AudioUnitRender(u, flags, ts, UInt32(bus), frames, data)
        }
    }
    func _v2Busses(_ t: AUAudioUnitBusType) -> [AUAudioUnitBus] {
        guard let u = _v2 else { return [] }
        let scope = t == .input ? kAudioUnitScope_Input : kAudioUnitScope_Output
        var n: UInt32 = 0, size: UInt32 = 4
        _ = AudioUnitGetProperty(u, kAudioUnitProperty_ElementCount, scope, 0, &n, &size)
        return (0..<n).map { e in
            var f = AudioStreamBasicDescription(); var s = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            _ = AudioUnitGetProperty(u, kAudioUnitProperty_StreamFormat, scope, e, &f, &s)
            return AUAudioUnitBus(_streamDescription: f, formatObject: nil)
        }
    }
    func _v2ParameterTree() -> AUParameterTree? {
        guard let u = _v2 else { return nil }
        var size: UInt32 = 0
        guard AudioUnitGetPropertyInfo(u, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, &size, nil) == noErr_ else { return nil }
        var ids = [AudioUnitParameterID](repeating: 0, count: Int(size) / 4)
        _ = AudioUnitGetProperty(u, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, &ids, &size)
        let params: [AUParameterNode] = ids.compactMap { id in
            var info = AudioUnitParameterInfo(); var s = UInt32(MemoryLayout<AudioUnitParameterInfo>.size)
            guard AudioUnitGetProperty(u, kAudioUnitProperty_ParameterInfo, kAudioUnitScope_Global, id, &info, &s) == noErr_ else { return nil }
            let name = info.cfNameString.map { $0.takeRetainedValue() as String } ?? "\(id)"
            let p = AUParameter(identifier: name.replacingOccurrences(of: " ", with: ""), name: name, address: AUParameterAddress(id), min: info.minValue,
                                max: info.maxValue, unit: info.unit, unitName: nil, flags: info.flags, valueStrings: nil, dependentParameters: nil)
            p._v2 = (id, kAudioUnitScope_Global, 0)
            var v: AudioUnitParameterValue = 0
            if AudioUnitGetParameter(u, id, kAudioUnitScope_Global, 0, &v) == noErr_ { p._value = v }
            return p
        }
        let tree = AUParameterTree(children: params)
        // the tree is the unit's: values go to it and come from it
        tree.implementorValueObserver = { p, v in
            if let k = p._v2 { _ = AudioUnitSetParameter(u, k.id, k.scope, k.element, v, 0) }
        }
        tree.implementorValueProvider = { p in
            guard let k = p._v2 else { return p._value }
            var v: AudioUnitParameterValue = 0
            return AudioUnitGetParameter(u, k.id, k.scope, k.element, &v) == noErr_ ? v : p._value
        }
        return tree
    }
    func _v2Double(_ id: AudioUnitPropertyID) -> Double {
        guard let u = _v2 else { return 0 }
        var v: Float64 = 0, size: UInt32 = 8
        return AudioUnitGetProperty(u, id, kAudioUnitScope_Global, 0, &v, &size) == noErr_ ? v : 0
    }
    func _v2UInt32(_ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ e: AudioUnitElement) -> UInt32 {
        guard let u = _v2 else { return 0 }
        var v: UInt32 = 0, size: UInt32 = 4
        return AudioUnitGetProperty(u, id, scope, e, &v, &size) == noErr_ ? v : 0
    }
}

/// A size of host view an audio unit's user interface may take.
@objc(AUAudioUnitViewConfiguration) open class AUAudioUnitViewConfiguration: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc public let width: CGFloat
    @objc public let height: CGFloat
    @objc public let hostHasController: Bool
    @objc public init(width: CGFloat, height: CGFloat, hostHasController: Bool) {
        self.width = width; self.height = height; self.hostHasController = hostHasController
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(Double(width), forKey: "width"); coder.encode(Double(height), forKey: "height"); coder.encode(hostHasController, forKey: "hostHasController")
    }
    @objc public required init?(coder: NSCoder) {
        width = CGFloat(coder.decodeDouble(forKey: "width")); height = CGFloat(coder.decodeDouble(forKey: "height"))
        hostHasController = coder.decodeBool(forKey: "hostHasController")
        super.init()
    }
}

/// An audio unit made from a version 2 component (isim's own units and the registered plug-ins).
@objc(AUAudioUnitV2Bridge) open class AUAudioUnitV2Bridge: AUAudioUnit {
    @objc open var audioUnit: AudioUnit { _v2! }
}

/// The audio unit's side of an extension's principal class.
@objc(AUAudioUnitFactory) public protocol AUAudioUnitFactory: NSExtensionRequestHandling {
    @objc(createAudioUnitWithComponentDescription:error:) func createAudioUnit(with desc: AudioComponentDescription) throws -> AUAudioUnit
}

/// A channel for messages between a host and an audio unit.
@objc(AUMessageChannel) public protocol AUMessageChannel {
    @objc(callAudioUnit:) optional func callAudioUnit(_ message: [AnyHashable: Any]) -> [AnyHashable: Any]
    @objc optional var callHostBlock: CallHostBlock? { get set }
}
/// isim: the channel AUAudioUnit's messageChannel(for:) returns: the unit answers no messages
final class _AUMessageChannel: NSObject, AUMessageChannel {
    unowned let unit: AUAudioUnit
    let name: String
    var callHostBlock: CallHostBlock?
    init(_ u: AUAudioUnit, _ n: String) { unit = u; name = n }
    func callAudioUnit(_ message: [AnyHashable: Any]) -> [AnyHashable: Any] { [:] }
}

/// The head-tracking binaural renderer's audio unit (kAudioUnitType_HeadTrackingBinauralRenderer, iOS 26).
/// isim has no head tracking: the renderer reports none.
@objc(AUHeadTrackingBinauralRenderer) open class AUHeadTrackingBinauralRenderer: AUAudioUnit {
    @objc open var isHeadTracking: Bool { false }
    @objc open var deviceUID: String?
    @objc open var isDisabled: Bool = false
}

// MARK: - registered subclasses as version 2 units

extension _AUComponent {
    /// an AUAudioUnit subclass registered with AUAudioUnit.registerSubclass
    var auClass: AUAudioUnit.Type? {
        get { _AUComponent.lock.lock(); defer { _AUComponent.lock.unlock() }; return _auClasses[ObjectIdentifier(self)] }
        set { _AUComponent.lock.lock(); _auClasses[ObjectIdentifier(self)] = newValue; _AUComponent.lock.unlock() }
    }
}
nonisolated(unsafe) private var _auClasses: [ObjectIdentifier: AUAudioUnit.Type] = [:]

/// isim: a version 2 instance of a registered AUAudioUnit subclass: an AudioComponentPlugInInterface whose functions
/// call the AUAudioUnit (formats, maximum frames, render callbacks, parameters, initialize, render).
struct _AUv3PlugIn {
    var iface: AudioComponentPlugInInterface
    var unit: Unmanaged<AUAudioUnit>
    var callbacks: [AURenderCallbackStruct?]
}
func _v3Storage(_ p: UnsafeMutableRawPointer) -> UnsafeMutablePointer<_AUv3PlugIn> { p.assumingMemoryBound(to: _AUv3PlugIn.self) }
private func _v3Unit(_ p: UnsafeMutableRawPointer) -> AUAudioUnit { _v3Storage(p).pointee.unit.takeUnretainedValue() }

let _v3Initialize: AudioUnitInitializeProc = { p in
    do { try _v3Unit(p).allocateRenderResources(); return noErr_ } catch { return OSStatus((error as NSError).code) }
}
let _v3Uninitialize: AudioUnitUninitializeProc = { p in _v3Unit(p).deallocateRenderResources(); return noErr_ }
let _v3GetPropertyInfo: AudioUnitGetPropertyInfoProc = { p, id, scope, e, size, writable in
    var s: UInt32 = 0
    let st = _v3GetProperty(p, id, scope, e, nil, &s)
    size?.pointee = s; writable?.pointee = true
    return st
}
private func _v3GetProperty(_ p: UnsafeMutableRawPointer, _ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ e: AudioUnitElement,
                            _ out: UnsafeMutableRawPointer?, _ size: UnsafeMutablePointer<UInt32>) -> OSStatus {
    let au = _v3Unit(p)
    switch id {
    case kAudioUnitProperty_StreamFormat:
        let busses = scope == kAudioUnitScope_Input ? au.inputBusses : au.outputBusses
        guard Int(e) < busses.count else { return kAudioUnitErr_InvalidElement }
        return _auPut(busses[Int(e)]._asbd, size, out)
    case kAudioUnitProperty_ElementCount:
        return _auPut(UInt32(scope == kAudioUnitScope_Input ? au.inputBusses.count : scope == kAudioUnitScope_Output ? au.outputBusses.count : 1), size, out)
    case kAudioUnitProperty_MaximumFramesPerSlice: return _auPut(au.maximumFramesToRender, size, out)
    case kAudioUnitProperty_Latency: return _auPut(au.latency, size, out)
    case kAudioUnitProperty_TailTime: return _auPut(au.tailTime, size, out)
    case kAudioUnitProperty_BypassEffect: return _auPut(UInt32(au.shouldBypassEffect ? 1 : 0), size, out)
    case kAudioUnitProperty_ParameterList:
        let ps = au.parameterTree?.allParameters ?? []
        guard let out else { size.pointee = UInt32(ps.count * 4); return noErr_ }
        let n = min(ps.count, Int(size.pointee) / 4)
        for i in 0..<n { out.storeBytes(of: AudioUnitParameterID(truncatingIfNeeded: ps[i].address), toByteOffset: 4 * i, as: UInt32.self) }
        size.pointee = UInt32(n * 4)
        return noErr_
    case kAudioUnitProperty_ParameterInfo:
        guard let prm = au.parameterTree?.parameter(withAddress: AUParameterAddress(e)) else { return kAudioUnitErr_InvalidParameter }
        var info = AudioUnitParameterInfo()
        info.cfNameString = Unmanaged.passRetained(prm.displayName as CFString)
        info.unit = prm.unit; info.minValue = prm.minValue; info.maxValue = prm.maxValue; info.defaultValue = prm.value
        info.flags = prm.flags.union([.flag_HasCFNameString, .flag_CFNameRelease])
        return _auPut(info, size, out)
    default: return kAudioUnitErr_InvalidProperty
    }
}
let _v3GetPropertyProc: AudioUnitGetPropertyProc = { p, id, scope, e, out, size in _v3GetProperty(p, id, scope, e, out, size) }
let _v3SetProperty: AudioUnitSetPropertyProc = { p, id, scope, e, data, size in
    let au = _v3Unit(p)
    switch id {
    case kAudioUnitProperty_StreamFormat:
        guard Int(size) >= MemoryLayout<AudioStreamBasicDescription>.size else { return kAudioUnitErr_InvalidPropertyValue }
        let busses = scope == kAudioUnitScope_Input ? au.inputBusses : au.outputBusses
        guard Int(e) < busses.count else { return kAudioUnitErr_InvalidElement }
        do { try busses[Int(e)]._setStreamDescription(data.loadUnaligned(as: AudioStreamBasicDescription.self), formatObject: nil); return noErr_ }
        catch { return OSStatus((error as NSError).code) }
    case kAudioUnitProperty_MaximumFramesPerSlice:
        au.maximumFramesToRender = data.loadUnaligned(as: UInt32.self); return noErr_
    case kAudioUnitProperty_BypassEffect:
        au.shouldBypassEffect = data.loadUnaligned(as: UInt32.self) != 0; return noErr_
    case kAudioUnitProperty_SetRenderCallback:
        let s = _v3Storage(p)
        while s.pointee.callbacks.count <= Int(e) { s.pointee.callbacks.append(nil) }
        let cb = data.loadUnaligned(as: AURenderCallbackStruct.self)
        s.pointee.callbacks[Int(e)] = cb.inputProc == nil ? nil : cb
        return noErr_
    default: return kAudioUnitErr_InvalidProperty
    }
}
let _v3GetParameter: AudioUnitGetParameterProc = { p, id, scope, e, v in
    guard let prm = _v3Unit(p).parameterTree?.parameter(withID: id, scope: scope, element: e) else { return kAudioUnitErr_InvalidParameter }
    v.pointee = prm.value
    return noErr_
}
let _v3SetParameter: AudioUnitSetParameterProc = { p, id, scope, e, v, _ in
    guard let prm = _v3Unit(p).parameterTree?.parameter(withID: id, scope: scope, element: e) else { return kAudioUnitErr_InvalidParameter }
    prm.value = v
    return noErr_
}
let _v3Reset: AudioUnitResetProc = { p, _, _ in _v3Unit(p).reset(); return noErr_ }
let _v3Render: AudioUnitRenderProc = { p, flags, ts, bus, frames, data in
    let s = _v3Storage(p)
    let au = s.pointee.unit.takeUnretainedValue()
    let callbacks = s.pointee.callbacks
    var f = flags?.pointee ?? []
    return au.renderBlock(&f, ts, frames, Int(bus), data) { flags, ts, frames, bus, data in
        guard bus < callbacks.count, let cb = callbacks[bus], let proc = cb.inputProc else { return kAudioUnitErr_NoConnection }
        return proc(cb.inputProcRefCon ?? UnsafeMutableRawPointer(bitPattern: 1)!, flags, ts, UInt32(bus), frames, data)   // a nil refCon, as the units pass it
    }
}
private func _v3Method<T>(_ f: T) -> AudioComponentMethod { unsafeBitCast(f, to: AudioComponentMethod.self) }
let _v3Lookup: @convention(c) (Int16) -> AudioComponentMethod? = { sel in
    switch Int(sel) {
    case Int(kAudioUnitInitializeSelect): return _v3Method(_v3Initialize)
    case Int(kAudioUnitUninitializeSelect): return _v3Method(_v3Uninitialize)
    case Int(kAudioUnitGetPropertyInfoSelect): return _v3Method(_v3GetPropertyInfo)
    case Int(kAudioUnitGetPropertySelect): return _v3Method(_v3GetPropertyProc)
    case Int(kAudioUnitSetPropertySelect): return _v3Method(_v3SetProperty)
    case Int(kAudioUnitGetParameterSelect): return _v3Method(_v3GetParameter)
    case Int(kAudioUnitSetParameterSelect): return _v3Method(_v3SetParameter)
    case Int(kAudioUnitResetSelect): return _v3Method(_v3Reset)
    case Int(kAudioUnitRenderSelect): return _v3Method(_v3Render)
    default: return nil
    }
}
/// a version 2 instance of a registered subclass (AudioComponentInstanceNew)
func _newV3Instance(_ c: _AUComponent, _ cls: AUAudioUnit.Type, _ out: UnsafeMutablePointer<AudioComponentInstance?>) -> OSStatus {
    let au: AUAudioUnit
    do { au = try AUAudioUnit._instantiate(cls, c.desc, []) } catch { return OSStatus((error as NSError).code) }
    let storage = UnsafeMutablePointer<_AUv3PlugIn>.allocate(capacity: 1)
    storage.initialize(to: _AUv3PlugIn(iface: AudioComponentPlugInInterface(Open: { _, _ in noErr_ }, Close: { p in
        let s = _v3Storage(p)
        s.pointee.unit.release()
        s.deinitialize(count: 1); s.deallocate()
        return noErr_
    }, Lookup: _v3Lookup, reserved: nil), unit: Unmanaged.passRetained(au), callbacks: []))
    let plug = _AUPlugIn(c, UnsafeMutableRawPointer(storage).assumingMemoryBound(to: AudioComponentPlugInInterface.self))
    plug.handle = _handle(plug)
    out.pointee = plug.handle
    return noErr_
}
