// isim Network (issue #422): the iOS 26 structured-concurrency API over isim's NWConnection, NWListener and NWBrowser
// (host sockets and OpenSSL). A connection's protocol stack is written with a result builder ({ TLS() }, { UDP() },
// { WebSocket { TLS() } }, { TLV { TCP() } }, { Coder(Message.self, using: .json) { TLS() } }); each layer turns into
// NWParameters, and what the application protocol allows decides which send and receive methods a NetworkChannel has.
// Adapted: TLV frames are a big-endian type and length (UInt32 each by default) before the value; Coder frames each
// encoded message with a 4-byte big-endian length on streams (one datagram per message on UDP), so isim peers talk to
// each other. DTLS, Framer and QUIC stacks: Structured27.swift and QUIC.swift. Not on isim: Wi-Fi Aware.
import Foundation

// MARK: - protocol stack

/// how a layer turns into NWParameters (isim)
public final class _NWStack: @unchecked Sendable {
    var ip = NWProtocolIP.Options()
    var tcp: NWProtocolTCP.Options?
    var udp: NWProtocolUDP.Options?
    var tls: NWProtocolTLS.Options?
    var webSocket: NWProtocolWebSocket.Options?
    var framer: NWProtocolFramer.Options?
    var quic: NWProtocolQUIC.Options?
    init() {}
    func parameters() -> NWParameters {
        let p = quic.map { NWParameters(quic: $0) }
            ?? (udp != nil ? NWParameters(dtls: tls, udp: udp!) : NWParameters(tls: tls, tcp: tcp ?? NWProtocolTCP.Options()))
        p.defaultProtocolStack.internetProtocol = ip
        if let ws = webSocket { p.defaultProtocolStack.applicationProtocols.insert(ws, at: 0) }
        if let f = framer { p.defaultProtocolStack.applicationProtocols.insert(f, at: 0) }
        return p
    }
}

@available(iOS 26.0, *)
public protocol NetworkProtocolOptions {
    associatedtype BelowProtocol
    associatedtype Metadata
    associatedtype ProtocolStorage
    typealias Message<Content> = (content: Content, metadata: Metadata)
    /// isim: adds this layer and the ones below it to the parameters
    func _apply(to stack: _NWStack)
}
/// a byte stream (TCP, TLS): sends bytes, receives a number of them
@available(iOS 26.0, *) public protocol StreamProtocol: NetworkProtocolOptions {}
/// datagrams (UDP)
@available(iOS 26.0, *) public protocol DatagramProtocol: NetworkProtocolOptions {}
/// whole messages (WebSocket, TLV, Coder)
@available(iOS 26.0, *) public protocol MessageProtocol: NetworkProtocolOptions {
    associatedtype ContentType
    associatedtype LegacyMessage
}
/// one connection per channel
@available(iOS 26.0, *) public protocol OneToOneProtocol: NetworkProtocolOptions {}
/// several streams per connection (QUIC)
@available(iOS 26.0, *) public protocol MultiplexProtocol: NetworkProtocolOptions {}
/// a framer's own protocol
@available(iOS 26.0, *) public protocol FramerProtocol: NetworkProtocolOptions {
    static var definition: NWProtocolFramer.Definition { get }
}
@available(iOS 26.0, *) public protocol NetworkMetadataProtocol {}
@available(iOS 26.0, *) public protocol ConnectionStorage { init() }
@available(iOS 26.0, *) public struct DefaultProtocolStorage: ConnectionStorage, Sendable { public init() {} }

/// a protocol stack: the application protocol, written over the ones below it (adapted: one stack per builder; isim's
/// Swift compiler cannot lower Apple's variadic form)
@available(iOS 26.0, *)
@resultBuilder public struct ProtocolStackBuilder<ApplicationProtocol> {
    public static func buildBlock(_ application: ApplicationProtocol) -> ApplicationProtocol { application }
}
@available(iOS 26.0, *)
@resultBuilder public struct ProtocolMetadataBuilder {
    public static func buildBlock(_ metadata: NWProtocolMetadata...) -> [NWProtocolMetadata] { metadata }
}

@available(iOS 26.0, *)
public struct IP: NetworkProtocolOptions, Sendable {
    public typealias BelowProtocol = Never
    public typealias Metadata = NWProtocolIP.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    nonisolated(unsafe) var options = NWProtocolIP.Options()
    public init() {}
    private func with(_ f: (NWProtocolIP.Options) -> Void) -> IP {
        let o = NWProtocolIP.Options(); o.version = options.version; o.hopLimit = options.hopLimit; o.useMinimumMTU = options.useMinimumMTU
        o.disableFragmentation = options.disableFragmentation; o.shouldCalculateReceiveTime = options.shouldCalculateReceiveTime
        o.localAddressPreference = options.localAddressPreference; o.disableMulticastLoopback = options.disableMulticastLoopback
        f(o); var c = self; c.options = o; return c
    }
    public func version(_ version: NWProtocolIP.Options.Version) -> IP { with { $0.version = version } }
    public func hopLimit(_ hopLimit: UInt8) -> IP { with { $0.hopLimit = hopLimit } }
    public func minimumMTU(_ on: Bool) -> IP { with { $0.useMinimumMTU = on } }
    public func fragmentationDisabled(_ on: Bool) -> IP { with { $0.disableFragmentation = on } }
    public func receiveTimeCalculated(_ on: Bool) -> IP { with { $0.shouldCalculateReceiveTime = on } }
    public func multicastLoopbackDisabled(_ on: Bool) -> IP { with { $0.disableMulticastLoopback = on } }
    /// iOS 26: which local IPv6 address connections use
    public func localAddressPreference(_ preference: NWProtocolIP.Options.AddressPreference) -> IP { with { $0.localAddressPreference = preference } }
    public func _apply(to stack: _NWStack) { stack.ip = options }
}

