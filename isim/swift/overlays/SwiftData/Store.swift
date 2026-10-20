// isim SwiftData: the store — an SQLite database (the SQLite isim's Core Data uses) with one table per entity, each row
// a model's primary key and its values as JSON (attributes as their Codable encoding, relationships as primary keys).
// #Index and unique attributes get SQLite indexes on the JSON values. Containers on the same file share one store.
import Foundation
import SQLite3

final class _SQLStore: @unchecked Sendable {
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
        var names: [String] = []
        query("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Z\\_%' ESCAPE '\\'") { names.append(String(cString: sqlite3_column_text($0, 0))) }
        for n in names { exec("DELETE FROM \"\(n)\"") }
        _SQLStore.lock.lock(); next = [:]; _SQLStore.lock.unlock()
        bump()
    }
}
