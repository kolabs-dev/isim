// isim AppIntents: intent donations (IntentDonationManager) and relevant intents (RelevantIntentManager).
// Donations are kept with the app's other donated interactions (Library/isim/Interactions.plist in its container, as
// INInteraction.donate keeps them): the Shortcuts app lists them as the app's Siri Suggestions, newest first, and runs
// them with the donated parameter values (the system's intent request, System.swift). Relevant intents are kept
// (Library/isim/RelevantIntents.plist); isim's home screen has no Smart Stack to rank them (stub).
import Foundation
import CoreLocation

// MARK: - donations

public struct IntentDonationIdentifier: Hashable, Sendable, Codable, CustomStringConvertible {
    let uuid: UUID
    init(_ uuid: UUID = UUID()) { self.uuid = uuid }
    public var description: String { uuid.uuidString }
}

public struct IntentDonationMatchingPredicate: Sendable {
    enum Kind: @unchecked Sendable {
        case donations([IntentDonationIdentifier]), entities([EntityIdentifier]), intentType(any AppIntent.Type, EntityIdentifier?)
    }
    let kind: Kind
    public static func donationIdentifier(_ identifier: IntentDonationIdentifier) -> Self { Self(kind: .donations([identifier])) }
    public static func donationIdentifiers(_ identifiers: [IntentDonationIdentifier]) -> Self { Self(kind: .donations(identifiers)) }
    public static func entityIdentifier(_ identifier: EntityIdentifier) -> Self { Self(kind: .entities([identifier])) }
    public static func entityIdentifiers(_ identifiers: [EntityIdentifier]) -> Self { Self(kind: .entities(identifiers)) }
    public static func intentType(_ type: any AppIntent.Type, entityIdentifier: EntityIdentifier? = nil) -> Self {
        Self(kind: .intentType(type, entityIdentifier))
    }
    func matches(_ e: [String: Any]) -> Bool {
        let entities = e["entities"] as? [String] ?? []
        switch kind {
        case .donations(let ids): return ids.contains { $0.description == e["identifier"] as? String }
        case .entities(let ids): return ids.contains { entities.contains($0.description) }
        case .intentType(let t, let entity):
            return e["appIntent"] as? String == _isimTypeName(t) && (entity.map { entities.contains($0.description) } ?? true)
        }
    }
}

public struct IntentDonationManager: Sendable {
    public static let shared = IntentDonationManager()