@available(iOS 26.0, *)
public struct TCP: StreamProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = IP
    public typealias Metadata = NWProtocolTCP.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    var ip = IP()
    nonisolated(unsafe) var options = NWProtocolTCP.Options()
    public init() {}
    public init(_ below: () -> IP) { ip = below() }
    private func with(_ f: (NWProtocolTCP.Options) -> Void) -> TCP {
        let o = NWProtocolTCP.Options(), a = options
        o.noDelay = a.noDelay; o.noPush = a.noPush; o.noOptions = a.noOptions; o.enableKeepalive = a.enableKeepalive
        o.keepaliveCount = a.keepaliveCount; o.keepaliveIdle = a.keepaliveIdle; o.keepaliveInterval = a.keepaliveInterval
        o.maximumSegmentSize = a.maximumSegmentSize; o.connectionTimeout = a.connectionTimeout; o.persistTimeout = a.persistTimeout
        o.connectionDropTime = a.connectionDropTime; o.retransmitFinDrop = a.retransmitFinDrop; o.disableAckStretching = a.disableAckStretching
        o.enableFastOpen = a.enableFastOpen; o.disableECN = a.disableECN
        f(o); var c = self; c.options = o; return c
    }
    public func noDelay(_ on: Bool) -> TCP { with { $0.noDelay = on } }
    public func noPush(_ on: Bool) -> TCP { with { $0.noPush = on } }
    public func noOptions(_ on: Bool) -> TCP { with { $0.noOptions = on } }
    public func keepalive(idleTimeInSeconds: UInt32, count: UInt32, intervalInSeconds: UInt32) -> TCP {
        with { $0.enableKeepalive = true; $0.keepaliveIdle = Int(idleTimeInSeconds); $0.keepaliveCount = Int(count); $0.keepaliveInterval = Int(intervalInSeconds) }
    }
    public func maximumSegmentSize(_ size: UInt32) -> TCP { with { $0.maximumSegmentSize = Int(size) } }
    public func connectionTimeout(_ seconds: UInt32) -> TCP { with { $0.connectionTimeout = Int(seconds) } }
    public func persistTimeout(_ seconds: UInt32) -> TCP { with { $0.persistTimeout = Int(seconds) } }
    public func retransmitConnectionDropTime(_ seconds: UInt32) -> TCP { with { $0.connectionDropTime = Int(seconds) } }
    public func retransmitFinDrop(_ on: Bool) -> TCP { with { $0.retransmitFinDrop = on } }
    public func ackStretchingDisabled(_ on: Bool) -> TCP { with { $0.disableAckStretching = on } }
    public func fastOpenAllowed(_ on: Bool) -> TCP { with { $0.enableFastOpen = on } }
    public func ecnDisabled(_ on: Bool) -> TCP { with { $0.disableECN = on } }
    public func _apply(to stack: _NWStack) { ip._apply(to: stack); stack.tcp = options }
}

@available(iOS 26.0, *)
public struct UDP: DatagramProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = IP
    public typealias Metadata = NWProtocolUDP.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    var ip = IP()
    var noChecksum = false
    public init() {}
    public init(_ below: () -> IP) { ip = below() }
    public func noChecksumPreferred(_ on: Bool) -> UDP { var c = self; c.noChecksum = on; return c }
    public func _apply(to stack: _NWStack) {
        ip._apply(to: stack)
        let o = NWProtocolUDP.Options(); o.preferNoChecksum = noChecksum
        stack.udp = o
    }
}

@available(iOS 26.0, *)
public struct TLS: StreamProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = TCP
    public typealias Metadata = NWProtocolTLS.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    /// whether the peer must present a certificate
    public enum PeerAuthentication: Sendable, Hashable { case required, optional, none }
    var tcp = TCP()
    nonisolated(unsafe) var options = NWProtocolTLS.Options()
    public init() {}
    public init(_ below: () -> TCP) { tcp = below() }
    private func with(_ f: (sec_protocol_options_t) -> Void) -> TLS { f(options.securityProtocolOptions); return self }
    public func applicationProtocols(_ protocols: [String]) -> TLS { with { o in for p in protocols { sec_protocol_options_add_tls_application_protocol(o, p) } } }
    public func version(min: tls_protocol_version_t?, max: tls_protocol_version_t?) -> TLS {
        with { o in
            if let min { sec_protocol_options_set_min_tls_protocol_version(o, min) }
            if let max { sec_protocol_options_set_max_tls_protocol_version(o, max) }
        }
    }
    public func localIdentity(_ identity: sec_identity_t) -> TLS { with { sec_protocol_options_set_local_identity($0, identity) } }
    public func peerAuthentication(_ authentication: PeerAuthentication) -> TLS {
        with { sec_protocol_options_set_peer_authentication_required($0, authentication == .required) }
    }
    public func certificateValidator(_ validator: @escaping @Sendable (sec_protocol_metadata_t, sec_trust_t) async -> Bool) -> TLS {
        with { o in
            sec_protocol_options_set_verify_block(o, { metadata, trust, complete in
                Task { complete(await validator(metadata, trust)) }
            }, DispatchQueue.global())
        }
    }
    public func ticketsEnabled(_ on: Bool) -> TLS { self }
    public func earlyDataEnabled(_ on: Bool) -> TLS { self }
    /// the cipher suites to offer (kept: the host's OpenSSL picks from its own)
    public func cipherSuites(_ suites: [tls_ciphersuite_t]) -> TLS { with { o in for s in suites { sec_protocol_options_append_tls_ciphersuite(o, s) } } }
    public func cipherSuiteGroups(_ groups: [tls_ciphersuite_group_t]) -> TLS { with { o in for g in groups { sec_protocol_options_append_tls_ciphersuite_group(o, g) } } }
    public func _apply(to stack: _NWStack) { tcp._apply(to: stack); stack.tls = options }
}

@available(iOS 26.0, *)
public struct WebSocket: MessageProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = any StreamProtocol
    public typealias Metadata = NWProtocolWebSocket.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    public typealias ContentType = Data
    public typealias LegacyMessage = NWConnection.ContentContext
    nonisolated(unsafe) let below: any StreamProtocol
    nonisolated(unsafe) var options = NWProtocolWebSocket.Options()
    public init<Below: StreamProtocol>(_ below: () -> Below) { self.below = below() }
    private func with(_ f: (NWProtocolWebSocket.Options) -> Void) -> WebSocket { f(options); return self }
    public func autoReplyPing(_ on: Bool) -> WebSocket { with { $0.autoReplyPing = on } }
    public func maximumMessageSize(_ size: Int) -> WebSocket { with { $0.maximumMessageSize = size } }
    public func skipHandshake(_ on: Bool) -> WebSocket { with { $0.skipHandshake = on } }
    public func subprotocols(_ subprotocols: [String]) -> WebSocket { with { $0.setSubprotocols(subprotocols) } }
    public func additionalHeaders(_ headers: [(name: String, value: String)]) -> WebSocket { with { $0.setAdditionalHeaders(headers) } }
    public func _apply(to stack: _NWStack) { below._apply(to: stack); stack.webSocket = options }
}

