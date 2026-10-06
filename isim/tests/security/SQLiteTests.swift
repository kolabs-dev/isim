// SQLite3 C API from Swift (forwarded to the host's libsqlite3): files in the app container, binds, steps, errors.
import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func sqliteTests() {
    let path = NSTemporaryDirectory() + "isim-sqlite-test.db"
    unlink(path)
    var db: OpaquePointer?
    check(sqlite3_open(path, &db) == SQLITE_OK && db != nil, "sqlite3_open creates a database file")
    defer { sqlite3_close(db); unlink(path) }
    check(String(cString: sqlite3_libversion()).hasPrefix("3.") && sqlite3_libversion_number() >= 3_037_000, "sqlite3_libversion \(String(cString: sqlite3_libversion()))")
    check(sqlite3_exec(db, "CREATE TABLE notes(id INTEGER PRIMARY KEY, title TEXT NOT NULL, score REAL, blob BLOB)", nil, nil, nil) == SQLITE_OK, "CREATE TABLE via sqlite3_exec")

    var stmt: OpaquePointer?
    check(sqlite3_prepare_v2(db, "INSERT INTO notes(title, score, blob) VALUES (?, ?, ?)", -1, &stmt, nil) == SQLITE_OK, "sqlite3_prepare_v2 INSERT")
    let titles = ["first", "second ✓", "third"]
    var ok = true
    for (i, t) in titles.enumerated() {
        sqlite3_bind_text(stmt, 1, t, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, Double(i) + 0.5)
        let bytes: [UInt8] = [0xde, 0xad, UInt8(i)]
        bytes.withUnsafeBytes { _ = sqlite3_bind_blob(stmt, 3, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT) }
        ok = ok && sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_reset(stmt)
    }
    sqlite3_finalize(stmt)
    check(ok && sqlite3_last_insert_rowid(db) == 3 && sqlite3_changes(db) == 1, "bound inserts (text, double, blob) + last_insert_rowid")

    var rows: [String] = []
    if sqlite3_prepare_v2(db, "SELECT id, title, score, blob FROM notes WHERE score > ? ORDER BY id DESC", -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_double(stmt, 1, 1.0)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let score = sqlite3_column_double(stmt, 2)
            let n = Int(sqlite3_column_bytes(stmt, 3))
            let blob = Array(UnsafeRawBufferPointer(start: sqlite3_column_blob(stmt, 3), count: n))
            rows.append("\(id):\(title):\(score):\(blob.last ?? 255)")
        }
    }
    sqlite3_finalize(stmt)
    check(rows == ["3:third:2.5:2", "2:second ✓:1.5:1"], "SELECT with a bound parameter and column readers (\(rows))")

    var count = 0
    let cb: @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 = { ctx, n, values, _ in
        ctx!.assumingMemoryBound(to: Int.self).pointee += 1
        return 0
    }
    sqlite3_exec(db, "SELECT * FROM notes", cb, &count, nil)
    check(count == 3, "sqlite3_exec callback runs per row")

    check(sqlite3_exec(db, "INSERT INTO notes(title) VALUES (NULL)", nil, nil, nil) == SQLITE_CONSTRAINT, "NOT NULL constraint error")
    check(String(cString: sqlite3_errmsg(db)).hasPrefix("NOT NULL"), "sqlite3_errmsg: \(String(cString: sqlite3_errmsg(db)))")
    check(sqlite3_prepare_v2(db, "SELEKT 1", -1, &stmt, nil) == SQLITE_ERROR, "syntax errors from sqlite3_prepare_v2")

    sqlite3_exec(db, "BEGIN", nil, nil, nil)
    sqlite3_exec(db, "DELETE FROM notes", nil, nil, nil)
    sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
    var n: Int32 = -1
    if sqlite3_prepare_v2(db, "SELECT count(*) FROM notes", -1, &stmt, nil) == SQLITE_OK, sqlite3_step(stmt) == SQLITE_ROW { n = sqlite3_column_int(stmt, 0) }
    sqlite3_finalize(stmt)
    check(n == 3, "transactions roll back")

    sqlite3_close(db); db = nil
    check(sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, "reopen read-only (data persisted in the file)")
    check(sqlite3_exec(db, "DELETE FROM notes", nil, nil, nil) == SQLITE_READONLY, "read-only database refuses writes")
}
