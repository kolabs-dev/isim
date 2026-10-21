// HealthKit: anchored object queries (the samples added and deleted since an anchor), source queries, the Swift query
// descriptors (iOS 15.4) and background delivery. The device's Health database numbers its changes; an anchor is the
// last number a query saw, and a deletion leaves a tombstone (HKDeletedObject).
import Foundation

/// where an anchored object query left off; archive it to resume after a relaunch
@objc(HKQueryAnchor) open class HKQueryAnchor: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    let value: Int
    public init(fromValue value: Int) { self.value = value }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(value, forKey: "HKQueryAnchorValue") }
    public required init?(coder: NSCoder) { value = coder.decodeInteger(forKey: "HKQueryAnchorValue") }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? HKQueryAnchor)?.value == value }
    open override var hash: Int { value }
    open override var description: String { "<HKQueryAnchor: \(value)>" }
}

/// a sample that was deleted from the Health database
@objc(HKDeletedObject) open class HKDeletedObject: NSObject, @unchecked Sendable {
    open private(set) var uuid: UUID
    @objc open private(set) var metadata: [String: Any]?
    init(_ t: _HKTombstone) { uuid = UUID(uuidString: t.uuid) ?? UUID(); metadata = t.metadata }
    @objc(UUID) var _objc_UUID: UUID { uuid }
}

@objc(HKAnchoredObjectQuery) open class HKAnchoredObjectQuery: HKQuery, @unchecked Sendable {
    public typealias Handler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
    let limit: Int
    var anchor: HKQueryAnchor?
    let handler: Handler
    /// called with what changed after the initial results, while the query runs
    open var updateHandler: Handler?
    public init(type: HKSampleType, predicate: NSPredicate?, anchor: HKQueryAnchor?, limit: Int, resultsHandler handler: @escaping Handler) {
        self.limit = limit; self.anchor = anchor; self.handler = handler
        super.init(type, predicate)
    }
    /// the samples and deletions after the anchor, in the order they happened, and the anchor after them
    func changes() -> ([HKSample], [HKDeletedObject], HKQueryAnchor) {
        let after = anchor?.value
        let added = matching().filter { after == nil || $0._seq > after! }.sorted { $0._seq < $1._seq }
        let id = objectType?.identifier ?? ""
        // deletions are reported only from an anchor (a first query has nothing to forget)
        let gone = after == nil ? [] : _HKDB.deleted().filter { $0.type == id && $0.seq > after! && _HKDB.canSee($0.type, $0.bundle) }
        var events: [(Int, Any)] = added.map { ($0._seq, $0) } + gone.map { ($0.seq, $0) }
        events.sort { $0.0 < $1.0 }
        let limited = limit > 0 && events.count > limit
        if limited { events = Array(events.prefix(limit)) }
        let last = limited ? events.last!.0 : _HKDB.lastSeq(_HKDB.load(), _HKDB.deleted())
        return (events.compactMap { $0.1 as? HKSample }, events.compactMap { ($0.1 as? _HKTombstone).map(HKDeletedObject.init) },
                HKQueryAnchor(fromValue: max(last, after ?? 0)))
    }
    override func run() {
        let (a, d, next) = changes()
        anchor = next
        handler(self, a, d, next, nil)
        if updateHandler != nil { _HKObservers.add(self) }
    }
    func update() {
        guard running, let u = updateHandler else { return }
        let (a, d, next) = changes()
        if a.isEmpty && d.isEmpty { return }
        anchor = next
        u(self, a, d, next, nil)
    }
}

/// the apps (sources) that saved samples of a type the app may read
@objc(HKSourceQuery) open class HKSourceQuery: HKQuery, @unchecked Sendable {
    let handler: (HKSourceQuery, Set<HKSource>?, Error?) -> Void
    public init(sampleType: HKSampleType, samplePredicate objectPredicate: NSPredicate?, completionHandler: @escaping (HKSourceQuery, Set<HKSource>?, Error?) -> Void) {
        handler = completionHandler
        super.init(sampleType, objectPredicate)
    }
    override func run() { handler(self, Set(matching().map(\.sourceRevision.source)), nil) }
}