/// a fixed-width integer in network byte order (TLV's type and length)
@available(iOS 26.0, *)
public protocol NetworkFixedWidthInteger: FixedWidthInteger {
    init(bigEndian: Self)
    var bigEndian: Self { get }
}
@available(iOS 26.0, *) extension UInt8: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension UInt16: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension UInt32: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension UInt64: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension Int8: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension Int16: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension Int32: NetworkFixedWidthInteger {}
@available(iOS 26.0, *) extension Int64: NetworkFixedWidthInteger {}

/// type-length-value messages over a stream
@available(iOS 26.0, *)
public struct TLV: MessageProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = any StreamProtocol
    public typealias ProtocolStorage = DefaultProtocolStorage
    public typealias ContentType = Data
    public typealias LegacyMessage = NWConnection.ContentContext
    /// a received message's type
    public struct Metadata: Sendable, Hashable {
        public let type: Int
    }
    nonisolated(unsafe) let below: any StreamProtocol
    let typeBytes: Int, lengthBytes: Int
    public init<Below: StreamProtocol>(_ below: () -> Below) { self.below = below(); typeBytes = 4; lengthBytes = 4 }
    public init<T: NetworkFixedWidthInteger, L: NetworkFixedWidthInteger, Below: StreamProtocol>(type: T.Type, length: L.Type, _ below: () -> Below) {
        self.below = below(); typeBytes = MemoryLayout<T>.size; lengthBytes = MemoryLayout<L>.size
    }
    public func _apply(to stack: _NWStack) { below._apply(to: stack) }
}

/// encodes and decodes a message's value
@available(iOS 26.0, *) public protocol NetworkEncoder { func encode<T: Encodable>(_ value: T) throws -> Data }
@available(iOS 26.0, *) public protocol NetworkDecoder { func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T }
@available(iOS 26.0, *) extension JSONEncoder: NetworkEncoder {}
@available(iOS 26.0, *) extension JSONDecoder: NetworkDecoder {}
@available(iOS 26.0, *) extension PropertyListEncoder: NetworkEncoder {}
@available(iOS 26.0, *) extension PropertyListDecoder: NetworkDecoder {}
@available(iOS 26.0, *)
public protocol NetworkCoder: Sendable {
    associatedtype Encoder: NetworkEncoder
    associatedtype Decoder: NetworkDecoder
    init()
    func makeEncoder() -> Encoder
    func makeDecoder() -> Decoder
}
@available(iOS 26.0, *)
public struct NetworkJSONCoder: NetworkCoder {
    public init() {}
    public func makeEncoder() -> JSONEncoder { JSONEncoder() }
    public func makeDecoder() -> JSONDecoder { JSONDecoder() }
}
@available(iOS 26.0, *)
public struct NetworkPropertyListCoder: NetworkCoder {
    public init() {}
    public func makeEncoder() -> PropertyListEncoder { PropertyListEncoder() }
    public func makeDecoder() -> PropertyListDecoder { PropertyListDecoder() }
}
@available(iOS 26.0, *)
extension NetworkCoder where Self == NetworkJSONCoder { public static var json: NetworkJSONCoder { NetworkJSONCoder() } }
@available(iOS 26.0, *)
extension NetworkCoder where Self == NetworkPropertyListCoder { public static var propertyList: NetworkPropertyListCoder { NetworkPropertyListCoder() } }

/// Codable messages
@available(iOS 26.0, *)
public struct Coder<Sending: Codable & Sendable, Receiving: Codable & Sendable, CoderType: NetworkCoder>: MessageProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = any NetworkProtocolOptions
    public typealias ProtocolStorage = DefaultProtocolStorage
    public typealias ContentType = Receiving
    public typealias LegacyMessage = NWConnection.ContentContext
    public struct Metadata: Sendable, Hashable {}
    nonisolated(unsafe) let below: any NetworkProtocolOptions
    let coder: CoderType
    public init<Below: StreamProtocol>(_ type: Sending.Type, using coder: CoderType, _ below: () -> Below) where Sending == Receiving {
        self.below = below(); self.coder = coder
    }
    public init<Below: DatagramProtocol>(_ type: Sending.Type, using coder: CoderType, _ below: () -> Below) where Sending == Receiving {
        self.below = below(); self.coder = coder
    }
    public init<Below: StreamProtocol>(sending: Sending.Type, receiving: Receiving.Type, using coder: CoderType, _ below: () -> Below) {
        self.below = below(); self.coder = coder
    }
    public init<Below: DatagramProtocol>(sending: Sending.Type, receiving: Receiving.Type, using coder: CoderType, _ below: () -> Below) {
        self.below = below(); self.coder = coder
    }
    public init<Below: StreamProtocol>(receiving: Receiving.Type, sending: Sending.Type, using coder: CoderType, _ below: () -> Below) {
        self.below = below(); self.coder = coder
    }
    public init<Below: DatagramProtocol>(receiving: Receiving.Type, sending: Sending.Type, using coder: CoderType, _ below: () -> Below) {
        self.below = below(); self.coder = coder
    }
    var _datagrams: Bool { below is any DatagramProtocol }
    public func _apply(to stack: _NWStack) { below._apply(to: stack) }
}

// MARK: - parameters

