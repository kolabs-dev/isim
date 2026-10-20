// isim SwiftData: ModelContext — one instance per stored model, the inserts, changes and deletes since the last save
// (with uniqueness upserts and delete rules), fetches from the store's rows plus pending changes, save and rollback,
// autosave — and ModelContainer, the store of its configuration and the main context.
import Foundation
import Combine
import Observation

/// a weak reference that can cross to the main queue (the context it holds is used there only)
struct _Weak<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ v: T) { value = v }
}

open class ModelContext: ObservableObject, Observable {
    public enum NotificationKey: String, Sendable {
        case queryGeneration, invalidatedAllIdentifiers, insertedIdentifiers, updatedIdentifiers, deletedIdentifiers, historyTokens
    }
    public static let willSave = Notification.Name("SwiftData.ModelContext.willSave")
    public static let didSave = Notification.Name("SwiftData.ModelContext.didSave")

    public let container: ModelContainer
    nonisolated let store: _SQLStore
    /// the models this context holds, by entity and primary key
    private var registered: [String: [Int64: AnyObject]] = [:]
    private var inserted: [AnyObject] = []
    private var dirty: [ObjectIdentifier: AnyObject] = [:]
    private var deleted: [AnyObject] = []
    /// deleted models whose `deny` relationships must be empty when saving
    private var denied: [(AnyObject, Int)] = []
    private var loaded: [String: Int] = [:]
    private let registrar = ObservationRegistrar()
    private var _changes = 0
    /// read inside fetch (SwiftUI's observation of @Query); bumped by every change
    var changes: Int {
        get { registrar.access(self, keyPath: \.changes); return _changes }
        set { registrar.withMutation(of: self, keyPath: \.changes) { _changes = newValue } }
    }
    public var autosaveEnabled = true
    public var author: String?
    public var undoManager: UndoManager?
    open var hasChanges: Bool { !inserted.isEmpty || !dirty.isEmpty || !deleted.isEmpty }

    public init(_ container: ModelContainer) {
        self.container = container
        store = container.store
        autosaveEnabled = false
    }
    init(main container: ModelContainer) {
        self.container = container
        store = container.store
        // saves of other contexts (a model actor's) refresh the main context's queries, as on iOS 18
        let me = _Weak(self)
        store.observeCommits { saver in
            guard let m = me.value, saver !== m else { return }
            DispatchQueue.main.async { guard let m = me.value else { return }; m.objectWillChange.send(); m.changes += 1 }
        }
    }

    // MARK: registry

    private func register(_ m: AnyObject, _ s: _BackingStore) {
        registered[s.info.entity, default: [:]][s.pk!] = m
        s.context = self; s.model = m
    }
    private func unregister(_ m: AnyObject) {
        let s = _store(m)
        if let k = s.pk, registered[s.info.entity]?[k] === m { registered[s.info.entity]?[k] = nil }
        s.context = nil
        dirty[ObjectIdentifier(m)] = nil
    }
    /// a stored model of this context, made from its row if no instance has it yet
    func _model(_ type: any PersistentModel.Type, _ key: Int64) -> AnyObject? {
        let info = _ModelInfo.of(type)
        if let m = registered[info.entity]?[key] { return _store(m).isDeleted ? nil : m }
        store.ensure(info)
        guard let row = store.row(info.entity, key) else { return nil }
        return materialize(type, info, key, row)
    }
    private func materialize(_ type: any PersistentModel.Type, _ info: _ModelInfo, _ key: Int64, _ row: [String: Any]) -> AnyObject {
        func make<M: PersistentModel>(_ t: M.Type) -> AnyObject {
            let b = _DefaultBackingData<M>(for: M.self)
            b.pk = key
            b.load(row)
            let m = M(backingData: b)
            return m
        }
        let m = make(type)
        register(m, _store(m))
        return m
    }
    /// brings the entity's registered models up to date with the store (rows other contexts saved)
    private func load(_ type: any PersistentModel.Type) {
        let info = _ModelInfo.of(type)
        store.ensure(info)
        guard loaded[info.entity] != store.generation else { return }
        loaded[info.entity] = store.generation
        let rows = store.rows(info.entity)
        var seen = Set<Int64>()
        for (key, row) in rows {
            seen.insert(key)
            if let m = registered[info.entity]?[key] {
                let s = _store(m)
                if !s.isDirty && !s.isInserted && !s.isDeleted { s.load(row) }
            } else {
                _ = materialize(type, info, key, row)
            }
        }
        for (key, m) in registered[info.entity] ?? [:] where !seen.contains(key) {
            let s = _store(m)
            if !s.isInserted && !s.isDirty { unregister(m) }
        }
    }

