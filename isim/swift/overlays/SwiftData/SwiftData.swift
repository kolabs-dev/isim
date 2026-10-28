// SwiftData on isim: models persist in an SQLite store on disk (Store.swift), the same SQLite isim's Core Data uses.
// @Model is a real compiler macro that expands like Apple's (stored properties become accessors over the model's
// backing data, Backing.swift); ModelContext (Context.swift) keeps one instance per stored model, tracks inserts,
// changes and deletes, and writes them on save (autosave on the main context). Adapted: fetches load the entity's
// rows and evaluate the predicate and sort in Swift (Apple translates them to SQL); no schema migration, history or
// CloudKit backend yet. Xcode's SwiftData app template runs as written.
@_exported import Foundation
import Combine
@_exported import Observation
import SwiftUI

@attached(member, names: named(_$backingData), named(persistentBackingData), named(schemaMetadata), named(init),
          named(_$observationRegistrar), named(access), named(withMutation))
@attached(memberAttribute)
@attached(extension, conformances: PersistentModel, Observable)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "ModelMacro")

/// the accessors @Model gives a stored property (Apple's expansion uses the same name)
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro _PersistedProperty() = #externalMacro(module: "SwiftDataMacros", type: "PersistedPropertyMacro")

@attached(peer)
public macro Attribute(_ options: Schema.Attribute.Option..., originalName: String? = nil, hashModifier: String? = nil) = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")
@attached(peer)
public macro Relationship(_ options: Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule = .nullify,
                          minimumModelCount: Int? = 0, maximumModelCount: Int? = 0, originalName: String? = nil,
                          inverse: AnyKeyPath? = nil, hashModifier: String? = nil) = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")
@attached(peer)
public macro Transient() = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")

/// Models whose values for these key paths must be unique: inserting a model that matches a stored one updates it.
@freestanding(declaration, names: named(_isimUniquenessConstraints))
public macro Unique<T>(_ constraints: [PartialKeyPath<T>]...) = #externalMacro(module: "SwiftDataMacros", type: "UniqueMacro") where T: PersistentModel
/// Indexes of the store for these key paths.
@freestanding(declaration, names: named(_isimIndexes))
public macro Index<T>(_ indices: [PartialKeyPath<T>]...) = #externalMacro(module: "SwiftDataMacros", type: "IndexMacro") where T: PersistentModel

/// What a persisted property's `_name` peer holds (its value is in the backing data).
public struct _SwiftDataNoType: Sendable { public init() {} }

// MARK: - Identifiers

/// A model's identity in its store: entity and primary key (temporary until the model is inserted). The default store's
/// keys are integers; a custom data store's (a UUID, a string) are kept as their text in `key`.
public struct PersistentIdentifier: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public struct ID: Hashable, Codable, Sendable {
        let primaryKey: Int64
        var key: String? = nil
    }
    public let id: ID
    public var entityName: String
    public var storeIdentifier: String?
    public var isTemporary: Bool { id.key == nil && id.primaryKey < 0 }
    init(entityName: String, storeIdentifier: String?, primaryKey: Int64) {
        id = ID(primaryKey: primaryKey); self.entityName = entityName; self.storeIdentifier = storeIdentifier
    }
    init(entityName: String, storeIdentifier: String?, key: String) {
        id = ID(primaryKey: 0, key: key); self.entityName = entityName; self.storeIdentifier = storeIdentifier
    }
    /// the identifier of a stored model, from its store, entity and primary key (an integer, or any Codable key a
    /// custom data store uses, such as a UUID)
    public static func identifier<T>(for storeIdentifier: String, entityName: String, primaryKey: T) throws -> PersistentIdentifier
        where T: Decodable, T: Encodable, T: Hashable, T: Sendable {
        if let k = (primaryKey as? any BinaryInteger).map({ Int64($0) }) {
            return PersistentIdentifier(entityName: entityName, storeIdentifier: storeIdentifier, primaryKey: k)
        }
        let text: String
        if let s = primaryKey as? String { text = s }
        else if let u = primaryKey as? UUID { text = u.uuidString }
        else if let s = primaryKey as? any LosslessStringConvertible { text = s.description }
        else if let d = try? JSONEncoder().encode([primaryKey]), let s = String(data: d, encoding: .utf8) { text = s }
        else { throw SwiftDataError.unknownSchema }
        return PersistentIdentifier(entityName: entityName, storeIdentifier: storeIdentifier, key: text)
    }
    public var description: String {
        let k = id.key.map { "p\($0)" } ?? (isTemporary ? "t\(-id.primaryKey)" : "p\(id.primaryKey)")
        return "PersistentIdentifier(\(entityName)/\(storeIdentifier ?? "-")/\(k))"
    }
    public static func < (a: PersistentIdentifier, b: PersistentIdentifier) -> Bool {
        (a.entityName, a.id.primaryKey, a.id.key ?? "") < (b.entityName, b.id.primaryKey, b.id.key ?? "")
    }
}

