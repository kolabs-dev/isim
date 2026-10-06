// Core Data self-test on isim: models (code + compiled .xcdatamodeld with codegen), SQLite and in-memory stores,
// @NSManaged accessors, relationships and delete rules, validation, fetching (SQL and in-memory predicates),
// contexts (child, background, merging, merge policies), batch requests, NSFetchedResultsController,
// migration. Prints PASS/FAIL per check and "coredata test: N/M passed" last; exits non-zero on failure.
import Foundation
import CoreData

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
/// Lets main-queue work (perform blocks, merges, change notifications) run.
func spin(_ seconds: Double = 0.2) { RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds)) }
func waitFor(_ timeout: Double = 5, _ cond: () -> Bool) -> Bool {
    let end = Date(timeIntervalSinceNow: timeout)
    while !cond() && Date() < end { spin(0.02) }
    return cond()
}
let storeDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("coredata-test")

@main struct Main {
    static func main() {
        try? FileManager.default.removeItem(atPath: storeDir.path)
        try? FileManager.default.createDirectory(atPath: storeDir.path, withIntermediateDirectories: true, attributes: nil)
        valueTransformerTests()
        programmaticModelTests()
        compiledModelTests()
        relationshipTests()
        fetchTests()
        contextTests()
        batchTests()
        fetchedResultsControllerTests()
        migrationTests()
        asyncTests()
        print("coredata test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
