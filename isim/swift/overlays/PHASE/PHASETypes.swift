// isim PHASE: enums, errors, envelopes, meta parameters, distance and directivity models, groups and duckers.
// The raw values of Apple's four-character-code enums (reverb, medium and material presets, curve types) are isim's
// (proposed); the others follow Apple's headers.
import Foundation
import AVFoundation
import simd
import QuartzCore

public let PHASEErrorDomain = "PHASEErrorDomain"
public let PHASESoundEventErrorDomain = "PHASESoundEventErrorDomain"
public let PHASEAssetErrorDomain = "PHASEAssetErrorDomain"

/// 'PHEa', 'PHEb', ...: the codes Apple's errors use
@inline(__always) func _fourCC(_ s: String) -> Int { s.utf8.reduce(0) { $0 << 8 | Int($1) } }

public struct PHASEError: CustomNSError, Hashable, Sendable {
    @objc(PHASEError) public enum Code: Int, Sendable { case initializeFailed = 1346913633, invalidObject = 1346913634 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { PHASEErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var initializeFailed: Code { .initializeFailed }
    public static var invalidObject: Code { .invalidObject }
}
public struct PHASESoundEventError: CustomNSError, Hashable, Sendable {
    @objc(PHASESoundEventError) public enum Code: Int, Sendable {
        case notFound = 1346913633, badData, invalidInstance, apiMisuse, systemNotInitialized, outOfMemory
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { PHASESoundEventErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var notFound: Code { .notFound }
    public static var badData: Code { .badData }
    public static var invalidInstance: Code { .invalidInstance }
    public static var apiMisuse: Code { .apiMisuse }
    public static var systemNotInitialized: Code { .systemNotInitialized }
    public static var outOfMemory: Code { .outOfMemory }
}
public struct PHASEAssetError: CustomNSError, Hashable, Sendable {
    @objc(PHASEAssetError) public enum Code: Int, Sendable {
        case failedToLoad = 1346913633, invalidEngineInstance, badParameters, alreadyExists, generalError, memoryAllocation
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { PHASEAssetErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var failedToLoad: Code { .failedToLoad }
    public static var invalidEngineInstance: Code { .invalidEngineInstance }
    public static var badParameters: Code { .badParameters }
    public static var alreadyExists: Code { .alreadyExists }
    public static var generalError: Code { .generalError }
    public static var memoryAllocation: Code { .memoryAllocation }
}

@objc public enum PHASENormalizationMode: Int, Sendable { case none = 0, dynamic = 1 }
@objc public enum PHASESpatializationMode: Int, Sendable { case automatic = 0, alwaysUseBinaural = 1, alwaysUseChannelBased = 2 }
@objc public enum PHASEReverbPreset: Int, Sendable {
    case none = 0, smallRoom, mediumRoom, largeRoom, largeRoom2, mediumChamber, largeChamber, mediumHall, mediumHall2, mediumHall3, largeHall, largeHall2, cathedral
}
@objc public enum PHASEMaterialPreset: Int, Sendable { case cardboard = 0, glass, brick, concrete, drywall, wood }
@objc public enum PHASECullOption: Int, Sendable { case terminate = 0, sleepWakeAtZero = 1, sleepWakeAtRandomOffset = 2, sleepWakeAtRealtimeOffset = 3, doNotCull = 4 }
@objc public enum PHASEPlaybackMode: Int, Sendable { case oneShot = 0, looping = 1 }
@objc public enum PHASECalibrationMode: Int, Sendable { case none = 0, relativeSpl = 1, absoluteSpl = 2 }
@objc public enum PHASEPushStreamCompletionCallbackCondition: Int, Sendable { case dataRendered = 0 }
@objc public enum PHASECurveType: Int, Sendable {
    case linear = 0, squared, inverseSquared, cubed, inverseCubed, sine, inverseSine, sigmoid, inverseSigmoid, holdStartValue, jumpToEndValue
    /// the curve from 0 to 1 over t in 0...1
    func shape(_ t: Double) -> Double {
        let t = min(1, max(0, t))
        switch self {
        case .linear: return t
        case .squared: return t * t
        case .inverseSquared: return 1 - (1 - t) * (1 - t)
        case .cubed: return t * t * t
        case .inverseCubed: return 1 - pow(1 - t, 3)
        case .sine: return sin(t * .pi / 2)
        case .inverseSine: return 1 - cos(t * .pi / 2)
        case .sigmoid: return t * t * (3 - 2 * t)
        case .inverseSigmoid: return t < 0.5 ? 0.5 * pow(2 * t, 1.0 / 3) : 1 - 0.5 * pow(2 - 2 * t, 1.0 / 3)
        case .holdStartValue: return t < 1 ? 0 : 1
        case .jumpToEndValue: return t > 0 ? 1 : 0
        }
    }
}
public struct PHASEPushStreamBufferOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var `default`: PHASEPushStreamBufferOptions { PHASEPushStreamBufferOptions(rawValue: 1 << 0) }
    public static var loops: PHASEPushStreamBufferOptions { PHASEPushStreamBufferOptions(rawValue: 1 << 1) }
    public static var interrupts: PHASEPushStreamBufferOptions { PHASEPushStreamBufferOptions(rawValue: 1 << 2) }
    public static var interruptsAtLoop: PHASEPushStreamBufferOptions { PHASEPushStreamBufferOptions(rawValue: 1 << 3) }
}
public struct PHASEAutomaticHeadTrackingFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var orientation: PHASEAutomaticHeadTrackingFlags { PHASEAutomaticHeadTrackingFlags(rawValue: 1 << 0) }
    public static var position: PHASEAutomaticHeadTrackingFlags { PHASEAutomaticHeadTrackingFlags(rawValue: 1 << 1) }
}
public struct PHASESpatialCategory: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let directPathTransmission = PHASESpatialCategory(rawValue: "PHASESpatialCategoryDirectPathTransmission")
    public static let earlyReflections = PHASESpatialCategory(rawValue: "PHASESpatialCategoryEarlyReflections")
    public static let lateReverb = PHASESpatialCategory(rawValue: "PHASESpatialCategoryLateReverb")
}

/// a value that fades from one value to another over a time (main and render threads read it)
struct _Ramp: Sendable {
    var from: Double, to: Double, start: CFTimeInterval = 0, duration: Double = 0, curve: PHASECurveType = .linear
    init(_ v: Double) { from = v; to = v }
    func value(_ now: CFTimeInterval = CACurrentMediaTime()) -> Double {
        guard duration > 0 else { return to }
        let t = (now - start) / duration
        return t >= 1 ? to : from + (to - from) * curve.shape(t)
    }
    mutating func fade(to v: Double, duration d: Double, curve c: PHASECurveType = .linear) {
        let now = CACurrentMediaTime()
        from = value(now); to = v; start = now; duration = max(0, d); curve = c
    }
}

// MARK: - numeric pairs and envelopes

@objc(PHASENumericPair) open class PHASENumericPair: NSObject, @unchecked Sendable {
    @objc open var first: Double
    @objc open var second: Double
    @objc public init(firstValue: Double, secondValue: Double) { first = firstValue; second = secondValue }
}

@objc(PHASEEnvelopeSegment) open class PHASEEnvelopeSegment: NSObject, @unchecked Sendable {
    open var endPoint: simd_double2
    @objc open var curveType: PHASECurveType
    public init(endPoint: simd_double2, curveType: PHASECurveType) { self.endPoint = endPoint; self.curveType = curveType }
    // Objective-C (frameworks/PHASE/PHASE.m: simd_double2 values as two numbers)
    @objc(_isim_segmentWithEndX:y:curveType:) class func _objc_make(_ x: Double, y: Double, curveType: PHASECurveType) -> PHASEEnvelopeSegment {
        PHASEEnvelopeSegment(endPoint: simd_double2(x, y), curveType: curveType)
    }
    @objc(_isim_endPoint) var _objc_endPoint: [NSNumber] {
        get { [NSNumber(value: endPoint.x), NSNumber(value: endPoint.y)] }
        set { endPoint = simd_double2(newValue[0].doubleValue, newValue[1].doubleValue) }
    }
}

/// a piecewise curve: a start point and segments ending at increasing x
@objc(PHASEEnvelope) open class PHASEEnvelope: NSObject, @unchecked Sendable {
    public let startPoint: simd_double2
    @objc public let segments: [PHASEEnvelopeSegment]
    @objc(_isim_startPoint) var _objc_startPoint: [NSNumber] { [NSNumber(value: startPoint.x), NSNumber(value: startPoint.y)] }
    @objc(_isim_envelopeWithStartX:y:segments:) class func _objc_make(_ x: Double, y: Double, segments: [PHASEEnvelopeSegment]) -> PHASEEnvelope? {
        PHASEEnvelope(startPoint: simd_double2(x, y), segments: segments)
    }
    public init?(startPoint: simd_double2, segments: [PHASEEnvelopeSegment]) {
        guard !segments.isEmpty else { return nil }
        var x = startPoint.x
        for s in segments { guard s.endPoint.x >= x else { return nil }; x = s.endPoint.x }
        self.startPoint = startPoint; self.segments = segments
    }
    @objc open var domain: PHASENumericPair { PHASENumericPair(firstValue: startPoint.x, secondValue: segments.last!.endPoint.x) }
    @objc open var range: PHASENumericPair {
        let ys = [startPoint.y] + segments.map(\.endPoint.y)
        return PHASENumericPair(firstValue: ys.min()!, secondValue: ys.max()!)
    }
    /// the curve's value at x (clamped to the domain)
    @objc(evaluateForValue:) open func evaluate(x: Double) -> Double {
        if x <= startPoint.x { return startPoint.y }
        var p = startPoint
        for s in segments {
            if x <= s.endPoint.x {
                let span = s.endPoint.x - p.x
                return p.y + (s.endPoint.y - p.y) * s.curveType.shape(span > 0 ? (x - p.x) / span : 1)
            }
            p = s.endPoint
        }
        return p.y
    }
}

// MARK: - definitions and meta parameters

@objc(PHASEDefinition) open class PHASEDefinition: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    init(_identifier: String?) { identifier = _identifier ?? UUID().uuidString }
}

@objc(PHASEMetaParameterDefinition) open class PHASEMetaParameterDefinition: PHASEDefinition, @unchecked Sendable {
    @objc public let value: Any
    init(_value: Any, identifier: String?) { value = _value; super.init(_identifier: identifier) }
    func _instance() -> PHASEMetaParameter { PHASEMetaParameter(_identifier: identifier, value: value) }
}
@objc(PHASENumberMetaParameterDefinition) open class PHASENumberMetaParameterDefinition: PHASEMetaParameterDefinition, @unchecked Sendable {
    @objc public let minimum: Double
    @objc public let maximum: Double
    @objc public convenience init(value: Double) { self.init(value: value, minimum: -Double.greatestFiniteMagnitude, maximum: .greatestFiniteMagnitude) }
    @objc public convenience init(value: Double, identifier: String) {
        self.init(_value: value, minimum: -Double.greatestFiniteMagnitude, maximum: .greatestFiniteMagnitude, identifier: identifier)
    }
    @objc public convenience init(value: Double, minimum: Double, maximum: Double) { self.init(_value: value, minimum: minimum, maximum: maximum, identifier: nil) }
    @objc public convenience init(value: Double, minimum: Double, maximum: Double, identifier: String) {
        self.init(_value: value, minimum: minimum, maximum: maximum, identifier: identifier)
    }
    init(_value v: Double, minimum: Double, maximum: Double, identifier: String?) {
        self.minimum = minimum; self.maximum = maximum
        super.init(_value: min(maximum, max(minimum, v)), identifier: identifier)
    }
    override func _instance() -> PHASEMetaParameter {
        PHASENumberMetaParameter(_identifier: identifier, value: value as? Double ?? 0, minimum: minimum, maximum: maximum)
    }
}
@objc(PHASEStringMetaParameterDefinition) open class PHASEStringMetaParameterDefinition: PHASEMetaParameterDefinition, @unchecked Sendable {
    @objc public init(value: String) { super.init(_value: value, identifier: nil) }
    @objc public init(value: String, identifier: String) { super.init(_value: value, identifier: identifier) }
    override func _instance() -> PHASEMetaParameter { PHASEStringMetaParameter(_identifier: identifier, value: value) }
}
/// a number derived from another meta parameter through an envelope
@objc(PHASEMappedMetaParameterDefinition) open class PHASEMappedMetaParameterDefinition: PHASENumberMetaParameterDefinition, @unchecked Sendable {
    @objc public let inputMetaParameterDefinition: PHASENumberMetaParameterDefinition
    @objc public let envelope: PHASEEnvelope
    @objc public convenience init(inputMetaParameterDefinition: PHASENumberMetaParameterDefinition, envelope: PHASEEnvelope) {
        self.init(_input: inputMetaParameterDefinition, envelope: envelope, identifier: nil)
    }
    @objc public convenience init(inputMetaParameterDefinition: PHASENumberMetaParameterDefinition, envelope: PHASEEnvelope, identifier: String) {
        self.init(_input: inputMetaParameterDefinition, envelope: envelope, identifier: identifier)
    }
    init(_input: PHASENumberMetaParameterDefinition, envelope: PHASEEnvelope, identifier: String?) {
        inputMetaParameterDefinition = _input; self.envelope = envelope
        super.init(_value: envelope.evaluate(x: _input.value as? Double ?? 0), minimum: envelope.range.first, maximum: envelope.range.second, identifier: identifier)
    }
}

/// a sound event's (or the registry's global) value of a meta parameter definition
@objc(PHASEMetaParameter) open class PHASEMetaParameter: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    let _lock = NSLock()
    var _value: Any
    init(_identifier: String, value: Any) { identifier = _identifier; _value = value }
    @objc open var value: Any {
        get { _lock.lock(); defer { _lock.unlock() }; return _value }
        set { _lock.lock(); _value = newValue; _lock.unlock() }
    }
}
@objc(PHASENumberMetaParameter) open class PHASENumberMetaParameter: PHASEMetaParameter, @unchecked Sendable {
    @objc public let minimum: Double
    @objc public let maximum: Double
    var _ramp: _Ramp
    /// a mapped parameter: its value is the envelope of the input's
    var _mapped: (PHASENumberMetaParameter, PHASEEnvelope)?
    init(_identifier: String, value: Double, minimum: Double, maximum: Double) {
        self.minimum = minimum; self.maximum = maximum; _ramp = _Ramp(value)
        super.init(_identifier: _identifier, value: value)
    }
    var _number: Double {
        if let (input, env) = _mapped { return env.evaluate(x: input._number) }
        _lock.lock(); defer { _lock.unlock() }
        return _ramp.value()
    }
    @objc open override var value: Any {
        get { _number }
        set {
            let v = min(maximum, max(minimum, (newValue as? NSNumber)?.doubleValue ?? (newValue as? Double) ?? _number))
            _lock.lock(); _ramp = _Ramp(v); _lock.unlock()
        }
    }
    /// moves to `value` over `duration` seconds
    @objc(fadeToValue:duration:) open func fade(value: Double, duration: TimeInterval) {
        _lock.lock(); _ramp.fade(to: min(maximum, max(minimum, value)), duration: duration); _lock.unlock()
    }
}
@objc(PHASEStringMetaParameter) open class PHASEStringMetaParameter: PHASEMetaParameter, @unchecked Sendable {
    var _string: String { value as? String ?? "" }
}

// MARK: - distance and directivity models

@objc(PHASEDistanceModelFadeOutParameters) open class PHASEDistanceModelFadeOutParameters: NSObject, @unchecked Sendable {
    @objc public let cullDistance: Double
    @objc public init(cullDistance: Double) { self.cullDistance = max(1e-6, cullDistance) }
}
@objc(PHASEDistanceModelParameters) open class PHASEDistanceModelParameters: NSObject, @unchecked Sendable {
    @objc open var fadeOutParameters: PHASEDistanceModelFadeOutParameters?
    func _gain(_ d: Double) -> Double { 1 }
    /// the model's gain at distance d (meters), faded out over the last tenth before the cull distance
    func _total(_ d: Double) -> Double {
        var g = _gain(d)
        if let f = fadeOutParameters { g *= min(1, max(0, (f.cullDistance - d) / (0.1 * f.cullDistance))) }
        return g
    }
}
/// 1 / distance (from one meter), raised to the rolloff factor
@objc(PHASEGeometricSpreadingDistanceModelParameters) open class PHASEGeometricSpreadingDistanceModelParameters: PHASEDistanceModelParameters, @unchecked Sendable {
    @objc open var rolloffFactor: Double = 1
    @objc public override init() { super.init() }
    override func _gain(_ d: Double) -> Double { pow(1 / max(1, d), rolloffFactor) }
}
@objc(PHASEEnvelopeDistanceModelParameters) open class PHASEEnvelopeDistanceModelParameters: PHASEDistanceModelParameters, @unchecked Sendable {
    @objc public let envelope: PHASEEnvelope
    @objc public init(envelope: PHASEEnvelope) { self.envelope = envelope }
    override func _gain(_ d: Double) -> Double { max(0, envelope.evaluate(x: d)) }
}

@objc(PHASEDirectivityModelParameters) open class PHASEDirectivityModelParameters: NSObject, @unchecked Sendable {
    /// the gain toward a direction `angle` radians off the forward axis
    func _gain(_ angle: Double) -> Double { 1 }
}
@objc(PHASECardioidDirectivityModelSubbandParameters) open class PHASECardioidDirectivityModelSubbandParameters: NSObject, @unchecked Sendable {
    @objc open var frequency: Double = 1000
    @objc open var pattern: Double = 0
    @objc open var sharpness: Double = 1
    @objc public override init() { super.init() }
}
/// ((1 - pattern) + pattern cos θ)^sharpness; isim applies the first subband to the whole spectrum (adapted)
@objc(PHASECardioidDirectivityModelParameters) open class PHASECardioidDirectivityModelParameters: PHASEDirectivityModelParameters, @unchecked Sendable {
    @objc public let subbandParameters: [PHASECardioidDirectivityModelSubbandParameters]
    @objc public init(subbandParameters: [PHASECardioidDirectivityModelSubbandParameters]) { self.subbandParameters = subbandParameters }
    override func _gain(_ angle: Double) -> Double {
        guard let s = subbandParameters.first else { return 1 }
        return pow(max(0, (1 - s.pattern) + s.pattern * cos(angle)), max(0, s.sharpness))
    }
}
@objc(PHASEConeDirectivityModelSubbandParameters) open class PHASEConeDirectivityModelSubbandParameters: NSObject, @unchecked Sendable {
    @objc open var frequency: Double = 1000
    @objc open private(set) var innerAngle: Double = 360
    @objc open private(set) var outerAngle: Double = 360
    @objc open var outerGain: Double = 1
    @objc public override init() { super.init() }
    /// full cone angles in degrees, inner ≤ outer
    @objc(setInnerAngle:outerAngle:) open func setAngles(innerAngle: Double, outerAngle: Double) {
        self.innerAngle = max(0, min(360, innerAngle)); self.outerAngle = max(self.innerAngle, min(360, outerAngle))
    }
}
/// full gain inside the inner cone, outerGain outside the outer one, linear between (first subband)
@objc(PHASEConeDirectivityModelParameters) open class PHASEConeDirectivityModelParameters: PHASEDirectivityModelParameters, @unchecked Sendable {
    @objc public let subbandParameters: [PHASEConeDirectivityModelSubbandParameters]
    @objc public init(subbandParameters: [PHASEConeDirectivityModelSubbandParameters]) { self.subbandParameters = subbandParameters }
    override func _gain(_ angle: Double) -> Double {
        guard let s = subbandParameters.first else { return 1 }
        let deg = angle * 180 / .pi, inner = s.innerAngle / 2, outer = s.outerAngle / 2
        if deg <= inner { return 1 }
        if deg >= outer { return s.outerGain }
        return 1 + (s.outerGain - 1) * (deg - inner) / max(1e-9, outer - inner)
    }
}

// MARK: - groups, presets and duckers

/// a mix group: gain and rate (with fades), mute and solo for the generators assigned to it
@objc(PHASEGroup) open class PHASEGroup: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    let _lock = NSLock()
    var _gain = _Ramp(1), _rate = _Ramp(1), _preset = _Ramp(1), _presetRate = _Ramp(1)
    weak var _engine: PHASEEngine?
    @objc open private(set) var isMuted = false
    @objc open private(set) var isSoloed = false
    @objc public init(identifier: String) { self.identifier = identifier }
    @objc(registerWithEngine:) open func register(engine: PHASEEngine) { _engine = engine; engine._lock.lock(); engine._groups[identifier] = self; engine._lock.unlock() }
    @objc open func unregisterFromEngine() {
        guard let e = _engine else { return }
        e._lock.lock(); e._groups[identifier] = nil; e._lock.unlock(); _engine = nil
    }
    @objc open var gain: Double {
        get { _lock.lock(); defer { _lock.unlock() }; return _gain.value() }
        set { _lock.lock(); _gain = _Ramp(max(0, newValue)); _lock.unlock() }
    }
    @objc open var rate: Double {
        get { _lock.lock(); defer { _lock.unlock() }; return _rate.value() }
        set { _lock.lock(); _rate = _Ramp(max(0.25, min(4, newValue))); _lock.unlock() }
    }
    @objc(fadeGain:duration:curveType:) open func fadeGain(gain: Double, duration: Double, curveType: PHASECurveType) {
        _lock.lock(); _gain.fade(to: max(0, gain), duration: duration, curve: curveType); _lock.unlock()
    }
    @objc(fadeRate:duration:curveType:) open func fadeRate(rate: Double, duration: Double, curveType: PHASECurveType) {
        _lock.lock(); _rate.fade(to: max(0.25, min(4, rate)), duration: duration, curve: curveType); _lock.unlock()
    }
    @objc open func mute() { isMuted = true }
    @objc open func unmute() { isMuted = false }
    @objc open func solo() { isSoloed = true }
    @objc open func unsolo() { isSoloed = false }
    /// the group's gain and rate now (with the active preset)
    var _now: (gain: Double, rate: Double) {
        _lock.lock(); defer { _lock.unlock() }
        let now = CACurrentMediaTime()
        return (_gain.value(now) * _preset.value(now), _rate.value(now) * _presetRate.value(now))
    }
}

