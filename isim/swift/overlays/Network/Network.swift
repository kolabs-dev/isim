// isim Network framework (self-authored): NWPathMonitor and the path/interface types it reports.
// The path mirrors the host's connectivity (a non-loopback interface that is up and has an address);
// ISIM_NETWORK=offline makes it unsatisfied. Changes are polled every 2 seconds.
// NWConnection, NWListener and NWBrowser are in Connection.swift / Listener.swift.
@_exported import Foundation
import isim_host

public struct NWInterface: Hashable, Sendable, CustomDebugStringConvertible {
    public enum InterfaceType: Hashable, Sendable { case other, wifi, cellular, wiredEthernet, loopback }
    public let type: InterfaceType
    public let name: String
    public let index: Int
    public var debugDescription: String { name }
}

public struct NWPath: Equatable, Sendable, CustomDebugStringConvertible {
    public enum Status: Equatable, Sendable { case satisfied, unsatisfied, requiresConnection }
    public enum UnsatisfiedReason: Equatable, Sendable { case notAvailable, cellularDenied, wifiDenied, localNetworkDenied, vpnInactive }

    public let status: Status
    public let unsatisfiedReason: UnsatisfiedReason
    public let availableInterfaces: [NWInterface]
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let supportsIPv4: Bool
    public let supportsIPv6: Bool
    public let supportsDNS: Bool
    /// the connection's local and remote addresses (NWConnection.currentPath)
    public var localEndpoint: NWEndpoint? = nil
    public var remoteEndpoint: NWEndpoint? = nil
    public var gateways: [NWEndpoint] { [] }
    public func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool { availableInterfaces.first?.type == type }
    public var debugDescription: String {
        "\(status)" + (availableInterfaces.isEmpty ? "" : " (\(availableInterfaces.map(\.name).joined(separator: ", ")))")
    }

    /// the host's current connectivity, filtered by the monitor's interface requirements
    static func _current(required: NWInterface.InterfaceType?, prohibited: [NWInterface.InterfaceType]) -> NWPath {
        var flags: Int32 = 0
        let up = isim_net_path(&flags) != 0
        var ifs: [NWInterface] = []
        if flags & 1 != 0 { ifs.append(NWInterface(type: .wifi, name: "en0", index: 1)) }
        if flags & 2 != 0 { ifs.append(NWInterface(type: .wiredEthernet, name: ifs.isEmpty ? "en0" : "en1", index: ifs.count + 1)) }
        if flags & 16 != 0 { ifs.append(NWInterface(type: .other, name: "utun0", index: ifs.count + 1)) }
        ifs.removeAll { prohibited.contains($0.type) }
        if let required { ifs.removeAll { $0.type != required } }
        let ok = up && !ifs.isEmpty
        return NWPath(status: ok ? .satisfied : .unsatisfied, unsatisfiedReason: .notAvailable, availableInterfaces: ok ? ifs : [],
                      isExpensive: false, isConstrained: false, supportsIPv4: ok && flags & 4 != 0, supportsIPv6: ok && flags & 8 != 0, supportsDNS: ok)
    }
}

public final class NWPathMonitor: @unchecked Sendable {
    public var pathUpdateHandler: (@Sendable (NWPath) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return handler }
        set { lock.lock(); handler = newValue; lock.unlock() }
    }
    public var currentPath: NWPath { lock.lock(); defer { lock.unlock() }; return path ?? NWPath._current(required: required, prohibited: prohibited) }
    public private(set) var queue: DispatchQueue?

    let lock = NSLock()
    let required: NWInterface.InterfaceType?
    let prohibited: [NWInterface.InterfaceType]
    var handler: (@Sendable (NWPath) -> Void)?
    var path: NWPath?
    var timer: DispatchSourceTimer?
    var cancelled = false

    public init() { required = nil; prohibited = [] }
    public init(requiredInterfaceType: NWInterface.InterfaceType) { required = requiredInterfaceType; prohibited = [] }
    public init(prohibitedInterfaceTypes: [NWInterface.InterfaceType]) { required = nil; prohibited = prohibitedInterfaceTypes }

    /// Delivers the current path to pathUpdateHandler on `queue`, then again whenever it changes.
    public func start(queue: DispatchQueue) {
        lock.lock()
        guard self.queue == nil, !cancelled else { lock.unlock(); return }
        self.queue = queue
        lock.unlock()
        let poll = DispatchQueue(label: "isim.NWPathMonitor")
        let t = DispatchSource.makeTimerSource(queue: poll)
        t.schedule(deadline: .now(), repeating: 2.0)
        t.setEventHandler { [weak self] in self?.refresh() }
        lock.lock(); timer = t; lock.unlock()
        t.resume()
    }
    func refresh() {
        let p = NWPath._current(required: required, prohibited: prohibited)
        lock.lock()
        let changed = path != p && !cancelled
        if changed { path = p }
        let h = handler, q = queue
        lock.unlock()
        if changed, let h, let q { q.async { h(p) } }
    }
    public func cancel() {
        lock.lock(); cancelled = true; let t = timer; timer = nil; lock.unlock()
        t?.cancel()
    }
}

/// iOS 17: `for await path in monitor { ... }` (starts the monitor on a private queue)
extension NWPathMonitor: AsyncSequence {
    public typealias Element = NWPath
    public struct AsyncIterator: AsyncIteratorProtocol {
        var base: AsyncStream<NWPath>.Iterator
        public mutating func next() async -> NWPath? { await base.next() }
    }
    public func makeAsyncIterator() -> AsyncIterator {
        let (stream, cont) = AsyncStream<NWPath>.makeStream()
        pathUpdateHandler = { cont.yield($0) }
        cont.onTermination = { [weak self] _ in self?.cancel() }
        start(queue: DispatchQueue(label: "isim.NWPathMonitor.async"))
        return AsyncIterator(base: stream.makeAsyncIterator())
    }
}
