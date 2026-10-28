// isim SwiftData: the store — an SQLite database (the SQLite isim's Core Data uses) with one table per entity, each row
// a model's primary key and its values as JSON (attributes as their Codable encoding, relationships as primary keys).
// #Index and unique attributes get SQLite indexes on the JSON values. Containers on the same file share one store.
// Each save also records a history transaction (isim_history: author, time, bundle, process, and its changes as JSON).
// _Store is what a context works with: this store, or an app's DataStore (_CustomStore, DataStore.swift).
import Foundation
import SQLite3

/// the changes a context saves: inserted and updated models (with the names of the properties that changed) and
/// deleted ones (with their tombstone: the values of attributes marked .preserveValueOnDeletion)
struct _SaveSet {
    var inserted: [_BackingStore] = []
    var updated: [(_BackingStore, [String])] = []
    var deleted: [(_BackingStore, [String: Any])] = []
    var isEmpty: Bool { inserted.isEmpty && updated.isEmpty && deleted.isEmpty }
}

protocol _Store: AnyObject, Sendable {
    var identifier: String { get }
    /// bumped by every save, so contexts know to reload rows
    var generation: Int { get }
    func ensure(_ info: _ModelInfo)
    /// the entity's models as rows: attributes as JSON fragments, relationships as (local) primary keys
    func rows(_ info: _ModelInfo) -> [(Int64, [String: Any])]
    func row(_ info: _ModelInfo, _ pk: Int64) -> [String: Any]?
    /// a primary key for a new model
    func allocate(_ entity: String) -> Int64
    func save(_ changes: _SaveSet, editing: EditingState) throws -> (any HistoryToken)?
    func eraseAll() throws
    func observeCommits(_ f: @escaping (AnyObject?) -> Void)
    func committed(by saver: AnyObject?)
    /// the identifier apps see for a model, and back
    func publicIdentifier(_ entity: String, _ pk: Int64) -> PersistentIdentifier
    func localKey(_ id: PersistentIdentifier) -> Int64?
    func fetchHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws -> [T]
    func deleteHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws
    /// deletes in the store without loading the models; false when the store cannot (the context deletes them)
    func batchDelete<T: PersistentModel>(_ request: DataStoreBatchDeleteRequest<T>) throws -> Bool
    func initializeState(for editingState: EditingState)
    func invalidateState(for editingState: EditingState)
}

/// a history descriptor's predicate, sort and limit over a store's transactions
func _applyHistory<T>(_ list: [T], _ d: HistoryDescriptor<T>) throws -> [T] {
    var l = list
    if let p = d.predicate { l = try l.filter { try p.evaluate($0) } }
    if !d.sortBy.isEmpty { l.sort(using: d.sortBy) }
    if d.fetchLimit > 0 { l = Array(l.prefix(Int(clamping: d.fetchLimit))) }
    return l
}

final class _SQLStore: _Store, @unchecked Sendable {
    let path: String
    private(set) var identifier = ""
    private var db: OpaquePointer?
    /// bumped by every save, so contexts know to reload rows
    var generation: Int { _SQLStore.lock.lock(); defer { _SQLStore.lock.unlock() }; return _generation }
    private var _generation = 0
    private func bump() { _SQLStore.lock.lock(); _generation += 1; _SQLStore.lock.unlock() }
    private var next: [String: Int64] = [:]
    private var tables: Set<String> = []
    private static let lock = NSLock()
    nonisolated(unsafe) private static var open: [String: _SQLStore] = [:]
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// the store of a configuration: shared per file, a new one for each in-memory configuration
    static func store(for c: ModelConfiguration) throws -> _SQLStore {
        if c.isStoredInMemoryOnly { return try _SQLStore(path: ":memory:") }
        lock.lock(); defer { lock.unlock() }
        let path = c.url.standardizedFileURL.path
        if let s = open[path] { return s }
        try? FileManager.default.createDirectory(at: c.url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        let s = try _SQLStore(path: path)
        open[path] = s
        return s
    }

    private init(path: String) throws {
        self.path = path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            NSLog("SwiftData: cannot open the store at %@: %@", path, db.map { String(cString: sqlite3_errmsg($0)) } ?? "?")
            throw SwiftDataError.loadIssueModelContainer
        }
        _ = exec("PRAGMA journal_mode=WAL")
        _ = exec("CREATE TABLE IF NOT EXISTS isim_meta (key TEXT PRIMARY KEY, value TEXT)")
        _ = exec("CREATE TABLE IF NOT EXISTS isim_history (tx INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, timestamp REAL, bundle TEXT, process TEXT, changes TEXT)")
        var id: String?
        query("SELECT value FROM isim_meta WHERE key = 'identifier'") { s in id = String(cString: sqlite3_column_text(s, 0)) }
        if id == nil {
            id = UUID().uuidString
            run("INSERT INTO isim_meta (key, value) VALUES ('identifier', ?)") { sqlite3_bind_text($0, 1, id!, -1, _SQLStore.transient) }
        }
        identifier = id!
    }
    deinit { sqlite3_close(db) }

