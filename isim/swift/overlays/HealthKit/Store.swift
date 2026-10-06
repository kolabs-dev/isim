// HKHealthStore: authorization (the Health Access sheet), the local sample database and queries.
import UIKit

struct _HKRecord: Codable {
    var uuid: String, kind: String, type: String, start: Double, end: Double, value: Double
    var bundle: String, source: String, metadata: [String: String]?
}

enum _HKDB {
    static var path: String { (_Privacy.deviceDir("Library/Health") as NSString).appendingPathComponent("healthdb.json") }
    static func load() -> [_HKRecord] { _Privacy.readJSON([_HKRecord].self, path) ?? [] }
    static func save(_ r: [_HKRecord]) { _Privacy.writeJSON(r, path) }
    static func sample(_ r: _HKRecord) -> HKSample {
        let s: HKSample
        if r.kind == "c" {
            s = HKCategorySample(type: HKCategoryType(r.type), value: Int(r.value), start: Date(timeIntervalSince1970: r.start), end: Date(timeIntervalSince1970: r.end), metadata: r.metadata)
        } else {
            s = HKQuantitySample(type: HKQuantityType(r.type), quantity: HKQuantity(unit: _HKUnits.canonical(r.type), doubleValue: r.value),
                                 start: Date(timeIntervalSince1970: r.start), end: Date(timeIntervalSince1970: r.end), metadata: r.metadata)
        }
        s.uuid = UUID(uuidString: r.uuid) ?? UUID()
        s.sourceRevision = HKSourceRevision(source: HKSource(name: r.source, bundleIdentifier: r.bundle), version: nil)
        return s
    }
    static func record(_ o: HKObject) -> _HKRecord? {
        guard let s = o as? HKSample else { return nil }
        var md: [String: String]? = nil
        if let m = s.metadata { md = m.mapValues { "\($0)" } }
        if let q = s as? HKQuantitySample {
            let unit = _HKUnits.canonical(q.sampleType.identifier)
            guard q.quantity.is(compatibleWith: unit) else { return nil }
            return _HKRecord(uuid: s.uuid.uuidString, kind: "q", type: s.sampleType.identifier, start: s.startDate.timeIntervalSince1970,
                             end: s.endDate.timeIntervalSince1970, value: q.quantity.doubleValue(for: unit), bundle: _Privacy.bundleID, source: _Privacy.appName, metadata: md)
        }
        if let c = s as? HKCategorySample {
            return _HKRecord(uuid: s.uuid.uuidString, kind: "c", type: s.sampleType.identifier, start: s.startDate.timeIntervalSince1970,
                             end: s.endDate.timeIntervalSince1970, value: Double(c.value), bundle: _Privacy.bundleID, source: _Privacy.appName, metadata: md)
        }
        return nil
    }
    /// samples of `type` this app may see: all when read access was granted, otherwise only its own (iOS hides denial)
    static func visible(_ type: HKObjectType) -> [HKSample] {
        let canRead = _HKAuth.read(type.identifier) == true
        return load().filter { $0.type == type.identifier && (canRead || $0.bundle == _Privacy.bundleID) }.map(sample)
    }
}

enum _HKAuth {
    static func share(_ id: String) -> Bool? { _Privacy.stored("health.share." + id).map { $0 == 1 } }
    static func read(_ id: String) -> Bool? { _Privacy.stored("health.read." + id).map { $0 == 1 } }
    static func requested(_ id: String) -> Bool { _Privacy.stored("health.asked." + id) != nil }
}

public typealias HKObserverQueryCompletionHandler = () -> Void

