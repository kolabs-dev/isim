// isim Foundation: ProgressManager, ProgressReporter and Subprogress (swift-foundation's progress reporting for Swift
// concurrency). Adapted: counts, fraction (children's progress counted in the share their parent assigned them),
// completion, subprogresses (an unstarted subprogress completes its share when it goes away), setCounts; properties
// (the six built in and an app's own ProgressManager.Property types) whose summaries merge the values of a manager and
// its children (a finished child's summary is kept through the property's finalSummary); read-only reporters that a
// manager can assign a share to; and the bridge to Progress both ways (a Progress child of a manager, a subprogress of a
// Progress). Not provided: observation (ProgressManager is not @Observable in isim).

/// Progress that tasks report: a total count, a completed count, properties, and children started from subprogresses.
@available(iOS 26.0, *)
@dynamicMemberLookup
public final class ProgressManager: @unchecked Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    /// A value a progress manager reports, and how the values of a manager and its children add up into a summary.
    public protocol Property: SendableMetatype {
        associatedtype Value: Sendable
        associatedtype Summary: Sendable
        static var key: String { get }
        static var defaultValue: Value { get }
        static var defaultSummary: Summary { get }
        static func reduce(into summary: inout Summary, value: Value)
        static func merge(_ summary1: Summary, _ summary2: Summary) -> Summary
        static func finalSummary(_ parentSummary: Summary, _ childSummary: Summary) -> Summary
    }
    /// The built-in properties (`manager.totalFileCount`, `summary(of: \.totalByteCount)`, …); apps add their own in
    /// extensions.
    public enum Properties {
        public var totalFileCount: TotalFileCount.Type { TotalFileCount.self }
        public enum TotalFileCount: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.TotalFileCount" }
            public static var defaultValue: Int { 0 }
            public static var defaultSummary: Int { 0 }
            public static func reduce(into summary: inout Int, value: Int) { summary += value }
            public static func merge(_ a: Int, _ b: Int) -> Int { a + b }
            public static func finalSummary(_ parent: Int, _ child: Int) -> Int { parent + child }
        }
        public var completedFileCount: CompletedFileCount.Type { CompletedFileCount.self }
        public enum CompletedFileCount: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.CompletedFileCount" }
            public static var defaultValue: Int { 0 }
            public static var defaultSummary: Int { 0 }
            public static func reduce(into summary: inout Int, value: Int) { summary += value }
            public static func merge(_ a: Int, _ b: Int) -> Int { a + b }
            public static func finalSummary(_ parent: Int, _ child: Int) -> Int { parent + child }
        }
        public var totalByteCount: TotalByteCount.Type { TotalByteCount.self }
        public enum TotalByteCount: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.TotalByteCount" }
            public static var defaultValue: UInt64 { 0 }
            public static var defaultSummary: UInt64 { 0 }
            public static func reduce(into summary: inout UInt64, value: UInt64) { summary += value }
            public static func merge(_ a: UInt64, _ b: UInt64) -> UInt64 { a + b }
            public static func finalSummary(_ parent: UInt64, _ child: UInt64) -> UInt64 { parent + child }
        }
        public var completedByteCount: CompletedByteCount.Type { CompletedByteCount.self }
        public enum CompletedByteCount: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.CompletedByteCount" }
            public static var defaultValue: UInt64 { 0 }
            public static var defaultSummary: UInt64 { 0 }
            public static func reduce(into summary: inout UInt64, value: UInt64) { summary += value }
            public static func merge(_ a: UInt64, _ b: UInt64) -> UInt64 { a + b }
            public static func finalSummary(_ parent: UInt64, _ child: UInt64) -> UInt64 { parent + child }
        }
        /// bytes per second of each manager still running (a finished child's throughput is dropped)
        public var throughput: Throughput.Type { Throughput.self }
        public enum Throughput: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.Throughput" }
            public static var defaultValue: UInt64 { 0 }
            public static var defaultSummary: [UInt64] { [] }
            public static func reduce(into summary: inout [UInt64], value: UInt64) { summary.append(value) }
            public static func merge(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] { a + b }
            public static func finalSummary(_ parent: [UInt64], _ child: [UInt64]) -> [UInt64] { parent }
        }
        /// the longest estimate of the managers still running
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { EstimatedTimeRemaining.self }
        public enum EstimatedTimeRemaining: Sendable, Property {
            public static var key: String { "Foundation.ProgressManager.Properties.EstimatedTimeRemaining" }
            public static var defaultValue: Duration { .zero }
            public static var defaultSummary: Duration { .zero }
            public static func reduce(into summary: inout Duration, value: Duration) { summary = max(summary, value) }
            public static func merge(_ a: Duration, _ b: Duration) -> Duration { max(a, b) }
            public static func finalSummary(_ parent: Duration, _ child: Duration) -> Duration { parent }
        }
    }

    /// a child: a manager started from a subprogress or assigned through its reporter, or a Progress
    private enum Child {
        case manager(ProgressManager)
        case progress(Progress)
        var fraction: Double {
            switch self {
            case .manager(let m): return m.fractionCompleted
            case .progress(let p): return p.fractionCompleted
            }
        }
        var finished: Bool {
            switch self {
            case .manager(let m): return m.isFinished
            case .progress(let p): return p.isFinished
            }
        }
    }
    private let lock = NSLock()
    private var total: Int?, completed = 0
    private var children: [(child: Child, share: Int)] = []
    private var values: [String: any Sendable] = [:]
    /// the summaries of children that finished, per property key (merged with finalSummary)
    private var finishedSummaries: [String: [any Sendable]] = [:]
    /// called after this manager or a child changes (the Progress a subprogress of a Progress mirrors into)
    var onChange: (@Sendable () -> Void)?

    public init(totalCount: Int?) { total = totalCount }
    public var totalCount: Int? { lock.lock(); defer { lock.unlock() }; return total }
    public var completedCount: Int { lock.lock(); defer { lock.unlock() }; return completed }
    /// completed / total, with each running child adding its fraction of its share; 0 while indeterminate
    public var fractionCompleted: Double {
        lock.lock(); let t = total, c = completed, kids = children; lock.unlock()
        guard let t, t > 0 else { return 0 }
        let partial = kids.reduce(0.0) { $0 + (min(1, $1.child.fraction) * Double($1.share)) }
        return min(1, (Double(c) + partial) / Double(t))
    }
    public var isIndeterminate: Bool { totalCount == nil }
    public var isFinished: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let t = total else { return false }
        return completed >= t
    }
    /// A read-only view of this manager for other code to observe, or to assign a share of another manager to.
    public var reporter: ProgressReporter { ProgressReporter(manager: self) }
    /// the managers this one reports into (told when it changes and finishes)
    private var parents: [ProgressManager] = []
    private func changed() {
        if isFinished {
            lock.lock(); let ps = parents; parents = []; lock.unlock()
            for p in ps { p.childFinished(self) }
        } else {
            lock.lock(); let ps = parents; lock.unlock()
            for p in ps { p.changed() }
        }
        onChange?()
    }
    public func complete(count: Int) {
        lock.lock(); completed += count; lock.unlock()
        changed()
    }
    public func setCounts(_ counts: (_ completed: inout Int, _ total: inout Int?) -> Void) {
        lock.lock(); counts(&completed, &total); lock.unlock()
        changed()
    }
    /// A share of this progress for a child task to start.
    public func subprogress(assigningCount portionOfParentTotal: Int) -> Subprogress { Subprogress(parent: .manager(self), assignedCount: portionOfParentTotal) }
    /// Counts a Progress's fraction in a share of this manager (it completes the share when it finishes).
    public func assign(count portionOfParentTotal: Int, to progress: Progress) {
        if progress.isFinished { complete(count: portionOfParentTotal); return }
        lock.lock(); children.append((.progress(progress), portionOfParentTotal)); lock.unlock()
        let token = _ProgressFinishObserver.observe(progress) { [weak self] in self?.progressChanged(progress) }
        lock.lock(); progressObservers.append(token); lock.unlock()
    }
    /// Counts another manager's progress, seen through its reporter, in a share of this manager.
    public func assign(count portionOfParentTotal: Int, to reporter: ProgressReporter) {
        adopt(reporter.manager, share: portionOfParentTotal)
    }
    private var progressObservers: [NSObject] = []
    private func progressChanged(_ p: Progress) {
        guard p.isFinished else { changed(); return }
        lock.lock()
        if let i = children.firstIndex(where: { if case .progress(let q) = $0.child { return q === p }; return false }) {
            completed += children[i].share; children.remove(at: i)
        }
        lock.unlock()
        changed()
    }
    func adopt(_ child: ProgressManager, share: Int) {
        if child.isFinished { complete(count: share); return }
        lock.lock(); children.append((.manager(child), share)); lock.unlock()
        child.lock.lock(); child.parents.append(self); child.lock.unlock()
        changed()
    }
    /// a finished child's share counts as completed, and its summaries are kept
    func childFinished(_ child: ProgressManager) {
        let snapshot = child.allSummaries()
        lock.lock()
        if let i = children.firstIndex(where: { if case .manager(let m) = $0.child { return m === child }; return false }) {
            completed += children[i].share; children.remove(at: i)
            for (k, v) in snapshot { finishedSummaries[k, default: []].append(v) }
        }
        lock.unlock()
        changed()
    }

    // ---- properties ----
    /// the summaries of every property set on this manager or its children (kept when it finishes), by key
    private var propertyTypes: [String: any Property.Type] = [:]
    fileprivate func allSummaries() -> [String: any Sendable] {
        lock.lock(); let types = propertyTypes; lock.unlock()
        var out: [String: any Sendable] = [:]
        for (k, t) in types { out[k] = _summaryErased(t, self) }
        return out
    }
    fileprivate func value<P: Property>(_ p: P.Type) -> P.Value {
        lock.lock(); defer { lock.unlock() }
        return values[P.key] as? P.Value ?? P.defaultValue
    }
    fileprivate func setValue<P: Property>(_ p: P.Type, _ v: P.Value) {
        lock.lock(); values[P.key] = v; propertyTypes[P.key] = P.self; lock.unlock()
        var ancestors = parents
        while let a = ancestors.popLast() { a.lock.lock(); a.propertyTypes[P.key] = P.self; let more = a.parents; a.lock.unlock(); ancestors += more }
        changed()
    }
    /// this manager's value reduced into the property's summary, merged with its running children's and its finished
    /// children's summaries
    fileprivate func summaryValue<P: Property>(_ p: P.Type) -> P.Summary {
        lock.lock(); let own = values[P.key] as? P.Value; let kids = children; let done = finishedSummaries[P.key] ?? []; lock.unlock()
        var s = P.defaultSummary
        if let own { P.reduce(into: &s, value: own) }                   // (a value never set adds nothing)
        for k in kids { if case .manager(let m) = k.child { s = P.merge(s, m.summaryValue(P.self)) } }
        for d in done { if let d = d as? P.Summary { s = P.finalSummary(s, d) } }
        return s
    }

    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> Int where P.Value == Int, P.Summary == Int {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == [UInt64] {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> Duration where P.Value == Duration, P.Summary == Duration {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> String? where P.Value == String?, P.Summary == [String?] {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> URL? where P.Value == URL?, P.Summary == [URL?] {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public subscript<P: Property>(dynamicMember key: KeyPath<Properties, P.Type>) -> P.Value where P.Value == Double, P.Summary == Double {
        get { value(P.self) }
        set { setValue(P.self, newValue) }
    }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == Int, P.Summary == Int { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == UInt64, P.Summary == UInt64 { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == UInt64, P.Summary == [UInt64] { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == Duration, P.Summary == Duration { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == String?, P.Summary == [String?] { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == URL?, P.Summary == [URL?] { summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<Properties, P.Type>) -> P.Summary where P.Value == Double, P.Summary == Double { summaryValue(P.self) }

    public static func == (a: ProgressManager, b: ProgressManager) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    public var description: String { "ProgressManager(\(completedCount) of \(totalCount.map(String.init) ?? "?"), \(fractionCompleted))" }
    public var debugDescription: String {
        lock.lock(); let n = children.count; lock.unlock()
        return "<ProgressManager \(Unmanaged.passUnretained(self).toOpaque()): completed \(completedCount), total \(totalCount.map(String.init) ?? "nil"), fraction \(fractionCompleted), children \(n)>"
    }
}

@available(iOS 26.0, *)
private func _summaryErased<P: ProgressManager.Property>(_ p: P.Type, _ m: ProgressManager) -> any Sendable { m.summaryValue(p) }

/// Observes a Progress's completion (KVO on fractionCompleted) for a manager it was assigned to.
private final class _ProgressFinishObserver: NSObject, @unchecked Sendable {
    let progress: Progress
    let handler: () -> Void
    init(progress: Progress, handler: @escaping () -> Void) { self.progress = progress; self.handler = handler; super.init() }
    static func observe(_ p: Progress, _ handler: @escaping () -> Void) -> NSObject {
        let o = _ProgressFinishObserver(progress: p, handler: handler)
        p.addObserver(o, forKeyPath: "fractionCompleted", options: [], context: nil)
        return o
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) { handler() }
    deinit { progress.removeObserver(self, forKeyPath: "fractionCompleted") }
}

/// A read-only view of a ProgressManager: its counts, fraction and property summaries.
@available(iOS 26.0, *)
@dynamicMemberLookup
public final class ProgressReporter: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public typealias Property = ProgressManager.Property
    let manager: ProgressManager
    init(manager: ProgressManager) { self.manager = manager }
    public var totalCount: Int? { manager.totalCount }
    public var completedCount: Int { manager.completedCount }
    public var fractionCompleted: Double { manager.fractionCompleted }
    public var isIndeterminate: Bool { manager.isIndeterminate }
    public var isFinished: Bool { manager.isFinished }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P.Value == Int, P.Summary == Int { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == [UInt64] { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P.Value == Duration, P.Summary == Duration { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String? where P.Value == String?, P.Summary == [String?] { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> URL? where P.Value == URL?, P.Summary == [URL?] { manager.value(P.self) }
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value where P.Value == Double, P.Summary == Double { manager.value(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P.Value == Int, P.Summary == Int { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [UInt64] where P.Value == UInt64, P.Summary == [UInt64] { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P.Value == Duration, P.Summary == Duration { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [String?] where P.Value == String?, P.Summary == [String?] { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [URL?] where P.Value == URL?, P.Summary == [URL?] { manager.summaryValue(P.self) }
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Double where P.Value == Double, P.Summary == Double { manager.summaryValue(P.self) }
    public var description: String { "ProgressReporter(\(manager.description))" }
    public var debugDescription: String { "<ProgressReporter of \(manager.debugDescription)>" }
}

/// The share of a parent's progress a child task reports into: `start(totalCount:)` makes its ProgressManager.
@available(iOS 26.0, *)
public struct Subprogress: ~Copyable, Sendable {
    enum Parent: @unchecked Sendable {
        case manager(ProgressManager)
        case progress(Progress)
    }
    let parent: Parent
    let assignedCount: Int
    var started = false
    init(parent: Parent, assignedCount: Int) { self.parent = parent; self.assignedCount = assignedCount }
    public consuming func start(totalCount: Int?) -> ProgressManager {
        started = true
        let child = ProgressManager(totalCount: totalCount)
        switch parent {
        case .manager(let p): p.adopt(child, share: assignedCount)
        case .progress(let p):
            /* a Progress child, its completed units following the manager's fraction */
            let mirror = Progress(totalUnitCount: 1_000_000, parent: p, pendingUnitCount: Int64(assignedCount))
            let box = _UncheckedProgress(progress: mirror)
            child.onChange = { [weak child] in
                guard let child else { return }
                box.progress.completedUnitCount = child.isFinished ? 1_000_000 : Int64(child.fractionCompleted * 1_000_000)
            }
        }
        return child
    }
    deinit {
        guard !started else { return }
        switch parent {
        case .manager(let p): p.complete(count: assignedCount)
        case .progress(let p): p.completedUnitCount += Int64(assignedCount)
        }
    }
}
private struct _UncheckedProgress: @unchecked Sendable { let progress: Progress }

@available(iOS 26.0, *)
extension Progress {
    /// A share of this progress (its pending unit count) for a child task to report into with a ProgressManager.
    public func subprogress(assigningCount count: Int) -> Subprogress { Subprogress(parent: .progress(self), assignedCount: count) }
}