/// parameters a connection or listener is made with: the protocol stack and NWParameters' settings
@available(iOS 26.0, *)
public protocol NWParametersProvider {
    var parameters: NWParameters { get }
}
@available(iOS 26.0, *)
extension NWParametersProvider {
    private func with(_ f: (NWParameters) -> Void) -> Self { f(parameters); return self }
    public func localEndpoint(_ endpoint: NWEndpoint?) -> Self { with { $0.requiredLocalEndpoint = endpoint } }
    public func localPort(_ port: NWEndpoint.Port) -> Self { with { $0.requiredLocalEndpoint = .hostPort(host: "0.0.0.0", port: port) } }
    public func localEndpointReuseAllowed(_ on: Bool) -> Self { with { $0.allowLocalEndpointReuse = on } }
    public func localOnly(_ on: Bool) -> Self { with { $0.acceptLocalOnly = on } }
    public func peerToPeerIncluded(_ on: Bool) -> Self { with { $0.includePeerToPeer = on } }
    public func fastOpenAllowed(_ on: Bool) -> Self { with { $0.allowFastOpen = on } }
    public func requiredInterface(_ interface: NWInterface) -> Self { with { $0.requiredInterface = interface } }
    public func requiredInterfaceType(_ type: NWInterface.InterfaceType) -> Self { with { $0.requiredInterfaceType = type } }
    public func prohibitedInterfaces(_ interfaces: [NWInterface]) -> Self { with { $0.prohibitedInterfaces = interfaces } }
    public func prohibitedInterfaceTypes(_ types: [NWInterface.InterfaceType]) -> Self { with { $0.prohibitedInterfaceTypes = types } }
    public func expensivePathsProhibited(_ on: Bool) -> Self { with { $0.prohibitExpensivePaths = on } }
    public func constrainedPathsProhibited(_ on: Bool) -> Self { with { $0.prohibitConstrainedPaths = on } }
    public func ultraConstrainedPathsAllowed(_ on: Bool) -> Self { with { $0.allowUltraConstrainedPaths = on } }
    public func noProxiesPreferred(_ on: Bool) -> Self { with { $0.preferNoProxies = on } }
    public func serviceClass(_ serviceClass: NWParameters.ServiceClass) -> Self { with { $0.serviceClass = serviceClass } }
    public func multipathServiceType(_ type: NWParameters.MultipathServiceType) -> Self { with { $0.multipathServiceType = type } }
    public func expiredDNSBehavior(_ behavior: NWParameters.ExpiredDNSBehavior) -> Self { with { $0.expiredDNSBehavior = behavior } }
    public func dnssecValidationRequired(_ on: Bool) -> Self { with { $0.requiresDNSSECValidation = on } }
}

/// a protocol stack and the parameters around it
@available(iOS 26.0, *)
public struct NWParametersBuilder<Top: NetworkProtocolOptions>: NWParametersProvider, @unchecked Sendable {
    public let parameters: NWParameters
    let top: Top
    public init(@ProtocolStackBuilder<Top> _ stack: () -> Top) {
        top = stack()
        let st = _NWStack(); top._apply(to: st)
        parameters = st.parameters()
    }
    public init(auto stack: () -> Top) { self.init(stack) }
    init(top: Top, parameters: NWParameters) { self.top = top; self.parameters = parameters }
    public static func parameters(@ProtocolStackBuilder<Top> _ stack: () -> Top) -> NWParametersBuilder<Top> { NWParametersBuilder(stack) }
    public static func parameters(initialParameters: NWParameters, @ProtocolStackBuilder<Top> _ stack: () -> Top) -> NWParametersBuilder<Top> {
        let top = stack()
        let st = _NWStack(); top._apply(to: st)
        let p = st.parameters()
        p.requiredLocalEndpoint = initialParameters.requiredLocalEndpoint; p.allowLocalEndpointReuse = initialParameters.allowLocalEndpointReuse
        p.acceptLocalOnly = initialParameters.acceptLocalOnly; p.includePeerToPeer = initialParameters.includePeerToPeer
        p.requiredInterfaceType = initialParameters.requiredInterfaceType; p.serviceClass = initialParameters.serviceClass
        return NWParametersBuilder(top: top, parameters: p)
    }
}

// MARK: - channels and connections

/// something a connection can be made to: an endpoint, or one a browser found
@available(iOS 26.0, *)
public protocol Connectable: Sendable {
    var _nwEndpoint: NWEndpoint { get }
}
@available(iOS 26.0, *)
extension NWEndpoint: Connectable { public var _nwEndpoint: NWEndpoint { self } }