open class HKHealthStore: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    /// true on iPhone (and on iPad from iPadOS 17), like the Simulator
    open class func isHealthDataAvailable() -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone || _Privacy.osMajor >= 17
    }
    open func supportsHealthRecords() -> Bool { false }

    // MARK: authorization
    open func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        if let s = _HKAuth.share(type.identifier) { return s ? .sharingAuthorized : .sharingDenied }
        return _HKAuth.requested(type.identifier) ? .sharingDenied : .notDetermined
    }
    open func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?, completion: @escaping (Bool, Error?) -> Void) {
        let share = (typesToShare ?? []).sorted { $0.identifier < $1.identifier }
        let read = (typesToRead ?? []).sorted { $0.identifier < $1.identifier }
        func finish(_ ok: Bool, _ e: Error?) { _Privacy.reply { completion(ok, e) } }
        if share.isEmpty && read.isEmpty { finish(false, HKError(.errorInvalidArgument, "Must request authorization for at least one data type")); return }
        if !share.isEmpty && _Privacy.usage("NSHealthUpdateUsageDescription", "HealthKit") == nil {
            finish(false, HKError(.errorInvalidArgument, "NSHealthUpdateUsageDescription must be set in the app's Info.plist in order to request write authorization.")); return
        }
        if !read.isEmpty && _Privacy.usage("NSHealthShareUsageDescription", "HealthKit") == nil {
            finish(false, HKError(.errorInvalidArgument, "NSHealthShareUsageDescription must be set in the app's Info.plist in order to request read authorization.")); return
        }
        let newShare = share.filter { _HKAuth.share($0.identifier) == nil }
        let newRead = read.filter { _HKAuth.read($0.identifier) == nil }
        if newShare.isEmpty && newRead.isEmpty { finish(true, nil); return }         // already answered: no sheet
        _Privacy.onMain {
            func record(_ w: [String: Bool], _ r: [String: Bool]) {
                for (id, on) in w { _Privacy.store("health.share." + id, on ? 1 : 0); _Privacy.store("health.asked." + id, 1) }
                for (id, on) in r { _Privacy.store("health.read." + id, on ? 1 : 0); _Privacy.store("health.asked." + id, 1) }
                NSLog("isim HealthKit: %@ write %@, read %@", _Privacy.appName,
                      w.filter { $0.value }.keys.sorted().map(_HKNames.name).joined(separator: ", "), r.filter { $0.value }.keys.sorted().map(_HKNames.name).joined(separator: ", "))
                finish(true, nil)
            }
            if let sc = _Privacy.scripted("HEALTH") {
                let on = sc == "allow" || sc == "1" || sc == "yes"
                record(Dictionary(uniqueKeysWithValues: newShare.map { ($0.identifier, on) }), Dictionary(uniqueKeysWithValues: newRead.map { ($0.identifier, on) }))
                return
            }
            guard let top = _Privacy.topController() else { finish(false, HKError(.errorAuthorizationNotDetermined)); return }
            let sheet = _HKAccessController(share: newShare.map(\.identifier), read: newRead.map(\.identifier),
                                            purpose: (!newShare.isEmpty ? _Privacy.usage("NSHealthUpdateUsageDescription", "HealthKit") : nil)
                                                ?? _Privacy.usage("NSHealthShareUsageDescription", "HealthKit") ?? "", done: record)
            let nav = UINavigationController(rootViewController: sheet)
            nav.isModalInPresentation = true
            top.present(nav, animated: true, completion: nil)
        }
    }
    open func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            requestAuthorization(toShare: typesToShare, read: typesToRead) { ok, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func getRequestStatusForAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>,
                                               completion: @escaping (HKAuthorizationRequestStatus, Error?) -> Void) {
        let pending = typesToShare.contains { _HKAuth.share($0.identifier) == nil } || typesToRead.contains { _HKAuth.read($0.identifier) == nil }
        _Privacy.reply { completion(pending ? .shouldRequest : .unnecessary, nil) }
    }
    open func statusForAuthorizationRequest(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        await withCheckedContinuation { k in getRequestStatusForAuthorization(toShare: typesToShare, read: typesToRead) { s, _ in k.resume(returning: s) } }
    }

    // MARK: saving
    open func save(_ object: HKObject, withCompletion completion: @escaping (Bool, Error?) -> Void) { save([object], withCompletion: completion) }
    open func save(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        var records: [_HKRecord] = []
        for o in objects {
            guard let s = o as? HKSample else { _Privacy.reply { completion(false, HKError(.errorInvalidArgument, "Unsupported object")) }; return }
            switch _HKAuth.share(s.sampleType.identifier) {
            case nil:
                _Privacy.reply { completion(false, HKError(.errorAuthorizationNotDetermined, "Authorization is not determined")) }; return
            case false?:
                _Privacy.reply { completion(false, HKError(.errorAuthorizationDenied, "Authorization is denied")) }; return
            default: break
            }
            guard let r = _HKDB.record(s) else {
                _Privacy.reply { completion(false, HKError(.errorInvalidArgument, "Quantity is not compatible with \(s.sampleType.identifier)")) }; return
            }
            records.append(r)
        }
        DispatchQueue.main.async {
            _HKDB.save(_HKDB.load() + records)
            for o in objects { o.sourceRevision = HKSourceRevision(source: .default(), version: nil) }
            _HKObservers.changed(Set(records.map(\.type)))
            _Privacy.reply { completion(true, nil) }
        }
    }
    open func save(_ object: HKObject) async throws { try await save([object]) }
    open func save(_ objects: [HKObject]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            save(objects) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func delete(_ object: HKObject, withCompletion completion: @escaping (Bool, Error?) -> Void) { delete([object], withCompletion: completion) }
    open func delete(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            let ids = Set(objects.map(\.uuid.uuidString))
            let all = _HKDB.load()
            // apps can delete only the samples they saved
            _HKDB.save(all.filter { !(ids.contains($0.uuid) && $0.bundle == _Privacy.bundleID) })
            _HKObservers.changed(Set(all.filter { ids.contains($0.uuid) }.map(\.type)))
            _Privacy.reply { completion(true, nil) }
        }
    }
    open func delete(_ object: HKObject) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in delete(object) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }

    // MARK: characteristics (not set on the simulated device)
    open func biologicalSex() throws -> HKBiologicalSexObject { HKBiologicalSexObject() }
    open func dateOfBirthComponents() throws -> DateComponents { throw HKError(.errorNoData, "No data available for the specified predicate.") }

    // MARK: queries
    open func execute(_ query: HKQuery) {
        query.store = self; query.running = true
        DispatchQueue.global().async { query.run() }
    }
    open func stop(_ query: HKQuery) { query.running = false; _HKObservers.remove(query) }
}