    // MARK: changes

    func _changed(_ m: AnyObject) {
        let s = _store(m)
        if !s.isInserted && !s.isDeleted { s.isDirty = true; dirty[ObjectIdentifier(m)] = m }
        changed()
    }
    private var saveScheduled = false
    /// autosave, as SwiftData's main context: after the current event (a rollback in the same turn still undoes)
    private func changed() {
        objectWillChange.send()
        changes += 1
        guard autosaveEnabled, !saveScheduled else { return }
        saveScheduled = true
        let me = _Weak(self)
        DispatchQueue.main.async {
            guard let self = me.value else { return }
            self.saveScheduled = false
            if self.autosaveEnabled && self.hasChanges { try? self.save() }
        }
    }

    open func insert<T: PersistentModel>(_ model: T) { _insertObject(model) }

    /// inserts a model and the models its relationships reach
    func _insertObject(_ m: AnyObject) {
        let s = _store(m)
        if s.context === self {
            if s.isDeleted, let i = deleted.firstIndex(where: { $0 === m }) { deleted.remove(at: i); s.isDeleted = false; changed() }
            return
        }
        guard s.context == nil else { NSLog("SwiftData: a model of another context was inserted into this one; ignored"); return }
        let info = s.info
        store.ensure(info)
        s.model = m
        if let (key, previous) = uniqueMatch(s) {
            // an upsert: the new model takes the stored model's place, with its values
            s.pk = key; s.isDirty = true
            register(m, s)
            // relationships the new model leaves empty keep the stored model's (their inverses now point to it)
            let row = previous == nil ? store.row(info.entity, key) : nil
            for (i, p) in info.properties.enumerated() where p.target != nil && s.objects(i).isEmpty {
                if let old = previous, old !== m {
                    let objs = _store(old).objects(i)
                    s.slots[i] = p.toMany ? .many(objs) : .one(objs.first)
                    if let inv = info.inverse(i) { for o in objs { _store(o).unlink(inv.index, old); _store(o).link(inv.index, m, me: o) } }
                } else if let v = row?[p.name] {
                    s.slots[i] = p.toMany ? .rawMany(((v as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.int64Value }) : .rawOne((v as? NSNumber)?.int64Value)
                }
            }
            if let p = previous, p !== m { _store(p).context = nil; dirty[ObjectIdentifier(p)] = nil; inserted.removeAll { $0 === p } }
            dirty[ObjectIdentifier(m)] = m
        } else {
            s.pk = store.allocate(info.entity)
            s.isInserted = true
            register(m, s)
            inserted.append(m)
        }
        s.adopt(m)
        for (i, p) in info.properties.enumerated() where p.target != nil {
            for o in s.objects(i) { _insertObject(o) }
        }
        changed()
    }

    /// the stored (or inserted) model whose unique values match the new one's
    private func uniqueMatch(_ s: _BackingStore) -> (Int64, AnyObject?)? {
        let info = s.info
        guard !info.uniques.isEmpty else { return nil }
        let keys = info.uniques.compactMap { list -> [String]? in
            let parts = list.compactMap { s.json($0).map(_jsonText) }
            return parts.count == list.count ? parts : nil
        }
        guard !keys.isEmpty else { return nil }
        func matches(_ value: (Int) -> Any?) -> Bool {
            for (n, list) in info.uniques.enumerated() where n < keys.count {
                if list.map({ value($0).map(_jsonText) ?? "\u{0}" }) == keys[n] { return true }
            }
            return false
        }
        for (key, m) in registered[info.entity] ?? [:] where m !== s.model && !_store(m).isDeleted {
            if matches({ _store(m).json($0) }) { return (key, m) }
        }
        for (key, row) in store.rows(info.entity) where registered[info.entity]?[key] == nil {
            if matches({ row[info.properties[$0].name] }) { return (key, nil) }
        }
        return nil
    }

    open func delete<T: PersistentModel>(_ model: T) { deleteObject(model) }

    private func deleteObject(_ m: AnyObject) {
        let s = _store(m)
        guard s.context === self, !s.isDeleted else { return }
        let info = s.info
        if s.isInserted, let i = inserted.firstIndex(where: { $0 === m }) { inserted.remove(at: i) } else { deleted.append(m) }
        s.isDeleted = true
        dirty[ObjectIdentifier(m)] = nil
        for (i, p) in info.properties.enumerated() where p.target != nil {
            let related = s.objects(i)
            switch p.relationship?.deleteRule ?? .nullify {
            case .cascade:
                if let inv = info.inverse(i) { for o in related { _store(o).unlink(inv.index, m) } }
                for o in related { deleteObject(o) }
            case .nullify:
                if let inv = info.inverse(i) { for o in related { _store(o).unlink(inv.index, m) } }
            case .deny:
                if !related.isEmpty { denied.append((m, i)) }
            case .noAction: break
            }
        }
        if s.isInserted { s.isInserted = false; unregister(m) }
        changed()
    }

    /// deletes the models of a type that match a predicate (all of them without one)
    open func delete<T: PersistentModel>(model: T.Type, where predicate: Predicate<T>? = nil, includeSubclasses: Bool = true) throws {
        for m in try fetch(FetchDescriptor<T>(predicate: predicate)) { delete(m) }
    }

    open func save() throws {
        guard hasChanges else { return }
        NotificationCenter.default.post(name: ModelContext.willSave, object: self)
        for (m, i) in denied where _store(m).isDeleted {
            if _store(m).objects(i).contains(where: { !_store($0).isDeleted }) {
                NSLog("SwiftData: %@ cannot be deleted: its %@ relationship (delete rule deny) is not empty", _store(m).info.entity, _store(m).info.properties[i].name)
                throw SwiftDataError.modelValidationFailure
            }
        }
        let ins = inserted, upd = Array(dirty.values), del = deleted
        if container.allowsSave {
            store.begin()
            do {
                for m in ins + upd { let s = _store(m); try store.put(s.info.entity, s.pk!, try s.row()) }
                for m in del { let s = _store(m); if let k = s.pk { store.remove(s.info.entity, k) } }
            } catch { store.abort(); throw error }
            store.commit()
        }
        for m in ins + upd { let s = _store(m); s.isInserted = false; s.isDirty = false; s.saved = s.slots }
        for m in del { unregister(m) }
        let ids = { (l: [AnyObject]) in l.map { _store($0).identifier } }
        let info: [String: Any] = [NotificationKey.insertedIdentifiers.rawValue: ids(ins), NotificationKey.updatedIdentifiers.rawValue: ids(upd),
                                   NotificationKey.deletedIdentifiers.rawValue: del.map { m -> PersistentIdentifier in
                                       let s = _store(m); return PersistentIdentifier(entityName: s.info.entity, storeIdentifier: store.identifier, primaryKey: s.pk ?? s.temporaryKey) }]
        inserted = []; dirty = [:]; deleted = []; denied = []
        for k in loaded.keys { loaded[k] = store.generation }
        objectWillChange.send()
        changes += 1
        store.committed(by: self)
        NotificationCenter.default.post(name: ModelContext.didSave, object: self, userInfo: info)
    }

    /// undoes the changes since the last save: inserted models leave, changed ones get their saved values back,
    /// deleted ones come back
    open func rollback() {
        for m in inserted { let s = _store(m); s.isInserted = false; unregister(m) }
        for m in dirty.values {
            let s = _store(m)
            if let saved = s.saved { s.slots = saved; s.isDirty = false } else { s.isDirty = false; unregister(m) }
        }
        for m in deleted {
            let s = _store(m)
            s.isDeleted = false
            if let saved = s.saved { s.slots = saved }
        }
        inserted = []; dirty = [:]; deleted = []; denied = []
        loaded = [:]
        objectWillChange.send()
        changes += 1
    }

    open func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T: PersistentModel {
        _ = changes
        load(T.self)
        let info = _ModelInfo.of(T.self)
        var list = (registered[info.entity] ?? [:]).sorted { $0.key < $1.key }.compactMap { $0.value as? T }
        list.removeAll { m in let s = m._store; return s.isDeleted || (!descriptor.includePendingChanges && s.isInserted) }
        if let p = descriptor.predicate { list = try list.filter { try p.evaluate($0) } }
        if !descriptor.sortBy.isEmpty { list.sort(using: descriptor.sortBy) }
        if let o = descriptor.fetchOffset, o > 0 { list = Array(list.dropFirst(o)) }
        if let limit = descriptor.fetchLimit { list = Array(list.prefix(limit)) }
        return list
    }
    open func fetchCount<T>(_ descriptor: FetchDescriptor<T>) throws -> Int where T: PersistentModel { try fetch(descriptor).count }
    open func fetchIdentifiers<T>(_ descriptor: FetchDescriptor<T>) throws -> [PersistentIdentifier] where T: PersistentModel {
        try fetch(descriptor).map(\.persistentModelID)
    }
    /// calls block with each matching model
    open func enumerate<T>(_ descriptor: FetchDescriptor<T>, batchSize: Int = 5000, allowEscapingMutations: Bool = false,
                           block: (T) throws -> Void) throws where T: PersistentModel {
        for m in try fetch(descriptor) { try block(m) }
    }
    /// runs block, then saves
    open func transaction(block: () throws -> Void) throws {
        try block()
        try save()
    }
    open func processPendingChanges() {}

    /// the model with that identifier in this context (a stored one is loaded)
    open func model(for id: PersistentIdentifier) -> any PersistentModel {
        if let m = _find(id) { return m }
        fatalError("SwiftData: no model with identifier \(id) in this context")
    }
    open func registeredModel<T: PersistentModel>(for id: PersistentIdentifier) -> T? {
        if id.isTemporary { return inserted.first { _store($0).identifier == id } as? T }
        return registered[id.entityName]?[id.id.primaryKey] as? T
    }
    func _find(_ id: PersistentIdentifier) -> (any PersistentModel)? {
        if let m = inserted.first(where: { _store($0).temporaryKey == id.id.primaryKey }) { return m as? any PersistentModel }
        if let m = registered[id.entityName]?[id.id.primaryKey] { return m as? any PersistentModel }
        guard let t = container.schema.types.first(where: { _ModelInfo.of($0).entity == id.entityName }) else { return nil }
        return _model(t, id.id.primaryKey) as? any PersistentModel
    }
    public var insertedModelsArray: [any PersistentModel] { inserted.compactMap { $0 as? any PersistentModel } }
    public var changedModelsArray: [any PersistentModel] { dirty.values.compactMap { $0 as? any PersistentModel } }
    public var deletedModelsArray: [any PersistentModel] { deleted.compactMap { $0 as? any PersistentModel } }

    /// forgets every model (ModelContainer.deleteAllData)
    func reset() {
        for (_, list) in registered { for (_, m) in list { _store(m).context = nil } }
        registered = [:]; inserted = []; dirty = [:]; deleted = []; denied = []; loaded = [:]
        objectWillChange.send()
        changes += 1
    }
}

open class ModelContainer: @unchecked Sendable {
    public let schema: Schema
    public let configurations: Set<ModelConfiguration>
    nonisolated let store: _SQLStore
    let allowsSave: Bool
    private var main: ModelContext?
    private let lock = NSLock()
    /// the context of the main actor (autosave on)
    @MainActor public var mainContext: ModelContext {
        lock.lock(); defer { lock.unlock() }
        if let m = main { return m }
        let m = ModelContext(main: self)
        main = m
        return m
    }