// MARK: - Models

/// A model class (@Model): its values live in its backing data; identified by its persistent identifier, hashed and
/// compared by identity, observable.
public protocol PersistentModel: AnyObject, Observable, Hashable, Identifiable {
    init(backingData: any BackingData<Self>)
    var persistentBackingData: any BackingData<Self> { get set }
    static var schemaMetadata: [Schema.PropertyMetadata] { get }
    /// #Unique's constraints (none without it)
    static var _isimUniquenessConstraints: [[AnyKeyPath]] { get }
    /// #Index's indexes (none without it)
    static var _isimIndexes: [[AnyKeyPath]] { get }
}

extension PersistentModel {
    public static var _isimUniquenessConstraints: [[AnyKeyPath]] { [] }
    public static var _isimIndexes: [[AnyKeyPath]] { [] }
    public var id: PersistentIdentifier { persistentModelID }
    public static func == (a: Self, b: Self) -> Bool { a === b }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    public var persistentModelID: PersistentIdentifier { _store.identifier }
    /// the context the model was inserted into (nil before insert or after delete)
    public var modelContext: ModelContext? { _store.context }
    /// whether the model has changes its context has not saved
    public var hasChanges: Bool { _store.isInserted || _store.isDirty }
    public var isDeleted: Bool { _store.isDeleted }
    var _store: _BackingStore { persistentBackingData as! _BackingStore }

    public static func createBackingData<P: PersistentModel>() -> some BackingData<P> { _DefaultBackingData<P>(for: P.self) }

    public func getValue<Value: Decodable>(forKey key: KeyPath<Self, Value>) -> Value { persistentBackingData.getValue(forKey: key) }
    public func getValue<Value: PersistentModel>(forKey key: KeyPath<Self, Value>) -> Value { _store.adopt(self); return persistentBackingData.getValue(forKey: key) }
    public func getValue<Value: PersistentModel>(forKey key: KeyPath<Self, Value?>) -> Value? { _store.adopt(self); return persistentBackingData.getValue(forKey: key) }
    public func getValue<Value, OtherModel>(forKey key: KeyPath<Self, Value>) -> Value where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        _store.adopt(self); return persistentBackingData.getValue(forKey: key)
    }
    public func getValue<Value, OtherModel>(forKey key: KeyPath<Self, Value?>) -> Value? where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        _store.adopt(self); return persistentBackingData.getValue(forKey: key)
    }
    public func getTransformableValue<Value>(forKey key: KeyPath<Self, Value>) -> Value { persistentBackingData.getTransformableValue(forKey: key) }

    public func setValue<Value: Encodable>(forKey key: KeyPath<Self, Value>, to newValue: Value) { _store.adopt(self); persistentBackingData.setValue(forKey: key, to: newValue) }
    public func setValue<Value: PersistentModel>(forKey key: KeyPath<Self, Value>, to newValue: Value) { _store.adopt(self); persistentBackingData.setValue(forKey: key, to: newValue) }
    public func setValue<Value: PersistentModel>(forKey key: KeyPath<Self, Value?>, to newValue: Value?) { _store.adopt(self); persistentBackingData.setValue(forKey: key, to: newValue) }
    public func setValue<Value, OtherModel>(forKey key: KeyPath<Self, Value>, to newValue: Value) where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        _store.adopt(self); persistentBackingData.setValue(forKey: key, to: newValue)
    }
    public func setValue<Value, OtherModel>(forKey key: KeyPath<Self, Value?>, to newValue: Value?) where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        _store.adopt(self); persistentBackingData.setValue(forKey: key, to: newValue)
    }
    public func setTransformableValue<Value>(forKey key: KeyPath<Self, Value>, to newValue: Value) { _store.adopt(self); persistentBackingData.setTransformableValue(forKey: key, to: newValue) }
}

