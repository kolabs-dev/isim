// isim Combine: Merge3...Merge8, MapKeyPath / 2 / 3, First and Contains as their own publisher types, the conditional
// Equatable conformances and public initializers Apple's operators have, Codable demand, Future.value, and the
// descriptions of Subscribers.Assign. Independent implementation (issue #355).
import Darwin

extension Publishers {
    /// Merges 3 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public init(_ a: A, _ b: B, _ c: C) { self.a = a; self.b = b; self.c = c }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }
    /// Merges 4 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure, A.Output == D.Output, A.Failure == D.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public init(_ a: A, _ b: B, _ c: C, _ d: D) { self.a = a; self.b = b; self.c = c; self.d = d }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }
    /// Merges 5 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge5<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure, A.Output == D.Output, A.Failure == D.Failure, A.Output == E.Output, A.Failure == E.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher(), e.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }
    /// Merges 6 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge6<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure, A.Output == D.Output, A.Failure == D.Failure, A.Output == E.Output, A.Failure == E.Failure, A.Output == F.Output, A.Failure == F.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public let f: F
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher(), e.eraseToAnyPublisher(), f.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }
    /// Merges 7 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge7<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure, A.Output == D.Output, A.Failure == D.Failure, A.Output == E.Output, A.Failure == E.Failure, A.Output == F.Output, A.Failure == F.Failure, A.Output == G.Output, A.Failure == G.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public let f: F
        public let g: G
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f; self.g = g }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher(), e.eraseToAnyPublisher(), f.eraseToAnyPublisher(), g.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }
    /// Merges 8 publishers: values as they arrive, finished when all are, failed when one fails.
    public struct Merge8<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure, A.Output == C.Output, A.Failure == C.Failure, A.Output == D.Output, A.Failure == D.Failure, A.Output == E.Output, A.Failure == E.Failure, A.Output == F.Output, A.Failure == F.Failure, A.Output == G.Output, A.Failure == G.Failure, A.Output == H.Output, A.Failure == H.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public let f: F
        public let g: G
        public let h: H
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f; self.g = g; self.h = h }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            MergeMany([a.eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher(), e.eraseToAnyPublisher(), f.eraseToAnyPublisher(), g.eraseToAnyPublisher(), h.eraseToAnyPublisher()]).subscribe(subscriber)
        }
    }

    /// Maps each value to the value at a key path.
    public struct MapKeyPath<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let keyPath: KeyPath<Upstream.Output, Output>
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let k = keyPath
            upstream.map { $0[keyPath: k] }.subscribe(subscriber)
        }
    }
    /// Maps each value to the values at two key paths.
    public struct MapKeyPath2<Upstream: Publisher, Output0, Output1>: Publisher {
        public typealias Output = (Output0, Output1)
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let keyPath0: KeyPath<Upstream.Output, Output0>
        public let keyPath1: KeyPath<Upstream.Output, Output1>
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let k0 = keyPath0, k1 = keyPath1
            upstream.map { ($0[keyPath: k0], $0[keyPath: k1]) }.subscribe(subscriber)
        }
    }
    /// Maps each value to the values at three key paths.
    public struct MapKeyPath3<Upstream: Publisher, Output0, Output1, Output2>: Publisher {
        public typealias Output = (Output0, Output1, Output2)
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let keyPath0: KeyPath<Upstream.Output, Output0>
        public let keyPath1: KeyPath<Upstream.Output, Output1>
        public let keyPath2: KeyPath<Upstream.Output, Output2>
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let k0 = keyPath0, k1 = keyPath1, k2 = keyPath2
            upstream.map { ($0[keyPath: k0], $0[keyPath: k1], $0[keyPath: k2]) }.subscribe(subscriber)
        }
    }

    /// The first value, then finished (upstream cancelled).
    public struct First<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            upstream.prefix(1).subscribe(subscriber)
        }
    }

    /// true as soon as upstream produces `output` (then finished), false if it finishes without.
    public struct Contains<Upstream: Publisher>: Publisher where Upstream.Output: Equatable {
        public typealias Output = Bool
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let output: Upstream.Output
        public init(upstream: Upstream, output: Upstream.Output) { self.upstream = upstream; self.output = output }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let o = output
            upstream.contains { $0 == o }.subscribe(subscriber)
        }
    }
}

