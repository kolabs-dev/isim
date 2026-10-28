// isim SwiftData: custom data stores (iOS 18) — an app's own persistence behind ModelContainer. The app gives the
// container a DataStoreConfiguration; the container opens its Store and the contexts fetch and save through it:
// fetches become DataStoreFetchRequests (predicates and sorts are applied in memory, as when a store answers
// .preferInMemoryFilter), saves become DataStoreSaveChangesRequests of snapshots, and the identifiers the store
// assigns to inserted models (remappedIdentifiers) replace the temporary ones. _CustomStore adapts a DataStore to the
// row interface the context uses (_Store): rows keyed by local integer keys, mapped to the store's identifiers.
// DefaultStore is the default (SQLite) store behind the same protocol; DefaultSnapshot the snapshot it uses.
import Foundation

// MARK: - protocols

public protocol DataStoreConfiguration: Hashable {
    associatedtype Store: DataStore where Self.Store.Configuration == Self
    var name: String { get }
    var schema: Schema? { get set }
    func validate() throws
}
extension DataStoreConfiguration {
    public func validate() throws {}
}

public protocol DataStore {
    associatedtype Configuration: DataStoreConfiguration where Self.Configuration.Store == Self
    associatedtype Snapshot: DataStoreSnapshot
    init(_ configuration: Self.Configuration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws
    var configuration: Self.Configuration { get }
    var identifier: String { get }
    var schema: Schema { get }
    func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, Self.Snapshot> where T: PersistentModel
    func fetchCount<T>(_ request: DataStoreFetchRequest<T>) throws -> Int where T: PersistentModel
    func fetchIdentifiers<T>(_ request: DataStoreFetchRequest<T>) throws -> [PersistentIdentifier] where T: PersistentModel
    func save(_ request: DataStoreSaveChangesRequest<Self.Snapshot>) throws -> DataStoreSaveChangesResult<Self.Snapshot>
    func erase() throws
    func initializeState(for editingState: EditingState)
    func invalidateState(for editingState: EditingState)
    func cachedSnapshots(for persistentIdentifiers: [PersistentIdentifier], editingState: EditingState) throws -> [PersistentIdentifier: Self.Snapshot]
}
extension DataStore {
    public func fetchCount<T>(_ request: DataStoreFetchRequest<T>) throws -> Int where T: PersistentModel { try fetch(request).fetchedSnapshots.count }
    public func fetchIdentifiers<T>(_ request: DataStoreFetchRequest<T>) throws -> [PersistentIdentifier] where T: PersistentModel {
        try fetch(request).fetchedSnapshots.map(\.persistentIdentifier)
    }
    public func erase() throws { throw DataStoreError.unsupportedFeature }
    public func initializeState(for editingState: EditingState) {}
    public func invalidateState(for editingState: EditingState) {}
    public func cachedSnapshots(for persistentIdentifiers: [PersistentIdentifier], editingState: EditingState) throws -> [PersistentIdentifier: Self.Snapshot] { [:] }
}

/// A store that deletes models matching a predicate without loading them.
public protocol DataStoreBatching: DataStore {
    func delete<T>(_ request: DataStoreBatchDeleteRequest<T>) throws where T: PersistentModel
}

/// A store that records history.
public protocol HistoryProviding<HistoryType>: DataStore {
    associatedtype HistoryType: HistoryTransaction
    static var historyType: Self.HistoryType.Type { get }
    func fetchHistory(_ descriptor: HistoryDescriptor<Self.HistoryType>) throws -> [Self.HistoryType]
    func deleteHistory(_ descriptor: HistoryDescriptor<Self.HistoryType>) throws
}
extension HistoryProviding {
    public static var historyType: Self.HistoryType.Type { HistoryType.self }
}

/// A model's values as a store keeps them: its identifier and, per property, the attribute's value or the related
/// models' identifiers. Encoded with DataStoreSnapshotCodingKey keys.
public protocol DataStoreSnapshot: Decodable, Encodable, Sendable {
    var persistentIdentifier: PersistentIdentifier { get }
    init(from backingData: any BackingData, relatedBackingDatas: inout [PersistentIdentifier: any BackingData])
    func copy(persistentIdentifier: PersistentIdentifier, remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]?) -> Self
}
extension DataStoreSnapshot {
    public func copy(persistentIdentifier: PersistentIdentifier) -> Self { copy(persistentIdentifier: persistentIdentifier, remappedIdentifiers: nil) }
}

