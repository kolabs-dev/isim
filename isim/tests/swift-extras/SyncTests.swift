import Foundation
import Synchronization
import Distributed

@available(iOS 18.0, *)
final class Counter: Sendable {
    let mutex = Mutex(0)
    let atomic = Atomic(0)
}

@available(iOS 18.0, *)
func synchronizationTests() {
    let c = Counter()
    DispatchQueue.concurrentPerform(iterations: 8) { _ in
        for _ in 0..<10_000 {
            c.mutex.withLock { $0 += 1 }
            c.atomic.wrappingAdd(1, ordering: .relaxed)
        }
    }
    check(c.mutex.withLock { $0 } == 80_000, "Mutex.withLock serializes 8 threads")
    check(c.atomic.load(ordering: .acquiring) == 80_000, "Atomic<Int>.wrappingAdd from 8 threads")
    let flag = Atomic(false)
    let (exchanged, original) = flag.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing)
    check(exchanged && !original && flag.load(ordering: .relaxed), "Atomic<Bool>.compareExchange")
    let small = Atomic<UInt8>(250)
    let r = small.wrappingAdd(10, ordering: .sequentiallyConsistent)
    check(r.oldValue == 250 && r.newValue == 4, "Atomic<UInt8> wraps")
    let m = Atomic(5)
    m.max(9, ordering: .relaxed); m.min(7, ordering: .relaxed)
    check(m.load(ordering: .relaxed) == 7, "Atomic min/max")
    let pair = Atomic(WordPair(first: 1, second: 2))
    _ = pair.compareExchange(expected: WordPair(first: 1, second: 2), desired: WordPair(first: 3, second: 4), ordering: .sequentiallyConsistent)
    let pv = pair.load(ordering: .relaxed)
    check(pv.first == 3 && pv.second == 4, "Atomic<WordPair> (128-bit compare-exchange)")
    final class Thing: Sendable { let n: Int; init(_ n: Int) { self.n = n } }
    let lazy = AtomicLazyReference<Thing>()
    let first = lazy.storeIfNil(Thing(1)), second = lazy.storeIfNil(Thing(2))
    check(first === second && lazy.load()?.n == 1, "AtomicLazyReference.storeIfNil keeps the first value")
    let tried = c.mutex.withLockIfAvailable { $0 }
    check(tried == 80_000, "Mutex.withLockIfAvailable")
    let ptr = Atomic<UnsafeMutableRawPointer?>(nil)
    ptr.store(UnsafeMutableRawPointer(bitPattern: 0x1000), ordering: .releasing)
    check(ptr.load(ordering: .acquiring) == UnsafeMutableRawPointer(bitPattern: 0x1000), "Atomic<UnsafeMutableRawPointer?>")
}

// MARK: - Distributed actors

distributed actor Greeter {
    typealias ActorSystem = LocalTestingDistributedActorSystem
    var greetings = 0
    distributed func greet(_ name: String) -> String {
        greetings += 1
        return "Hello, \(name)! (#\(greetings))"
    }
    distributed func fail() throws -> Int { throw GreeterError.nope }
    nonisolated var label: String { "greeter \(id)" }
}
enum GreeterError: Error, Codable { case nope }

func distributedTests() async {
    let system = LocalTestingDistributedActorSystem()
    let greeter = Greeter(actorSystem: system)
    do {
        let a = try await greeter.greet("isim")
        let b = try await greeter.greet("again")
        check(a == "Hello, isim! (#1)" && b == "Hello, again! (#2)", "distributed actor: distributed func calls (\(a))")
    } catch { check(false, "distributed actor call threw \(error)") }
    do {
        let resolved = try Greeter.resolve(id: greeter.id, using: system)
        let c = try await resolved.greet("resolved")
        check(c.hasSuffix("(#3)"), "resolve(id:using:) finds the local actor (\(c))")
    } catch { check(false, "resolve threw \(error)") }
    do { _ = try await greeter.fail(); check(false, "distributed throws") }
    catch { check(error is GreeterError, "distributed func errors propagate") }
    check(greeter.label.hasPrefix("greeter "), "nonisolated members and actor id")
    // remote call through the system's executeDistributedTarget path
    do {
        let id = greeter.id
        let remote = try Greeter.resolve(id: id, using: system)
        check(__isRemoteActor(remote) == false, "LocalTestingDistributedActorSystem resolves to the local instance")
    } catch { check(false, "resolve 2 threw \(error)") }
}
