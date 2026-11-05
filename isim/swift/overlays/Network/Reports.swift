// isim Network (issue #851): NWConnection's establishment and data transfer reports, discontiguous receives, and
// connections taken out of connection groups. Adapted: isim measures what its sockets see. Name resolution is the
// host resolver's query (its time and address count), each refused address is a previous attempt, the TCP handshake
// is the time connect() took (one round trip, which also stands for the path's RTT) and TLS the handshake's time;
// byte counts are the bytes the app sent and received (transport counts are the same: isim has no TCP-level counters),
// packet counts the sends and reads made, and duplicates, reordering and retransmissions are not seen (0).
@_exported import Foundation

/// what a connection measured (isim)
struct _NWStats {
    var startedAt: DispatchTime?, readyAt: DispatchTime?, attemptAt: DispatchTime?
    var resolution: (duration: TimeInterval, count: Int, first: NWEndpoint?)?
    var connected: NWEndpoint?
    var failedAttempts = 0
    var connectDuration: TimeInterval = 0, tlsDuration: TimeInterval?
    var sent: UInt64 = 0, received: UInt64 = 0, sends: UInt64 = 0, reads: UInt64 = 0
    static func seconds(since t: DispatchTime) -> TimeInterval { Double(DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1e9 }
    static func seconds(_ a: DispatchTime?, _ b: DispatchTime?) -> TimeInterval {
        guard let a, let b, b.uptimeNanoseconds >= a.uptimeNanoseconds else { return 0 }
        return Double(b.uptimeNanoseconds - a.uptimeNanoseconds) / 1e9
    }
}

extension NWConnection {
    /// how a connection was established (iOS 13)
    public struct EstablishmentReport: Sendable {
        /// one name resolution
        public struct Resolution: Sendable {
            /// where the answer came from
            public enum Source: Sendable, Hashable { case query, cache, expiredCache }
            /// the transport the DNS query used
            public enum DNSProtocol: Sendable, Hashable { case unknown, udp, tcp, tls, https }
            public let source: Source
            public let duration: TimeInterval
            public let endpointCount: Int
            public let successfulEndpoint: NWEndpoint
            public let preferredEndpoint: NWEndpoint
            public var dnsProtocol: DNSProtocol { _dnsProtocol }
            let _dnsProtocol: DNSProtocol
        }
        /// one protocol's handshake (TCP, TLS)
        public struct Handshake: Sendable {
            public let definition: NWProtocolDefinition
            public let handshakeDuration: TimeInterval
            public let handshakeRTT: TimeInterval
        }
        public let duration: TimeInterval
        public let attemptStartedAfterInterval: TimeInterval
        public let previousAttemptCount: Int
        public let usedProxy: Bool
        public let proxyConfigured: Bool
        public let proxyEndpoint: NWEndpoint?
        public let resolutions: [Resolution]
        public let handshakes: [Handshake]
    }

    /// what a connection sent and received over a span of time (iOS 13)
    public struct DataTransferReport: Sendable {
        /// one path's counts
        public struct PathReport: Sendable {
            public let interface: NWInterface
            public var radioType: NWInterface.RadioType? { nil }
            public let receivedIPPacketCount: UInt64
            public let sentIPPacketCount: UInt64
            public let receivedTransportByteCount: UInt64
            public let receivedTransportDuplicateByteCount: UInt64
            public let receivedTransportOutOfOrderByteCount: UInt64
            public let sentTransportByteCount: UInt64
            public let retransmittedTransportByteCount: UInt64
            public let transportSmoothedRTT: TimeInterval
            public let transportMinimumRTT: TimeInterval
            public let transportRTTVariance: TimeInterval
            public let receivedApplicationByteCount: UInt64
            public let sentApplicationByteCount: UInt64
        }
        public let duration: TimeInterval
        public let pathReports: [PathReport]
        public let aggregatePathReport: PathReport
    }

    /// a data transfer report being gathered: collect it to end it
    public final class PendingDataTransferReport: @unchecked Sendable {
        weak var connection: NWConnection?
        let start: DispatchTime
        let base: _NWStats
        var collected: DataTransferReport?
        init(_ c: NWConnection) { connection = c; start = .now(); c.lock.lock(); base = c._stats; c.lock.unlock() }
        public func collect(queue: DispatchQueue, completion: @escaping @Sendable (DataTransferReport) -> Void) {
            let r = collected ?? report()
            collected = r
            queue.async { completion(r) }
        }
        func report() -> DataTransferReport {
            var now = base
            if let c = connection { c.lock.lock(); now = c._stats; c.lock.unlock() }
            let rtt = now.connectDuration
            let path = DataTransferReport.PathReport(
                interface: connection?._reportInterface ?? NWInterface(type: .loopback, name: "lo0", index: 1),
                receivedIPPacketCount: now.reads - base.reads, sentIPPacketCount: now.sends - base.sends,
                receivedTransportByteCount: now.received - base.received, receivedTransportDuplicateByteCount: 0,
                receivedTransportOutOfOrderByteCount: 0, sentTransportByteCount: now.sent - base.sent, retransmittedTransportByteCount: 0,
                transportSmoothedRTT: rtt, transportMinimumRTT: rtt, transportRTTVariance: 0,
                receivedApplicationByteCount: now.received - base.received, sentApplicationByteCount: now.sent - base.sent)
            return DataTransferReport(duration: _NWStats.seconds(since: start), pathReports: [path], aggregatePathReport: path)
        }
    }