public typealias DataStoreSnapshotValue = Decodable & Encodable & Sendable

public enum DataStoreSnapshotCodingKey: CodingKey, Hashable, Sendable {
    case persistentIdentifier
    case modeledProperty(String)
    public var stringValue: String {
        switch self { case .persistentIdentifier: return "persistentIdentifier"; case .modeledProperty(let n): return n }
    }
    public init?(stringValue: String) { self = stringValue == "persistentIdentifier" ? .persistentIdentifier : .modeledProperty(stringValue) }
    public var intValue: Int? { nil }
    public init?(intValue: Int) { return nil }
}

public enum DataStoreError: Error, Hashable, Sendable {
    case invalidPredicate
    case preferInMemoryFilter
    case preferInMemorySort
    case unsupportedFeature
}

/// The context a request comes from (its author).
public struct EditingState: Hashable, Sendable {
    let id: UUID
    public var author: String?
    init(id: UUID = UUID(), author: String?) { self.id = id; self.author = author }
}

// MARK: - requests and results

public struct DataStoreFetchRequest<T: PersistentModel> {
    public let descriptor: FetchDescriptor<T>
    public let editingState: EditingState
}

public struct DataStoreFetchResult<ModelType: PersistentModel, SnapshotType: DataStoreSnapshot> {
    public let descriptor: FetchDescriptor<ModelType>
    public let fetchedSnapshots: [SnapshotType]
    public let relatedSnapshots: [PersistentIdentifier: SnapshotType]
    public init(descriptor: FetchDescriptor<ModelType>, fetchedSnapshots: [SnapshotType], relatedSnapshots: [PersistentIdentifier: SnapshotType] = [:]) {
        self.descriptor = descriptor; self.fetchedSnapshots = fetchedSnapshots; self.relatedSnapshots = relatedSnapshots
    }
}

public struct DataStoreSaveChangesRequest<SnapshotType: DataStoreSnapshot>: Sendable {
    public let editingState: EditingState
    public let inserted: [SnapshotType]
    public let updated: [SnapshotType]
    public let deleted: [SnapshotType]
}

public class DataStoreSaveChangesResult<T: DataStoreSnapshot>: @unchecked Sendable {
    public let storeIdentifier: String
    public let remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]
    public let snapshotsToReregister: [PersistentIdentifier: T]
    public let historyToken: (any HistoryToken)?
    public init(for storeIdentifier: String, remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier] = [:],
                snapshotsToReregister: [PersistentIdentifier: T] = [:]) {
        self.storeIdentifier = storeIdentifier; self.remappedIdentifiers = remappedIdentifiers
        self.snapshotsToReregister = snapshotsToReregister; historyToken = nil
    }
    public init(for storeIdentifier: String, remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier] = [:],
                snapshotsToReregister: [PersistentIdentifier: T] = [:], historyToken: (any HistoryToken)?) {
        self.storeIdentifier = storeIdentifier; self.remappedIdentifiers = remappedIdentifiers
        self.snapshotsToReregister = snapshotsToReregister; self.historyToken = historyToken
    }
}

public struct DataStoreBatchDeleteRequest<T: PersistentModel> {
    public let editingState: EditingState
    public let includeSubclasses: Bool
    public let predicate: Predicate<T>?
}

// MARK: - JSON values

