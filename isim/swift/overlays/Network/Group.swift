// isim Network framework: NWConnectionGroup with NWMulticastGroup (iOS 14) — UDP multicast on the host's network:
// the group's socket joins each IPv4/IPv6 group address (IP_ADD_MEMBERSHIP / IPV6_JOIN_GROUP) on the group port,
// with multicast loopback on so other apps on the same host (other isim devices too) hear it. Messages arrive with
// their sender; reply(to:content:) and send(to:) answer it by unicast. NWMultiplexGroup (QUIC streams) is accepted
// but fails: isim has no QUIC.
@_exported import Foundation

public protocol NWGroupDescriptor {}

public struct NWMulticastGroup: NWGroupDescriptor, Equatable, CustomDebugStringConvertible, Sendable {
    public private(set) var members: [NWEndpoint]
    public var disableUnicast: Bool
    var sources: [NWEndpoint?] = []
    /// group addresses are hostPort endpoints with multicast addresses (224.0.0.0/4, ff00::/8), all on one port
    public init(for groupAddresses: [NWEndpoint], from sourceEndpoint: NWEndpoint? = nil, disableUnicast: Bool = false) throws {
        members = []; self.disableUnicast = disableUnicast
        for g in groupAddresses { try joinGroup(on: g, from: sourceEndpoint) }
    }
    public mutating func joinGroup(on endpoint: NWEndpoint, from sourceEndpoint: NWEndpoint? = nil) throws {
        guard case .hostPort(let h, _) = endpoint else { throw NWError.posix(.EINVAL) }
        switch h {
        case .ipv4(let a) where a.isMulticast: break
        case .ipv6(let a) where a.isMulticast: break
        default: throw NWError.posix(.EINVAL)
        }
        members.append(endpoint); sources.append(sourceEndpoint)
    }
    public var debugDescription: String { members.map(\.debugDescription).joined(separator: ", ") }
    public static func == (a: NWMulticastGroup, b: NWMulticastGroup) -> Bool { a.members == b.members && a.disableUnicast == b.disableUnicast }
}

/// QUIC streams to one peer (iOS 15): isim has no QUIC, so a group with it fails with ENOTSUP
public struct NWMultiplexGroup: NWGroupDescriptor, Sendable {
    public let remoteEndpoint: NWEndpoint
    public init(to remoteEndpoint: NWEndpoint) { self.remoteEndpoint = remoteEndpoint }
}

public final class NWConnectionGroup: CustomDebugStringConvertible, @unchecked Sendable {
    public enum State: Equatable, Sendable { case setup, waiting(NWError), ready, failed(NWError), cancelled }

    /// a received message: who sent it, to answer them
    public final class Message: @unchecked Sendable {
        public let remoteEndpoint: NWEndpoint?
        public let localEndpoint: NWEndpoint?
        public var isFinal = true
        public var expirationMilliseconds: UInt64 = 0
        public var relativePriority: Double = 0.5
        weak var group: NWConnectionGroup?
        init(remote: NWEndpoint?, local: NWEndpoint?) { remoteEndpoint = remote; localEndpoint = local }
        public static let `default` = Message(remote: nil, local: nil)
        public func reply(content: Data?) { group?.reply(to: self, content: content) }
    }

    public let descriptor: NWGroupDescriptor
    public let parameters: NWParameters
    public private(set) var queue: DispatchQueue?
    public var state: State { lock.lock(); defer { lock.unlock() }; return _state }
    public var stateUpdateHandler: (@Sendable (State) -> Void)?
    public var newConnectionHandler: (@Sendable (NWConnection) -> Void)?
    public var debugDescription: String { "[G \(descriptor)]" }

    let lock = NSLock()
    var _state = State.setup
    var fd: Int32 = -1
    var receiveHandler: ((Message, Data?, Bool) -> Void)?
    var maximumMessageSize = 8192
    var rejectOversized = true
    var reader: Thread?

    public init(with descriptor: NWGroupDescriptor, using parameters: NWParameters) {
        self.descriptor = descriptor; self.parameters = parameters
    }

    func setState(_ s: State) {
        lock.lock()
        if _state == .cancelled || _state == s { lock.unlock(); return }
        _state = s
        let h = stateUpdateHandler, q = queue
        lock.unlock()
        if let h { (q ?? .main).async { h(s) } }
    }

    public func setReceiveHandler(maximumMessageSize: Int = 8192, rejectOversizedMessages: Bool = true,
                                  handler: @escaping @Sendable (Message, Data?, Bool) -> Void) {
        lock.lock(); receiveHandler = handler; self.maximumMessageSize = maximumMessageSize; rejectOversized = rejectOversizedMessages; lock.unlock()
    }

