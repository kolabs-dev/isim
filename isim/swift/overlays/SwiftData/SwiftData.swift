// SwiftData on isim: an adapted, process-local model container. @Model is a real compiler macro; models live in their
// container's main context (identity-preserving instances, insertion order) for the life of the process, without
// Apple's on-disk store, schema migration or CloudKit backend. Fetches apply the descriptor's predicate, sort, offset
// and limit; contexts are Observable, so SwiftUI views that read @Query (or fetch) refresh after insert, delete, save
// and rollback. Xcode's SwiftData app template (Schema, ModelConfiguration(schema:isStoredInMemoryOnly:),
// ModelContainer(for:configurations:), @Query(sort:order:), .modelContainer(for:inMemory:)) runs as written.
@_exported import Foundation
import Combine
import Observation
import SwiftUI

@attached(member, names: named(_$persistentModelID), named(persistentModelID))
@attached(extension, conformances: PersistentModel)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "ModelMacro")

@attached(peer)
public macro Attribute(_ options: Schema.Attribute.Option..., originalName: String? = nil, hashModifier: String? = nil) = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")
@attached(peer)
public macro Relationship(_ options: Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule = .nullify,
                          minimumModelCount: Int = 0, maximumModelCount: Int = 0, originalName: String? = nil,
                          inverse: AnyKeyPath? = nil, hashModifier: String? = nil) = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")
@attached(peer)
public macro Transient() = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")

public struct PersistentIdentifier: Hashable, Codable, Sendable, CustomStringConvertible, Comparable {
    private let value: UUID
    private let order: UInt64
    nonisolated(unsafe) private static var next: UInt64 = 0
    private static let lock = NSLock()
    public init() {
        value = UUID()
        PersistentIdentifier.lock.lock()
        PersistentIdentifier.next += 1
        order = PersistentIdentifier.next
        PersistentIdentifier.lock.unlock()
    }
    public var description: String { value.uuidString }
    public static func < (a: PersistentIdentifier, b: PersistentIdentifier) -> Bool { a.order < b.order }
}

/// A model class (@Model): identified by its persistent identifier, hashed and compared by identity, observable.
public protocol PersistentModel: AnyObject, Observable, Hashable, Identifiable {
    var persistentModelID: PersistentIdentifier { get }
}
extension PersistentModel {
    public var id: PersistentIdentifier { persistentModelID }
    public static func == (a: Self, b: Self) -> Bool { a === b }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    /// the context the model was inserted into (nil before insert or after delete)
    @MainActor public var modelContext: ModelContext? { ModelContext._owner(of: self) }
}

/// The model types of a container, and the options of their properties.
public final class Schema: Hashable, @unchecked Sendable {
    public enum Attribute {
        public struct Option: OptionSet, Sendable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let unique = Option(rawValue: 1)
            public static let externalStorage = Option(rawValue: 2)
            public static let encrypt = Option(rawValue: 4)
            public static let preserveValueOnDeletion = Option(rawValue: 8)
        }
    }
    public enum Relationship {
        public struct Option: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let unique = Option(rawValue: 1) }
        public enum DeleteRule: Sendable { case noAction, nullify, cascade, deny }
    }
    public struct Version: Hashable, Sendable, CustomStringConvertible {
        public let major: Int, minor: Int, patch: Int
        public init(_ major: Int, _ minor: Int, _ patch: Int) { self.major = major; self.minor = minor; self.patch = patch }
        public var description: String { "\(major).\(minor).\(patch)" }
    }
    /// the names of the schema's model types
    public let entityNames: [String]
    let types: [any PersistentModel.Type]
    public let version: Version
    public init(_ types: [any PersistentModel.Type], version: Version = Version(1, 0, 0)) {
        self.types = types; self.version = version
        entityNames = types.map { String(describing: $0) }
    }
    public convenience init(_ types: any PersistentModel.Type..., version: Version = Version(1, 0, 0)) { self.init(types, version: version) }
    public convenience init() { self.init([any PersistentModel.Type]()) }
    public static func == (a: Schema, b: Schema) -> Bool { a.entityNames == b.entityNames && a.version == b.version }
    public func hash(into h: inout Hasher) { h.combine(entityNames); h.combine(version) }
}

public struct ModelConfiguration: Hashable, Sendable {
    public var name: String
    public var schema: Schema?
    public var isStoredInMemoryOnly: Bool
    public var allowsSave: Bool
    public init(_ name: String? = nil, schema: Schema? = nil, isStoredInMemoryOnly: Bool = false, allowsSave: Bool = true) {
        self.name = name ?? "default"; self.schema = schema; self.isStoredInMemoryOnly = isStoredInMemoryOnly; self.allowsSave = allowsSave
    }
    public init(schema: Schema? = nil, isStoredInMemoryOnly: Bool = false, allowsSave: Bool = true) {
        self.init(nil, schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly, allowsSave: allowsSave)
    }
    public init(isStoredInMemoryOnly: Bool) { self.init(nil, schema: nil, isStoredInMemoryOnly: isStoredInMemoryOnly) }
    /// where Apple's store would be (isim keeps models in memory)
    public var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return isStoredInMemoryOnly ? URL(fileURLWithPath: "/dev/null") : dir.appendingPathComponent("\(name).store")
    }
}

