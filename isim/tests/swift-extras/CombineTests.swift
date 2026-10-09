import Foundation
import Combine

struct Boom: Error, Equatable { var code = 1 }

/// Runs a synchronous publisher chain and returns its values plus "finished" / "failure(...)".
func run<P: Publisher>(_ p: P) -> ([P.Output], String) {
    var values: [P.Output] = []
    var end = "none"
    let c = p.sink(receiveCompletion: { c in
        switch c { case .finished: end = "finished"; case .failure(let e): end = "failure(\(e))" }
    }, receiveValue: { values.append($0) })
    _ = c
    return (values, end)
}

/// Like `run` for chains that complete on other queues.
func runAsync<P: Publisher>(_ p: P, timeout: Double = 10) -> ([P.Output], String) {
    let lock = NSLock()
    var values: [P.Output] = []
    var end = "none"
    let done = DispatchSemaphore(value: 0)
    let c = p.sink(receiveCompletion: { c in
        lock.lock()
        switch c { case .finished: end = "finished"; case .failure(let e): end = "failure(\(e))" }
        lock.unlock()
        done.signal()
    }, receiveValue: { v in lock.lock(); values.append(v); lock.unlock() })
    _ = done.wait(timeout: .now() + timeout)
    c.cancel()
    lock.lock(); defer { lock.unlock() }
    return (values, end)
}

/// A subscriber that requests values one at a time, on demand.
final class Stepper<Input, Failure: Error>: Subscriber {
    var subscription: Subscription?
    var values: [Input] = []
    var completed = false
    func receive(subscription: Subscription) { self.subscription = subscription }
    func receive(_ input: Input) -> Subscribers.Demand { values.append(input); return .none }
    func receive(completion: Subscribers.Completion<Failure>) { completed = true }
}

final class LineLog: TextOutputStream {
    var lines: [String] = []
    func write(_ s: String) { if s != "\n" { lines.append(s.hasSuffix("\n") ? String(s.dropLast()) : s) } }
}

struct Item: Codable, Equatable { var id: Int; var name: String }