open class HKBiologicalSexObject: NSObject, @unchecked Sendable { open var biologicalSex: HKBiologicalSex { .notSet } }

// MARK: - Queries

open class HKQuery: NSObject, @unchecked Sendable {
    open var objectType: HKObjectType?
    open var sampleType: HKSampleType? { objectType as? HKSampleType }
    open var predicate: NSPredicate?
    weak var store: HKHealthStore?
    var running = false
    init(_ type: HKObjectType?, _ predicate: NSPredicate?) { objectType = type; self.predicate = predicate }
    func run() {}
    func matching() -> [HKSample] {
        guard let t = objectType else { return [] }
        var s = _HKDB.visible(t)
        if let p = predicate { s = s.filter { p.evaluate(with: $0) } }
        return s
    }

    public struct QueryOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let strictStartDate = QueryOptions(rawValue: 1)
        public static let strictEndDate = QueryOptions(rawValue: 2)
    }
    open class func predicateForSamples(withStart startDate: Date?, end endDate: Date?, options: QueryOptions = []) -> NSPredicate {
        NSPredicate { obj, _ in
            guard let s = obj as? HKSample else { return false }
            if let a = startDate { if options.contains(.strictStartDate) ? s.startDate < a : s.endDate < a { return false } }
            if let b = endDate { if options.contains(.strictEndDate) ? s.endDate > b : s.startDate >= b { return false } }
            return true
        }
    }
    open class func predicateForObjects(from source: HKSource) -> NSPredicate {
        NSPredicate { obj, _ in (obj as? HKObject)?.sourceRevision.source.bundleIdentifier == source.bundleIdentifier }
    }
    open class func predicateForObjects(from sources: Set<HKSource>) -> NSPredicate {
        let ids = Set(sources.map(\.bundleIdentifier))
        return NSPredicate { obj, _ in ids.contains((obj as? HKObject)?.sourceRevision.source.bundleIdentifier ?? "") }
    }
    open class func predicateForObject(with uuid: UUID) -> NSPredicate { NSPredicate { obj, _ in (obj as? HKObject)?.uuid == uuid } }
    open class func predicateForObjects(with uuids: Set<UUID>) -> NSPredicate { NSPredicate { obj, _ in uuids.contains((obj as? HKObject)?.uuid ?? UUID()) } }
    open class func predicateForObjects(withMetadataKey key: String) -> NSPredicate { NSPredicate { obj, _ in (obj as? HKObject)?.metadata?[key] != nil } }
    open class func predicateForCategorySamples(with op: NSComparisonPredicate.Operator, value: Int) -> NSPredicate {
        NSPredicate { obj, _ in
            guard let v = (obj as? HKCategorySample)?.value else { return false }
            switch op {
            case .equalTo: return v == value
            case .notEqualTo: return v != value
            case .lessThan: return v < value
            case .lessThanOrEqualTo: return v <= value
            case .greaterThan: return v > value
            case .greaterThanOrEqualTo: return v >= value
            default: return false
            }
        }
    }
}

