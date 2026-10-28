// isim SwiftData: observers (iOS 27) — ResultsObserver keeps a fetch's results (and their sections) up to date as the
// context or the store changes, for code outside SwiftUI (UIKit lists, view models); HistoryObserver counts the history
// transactions of the observed models; SectionedResults, ResultsSection and FetchResultsCollection hold the results.
// Observable: reading results, sections or eventCounter inside withObservationTracking (or a SwiftUI body) tracks them.
import Foundation
import Observation

/// A fetch's models, in order.
public struct FetchResultsCollection<Element: PersistentModel>: RandomAccessCollection {
    let models: [Element]
    init(_ models: [Element]) { self.models = models }
    public var startIndex: Int { 0 }
    public var endIndex: Int { models.count }
    public subscript(position: Int) -> Element { models[position] }
}

/// A section of results: the models whose section key path has this title.
public struct ResultsSection<Element: PersistentModel, SectionTitle: Hashable>: RandomAccessCollection, Identifiable, Equatable {
    public let title: SectionTitle
    let models: [Element]
    public var id: SectionTitle { title }
    public var startIndex: Int { 0 }
    public var endIndex: Int { models.count }
    public subscript(position: Int) -> Element { models[position] }
    public static func == (a: ResultsSection<Element, SectionTitle>, b: ResultsSection<Element, SectionTitle>) -> Bool {
        a.title == b.title && a.models.elementsEqual(b.models, by: ===)
    }
}

/// Results grouped into sections, in the order their first models come.
public struct SectionedResults<Element: PersistentModel, SectionTitle: Hashable>: RandomAccessCollection, Equatable {
    let sections: [ResultsSection<Element, SectionTitle>]
    init(_ models: [Element], title: (Element) -> SectionTitle) {
        var order: [SectionTitle] = [], groups: [SectionTitle: [Element]] = [:]
        for m in models {
            let t = title(m)
            if groups[t] == nil { order.append(t) }
            groups[t, default: []].append(m)
        }
        sections = order.map { ResultsSection(title: $0, models: groups[$0]!) }
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { sections.count }
    public subscript(position: Int) -> ResultsSection<Element, SectionTitle> { sections[position] }
    public var sectionTitles: [SectionTitle] { sections.map(\.title) }
    public func contains(sectionTitle: SectionTitle) -> Bool { sections.contains { $0.title == sectionTitle } }
    public func index(ofSectionTitled title: SectionTitle) -> Int? { sections.firstIndex { $0.title == title } }
    public subscript(sectionTitle title: SectionTitle) -> ResultsSection<Element, SectionTitle>? { sections.first { $0.title == title } }
    public static func == (a: SectionedResults<Element, SectionTitle>, b: SectionedResults<Element, SectionTitle>) -> Bool { a.sections == b.sections }
}

/// A fetch kept up to date: its results change when the context's models (or the store's rows) change.
@available(iOS 27.0, *)
public final class ResultsObserver<Element: PersistentModel, SectionTitle: Hashable>: Observable, @unchecked Sendable {
    public let modelContext: ModelContext
    private let registrar = ObservationRegistrar()
    private var _descriptor: FetchDescriptor<Element>
    private let title: ((Element) -> SectionTitle)?
    public private(set) var sectionBy: PartialKeyPath<Element>?
    private var stale = true
    private var cached: [Element] = []

    init(_ descriptor: FetchDescriptor<Element>, context: ModelContext, sectionBy: PartialKeyPath<Element>?, title: ((Element) -> SectionTitle)?) throws {
        _descriptor = descriptor; modelContext = context; self.sectionBy = sectionBy; self.title = title
        _ = try context.fetch(descriptor)
        let me = _Weak(self)
        context.store.observeCommits { _ in me.value?.invalidate() }
    }
    private func invalidate() {
        registrar.withMutation(of: self, keyPath: \.results) { stale = true }
    }
    private var models: [Element] {
        // the fetch reads the context's change count, so observing it tells when the results are out of date
        if stale {
            stale = false
            let me = _Weak(self)
            cached = withObservationTracking { (try? modelContext.fetch(_descriptor)) ?? [] } onChange: { me.value?.invalidate() }
        }
        return cached
    }

    public var fetchDescriptor: FetchDescriptor<Element> {
        get { registrar.access(self, keyPath: \.fetchDescriptor); return _descriptor }
        set { registrar.withMutation(of: self, keyPath: \.fetchDescriptor) { _descriptor = newValue }; invalidate() }
    }
    public var filterBy: Predicate<Element>? {
        get { fetchDescriptor.predicate }
        set { fetchDescriptor.predicate = newValue }
    }
    public var sortBy: [SortDescriptor<Element>] {
        get { fetchDescriptor.sortBy }
        set { fetchDescriptor.sortBy = newValue }
    }
    public var results: FetchResultsCollection<Element> {
        registrar.access(self, keyPath: \.results)
        return FetchResultsCollection(models)
    }
    /// the results by section (nil without a section key path)
    public var sections: SectionedResults<Element, SectionTitle>? {
        registrar.access(self, keyPath: \.results)
        return title.map { SectionedResults(models, title: $0) }
    }
    /// the model at [section, item] (section 0 without sections)
    public func element(at indexPath: IndexPath) -> Element? {
        guard indexPath.count == 2 else { return nil }
        let s = indexPath[0], i = indexPath[1]
        if let sections {
            guard s >= 0, s < sections.count, i >= 0, i < sections[s].count else { return nil }
            return sections[s][i]
        }
        let r = results
        return s == 0 && i >= 0 && i < r.count ? r[i] : nil
    }
    public func indexPath(for element: Element) -> IndexPath? {
        if let sections {
            for (s, sec) in sections.enumerated() { if let i = sec.models.firstIndex(where: { $0 === element }) { return IndexPath(indexes: [s, i]) } }
            return nil
        }
        return results.models.firstIndex { $0 === element }.map { IndexPath(indexes: [0, $0]) }
    }
}

@available(iOS 27.0, *)
extension ResultsObserver where SectionTitle == Never {
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, modelContext: ModelContext, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: modelContext, sectionBy: nil, title: nil)
    }
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, modelContainer: ModelContainer, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: _observerContext(modelContainer, isolation), sectionBy: nil, title: nil)
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, modelContext: ModelContext,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), context: modelContext, sectionBy: nil, title: nil)
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, modelContainer: ModelContainer,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), context: _observerContext(modelContainer, isolation), sectionBy: nil, title: nil)
    }
}

