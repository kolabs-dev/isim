// isim CoreHaptics: the Objective-C interface (sdk-src/Frameworks/CoreHaptics, issue #548). The classes are
// @objc(CH…) and @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are
// internal Objective-C entry points, under Apple's selectors, for what uses Swift-only types (the parameter, event and
// key structs, which are NSStrings in Objective-C, the engine's Swift enums, and the protocol-typed players and
// capabilities). Players are _IsimHapticPlayer, an NSObject answering CHHapticAdvancedPatternPlayer's selectors.
import Foundation

extension CHHapticEventParameter {
    @objc(initWithParameterID:value:) convenience init(_objcParameterID id: String, value: Float) { self.init(parameterID: ID(rawValue: id), value: value) }
    @objc(parameterID) var _objcParameterID: String { parameterID.rawValue }
}
extension CHHapticDynamicParameter {
    @objc(initWithParameterID:value:relativeTime:) convenience init(_objcParameterID id: String, value: Float, relativeTime: TimeInterval) {
        self.init(parameterID: ID(rawValue: id), value: value, relativeTime: relativeTime)
    }
    @objc(parameterID) var _objcParameterID: String { parameterID.rawValue }
}
extension CHHapticParameterCurve {
    @objc(initWithParameterID:controlPoints:relativeTime:) convenience init(_objcParameterID id: String, controlPoints: [ControlPoint], relativeTime: TimeInterval) {
        self.init(parameterID: CHHapticDynamicParameter.ID(rawValue: id), controlPoints: controlPoints, relativeTime: relativeTime)
    }
    @objc(parameterID) var _objcParameterID: String { parameterID.rawValue }
}
extension CHHapticEvent {
    @objc(initWithEventType:parameters:relativeTime:) convenience init(_objcEventType t: String, parameters: [CHHapticEventParameter], relativeTime: TimeInterval) {
        self.init(eventType: EventType(rawValue: t), parameters: parameters, relativeTime: relativeTime)
    }
    @objc(initWithEventType:parameters:relativeTime:duration:)
    convenience init(_objcEventType t: String, parameters: [CHHapticEventParameter], relativeTime: TimeInterval, duration: TimeInterval) {
        self.init(eventType: EventType(rawValue: t), parameters: parameters, relativeTime: relativeTime, duration: duration)
    }
    @objc(type) var _objcType: String {
        get { type.rawValue }
        set { type = EventType(rawValue: newValue) }
    }
}
extension CHHapticPattern {
    /// keys: Objective-C's CHHapticPatternKey strings
    @objc(initWithDictionary:error:) convenience init(_objcDictionary d: [String: Any]) throws {
        var out: [Key: Any] = [:]
        for (k, v) in d { out[Key(rawValue: k)] = v }
        try self.init(dictionary: out)
    }
    @objc(exportDictionaryAndReturnError:) func _objcExportDictionary() throws -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in try exportDictionary() { out[k.rawValue] = v }
        return out
    }
}

/// CHHapticParameterAttributes for Objective-C
@objcMembers final class _CHObjCParameterAttributes: NSObject {
    let minValue: Float, maxValue: Float, defaultValue: Float
    init(_ a: any CHHapticParameterAttributes) { minValue = a.minValue; maxValue = a.maxValue; defaultValue = a.defaultValue }
}
/// CHHapticDeviceCapability for Objective-C
final class _CHObjCCapability: NSObject {
    let cap: any CHHapticDeviceCapability
    init(_ c: any CHHapticDeviceCapability) { cap = c }
    @objc var supportsHaptics: Bool { cap.supportsHaptics }
    @objc var supportsAudio: Bool { cap.supportsAudio }
    @objc(attributesForEventParameter:eventType:error:) func attributes(forEventParameter p: String, eventType t: String) throws -> _CHObjCParameterAttributes {
        _CHObjCParameterAttributes(try cap.attributes(forEventParameter: .init(rawValue: p), eventType: .init(rawValue: t)))
    }
    @objc(attributesForDynamicParameter:error:) func attributes(forDynamicParameter p: String) throws -> _CHObjCParameterAttributes {
        _CHObjCParameterAttributes(try cap.attributes(forDynamicParameter: .init(rawValue: p)))
    }
}

extension CHHapticEngine {
    @objc(capabilitiesForHardware) class func _objcCapabilities() -> NSObject { _CHObjCCapability(capabilitiesForHardware()) }
    /// the reason as CHHapticEngineStoppedReason's raw value
    @objc(stoppedHandler) var _objcStoppedHandler: (Int) -> Void {
        get { let h = stoppedHandler; return { h(StoppedReason(rawValue: $0) ?? .systemError) } }
        set { stoppedHandler = { newValue($0.rawValue) } }
    }
    @objc(isAutoShutdownEnabled) var _objcAutoShutdownEnabled: Bool {
        get { isAutoShutdownEnabled }
        @objc(setAutoShutdownEnabled:) set { isAutoShutdownEnabled = newValue }
    }
    /// id<CHHapticPatternPlayer>
    @objc(createPlayerWithPattern:error:) func _objcMakePlayer(with pattern: CHHapticPattern) throws -> NSObject {
        try makePlayer(with: pattern) as! NSObject
    }
    /// id<CHHapticAdvancedPatternPlayer>
    @objc(createAdvancedPlayerWithPattern:error:) func _objcMakeAdvancedPlayer(with pattern: CHHapticPattern) throws -> NSObject {
        try makeAdvancedPlayer(with: pattern) as! NSObject
    }
    /// the handler returns CHHapticEngineFinishedAction's raw value
    @objc(notifyWhenPlayersFinished:) func _objcNotifyWhenPlayersFinished(_ handler: @escaping (Error?) -> Int) {
        notifyWhenPlayersFinished { FinishedAction(rawValue: handler($0)) ?? .stopEngine }
    }
}