    static func table(_ entity: String) -> String { "\"Z_\(entity)\"" }

    @discardableResult func exec(_ sql: String) -> Bool {
        var err: UnsafeMutablePointer<CChar>?
        let ok = sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK
        if !ok { NSLog("SwiftData: SQLite: %@ (%@)", err.map { String(cString: $0) } ?? "?", sql); sqlite3_free(err) }
        return ok
    }
    private func query(_ sql: String, bind: (OpaquePointer?) -> Void = { _ in }, row: (OpaquePointer?) -> Void) {
        var s: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK else { NSLog("SwiftData: SQLite: %@ (%@)", String(cString: sqlite3_errmsg(db)), sql); return }
        defer { sqlite3_finalize(s) }
        bind(s)
        while sqlite3_step(s) == SQLITE_ROW { row(s) }
    }
    @discardableResult private func run(_ sql: String, bind: (OpaquePointer?) -> Void) -> Bool {
        var s: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK else { NSLog("SwiftData: SQLite: %@ (%@)", String(cString: sqlite3_errmsg(db)), sql); return false }
        defer { sqlite3_finalize(s) }
        bind(s)
        let r = sqlite3_step(s)
        if r != SQLITE_DONE { NSLog("SwiftData: SQLite: %@ (%@)", String(cString: sqlite3_errmsg(db)), sql) }
        return r == SQLITE_DONE
    }

    /// the schema version the store was last opened with (nil: a new store)
    var version: Schema.Version? {
        get {
            var v: String?
            query("SELECT value FROM isim_meta WHERE key = 'version'") { v = String(cString: sqlite3_column_text($0, 0)) }
            let n = (v ?? "").split(separator: ".").compactMap { Int($0) }
            return n.count == 3 ? Schema.Version(n[0], n[1], n[2]) : nil
        }
        set {
            guard let v = newValue else { return }
            run("INSERT OR REPLACE INTO isim_meta (key, value) VALUES ('version', ?)") { sqlite3_bind_text($0, 1, v.description, -1, _SQLStore.transient) }
        }
    }

    /// called after each save (on the saving thread), with the context that saved
    private var observers: [(AnyObject?) -> Void] = []
    func observeCommits(_ f: @escaping (AnyObject?) -> Void) { _SQLStore.lock.lock(); observers.append(f); _SQLStore.lock.unlock() }
    func committed(by saver: AnyObject?) {
        _SQLStore.lock.lock(); let list = observers; _SQLStore.lock.unlock()
        for f in list { f(saver) }
    }

    /// the entity's table, and its indexes (#Index, unique attributes and #Unique constraints)
    func ensure(_ info: _ModelInfo) {
        _SQLStore.lock.lock(); defer { _SQLStore.lock.unlock() }
        guard tables.insert(info.entity).inserted else { return }
        let t = _SQLStore.table(info.entity)
        exec("CREATE TABLE IF NOT EXISTS \(t) (pk INTEGER PRIMARY KEY, data TEXT NOT NULL)")
        for (n, list) in (info.indexes + info.uniques).enumerated() {
            let cols = list.map { "json_extract(data, '$.\"\(info.properties[$0].name)\"')" }.joined(separator: ", ")
            exec("CREATE INDEX IF NOT EXISTS \"Z_\(info.entity)_I\(n)\" ON \(t) (\(cols))")
        }
    }

    func rows(_ info: _ModelInfo) -> [(Int64, [String: Any])] { rows(info.entity) }
    func row(_ info: _ModelInfo, _ pk: Int64) -> [String: Any]? { row(info.entity, pk) }
    func publicIdentifier(_ entity: String, _ pk: Int64) -> PersistentIdentifier {
        PersistentIdentifier(entityName: entity, storeIdentifier: identifier, primaryKey: pk)
    }
    func localKey(_ id: PersistentIdentifier) -> Int64? { id.id.key == nil ? id.id.primaryKey : nil }
    func initializeState(for editingState: EditingState) {}
    func invalidateState(for editingState: EditingState) {}
    func batchDelete<T: PersistentModel>(_ request: DataStoreBatchDeleteRequest<T>) throws -> Bool { false }