open class HKSampleQuery: HKQuery, @unchecked Sendable {
    public let limit: Int
    public let sortDescriptors: [NSSortDescriptor]?
    let handler: (HKSampleQuery, [HKSample]?, Error?) -> Void
    public init(sampleType: HKSampleType, predicate: NSPredicate?, limit: Int, sortDescriptors: [NSSortDescriptor]?,
                resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.limit = limit; self.sortDescriptors = sortDescriptors; handler = resultsHandler
        super.init(sampleType, predicate)
    }
    override func run() {
        var s = matching()
        for d in (sortDescriptors ?? []).reversed() {
            let asc = d.ascending
            switch d.key {
            case HKSampleSortIdentifierEndDate?: s.sort { asc ? $0.endDate < $1.endDate : $0.endDate > $1.endDate }
            default: s.sort { asc ? $0.startDate < $1.startDate : $0.startDate > $1.startDate }
            }
        }
        if limit > 0 && s.count > limit { s = Array(s.prefix(limit)) }
        handler(self, s, nil)
    }
}

public struct HKStatisticsOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let separateBySource = HKStatisticsOptions(rawValue: 1)
    public static let discreteAverage = HKStatisticsOptions(rawValue: 2)
    public static let discreteMin = HKStatisticsOptions(rawValue: 4)
    public static let discreteMax = HKStatisticsOptions(rawValue: 8)
    public static let cumulativeSum = HKStatisticsOptions(rawValue: 16)
    public static let mostRecent = HKStatisticsOptions(rawValue: 32)
    public static let duration = HKStatisticsOptions(rawValue: 64)
}

open class HKStatistics: NSObject, @unchecked Sendable {
    public let quantityType: HKQuantityType
    public let startDate: Date
    public let endDate: Date
    let samples: [HKQuantitySample]
    let options: HKStatisticsOptions
    init(_ type: HKQuantityType, _ start: Date, _ end: Date, _ samples: [HKQuantitySample], _ options: HKStatisticsOptions) {
        quantityType = type; startDate = start; endDate = end; self.samples = samples; self.options = options
    }
    var unit: HKUnit { _HKUnits.canonical(quantityType.identifier) }
    func q(_ v: Double?) -> HKQuantity? { v.map { HKQuantity(unit: unit, doubleValue: $0) } }
    var values: [Double] { samples.map { $0.quantity.doubleValue(for: unit) } }
    open func sumQuantity() -> HKQuantity? { options.contains(.cumulativeSum) && !samples.isEmpty ? q(values.reduce(0, +)) : nil }
    open func averageQuantity() -> HKQuantity? { options.contains(.discreteAverage) && !samples.isEmpty ? q(values.reduce(0, +) / Double(values.count)) : nil }
    open func minimumQuantity() -> HKQuantity? { options.contains(.discreteMin) ? q(values.min()) : nil }
    open func maximumQuantity() -> HKQuantity? { options.contains(.discreteMax) ? q(values.max()) : nil }
    open func mostRecentQuantity() -> HKQuantity? { options.contains(.mostRecent) ? samples.max { $0.endDate < $1.endDate }?.quantity : nil }
    open func mostRecentQuantityDateInterval() -> DateInterval? {
        samples.max { $0.endDate < $1.endDate }.map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }
    open func sumQuantity(for source: HKSource) -> HKQuantity? {
        let v = samples.filter { $0.sourceRevision.source == source }.map { $0.quantity.doubleValue(for: unit) }
        return v.isEmpty ? nil : q(v.reduce(0, +))
    }
    open var sources: [HKSource]? { Array(Set(samples.map(\.sourceRevision.source))) }
}