extension Publisher {
    public func merge<B: Publisher, C: Publisher>(with b: B, _ c: C) -> Publishers.Merge3<Self, B, C> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure { Publishers.Merge3(self, b, c) }
    public func merge<B: Publisher, C: Publisher, D: Publisher>(with b: B, _ c: C, _ d: D) -> Publishers.Merge4<Self, B, C, D> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure { Publishers.Merge4(self, b, c, d) }
    public func merge<B: Publisher, C: Publisher, D: Publisher, E: Publisher>(with b: B, _ c: C, _ d: D, _ e: E) -> Publishers.Merge5<Self, B, C, D, E> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure, E.Output == Output, E.Failure == Failure { Publishers.Merge5(self, b, c, d, e) }
    public func merge<B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Publishers.Merge6<Self, B, C, D, E, F> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure, E.Output == Output, E.Failure == Failure, F.Output == Output, F.Failure == Failure { Publishers.Merge6(self, b, c, d, e, f) }
    public func merge<B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Publishers.Merge7<Self, B, C, D, E, F, G> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure, E.Output == Output, E.Failure == Failure, F.Output == Output, F.Failure == Failure, G.Output == Output, G.Failure == Failure { Publishers.Merge7(self, b, c, d, e, f, g) }
    public func merge<B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Publishers.Merge8<Self, B, C, D, E, F, G, H> where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure, E.Output == Output, E.Failure == Failure, F.Output == Output, F.Failure == Failure, G.Output == Output, G.Failure == Failure, H.Output == Output, H.Failure == Failure { Publishers.Merge8(self, b, c, d, e, f, g, h) }
    public func map<T0, T1>(_ keyPath0: KeyPath<Output, T0>, _ keyPath1: KeyPath<Output, T1>) -> Publishers.MapKeyPath2<Self, T0, T1> {
        Publishers.MapKeyPath2(upstream: self, keyPath0: keyPath0, keyPath1: keyPath1)
    }
    public func map<T0, T1, T2>(_ keyPath0: KeyPath<Output, T0>, _ keyPath1: KeyPath<Output, T1>, _ keyPath2: KeyPath<Output, T2>)
        -> Publishers.MapKeyPath3<Self, T0, T1, T2> {
        Publishers.MapKeyPath3(upstream: self, keyPath0: keyPath0, keyPath1: keyPath1, keyPath2: keyPath2)
    }
}
extension Publisher where Output: Equatable {
    public func contains(_ output: Output) -> Publishers.Contains<Self> { Publishers.Contains(upstream: self, output: output) }
}