// MARK: - Swift query descriptors (iOS 15.4)

/// a query that returns one result
public protocol HKAsyncQuery {
    associatedtype Output
    func result(for healthStore: HKHealthStore) async throws -> Output
}
/// a query that returns a sequence of results (the first, then updates)
public protocol HKAsyncSequenceQuery {
    associatedtype Sequence: AsyncSequence
    func results(for healthStore: HKHealthStore) -> Sequence
}

/// a sample type with an optional predicate, for the query descriptors
public struct HKSamplePredicate<Sample: HKSample>: @unchecked Sendable {
    public let sampleType: HKSampleType
    public let nsPredicate: NSPredicate?
    init(_ type: HKSampleType, _ predicate: NSPredicate?) { sampleType = type; nsPredicate = predicate }
    public func evaluate(_ sample: Sample) -> Bool {
        sample.sampleType.identifier == sampleType.identifier && (nsPredicate?.evaluate(with: sample) ?? true)
    }
}
extension HKSamplePredicate where Sample == HKSample {
    public static func sample(type: HKSampleType, predicate: NSPredicate? = nil) -> HKSamplePredicate<HKSample> { .init(type, predicate) }
}
extension HKSamplePredicate where Sample == HKQuantitySample {
    public static func quantitySample(type: HKQuantityType, predicate: NSPredicate? = nil) -> HKSamplePredicate<HKQuantitySample> { .init(type, predicate) }
}
extension HKSamplePredicate where Sample == HKCategorySample {
    public static func categorySample(type: HKCategoryType, predicate: NSPredicate? = nil) -> HKSamplePredicate<HKCategorySample> { .init(type, predicate) }
}

/// reads samples: every predicate's matches, sorted, up to a limit
public struct HKSampleQueryDescriptor<Sample: HKSample>: HKAsyncQuery, @unchecked Sendable {
    public var predicates: [HKSamplePredicate<Sample>]
    public var sortDescriptors: [SortDescriptor<Sample>]
    public var limit: Int?
    public init(predicates: [HKSamplePredicate<Sample>], sortDescriptors: [SortDescriptor<Sample>], limit: Int? = nil) {
        self.predicates = predicates; self.sortDescriptors = sortDescriptors; self.limit = limit
    }
    public func result(for healthStore: HKHealthStore) async throws -> [Sample] {
        var out: [Sample] = []
        for p in predicates {
            let found: [HKSample] = try await withCheckedThrowingContinuation { k in
                healthStore.execute(HKSampleQuery(sampleType: p.sampleType, predicate: p.nsPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { k.resume(throwing: e) } else { k.resume(returning: s ?? []) }
                })
            }
            out += found.compactMap { $0 as? Sample }
        }
        if !sortDescriptors.isEmpty { out = out.sorted(using: sortDescriptors) }
        if let limit, limit > 0, out.count > limit { out = Array(out.prefix(limit)) }
        return out
    }
}