/// A to-many relationship's value: an array of models.
public protocol RelationshipCollection: Collection {
    associatedtype PersistentElement: PersistentModel
    init(_ models: [PersistentElement])
    var _models: [PersistentElement] { get }
}
extension Array: RelationshipCollection where Element: PersistentModel {
    public typealias PersistentElement = Element
    public init(_ models: [Element]) { self = models }
    public var _models: [Element] { self }
}

// MARK: - Schema

/// A property's description in a schema: an attribute or a relationship.
public protocol SchemaProperty: Codable, Hashable {
    var name: String { get }
    var originalName: String { get }
    var valueType: any Any.Type { get }
    var isAttribute: Bool { get }
    var isRelationship: Bool { get }
    var isTransient: Bool { get }
    var isOptional: Bool { get }
    var isUnique: Bool { get }
}

func _isOptional(_ t: Any.Type) -> Bool { t is _OptionalMarker.Type }
protocol _OptionalMarker {}
extension Optional: _OptionalMarker {}

/// The model types of a container, their properties and constraints.
public final class Schema: Hashable, @unchecked Sendable {
    /// An attribute: a stored value property, and its options.
    public final class Attribute: SchemaProperty, @unchecked Sendable {
        public struct Option: Hashable, Codable, Sendable {
            let kind: String
            public static var unique: Option { Option(kind: "unique") }
            public static var externalStorage: Option { Option(kind: "externalStorage") }
            public static var allowsCloudEncryption: Option { Option(kind: "allowsCloudEncryption") }
            public static var preserveValueOnDeletion: Option { Option(kind: "preserveValueOnDeletion") }
            public static var ephemeral: Option { Option(kind: "ephemeral") }
            public static var spotlight: Option { Option(kind: "spotlight") }
            public static func transformable(by transformerName: String) -> Option { Option(kind: "transformable:" + transformerName) }
        }
        public internal(set) var name: String
        public var originalName: String
        public var options: [Option]
        public internal(set) var valueType: any Any.Type
        public var defaultValue: Any?
        public var hashModifier: String?
        public init(_ options: Option..., originalName: String? = nil, hashModifier: String? = nil) {
            self.options = options; name = ""; self.originalName = originalName ?? ""; valueType = Any.self; self.hashModifier = hashModifier
        }
        public init(name: String, originalName: String? = nil, options: [Option] = [], valueType: any Any.Type, defaultValue: Any? = nil, hashModifier: String? = nil) {
            self.name = name; self.originalName = originalName ?? name; self.options = options; self.valueType = valueType
            self.defaultValue = defaultValue; self.hashModifier = hashModifier
        }
        public var isAttribute: Bool { true }
        public var isRelationship: Bool { false }
        public var isTransient: Bool { false }
        public var isOptional: Bool { _isOptional(valueType) }
        public var isUnique: Bool { options.contains(.unique) }
        public var isTransformable: Bool { options.contains { $0.kind.hasPrefix("transformable:") } }
        public var isCodable: Bool { valueType is any Codable.Type }
        enum CodingKeys: String, CodingKey { case name, originalName, options, hashModifier }
        public required init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name); originalName = try c.decode(String.self, forKey: .originalName)
            options = try c.decode([Option].self, forKey: .options); hashModifier = try c.decodeIfPresent(String.self, forKey: .hashModifier); valueType = Any.self
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name); try c.encode(originalName, forKey: .originalName); try c.encode(options, forKey: .options)
            try c.encodeIfPresent(hashModifier, forKey: .hashModifier)
        }
        public static func == (a: Attribute, b: Attribute) -> Bool { a.name == b.name && a.options == b.options && a.originalName == b.originalName }
        public func hash(into h: inout Hasher) { h.combine(name); h.combine(options) }
    }

    /// A relationship: a property whose value is a model or models, its delete rule and inverse.
    public final class Relationship: SchemaProperty, @unchecked Sendable {
        public struct Option: Hashable, Codable, Sendable {
            let kind: String
            public static var unique: Option { Option(kind: "unique") }
        }
        public enum DeleteRule: String, Hashable, Codable, Sendable { case noAction, nullify, cascade, deny }
        public internal(set) var name: String
        public var originalName: String
        public var options: [Option]
        public var deleteRule: DeleteRule
        public var minimumModelCount: Int?
        public var maximumModelCount: Int?
        public var inverseKeyPath: AnyKeyPath?
        public internal(set) var inverseName: String?
        public internal(set) var keypath: AnyKeyPath?
        public internal(set) var destination: String
        public internal(set) var valueType: any Any.Type
        public var hashModifier: String?
        public init(_ options: Option..., deleteRule: DeleteRule = .nullify, minimumModelCount: Int? = 0, maximumModelCount: Int? = 0,
                    originalName: String? = nil, inverse: AnyKeyPath? = nil, hashModifier: String? = nil) {
            self.options = options; self.deleteRule = deleteRule; self.minimumModelCount = minimumModelCount; self.maximumModelCount = maximumModelCount
            self.originalName = originalName ?? ""; inverseKeyPath = inverse; self.hashModifier = hashModifier
            name = ""; destination = ""; valueType = Any.self
        }
        public var isAttribute: Bool { false }
        public var isRelationship: Bool { true }
        public var isTransient: Bool { false }
        public var isOptional: Bool { _isOptional(valueType) }
        public var isUnique: Bool { options.contains(.unique) }
        public var isToOneRelationship: Bool { !(valueType is _ToManyMarker.Type) }
        enum CodingKeys: String, CodingKey { case name, originalName, options, deleteRule, destination, inverseName }
        public required init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name); originalName = try c.decode(String.self, forKey: .originalName)
            options = try c.decode([Option].self, forKey: .options); deleteRule = try c.decode(DeleteRule.self, forKey: .deleteRule)
            destination = try c.decode(String.self, forKey: .destination); inverseName = try c.decodeIfPresent(String.self, forKey: .inverseName)
            valueType = Any.self
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name); try c.encode(originalName, forKey: .originalName); try c.encode(options, forKey: .options)
            try c.encode(deleteRule, forKey: .deleteRule); try c.encode(destination, forKey: .destination); try c.encodeIfPresent(inverseName, forKey: .inverseName)
        }
        public static func == (a: Relationship, b: Relationship) -> Bool { a.name == b.name && a.destination == b.destination && a.deleteRule == b.deleteRule }
        public func hash(into h: inout Hasher) { h.combine(name); h.combine(destination) }
    }

    /// What @Model generates for each persisted property.
    public struct PropertyMetadata {
        let name: String, keypath: AnyKeyPath, defaultValue: Any?, metadata: (any SchemaProperty)?
        public init(name: String, keypath: AnyKeyPath, defaultValue: Any?, metadata: (any SchemaProperty)?) {
            self.name = name; self.keypath = keypath; self.defaultValue = defaultValue; self.metadata = metadata
        }
    }

    /// A model type of the schema.
    public final class Entity: Hashable, @unchecked Sendable {
        public let name: String
        public let properties: [any SchemaProperty]
        public var attributes: Set<Attribute> { Set(properties.compactMap { $0 as? Attribute }) }
        public var relationships: Set<Relationship> { Set(properties.compactMap { $0 as? Relationship }) }
        public var storedProperties: [any SchemaProperty] { properties }
        public var storedPropertiesByName: [String: any SchemaProperty] { Dictionary(properties.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a }) }
        public var attributesByName: [String: Attribute] { Dictionary(attributes.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a }) }
        public var relationshipsByName: [String: Relationship] { Dictionary(relationships.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a }) }
        /// the properties whose values together must be unique (#Unique, @Attribute(.unique))
        public let uniquenessConstraints: [[String]]
        public let indices: [[String]]
        init(_ info: _ModelInfo) {
            name = info.entity
            properties = info.properties.map { $0.schemaProperty }
            uniquenessConstraints = info.uniques.map { $0.map { info.properties[$0].name } }
            indices = info.indexes.map { $0.map { info.properties[$0].name } }
        }
        public static func == (a: Entity, b: Entity) -> Bool { a.name == b.name }
        public func hash(into h: inout Hasher) { h.combine(name) }
    }

    public struct Version: Hashable, Codable, Sendable, CustomStringConvertible, Comparable {
        public let major: Int, minor: Int, patch: Int
        public init(_ major: Int, _ minor: Int, _ patch: Int) { self.major = major; self.minor = minor; self.patch = patch }
        public var description: String { "\(major).\(minor).\(patch)" }
        public static func < (a: Version, b: Version) -> Bool { (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch) }
    }
    public static let schemaEncodingVersion = Version(1, 0, 0)

    /// the model types and those their relationships reach
    public let entities: [Entity]
    public let entitiesByName: [String: Entity]
    public let version: Version
    public let encodingVersion: Version
    let types: [any PersistentModel.Type]

    public init(_ types: [any PersistentModel.Type], version: Version = Version(1, 0, 0)) {
        var all: [any PersistentModel.Type] = [], seen = Set<ObjectIdentifier>()
        var queue = types
        while !queue.isEmpty {
            let t = queue.removeFirst()
            guard seen.insert(ObjectIdentifier(t)).inserted else { continue }
            all.append(t)
            queue += _ModelInfo.of(t).properties.compactMap(\.target)
        }
        self.types = all; self.version = version; encodingVersion = Schema.schemaEncodingVersion
        entities = all.map { Entity(_ModelInfo.of($0)) }
        entitiesByName = Dictionary(entities.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    }
    public convenience init(_ types: any PersistentModel.Type..., version: Version = Version(1, 0, 0)) { self.init(types, version: version) }
    public convenience init() { self.init([any PersistentModel.Type]()) }
    public func entity<T: PersistentModel>(for type: T.Type) -> Entity? { entitiesByName[Schema.entityName(for: type)] }
    public static func entityName<T: PersistentModel>(for type: T.Type) -> String { _ModelInfo.of(type).entity }
    public static func == (a: Schema, b: Schema) -> Bool { a.entities.map(\.name) == b.entities.map(\.name) && a.version == b.version }
    public func hash(into h: inout Hasher) { h.combine(entities.map(\.name)); h.combine(version) }
}

