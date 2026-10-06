// isim CoreHaptics (self-authored). isim has no haptic hardware, like Apple's Simulator:
// CHHapticEngine.capabilitiesForHardware().supportsHaptics is false. Engines, patterns (events, parameters,
// parameter curves, AHAP dictionaries/files) and players are fully modelled: patterns are validated, players keep
// time (start/stop/pause/resume/seek/loop/rate) and run their completion handlers after the pattern's duration,
// and each playback is logged on stderr ("CoreHaptics: ..."). Nothing is felt or heard (audio events are silent).
import Foundation

public typealias CHHapticAudioResourceID = Int
public let CHHapticTimeImmediate: TimeInterval = 0

public struct CHHapticError: Error, CustomNSError, Hashable {
    public enum Code: Int, Sendable {
        case engineNotRunning = -4805, operationNotPermitted = -4806, engineStartTimeout = -4808, notSupported = -4809,
             serverInitFailed = -4810, serverInterrupted = -4811, invalidPatternPlayer = -4812, invalidPatternData = -4813,
             invalidPatternDictionary = -4814, invalidAudioSession = -4815, invalidEngineParameter = -4816,
             invalidParameterType = -4820, invalidEventType = -4821, invalidEventTime = -4822, invalidEventDuration = -4823,
             invalidAudioResource = -4824, resourceNotAvailable = -4825, badEventEntry = -4830, badParameterEntry = -4831,
             invalidTime = -4840, fileNotFound = -4851, insufficientPower = -4897, unknownError = -4898, memoryError = -4899
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { "com.apple.CoreHaptics" }
    public var errorCode: Int { code.rawValue }
    public static var engineNotRunning: Code { .engineNotRunning }
    public static var invalidPatternData: Code { .invalidPatternData }
    public static var invalidPatternDictionary: Code { .invalidPatternDictionary }
    public static var invalidEventTime: Code { .invalidEventTime }
    public static var invalidPatternPlayer: Code { .invalidPatternPlayer }
}

func _hapticLog(_ s: String) { FileHandle.standardError.write(("CoreHaptics: " + s + "\n").data(using: .utf8)!) }

// MARK: - parameters
public struct CHHapticEventParameter_ID: Hashable, RawRepresentable, Sendable { public var rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public class CHHapticEventParameter: NSObject {
    public typealias ID = CHHapticEventParameter_ID
    public let parameterID: ID
    public var value: Float
    public init(parameterID: ID, value: Float) { self.parameterID = parameterID; self.value = value }
}
extension CHHapticEventParameter_ID {
    public static let hapticIntensity = Self(rawValue: "HapticIntensity"), hapticSharpness = Self(rawValue: "HapticSharpness")
    public static let attackTime = Self(rawValue: "AttackTime"), decayTime = Self(rawValue: "DecayTime"), releaseTime = Self(rawValue: "ReleaseTime")
    public static let sustained = Self(rawValue: "Sustained"), audioVolume = Self(rawValue: "AudioVolume"), audioPitch = Self(rawValue: "AudioPitch")
    public static let audioPan = Self(rawValue: "AudioPan"), audioBrightness = Self(rawValue: "AudioBrightness")
}
public struct CHHapticDynamicParameter_ID: Hashable, RawRepresentable, Sendable { public var rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public class CHHapticDynamicParameter: NSObject {
    public typealias ID = CHHapticDynamicParameter_ID
    public let parameterID: ID
    public var value: Float
    public var relativeTime: TimeInterval
    public init(parameterID: ID, value: Float, relativeTime: TimeInterval) { self.parameterID = parameterID; self.value = value; self.relativeTime = relativeTime }
}
extension CHHapticDynamicParameter_ID {
    public static let hapticIntensityControl = Self(rawValue: "HapticIntensityControl"), hapticSharpnessControl = Self(rawValue: "HapticSharpnessControl")
    public static let hapticAttackTimeControl = Self(rawValue: "HapticAttackTimeControl"), hapticDecayTimeControl = Self(rawValue: "HapticDecayTimeControl")
    public static let hapticReleaseTimeControl = Self(rawValue: "HapticReleaseTimeControl"), audioVolumeControl = Self(rawValue: "AudioVolumeControl")
    public static let audioPanControl = Self(rawValue: "AudioPanControl"), audioBrightnessControl = Self(rawValue: "AudioBrightnessControl")
    public static let audioPitchControl = Self(rawValue: "AudioPitchControl"), audioAttackTimeControl = Self(rawValue: "AudioAttackTimeControl")
    public static let audioDecayTimeControl = Self(rawValue: "AudioDecayTimeControl"), audioReleaseTimeControl = Self(rawValue: "AudioReleaseTimeControl")
}
public class CHHapticParameterCurve: NSObject {
    public class ControlPoint: NSObject {
        public var relativeTime: TimeInterval
        public var value: Float
        public init(relativeTime: TimeInterval, value: Float) { self.relativeTime = relativeTime; self.value = value }
    }
    public let parameterID: CHHapticDynamicParameter.ID
    public var relativeTime: TimeInterval
    public let controlPoints: [ControlPoint]
    public init(parameterID: CHHapticDynamicParameter.ID, controlPoints: [ControlPoint], relativeTime: TimeInterval) {
        self.parameterID = parameterID; self.controlPoints = controlPoints; self.relativeTime = relativeTime
    }
}

// MARK: - events and patterns
public struct CHHapticEvent_EventType: Hashable, RawRepresentable, Sendable { public var rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public class CHHapticEvent: NSObject {
    public typealias EventType = CHHapticEvent_EventType
    public var type: EventType
    public var eventParameters: [CHHapticEventParameter]
    public var relativeTime: TimeInterval
    public var duration: TimeInterval
    public init(eventType: EventType, parameters: [CHHapticEventParameter], relativeTime: TimeInterval) {
        type = eventType; eventParameters = parameters; self.relativeTime = relativeTime
        duration = eventType == .hapticTransient ? 0.0 : 0.0
    }
    public init(eventType: EventType, parameters: [CHHapticEventParameter], relativeTime: TimeInterval, duration: TimeInterval) {
        type = eventType; eventParameters = parameters; self.relativeTime = relativeTime; self.duration = duration
    }
    public init(audioResourceID: CHHapticAudioResourceID, parameters: [CHHapticEventParameter], relativeTime: TimeInterval) {
        type = .audioCustom; eventParameters = parameters; self.relativeTime = relativeTime; duration = 0
    }
    public init(audioResourceID: CHHapticAudioResourceID, parameters: [CHHapticEventParameter], relativeTime: TimeInterval, duration: TimeInterval) {
        type = .audioCustom; eventParameters = parameters; self.relativeTime = relativeTime; self.duration = duration
    }
    /// how long the event lasts in a pattern (transients ~ 22 ms on device)
    var _span: TimeInterval { type == .hapticTransient ? 0.022 : duration }
}
extension CHHapticEvent_EventType {
    public static let hapticTransient = Self(rawValue: "HapticTransient"), hapticContinuous = Self(rawValue: "HapticContinuous")
    public static let audioContinuous = Self(rawValue: "AudioContinuous"), audioCustom = Self(rawValue: "AudioCustom")
}

public struct CHHapticPattern_Key: Hashable, RawRepresentable, Sendable { public var rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public class CHHapticPattern: NSObject {
    public typealias Key = CHHapticPattern_Key
    let events: [CHHapticEvent]
    let parameters: [CHHapticDynamicParameter]
    let curves: [CHHapticParameterCurve]
    public init(events: [CHHapticEvent], parameters: [CHHapticDynamicParameter]) throws {
        try CHHapticPattern._validate(events)
        self.events = events; self.parameters = parameters; curves = []
    }
    public init(events: [CHHapticEvent], parameterCurves: [CHHapticParameterCurve]) throws {
        try CHHapticPattern._validate(events)
        self.events = events; parameters = []; curves = parameterCurves
    }
    /// AHAP as a dictionary: ["Pattern": [["Event": [...]], ["Parameter": [...]], ["ParameterCurve": [...]]]]
    public convenience init(dictionary: [CHHapticPattern.Key: Any]) throws {
        guard let entries = dictionary[.pattern] as? [Any] else { throw CHHapticError(.invalidPatternDictionary) }
        var events: [CHHapticEvent] = [], curves: [CHHapticParameterCurve] = []
        func num(_ v: Any?) -> Double? { (v as? Double) ?? (v as? Int).map(Double.init) ?? (v as? Float).map(Double.init) ?? (v as? NSNumber)?.doubleValue }
        for case let entry as [AnyHashable: Any] in entries {
            if let e = entry[Key.event.rawValue] as? [AnyHashable: Any] ?? entry[Key.event] as? [AnyHashable: Any] {
                guard let t = e[Key.eventType.rawValue] as? String ?? (e[Key.eventType] as? CHHapticEvent.EventType)?.rawValue else { throw CHHapticError(.badEventEntry) }
                var ps: [CHHapticEventParameter] = []
                for case let p as [AnyHashable: Any] in (e[Key.eventParameters.rawValue] as? [Any] ?? e[Key.eventParameters] as? [Any] ?? []) {
                    guard let id = p[Key.parameterID.rawValue] as? String ?? (p[Key.parameterID] as? CHHapticEventParameter.ID)?.rawValue,
                          let v = num(p[Key.parameterValue.rawValue] ?? p[Key.parameterValue]) else { throw CHHapticError(.badParameterEntry) }
                    ps.append(CHHapticEventParameter(parameterID: .init(rawValue: id), value: Float(v)))
                }
                let time = num(e[Key.time.rawValue] ?? e[Key.time]) ?? 0
                let dur = num(e[Key.eventDuration.rawValue] ?? e[Key.eventDuration]) ?? 0
                events.append(CHHapticEvent(eventType: .init(rawValue: t), parameters: ps, relativeTime: time, duration: dur))
            } else if let c = entry[Key.parameterCurve.rawValue] as? [AnyHashable: Any] ?? entry[Key.parameterCurve] as? [AnyHashable: Any] {
                let id = c[Key.parameterID.rawValue] as? String ?? (c[Key.parameterID] as? CHHapticDynamicParameter.ID)?.rawValue ?? ""
                var pts: [CHHapticParameterCurve.ControlPoint] = []
                for case let p as [AnyHashable: Any] in (c[Key.parameterCurveControlPoints.rawValue] as? [Any] ?? c[Key.parameterCurveControlPoints] as? [Any] ?? []) {
                    pts.append(.init(relativeTime: num(p[Key.time.rawValue] ?? p[Key.time]) ?? 0, value: Float(num(p[Key.parameterValue.rawValue] ?? p[Key.parameterValue]) ?? 0)))
                }
                curves.append(CHHapticParameterCurve(parameterID: .init(rawValue: id), controlPoints: pts, relativeTime: num(c[Key.time.rawValue] ?? c[Key.time]) ?? 0))
            }
        }
        try self.init(events: events, parameterCurves: curves)
    }
    public convenience init(contentsOf url: URL) throws {
        guard let data = try? Data(contentsOf: url) else { throw CHHapticError(.fileNotFound) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CHHapticError(.invalidPatternData) }
        var d: [Key: Any] = [:]; for (k, v) in obj { d[Key(rawValue: k)] = v }
        try self.init(dictionary: d)
    }
    static func _validate(_ events: [CHHapticEvent]) throws {
        for e in events {
            if e.relativeTime < 0 { throw CHHapticError(.invalidEventTime) }
            if e.duration < 0 { throw CHHapticError(.invalidEventDuration) }
            if ![CHHapticEvent.EventType.hapticTransient, .hapticContinuous, .audioContinuous, .audioCustom].contains(e.type) { throw CHHapticError(.invalidEventType) }
        }
    }
    public var duration: TimeInterval { events.map { $0.relativeTime + $0._span }.max() ?? 0 }
    public func exportDictionary() throws -> [CHHapticPattern.Key: Any] {
        var out: [Any] = []
        for e in events {
            var ev: [String: Any] = [Key.time.rawValue: e.relativeTime, Key.eventType.rawValue: e.type.rawValue,
                                     Key.eventParameters.rawValue: e.eventParameters.map { [Key.parameterID.rawValue: $0.parameterID.rawValue, Key.parameterValue.rawValue: Double($0.value)] }]
            if e.type != .hapticTransient { ev[Key.eventDuration.rawValue] = e.duration }
            out.append([Key.event.rawValue: ev])
        }
        return [.version: 1.0, .pattern: out]
    }
}
extension CHHapticPattern_Key {
    public static let version = Self(rawValue: "Version"), pattern = Self(rawValue: "Pattern"), event = Self(rawValue: "Event")
    public static let eventType = Self(rawValue: "EventType"), time = Self(rawValue: "Time"), eventDuration = Self(rawValue: "EventDuration")
    public static let eventWaveformPath = Self(rawValue: "EventWaveformPath"), eventParameters = Self(rawValue: "EventParameters")
    public static let eventWaveformUseVolumeEnvelope = Self(rawValue: "EventWaveformUseVolumeEnvelope"), parameter = Self(rawValue: "Parameter")
    public static let parameterID = Self(rawValue: "ParameterID"), parameterValue = Self(rawValue: "ParameterValue")
    public static let parameterCurve = Self(rawValue: "ParameterCurve"), parameterCurveControlPoints = Self(rawValue: "ParameterCurveControlPoints")
}

// MARK: - capabilities
public protocol CHHapticParameterAttributes {
    var minValue: Float { get }
    var maxValue: Float { get }
    var defaultValue: Float { get }
}
struct _ParamAttrs: CHHapticParameterAttributes { var minValue: Float, maxValue: Float, defaultValue: Float }
public protocol CHHapticDeviceCapability {
    var supportsHaptics: Bool { get }
    var supportsAudio: Bool { get }
    func attributes(forEventParameter inParameter: CHHapticEvent.ParameterID, eventType type: CHHapticEvent.EventType) throws -> any CHHapticParameterAttributes
    func attributes(forDynamicParameter inParameter: CHHapticDynamicParameter.ID) throws -> any CHHapticParameterAttributes
}
extension CHHapticEvent { public typealias ParameterID = CHHapticEventParameter.ID }
struct _IsimHapticCapability: CHHapticDeviceCapability {
    var supportsHaptics: Bool { false }        // like the Simulator: no Taptic Engine
    var supportsAudio: Bool { false }
    func attributes(forEventParameter p: CHHapticEvent.ParameterID, eventType type: CHHapticEvent.EventType) throws -> any CHHapticParameterAttributes {
        switch p {
        case .audioPitch, .audioPan: return _ParamAttrs(minValue: -1, maxValue: 1, defaultValue: 0)
        case .sustained: return _ParamAttrs(minValue: 0, maxValue: 1, defaultValue: 1)
        case .hapticIntensity, .audioVolume: return _ParamAttrs(minValue: 0, maxValue: 1, defaultValue: 1)
        default: return _ParamAttrs(minValue: 0, maxValue: 1, defaultValue: 0.5)
        }
    }
    func attributes(forDynamicParameter p: CHHapticDynamicParameter.ID) throws -> any CHHapticParameterAttributes {
        _ParamAttrs(minValue: -1, maxValue: 1, defaultValue: 0)
    }
}

// MARK: - players
public protocol CHHapticPatternPlayer: AnyObject {
    func start(atTime time: TimeInterval) throws
    func stop(atTime time: TimeInterval) throws
    func sendParameters(_ parameters: [CHHapticDynamicParameter], atTime time: TimeInterval) throws
    func scheduleParameterCurve(_ parameterCurve: CHHapticParameterCurve, atTime time: TimeInterval) throws
    func cancel() throws
    var isMuted: Bool { get set }
}
public protocol CHHapticAdvancedPatternPlayer: CHHapticPatternPlayer {
    func pause(atTime time: TimeInterval) throws
    func resume(atTime time: TimeInterval) throws
    func seek(toOffset offsetTime: TimeInterval) throws
    var loopEnabled: Bool { get set }
    var loopEnd: TimeInterval { get set }
    var playbackRate: Float { get set }
    var completionHandler: CHHapticAdvancedPatternPlayerCompletionHandler? { get set }
}
public typealias CHHapticAdvancedPatternPlayerCompletionHandler = (Error?) -> Void

final class _IsimHapticPlayer: CHHapticAdvancedPatternPlayer {
    weak var engine: CHHapticEngine?
    let pattern: CHHapticPattern
    var isMuted = false, loopEnabled = false, loopEnd: TimeInterval = 0, playbackRate: Float = 1
    var completionHandler: CHHapticAdvancedPatternPlayerCompletionHandler?
    var offset: TimeInterval = 0          // pattern time when (re)started
    var startedAt: TimeInterval? = nil     // engine clock when running
    var generation = 0
    init(engine: CHHapticEngine, pattern: CHHapticPattern) { self.engine = engine; self.pattern = pattern }
    var length: TimeInterval { loopEnd > 0 ? loopEnd : pattern.duration }
    func at(_ time: TimeInterval, _ body: @escaping () -> Void) {
        let now = engine?.currentTime ?? 0
        let delay = time <= now ? 0 : time - now
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body)
    }
    func start(atTime time: TimeInterval) throws {
        guard let engine, engine._running else { throw CHHapticError(.engineNotRunning) }
        at(time) { [self] in
            offset = 0; begin()
            let ev = pattern.events
            _hapticLog("pattern started: \(ev.count) event(s) (\(ev.filter { $0.type == .hapticTransient }.count) transient, \(ev.filter { $0.type == .hapticContinuous }.count) continuous), duration \(String(format: "%.3f", pattern.duration)) s\(isMuted ? ", muted" : "") — not felt (no haptic hardware)")
        }
    }
    func begin() {
        generation += 1
        let g = generation
        startedAt = engine?.currentTime ?? 0
        engine?._active.insert(ObjectIdentifier(self))
        let remaining = max(0, length - offset) / Double(max(playbackRate, 0.01))
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [self] in
            guard g == generation, startedAt != nil else { return }
            if loopEnabled && length > 0 { offset = 0; begin(); return }
            finish(nil)
        }
    }
    func finish(_ error: Error?) {
        startedAt = nil; generation += 1
        completionHandler?(error)
        engine?._playerFinished(self, error)
    }
    func stop(atTime time: TimeInterval) throws { at(time) { [self] in if startedAt != nil { _hapticLog("pattern stopped"); finish(nil) } } }
    func cancel() throws { if startedAt != nil { finish(nil) } }
    func pause(atTime time: TimeInterval) throws {
        at(time) { [self] in
            guard let s = startedAt else { return }
            offset += ((engine?.currentTime ?? 0) - s) * Double(playbackRate); startedAt = nil; generation += 1
        }
    }
    func resume(atTime time: TimeInterval) throws { at(time) { [self] in if startedAt == nil { begin() } } }
    func seek(toOffset offsetTime: TimeInterval) throws {
        offset = max(0, offsetTime)
        if startedAt != nil { begin() }
    }
    func sendParameters(_ parameters: [CHHapticDynamicParameter], atTime time: TimeInterval) throws {
        guard engine?._running == true else { throw CHHapticError(.engineNotRunning) }
    }
    func scheduleParameterCurve(_ parameterCurve: CHHapticParameterCurve, atTime time: TimeInterval) throws {
        guard engine?._running == true else { throw CHHapticError(.engineNotRunning) }
    }
}

// MARK: - engine
public class CHHapticEngine: NSObject {
    public enum StoppedReason: Int, Sendable {
        case audioSessionInterrupt = 1, applicationSuspended = 2, idleTimeout = 3, notifyWhenFinished = 4, engineDestroyed = 5,
             gameControllerDisconnect = 6, systemError = -1
    }
    public enum FinishedAction: Int, Sendable { case stopEngine = 1, leaveEngineRunning = 2 }
    public typealias StoppedHandler = (StoppedReason) -> Void
    public typealias ResetHandler = () -> Void
    public typealias FinishedHandler = (Error?) -> FinishedAction
    public typealias CompletionHandler = (Error?) -> Void