/// a JSON value that encodes as itself (a snapshot's property values)
enum _JSONValue: Codable, Hashable, @unchecked Sendable {
    case null, bool(Bool), int(Int64), double(Double), string(String), array([_JSONValue]), object([String: _JSONValue])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int64.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([_JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: _JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
    /// from a JSONSerialization value
    init(_ any: Any) {
        if let d = try? JSONSerialization.data(withJSONObject: [any], options: [.fragmentsAllowed]),
           let v = try? JSONDecoder().decode([_JSONValue].self, from: d).first { self = v } else { self = .null }
    }
    /// as a JSONSerialization value
    var any: Any {
        guard let d = try? JSONEncoder().encode([self]), let a = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) as? [Any] else { return NSNull() }
        return a.first ?? NSNull()
    }
}

func _jsonObject<V: Encodable>(_ v: V) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(v), options: [.fragmentsAllowed])
}
func _fromJSONObject<V: Decodable>(_ type: V.Type, _ j: Any) throws -> V {
    try JSONDecoder().decode(V.self, from: JSONSerialization.data(withJSONObject: j, options: [.fragmentsAllowed]))
}

// MARK: - default snapshot and store

/// The snapshot the default store (and stores that use it) works with: an identifier and each property's value.
public struct DefaultSnapshot: DataStoreSnapshot, Hashable {
    public let persistentIdentifier: PersistentIdentifier
    /// attributes as their Codable encoding; relationships as the related models' identifiers
    let values: [String: _JSONValue]
    init(persistentIdentifier: PersistentIdentifier, values: [String: _JSONValue]) { self.persistentIdentifier = persistentIdentifier; self.values = values }

    public init(from backingData: any BackingData, relatedBackingDatas: inout [PersistentIdentifier: any BackingData]) {
        let s = backingData as! _BackingStore
        var values: [String: _JSONValue] = [:]
        let row = (try? s.row()) ?? [:]
        func id(_ i: Int, _ k: Int64) -> PersistentIdentifier {
            let entity = _ModelInfo.of(s.info.properties[i].target!).entity
            return s.context?.store.publicIdentifier(entity, k) ?? PersistentIdentifier(entityName: entity, storeIdentifier: nil, primaryKey: k)
        }
        for (i, p) in s.info.properties.enumerated() {
            guard let v = row[p.name] else { continue }
            if p.target == nil { values[p.name] = _JSONValue(v); continue }
            let keys = p.toMany ? ((v as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.int64Value } : [(v as? NSNumber)?.int64Value].compactMap { $0 }
            let ids = keys.map { id(i, $0) }
            for o in s.objects(i) { let b = _store(o); if let d = b as? any BackingData { relatedBackingDatas[b.identifier] = d } }
            values[p.name] = p.toMany ? .array(ids.map { (try? _jsonObject($0)).map { _JSONValue($0) } ?? .null }) : (ids.first.flatMap { (try? _jsonObject($0)).map { _JSONValue($0) } } ?? .null)
        }
        self.init(persistentIdentifier: s.identifier, values: values)
    }
    public func copy(persistentIdentifier: PersistentIdentifier, remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]?) -> DefaultSnapshot {
        guard let map = remappedIdentifiers, !map.isEmpty else { return DefaultSnapshot(persistentIdentifier: persistentIdentifier, values: values) }
        func remap(_ v: _JSONValue) -> _JSONValue {
            switch v {
            case .object:
                guard let id = try? _fromJSONObject(PersistentIdentifier.self, v.any), let n = map[id], let j = try? _jsonObject(n) else { return v }
                return _JSONValue(j)
            case .array(let a): return .array(a.map(remap))
            default: return v
            }
        }
        return DefaultSnapshot(persistentIdentifier: persistentIdentifier, values: values.mapValues(remap))
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DataStoreSnapshotCodingKey.self)
        persistentIdentifier = try c.decode(PersistentIdentifier.self, forKey: .persistentIdentifier)
        var v: [String: _JSONValue] = [:]
        for k in c.allKeys where k != .persistentIdentifier { v[k.stringValue] = try c.decode(_JSONValue.self, forKey: k) }
        values = v
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DataStoreSnapshotCodingKey.self)
        try c.encode(persistentIdentifier, forKey: .persistentIdentifier)
        for (k, v) in values.sorted(by: { $0.key < $1.key }) { try c.encode(v, forKey: .modeledProperty(k)) }
    }
}

