// isim Network framework: NWListener (TCP, UDP), Bonjour service advertising and NWBrowser over isim's local
// service registry (see Connection.swift).
@_exported import Foundation

// MARK: - TXT records

public struct NWTXTRecord: Hashable, CustomDebugStringConvertible, Sendable {
    public var dictionary: [String: String]
    public init() { dictionary = [:] }
    public init(_ dictionary: [String: String]) { self.dictionary = dictionary }
    public init(_ data: Data) {
        var d: [String: String] = [:], i = 0
        let b = [UInt8](data)
        while i < b.count {
            let n = Int(b[i]); i += 1
            guard i + n <= b.count else { break }
            let s = String(decoding: b[i..<i + n], as: UTF8.self); i += n
            if let eq = s.firstIndex(of: "=") { d[String(s[..<eq])] = String(s[s.index(after: eq)...]) } else if !s.isEmpty { d[s] = "" }
        }
        dictionary = d
    }
    public var data: Data {
        var out = Data()
        for (k, v) in dictionary.sorted(by: { $0.key < $1.key }) { let e = Data((v.isEmpty ? k : "\(k)=\(v)").utf8).prefix(255); out.append(UInt8(e.count)); out.append(e) }
        return out
    }
    public subscript(key: String) -> String? { get { dictionary[key] } set { dictionary[key] = newValue } }
    public var count: Int { dictionary.count }
    public var isEmpty: Bool { dictionary.isEmpty }
    public mutating func removeEntry(key: String) -> Bool { dictionary.removeValue(forKey: key) != nil }
    public var debugDescription: String { dictionary.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") }
}

// MARK: - the local service registry

struct _NWService: Codable, Hashable { let name: String, type: String, domain: String, port: UInt16, pid: Int32, txt: [String: String] }

enum _NWBonjour {
    static var root: URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? (NSHomeDirectory() as NSString).appendingPathComponent(".local/share/isim")
        return URL(fileURLWithPath: data).appendingPathComponent("Library/isim/Bonjour")
    }
    static func normType(_ t: String) -> String { t.hasSuffix(".") ? String(t.dropLast()) : t }
    static func file(_ s: _NWService) -> URL {
        root.appendingPathComponent(normType(s.type)).appendingPathComponent(s.name.replacingOccurrences(of: "/", with: "_") + ".json")
    }
    static func register(_ s: _NWService) {
        let f = file(s)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: f) }
    }
    static func unregister(_ s: _NWService) { try? FileManager.default.removeItem(at: file(s)) }
    static func services(type: String) -> [_NWService] {
        let dir = root.appendingPathComponent(normType(type))
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.sorted().compactMap { n -> _NWService? in
            guard n.hasSuffix(".json"), let d = try? Data(contentsOf: dir.appendingPathComponent(n)),
                  let s = try? JSONDecoder().decode(_NWService.self, from: d) else { return nil }
            // a service of an app that is gone is stale
            if s.pid != getpid() && !FileManager.default.fileExists(atPath: "/proc/\(s.pid)") { try? FileManager.default.removeItem(at: dir.appendingPathComponent(n)); return nil }
            return s
        }
    }
    static func lookup(name: String, type: String) -> _NWService? { services(type: type).first { $0.name == name } }
}

// MARK: - NWListener