    public class func capabilitiesForHardware() -> any CHHapticDeviceCapability { _IsimHapticCapability() }

    public var stoppedHandler: StoppedHandler = { _ in }
    public var resetHandler: ResetHandler = {}
    public var playsHapticsOnly = false
    public var playsAudioOnly = false
    public var isMutedForAudio = false
    public var isMutedForHaptics = false
    public var isAutoShutdownEnabled = false
    var _running = false
    var _startTime = Date()
    var _active = Set<ObjectIdentifier>()
    var _finished: FinishedHandler?
    var _resources: [CHHapticAudioResourceID: URL] = [:]

    public override init() { super.init() }
    public init(audioSession: AnyObject?) throws { super.init() }
    public var currentTime: TimeInterval { Date().timeIntervalSince(_startTime) }

    public func start() throws {
        if !_running { _running = true; _hapticLog("engine started (no haptic hardware: patterns are timed and logged, not felt)") }
    }
    public func start(completionHandler: CompletionHandler? = nil) {
        do { try start(); DispatchQueue.main.async { completionHandler?(nil) } } catch { DispatchQueue.main.async { completionHandler?(error) } }
    }
    public func startAndReturnError() throws { try start() }
    public func stop(completionHandler: CompletionHandler? = nil) {
        let was = _running
        _running = false; _active.removeAll()
        if was { _hapticLog("engine stopped") }
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    public func makePlayer(with pattern: CHHapticPattern) throws -> any CHHapticPatternPlayer { _IsimHapticPlayer(engine: self, pattern: pattern) }
    public func makeAdvancedPlayer(with pattern: CHHapticPattern) throws -> any CHHapticAdvancedPatternPlayer { _IsimHapticPlayer(engine: self, pattern: pattern) }
    public func notifyWhenPlayersFinished(finishedHandler: @escaping FinishedHandler) { _finished = finishedHandler; if _active.isEmpty { _allFinished(nil) } }
    func _playerFinished(_ p: _IsimHapticPlayer, _ error: Error?) {
        _active.remove(ObjectIdentifier(p))
        if _active.isEmpty { _allFinished(error) }
    }
    func _allFinished(_ error: Error?) {
        guard let h = _finished else { return }
        _finished = nil
        if h(error) == .stopEngine { stop(); stoppedHandler(.notifyWhenFinished) }
    }
    public func playPattern(from url: URL) throws {
        let p = try CHHapticPattern(contentsOf: url)
        try makePlayer(with: p).start(atTime: CHHapticTimeImmediate)
    }
    public func playPattern(from data: Data) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CHHapticError(.invalidPatternData) }
        var d: [CHHapticPattern.Key: Any] = [:]; for (k, v) in obj { d[.init(rawValue: k)] = v }
        try makePlayer(with: CHHapticPattern(dictionary: d)).start(atTime: CHHapticTimeImmediate)
    }
    public func registerAudioResource(_ resourceURL: URL, options: [AnyHashable: Any] = [:]) throws -> CHHapticAudioResourceID {
        guard FileManager.default.fileExists(atPath: resourceURL.path) else { throw CHHapticError(.fileNotFound) }
        let id = (_resources.keys.max() ?? 0) + 1
        _resources[id] = resourceURL
        return id
    }
    public func unregisterAudioResource(_ resourceID: CHHapticAudioResourceID) throws {
        guard _resources.removeValue(forKey: resourceID) != nil else { throw CHHapticError(.invalidAudioResource) }
    }
}