open class HKStatisticsQuery: HKQuery, @unchecked Sendable {
    let options: HKStatisticsOptions
    let handler: (HKStatisticsQuery, HKStatistics?, Error?) -> Void
    public init(quantityType: HKQuantityType, quantitySamplePredicate: NSPredicate?, options: HKStatisticsOptions,
                completionHandler handler: @escaping (HKStatisticsQuery, HKStatistics?, Error?) -> Void) {
        self.options = options; self.handler = handler
        super.init(quantityType, quantitySamplePredicate)
    }
    override func run() {
        let s = matching().compactMap { $0 as? HKQuantitySample }
        guard !s.isEmpty else { handler(self, nil, HKError(.errorNoData, "No data available for the specified predicate.")); return }
        handler(self, HKStatistics(objectType as! HKQuantityType, s.map(\.startDate).min()!, s.map(\.endDate).max()!, s, options), nil)
    }
}

open class HKStatisticsCollection: NSObject, @unchecked Sendable {
    let items: [HKStatistics]
    init(_ items: [HKStatistics]) { self.items = items }
    open func statistics() -> [HKStatistics] { items.filter { !$0.samples.isEmpty } }
    open func statistics(for date: Date) -> HKStatistics? { items.first { $0.startDate <= date && date < $0.endDate } }
    open func enumerateStatistics(from startDate: Date, to endDate: Date, with block: (HKStatistics, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        for s in items where s.endDate > startDate && s.startDate <= endDate {
            block(s, &stop)
            if stop.boolValue { break }
        }
    }
    open func sources() -> Set<HKSource> { Set(items.flatMap { $0.sources ?? [] }) }
}

open class HKStatisticsCollectionQuery: HKQuery, @unchecked Sendable {
    public let anchorDate: Date
    public let options: HKStatisticsOptions
    public let intervalComponents: DateComponents
    open var initialResultsHandler: ((HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void)?
    open var statisticsUpdateHandler: ((HKStatisticsCollectionQuery, HKStatistics?, HKStatisticsCollection?, Error?) -> Void)?
    public init(quantityType: HKQuantityType, quantitySamplePredicate: NSPredicate?, options: HKStatisticsOptions, anchorDate: Date, intervalComponents: DateComponents) {
        self.anchorDate = anchorDate; self.options = options; self.intervalComponents = intervalComponents
        super.init(quantityType, quantitySamplePredicate)
    }
    func collection() -> HKStatisticsCollection {
        let s = matching().compactMap { $0 as? HKQuantitySample }
        guard let first = s.map(\.startDate).min(), let last = s.map(\.startDate).max() else { return HKStatisticsCollection([]) }
        let cal = Calendar.current
        func add(_ d: Date, _ n: Int) -> Date {
            var c = DateComponents()
            c.year = intervalComponents.year.map { $0 * n }; c.month = intervalComponents.month.map { $0 * n }
            c.day = intervalComponents.day.map { $0 * n }; c.hour = intervalComponents.hour.map { $0 * n }
            c.minute = intervalComponents.minute.map { $0 * n }; c.second = intervalComponents.second.map { $0 * n }
            c.weekOfYear = intervalComponents.weekOfYear.map { $0 * n }
            return cal.date(byAdding: c, to: d) ?? d
        }
        // find the bucket containing `first`, then walk forward
        var n = 0
        if first < anchorDate { while add(anchorDate, n) > first && n > -100_000 { n -= 1 } }
        else { while add(anchorDate, n + 1) <= first && n < 100_000 { n += 1 } }
        var items: [HKStatistics] = []
        while add(anchorDate, n) <= last {
            let a = add(anchorDate, n), b = add(anchorDate, n + 1)
            items.append(HKStatistics(objectType as! HKQuantityType, a, b, s.filter { $0.startDate >= a && $0.startDate < b }, options))
            n += 1
        }
        return HKStatisticsCollection(items)
    }
    override func run() {
        let c = collection()
        initialResultsHandler?(self, c, nil)
        if statisticsUpdateHandler != nil { _HKObservers.add(self) }
    }
    func update() { let c = collection(); statisticsUpdateHandler?(self, nil, c, nil) }
}

open class HKObserverQuery: HKQuery, @unchecked Sendable {
    let handler: (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void
    public init(sampleType: HKSampleType, predicate: NSPredicate?, updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        handler = updateHandler
        super.init(sampleType, predicate)
    }
    override func run() { _HKObservers.add(self); handler(self, {}, nil) }
}

enum _HKObservers {
    nonisolated(unsafe) static var queries: [HKQuery] = []
    static func add(_ q: HKQuery) { DispatchQueue.main.async { queries.append(q) } }
    static func remove(_ q: HKQuery) { DispatchQueue.main.async { queries.removeAll { $0 === q } } }
    static func changed(_ types: Set<String>) {
        for q in queries where q.running && types.contains(q.objectType?.identifier ?? "") {
            DispatchQueue.global().async {
                if let o = q as? HKObserverQuery { o.handler(o, {}, nil) }
                if let c = q as? HKStatisticsCollectionQuery { c.update() }
            }
        }
    }
}

// MARK: - The Health Access sheet

final class _HKAccessController: UITableViewController {
    let share: [String], read: [String], purpose: String
    var shareOn: [String: Bool] = [:], readOn: [String: Bool] = [:]
    let done: ([String: Bool], [String: Bool]) -> Void
    init(share: [String], read: [String], purpose: String, done: @escaping ([String: Bool], [String: Bool]) -> Void) {
        self.share = share; self.read = read; self.purpose = purpose; self.done = done
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }
    var allOn: Bool { share.allSatisfy { shareOn[$0] == true } && read.allSatisfy { readOn[$0] == true } }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Health Access"
        navigationItem.leftBarButtonItem = _Privacy.barButton("Don’t Allow", id: "health-deny", self, #selector(isimHKDeny))
        navigationItem.rightBarButtonItem = _Privacy.barButton("Allow", bold: true, id: "health-allow", self, #selector(isimHKAllow))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
    }
    @objc func isimHKDeny() { finish(false) }
    @objc func isimHKAllow() { finish(true) }
    func finish(_ allow: Bool) {
        var w: [String: Bool] = [:], r: [String: Bool] = [:]
        for id in share { w[id] = allow && shareOn[id] == true }
        for id in read { r[id] = allow && readOn[id] == true }
        _Privacy.dismiss(self) { self.done(w, r) }
    }
    @objc func isimHKToggle(_ sw: UISwitch) {
        let i = sw.tag
        if i >= 10_000 { readOn[read[i - 10_000]] = sw.isOn } else { shareOn[share[i]] = sw.isOn }
        tableView.reloadData()
    }

    var sections: [String] { ["intro"] + (share.isEmpty ? [] : ["write"]) + (read.isEmpty ? [] : ["read"]) }
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] { case "write": return share.count; case "read": return read.count; default: return 2 }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case "write": return "Allow “\(_Privacy.appName)” to Write"
        case "read": return "Allow “\(_Privacy.appName)” to Read"
        default: return nil
        }
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section] == "intro" ? "App Explanation: \(purpose)" : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let kind = sections[indexPath.section]
        if kind == "intro" {
            cell.textLabel?.numberOfLines = 0
            if indexPath.row == 0 {
                cell.textLabel?.text = "“\(_Privacy.appName)” would like to access and update your Health data in the categories below."
            } else {
                cell.textLabel?.text = allOn ? "Turn Off All" : "Turn On All"
                cell.textLabel?.textColor = .systemBlue
                cell.selectionStyle = .default
            }
            return cell
        }
        let id = kind == "write" ? share[indexPath.row] : read[indexPath.row]
        cell.textLabel?.text = _HKNames.name(id)
        let sw = UISwitch()
        sw.isOn = (kind == "write" ? shareOn[id] : readOn[id]) == true
        sw.tag = kind == "write" ? indexPath.row : 10_000 + indexPath.row
        sw.accessibilityIdentifier = "health-\(kind)-\(_HKNames.name(id).replacingOccurrences(of: " ", with: ""))"
        sw.addTarget(self, action: #selector(isimHKToggle(_:)), for: .valueChanged)
        cell.accessoryView = sw
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard sections[indexPath.section] == "intro", indexPath.row == 1 else { return }
        let on = !allOn
        for id in share { shareOn[id] = on }
        for id in read { readOn[id] = on }
        tableView.reloadData()
    }
}
