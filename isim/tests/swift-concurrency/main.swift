// Swift Concurrency self-test on isim: async main, tasks, sleep, task groups, actors,
// MainActor, continuations, AsyncStream, cancellation, task locals.
import Foundation
import Dispatch

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

let queueKey = DispatchSpecificKey<String>()
/// an actor whose jobs run on a DispatchSerialQueue (its SerialExecutor)
actor QueueActor {
    let queue: DispatchSerialQueue
    var count = 0
    init(queue: DispatchSerialQueue) { self.queue = queue }
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    func bump() -> (Int, String?) { count += 1; return (count, DispatchQueue.getSpecific(key: queueKey)) }
}

/// Dispatch's queue kinds from Swift: targets, asyncAndWait, inactive queues, workloops (issue #268)
func dispatchQueueChecks() {
    let parent = DispatchSerialQueue(label: "isim.parent")
    parent.setSpecific(key: queueKey, value: "parent")
    let child = DispatchQueue(label: "isim.child")
    child.setTarget(queue: parent)
    check(child.sync { DispatchQueue.getSpecific(key: queueKey) } == "parent", "setTarget(queue:): the child runs through its target")
    let concurrent = DispatchConcurrentQueue(label: "isim.concurrent", target: parent)
    nonisolated(unsafe) var inside = 0, overlap = false
    let group = DispatchGroup()
    for _ in 0..<20 {
        concurrent.async(group: group) { inside += 1; if inside > 1 { overlap = true }; usleep(100); inside -= 1 }
    }
    check(group.wait(timeout: .now() + 10) == .success && !overlap, "DispatchConcurrentQueue targeting a serial queue is serialized by it")
    let value = parent.asyncAndWait { DispatchQueue.getSpecific(key: queueKey) ?? "none" }
    check(value == "parent", "asyncAndWait runs on the queue and returns its result")
    nonisolated(unsafe) var itemRan = false
    parent.asyncAndWait(execute: DispatchWorkItem { itemRan = true })
    parent.asyncAndWait { itemRan = itemRan && DispatchQueue.getSpecific(key: queueKey) == "parent" }
    check(itemRan, "asyncAndWait(execute:) with a work item and a closure")
    let idleSerial = DispatchSerialQueue(label: "isim.idle.serial", attributes: .initiallyInactive)
    nonisolated(unsafe) var serialEarly = false
    idleSerial.async { serialEarly = true }
    usleep(20_000)
    let wasEarly = serialEarly
    idleSerial.activate()
    idleSerial.sync {}
    check(!wasEarly && serialEarly, "DispatchSerialQueue.Attributes.initiallyInactive")
    nonisolated(unsafe) var early = false
    let idle = DispatchQueue(label: "isim.idle", attributes: .initiallyInactive)
    idle.async { early = true }
    usleep(30_000)
    check(!early, ".initiallyInactive queues wait for activate()")
    idle.activate()
    idle.sync {}
    check(early, "activate() starts an inactive queue")
    let loop = DispatchWorkloop(label: "isim.workloop", autoreleaseFrequency: .workItem)
    nonisolated(unsafe) var order: [Int] = []
    for i in 0..<5 { loop.async { order.append(i) } }
    loop.sync {}
    check(order == [0, 1, 2, 3, 4] && loop.label == "isim.workloop", "DispatchWorkloop runs its items one at a time")
    let serial: DispatchQueue = DispatchSerialQueue(label: "isim.serial")
    check(serial is DispatchSerialQueue && serial.label == "isim.serial", "DispatchSerialQueue is a DispatchQueue")
}

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

        // an actor on a DispatchSerialQueue
        let actorQueue = DispatchSerialQueue(label: "isim.actor")
        actorQueue.setSpecific(key: queueKey, value: "actor")
        let qa = QueueActor(queue: actorQueue)
        let (n, where_) = await qa.bump()
        check(n == 1 && where_ == "actor", "an actor's jobs run on its DispatchSerialQueue (unownedExecutor)")
        let isolated = actorQueue.sync { qa.assumeIsolated { $0.count == 1 } }
        check(isolated, "assumeIsolated on the actor's queue (DispatchSerialQueue.checkIsolated)")
        let counts = await withTaskGroup(of: Int.self) { g in
            for _ in 0..<20 { g.addTask { await qa.bump().0 } }
            var all: [Int] = []
            for await c in g { all.append(c) }
            return all
        }
        check(Set(counts) == Set(2...21), "the actor's jobs are serialized on the queue")
        dispatchQueueChecks()

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