    public let migrationPlan: (any SchemaMigrationPlan.Type)?

    public required convenience init(for givenSchema: Schema, configurations: [ModelConfiguration] = []) throws {
        try self.init(for: givenSchema, migrationPlan: nil, configurations: configurations)
    }
    /// a container whose store is migrated with the plan to the schema's version
    public init(for givenSchema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration] = []) throws {
        schema = givenSchema
        self.migrationPlan = migrationPlan
        let config = configurations.first ?? ModelConfiguration(schema: givenSchema)
        self.configurations = Set(configurations.isEmpty ? [config] : configurations)
        store = try _SQLStore.store(for: config)
        allowsSave = config.allowsSave
        for t in givenSchema.types { store.ensure(_ModelInfo.of(t)) }
        try _Migration.run(store, schema: givenSchema, plan: migrationPlan, configuration: config)
    }
    public convenience init(for givenSchema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws {
        try self.init(for: givenSchema, migrationPlan: migrationPlan, configurations: configurations)
    }
    public convenience init(for modelType: any PersistentModel.Type, _ modelTypes: any PersistentModel.Type...,
                            migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws {
        try self.init(for: Schema([modelType] + modelTypes), migrationPlan: migrationPlan, configurations: configurations)
    }
    /// a container over one schema version's models, for a migration stage
    init(migrating schema: Schema, store: _SQLStore, configuration: ModelConfiguration) {
        self.schema = schema; self.store = store; migrationPlan = nil
        configurations = [configuration]; allowsSave = true
        for t in schema.types { store.ensure(_ModelInfo.of(t)) }
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
    /// removes every model from the store
    open func deleteAllData() {
        store.eraseAll()
        lock.lock(); let m = main; lock.unlock()
        m?.reset()
    }
    /// removes every model from the store (iOS 18)
    open func erase() throws { deleteAllData() }
    open func storeIdentifier(forConfigurationNamed name: String) -> String? {
        configurations.contains { $0.name == name } ? store.identifier : nil
    }
    open func configurationName(forStoreIdentifier id: String) -> String? {
        id == store.identifier ? configurations.first?.name : nil
    }
}
