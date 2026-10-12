// SwiftData on isim: an adapted, process-local model container. @Model is a real compiler macro; storage uses
// identity-preserving model instances and explicit save(), without Apple's schema migration or CloudKit backend.
@_exported import Foundation
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

public struct PersistentIdentifier: Hashable, Codable, Sendable, CustomStringConvertible {
    private let value: UUID
    public init() { value = UUID() }
    public var description: String { value.uuidString }
}
public protocol PersistentModel: AnyObject { var persistentModelID: PersistentIdentifier { get } }

public enum Schema {
    public enum Attribute { public struct Option: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let unique = Option(rawValue: 1); public static let externalStorage = Option(rawValue: 2); public static let encrypt = Option(rawValue: 4); public static let preserveValueOnDeletion = Option(rawValue: 8) } }
    public enum Relationship {
        public struct Option: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let unique = Option(rawValue: 1) }
        public enum DeleteRule: Sendable { case noAction, nullify, cascade, deny }
    }
}

public struct ModelConfiguration: Sendable {
    public var name: String
    public var isStoredInMemoryOnly: Bool
    public init(_ name: String = "Default", isStoredInMemoryOnly: Bool = false) { self.name = name; self.isStoredInMemoryOnly = isStoredInMemoryOnly }
}
public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortBy: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) { self.predicate = predicate; self.sortBy = sortBy }
}

@MainActor open class ModelContext: ObservableObject {
    public let container: ModelContainer
    private var objects: [ObjectIdentifier: any PersistentModel] = [:]
    public var hasChanges = false
    public var autosaveEnabled = true
    init(_ container: ModelContainer) { self.container = container }
    open func insert<T: PersistentModel>(_ model: T) { objects[ObjectIdentifier(model)] = model; hasChanges = true; objectWillChange.send() }
    open func delete<T: PersistentModel>(_ model: T) { objects.removeValue(forKey: ObjectIdentifier(model)); hasChanges = true; objectWillChange.send() }
    open func save() throws { hasChanges = false }
    open func rollback() { hasChanges = false }
    open func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T: PersistentModel {
        var result = objects.values.compactMap { $0 as? T }
        if descriptor.fetchOffset ?? 0 > 0 { result = Array(result.dropFirst(descriptor.fetchOffset!)) }
        if let limit = descriptor.fetchLimit { result = Array(result.prefix(limit)) }
        return result
    }
    open func fetchCount<T>(_ descriptor: FetchDescriptor<T>) throws -> Int where T: PersistentModel { try fetch(descriptor).count }
}

@MainActor open class ModelContainer: ObservableObject {
    public let configurations: Set<String>
    public lazy var mainContext = ModelContext(self)
    public required init(for modelTypes: [any PersistentModel.Type], configurations: [ModelConfiguration] = []) throws {
        self.configurations = Set(configurations.isEmpty ? ["Default"] : configurations.map(\.name))
    }
    public convenience init(for modelType: any PersistentModel.Type, _ modelTypes: any PersistentModel.Type..., configurations: ModelConfiguration...) throws {
        try self.init(for: [modelType] + modelTypes, configurations: configurations)
    }
}

@MainActor @propertyWrapper public struct Query<Element: PersistentModel>: DynamicProperty {
    @Environment(\.modelContext) private var context
    private var descriptor: FetchDescriptor<Element>
    public init(filter: Predicate<Element>? = nil, sort: [SortDescriptor<Element>] = []) { descriptor = FetchDescriptor(predicate: filter, sortBy: sort) }
    public var wrappedValue: [Element] { (try? context.fetch(descriptor)) ?? [] }
    public var projectedValue: Query<Element> { self }
}
private struct ModelContextKey: EnvironmentKey {
    @MainActor static let fallback: ModelContext = try! ModelContainer(for: []).mainContext
    static var defaultValue: ModelContext { MainActor.assumeIsolated { fallback } }
}
extension EnvironmentValues {
    @MainActor public var modelContext: ModelContext { get { self[ModelContextKey.self] } set { self[ModelContextKey.self] = newValue } }
}
extension View {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some View { environment(\.modelContext, container.mainContext) }
    @MainActor public func modelContainer(for modelTypes: [any PersistentModel.Type], inMemory: Bool = false) -> some View {
        modelContainer(try! ModelContainer(for: modelTypes, configurations: [ModelConfiguration(isStoredInMemoryOnly: inMemory)]))
    }
}