/// reads the samples added and deleted since an anchor; results(for:) keeps delivering changes
public struct HKAnchoredObjectQueryDescriptor<Sample: HKSample>: HKAsyncQuery, HKAsyncSequenceQuery, @unchecked Sendable {
    public var predicates: [HKSamplePredicate<Sample>]
    public var anchor: HKQueryAnchor?
    public var limit: Int?
    public init(predicates: [HKSamplePredicate<Sample>], anchor: HKQueryAnchor?, limit: Int? = nil) {
        self.predicates = predicates; self.anchor = anchor; self.limit = limit
    }
    public struct Result: @unchecked Sendable {
        public let addedSamples: [Sample]
        public let deletedObjects: [HKDeletedObject]
        public let newAnchor: HKQueryAnchor
    }
    /// one predicate's query (HealthKit runs one anchored query per sample type)
    func query(_ p: HKSamplePredicate<Sample>, _ anchor: HKQueryAnchor?, _ handler: @escaping HKAnchoredObjectQuery.Handler) -> HKAnchoredObjectQuery {
        HKAnchoredObjectQuery(type: p.sampleType, predicate: p.nsPredicate, anchor: anchor, limit: limit ?? HKObjectQueryNoLimit, resultsHandler: handler)
    }
    func result(_ a: [HKSample]?, _ d: [HKDeletedObject]?, _ next: HKQueryAnchor?) -> Result {
        Result(addedSamples: (a ?? []).compactMap { $0 as? Sample }, deletedObjects: d ?? [], newAnchor: next ?? HKQueryAnchor(fromValue: 0))
    }
    public func result(for healthStore: HKHealthStore) async throws -> Result {
        var added: [Sample] = [], deleted: [HKDeletedObject] = [], last = anchor?.value ?? 0
        for p in predicates {
            let r: Result = try await withCheckedThrowingContinuation { k in
                healthStore.execute(query(p, anchor) { _, a, d, next, e in
                    if let e { k.resume(throwing: e) } else { k.resume(returning: result(a, d, next)) }
                })
            }
            added += r.addedSamples; deleted += r.deletedObjects; last = max(last, r.newAnchor.value)
        }
        return Result(addedSamples: added, deletedObjects: deleted, newAnchor: HKQueryAnchor(fromValue: last))
    }
    public struct Results: AsyncSequence, @unchecked Sendable {
        public typealias Element = Result
        let stream: AsyncThrowingStream<Result, Error>
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<Result, Error>.AsyncIterator
            public mutating func next() async throws -> Result? { try await base.next() }
        }
        public func makeAsyncIterator() -> Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }
    /// the first result, then a result for each change while the sequence is iterated (stops the queries when it ends)
    public func results(for healthStore: HKHealthStore) -> Results {
        let preds = predicates, start = anchor
        let stream = AsyncThrowingStream<Result, Error> { cont in
            var queries: [HKAnchoredObjectQuery] = []
            for p in preds {
                let q = query(p, start) { _, a, d, next, e in
                    if let e { cont.finish(throwing: e) } else { cont.yield(result(a, d, next)) }
                }
                q.updateHandler = { _, a, d, next, e in
                    if let e { cont.finish(throwing: e) } else { cont.yield(result(a, d, next)) }
                }
                queries.append(q)
                healthStore.execute(q)
            }
            let running = queries
            cont.onTermination = { _ in for q in running { healthStore.stop(q) } }
        }
        return Results(stream: stream)
    }
}

/// reads the sources (apps) of the samples a predicate matches
public struct HKSourceQueryDescriptor<Sample: HKSample>: HKAsyncQuery, @unchecked Sendable {
    public var predicate: HKSamplePredicate<Sample>
    public init(predicate: HKSamplePredicate<Sample>) { self.predicate = predicate }
    public func result(for healthStore: HKHealthStore) async throws -> [HKSource] {
        let found: Set<HKSource> = try await withCheckedThrowingContinuation { k in
            healthStore.execute(HKSourceQuery(sampleType: predicate.sampleType, samplePredicate: predicate.nsPredicate) { _, s, e in
                if let e { k.resume(throwing: e) } else { k.resume(returning: s ?? []) }
            })
        }
        return found.sorted { $0.name < $1.name }
    }
}

/// the anchor value of a query that has not run (deprecated: pass a nil HKQueryAnchor)
public let HKAnchoredObjectQueryNoAnchor: Int32 = 0

// MARK: - Background delivery

@objc public enum HKUpdateFrequency: Int, Sendable { case immediate = 1, hourly, daily, weekly }