public final class NWListener: CustomDebugStringConvertible, @unchecked Sendable {
    public enum State: Equatable, Sendable { case setup, waiting(NWError), ready, failed(NWError), cancelled }
    public struct Service: Equatable, CustomDebugStringConvertible, Sendable {
        public var name: String?
        public var type: String
        public var domain: String?
        public var txtRecordObject: NWTXTRecord?
        public var txtRecord: Data? { txtRecordObject?.data }
        public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: Data? = nil) {
            self.name = name; self.type = type; self.domain = domain; txtRecordObject = txtRecord.map { NWTXTRecord($0) }
        }
        public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: NWTXTRecord) {
            self.name = name; self.type = type; self.domain = domain; txtRecordObject = txtRecord
        }
        public var debugDescription: String { "\(name ?? "").\(type)\(domain ?? "local.")" }
    }
    public enum ServiceRegistrationChange: Sendable { case add(NWEndpoint), remove(NWEndpoint) }

    public let parameters: NWParameters
    public private(set) var port: NWEndpoint.Port?
    public var service: Service? { didSet { if state == .ready { advertise() } } }
    public var state: State { lock.lock(); defer { lock.unlock() }; return _state }
    public var stateUpdateHandler: (@Sendable (State) -> Void)?
    public var newConnectionHandler: (@Sendable (NWConnection) -> Void)?
    public var serviceRegistrationUpdateHandler: (@Sendable (ServiceRegistrationChange) -> Void)?
    public var newConnectionLimit: Int = Int.max
    public static let InfiniteConnectionLimit = Int.max
    public private(set) var queue: DispatchQueue?
    public var debugDescription: String { "[L \(port.map { String($0.rawValue) } ?? "-") \(parameters)]" }

    let lock = NSLock()
    var _state = State.setup
    var fd: Int32 = -1
    var registered: _NWService?
    var udpPeers: [Data: NWConnection] = [:]
    let requested: UInt16

    public init(using parameters: NWParameters, on port: NWEndpoint.Port) throws {
        self.parameters = parameters
        requested = port.rawValue
        if parameters.tls != nil {
            // TLS listeners need a server identity (sec_identity); isim provides TLS client connections only
            throw NWError.posix(.ENOTSUP)
        }
        try open()
    }
    public convenience init(using parameters: NWParameters) throws { try self.init(using: parameters, on: .any) }
    public convenience init(service: Service, using parameters: NWParameters) throws {
        try self.init(using: parameters, on: .any); self.service = service
    }

    func open() throws {
        let udp = parameters.isUDP
        let s = socket(AF_INET, udp ? SOCK_DGRAM : SOCK_STREAM, 0)
        guard s >= 0 else { throw _NWErrno.posix(errno) }
        var one: Int32 = 1
        if parameters.allowLocalEndpointReuse || !udp { setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, 4) }
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = requested.bigEndian
        a.sin_addr.s_addr = parameters.acceptLocalOnly ? UInt32(0x7f000001).bigEndian : 0
        let r = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard r == 0 else { let e = errno; close(s); throw _NWErrno.posix(e) }
        if !udp, listen(s, 64) != 0 { let e = errno; close(s); throw _NWErrno.posix(e) }
        fd = s
        if case .hostPort(_, let p)? = _NWSock.local(s) { port = p }
    }

    func setState(_ st: State) {
        lock.lock()
        if _state == .cancelled || _state == st { lock.unlock(); return }
        _state = st
        let h = stateUpdateHandler, q = queue
        lock.unlock()
        if let h { (q ?? .main).async { h(st) } }
    }

    public func start(queue: DispatchQueue) {
        lock.lock(); guard self.queue == nil else { lock.unlock(); return }; self.queue = queue; lock.unlock()
        setState(.ready)
        advertise()
        let loop = DispatchQueue(label: "isim.NWListener.accept")
        if parameters.isUDP { loop.async { self.udpLoop() } } else { loop.async { self.acceptLoop() } }
    }
    func advertise() {
        if let old = registered { _NWBonjour.unregister(old); registered = nil }
        guard let svc = service, let p = port else { return }
        let name = svc.name ?? (ProcessInfo.processInfo.hostName.isEmpty ? "isim" : "iPhone")
        let s = _NWService(name: name, type: _NWBonjour.normType(svc.type), domain: svc.domain ?? "local.", port: p.rawValue, pid: getpid(),
                           txt: svc.txtRecordObject?.dictionary ?? [:])
        _NWBonjour.register(s)
        registered = s
        let ep = NWEndpoint.service(name: name, type: s.type, domain: s.domain, interface: nil)
        if let h = serviceRegistrationUpdateHandler { (queue ?? .main).async { h(.add(ep)) } }
    }
    var accepted = 0
    func acceptLoop() {
        while state == .ready {
            var ss = sockaddr_storage(); var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let c = withUnsafeMutablePointer(to: &ss) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(fd, $0, &len) } }
            if c < 0 { if errno == EINTR { continue }; break }
            guard accepted < newConnectionLimit else { close(c); continue }
            accepted += 1
            if let t = parameters.tcpOptions, t.noDelay { var one: Int32 = 1; setsockopt(c, IPPROTO_TCP, TCP_NODELAY, &one, 4) }
            let peer = withUnsafeBytes(of: &ss) { _NWSock.endpoint($0.baseAddress!, Int(len)) }
            let conn = NWConnection(accepted: c, peer: peer, parameters: parameters)
            if let h = newConnectionHandler { (queue ?? .main).async { h(conn) } } else { close(c) }
        }
    }
    func udpLoop() {
        var buf = [UInt8](repeating: 0, count: 65536)
        while state == .ready {
            var ss = sockaddr_storage(); var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let n = buf.withUnsafeMutableBytes { b in withUnsafeMutablePointer(to: &ss) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, b.baseAddress!, b.count, 0, $0, &len) } } }
            if n < 0 { if errno == EINTR { continue }; break }
            let key = withUnsafeBytes(of: &ss) { Data($0.prefix(Int(len))) }
            let d = Data(buf[0..<n])
            lock.lock(); var conn = udpPeers[key]; lock.unlock()
            if conn == nil {
                let peer = withUnsafeBytes(of: &ss) { _NWSock.endpoint($0.baseAddress!, Int(len)) }
                let c = NWConnection(accepted: -1, peer: peer, parameters: parameters)
                let sfd = fd
                c.udpPeer = (send: { data in key.withUnsafeBytes { sa in data.withUnsafeBytes { p in
                    sendto(sfd, p.baseAddress!, data.count, 0, sa.baseAddress!.assumingMemoryBound(to: sockaddr.self), socklen_t(key.count)) } } }, inbox: _NWInbox())
                lock.lock(); udpPeers[key] = c; lock.unlock()
                conn = c
                if let h = newConnectionHandler { (queue ?? .main).async { h(c) } }
            }
            conn?.udpPeer?.inbox.put(d)
        }
    }
    public func cancel() {
        lock.lock()
        if _state == .cancelled { lock.unlock(); return }
        _state = .cancelled
        let h = stateUpdateHandler, q = queue, f = fd
        lock.unlock()
        if let r = registered {
            _NWBonjour.unregister(r); registered = nil
            let ep = NWEndpoint.service(name: r.name, type: r.type, domain: r.domain, interface: nil)
            if let rh = serviceRegistrationUpdateHandler { (q ?? .main).async { rh(.remove(ep)) } }
        }
        if f >= 0 { shutdown(f, SHUT_RDWR); close(f) }
        if let h { (q ?? .main).async { h(.cancelled) } }
    }
    deinit { if let r = registered { _NWBonjour.unregister(r) } }
}