/// the connection beneath a NetworkChannel: async reads with a buffer for framing (isim)
final class _NWChannelCore: @unchecked Sendable {
    let conn: NWConnection
    let lock = NSLock()
    var started = false
    var buffer = Data()
    var stateWaiters: [CheckedContinuation<Void, Error>] = []
    var stateHandlers: [@Sendable (NWConnection.State) -> Void] = []
    var pendingReport: NWConnection.PendingDataTransferReport?
    init(_ c: NWConnection) {
        conn = c
        c.stateUpdateHandler = { [weak self] s in self?.stateChanged(s) }
    }
    func start() {
        lock.lock(); let go = !started; started = true; lock.unlock()
        if go {
            let r = conn.startDataTransferReport()
            lock.lock(); pendingReport = r; lock.unlock()
            conn.start(queue: DispatchQueue(label: "isim.NetworkConnection"))
        }
    }
    func stateChanged(_ s: NWConnection.State) {
        lock.lock()
        let handlers = stateHandlers
        var resume: [CheckedContinuation<Void, Error>] = []
        var failure: NWError?
        switch s {
        case .ready: resume = stateWaiters; stateWaiters = []
        case .failed(let e): resume = stateWaiters; stateWaiters = []; failure = e
        case .cancelled: resume = stateWaiters; stateWaiters = []; failure = .posix(.ECANCELED)
        default: break
        }
        lock.unlock()
        for h in handlers { h(s) }
        for w in resume { if let failure { w.resume(throwing: failure) } else { w.resume() } }
    }
    /// starts the connection if needed and waits until it is ready
    func ready() async throws {
        start()
        switch conn.state {
        case .ready: return
        case .failed(let e): throw e
        case .cancelled: throw NWError.posix(.ECANCELED)
        default: break
        }
        /* a connection that is waiting (refused, no route) waits, as on iOS, until it is ready or the task is cancelled */
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
                lock.lock()
                switch conn.state {
                case .ready: lock.unlock(); k.resume()
                case .failed(let e): lock.unlock(); k.resume(throwing: e)
                case .cancelled: lock.unlock(); k.resume(throwing: NWError.posix(.ECANCELED))
                default:
                    if Task.isCancelled { lock.unlock(); k.resume(throwing: CancellationError()) } else { stateWaiters.append(k); lock.unlock() }
                }
            }
        } onCancel: { [self] in
            lock.lock(); let waiters = stateWaiters; stateWaiters = []; lock.unlock()
            for w in waiters { w.resume(throwing: CancellationError()) }
        }
    }
    func send(_ data: Data?, context: NWConnection.ContentContext = .defaultMessage, isComplete: Bool = true) async throws {
        try await ready()
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            conn.send(content: data, contentContext: context, isComplete: isComplete, completion: .contentProcessed { e in
                if let e { k.resume(throwing: e) } else { k.resume() }
            })
        }
    }
    func sendIdempotent(_ data: Data?, context: NWConnection.ContentContext = .defaultMessage, isComplete: Bool = true) {
        start()
        conn.send(content: data, contentContext: context, isComplete: isComplete, completion: .idempotent)
    }
    /// at least min bytes (fewer only at the end of the stream), at most max
    func read(min: Int, max: Int) async throws -> Data {
        try await ready()
        lock.lock()
        if buffer.count >= min {
            let n = Swift.min(buffer.count, max)
            let d = buffer.prefix(n); buffer.removeFirst(n); lock.unlock()
            return Data(d)
        }
        lock.unlock()
        while true {
            let (chunk, done) = try await withCheckedThrowingContinuation { (k: CheckedContinuation<(Data?, Bool), Error>) in
                conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { d, _, complete, e in
                    if let e { k.resume(throwing: e) } else { k.resume(returning: (d, complete)) }
                }
            }
            lock.lock()
            if let chunk { buffer.append(chunk) }
            if buffer.count >= min || (done && chunk == nil) || done {
                let n = Swift.min(buffer.count, max)
                let d = buffer.prefix(n); buffer.removeFirst(n); lock.unlock()
                if d.count < min && (done || chunk == nil) && d.isEmpty { throw NWError.posix(.ENODATA) }
                return Data(d)
            }
            lock.unlock()
        }
    }
    func readExactly(_ n: Int) async throws -> Data {
        let d = try await read(min: n, max: n)
        guard d.count == n else { throw NWError.posix(.ENODATA) }
        return d
    }
    /// a whole message (datagram or WebSocket frame) and its context
    func readMessage() async throws -> (Data, NWConnection.ContentContext?) {
        try await ready()
        return try await withCheckedThrowingContinuation { (k: CheckedContinuation<(Data, NWConnection.ContentContext?), Error>) in
            conn.receiveMessage { d, ctx, _, e in
                if let e { k.resume(throwing: e) } else if let d { k.resume(returning: (d, ctx)) } else { k.resume(throwing: NWError.posix(.ENODATA)) }
            }
        }
    }
}

/// a channel of an application protocol: what can be sent and received depends on the protocol
@available(iOS 26.0, *)
public class NetworkChannel<ApplicationProtocol: NetworkProtocolOptions>: Identifiable, Equatable, CustomDebugStringConvertible, @unchecked Sendable {
    public enum State: Equatable, Sendable { case setup, waiting(NWError), preparing, ready, failed(NWError), cancelled }
    let core: _NWChannelCore
    let application: ApplicationProtocol
    init(core: _NWChannelCore, application: ApplicationProtocol) { self.core = core; self.application = application }
    public var id: String { String(UInt(bitPattern: ObjectIdentifier(self).hashValue), radix: 16) }
    public var debugDescription: String { core.conn.debugDescription }
    public var parameters: NWParameters { core.conn.parameters }
    public var maximumDatagramSize: Int { core.conn.maximumDatagramSize }
    public var state: State { State(core.conn.state) }
    public static func == (a: NetworkChannel, b: NetworkChannel) -> Bool { a === b }
    public func metadata(definition: NWProtocolDefinition) -> NWProtocolMetadata? { core.conn.metadata(definition: definition) }
}
@available(iOS 26.0, *)
extension NetworkChannel.State {
    init(_ s: NWConnection.State) {
        switch s {
        case .setup: self = .setup
        case .waiting(let e): self = .waiting(e)
        case .preparing: self = .preparing
        case .ready: self = .ready
        case .failed(let e): self = .failed(e)
        case .cancelled: self = .cancelled
        }
    }
}

// byte streams: TCP, TLS
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol: StreamProtocol {
    public func send<Content: DataProtocol>(_ content: Content, endOfStream: Bool = false,
                                            @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(Data(content), context: endOfStream ? .finalMessage : .defaultStream, isComplete: endOfStream)
    }
    public func sendIdempotent<Content: DataProtocol>(_ content: Content, endOfStream: Bool = false,
                                                      @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) {
        core.sendIdempotent(Data(content), context: endOfStream ? .finalMessage : .defaultStream, isComplete: endOfStream)
    }
    public func receive(exactly length: Int) async throws -> ApplicationProtocol.Message<Data> {
        (try await core.readExactly(length), try _streamMetadata())
    }
    public func receive(atLeast minimum: Int, atMost maximum: Int) async throws -> ApplicationProtocol.Message<Data> {
        (try await core.read(min: minimum, max: maximum), try _streamMetadata())
    }
    func _streamMetadata() throws -> ApplicationProtocol.Metadata {
        if let m = ApplicationProtocol.Metadata.self as? NWProtocolTCP.Metadata.Type { return m.init() as! ApplicationProtocol.Metadata }
        if let m = core.conn.metadata(definition: NWProtocolTLS.definition) as? ApplicationProtocol.Metadata { return m }
        throw NWError.posix(.EINVAL)
    }
}

// datagrams: UDP
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol: DatagramProtocol {
    public func send<Content: DataProtocol>(_ content: Content, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(Data(content))
    }
    public func sendIdempotent<Content: DataProtocol>(_ content: Content, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) {
        core.sendIdempotent(Data(content))
    }
    public func receive() async throws -> ApplicationProtocol.Message<Data> {
        let (d, _) = try await core.readMessage()
        if let m = NWProtocolUDP.Metadata() as? ApplicationProtocol.Metadata { return (d, m) }
        if let m = core.conn.metadata(definition: NWProtocolTLS.definition) as? ApplicationProtocol.Metadata { return (d, m) }   /* DTLS */
        throw NWError.posix(.EINVAL)
    }
}