/// the types each app asked to be woken for (adapted: while it runs, its observer queries fire on changes; isim does not
/// launch a suspended app in the background)
enum _HKBackground {
    static var path: String { (_Privacy.deviceDir("Library/Health") as NSString).appendingPathComponent("background.json") }
    static func all() -> [String: [String: Int]] { _Privacy.readJSON([String: [String: Int]].self, path) ?? [:] }
    static func set(_ change: (inout [String: Int]) -> Void) {
        var a = all()
        var mine = a[_Privacy.bundleID] ?? [:]
        change(&mine)
        a[_Privacy.bundleID] = mine.isEmpty ? nil : mine
        _Privacy.writeJSON(a, path)
    }
}

extension HKHealthStore {
    public func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency, withCompletion completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            _HKBackground.set { $0[type.identifier] = frequency.rawValue }
            NSLog("isim HealthKit: %@ background delivery for %@ (%@)", _Privacy.appName, _HKNames.name(type.identifier),
                  ["", "immediate", "hourly", "daily", "weekly"][frequency.rawValue])
            _Privacy.reply { completion(true, nil) }
        }
    }
    public func disableBackgroundDelivery(for type: HKObjectType, withCompletion completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            _HKBackground.set { $0[type.identifier] = nil }
            _Privacy.reply { completion(true, nil) }
        }
    }
    public func disableAllBackgroundDelivery(completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            _HKBackground.set { $0.removeAll() }
            _Privacy.reply { completion(true, nil) }
        }
    }
    public func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            enableBackgroundDelivery(for: type, frequency: frequency) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    public func disableBackgroundDelivery(for type: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            disableBackgroundDelivery(for: type) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    public func disableAllBackgroundDelivery() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            disableAllBackgroundDelivery { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
}

// MARK: - Objective-C entry points

extension HKQueryAnchor {
    @objc(anchorFromValue:) class func _objc_anchor(_ v: UInt) -> HKQueryAnchor { HKQueryAnchor(fromValue: Int(v)) }
}
extension HKAnchoredObjectQuery {
    @objc(initWithType:predicate:anchor:limit:resultsHandler:)
    convenience init(_objcType t: HKSampleType, predicate: NSPredicate?, anchor: HKQueryAnchor?, limit: Int,
                     resultsHandler: @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, NSError?) -> Void) {
        self.init(type: t, predicate: predicate, anchor: anchor, limit: limit) { q, a, d, n, e in resultsHandler(q, a, d, n, e.map { $0 as NSError }) }
    }
    @objc(updateHandler) var _objc_updateHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, NSError?) -> Void)? {
        get { updateHandler.map { h in { q, a, d, n, e in h(q, a, d, n, e) } } }
        set { updateHandler = newValue.map { h in { q, a, d, n, e in h(q, a, d, n, e.map { $0 as NSError }) } } }
    }
}
extension HKSourceQuery {
    @objc(initWithSampleType:samplePredicate:completionHandler:)
    convenience init(_objcType t: HKSampleType, samplePredicate: NSPredicate?, completionHandler: @escaping (HKSourceQuery, Set<HKSource>?, NSError?) -> Void) {
        self.init(sampleType: t, samplePredicate: samplePredicate) { q, s, e in completionHandler(q, s, e.map { $0 as NSError }) }
    }
}
extension HKHealthStore {
    @objc(enableBackgroundDeliveryForType:frequency:withCompletion:)
    func _objc_enableBackground(_ t: HKObjectType, frequency: HKUpdateFrequency, completion: @escaping (Bool, NSError?) -> Void) {
        enableBackgroundDelivery(for: t, frequency: frequency) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(disableBackgroundDeliveryForType:withCompletion:)
    func _objc_disableBackground(_ t: HKObjectType, completion: @escaping (Bool, NSError?) -> Void) {
        disableBackgroundDelivery(for: t) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(disableAllBackgroundDeliveryWithCompletion:)
    func _objc_disableAllBackground(_ completion: @escaping (Bool, NSError?) -> Void) {
        disableAllBackgroundDelivery { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
}