// MARK: - Configuration, fetching, errors

public struct ModelConfiguration: Hashable, Sendable {
    public struct GroupContainer: Hashable, Sendable {
        let id: String?
        public static var automatic: GroupContainer { GroupContainer(id: "") }
        public static var none: GroupContainer { GroupContainer(id: nil) }
        public static func identifier(_ groupName: String) -> GroupContainer { GroupContainer(id: groupName) }
    }
    public struct CloudKitDatabase: Hashable, Sendable {
        let id: String?
        public static var automatic: CloudKitDatabase { CloudKitDatabase(id: "") }
        public static var none: CloudKitDatabase { CloudKitDatabase(id: nil) }
        public static func `private`(_ dbName: String) -> CloudKitDatabase { CloudKitDatabase(id: dbName) }
    }
    public let name: String
    public var schema: Schema?
    public let url: URL
    public let isStoredInMemoryOnly: Bool
    public let allowsSave: Bool
    public let groupContainer: GroupContainer
    public let cloudKitDatabase: CloudKitDatabase
    public var groupAppContainerIdentifier: String? { groupContainer.id.flatMap { $0.isEmpty ? nil : $0 } }
    public var cloudKitContainerIdentifier: String? { cloudKitDatabase.id.flatMap { $0.isEmpty ? nil : $0 } }