    public func start(queue: DispatchQueue) {
        lock.lock()
        guard self.queue == nil else { lock.unlock(); return }
        self.queue = queue
        lock.unlock()
        guard let group = descriptor as? NWMulticastGroup else { setState(.failed(.posix(.ENOTSUP))); return }
        guard parameters.isUDP else { setState(.failed(.posix(.EINVAL))); return }   /* multicast groups are UDP */
        guard case .hostPort(let firstHost, let port)? = group.members.first else { setState(.failed(.posix(.EINVAL))); return }
        let v6: Bool
        if case .ipv6 = firstHost { v6 = true } else { v6 = false }
        let s = socket(v6 ? AF_INET6 : AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { setState(.failed(_NWErrno.posix(errno))); return }
        var one: Int32 = 1
        setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, 4)
        setsockopt(s, SOL_SOCKET, SO_REUSEPORT, &one, 4)
        var bound: Int32
        if v6 {
            var a = sockaddr_in6(); a.sin6_family = sa_family_t(AF_INET6); a.sin6_port = port.rawValue.bigEndian
            a.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) } }
        } else {
            var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = port.rawValue.bigEndian
            a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        }
        guard bound == 0 else { let e = errno; close(s); setState(.failed(_NWErrno.posix(e))); return }
        for m in group.members {
            guard case .hostPort(let h, _) = m else { continue }
            var r: Int32 = 0
            switch h {
            case .ipv4(let a):
                var req = ip_mreq()
                a.rawValue.withUnsafeBytes { src in withUnsafeMutableBytes(of: &req.imr_multiaddr) { $0.copyMemory(from: src) } }
                r = setsockopt(s, IPPROTO_IP, IP_ADD_MEMBERSHIP, &req, socklen_t(MemoryLayout<ip_mreq>.size))
                var loop: UInt8 = 1
                setsockopt(s, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, 1)
            case .ipv6(let a):
                var req = ipv6_mreq()
                a.rawValue.withUnsafeBytes { src in withUnsafeMutableBytes(of: &req.ipv6mr_multiaddr) { $0.copyMemory(from: src) } }
                r = setsockopt(s, IPPROTO_IPV6, IPV6_JOIN_GROUP, &req, socklen_t(MemoryLayout<ipv6_mreq>.size))
            default: break
            }
            if r != 0 {
                let e = errno; close(s)
                print("isim: NWConnectionGroup: cannot join \(m) (\(e)): the host has no multicast route")
                setState(.failed(_NWErrno.posix(e)))
                return
            }
        }
        fd = s
        setState(.ready)
        let t = Thread { [weak self] in self?.readLoop(s) }
        t.name = "isim.NWConnectionGroup"
        reader = t
        t.start()
    }

    func readLoop(_ s: Int32) {
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            var ss = sockaddr_storage(); var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let n = buf.withUnsafeMutableBytes { b in
                withUnsafeMutablePointer(to: &ss) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(s, b.baseAddress!, b.count, 0, $0, &len) } }
            }
            if n < 0 {
                if errno == EINTR { continue }
                return
            }
            lock.lock(); let h = receiveHandler, q = queue, max = maximumMessageSize, reject = rejectOversized, live = _state == .ready; lock.unlock()
            guard live else { return }
            if n > max && reject { continue }
            let remote = withUnsafeBytes(of: &ss) { _NWSock.endpoint($0.baseAddress!, Int(len)) }
            let m = Message(remote: remote, local: _NWSock.local(s))
            m.group = self
            let data = Data(buf[0..<Swift.min(n, max)])
            if let h { (q ?? .main).async { h(m, data, true) } }
        }
    }

    /// to the whole group, or to one endpoint (unicast) when given
    public func send(content: Data?, to endpoint: NWEndpoint? = nil, message: Message = .default, completion: @escaping @Sendable (NWError?) -> Void) {
        let q = queue ?? .main
        guard state == .ready, fd >= 0 else { q.async { completion(.posix(.ENOTCONN)) }; return }
        let targets: [NWEndpoint]
        if let endpoint { targets = [endpoint] } else { targets = (descriptor as? NWMulticastGroup)?.members ?? [] }
        let data = content ?? Data()
        var err: NWError?
        for t in targets {
            switch _NWSock.resolve(t, udp: true) {
            case .failure(let e): err = e
            case .success(let addrs):
                guard let (sa, _) = addrs.first else { continue }
                let n = data.withUnsafeBytes { p in sa.withUnsafeBytes { a in
                    sendto(fd, p.baseAddress, data.count, 0, a.baseAddress!.assumingMemoryBound(to: sockaddr.self), socklen_t(sa.count)) } }
                if n < 0 { err = _NWErrno.posix(errno) }
            }
        }
        q.async { completion(err) }
    }
    public func reply(to message: Message, content: Data?) {
        guard let r = message.remoteEndpoint else { return }
        send(content: content, to: r) { _ in }
    }
    /// a connection to one member (iOS 15): a UDP connection to it
    public func extract(connectionTo endpoint: NWEndpoint? = nil, using protocolOptions: NWProtocolOptions? = nil) -> NWConnection? {
        guard let e = endpoint else { return nil }
        return NWConnection(to: e, using: .udp)
    }
    public func reinsert(connection: NWConnection) throws { connection.cancel() }

    public func cancel() {
        lock.lock()
        if _state == .cancelled { lock.unlock(); return }
        _state = .cancelled
        let h = stateUpdateHandler, q = queue, s = fd
        fd = -1
        lock.unlock()
        if s >= 0 { shutdown(s, SHUT_RDWR); close(s) }
        if let h { (q ?? .main).async { h(.cancelled) } }
    }
}