extension Publishers.Merge {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge3<A, B, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge3(a, b, p) }
    public func merge<Z: Publisher, Y: Publisher>(with z: Z, _ y: Y) -> Publishers.Merge4<A, B, Z, Y> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure { Publishers.Merge4(a, b, z, y) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge5<A, B, Z, Y, X> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure { Publishers.Merge5(a, b, z, y, x) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge6<A, B, Z, Y, X, W> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure { Publishers.Merge6(a, b, z, y, x, w) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge7<A, B, Z, Y, X, W, V> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure, V.Output == Output, V.Failure == Failure { Publishers.Merge7(a, b, z, y, x, w, v) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, U: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V, _ u: U) -> Publishers.Merge8<A, B, Z, Y, X, W, V, U> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure, V.Output == Output, V.Failure == Failure, U.Output == Output, U.Failure == Failure { Publishers.Merge8(a, b, z, y, x, w, v, u) }
}
extension Publishers.Merge3 {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge4<A, B, C, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge4(a, b, c, p) }
    public func merge<Z: Publisher, Y: Publisher>(with z: Z, _ y: Y) -> Publishers.Merge5<A, B, C, Z, Y> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure { Publishers.Merge5(a, b, c, z, y) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge6<A, B, C, Z, Y, X> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure { Publishers.Merge6(a, b, c, z, y, x) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge7<A, B, C, Z, Y, X, W> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure { Publishers.Merge7(a, b, c, z, y, x, w) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge8<A, B, C, Z, Y, X, W, V> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure, V.Output == Output, V.Failure == Failure { Publishers.Merge8(a, b, c, z, y, x, w, v) }
}
extension Publishers.Merge4 {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge5<A, B, C, D, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge5(a, b, c, d, p) }
    public func merge<Z: Publisher, Y: Publisher>(with z: Z, _ y: Y) -> Publishers.Merge6<A, B, C, D, Z, Y> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure { Publishers.Merge6(a, b, c, d, z, y) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge7<A, B, C, D, Z, Y, X> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure { Publishers.Merge7(a, b, c, d, z, y, x) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher, W: Publisher>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge8<A, B, C, D, Z, Y, X, W> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure, W.Output == Output, W.Failure == Failure { Publishers.Merge8(a, b, c, d, z, y, x, w) }
}
extension Publishers.Merge5 {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge6<A, B, C, D, E, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge6(a, b, c, d, e, p) }
    public func merge<Z: Publisher, Y: Publisher>(with z: Z, _ y: Y) -> Publishers.Merge7<A, B, C, D, E, Z, Y> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure { Publishers.Merge7(a, b, c, d, e, z, y) }
    public func merge<Z: Publisher, Y: Publisher, X: Publisher>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge8<A, B, C, D, E, Z, Y, X> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure, X.Output == Output, X.Failure == Failure { Publishers.Merge8(a, b, c, d, e, z, y, x) }
}
extension Publishers.Merge6 {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge7<A, B, C, D, E, F, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge7(a, b, c, d, e, f, p) }
    public func merge<Z: Publisher, Y: Publisher>(with z: Z, _ y: Y) -> Publishers.Merge8<A, B, C, D, E, F, Z, Y> where Z.Output == Output, Z.Failure == Failure, Y.Output == Output, Y.Failure == Failure { Publishers.Merge8(a, b, c, d, e, f, z, y) }
}
extension Publishers.Merge7 {
    public func merge<P: Publisher>(with p: P) -> Publishers.Merge8<A, B, C, D, E, F, G, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge8(a, b, c, d, e, f, g, p) }
}

// MARK: - Equatable where the parts are

extension Just: Equatable where Output: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.output == rhs.output }
}
extension Empty: Equatable where Output: Equatable, Failure: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.completeImmediately == rhs.completeImmediately }
}
extension Fail: Equatable where Failure: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.error == rhs.error }
}
extension Publishers.Collect: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.Count: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.IgnoreOutput: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.Last: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.First: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.SetFailureType: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream }
}
extension Publishers.CollectByCount: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.count == rhs.count }
}
extension Publishers.Drop: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.count == rhs.count }
}
extension Publishers.Output: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.range == rhs.range }
}
extension Publishers.Retry: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.retries == rhs.retries }
}
extension Publishers.Contains: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.output == rhs.output }
}
extension Publishers.ReplaceEmpty: Equatable where Upstream: Equatable, Upstream.Output: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.output == rhs.output }
}
extension Publishers.ReplaceError: Equatable where Upstream: Equatable, Upstream.Output: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.output == rhs.output }
}
extension Publishers.Sequence: Equatable where Elements: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.sequence == rhs.sequence }
}
extension Publishers.CombineLatest: Equatable where A: Equatable, B: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b }
}
extension Publishers.Zip: Equatable where A: Equatable, B: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b }
}
extension Publishers.Zip3: Equatable where A: Equatable, B: Equatable, C: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c }
}
extension Publishers.Zip4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d }
}
extension Publishers.Merge: Equatable where A: Equatable, B: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b }
}
extension Publishers.Merge3: Equatable where A: Equatable, B: Equatable, C: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c }
}
extension Publishers.Merge4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d }
}
extension Publishers.Merge5: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e }
}
extension Publishers.Merge6: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f }
}
extension Publishers.Merge7: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g }
}
extension Publishers.Merge8: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable, H: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g && lhs.h == rhs.h }
}
extension Publishers.MergeMany: Equatable where Upstream: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.publishers == rhs.publishers }
}
extension Publishers.Concatenate: Equatable where Prefix: Equatable, Suffix: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.prefix == rhs.prefix && lhs.suffix == rhs.suffix }
}
extension Publishers.DropUntilOutput: Equatable where Upstream: Equatable, Other: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.upstream == rhs.upstream && lhs.other == rhs.other }
}

// MARK: - Apple's public initializers

extension Publishers.CombineLatest {
    public init(_ a: A, _ b: B) { self.init(a: a, b: b) }
}
extension Publishers.HandleEvents {
    public init(upstream: Upstream, receiveSubscription: ((Subscription) -> Void)?, receiveOutput: ((Output) -> Void)?,
                receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?, receiveCancel: (() -> Void)?,
                receiveRequest: ((Subscribers.Demand) -> Void)?) {
        self.upstream = upstream; self.receiveSubscription = receiveSubscription; self.receiveOutput = receiveOutput
        self.receiveCompletion = receiveCompletion; self.receiveCancel = receiveCancel; self.receiveRequest = receiveRequest
    }
}

// MARK: - Demand, Future, Assign, Record

extension Subscribers.Demand: Codable {
    /// one unsigned integer, as Apple's: the count, or UInt.max for unlimited
    public init(from decoder: any Decoder) throws {
        let v = try decoder.singleValueContainer().decode(UInt.self)
        self = v == UInt.max ? .unlimited : .max(Int(clamping: v))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(max.map { UInt($0) } ?? UInt.max)
    }
}

extension Future {
    /// The promised value (async): waits for the promise; throws its failure.
    public var value: Output {
        get async throws {
            try await withCheckedThrowingContinuation { (k: CheckedContinuation<Output, Error>) in
                let box = _Ref<AnyCancellable?>(nil)
                box.value = sink(receiveCompletion: { c in if case .failure(let e) = c { k.resume(throwing: e) }; box.value = nil },
                                 receiveValue: { k.resume(returning: $0) })
            }
        }
    }
}
extension Future where Failure == Never {
    /// The promised value (async): waits for the promise.
    public var value: Output {
        get async {
            await withCheckedContinuation { (k: CheckedContinuation<Output, Never>) in
                let box = _Ref<AnyCancellable?>(nil)
                box.value = sink { k.resume(returning: $0) }
            }
        }
    }
}