public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortBy: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public var includePendingChanges = true
    public init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) { self.predicate = predicate; self.sortBy = sortBy }
}

@MainActor open class ModelContext: ObservableObject, Observable {
    nonisolated(unsafe) static var owners: [ObjectIdentifier: (model: AnyObject, context: ModelContext)] = [:]
    static func _owner(of model: AnyObject) -> ModelContext? { owners[ObjectIdentifier(model)]?.context }

    public let container: ModelContainer
    private var objects: [any PersistentModel] = []        // insertion order
    private var inserted: [ObjectIdentifier] = []
    private var deleted: [any PersistentModel] = []
    private let registrar = ObservationRegistrar()
    private var _changes = 0
    /// read inside fetch (SwiftUI's observation of @Query); bumped by every change
    private var changes: Int {
        get { registrar.access(self, keyPath: \.changes); return _changes }
        set { registrar.withMutation(of: self, keyPath: \.changes) { _changes = newValue } }
    }
    open private(set) var hasChanges = false
    public var autosaveEnabled = true
    public init(_ container: ModelContainer) { self.container = container }

    open func insert<T: PersistentModel>(_ model: T) {
        guard !objects.contains(where: { $0 === model }) else { return }
        objects.append(model)
        inserted.append(ObjectIdentifier(model))
        ModelContext.owners[ObjectIdentifier(model)] = (model, self)
        changed()
    }
    open func delete<T: PersistentModel>(_ model: T) {
        guard let i = objects.firstIndex(where: { $0 === model }) else { return }
        deleted.append(objects.remove(at: i))
        ModelContext.owners[ObjectIdentifier(model)] = nil
        changed()
    }
    /// deletes the models of a type that match a predicate (all of them without one)
    open func delete<T: PersistentModel>(model: T.Type, where predicate: Predicate<T>? = nil, includeSubclasses: Bool = true) throws {
        for m in try fetch(FetchDescriptor<T>(predicate: predicate)) { delete(m) }
    }
    open func save() throws { inserted = []; deleted = []; hasChanges = false; changes += 1 }
    /// undoes the changes since the last save: inserted models leave, deleted ones come back
    open func rollback() {
        objects.removeAll { m in inserted.contains(ObjectIdentifier(m)) }
        for m in deleted { objects.append(m); ModelContext.owners[ObjectIdentifier(m)] = (m, self) }
        objects.sort { $0.persistentModelID < $1.persistentModelID }
        inserted = []; deleted = []; hasChanges = false; changes += 1
    }
    open func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T: PersistentModel {
        _ = changes
        var result = objects.compactMap { $0 as? T }
        if let p = descriptor.predicate { result = try result.filter { try p.evaluate($0) } }
        if !descriptor.sortBy.isEmpty { result.sort(using: descriptor.sortBy) }
        if let o = descriptor.fetchOffset, o > 0 { result = Array(result.dropFirst(o)) }
        if let limit = descriptor.fetchLimit { result = Array(result.prefix(limit)) }
        return result
    }
    open func fetchCount<T>(_ descriptor: FetchDescriptor<T>) throws -> Int where T: PersistentModel { try fetch(descriptor).count }
    open func fetchIdentifiers<T>(_ descriptor: FetchDescriptor<T>) throws -> [PersistentIdentifier] where T: PersistentModel {
        try fetch(descriptor).map(\.persistentModelID)
    }
    /// the model with that identifier in this context
    open func model(for id: PersistentIdentifier) -> any PersistentModel {
        guard let m = objects.first(where: { $0.persistentModelID == id }) else { fatalError("SwiftData: no model with identifier \(id) in this context") }
        return m
    }
    open func registeredModel<T: PersistentModel>(for id: PersistentIdentifier) -> T? { objects.first { $0.persistentModelID == id } as? T }
    public var insertedModelsArray: [any PersistentModel] { objects.filter { inserted.contains(ObjectIdentifier($0)) } }
    public var deletedModelsArray: [any PersistentModel] { deleted }

    private var saveScheduled = false
    /// autosave, as SwiftData's main context: after the current event (a rollback in the same turn still undoes)
    private func changed() {
        hasChanges = true
        objectWillChange.send()
        changes += 1
        guard autosaveEnabled, !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            saveScheduled = false
            if autosaveEnabled && hasChanges { try? save() }
        }
    }
}