func combineTests() {
    let q = DispatchQueue(label: "combine.tests")

    // accumulate
    check(run([1, 2, 3, 4].publisher.scan(0, +)).0 == [1, 3, 6, 10], "scan")
    check(run([1, 2, 3].publisher.tryScan(0) { a, v in if v == 3 { throw Boom() }; return a + v }) .1 == "failure(Boom(code: 1))", "tryScan throws -> failure")
    check(run([1, 2, 3, 4].publisher.reduce(0, +)).0 == [10], "reduce")
    check(run([1, 2, 3].publisher.tryReduce(1) { $0 * $1 }).0 == [6], "tryReduce")
    let collected = run((1...7).publisher.collect(3))
    check(collected.0 == [[1, 2, 3], [4, 5, 6], [7]] && collected.1 == "finished", "collect(count) keeps the remainder")
    check(run((1...4).publisher.collect()).0 == [[1, 2, 3, 4]], "collect()")
    check(run([5, 1, 9, 3].publisher.count()).0 == [4], "count")
    check(run([5, 1, 9, 3].publisher.min()).0 == [1] && run([5, 1, 9, 3].publisher.max()).0 == [9], "min / max")
    check(run(["bb", "a", "ccc"].publisher.max { $0.count < $1.count }).0 == ["ccc"], "max(by:)")
    check(run([1, 2, 3].publisher.contains(2)).0 == [true] && run([1, 2, 3].publisher.contains(7)).0 == [false], "contains")
    check(run([2, 4, 6].publisher.allSatisfy { $0 % 2 == 0 }).0 == [true] && run([2, 3].publisher.allSatisfy { $0 % 2 == 0 }).0 == [false], "allSatisfy")
    check(run([1, 2, 3, 4].publisher.first { $0 > 2 }).0 == [3], "first(where:)")
    check(run([1, 2, 3, 4].publisher.last()).0 == [4] && run([1, 2, 3, 4].publisher.last { $0 < 3 }).0 == [2], "last / last(where:)")
    let ignored = run([1, 2, 3].publisher.ignoreOutput())
    check(ignored.0.isEmpty && ignored.1 == "finished", "ignoreOutput")
    check(run((0..<10).publisher.output(at: 4)).0 == [4] && run((0..<10).publisher.output(in: 2...4)).0 == [2, 3, 4], "output(at:) / output(in:)")
    check(run([1, 2, 5, 1].publisher.prefix { $0 < 3 }).0 == [1, 2], "prefix(while:)")
    check(run([1, 2, 5, 1].publisher.drop { $0 < 3 }).0 == [5, 1], "drop(while:)")
    check(run([1, 2, 3, 4].publisher.tryFilter { $0 % 2 == 0 }).0 == [2, 4], "tryFilter")
    check(run(["1", "x", "3"].publisher.tryCompactMap { Int($0) }).0 == [1, 3], "tryCompactMap")
    check(run([1, 1, 2, 2, 1].publisher.tryRemoveDuplicates { $0 == $1 }).0 == [1, 2, 1], "tryRemoveDuplicates")
    check(run([Int?.some(1), nil, 3].publisher.replaceNil(with: 0)).0 == [1, 0, 3], "replaceNil")
    check(run(Empty<Int, Never>().replaceEmpty(with: 42)).0 == [42] && run(Just(1).replaceEmpty(with: 42)).0 == [1], "replaceEmpty")
    struct P { var x: Int; var y: String }
    check(run(Just(P(x: 1, y: "a")).map(\.x, \.y)).0.map { "\($0.0)\($0.1)" } == ["1a"], "map(keyPath, keyPath)")

    // errors
    let failing = [1, 2].publisher.setFailureType(to: Boom.self).append(Fail(error: Boom(code: 7)))
    check(run(failing.replaceError(with: 0)).0 == [1, 2, 0], "replaceError")
    check(run(failing.mapError { _ in URLError(.badURL) }).1.contains("URLError"), "mapError to URLError")
    struct Wrapped: Error { var inner: Int }
    check(run(failing.mapError { Wrapped(inner: $0.code) }).1 == "failure(Wrapped(inner: 7))", "mapError transforms the failure")
    let caught = run(failing.catch { e in Just(e.code * 10) })
    check(caught.0 == [1, 2, 70] && caught.1 == "finished", "catch switches to the replacement publisher")
    check(run(failing.tryCatch { e -> Just<Int> in if e.code == 7 { throw Wrapped(inner: 1) }; return Just(0) }).1 == "failure(Wrapped(inner: 1))", "tryCatch rethrows")
    var attempts = 0
    let flaky = Deferred { () -> AnyPublisher<Int, Boom> in
        attempts += 1
        return attempts < 3 ? Fail(error: Boom(code: attempts)).eraseToAnyPublisher() : Just(attempts).setFailureType(to: Boom.self).eraseToAnyPublisher()
    }
    check(run(flaky.retry(5)).0 == [3] && attempts == 3, "retry resubscribes until success (\(attempts) attempts)")
    attempts = 0
    check(run(flaky.retry(1)).1 == "failure(Boom(code: 2))" && attempts == 2, "retry gives up after n retries")

    // combining
    let za = PassthroughSubject<Int, Never>(), zb = PassthroughSubject<String, Never>()
    var zipped: [String] = []
    var zipDone = false
    let zc = za.zip(zb).sink(receiveCompletion: { _ in zipDone = true }, receiveValue: { zipped.append("\($0)\($1)") })
    za.send(1); za.send(2); zb.send("a"); za.send(3); zb.send("b"); zb.send("c"); zb.send("d")
    za.send(completion: .finished)
    check(zipped == ["1a", "2b", "3c"] && zipDone, "zip pairs in order and finishes when one side is exhausted (\(zipped))")
    zc.cancel()
    check(run([1, 2].publisher.zip(["a", "b"].publisher, [true, false].publisher)).0.map { "\($0.0)\($0.1)\($0.2)" } == ["1atrue", "2bfalse"], "zip 3")
    check(run([1, 2].publisher.zip([10, 20].publisher) { $0 + $1 }).0 == [11, 22], "zip with transform")
    let c1 = CurrentValueSubject<Int, Never>(1), c2 = CurrentValueSubject<Int, Never>(2), c3 = CurrentValueSubject<Int, Never>(3)
    var latest: [Int] = []
    let cl = c1.combineLatest(c2, c3).sink { latest.append($0 + $1 + $2) }
    c2.send(20); c3.send(30)
    check(latest == [6, 24, 51], "combineLatest 3 (\(latest))")
    cl.cancel()
    check(run(Publishers.MergeMany([1].publisher, [2].publisher, [3].publisher)).0.sorted() == [1, 2, 3], "MergeMany")
    check(run([1].publisher.merge(with: [2].publisher, [3].publisher)).0.sorted() == [1, 2, 3], "merge(with:_:)")
    check(run([2, 3].publisher.append(4, 5).prepend(1)).0 == [1, 2, 3, 4, 5], "append / prepend")
    let outer = PassthroughSubject<PassthroughSubject<Int, Never>, Never>()
    let i1 = PassthroughSubject<Int, Never>(), i2 = PassthroughSubject<Int, Never>()
    var switched: [Int] = []
    let sw = outer.switchToLatest().sink { switched.append($0) }
    outer.send(i1); i1.send(1); outer.send(i2); i1.send(99); i2.send(2)
    check(switched == [1, 2], "switchToLatest drops the previous inner publisher (\(switched))")
    sw.cancel()
    var inner: [Int] = []
    var fmDone = false
    let fm = [1, 2, 3].publisher.flatMap(maxPublishers: .max(1)) { [$0, $0 * 10].publisher }
        .sink(receiveCompletion: { _ in fmDone = true }, receiveValue: { inner.append($0) })
    check(inner == [1, 10, 2, 20, 3, 30] && fmDone, "flatMap(maxPublishers:) waits for inner completion (\(inner))")
    fm.cancel()
    let trigger = PassthroughSubject<Void, Never>(), src = PassthroughSubject<Int, Never>()
    var gated: [Int] = []
    let g = src.drop(untilOutputFrom: trigger).sink { gated.append($0) }
    src.send(1); trigger.send(); src.send(2)
    var until: [Int] = []
    let stop = PassthroughSubject<Void, Never>()
    let u = src.prefix(untilOutputFrom: stop).sink { until.append($0) }
    src.send(3); stop.send(); src.send(4)
    check(gated == [2, 3, 4] && until == [3], "drop(untilOutputFrom:) / prefix(untilOutputFrom:)")
    g.cancel(); u.cancel()

    // demand: Sequence publisher and buffer honour the subscriber's demand
    let stepper = Stepper<Int, Never>()
    (1...).publisher.subscribe(stepper)
    stepper.subscription?.request(.max(2))
    stepper.subscription?.request(.max(1))
    check(stepper.values == [1, 2, 3] && !stepper.completed, "Sequence publisher is lazy and demand-driven (infinite range)")
    let bufSubject = PassthroughSubject<Int, Never>()
    let bufStep = Stepper<Int, Never>()
    bufSubject.buffer(size: 2, prefetch: .keepFull, whenFull: .dropNewest).subscribe(bufStep)
    for i in 1...5 { bufSubject.send(i) }
    bufStep.subscription?.request(.max(5))
    check(bufStep.values == [1, 2], "buffer(size: 2, .dropNewest) keeps the first two while there is no demand (\(bufStep.values))")
    let bufStep2 = Stepper<Int, Never>()
    let bufSubject2 = PassthroughSubject<Int, Never>()
    bufSubject2.buffer(size: 2, prefetch: .byRequest, whenFull: .dropOldest).subscribe(bufStep2)
    for i in 1...5 { bufSubject2.send(i) }
    bufStep2.subscription?.request(.unlimited)
    check(bufStep2.values == [4, 5], "buffer .dropOldest (\(bufStep2.values))")
    var bufErr = ""
    let bufSubject3 = PassthroughSubject<Int, Boom>()
    let bc = bufSubject3.buffer(size: 1, prefetch: .byRequest, whenFull: .customError { Boom(code: 9) })
        .sink(receiveCompletion: { if case .failure(let e) = $0 { bufErr = "\(e.code)" } }, receiveValue: { _ in })
    _ = bc
    check(bufErr == "", "buffer with unlimited demand never overflows")

    // coding
    let items = [Item(id: 1, name: "a"), Item(id: 2, name: "b")]
    let roundTrip = run(items.publisher.encode(encoder: JSONEncoder()).decode(type: Item.self, decoder: JSONDecoder()))
    check(roundTrip.0 == items && roundTrip.1 == "finished", "encode(encoder:) / decode(type:decoder:) JSON round trip")
    let bad = run(Just(Data("{".utf8)).decode(type: Item.self, decoder: JSONDecoder()))
    check(bad.0.isEmpty && bad.1.hasPrefix("failure("), "decode failure ends the stream")
    check(run(Just(Item(id: 3, name: "p")).encode(encoder: PropertyListEncoder()).decode(type: Item.self, decoder: PropertyListDecoder())).0 == [Item(id: 3, name: "p")], "property list encode/decode")

    // debugging
    let log = LineLog()
    _ = run([1, 2].publisher.print("nums", to: log))
    check(log.lines == ["nums: receive subscription: (Sequence)", "nums: request unlimited", "nums: receive value: (1)", "nums: receive value: (2)", "nums: receive finished"],
          "print(_:to:) lines (\(log.lines))")
    var seen: [String] = []
    _ = run([7].publisher.handleEvents(receiveSubscription: { _ in seen.append("sub") }, receiveOutput: { seen.append("out \($0)") },
                                       receiveCompletion: { _ in seen.append("done") }, receiveRequest: { seen.append("req \($0)") }))
    check(seen == ["sub", "req unlimited", "out 7", "done"], "handleEvents subscription/request hooks (\(seen))")
    var cancelled = false
    PassthroughSubject<Int, Never>().handleEvents(receiveCancel: { cancelled = true }).sink { _ in }.cancel()
    check(cancelled, "handleEvents receiveCancel")
    check(run([1, 2, 3].publisher.breakpoint(receiveOutput: { $0 > 5 })).0 == [1, 2, 3], "breakpoint passes values through when it does not trigger")
    check(run(Just(1).breakpointOnError()).0 == [1], "breakpointOnError")
    let recorded = run(Record<Int, Boom>(output: [1, 2], completion: .failure(Boom(code: 3))))
    check(recorded.0 == [1, 2] && recorded.1 == "failure(Boom(code: 3))", "Record")

    // sharing
    var connectValues: [Int] = []
    let connectable = [1, 2, 3].publisher.makeConnectable()
    let cs = connectable.sink { connectValues.append($0) }
    check(connectValues.isEmpty, "makeConnectable waits for connect()")
    let conn = connectable.connect()
    check(connectValues == [1, 2, 3], "connect() starts delivery")
    cs.cancel(); conn.cancel()
    let mc = [4, 5].publisher.multicast { PassthroughSubject<Int, Never>() }
    var m1: [Int] = [], m2: [Int] = []
    let s1 = mc.sink { m1.append($0) }, s2 = mc.sink { m2.append($0) }
    _ = mc.connect()
    check(m1 == [4, 5] && m2 == [4, 5], "multicast shares one subscription")
    s1.cancel(); s2.cancel()

    // timing (on a background queue)
    let t0 = Date()
    let delayed = runAsync([1, 2].publisher.delay(for: .milliseconds(150), scheduler: q))
    check(delayed.0 == [1, 2] && Date().timeIntervalSince(t0) >= 0.14, "delay(for:scheduler:) (\(Date().timeIntervalSince(t0))s)")
    let never = PassthroughSubject<Int, Boom>()
    let timedOut = runAsync(never.timeout(.milliseconds(100), scheduler: q, customError: { Boom(code: 408) }))
    check(timedOut.1 == "failure(Boom(code: 408))", "timeout with customError (\(timedOut.1))")
    let quiet = PassthroughSubject<Int, Never>()
    check(runAsync(quiet.timeout(.milliseconds(80), scheduler: q)).1 == "finished", "timeout without error finishes")

    let thr = PassthroughSubject<Int, Never>()
    var throttled: [Int] = []
    let tl = NSLock()
    let tc = thr.throttle(for: .milliseconds(200), scheduler: q, latest: true).sink { v in tl.lock(); throttled.append(v); tl.unlock() }
    thr.send(1); thr.send(2); thr.send(3)
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return throttled.count >= 2 }   // 1 at once, 3 at the window's end
    thr.send(4)
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return throttled.count >= 3 }
    tl.lock(); let thrV = throttled; tl.unlock()
    check(thrV == [1, 3, 4], "throttle(latest: true) emits the first value, then the latest per interval (\(thrV))")
    tc.cancel()
    let thr2 = PassthroughSubject<Int, Never>()
    var throttled2: [Int] = []
    let tc2 = thr2.throttle(for: .milliseconds(200), scheduler: q, latest: false).sink { v in tl.lock(); throttled2.append(v); tl.unlock() }
    thr2.send(1); thr2.send(2); thr2.send(3)
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return throttled2.count >= 2 }
    pause(0.25)                                       // a window later: 3 is not emitted
    tl.lock(); let thrV2 = throttled2; tl.unlock()
    check(thrV2 == [1, 2], "throttle(latest: false) keeps the first value of the window (\(thrV2))")
    tc2.cancel()

    let deb = PassthroughSubject<Int, Never>()
    var debounced: [Int] = []
    let dc = deb.debounce(for: .milliseconds(120), scheduler: q).sink { v in tl.lock(); debounced.append(v); tl.unlock() }
    // 1 and 2 are followed by another value within 30 ms, so they are dropped; on a loaded machine the sending thread
    // can stall past the debounce interval, which lets one through as it should: the measured gaps decide
    var sent: [Date] = []
    deb.send(1); sent.append(Date()); pause(0.03); deb.send(2); sent.append(Date()); pause(0.03); deb.send(3); sent.append(Date())
    let mustDrop = [1, 2].filter { sent[$0].timeIntervalSince(sent[$0 - 1]) < 0.1 }
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return debounced.contains(3) }
    deb.send(4)
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return debounced.contains(4) }
    tl.lock(); let debV = debounced; tl.unlock()
    check(debV.suffix(2) == [3, 4] && debV == debV.sorted() && mustDrop.allSatisfy { !debV.contains($0) },
          "debounce keeps the last value after a quiet period (\(debV))")
    dc.cancel()

    let ticks = PassthroughSubject<Int, Never>()
    var groups: [[Int]] = []
    let gc = ticks.collect(.byTimeOrCount(q, .milliseconds(150), 3)).sink { v in tl.lock(); groups.append(v); tl.unlock() }
    for i in 1...4 { ticks.send(i) }
    _ = waitFor { tl.lock(); defer { tl.unlock() }; return groups.count >= 2 }
    tl.lock(); let grp = groups; tl.unlock()
    check(grp == [[1, 2, 3], [4]], "collect(.byTimeOrCount) flushes when full and on the timer (\(grp))")
    gc.cancel()

    let measured = PassthroughSubject<Int, Never>()
    var intervals: [Double] = []
    let mi = measured.measureInterval(using: q).sink { intervals.append($0.timeInterval) }
    measured.send(0); pause(0.1); measured.send(1)
    check(intervals.count == 2 && intervals[1] >= 0.09, "measureInterval (\(intervals))")
    mi.cancel()

    let onQueue = runAsync(Deferred { Just(Thread.isMainThread) }.subscribe(on: q))
    check(onQueue.0 == [false], "subscribe(on:) runs the subscription on the scheduler")
}

