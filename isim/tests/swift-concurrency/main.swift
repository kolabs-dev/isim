// Swift Concurrency self-test on isim: async main, tasks, sleep, task groups, actors,
// MainActor, continuations, AsyncStream, cancellation, task locals.
import Foundation

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

actor Counter {
    var value = 0
    func increment() -> Int { value += 1; return value }
}

@MainActor final class Model {
    var log: [String] = []
    func record(_ s: String) { log.append(s) }
}

enum Trace { @TaskLocal static var id = "none" }

func slowSquare(_ x: Int) async -> Int {
    try? await Task.sleep(nanoseconds: 10_000_000)
    return x * x
}

@main struct Main {
    static func main() async {
        // basic await + child task
        let t = Task { await slowSquare(7) }
        check(await t.value == 49, "Task + await value")

        // sleep with Duration
        let clock = ContinuousClock()
        let start = clock.now
        try? await Task.sleep(for: .milliseconds(120))
        let elapsed = clock.now - start
        check(elapsed >= .milliseconds(110) && elapsed < .seconds(2), "Task.sleep(for:) ≈ 120ms (got \(elapsed))")

        // task group
        let sum = await withTaskGroup(of: Int.self) { group in
            for i in 1...10 { group.addTask { await slowSquare(i) } }
            var s = 0
            for await v in group { s += v }
            return s
        }
        check(sum == 385, "withTaskGroup sums squares (385)")

        // actor isolation under concurrency
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 { group.addTask { _ = await counter.increment() } }
        }
        check(await counter.value == 200, "actor serializes 200 concurrent increments")

        // MainActor hop
        let model = Model()
        model.record("a")
        await MainActor.run { model.record("b") }
        check(model.log == ["a", "b"], "MainActor isolation + MainActor.run")
        let onMain = await MainActor.run { Thread.isMainThread }
        check(onMain, "MainActor runs on the main thread")

        // continuation bridging a callback API (dispatch)
        let v: Int = await withCheckedContinuation { cont in
            DispatchQueue_global_after(0.05) { cont.resume(returning: 42) }
        }
        check(v == 42, "withCheckedContinuation resumed from a dispatch callback")

        // AsyncStream
        let stream = AsyncStream<Int> { c in
            Task { for i in 1...5 { c.yield(i); try? await Task.sleep(nanoseconds: 1_000_000) }; c.finish() }
        }
        var got: [Int] = []
        for await x in stream { got.append(x) }
        check(got == [1, 2, 3, 4, 5], "AsyncStream yields in order")

        // cancellation
        let long = Task { () -> Bool in
            do { try await Task.sleep(for: .seconds(10)); return false } catch { return error is CancellationError }
        }
        try? await Task.sleep(for: .milliseconds(20))
        long.cancel()
        check(await long.value, "cancellation interrupts Task.sleep")

        // task locals
        let seen = await Trace.$id.withValue("req-1") { await Task { Trace.id }.value }
        check(seen == "req-1", "TaskLocal inherited by child Task")

        // async let
        async let a = slowSquare(3)
        async let b = slowSquare(4)
        check(await a + b == 25, "async let")

        print("swift concurrency test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}

/* small dispatch helper via the C API (isim has no Swift Dispatch overlay yet) */
func DispatchQueue_global_after(_ seconds: Double, _ work: @escaping @Sendable () -> Void) {
    let box = Unmanaged.passRetained(WorkBox(work)).toOpaque()
    dispatch_after_f(dispatch_time(UInt64(DISPATCH_TIME_NOW), Int64(seconds * 1e9)), dispatch_get_global_queue(0, 0), box) { p in
        let b = Unmanaged<WorkBox>.fromOpaque(p!).takeRetainedValue()
        b.work()
    }
}
final class WorkBox: @unchecked Sendable { let work: @Sendable () -> Void; init(_ w: @escaping @Sendable () -> Void) { work = w } }