extension Subscribers.Assign: CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {
    public var description: String { "Assign \(Root.self)." }
    public var customMirror: Mirror { Mirror(self, children: ["object": object as Any, "keyPath": keyPath], displayStyle: .class) }
    public var playgroundDescription: Any { description }
}

extension Record.Recording {
    public typealias Input = Output
}
extension Record.Recording where Output: Encodable, Failure: Encodable {
    /// The recording as {"output": [...], "completion": {"success": true} or {"success": false, "error": ...}}.
    public func encode(into encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: _RecordingKey.self)
        try c.encode(output, forKey: .output)
        var done = c.nestedContainer(keyedBy: _RecordingKey.self, forKey: .completion)
        switch completion {
        case .finished: try done.encode(true, forKey: .success)
        case .failure(let e): try done.encode(false, forKey: .success); try done.encode(e, forKey: .error)
        }
    }
}

enum _RecordingKey: String, CodingKey { case output, completion, success, error }

// MARK: - isim ABI: the operators under their return types before #355 (apps built then keep calling these)

extension Publisher {
    // map(_ keyPath:) returned Publishers.Map, map(_:_:) / map(_:_:_:) Publishers.Map of a tuple
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE3mapyAA10PublishersO3MapVy_xqd__Gs7KeyPathCy6OutputQzqd__GlF")
    func _abi_map<T>(_ keyPath: KeyPath<Output, T>) -> Publishers.Map<Self, T> { Publishers.Map(upstream: self) { $0[keyPath: keyPath] } }
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE3mapyAA10PublishersO3MapVy_xqd___qd_0_tGs7KeyPathCy6OutputQzqd__G_AKyAMqd_0_Gtr0_lF")
    func _abi_map<T0, T1>(_ k0: KeyPath<Output, T0>, _ k1: KeyPath<Output, T1>) -> Publishers.Map<Self, (T0, T1)> {
        Publishers.Map(upstream: self) { ($0[keyPath: k0], $0[keyPath: k1]) }
    }
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE3mapyAA10PublishersO3MapVy_xqd___qd_0_qd_1_tGs7KeyPathCy6OutputQzqd__G_AKyAMqd_0_GAKyAMqd_1_Gtr1_lF")
    func _abi_map<T0, T1, T2>(_ k0: KeyPath<Output, T0>, _ k1: KeyPath<Output, T1>, _ k2: KeyPath<Output, T2>) -> Publishers.Map<Self, (T0, T1, T2)> {
        Publishers.Map(upstream: self) { ($0[keyPath: k0], $0[keyPath: k1], $0[keyPath: k2]) }
    }
    // first() returned Publishers.Output (prefix(1))
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE5firstAA10PublishersO6OutputVy_xGyF")
    func _abi_first() -> Publishers.Output<Self> { prefix(1) }
    // merge(with:_:) / merge(with:_:_:) returned a MergeMany of type-erased publishers
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE5merge4with_AA10PublishersO9MergeManyVy_AA03AnyB0Vy6OutputQz7FailureQzGGqd___qd_0_tAaBRd__AaBRd_0_ANQyd__AORSALQyd__AMRSANQyd_0_ARRSALQyd_0_ASRSr0_lF")
    func _abi_merge<B: Publisher, C: Publisher>(with b: B, _ c: C) -> Publishers.MergeMany<AnyPublisher<Output, Failure>>
        where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure {
        Publishers.MergeMany([eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher()])
    }
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAAE5merge4with__AA10PublishersO9MergeManyVy_AA03AnyB0Vy6OutputQz7FailureQzGGqd___qd_0_qd_1_tAaBRd__AaBRd_0_AaBRd_1_ANQyd__AORSALQyd__AMRSANQyd_0_ARRSALQyd_0_ASRSANQyd_1_ATRSALQyd_1_AURSr1_lF")
    func _abi_merge<B: Publisher, C: Publisher, D: Publisher>(with b: B, _ c: C, _ d: D) -> Publishers.MergeMany<AnyPublisher<Output, Failure>>
        where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure {
        Publishers.MergeMany([eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher()])
    }
}
extension Publisher where Output: Equatable {
    // contains(_:) returned Publishers.ContainsWhere
    @usableFromInline @_silgen_name("$s7Combine9PublisherPAASQ6OutputRpzrlE8containsyAA10PublishersO13ContainsWhereVy_xGAEF")
    func _abi_contains(_ output: Output) -> Publishers.ContainsWhere<Self> { contains { $0 == output } }
}