    /// the interface a report names: the loopback for local peers, else the path's first interface
    var _reportInterface: NWInterface {
        if case .hostPort(let h, _)? = _stats.connected ?? (fd >= 0 ? _NWSock.peer(fd) : nil) {
            switch h {
            case .ipv4(let a) where a.isLoopback: return NWInterface(type: .loopback, name: "lo0", index: 1)
            case .ipv6(let a) where a.isLoopback: return NWInterface(type: .loopback, name: "lo0", index: 1)
            default: break
            }
        }
        return NWPath._current(required: nil, prohibited: []).availableInterfaces.first ?? NWInterface(type: .loopback, name: "lo0", index: 1)
    }

    /// counts what a receive completion hands the app
    func _counting(_ completion: @escaping @Sendable (Data?, ContentContext?, Bool, NWError?) -> Void)
        -> @Sendable (Data?, ContentContext?, Bool, NWError?) -> Void {
        { [weak self] d, ctx, complete, e in
            if let n = d?.count, n > 0, let self { self.lock.lock(); self._stats.received += UInt64(n); self._stats.reads += 1; self.lock.unlock() }
            completion(d, ctx, complete, e)
        }
    }

    /// how the connection was established, once it is ready (nil before, or when it failed)
    public func requestEstablishmentReport(queue: DispatchQueue, completion: @escaping @Sendable (EstablishmentReport?) -> Void) {
        lock.lock(); let st = _stats, ready = _state == .ready || st.readyAt != nil; lock.unlock()
        guard ready else { queue.async { completion(nil) }; return }
        let report = _establishmentReport(st)
        queue.async { completion(report) }
    }
    func _establishmentReport(_ st: _NWStats) -> EstablishmentReport {
        var resolutions: [EstablishmentReport.Resolution] = []
        let isName: Bool = { if case .hostPort(.name, _) = endpoint { return true }; if case .url = endpoint { return true }; return false }()
        if let r = st.resolution, isName || r.count > 1 {
            let ok = st.connected ?? r.first ?? endpoint
            resolutions.append(.init(source: .query, duration: r.duration, endpointCount: r.count, successfulEndpoint: ok,
                                     preferredEndpoint: r.first ?? ok, _dnsProtocol: .udp))
        }
        var handshakes: [EstablishmentReport.Handshake] = []
        if !parameters.isUDP && acceptedFD < 0 {
            handshakes.append(.init(definition: NWProtocolTCP.definition, handshakeDuration: st.connectDuration, handshakeRTT: st.connectDuration))
        }
        if let t = st.tlsDuration { handshakes.append(.init(definition: NWProtocolTLS.definition, handshakeDuration: t, handshakeRTT: st.connectDuration)) }
        return EstablishmentReport(duration: _NWStats.seconds(st.startedAt, st.readyAt), attemptStartedAfterInterval: _NWStats.seconds(st.startedAt, st.attemptAt),
                                   previousAttemptCount: st.failedAttempts, usedProxy: false, proxyConfigured: false, proxyEndpoint: nil,
                                   resolutions: resolutions, handshakes: handshakes)
    }

    /// starts counting what the connection sends and receives
    public func startDataTransferReport() -> PendingDataTransferReport { PendingDataTransferReport(self) }

    /// receive(minimumIncompleteLength:maximumLength:completion:) with the bytes as DispatchData (iOS 14)
    public func receiveDiscontiguous(minimumIncompleteLength: Int, maximumLength: Int,
                                     completion: @escaping @Sendable (DispatchData?, ContentContext?, Bool, NWError?) -> Void) {
        receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength) { d, ctx, complete, e in
            completion(d.map(NWConnection._dispatchData), ctx, complete, e)
        }
    }
    /// receiveMessage(completion:) with the bytes as DispatchData (iOS 14)
    public func receiveMessageDiscontiguous(completion: @escaping @Sendable (DispatchData?, ContentContext?, Bool, NWError?) -> Void) {
        receiveMessage { d, ctx, complete, e in completion(d.map(NWConnection._dispatchData), ctx, complete, e) }
    }
    static func _dispatchData(_ d: Data) -> DispatchData { d.withUnsafeBytes { DispatchData(bytes: $0) } }

    /// a connection to one of a group's members (iOS 15): a UDP connection to it, with the group's parameters
    public convenience init?(from group: NWConnectionGroup, to endpoint: NWEndpoint? = nil, using options: NWProtocolOptions? = nil) {
        guard let e = endpoint ?? group.descriptor.members.first else { return nil }
        self.init(to: e, using: group.parameters.isUDP ? group.parameters : .udp)
    }
    /// a connection to the sender of a group's message (iOS 15)
    public convenience init?(message: NWConnectionGroup.Message) {
        guard let r = message.remoteEndpoint else { return nil }
        let p = message.group?.parameters
        self.init(to: r, using: p?.isUDP == true ? p! : .udp)
    }
}

@available(iOS 26.0, *)
extension NetworkChannel {
    /// what the channel's connection sent and received since it started
    public func dataTransferReport() async throws -> NWConnection.DataTransferReport {
        try await core.ready()
        core.lock.lock(); let pending = core.pendingReport; core.lock.unlock()
        return (pending ?? core.conn.startDataTransferReport()).report()
    }
    /// how the channel's connection was established (once it is ready)
    public func establishmentReport() async throws -> NWConnection.EstablishmentReport {
        try await core.ready()
        return try await withCheckedThrowingContinuation { k in
            core.conn.requestEstablishmentReport(queue: .global()) { r in
                if let r { k.resume(returning: r) } else { k.resume(throwing: NWError.posix(.ENOTCONN)) }
            }
        }
    }
}