@objc(PHASEGroupPresetSetting) open class PHASEGroupPresetSetting: NSObject, @unchecked Sendable {
    @objc public let gain: Double
    @objc public let rate: Double
    @objc public let gainCurveType: PHASECurveType
    @objc public let rateCurveType: PHASECurveType
    @objc public init(gain: Double, rate: Double, gainCurveType: PHASECurveType, rateCurveType: PHASECurveType) {
        self.gain = gain; self.rate = rate; self.gainCurveType = gainCurveType; self.rateCurveType = rateCurveType
    }
}
/// gains and rates for groups (by identifier), faded in when activated and back when deactivated
@objc(PHASEGroupPreset) open class PHASEGroupPreset: NSObject, @unchecked Sendable {
    @objc public let settings: [String: PHASEGroupPresetSetting]
    @objc public let timeToTarget: Double
    @objc public let timeToReset: Double
    weak var engine: PHASEEngine?
    @objc public init(engine: PHASEEngine, settings: [String: PHASEGroupPresetSetting], timeToTarget: Double, timeToReset: Double) {
        self.engine = engine; self.settings = settings; self.timeToTarget = timeToTarget; self.timeToReset = timeToReset
    }
    @objc open func activate() { activate(timeToTargetOverride: timeToTarget) }
    @objc open func activate(timeToTargetOverride: Double) {
        guard let e = engine else { return }
        if let old = e.activeGroupPreset, old !== self { old._reset(timeToTargetOverride) }
        for (id, s) in settings {
            guard let g = e.groups[id] else { continue }
            g._lock.lock()
            g._preset.fade(to: s.gain, duration: timeToTargetOverride, curve: s.gainCurveType)
            g._presetRate.fade(to: s.rate, duration: timeToTargetOverride, curve: s.rateCurveType)
            g._lock.unlock()
        }
        e._activePreset = self
    }
    @objc open func deactivate() { deactivate(timeToResetOverride: timeToReset) }
    @objc open func deactivate(timeToResetOverride: Double) {
        _reset(timeToResetOverride)
        if engine?._activePreset === self { engine?._activePreset = nil }
    }
    func _reset(_ t: Double) {
        guard let e = engine else { return }
        for id in settings.keys {
            guard let g = e.groups[id] else { continue }
            g._lock.lock(); g._preset.fade(to: 1, duration: t); g._presetRate.fade(to: 1, duration: t); g._lock.unlock()
        }
    }
}