    /// a store named `name` (default: "default") in the app's Application Support directory, or in memory
    public init(_ name: String? = nil, schema: Schema? = nil, isStoredInMemoryOnly: Bool = false, allowsSave: Bool = true,
                groupContainer: GroupContainer = .automatic, cloudKitDatabase: CloudKitDatabase = .automatic) {
        let n = name ?? "default"
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.name = n; self.schema = schema; self.isStoredInMemoryOnly = isStoredInMemoryOnly; self.allowsSave = allowsSave
        self.groupContainer = groupContainer; self.cloudKitDatabase = cloudKitDatabase
        url = isStoredInMemoryOnly ? URL(fileURLWithPath: "/dev/null") : dir.appendingPathComponent("\(n).store")
    }
    /// a store at a file URL
    public init(_ name: String? = nil, schema: Schema? = nil, url: URL, allowsSave: Bool = true, cloudKitDatabase: CloudKitDatabase = .automatic) {
        self.name = name ?? url.deletingPathExtension().lastPathComponent; self.schema = schema; self.url = url
        isStoredInMemoryOnly = url.path == "/dev/null"; self.allowsSave = allowsSave
        groupContainer = .none; self.cloudKitDatabase = cloudKitDatabase
    }
    public init(for forTypes: any PersistentModel.Type..., isStoredInMemoryOnly: Bool = false) {
        self.init(nil, schema: Schema(forTypes), isStoredInMemoryOnly: isStoredInMemoryOnly)
    }
    public init(isStoredInMemoryOnly: Bool) { self.init(nil, schema: nil, isStoredInMemoryOnly: isStoredInMemoryOnly) }
}

