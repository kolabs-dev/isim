// isim Foundation: ProgressManager and Subprogress (swift-foundation's progress reporting for Swift concurrency,
// iOS 26) — a subset: counts, fraction (children's progress counted in the share their parent assigned them),
// completion, subprogresses (an unstarted subprogress completes its share when it goes away), setCounts.
// Not provided: ProgressReporter, custom properties, the bridge to Progress.

/// Progress that tasks report: a total count, a completed count, and children started from subprogresses.
@available(iOS 26.0, *)
public final class ProgressManager: @unchecked Sendable, Hashable, CustomStringConvertible {
    private let lock = NSLock()
    private var total: Int?, completed = 0
    private var children: [(manager: ProgressManager, share: Int)] = []
    public init(totalCount: Int?) { total = totalCount }
    public var totalCount: Int? { lock.lock(); defer { lock.unlock() }; return total }
    public var completedCount: Int { lock.lock(); defer { lock.unlock() }; return completed }
    /// completed / total, with each running child adding its fraction of its share; 0 while indeterminate
    public var fractionCompleted: Double {
        lock.lock(); let t = total, c = completed, kids = children; lock.unlock()
        guard let t, t > 0 else { return 0 }
        let partial = kids.reduce(0.0) { $0 + (min(1, $1.manager.fractionCompleted) * Double($1.share)) }
        return min(1, (Double(c) + partial) / Double(t))
    }
    public var isIndeterminate: Bool { totalCount == nil }
    public var isFinished: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let t = total else { return false }
        return completed >= t
    }
    /// the manager whose subprogress started this one (told when this one finishes)
    weak var parentManager: ProgressManager?
    public func complete(count: Int) {
        lock.lock(); completed += count; lock.unlock()
        if isFinished, let p = parentManager { parentManager = nil; p.childFinished(self) }
    }
    public func setCounts(_ counts: (_ completed: inout Int, _ total: inout Int?) -> Void) {
        lock.lock(); counts(&completed, &total); lock.unlock()
    }
    /// A share of this progress for a child task to start.
    public func subprogress(assigningCount portionOfParentTotal: Int) -> Subprogress { Subprogress(parent: self, assignedCount: portionOfParentTotal) }
    func adopt(_ child: ProgressManager, share: Int) { lock.lock(); children.append((child, share)); lock.unlock() }
    /// a finished child's share counts as completed
    func childFinished(_ child: ProgressManager) {
        lock.lock()
        if let i = children.firstIndex(where: { $0.manager === child }) { completed += children[i].share; children.remove(at: i) }
        lock.unlock()
    }
    public static func == (a: ProgressManager, b: ProgressManager) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    public var description: String { "ProgressManager(\(completedCount) of \(totalCount.map(String.init) ?? "?"), \(fractionCompleted))" }
}

/// The share of a parent's progress a child task reports into: `start(totalCount:)` makes its ProgressManager.
@available(iOS 26.0, *)
public struct Subprogress: ~Copyable, Sendable {
    let parent: ProgressManager
    let assignedCount: Int
    var started = false
    init(parent: ProgressManager, assignedCount: Int) { self.parent = parent; self.assignedCount = assignedCount }
    public consuming func start(totalCount: Int?) -> ProgressManager {
        started = true
        let child = ProgressManager(totalCount: totalCount)
        child.parentManager = parent
        parent.adopt(child, share: assignedCount)
        return child
    }
    deinit { if !started { parent.complete(count: assignedCount) } }
}
