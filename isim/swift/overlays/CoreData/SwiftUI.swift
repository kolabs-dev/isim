// isim CoreData + SwiftUI: \.managedObjectContext, @FetchRequest / FetchedResults and @SectionedFetchRequest /
// SectionedFetchResults. Results re-fetch when the context reports changes (ObjectsDidChange, incl. merges and
// saves of child contexts) and the view re-renders, with the request's animation.
import SwiftUI
import Foundation

struct _ManagedObjectContextKey: EnvironmentKey {
    @MainActor static let fallback = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    static var defaultValue: NSManagedObjectContext { MainActor.assumeIsolated { fallback } }
}
extension EnvironmentValues {
    public var managedObjectContext: NSManagedObjectContext {
        get { self[_ManagedObjectContextKey.self] }
        set { self[_ManagedObjectContextKey.self] = newValue }
    }
}

/// Per-view-position fetch state shared by @FetchRequest and @SectionedFetchRequest.
@MainActor final class _IsimFetchBox<Result: NSFetchRequestResult> {
    var request: NSFetchRequest<Result>
    var animation: Animation?
    weak var context: NSManagedObjectContext?
    var results: [Result] = []
    var dirty = true
    var observer: NSObjectProtocol?
    var invalidate: (@Sendable () -> Void)?
    var configured = false            // the configuration was changed through the projected value
    init(_ request: NSFetchRequest<Result>, _ animation: Animation?) { self.request = request; self.animation = animation }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func attach(_ ctx: NSManagedObjectContext) {
        if context !== ctx {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            context = ctx
            dirty = true
            observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: ctx, queue: nil) { [weak self] (_: Notification) in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.dirty = true
                    if let a = self.animation { withAnimation(a) { self.invalidate?() } } else { self.invalidate?() }
                }
            }
        }
    }
    func refresh() {
        guard dirty, let ctx = context else { return }
        dirty = false
        do { results = try ctx.fetch(request) }
        catch { print("isim CoreData: @FetchRequest fetch failed: \(error)"); results = [] }
    }
}

func _isimRequest<Result: NSFetchRequestResult>(_ type: Result.Type, entity: NSEntityDescription?) -> NSFetchRequest<Result> {
    if let entity {
        let r = NSFetchRequest<Result>(entityName: entity.name ?? "")
        r.entity = entity
        return r
    }
    if let mo = Result.self as? NSManagedObject.Type { return mo.fetchRequest() as! NSFetchRequest<Result> }
    fatalError("@FetchRequest: \(Result.self) is not an NSManagedObject subclass; pass entity: or fetchRequest:")
}
/// What identifies a request across view re-creations (NSPredicate / NSSortDescriptor compare by identity).
func _isimSignature<R>(_ r: NSFetchRequest<R>) -> String {
    let sorts = (r.sortDescriptors ?? []).map { "\($0.key ?? "<cmp>"):\($0.ascending)" }.joined(separator: ",")
    return "\(r.entityName ?? "")|\(r.predicate?.predicateFormat ?? "")|\(sorts)|\(r.fetchLimit)|\(r.fetchOffset)"
}
/// Swift SortDescriptor -> NSSortDescriptor (compared in memory with the Swift comparator).
func _isimSortDescriptors<Result>(_ sds: [SortDescriptor<Result>]) -> [NSSortDescriptor] {
    sds.map { sd in
        NSSortDescriptor(key: nil, ascending: true) { a, b in
            guard let x = a as? Result, let y = b as? Result else { return .orderedSame }
            return sd.compare(x, y)
        }
    }
}

@propertyWrapper
public struct FetchRequest<Result: NSFetchRequestResult>: DynamicProperty, _IsimInstallableDynamicProperty {
    public struct Configuration {
        public var nsSortDescriptors: [NSSortDescriptor]
        public var nsPredicate: NSPredicate?
    }
    let initial: NSFetchRequest<Result>
    let animation: Animation?
    final class Holder { var box: AnyObject? }
    let holder = Holder()
    var box: _IsimFetchBox<Result>? { holder.box as? _IsimFetchBox<Result> }

    public init(fetchRequest: NSFetchRequest<Result>, animation: Animation? = nil) { initial = fetchRequest; self.animation = animation }
    public init(fetchRequest: NSFetchRequest<Result>, transaction: Transaction) { initial = fetchRequest; animation = nil }
    public init(entity: NSEntityDescription, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        let r = _isimRequest(Result.self, entity: entity)
        r.sortDescriptors = sortDescriptors; r.predicate = predicate
        self.init(fetchRequest: r, animation: animation)
    }
    public init(sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        let r = _isimRequest(Result.self, entity: nil)
        r.sortDescriptors = sortDescriptors; r.predicate = predicate
        self.init(fetchRequest: r, animation: animation)
    }
    public init(sortDescriptors: [SortDescriptor<Result>], predicate: NSPredicate? = nil, animation: Animation? = nil) where Result: NSManagedObject {
        self.init(sortDescriptors: _isimSortDescriptors(sortDescriptors), predicate: predicate, animation: animation)
    }

    @MainActor public func _isimInstall(_ site: _IsimDynamicPropertySite) {
        let b = site.storage { _IsimFetchBox(initial, animation) }
        if !b.configured && _isimSignature(b.request) != _isimSignature(initial) {
            b.request = initial; b.dirty = true            // the view was re-created with a different request
        }
        b.animation = animation
        b.invalidate = site.invalidate
        b.attach(site.environment.managedObjectContext)
        b.refresh()
        holder.box = b
    }