/// lowers the target groups while any source group is playing
@objc(PHASEDucker) open class PHASEDucker: NSObject, @unchecked Sendable {
    @objc public let sourceGroups: Set<PHASEGroup>
    @objc public let targetGroups: Set<PHASEGroup>
    @objc public let gain: Double
    @objc public let attackTime: Double
    @objc public let releaseTime: Double
    @objc public let attackCurve: PHASECurveType
    @objc public let releaseCurve: PHASECurveType
    @objc public let identifier = UUID().uuidString
    @objc open private(set) var isActive = false
    weak var engine: PHASEEngine?
    let _lock = NSLock()
    var _level = _Ramp(1), _ducking = false
    @objc public init(engine: PHASEEngine, sourceGroups: Set<PHASEGroup>, targetGroups: Set<PHASEGroup>, gain: Double, attackTime: Double,
                      releaseTime: Double, attackCurve: PHASECurveType, releaseCurve: PHASECurveType) {
        self.engine = engine; self.sourceGroups = sourceGroups; self.targetGroups = targetGroups; self.gain = max(0, min(1, gain))
        self.attackTime = attackTime; self.releaseTime = releaseTime; self.attackCurve = attackCurve; self.releaseCurve = releaseCurve
        super.init()
        engine._lock.lock(); engine._duckers.append(self); engine._lock.unlock()
    }
    @objc open func activate() { isActive = true }
    @objc open func deactivate() { isActive = false; _set(false) }
    /// called by the renderer with whether a source group is playing
    func _set(_ ducking: Bool) {
        _lock.lock(); defer { _lock.unlock() }
        guard ducking != _ducking else { return }
        _ducking = ducking
        if ducking { _level.fade(to: gain, duration: attackTime, curve: attackCurve) } else { _level.fade(to: 1, duration: releaseTime, curve: releaseCurve) }
    }
    var _now: Double { _lock.lock(); defer { _lock.unlock() }; return _level.value() }
}