// MARK: - NWBrowser

public final class NWBrowser: CustomDebugStringConvertible, @unchecked Sendable {
    public enum Descriptor: Hashable, Sendable {
        case bonjour(type: String, domain: String?)
        case bonjourWithTXTRecord(type: String, domain: String?)
        var type: String { switch self { case .bonjour(let t, _), .bonjourWithTXTRecord(let t, _): return t } }
    }
    public enum State: Equatable, Sendable { case setup, ready, failed(NWError), cancelled, waiting(NWError) }
    public struct Result: Hashable, CustomDebugStringConvertible, Sendable {
        public enum Change: Hashable, Sendable {
            case identical, added(Result), removed(Result), changed(old: Result, new: Result, flags: Flags)
            public struct Flags: OptionSet, Hashable, Sendable {
                public let rawValue: UInt32
                public init(rawValue: UInt32) { self.rawValue = rawValue }
                public static let identical = Flags(rawValue: 1), interfaceAdded = Flags(rawValue: 2), interfaceRemoved = Flags(rawValue: 4), metadataChanged = Flags(rawValue: 8)
            }
        }
        public enum Metadata: Hashable, Sendable { case bonjour(NWTXTRecord), none }
        public let endpoint: NWEndpoint
        public let metadata: Metadata
        public let interfaces: [NWInterface]
        public var debugDescription: String { endpoint.debugDescription }
    }
    public let descriptor: Descriptor
    public let parameters: NWParameters
    public var browseResults: Set<Result> { lock.lock(); defer { lock.unlock() }; return results }
    public var browseResultsChangedHandler: (@Sendable (Set<Result>, Set<Result.Change>) -> Void)?
    public var stateUpdateHandler: (@Sendable (State) -> Void)?
    public private(set) var state: State = .setup
    public private(set) var queue: DispatchQueue?
    public var debugDescription: String { "[B \(descriptor.type)]" }
    let lock = NSLock()
    var results: Set<Result> = []
    var timer: DispatchSourceTimer?

    public init(for descriptor: Descriptor, using parameters: NWParameters) { self.descriptor = descriptor; self.parameters = parameters }

    public func start(queue: DispatchQueue) {
        guard self.queue == nil else { return }
        self.queue = queue
        state = .ready
        if let h = stateUpdateHandler { queue.async { h(.ready) } }
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "isim.NWBrowser"))
        t.schedule(deadline: .now(), repeating: 0.5)
        t.setEventHandler { [weak self] in self?.poll() }
        timer = t
        t.resume()
    }
    func poll() {
        let withTXT: Bool = { if case .bonjourWithTXTRecord = descriptor { return true }; return false }()
        let now = Set(_NWBonjour.services(type: descriptor.type).map {
            Result(endpoint: .service(name: $0.name, type: $0.type, domain: $0.domain, interface: nil),
                   metadata: withTXT ? .bonjour(NWTXTRecord($0.txt)) : .none, interfaces: [])
        })
        lock.lock()
        let old = results
        guard now != old else { lock.unlock(); return }
        results = now
        lock.unlock()
        var changes = Set<Result.Change>()
        for r in now where !old.contains(where: { $0.endpoint == r.endpoint }) { changes.insert(.added(r)) }
        for r in old where !now.contains(where: { $0.endpoint == r.endpoint }) { changes.insert(.removed(r)) }
        for r in now { if let o = old.first(where: { $0.endpoint == r.endpoint }), o != r { changes.insert(.changed(old: o, new: r, flags: .metadataChanged)) } }
        if let h = browseResultsChangedHandler, let q = queue { q.async { h(now, changes) } }
    }
    public func cancel() {
        timer?.cancel(); timer = nil
        state = .cancelled
        if let h = stateUpdateHandler { (queue ?? .main).async { h(.cancelled) } }
    }
}