public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortBy: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public var includePendingChanges = true
    /// kept; isim loads every property
    public var propertiesToFetch: [PartialKeyPath<T>] = []
    /// kept; isim loads relationships when they are read
    public var relationshipKeyPathsForPrefetching: [PartialKeyPath<T>] = []
    public init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) { self.predicate = predicate; self.sortBy = sortBy }
}

/// SwiftData's errors.
public struct SwiftDataError: Error, Equatable, Hashable, Sendable, CustomStringConvertible {
    let code: String
    public var description: String { "SwiftDataError(\(code))" }
    public static let loadIssueModelContainer = SwiftDataError(code: "loadIssueModelContainer")
    public static let configurationFileNameContainsInvalidCharacters = SwiftDataError(code: "configurationFileNameContainsInvalidCharacters")
    public static let configurationFileNameTooLong = SwiftDataError(code: "configurationFileNameTooLong")
    public static let configurationSchemaNotFoundInContainerSchema = SwiftDataError(code: "configurationSchemaNotFoundInContainerSchema")
    public static let duplicateConfiguration = SwiftDataError(code: "duplicateConfiguration")
    public static let backwardMigration = SwiftDataError(code: "backwardMigration")
    public static let unknownSchema = SwiftDataError(code: "unknownSchema")
    public static let unknownDataStoreSchema = SwiftDataError(code: "unknownDataStoreSchema")
    public static let unsupportedPredicate = SwiftDataError(code: "unsupportedPredicate")
    public static let unsupportedSortDescriptor = SwiftDataError(code: "unsupportedSortDescriptor")
    public static let unsupportedKeyPath = SwiftDataError(code: "unsupportedKeyPath")
    public static let includePendingChangesWithBatchSize = SwiftDataError(code: "includePendingChangesWithBatchSize")
    public static let sortingPendingChangesWithIdentifiers = SwiftDataError(code: "sortingPendingChangesWithIdentifiers")
    public static let invalidTransactionFetchRequest = SwiftDataError(code: "invalidTransactionFetchRequest")
    public static let historyTokenExpired = SwiftDataError(code: "historyTokenExpired")
    public static let missingModelContext = SwiftDataError(code: "missingModelContext")
    /// a save broke the model's rules (a `deny` delete rule, a relationship's minimum or maximum count)
    public static let modelValidationFailure = SwiftDataError(code: "modelValidationFailure")
    public static func ~= (match: SwiftDataError, error: any Error) -> Bool { (error as? SwiftDataError) == match }
}