// WebSocket
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol == WebSocket {
    private func frame(_ opcode: NWProtocolWebSocket.Opcode, _ metadata: [NWProtocolMetadata] = []) -> NWConnection.ContentContext {
        NWConnection.ContentContext(identifier: "isim.websocket", metadata: [NWProtocolWebSocket.Metadata(opcode: opcode)] + metadata)
    }
    public func send<Content: DataProtocol>(_ content: Content, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(Data(content), context: frame(.binary, metadata()))
    }
    public func send(_ string: String, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(Data(string.utf8), context: frame(.text, metadata()))
    }
    public func sendIdempotent(_ string: String, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) {
        core.sendIdempotent(Data(string.utf8), context: frame(.text, metadata()))
    }
    public func ping<Content: DataProtocol>(_ content: Content?, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(content.map { Data($0) } ?? Data(), context: frame(.ping, metadata()))
    }
    public func pong<Content: DataProtocol>(_ content: Content?, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await core.send(content.map { Data($0) } ?? Data(), context: frame(.pong, metadata()))
    }
    public func close(code: NWProtocolWebSocket.CloseCode = .protocolCode(.normalClosure), reason: String? = nil,
                      @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        let m = NWProtocolWebSocket.Metadata(opcode: .close)
        m.closeCode = code
        try await core.send(reason.map { Data($0.utf8) } ?? Data(), context: NWConnection.ContentContext(identifier: "isim.websocket.close", metadata: [m]))
    }
    public func receive() async throws -> WebSocket.Message<Data> {
        let (d, ctx) = try await core.readMessage()
        let m = (ctx?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata) ?? NWProtocolWebSocket.Metadata(opcode: .binary)
        return (d, m)
    }
}

// TLV
extension Data {
    func _bigEndianInt(_ bytes: Int) -> Int { reduce(0) { ($0 << 8) | Int($1) } }
    static func _bigEndian(_ v: Int, _ bytes: Int) -> Data { Data((0..<bytes).reversed().map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) }) }
}
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol == TLV {
    public func send<Content: DataProtocol>(_ content: Content, type: Int, lastMessage: Bool = false,
                                            @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        let t = application, value = Data(content)
        try await core.send(Data._bigEndian(type, t.typeBytes) + Data._bigEndian(value.count, t.lengthBytes) + value,
                            context: lastMessage ? .finalMessage : .defaultStream, isComplete: lastMessage)
    }
    public func sendIdempotent<Content: DataProtocol>(_ content: Content, type: Int, lastMessage: Bool = false,
                                                      @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) {
        let t = application, value = Data(content)
        core.sendIdempotent(Data._bigEndian(type, t.typeBytes) + Data._bigEndian(value.count, t.lengthBytes) + value)
    }
    public func receive() async throws -> TLV.Message<Data> {
        let t = application
        let header = try await core.readExactly(t.typeBytes + t.lengthBytes)
        let type = header.prefix(t.typeBytes)._bigEndianInt(t.typeBytes), length = header.suffix(t.lengthBytes)._bigEndianInt(t.lengthBytes)
        let value = length > 0 ? try await core.readExactly(length) : Data()
        return (value, TLV.Metadata(type: type))
    }
}