    func rows(_ entity: String) -> [(Int64, [String: Any])] {
        var out: [(Int64, [String: Any])] = []
        query("SELECT pk, data FROM \(_SQLStore.table(entity)) ORDER BY pk") { s in
            let pk = sqlite3_column_int64(s, 0)
            let text = String(cString: sqlite3_column_text(s, 1))
            out.append((pk, (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]))
        }
        return out
    }
    func row(_ entity: String, _ pk: Int64) -> [String: Any]? {
        var out: [String: Any]?
        query("SELECT data FROM \(_SQLStore.table(entity)) WHERE pk = ?", bind: { sqlite3_bind_int64($0, 1, pk) }) { s in
            out = (try? JSONSerialization.jsonObject(with: Data(String(cString: sqlite3_column_text(s, 0)).utf8))) as? [String: Any]
        }
        return out
    }
    /// a primary key for a new model
    func allocate(_ entity: String) -> Int64 {
        _SQLStore.lock.lock(); defer { _SQLStore.lock.unlock() }
        if next[entity] == nil {
            var m: Int64 = 0
            query("SELECT MAX(pk) FROM \(_SQLStore.table(entity))") { m = sqlite3_column_int64($0, 0) }
            next[entity] = m + 1
        }
        let k = next[entity]!
        next[entity] = k + 1
        return k
    }

    /// writes a context's changes in one SQLite transaction, with their history transaction
    func save(_ changes: _SaveSet, editing: EditingState) throws -> (any HistoryToken)? {
        begin()
        do {
            for s in changes.inserted { try put(s.info.entity, s.pk!, try s.row()) }
            for (s, _) in changes.updated { try put(s.info.entity, s.pk!, try s.row()) }
            for (s, _) in changes.deleted { if let k = s.pk { remove(s.info.entity, k) } }
        } catch { abort(); throw error }
        var list: [[String: Any]] = changes.inserted.map { ["k": "i", "e": $0.info.entity, "p": NSNumber(value: $0.pk!)] as [String: Any] }
        list += changes.updated.map { ["k": "u", "e": $0.0.info.entity, "p": NSNumber(value: $0.0.pk!), "a": $0.1] as [String: Any] }
        list += changes.deleted.compactMap { d in d.0.pk.map { ["k": "d", "e": d.0.info.entity, "p": NSNumber(value: $0), "t": d.1] as [String: Any] } }
        let token = record(list, author: editing.author)
        commit()
        return token
    }

    // MARK: history

