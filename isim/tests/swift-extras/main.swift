// SwiftExtrasTest: Combine operators, Dispatch sources / DispatchIO / DispatchData, Synchronization,
// Distributed actors. Last line: "swift extras test: N/M passed".
import Foundation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func check(_ ok: Bool, _ what: @autoclosure () -> String) {
    checks += 1
    if ok { print("PASS  \(what())") } else { failures += 1; print("FAIL  \(what())") }
}
/// Blocks the calling thread (never the queues under test).
func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

@main struct Main {
    static func main() async {
        print("--- Combine"); combineTests(); await combineAsyncTests()
        print("--- Dispatch"); dispatchTests()
        print("--- Synchronization")
        if #available(iOS 18.0, *) { synchronizationTests() } else { check(false, "Synchronization needs iOS 18 (isim device OS too old)") }
        print("--- Distributed"); await distributedTests()
        print("swift extras test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