// MARK: - SwiftUI

@MainActor @propertyWrapper public struct Query<Element: PersistentModel>: DynamicProperty, _IsimInstallableDynamicProperty {
    /// the view's context (from its environment, at install) and the subscription that re-renders the view
    final class Holder { weak var context: ModelContext?; var watching: ObjectIdentifier?; var cancel: AnyCancellable?; var error: (any Error)? }
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
    public var wrappedValue: [Element] {
        do { let r = try modelContext.fetch(descriptor); holder.error = nil; return r } catch { holder.error = error; return [] }
    }
    /// the error of the last fetch (nil when it succeeded)
    @available(iOS 27.0, *)
    public var fetchError: (any Error)? { holder.error }
    /// the results as one section (titled "")
    @available(iOS 27.0, *)
    public var sections: SectionedResults<Element, String> { SectionedResults(wrappedValue, title: { _ in "" }) }
    public var modelContext: ModelContext { holder.context ?? ModelContextKey.defaultValue }
}
private struct ModelContextKey: EnvironmentKey {
    @MainActor static let fallback: ModelContext = try! ModelContainer(for: Schema(), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]).mainContext
    static var defaultValue: ModelContext { MainActor.assumeIsolated { fallback } }
}
extension EnvironmentValues {
    @MainActor public var modelContext: ModelContext { get { self[ModelContextKey.self] } set { self[ModelContextKey.self] = newValue } }
}
extension View {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some View { environment(\.modelContext, container.mainContext) }
    @MainActor public func modelContainer(for modelTypes: [any PersistentModel.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some View {
        modelContainer(_containers.container(modelTypes, inMemory: inMemory, autosave: isAutosaveEnabled, onSetup: onSetup))
    }
    @MainActor public func modelContainer(for modelType: any PersistentModel.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some View {
        modelContainer(for: [modelType], inMemory: inMemory, isAutosaveEnabled: isAutosaveEnabled, onSetup: onSetup)
    }
    @MainActor public func modelContext(_ modelContext: ModelContext) -> some View { environment(\.modelContext, modelContext) }
}
extension Scene {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some Scene { environment(\.modelContext, container.mainContext) }
    @MainActor public func modelContainer(for modelTypes: [any PersistentModel.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some Scene {
        modelContainer(_containers.container(modelTypes, inMemory: inMemory, autosave: isAutosaveEnabled, onSetup: onSetup))
    }
    @MainActor public func modelContainer(for modelType: any PersistentModel.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false, onSetup: @escaping (Swift.Result<ModelContainer, any Error>) -> Void = { _ in }) -> some Scene {
        modelContainer(for: [modelType], inMemory: inMemory, isAutosaveEnabled: isAutosaveEnabled, onSetup: onSetup)
    }
}
/// .modelContainer(for:) keeps one container per set of model types (a view's body runs many times)
@MainActor enum _containers {
    static var made: [String: ModelContainer] = [:]
    static func container(_ types: [any PersistentModel.Type], inMemory: Bool, autosave: Bool, onSetup: (Swift.Result<ModelContainer, any Error>) -> Void) -> ModelContainer {
        let key = types.map { String(reflecting: $0) }.joined(separator: ",") + (inMemory ? "/memory" : "")
        if let c = made[key] { return c }
        do {
            let c = try ModelContainer(for: Schema(types), configurations: [ModelConfiguration(isStoredInMemoryOnly: inMemory)])
            c.mainContext.autosaveEnabled = autosave
            made[key] = c
            onSetup(.success(c))
            return c
        } catch {
            onSetup(.failure(error))
            let c = try! ModelContainer(for: Schema(types), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            made[key] = c
            return c
        }
    }
}