@MainActor open class ModelContainer: ObservableObject {
    public let schema: Schema
    public let configurations: [ModelConfiguration]
    public lazy var mainContext = ModelContext(self)
    public required init(for givenSchema: Schema, configurations: [ModelConfiguration] = []) throws {
        schema = givenSchema
        self.configurations = configurations.isEmpty ? [ModelConfiguration(schema: givenSchema)] : configurations
    }
    public convenience init(for givenSchema: Schema, configurations: ModelConfiguration...) throws {
        try self.init(for: givenSchema, configurations: configurations)
    }
    public convenience init(for modelTypes: [any PersistentModel.Type], configurations: [ModelConfiguration] = []) throws {
        try self.init(for: Schema(modelTypes), configurations: configurations)
    }
    public convenience init(for modelType: any PersistentModel.Type, _ modelTypes: any PersistentModel.Type..., configurations: ModelConfiguration...) throws {
        try self.init(for: Schema([modelType] + modelTypes), configurations: configurations)
    }
    open func deleteAllData() { mainContext = ModelContext(self) }
}

@MainActor @propertyWrapper public struct Query<Element: PersistentModel>: DynamicProperty, _IsimInstallableDynamicProperty {
    /// the view's context (from its environment, at install) and the subscription that re-renders the view
    final class Holder { weak var context: ModelContext?; var watching: ObjectIdentifier?; var cancel: AnyCancellable? }
    private let holder = Holder()
    private var descriptor: FetchDescriptor<Element>
    public init(_ descriptor: FetchDescriptor<Element>) { self.descriptor = descriptor }
    public init(filter: Predicate<Element>? = nil, sort: [SortDescriptor<Element>] = []) { descriptor = FetchDescriptor(predicate: filter, sortBy: sort) }
    public init<Value: Comparable>(filter: Predicate<Element>? = nil, sort keyPath: KeyPath<Element, Value> & Sendable, order: SortOrder = .forward) {
        descriptor = FetchDescriptor(predicate: filter, sortBy: [SortDescriptor(keyPath, order: order)])
    }
    public init<Value: Comparable>(filter: Predicate<Element>? = nil, sort keyPath: KeyPath<Element, Value?> & Sendable, order: SortOrder = .forward) {
        descriptor = FetchDescriptor(predicate: filter, sortBy: [SortDescriptor(keyPath, order: order)])
    }
    public func _isimInstall(_ site: _IsimDynamicPropertySite) {
        let context = site.environment.modelContext
        holder.context = context
        let watch = site.storage { Holder() }                 // one subscription per view position
        guard watch.watching != ObjectIdentifier(context) else { return }
        watch.watching = ObjectIdentifier(context)
        let invalidate = site.invalidate
        watch.cancel = context.objectWillChange.sink { _ in DispatchQueue.main.async { invalidate() } }
    }
    /// the matching models, fetched from the view's context each time the view evaluates
    public var wrappedValue: [Element] { (try? modelContext.fetch(descriptor)) ?? [] }
    public var modelContext: ModelContext { holder.context ?? ModelContextKey.defaultValue }
}
private struct ModelContextKey: EnvironmentKey {
    @MainActor static let fallback: ModelContext = try! ModelContainer(for: Schema()).mainContext
    static var defaultValue: ModelContext { MainActor.assumeIsolated { fallback } }
}
extension EnvironmentValues {
    @MainActor public var modelContext: ModelContext { get { self[ModelContextKey.self] } set { self[ModelContextKey.self] = newValue } }
}
extension View {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some View { environment(\.modelContext, container.mainContext) }
    @MainActor public func modelContainer(for modelTypes: [any PersistentModel.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some View {
        modelContainer(_containers.container(modelTypes, inMemory: inMemory, onSetup: onSetup))
    }
    @MainActor public func modelContainer(for modelType: any PersistentModel.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some View {
        modelContainer(for: [modelType], inMemory: inMemory, onSetup: onSetup)
    }
    @MainActor public func modelContext(_ modelContext: ModelContext) -> some View { environment(\.modelContext, modelContext) }
}
extension Scene {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some Scene { environment(\.modelContext, container.mainContext) }
    @MainActor public func modelContainer(for modelTypes: [any PersistentModel.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some Scene {
        modelContainer(_containers.container(modelTypes, inMemory: inMemory, onSetup: onSetup))
    }
    @MainActor public func modelContainer(for modelType: any PersistentModel.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some Scene {
        modelContainer(for: [modelType], inMemory: inMemory, onSetup: onSetup)
    }
}
/// .modelContainer(for:) keeps one container per set of model types (a view's body runs many times)
@MainActor enum _containers {
    static var made: [String: ModelContainer] = [:]
    static func container(_ types: [any PersistentModel.Type], inMemory: Bool, onSetup: (Swift.Result<ModelContainer, any Error>) -> Void) -> ModelContainer {
        let key = types.map { String(reflecting: $0) }.joined(separator: ",") + (inMemory ? "/memory" : "")
        if let c = made[key] { return c }
        let c = try! ModelContainer(for: Schema(types), configurations: [ModelConfiguration(isStoredInMemoryOnly: inMemory)])
        made[key] = c
        onSetup(.success(c))
        return c
    }
}