/// The default store (SQLite, Store.swift) as a DataStore.
public final class DefaultStore: DataStore, DataStoreBatching, HistoryProviding, @unchecked Sendable {
    public typealias Configuration = ModelConfiguration
    public typealias Snapshot = DefaultSnapshot
    public typealias HistoryType = DefaultHistoryTransaction
    public typealias TokenType = DefaultHistoryToken
    public let configuration: ModelConfiguration
    public let name: String
    public let schema: Schema
    let sql: _SQLStore
    public var identifier: String { sql.identifier }

    public init(_ configuration: ModelConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws {
        self.configuration = configuration
        name = configuration.name
        schema = configuration.schema ?? Schema()
        sql = try _SQLStore.store(for: configuration)
        for t in schema.types { sql.ensure(_ModelInfo.of(t)) }
        try _Migration.run(sql, schema: schema, plan: migrationPlan, configuration: configuration)
    }

    /// a row as a snapshot: relationships' keys become identifiers
    func snapshot(_ info: _ModelInfo, _ pk: Int64, _ row: [String: Any]) -> DefaultSnapshot {
        var values: [String: _JSONValue] = [:]
        for p in info.properties {
            guard let v = row[p.name] else { continue }
            guard let target = p.target else { values[p.name] = _JSONValue(v); continue }
            let entity = _ModelInfo.of(target).entity
            func id(_ n: Any) -> _JSONValue {
                guard let k = (n as? NSNumber)?.int64Value, let j = try? _jsonObject(sql.publicIdentifier(entity, k)) else { return .null }
                return _JSONValue(j)
            }
            values[p.name] = p.toMany ? .array(((v as? [Any]) ?? []).map(id)) : id(v)
        }
        return DefaultSnapshot(persistentIdentifier: sql.publicIdentifier(info.entity, pk), values: values)
    }
    /// a snapshot as a row: identifiers become keys
    func row(_ info: _ModelInfo, _ s: DefaultSnapshot, _ keys: [PersistentIdentifier: Int64]) -> [String: Any] {
        var out: [String: Any] = [:]
        for p in info.properties {
            guard let v = s.values[p.name] else { continue }
            guard p.target != nil else { out[p.name] = v.any; continue }
            func key(_ j: _JSONValue) -> Any {
                guard let id = try? _fromJSONObject(PersistentIdentifier.self, j.any) else { return NSNull() }
                return NSNumber(value: keys[id] ?? sql.localKey(id) ?? 0)
            }
            if case .array(let a) = v { out[p.name] = a.map(key) } else { out[p.name] = key(v) }
        }
        return out
    }

    public func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot> where T: PersistentModel {
        if request.descriptor.predicate != nil { throw DataStoreError.preferInMemoryFilter }
        if !request.descriptor.sortBy.isEmpty { throw DataStoreError.preferInMemorySort }
        let info = _ModelInfo.of(T.self)
        sql.ensure(info)
        var list = sql.rows(info.entity).map { snapshot(info, $0.0, $0.1) }
        if let o = request.descriptor.fetchOffset, o > 0 { list = Array(list.dropFirst(o)) }
        if let l = request.descriptor.fetchLimit { list = Array(list.prefix(l)) }
        return DataStoreFetchResult(descriptor: request.descriptor, fetchedSnapshots: list)
    }
    public func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws -> DataStoreSaveChangesResult<DefaultSnapshot> {
        var types: [String: _ModelInfo] = [:]
        for t in schema.types { let i = _ModelInfo.of(t); types[i.entity] = i }
        func info(_ s: DefaultSnapshot) throws -> _ModelInfo {
            guard let i = types[s.persistentIdentifier.entityName] else { throw SwiftDataError.unknownSchema }
            return i
        }
        var remapped: [PersistentIdentifier: PersistentIdentifier] = [:], keys: [PersistentIdentifier: Int64] = [:]
        for s in request.inserted {
            let i = try info(s), k = sql.allocate(i.entity)
            keys[s.persistentIdentifier] = k
            remapped[s.persistentIdentifier] = sql.publicIdentifier(i.entity, k)
        }
        var changes: [[String: Any]] = []
        var reregister: [PersistentIdentifier: DefaultSnapshot] = [:]
        sql.begin()
        do {
            for s in request.inserted + request.updated {
                let i = try info(s)
                guard let k = keys[s.persistentIdentifier] ?? sql.localKey(s.persistentIdentifier) else { continue }
                try sql.put(i.entity, k, row(i, s, keys))
                let id = sql.publicIdentifier(i.entity, k)
                reregister[id] = s.copy(persistentIdentifier: id, remappedIdentifiers: remapped)
                changes.append(keys[s.persistentIdentifier] != nil ? ["k": "i", "e": i.entity, "p": NSNumber(value: k)] as [String: Any]
                                                                   : ["k": "u", "e": i.entity, "p": NSNumber(value: k), "a": s.values.keys.sorted()] as [String: Any])
            }
            for s in request.deleted {
                let i = try info(s)
                guard let k = sql.localKey(s.persistentIdentifier) else { continue }
                sql.remove(i.entity, k)
                let kept = i.properties.filter { $0.attribute?.options.contains(.preserveValueOnDeletion) == true }.compactMap { p in s.values[p.name].map { (p.name, $0.any) } }
                changes.append(["k": "d", "e": i.entity, "p": NSNumber(value: k), "t": Dictionary(kept, uniquingKeysWith: { a, _ in a })] as [String: Any])
            }
        } catch { sql.abort(); throw error }
        let token = sql.record(changes, author: request.editingState.author)
        sql.commit()
        sql.committed(by: nil)
        return DataStoreSaveChangesResult(for: identifier, remappedIdentifiers: remapped, snapshotsToReregister: reregister, historyToken: token)
    }
    public func delete<T>(_ request: DataStoreBatchDeleteRequest<T>) throws where T: PersistentModel {
        if request.predicate != nil { throw DataStoreError.preferInMemoryFilter }
        let info = _ModelInfo.of(T.self)
        sql.ensure(info)
        sql.begin()
        for (k, _) in sql.rows(info.entity) { sql.remove(info.entity, k) }
        sql.commit()
    }
    public func erase() throws { sql.eraseAll() }
    public func fetchHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws -> [DefaultHistoryTransaction] {
        try sql.fetchHistory(descriptor, schema: schema)
    }
    public func deleteHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws { try sql.deleteHistory(descriptor, schema: schema) }
}

extension ModelConfiguration: DataStoreConfiguration {
    public typealias Store = DefaultStore
}

// MARK: - a custom store behind a context

/// adapts an app's DataStore to the context's row interface: local integer keys for the store's identifiers,
/// snapshots converted to and from rows, history and batch deletes forwarded when the store provides them
final class _CustomStore<S: DataStore>: _Store, @unchecked Sendable {
    let base: S
    let schema: Schema
    private let lock = NSRecursiveLock()
    private var _generation = 0
    private var observers: [(AnyObject?) -> Void] = []
    private var nextKey: Int64 = 0
    /// local key ↔ the store's identifier (inserted models have a temporary one until the store remaps it)
    private var ids: [Int64: PersistentIdentifier] = [:]
    private var keys: [PersistentIdentifier: Int64] = [:]
    /// the rows of the last fetch, by entity and key (row(_:_:) and related models)
    private var cache: [String: [Int64: [String: Any]]] = [:]
    private var types: [String: _ModelInfo] = [:]