func combineAsyncTests() async {
    var got: [Int] = []
    for await v in [1, 2, 3].publisher.values { got.append(v) }
    check(got == [1, 2, 3], ".values (AsyncPublisher) over a Sequence publisher")
    // the senders wait until the iterator exists (making it subscribes): a value sent before that is not delivered, and a
    // fixed delay raced the loop's start on a loaded machine
    let subject = PassthroughSubject<String, Boom>()
    let subscribed = DispatchSemaphore(value: 0)
    Task.detached { subscribed.wait(); subject.send("a"); subject.send("b"); subject.send(completion: .failure(Boom(code: 5))) }
    var strings: [String] = []
    do {
        var it = subject.values.makeAsyncIterator()
        subscribed.signal()
        while let s = try await it.next() { strings.append(s) }
        check(false, ".values (AsyncThrowingPublisher) should throw")
    } catch {
        check(strings == ["a", "b"] && (error as? Boom)?.code == 5, ".values (AsyncThrowingPublisher) yields values then throws the failure")
    }
    let model = CurrentValueSubject<Int, Never>(10)
    var firstTwo: [Int] = []
    let modelSubscribed = DispatchSemaphore(value: 0)
    Task.detached { modelSubscribed.wait(); model.send(11) }
    var modelValues = model.values.makeAsyncIterator()
    modelSubscribed.signal()
    while let v = await modelValues.next() { firstTwo.append(v); if firstTwo.count == 2 { break } }
    check(firstTwo == [10, 11], ".values over CurrentValueSubject, break ends the iteration")
}