// Coder
@available(iOS 26.0, *)
extension NetworkChannel {
    public func send<Sending, Receiving, CoderType>(_ value: Sending, @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws
        where ApplicationProtocol == Coder<Sending, Receiving, CoderType> {
        let data = try application.coder.makeEncoder().encode(value)
        if application._datagrams { try await core.send(data) } else { try await core.send(Data._bigEndian(data.count, 4) + data, context: .defaultStream, isComplete: false) }
    }
    public func receive<Sending, Receiving, CoderType>() async throws -> ApplicationProtocol.Message<Receiving>
        where ApplicationProtocol == Coder<Sending, Receiving, CoderType> {
        let data: Data
        if application._datagrams { data = try await core.readMessage().0 }
        else { let n = try await core.readExactly(4)._bigEndianInt(4); data = n > 0 ? try await core.readExactly(n) : Data() }
        return (try application.coder.makeDecoder().decode(Receiving.self, from: data), Coder<Sending, Receiving, CoderType>.Metadata())
    }
}

/// whole messages as they arrive, until the connection ends
@available(iOS 26.0, *)
public protocol _NWMessageReceiving: MessageProtocol {
    static func _receive(_ channel: NetworkChannel<Self>) async throws -> Message<ContentType>
}
@available(iOS 26.0, *)
extension WebSocket: _NWMessageReceiving {
    public static func _receive(_ channel: NetworkChannel<WebSocket>) async throws -> Message<Data> { try await channel.receive() }
}
@available(iOS 26.0, *)
extension TLV: _NWMessageReceiving {
    public static func _receive(_ channel: NetworkChannel<TLV>) async throws -> Message<Data> { try await channel.receive() }
}
@available(iOS 26.0, *)
extension Coder: _NWMessageReceiving {
    public static func _receive(_ channel: NetworkChannel<Coder>) async throws -> Message<Receiving> { try await channel.receive() }
}
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol: _NWMessageReceiving {
    public var messages: AsyncThrowingStream<ApplicationProtocol.Message<ApplicationProtocol.ContentType>, any Error> {
        AsyncThrowingStream { [self] in
            do { return try await ApplicationProtocol._receive(self) }
            catch NWError.posix(.ENODATA) { return nil }
            catch let e as NWError where self.core.conn.state == .cancelled { _ = e; return nil }
        }
    }
}

/// a connection to an endpoint with an application protocol
@available(iOS 26.0, *)
public final class NetworkConnection<ApplicationProtocol: NetworkProtocolOptions>: NetworkChannel<ApplicationProtocol>, @unchecked Sendable {
    public convenience init(to endpoint: NWEndpoint, @ProtocolStackBuilder<ApplicationProtocol> using stack: () -> ApplicationProtocol) {
        self.init(to: endpoint, using: NWParametersBuilder<ApplicationProtocol>(stack))
    }
    public convenience init(to endpoint: NWEndpoint, using builder: NWParametersBuilder<ApplicationProtocol>) {
        self.init(core: _NWChannelCore(NWConnection(to: endpoint, using: builder.parameters)), application: builder.top)
    }
    public convenience init(to connectable: any Connectable, @ProtocolStackBuilder<ApplicationProtocol> using stack: () -> ApplicationProtocol) {
        self.init(to: connectable._nwEndpoint, using: NWParametersBuilder<ApplicationProtocol>(stack))
    }
    public convenience init(to connectable: any Connectable, using builder: NWParametersBuilder<ApplicationProtocol>) {
        self.init(to: connectable._nwEndpoint, using: builder)
    }
    /// starts connecting (sending or receiving starts it too)
    @discardableResult public func start() -> Self { core.start(); return self }
    public var localEndpoint: NWEndpoint? { core.conn.currentPath?.localEndpoint }
    public var remoteEndpoint: NWEndpoint? { core.conn.currentPath?.remoteEndpoint ?? core.conn.endpoint }
    public var currentPath: NWPath? { core.conn.currentPath }
    public func tryNextEndpoint() { core.conn.restart() }
    @discardableResult
    public func onStateUpdate(_ handler: @escaping @Sendable (NetworkConnection<ApplicationProtocol>, NetworkChannel<ApplicationProtocol>.State) -> Void) -> Self {
        core.lock.lock()
        core.stateHandlers.append { [weak self] s in if let self { handler(self, State(s)) } }
        core.lock.unlock()
        return self
    }
    @discardableResult
    public func onPathUpdate(_ handler: @escaping @Sendable (NetworkConnection<ApplicationProtocol>, NWPath) -> Void) -> Self {
        core.conn.pathUpdateHandler = { [weak self] p in if let self { handler(self, p) } }; return self
    }
    @discardableResult
    public func onViabilityUpdate(_ handler: @escaping @Sendable (NetworkConnection<ApplicationProtocol>, Bool) -> Void) -> Self {
        core.conn.viabilityUpdateHandler = { [weak self] v in if let self { handler(self, v) } }; return self
    }
    @discardableResult
    public func onBetterPathUpdate(_ handler: @escaping @Sendable (NetworkConnection<ApplicationProtocol>, Bool) -> Void) -> Self {
        core.conn.betterPathUpdateHandler = { [weak self] v in if let self { handler(self, v) } }; return self
    }
    deinit { core.conn.cancel() }
}

/// runs body with a connection, and closes it after
@available(iOS 26.0, *)
public func withNetworkConnection<ApplicationProtocol: NetworkProtocolOptions, Result>(
    to endpoint: NWEndpoint, @ProtocolStackBuilder<ApplicationProtocol> using stack: () -> ApplicationProtocol,
    _ body: (NetworkConnection<ApplicationProtocol>) async throws -> Result) async throws -> Result {
    try await withNetworkConnection(to: endpoint, using: NWParametersBuilder<ApplicationProtocol>(stack), body)
}
@available(iOS 26.0, *)
public func withNetworkConnection<ApplicationProtocol: NetworkProtocolOptions, Result>(
    to endpoint: NWEndpoint, using builder: NWParametersBuilder<ApplicationProtocol>,
    _ body: (NetworkConnection<ApplicationProtocol>) async throws -> Result) async throws -> Result {
    let c = NetworkConnection(to: endpoint, using: builder)
    c.start()
    defer { c.core.conn.cancel() }
    return try await body(c)
}

// MARK: - listeners

/// what a listener advertises (Bonjour)
@available(iOS 26.0, *)
public protocol ListenerProvider: Sendable {
    var service: NWListener.Service { get }
}
@available(iOS 26.0, *)
public struct BonjourListenerProvider: ListenerProvider {
    public let service: NWListener.Service
    public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: NWTXTRecord? = nil) {
        service = txtRecord.map { NWListener.Service(name: name, type: type, domain: domain, txtRecord: $0) } ?? NWListener.Service(name: name, type: type, domain: domain)
    }
}
@available(iOS 26.0, *)
extension ListenerProvider where Self == BonjourListenerProvider {
    public static func bonjour(name: String? = nil, type: String, domain: String? = nil, txtRecord: NWTXTRecord? = nil) -> BonjourListenerProvider {
        BonjourListenerProvider(name: name, type: type, domain: domain, txtRecord: txtRecord)
    }
}

/// accepts connections and runs a closure for each
@available(iOS 26.0, *)
public final class NetworkListener<ApplicationProtocol: NetworkProtocolOptions>: @unchecked Sendable {
    public enum State: Equatable, Sendable { case setup, waiting(NWError), ready, failed(NWError), cancelled }
    public enum ServiceRegistrationChange: Sendable { case add(NWEndpoint), remove(NWEndpoint) }
    public typealias StateUpdateHandler = @Sendable (NetworkListener<ApplicationProtocol>, State) -> Void
    public typealias ServiceRegistrationUpdateHandler = @Sendable (NetworkListener<ApplicationProtocol>, ServiceRegistrationChange) -> Void
    let listener: NWListener
    let application: ApplicationProtocol
    var stateHandler: StateUpdateHandler?
    var registrationHandler: ServiceRegistrationUpdateHandler?
    public convenience init(for provider: (any ListenerProvider)? = nil, @ProtocolStackBuilder<ApplicationProtocol> using stack: () -> ApplicationProtocol) throws {
        try self.init(for: provider, using: NWParametersBuilder<ApplicationProtocol>(stack))
    }
    public init(for provider: (any ListenerProvider)? = nil, using builder: NWParametersBuilder<ApplicationProtocol>) throws {
        var port = NWEndpoint.Port.any
        if case .hostPort(_, let p) = builder.parameters.requiredLocalEndpoint { port = p }
        listener = try NWListener(using: builder.parameters, on: port)
        listener.service = provider?.service
        application = builder.top
    }
    public var port: NWEndpoint.Port? { listener.port }
    public var service: NWListener.Service? { listener.service }
    public var newConnectionLimit: Int { get { listener.newConnectionLimit } set { listener.newConnectionLimit = newValue } }
    @discardableResult public func newConnectionLimit(_ limit: Int) -> Self { listener.newConnectionLimit = limit; return self }
    @discardableResult public func onStateUpdate(_ handler: @escaping StateUpdateHandler) -> Self { stateHandler = handler; return self }
    @discardableResult public func onServiceRegistrationUpdate(_ handler: @escaping ServiceRegistrationUpdateHandler) -> Self {
        registrationHandler = handler; return self
    }
    /// accepts connections until the task is cancelled; each runs handler in a task of its own
    public func run(_ handler: @escaping @Sendable (NetworkConnection<ApplicationProtocol>) async throws -> Void) async throws {
        let (incoming, sink) = AsyncThrowingStream<NWConnection, Error>.makeStream()
        listener.newConnectionHandler = { sink.yield($0) }
        listener.stateUpdateHandler = { [weak self] s in
            guard let self else { return }
            let st: State
            switch s {
            case .setup: st = .setup
            case .waiting(let e): st = .waiting(e)
            case .ready: st = .ready
            case .failed(let e): st = .failed(e); sink.finish(throwing: e)
            case .cancelled: st = .cancelled; sink.finish()
            }
            self.stateHandler?(self, st)
        }
        listener.serviceRegistrationUpdateHandler = { [weak self] change in
            guard let self else { return }
            switch change {
            case .add(let e): self.registrationHandler?(self, .add(e))
            case .remove(let e): self.registrationHandler?(self, .remove(e))
            }
        }
        listener.start(queue: DispatchQueue(label: "isim.NetworkListener"))
        let app = application
        try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for try await c in incoming {
                    let connection = NetworkConnection(core: _NWChannelCore(c), application: app)
                    group.addTask { try? await handler(connection); connection.core.conn.cancel() }
                }
            }
        } onCancel: { [listener] in listener.cancel() }
    }
}