    init(_ base: S, schema: Schema) {
        self.base = base; self.schema = schema
        for t in schema.types { let i = _ModelInfo.of(t); types[i.entity] = i }
    }
    var identifier: String { base.identifier }
    var generation: Int { lock.lock(); defer { lock.unlock() }; return _generation }
    func ensure(_ info: _ModelInfo) { lock.lock(); types[info.entity] = info; lock.unlock() }

    func key(for id: PersistentIdentifier) -> Int64 {
        lock.lock(); defer { lock.unlock() }
        if let k = keys[id] { return k }
        nextKey += 1
        ids[nextKey] = id; keys[id] = nextKey
        return nextKey
    }
    func allocate(_ entity: String) -> Int64 {
        lock.lock(); defer { lock.unlock() }
        nextKey += 1
        // a temporary identifier until the store saves it
        let id = PersistentIdentifier(entityName: entity, storeIdentifier: nil, primaryKey: -(Int64(1) << 40) - nextKey)
        ids[nextKey] = id; keys[id] = nextKey
        return nextKey
    }
    func publicIdentifier(_ entity: String, _ pk: Int64) -> PersistentIdentifier {
        lock.lock(); defer { lock.unlock() }
        return ids[pk] ?? PersistentIdentifier(entityName: entity, storeIdentifier: nil, primaryKey: -(Int64(1) << 40) - pk)
    }
    func localKey(_ id: PersistentIdentifier) -> Int64? { lock.lock(); defer { lock.unlock() }; return keys[id] }

