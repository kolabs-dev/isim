// Swift 6.2 self-test: Span, MutableSpan, RawSpan (back-deployed like Apple's: ContiguousArray's spans run on every
// iOS, Array / String / InlineArray spans need iOS 26), InlineArray and Observations (iOS 26), TaskExecutor and
// withTaskExecutorPreference (iOS 18). Checks newer than the selected --os are skipped, like on a device; the
// "available:" line says which ran. Last line: "swift 6.2 test: N/M passed".
import Foundation
import Observation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func check(_ ok: Bool, _ what: @autoclosure () -> String) {
    checks += 1
    if ok { print("PASS  \(what())") } else { failures += 1; print("FAIL  \(what())") }
}

func spanTests() {
    var numbers: ContiguousArray<Int> = [3, 1, 4, 1, 5]
    readSpanTests(numbers)
    mutableSpanTests(&numbers)
    check(Array(numbers) == [5, 9, 40, 1, 3], "MutableSpan writes reach the array")
}

func readSpanTests(_ numbers: ContiguousArray<Int>) {
    let span = numbers.span
    check(span.count == 5 && !span.isEmpty, "Span count / isEmpty")
    check(span[0] == 3 && span[4] == 5, "Span subscript")
    var sum = 0
    for i in span.indices { sum += span[i] }
    check(sum == 14, "Span indices")
    let tail = span.extracting(2...)
    check(tail.count == 3 && tail[0] == 4, "Span extracting(_:)")
    check(span.withUnsafeBufferPointer { Array($0) } == [3, 1, 4, 1, 5], "Span withUnsafeBufferPointer")

    let bytes = span.bytes
    check(bytes.byteCount == 5 * MemoryLayout<Int>.stride, "RawSpan byteCount")
    check(bytes.unsafeLoad(fromByteOffset: MemoryLayout<Int>.stride * 2, as: Int.self) == 4, "RawSpan unsafeLoad")
    let raw = RawSpan(_elements: span)
    check(raw.extracting(droppingFirst: MemoryLayout<Int>.stride).byteCount == 4 * MemoryLayout<Int>.stride,
          "RawSpan extracting(droppingFirst:)")
}

func mutableSpanTests(_ numbers: inout ContiguousArray<Int>) {
    var mutable = numbers.mutableSpan
    mutable[1] = 9
    mutable.swapAt(0, 4)
    check(mutable.count == 5 && mutable[0] == 5 && mutable[4] == 3, "MutableSpan subscript set, swapAt")
    mutable.withUnsafeMutableBufferPointer { $0[2] = 40 }
    check(mutable.span[2] == 40, "MutableSpan withUnsafeMutableBufferPointer, span")
}

@available(iOS 26.0, *)
func span26Tests() {
    let array = [10, 20, 30]
    let s = array.span
    check(s.count == 3 && s[2] == 30, "Array.span (iOS 26)")
    let text = "héllo"
    let utf8 = text.utf8.span
    check(utf8.count == 6 && utf8[0] == UInt8(ascii: "h"), "String.UTF8View.span (iOS 26)")
    var copy = array
    var m = copy.mutableSpan
    m[0] = 11
    _ = consume m
    check(copy == [11, 20, 30], "Array.mutableSpan (iOS 26)")
}

@available(iOS 26.0, *)
func inlineArrayTests() {
    var a: InlineArray<4, Int> = [1, 2, 3, 4]
    check(a.count == 4 && MemoryLayout<InlineArray<4, Int>>.size == 4 * MemoryLayout<Int>.size, "InlineArray count, inline layout")
    a[2] = 30
    var sum = 0
    for i in a.indices { sum += a[i] }
    check(sum == 37, "InlineArray subscript, indices")
    let filled = InlineArray<3, String>(repeating: "x")
    check(filled[0] == "x" && filled[2] == "x", "InlineArray(repeating:)")
    let squares = InlineArray<5, Int> { $0 * $0 }
    check(squares[4] == 16, "InlineArray(_:) generator")
    check(a.span[2] == 30, "InlineArray.span")
    a.swapAt(0, 3)
    check(a[0] == 4 && a[3] == 1, "InlineArray swapAt")
}

let onExecutor = DispatchSpecificKey<Bool>()

/// A task executor on a serial queue that counts the jobs it is given.
@available(iOS 18.0, *)
final class CountingExecutor: TaskExecutor, @unchecked Sendable {
    let queue = DispatchQueue(label: "swift62.executor")
    private let lock = NSLock()
    private var count = 0
    var jobs: Int { lock.lock(); defer { lock.unlock() }; return count }
    init() { queue.setSpecific(key: onExecutor, value: true) }
    func enqueue(_ job: consuming ExecutorJob) {
        lock.lock(); count += 1; lock.unlock()
        let unowned = UnownedJob(job)
        let executor = asUnownedTaskExecutor()
        queue.async { unowned.runSynchronously(on: executor) }
    }
}

@available(iOS 18.0, *)
func taskExecutorTests() async {
    let executor = CountingExecutor()
    let ranOn = await withTaskExecutorPreference(executor) { () async -> Bool in
        await Task.yield()
        return DispatchQueue.getSpecific(key: onExecutor) == true
    }
    check(executor.jobs > 0, "withTaskExecutorPreference enqueues jobs on the executor")
    check(ranOn, "nonisolated async code runs on the preferred executor")
    let before = executor.jobs
    let child = await Task(executorPreference: executor) { () -> Bool in
        await Task.yield()
        return DispatchQueue.getSpecific(key: onExecutor) == true
    }.value
    check(child && executor.jobs > before, "Task(executorPreference:)")
    let group = await withTaskGroup(of: Int.self) { g in
        for i in 1...4 { g.addTask(executorPreference: executor) { i * 10 } }
        return await g.reduce(0, +)
    }
    check(group == 100, "TaskGroup addTask(executorPreference:)")
    let global = await Task(executorPreference: globalConcurrentExecutor) { DispatchQueue.getSpecific(key: onExecutor) }.value
    check(global == nil, "globalConcurrentExecutor")
}

@Observable final class Temperature {
    var celsius = 20
}

@available(iOS 26.0, *)
func observationsTests() async {
    let t = Temperature()
    let values = Observations { t.celsius }
    var seen: [Int] = []
    var mutator: Task<Void, Never>?
    for await v in values {
        seen.append(v)
        if mutator == nil {                                  // change the value only once the first one arrived
            mutator = Task { @MainActor in
                for v in [21, 22, 23] {
                    try? await Task.sleep(for: .milliseconds(30))
                    t.celsius = v
                }
            }
        }
        if v == 23 { break }
    }
    await mutator?.value
    check(seen.first == 20 && seen.last == 23, "Observations yields the initial and changed values (\(seen))")
    check(seen == seen.sorted(), "Observations values in order")
}

@main struct Main {
    static func main() async {
        print("--- Span"); spanTests()
        var ran: [String] = ["Span"]
        if #available(iOS 18.0, *) { print("--- TaskExecutor"); await taskExecutorTests(); ran.append("TaskExecutor") }
        if #available(iOS 26.0, *) {
            print("--- iOS 26"); span26Tests(); inlineArrayTests(); await observationsTests()
            ran += ["InlineArray", "Observations"]
        }
        print("available: \(ran.joined(separator: " "))")
        print("swift 6.2 test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