    static var path: String { (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/Interactions.plist") }
    static let lock = NSLock()
    static func load() -> [[String: Any]] { (NSDictionary(contentsOfFile: path)?["interactions"] as? [[String: Any]]) ?? [] }
    static func store(_ list: [[String: Any]]) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        (["interactions": list] as NSDictionary).write(toFile: path, atomically: true)
    }

    /// a parameter value as the system's intent request takes it (entities: their identifier; enums: the raw value)
    static func serialize(_ v: Any) -> (String, EntityIdentifier?)? {
        if let o = v as? _IsimOptional { return o._isimUnwrapped.flatMap(serialize) }
        if let e = v as? any AppEntity { return ("\(e.id)", _entityIdentifier(e)) }
        if let e = v as? any AppEnum { return (e.rawValue, nil) }
        if let b = v as? Bool { return (b ? "true" : "false", nil) }
        if let d = v as? Date { return (ISO8601DateFormatter().string(from: d), nil) }
        if let u = v as? URL { return (u.absoluteString, nil) }
        if let f = v as? IntentFile { return (f.fileURL?.path ?? f.filename, nil) }
        return (_IsimValues.describe(v), nil)
    }

    func record<I: AppIntent>(_ intent: I, result: (any IntentResult)?) -> IntentDonationIdentifier {
        let id = IntentDonationIdentifier()
        var params: [String: String] = [:], entities: [String] = [], shown: [String] = []
        for (name, p) in _IsimReflection.parameters(of: intent) where p._isimHasValue {
            guard let v = p._isimCurrent, let (s, entity) = Self.serialize(v) else { continue }
            params[name] = s
            if let entity { entities.append(entity.description) }
            shown.append(_IsimValues.describe(v))
        }
        let title = I.title.description + (shown.isEmpty ? "" : " · " + shown.joined(separator: ", "))
        var e: [String: Any] = ["identifier": id.description, "appIntent": _isimTypeName(I.self), "title": title, "params": params,
                                "entities": entities, "date": Date(), "app": Bundle.main.bundleIdentifier ?? ""]
        if let d = (result as? any _ResultCarrying)?._dialog?.text { e["dialog"] = d }
        Self.lock.lock()
        var list = Self.load()
        list.append(e)
        while list.count > 100 { list.removeFirst() }
        Self.store(list)
        Self.lock.unlock()
        NSLog("isim AppIntents: donated “%@” (%@)", title, id.description)
        return id
    }

    @discardableResult
    public func donate<I: AppIntent>(intent: I) -> IntentDonationIdentifier { record(intent, result: nil) }
    @discardableResult
    public func donate<I: AppIntent>(intent: I) async throws -> IntentDonationIdentifier { record(intent, result: nil) }
    @discardableResult
    public func donate<I: AppIntent, R: IntentResult>(intent: I, result: R) -> IntentDonationIdentifier { record(intent, result: result) }
    @discardableResult
    public func donate<I: AppIntent, R: IntentResult>(intent: I, result: R) async throws -> IntentDonationIdentifier { record(intent, result: result) }

    @discardableResult
    public func deleteDonations(matching predicate: IntentDonationMatchingPredicate) async throws -> [IntentDonationIdentifier] {
        Self.lock.lock(); defer { Self.lock.unlock() }
        var deleted: [IntentDonationIdentifier] = [], kept: [[String: Any]] = []
        for e in Self.load() {
            if e["appIntent"] != nil, predicate.matches(e), let s = e["identifier"] as? String, let u = UUID(uuidString: s) {
                deleted.append(IntentDonationIdentifier(u))
            } else { kept.append(e) }
        }
        Self.store(kept)
        NSLog("isim AppIntents: deleted %d donation(s)", deleted.count)
        return deleted
    }
}

func _entityIdentifier<E: AppEntity>(_ e: E) -> EntityIdentifier { EntityIdentifier(for: e) }

// MARK: - relevance

/// when an intent is relevant (WidgetKit's Smart Stack): dates, places, sleep, fitness, headphones
public struct RelevantContext: Sendable {
    public struct DateKind: Hashable, Sendable {
        let name: String
        public static var `default`: DateKind { DateKind(name: "default") }
        public static var informational: DateKind { DateKind(name: "informational") }
        public static var scheduled: DateKind { DateKind(name: "scheduled") }
    }
    public struct SleepCondition: Hashable, Sendable {
        let name: String
        public static var bedtime: SleepCondition { SleepCondition(name: "bedtime") }
        public static var wakeup: SleepCondition { SleepCondition(name: "wakeup") }
    }
    public struct FitnessCondition: Hashable, Sendable {
        let name: String
        public static var activityRingsIncomplete: FitnessCondition { FitnessCondition(name: "activityRingsIncomplete") }
        public static var workoutActive: FitnessCondition { FitnessCondition(name: "workoutActive") }
    }
    public struct HeadphonesCondition: Hashable, Sendable {
        let name: String
        public static var connected: HeadphonesCondition { HeadphonesCondition(name: "connected") }
    }
    public struct InferredLocation: Hashable, Sendable {
        let name: String
        public static var home: InferredLocation { InferredLocation(name: "home") }
        public static var work: InferredLocation { InferredLocation(name: "work") }
        public static var school: InferredLocation { InferredLocation(name: "school") }
        public static var commute: InferredLocation { InferredLocation(name: "commute") }
    }
    let summary: String
    public static func date(_ date: Date) -> RelevantContext { .date(date, kind: .default) }
    public static func date(_ date: Date, kind: DateKind) -> RelevantContext { RelevantContext(summary: "date \(date) \(kind.name)") }
    public static func date(from: Date, to: Date) -> RelevantContext { RelevantContext(summary: "date \(from) to \(to)") }
    public static func date(interval: DateInterval, kind: DateKind) -> RelevantContext {
        RelevantContext(summary: "date \(interval.start) to \(interval.end) \(kind.name)")
    }
    public static func date(range: ClosedRange<Date>, kind: DateKind) -> RelevantContext {
        RelevantContext(summary: "date \(range.lowerBound) to \(range.upperBound) \(kind.name)")
    }
    public static func location(_ region: CLRegion) -> RelevantContext { RelevantContext(summary: "location \(region.identifier)") }
    public static func location(inferred: InferredLocation) -> RelevantContext { RelevantContext(summary: "location \(inferred.name)") }
    public static func sleep(_ condition: SleepCondition) -> RelevantContext { RelevantContext(summary: "sleep \(condition.name)") }
    public static func fitness(_ condition: FitnessCondition) -> RelevantContext { RelevantContext(summary: "fitness \(condition.name)") }
    public static func hardware(headphones: HeadphonesCondition) -> RelevantContext { RelevantContext(summary: "headphones \(headphones.name)") }
}

public struct RelevantIntent: @unchecked Sendable {
    let intent: any AppIntent
    let widgetKind: String
    let relevance: RelevantContext
    public init<IntentType: WidgetConfigurationIntent>(_ intent: IntentType, widgetKind: String, relevance: RelevantContext) {
        self.intent = intent; self.widgetKind = widgetKind; self.relevance = relevance
    }
}

public final class RelevantIntentManager: @unchecked Sendable {
    public static let shared = RelevantIntentManager()
    /// replaces the app's relevant intents
    public func updateRelevantIntents(_ relevantIntents: [RelevantIntent]) async throws {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/RelevantIntents.plist")
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let list = relevantIntents.map { ["intent": _isimTypeName(type(of: $0.intent)), "widgetKind": $0.widgetKind, "relevance": $0.relevance.summary] }
        (["relevantIntents": list] as NSDictionary).write(toFile: path, atomically: true)
        NSLog("isim AppIntents: %d relevant intent(s) for %@ (no Smart Stack on isim)", relevantIntents.count,
              Set(relevantIntents.map(\.widgetKind)).sorted().joined(separator: ", "))
    }
}