    /// a snapshot as a row with local keys
    private func row(_ snapshot: S.Snapshot) -> (String, Int64, [String: Any])? {
        let id = snapshot.persistentIdentifier
        guard let info = types[id.entityName], let j = (try? _jsonObject(snapshot)) as? [String: Any] else { return nil }
        var out: [String: Any] = [:]
        for p in info.properties {
            guard let v = j[p.name] else { continue }
            guard p.target != nil else { out[p.name] = v; continue }
            func k(_ x: Any) -> Any {
                guard !(x is NSNull), let i = try? _fromJSONObject(PersistentIdentifier.self, x) else { return NSNull() }
                return NSNumber(value: key(for: i))
            }
            out[p.name] = p.toMany ? ((v as? [Any]) ?? []).map(k) : k(v)
        }
        return (info.entity, key(for: id), out)
    }
    func rows(_ info: _ModelInfo) -> [(Int64, [String: Any])] {
        func fetch<T: PersistentModel>(_ t: T.Type) -> DataStoreFetchResult<T, S.Snapshot>? {
            do { return try base.fetch(DataStoreFetchRequest<T>(descriptor: FetchDescriptor<T>(), editingState: EditingState(author: nil))) } catch {
                NSLog("SwiftData: the %@ store's fetch of %@ failed: %@", identifier, info.entity, String(describing: error)); return nil
            }
        }
        func run<T: PersistentModel>(_ t: T.Type) -> [(Int64, [String: Any])] {
            guard let r = fetch(t) else { return [] }
            var out: [(Int64, [String: Any])] = []
            lock.lock(); defer { lock.unlock() }
            cache[info.entity] = [:]
            for s in r.fetchedSnapshots { if case let (e, k, v)? = row(s) { if e == info.entity { out.append((k, v)) }; cache[e, default: [:]][k] = v } }
            for s in r.relatedSnapshots.values { if case let (e, k, v)? = row(s) { cache[e, default: [:]][k] = v } }
            return out.sorted { $0.0 < $1.0 }
        }
        return run(info.type)
    }
    func row(_ info: _ModelInfo, _ pk: Int64) -> [String: Any]? {
        lock.lock()
        if let r = cache[info.entity]?[pk] { lock.unlock(); return r }
        lock.unlock()
        return rows(info).first { $0.0 == pk }?.1
    }