@available(iOS 27.0, *)
extension ResultsObserver where SectionTitle == String {
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, sectionBy: KeyPath<Element, String>, modelContext: ModelContext,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: modelContext, sectionBy: sectionBy, title: { $0[keyPath: sectionBy] })
    }
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, sectionBy: KeyPath<Element, String?>, modelContext: ModelContext,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: modelContext, sectionBy: sectionBy, title: { $0[keyPath: sectionBy] ?? "" })
    }
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, sectionBy: KeyPath<Element, String>, modelContainer: ModelContainer,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: _observerContext(modelContainer, isolation), sectionBy: sectionBy, title: { $0[keyPath: sectionBy] })
    }
    public convenience init(fetchDescriptor: FetchDescriptor<Element>, sectionBy: KeyPath<Element, String?>, modelContainer: ModelContainer,
                            isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor, context: _observerContext(modelContainer, isolation), sectionBy: sectionBy, title: { $0[keyPath: sectionBy] ?? "" })
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, sectionBy: KeyPath<Element, String>,
                            modelContext: ModelContext, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor: FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), sectionBy: sectionBy, modelContext: modelContext)
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, sectionBy: KeyPath<Element, String?>,
                            modelContext: ModelContext, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(fetchDescriptor: FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), sectionBy: sectionBy, modelContext: modelContext)
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, sectionBy: KeyPath<Element, String>,
                            modelContainer: ModelContainer, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), context: _observerContext(modelContainer, isolation),
                      sectionBy: sectionBy, title: { $0[keyPath: sectionBy] })
    }
    public convenience init(filterBy: Predicate<Element>? = nil, sortBy: [SortDescriptor<Element>]? = nil, sectionBy: KeyPath<Element, String?>,
                            modelContainer: ModelContainer, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(FetchDescriptor(predicate: filterBy, sortBy: sortBy ?? []), context: _observerContext(modelContainer, isolation),
                      sectionBy: sectionBy, title: { $0[keyPath: sectionBy] ?? "" })
    }
}

/// the context an observer made from a container uses: the main context on the main actor, its own otherwise
func _observerContext(_ container: ModelContainer, _ isolation: (any Actor)?) -> ModelContext {
    if isolation === MainActor.shared { return MainActor.assumeIsolated { _Weak(container.mainContext) }.value ?? ModelContext(container) }
    return ModelContext(container)
}

/// Counts the store's history transactions that change the observed models (by the given authors, when there are
/// any): eventCounter goes up by one for each, so observing it tells when to fetch the history since a token.
@available(iOS 27.0, *)
public final class HistoryObserver: Observable, @unchecked Sendable {
    public let modelContainer: ModelContainer
    public let observedModels: [any PersistentModel.Type]
    public let authors: Set<String>
    private let registrar = ObservationRegistrar()
    private var _events = 0
    private var tokens: [String: any HistoryToken]
    private let lock = NSLock()

    public var eventCounter: Int {
        get { registrar.access(self, keyPath: \.eventCounter); lock.lock(); defer { lock.unlock() }; return _events }
        set { registrar.withMutation(of: self, keyPath: \.eventCounter) { lock.lock(); _events = newValue; lock.unlock() } }
    }

    init(_ tokens: [String: any HistoryToken]?, _ models: [any PersistentModel.Type], _ authors: Set<String>, _ container: ModelContainer) throws {
        modelContainer = container; observedModels = models; self.authors = authors
        self.tokens = tokens ?? [:]
        // events since the tokens given; then follow what the store records next
        if tokens != nil { _events = relevant().count }
        if let last = latest().last { self.tokens[last.storeIdentifier] = last.token }
        let me = _Weak(self)
        container.store.observeCommits { _ in me.value?.check() }
    }
    public convenience init(historyTokens: [String: any HistoryToken]?, observedModels: [any PersistentModel.Type], authors: Set<String>,
                            modelContainer: ModelContainer, isolation: isolated (any Actor)? = #isolation) throws {
        try self.init(historyTokens, observedModels, authors, modelContainer)
    }

    private func latest() -> [DefaultHistoryTransaction] {
        (try? modelContainer.store.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>(), schema: modelContainer.schema)) ?? []
    }
    /// the transactions after the tokens that touch the observed models
    private func relevant() -> [DefaultHistoryTransaction] {
        let entities = Set(observedModels.map { _ModelInfo.of($0).entity })
        return latest().filter { t in
            if let mine = tokens[t.storeIdentifier] as? DefaultHistoryToken, t.token <= mine { return false }
            if !authors.isEmpty && !authors.contains(t.author ?? "") { return false }
            return entities.isEmpty || t.changes.contains { entities.contains($0.changedPersistentIdentifier.entityName) }
        }
    }
    private func check() {
        lock.lock()
        let new = relevant()
        if let last = latest().last { tokens[last.storeIdentifier] = last.token }
        lock.unlock()
        if !new.isEmpty { eventCounter += new.count }
    }
}