// MARK: - browsers

/// what a browser looks for
@available(iOS 26.0, *)
public protocol BrowserProvider: Sendable {
    associatedtype Endpoint: Sendable
    var _descriptor: NWBrowser.Descriptor { get }
    func _endpoint(_ result: NWBrowser.Result) -> Endpoint
}
/// Bonjour services of a type
@available(iOS 26.0, *)
public struct Bonjour: BrowserProvider {
    public struct Endpoint: Connectable, Hashable, Identifiable, CustomStringConvertible, Sendable {
        public let name: String
        public let type: String
        public let domain: String
        public let txtRecord: NWTXTRecord
        public let result: NWBrowser.Result
        public var nwEndpoint: NWEndpoint { result.endpoint }
        public var _nwEndpoint: NWEndpoint { result.endpoint }
        public var id: String { "\(name).\(type)\(domain)" }
        public var description: String { "\(name).\(type)\(domain)" }
        public static func == (a: Endpoint, b: Endpoint) -> Bool { a.result == b.result }
        public func hash(into h: inout Hasher) { h.combine(result) }
    }
    let type: String, domain: String?, txt: Bool
    public var _descriptor: NWBrowser.Descriptor { txt ? .bonjourWithTXTRecord(type: type, domain: domain) : .bonjour(type: type, domain: domain) }
    public func _endpoint(_ r: NWBrowser.Result) -> Endpoint {
        var name = "", type = self.type, domain = domain ?? "local."
        if case .service(let n, let t, let d, _) = r.endpoint { name = n; type = t; domain = d }
        var txt = NWTXTRecord()
        if case .bonjour(let t) = r.metadata { txt = t }
        return Endpoint(name: name, type: type, domain: domain, txtRecord: txt, result: r)
    }
}
@available(iOS 26.0, *)
extension BrowserProvider where Self == Bonjour {
    public static func bonjour(_ type: String, domain: String? = nil, includeTxtRecord: Bool = false) -> Bonjour {
        Bonjour(type: type, domain: domain, txt: includeTxtRecord)
    }
}

/// finds endpoints, handing each updated set to a closure
@available(iOS 26.0, *)
public final class NetworkBrowser<Provider: BrowserProvider>: @unchecked Sendable {
    public enum State: Equatable, Sendable { case setup, ready, failed(NWError), cancelled, waiting(NWError) }
    public enum RunResult<T> { case `continue`, finish(T) }
    public typealias StateUpdateHandler = @Sendable (NetworkBrowser<Provider>, State) -> Void
    let provider: Provider
    let browser: NWBrowser
    var stateHandler: StateUpdateHandler?
    public init(for provider: Provider, using parameters: NWParameters? = nil) {
        self.provider = provider
        browser = NWBrowser(for: provider._descriptor, using: parameters ?? .tcp)
    }
    @discardableResult public func onStateUpdate(_ handler: @escaping StateUpdateHandler) -> Self { stateHandler = handler; return self }
    /// hands each updated set of endpoints to body until it finishes
    public func run<Return>(_ body: @escaping ([Provider.Endpoint]) async throws -> RunResult<Return>) async throws -> Return {
        let (updates, sink) = AsyncThrowingStream<[NWBrowser.Result], Error>.makeStream()
        browser.browseResultsChangedHandler = { results, _ in sink.yield(results.sorted { $0.endpoint.debugDescription < $1.endpoint.debugDescription }) }
        browser.stateUpdateHandler = { [weak self] s in
            guard let self else { return }
            let st: State
            switch s {
            case .setup: st = .setup
            case .ready: st = .ready; sink.yield(self.browser.browseResults.sorted { $0.endpoint.debugDescription < $1.endpoint.debugDescription })
            case .failed(let e): st = .failed(e); sink.finish(throwing: e)
            case .cancelled: st = .cancelled; sink.finish()
            case .waiting(let e): st = .waiting(e)
            }
            self.stateHandler?(self, st)
        }
        browser.start(queue: DispatchQueue(label: "isim.NetworkBrowser"))
        defer { browser.cancel() }
        return try await withTaskCancellationHandler {
            for try await results in updates {
                if case .finish(let r) = try await body(results.map(provider._endpoint)) { return r }
            }
            throw CancellationError()
        } onCancel: { [browser] in browser.cancel() }
    }
    /// hands each updated set of endpoints to body until the task is cancelled
    public func run(_ body: @escaping ([Provider.Endpoint]) async throws -> Void) async throws {
        let _: Void = try await run { endpoints -> RunResult<Void> in try await body(endpoints); return .continue }
    }
}

/// an endpoint of a kind the API cannot use there
@available(iOS 26.0, *)
public struct UnexpectedEndpointType: Error, Sendable {
    public let endpoint: NWEndpoint
    public init(endpoint: NWEndpoint) { self.endpoint = endpoint }
}