    public var wrappedValue: FetchedResults<Result> {
        MainActor.assumeIsolated {
            guard let b = box else { return FetchedResults(results: [], request: initial, configure: nil) }
            b.refresh()
            let pv = projectedValue
            return FetchedResults(results: b.results, request: b.request, configure: { pv.wrappedValue = $0 })
        }
    }
    public var projectedValue: Binding<Configuration> {
        let h = holder, initial = initial
        return Binding(get: {
            MainActor.assumeIsolated {
                let r = (h.box as? _IsimFetchBox<Result>)?.request ?? initial
                return Configuration(nsSortDescriptors: r.sortDescriptors ?? [], nsPredicate: r.predicate)
            }
        }, set: { c in
            MainActor.assumeIsolated {
                guard let b = h.box as? _IsimFetchBox<Result> else { return }
                let r = b.request.copy() as! NSFetchRequest<Result>
                r.sortDescriptors = c.nsSortDescriptors; r.predicate = c.nsPredicate
                b.request = r; b.configured = true; b.dirty = true
                b.invalidate?()
            }
        })
    }
}
extension FetchRequest.Configuration where Result: NSManagedObject {
    /// Swift sort descriptors (setting them sorts in memory with the Swift comparators).
    public var sortDescriptors: [SortDescriptor<Result>] {
        get { [] }
        set { nsSortDescriptors = _isimSortDescriptors(newValue) }
    }
}

public struct FetchedResults<Result: NSFetchRequestResult>: RandomAccessCollection {
    let results: [Result]
    let request: NSFetchRequest<Result>
    let configure: ((FetchRequest<Result>.Configuration) -> Void)?
    public var startIndex: Int { 0 }
    public var endIndex: Int { results.count }
    public subscript(position: Int) -> Result { results[position] }
    /// Setting it re-fetches with the new predicate (like iOS 15).
    public var nsPredicate: NSPredicate? {
        get { request.predicate }
        nonmutating set { configure?(.init(nsSortDescriptors: request.sortDescriptors ?? [], nsPredicate: newValue)) }
    }
    public var nsSortDescriptors: [NSSortDescriptor] {
        get { request.sortDescriptors ?? [] }
        nonmutating set { configure?(.init(nsSortDescriptors: newValue, nsPredicate: request.predicate)) }
    }
}
extension FetchedResults where Result: NSManagedObject {
    public var sortDescriptors: [SortDescriptor<Result>] {
        get { [] }
        nonmutating set { nsSortDescriptors = _isimSortDescriptors(newValue) }
    }
}

// MARK: - Sectioned

@propertyWrapper
public struct SectionedFetchRequest<SectionIdentifier: Hashable, Result: NSFetchRequestResult>: DynamicProperty, _IsimInstallableDynamicProperty {
    let inner: FetchRequest<Result>
    let sectionIdentifier: KeyPath<Result, SectionIdentifier>
    public init(fetchRequest: NSFetchRequest<Result>, sectionIdentifier: KeyPath<Result, SectionIdentifier>, animation: Animation? = nil) {
        inner = FetchRequest(fetchRequest: fetchRequest, animation: animation); self.sectionIdentifier = sectionIdentifier
    }
    public init(entity: NSEntityDescription, sectionIdentifier: KeyPath<Result, SectionIdentifier>, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        inner = FetchRequest(entity: entity, sortDescriptors: sortDescriptors, predicate: predicate, animation: animation); self.sectionIdentifier = sectionIdentifier
    }
    public init(sectionIdentifier: KeyPath<Result, SectionIdentifier>, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        inner = FetchRequest(sortDescriptors: sortDescriptors, predicate: predicate, animation: animation); self.sectionIdentifier = sectionIdentifier
    }
    public init(sectionIdentifier: KeyPath<Result, SectionIdentifier>, sortDescriptors: [SortDescriptor<Result>], predicate: NSPredicate? = nil, animation: Animation? = nil) where Result: NSManagedObject {
        inner = FetchRequest(sortDescriptors: sortDescriptors, predicate: predicate, animation: animation); self.sectionIdentifier = sectionIdentifier
    }
    @MainActor public func _isimInstall(_ site: _IsimDynamicPropertySite) { inner._isimInstall(site) }
    public var wrappedValue: SectionedFetchResults<SectionIdentifier, Result> {
        let all = inner.wrappedValue
        var sections: [SectionedFetchResults<SectionIdentifier, Result>.Section] = []
        for r in all {
            let id = r[keyPath: sectionIdentifier]
            if let last = sections.last, last.id == id { sections[sections.count - 1].elements.append(r) }
            else { sections.append(.init(id: id, elements: [r])) }
        }
        return SectionedFetchResults(sections: sections, request: all.request, configure: all.configure)
    }
    public var projectedValue: Binding<FetchRequest<Result>.Configuration> { inner.projectedValue }
}

public struct SectionedFetchResults<SectionIdentifier: Hashable, Result: NSFetchRequestResult>: RandomAccessCollection {
    public struct Section: Identifiable, RandomAccessCollection {
        public let id: SectionIdentifier
        var elements: [Result]
        public var startIndex: Int { 0 }
        public var endIndex: Int { elements.count }
        public subscript(position: Int) -> Result { elements[position] }
    }
    let sections: [Section]
    let request: NSFetchRequest<Result>
    let configure: ((FetchRequest<Result>.Configuration) -> Void)?
    public var startIndex: Int { 0 }
    public var endIndex: Int { sections.count }
    public subscript(position: Int) -> Section { sections[position] }
    public var nsPredicate: NSPredicate? {
        get { request.predicate }
        nonmutating set { configure?(.init(nsSortDescriptors: request.sortDescriptors ?? [], nsPredicate: newValue)) }
    }
    public var nsSortDescriptors: [NSSortDescriptor] {
        get { request.sortDescriptors ?? [] }
        nonmutating set { configure?(.init(nsSortDescriptors: newValue, nsPredicate: request.predicate)) }
    }
}