    /// records a transaction (inside the save's SQLite transaction); its token
    func record(_ changes: [[String: Any]], author: String?) -> DefaultHistoryToken? {
        guard !changes.isEmpty, let d = try? JSONSerialization.data(withJSONObject: changes, options: [.sortedKeys]) else { return nil }
        let text = String(data: d, encoding: .utf8) ?? "[]"
        let bundle = Bundle.main.bundleIdentifier ?? "", process = String(ProcessInfo.processInfo.processIdentifier)
        run("INSERT INTO isim_history (author, timestamp, bundle, process, changes) VALUES (?, ?, ?, ?, ?)") { s in
            if let author { sqlite3_bind_text(s, 1, author, -1, _SQLStore.transient) } else { sqlite3_bind_null(s, 1) }
            sqlite3_bind_double(s, 2, Date().timeIntervalSinceReferenceDate)
            sqlite3_bind_text(s, 3, bundle, -1, _SQLStore.transient)
            sqlite3_bind_text(s, 4, process, -1, _SQLStore.transient)
            sqlite3_bind_text(s, 5, text, -1, _SQLStore.transient)
        }
        return DefaultHistoryToken(storeIdentifier: identifier, tokenValue: sqlite3_last_insert_rowid(db))
    }
    /// every recorded transaction, oldest first, with its changes typed by the schema's models (changes to models
    /// the schema does not have are left out)
    func history(schema: Schema) -> [DefaultHistoryTransaction] {
        var types: [String: any PersistentModel.Type] = [:]
        for t in schema.types { types[_ModelInfo.of(t).entity] = t }
        var out: [DefaultHistoryTransaction] = []
        query("SELECT tx, author, timestamp, bundle, process, changes FROM isim_history ORDER BY tx") { s in
            let tx = sqlite3_column_int64(s, 0)
            let author = sqlite3_column_type(s, 1) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(s, 1))
            let when = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(s, 2))
            let bundle = String(cString: sqlite3_column_text(s, 3)), process = String(cString: sqlite3_column_text(s, 4))
            let list = (try? JSONSerialization.jsonObject(with: Data(String(cString: sqlite3_column_text(s, 5)).utf8))) as? [[String: Any]] ?? []
            var changes: [HistoryChange] = []
            for (n, c) in list.enumerated() {
                guard let e = c["e"] as? String, let t = types[e], let pk = (c["p"] as? NSNumber)?.int64Value else { continue }
                let id = publicIdentifier(e, pk), change = (tx << 20) | Int64(n)
                func make<M: PersistentModel>(_ m: M.Type) -> HistoryChange? {
                    switch c["k"] as? String {
                    case "i": return .insert(DefaultHistoryInsert<M>(changeIdentifier: change, transactionIdentifier: tx, changedPersistentIdentifier: id))
                    case "u":
                        let info = _ModelInfo.of(M.self)
                        let paths = ((c["a"] as? [String]) ?? []).compactMap { info.byName[$0] }.map { info.properties[$0].keyPath }
                        return .update(DefaultHistoryUpdate<M>(changeIdentifier: change, transactionIdentifier: tx, changedPersistentIdentifier: id,
                                                               updatedAttributes: paths.compactMap { _sendablePath($0, M.self) }))
                    case "d":
                        return .delete(DefaultHistoryDelete<M>(changeIdentifier: change, transactionIdentifier: tx, changedPersistentIdentifier: id,
                                                               tombstone: HistoryTombstone<M>(json: (c["t"] as? [String: Any]) ?? [:])))
                    default: return nil
                    }
                }
                if let ch = make(t) { changes.append(ch) }
            }
            out.append(DefaultHistoryTransaction(transactionIdentifier: tx, changes: changes, storeIdentifier: identifier, author: author,
                                                 timestamp: when, token: DefaultHistoryToken(storeIdentifier: identifier, tokenValue: tx),
                                                 bundleIdentifier: bundle, processIdentifier: process))
        }
        return out
    }
    func fetchHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws -> [T] {
        guard let list = history(schema: schema) as? [T] else { throw SwiftDataError.invalidTransactionFetchRequest }
        return try _applyHistory(list, descriptor)
    }
    func deleteHistory<T: HistoryTransaction>(_ descriptor: HistoryDescriptor<T>, schema: Schema) throws {
        let gone = try fetchHistory(descriptor, schema: schema).compactMap { ($0 as? DefaultHistoryTransaction)?.transactionIdentifier }
        guard !gone.isEmpty else { return }
        begin()
        for tx in gone { run("DELETE FROM isim_history WHERE tx = ?") { sqlite3_bind_int64($0, 1, tx) } }
        exec("COMMIT")
    }

    func begin() { exec("BEGIN IMMEDIATE") }
    func commit() { exec("COMMIT"); bump() }
    func abort() { exec("ROLLBACK") }
    func put(_ entity: String, _ pk: Int64, _ values: [String: Any]) throws {
        let d = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
        let text = String(data: d, encoding: .utf8) ?? "{}"
        run("INSERT OR REPLACE INTO \(_SQLStore.table(entity)) (pk, data) VALUES (?, ?)") {
            sqlite3_bind_int64($0, 1, pk); sqlite3_bind_text($0, 2, text, -1, _SQLStore.transient)
        }
    }
    func remove(_ entity: String, _ pk: Int64) {
        run("DELETE FROM \(_SQLStore.table(entity)) WHERE pk = ?") { sqlite3_bind_int64($0, 1, pk) }
    }
    /// every model of every entity (ModelContainer.deleteAllData)
    func eraseAll() {
        exec("DELETE FROM isim_history")
        var names: [String] = []
        query("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Z\\_%' ESCAPE '\\'") { names.append(String(cString: sqlite3_column_text($0, 0))) }
        for n in names { exec("DELETE FROM \"\(n)\"") }
        _SQLStore.lock.lock(); next = [:]; _SQLStore.lock.unlock()
        bump()
    }
}