    func save(_ changes: _SaveSet, editing: EditingState) throws -> (any HistoryToken)? {
        func snap(_ s: _BackingStore) -> S.Snapshot? {
            guard let b = s as? any BackingData else { return nil }
            var related: [PersistentIdentifier: any BackingData] = [:]
            return S.Snapshot(from: b, relatedBackingDatas: &related)
        }
        let request = DataStoreSaveChangesRequest<S.Snapshot>(editingState: editing, inserted: changes.inserted.compactMap(snap),
                                                               updated: changes.updated.compactMap { snap($0.0) }, deleted: changes.deleted.compactMap { snap($0.0) })
        let result = try base.save(request)
        lock.lock()
        for (old, new) in result.remappedIdentifiers {
            guard let k = keys[old] else { continue }
            keys[old] = nil; keys[new] = k; ids[k] = new
        }
        for (s, _) in changes.deleted { if let k = s.pk, let id = ids[k] { cache[id.entityName]?[k] = nil } }
        lock.unlock()
        for s in result.snapshotsToReregister.values { if case let (e, k, v)? = row(s) { lock.lock(); cache[e, default: [:]][k] = v; lock.unlock() } }
        lock.lock(); _generation += 1; lock.unlock()
        return result.historyToken
    }
    func eraseAll() throws {
        try base.erase()
        lock.lock(); cache = [:]; _generation += 1; lock.unlock()
    }
    func observeCommits(_ f: @escaping (AnyObject?) -> Void) { lock.lock(); observers.append(f); lock.unlock() }
    func committed(by saver: AnyObject?) {
        lock.lock(); let list = observers; lock.unlock()
        for f in list { f(saver) }
    }
    func fetchHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws -> [T] {
        guard let h = base as? any HistoryProviding else { throw SwiftDataError.invalidTransactionFetchRequest }
        func run<H: HistoryProviding>(_ h: H) throws -> [T] {
            guard let d = descriptor as? HistoryDescriptor<H.HistoryType> else { throw SwiftDataError.invalidTransactionFetchRequest }
            return try h.fetchHistory(d) as? [T] ?? []
        }
        return try run(h)
    }
    func deleteHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws {
        guard let h = base as? any HistoryProviding else { throw SwiftDataError.invalidTransactionFetchRequest }
        func run<H: HistoryProviding>(_ h: H) throws {
            guard let d = descriptor as? HistoryDescriptor<H.HistoryType> else { throw SwiftDataError.invalidTransactionFetchRequest }
            try h.deleteHistory(d)
        }
        try run(h)
    }
    func batchDelete<T: PersistentModel>(_ request: DataStoreBatchDeleteRequest<T>) throws -> Bool {
        guard let b = base as? any DataStoreBatching else { return false }
        func run<B: DataStoreBatching>(_ b: B) throws { try b.delete(request) }
        do { try run(b) } catch DataStoreError.preferInMemoryFilter { return false }
        lock.lock(); cache[_ModelInfo.of(T.self).entity] = nil; _generation += 1; lock.unlock()
        return true
    }
    func initializeState(for editingState: EditingState) { base.initializeState(for: editingState) }
    func invalidateState(for editingState: EditingState) { base.invalidateState(for: editingState) }
}

/// opens a configuration's store for a container (the default store's configurations keep the SQLite store itself)
func _openStore<C: DataStoreConfiguration>(_ configuration: C, schema: Schema, plan: (any SchemaMigrationPlan.Type)?) throws -> any _Store {
    var c = configuration
    if c.schema == nil { c.schema = schema }
    try c.validate()
    let store = try C.Store(c, migrationPlan: plan)
    return _CustomStore(store, schema: c.schema ?? schema)
}
