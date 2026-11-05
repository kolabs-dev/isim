// isim Network (issue #851): more of the structured-concurrency API. DTLS stacks (iOS 27), Framer stacks (an app's
// NWProtocolFramer as the application protocol), integers off byte streams, and WebSocket messages sent and received
// in pieces. Adapted: a framer is the connection's one message protocol (isim runs one message protocol per
// connection), so a framer stacked on WebSocket or TLV is not supported.
import Foundation

/// DTLS over UDP (iOS 27)
@available(iOS 26.0, *)
public struct DTLS: DatagramProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = UDP
    public typealias Metadata = NWProtocolTLS.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    /// whether the peer must present a certificate
    public enum PeerAuthentication: Sendable, Hashable { case required, optional, none }
    var udp = UDP()
    nonisolated(unsafe) var options = NWProtocolTLS.Options()
    public init() {}
    public init(@ProtocolStackBuilder<UDP> _ builder: () -> UDP) { udp = builder() }
    private func with(_ f: (sec_protocol_options_t) -> Void) -> DTLS { f(options.securityProtocolOptions); return self }
    public func applicationProtocols(_ protocols: [String]) -> DTLS { with { o in for p in protocols { sec_protocol_options_add_tls_application_protocol(o, p) } } }
    public func version(min: tls_protocol_version_t? = nil, max: tls_protocol_version_t? = nil) -> DTLS {
        with { o in
            if let min { sec_protocol_options_set_min_tls_protocol_version(o, min) }
            if let max { sec_protocol_options_set_max_tls_protocol_version(o, max) }
        }
    }
    public func localIdentity(_ identity: sec_identity_t) -> DTLS { with { sec_protocol_options_set_local_identity($0, identity) } }
    public func peerAuthentication(_ preference: DTLS.PeerAuthentication) -> DTLS {
        with { sec_protocol_options_set_peer_authentication_required($0, preference == .required) }
    }
    public func certificateValidator(_ handler: @escaping @Sendable (sec_protocol_metadata_t, sec_trust_t) async -> Bool) -> DTLS {
        with { o in
            sec_protocol_options_set_verify_block(o, { metadata, trust, complete in
                Task { complete(await handler(metadata, trust)) }
            }, DispatchQueue.global())
        }
    }
    public func cipherSuites(_ suites: [tls_ciphersuite_t]) -> DTLS { with { o in for s in suites { sec_protocol_options_append_tls_ciphersuite(o, s) } } }
    public func cipherSuiteGroups(_ groups: [tls_ciphersuite_group_t]) -> DTLS { with { o in for g in groups { sec_protocol_options_append_tls_ciphersuite_group(o, g) } } }
    public func ticketsEnabled(_ enabled: Bool) -> DTLS { self }
    public func earlyDataEnabled(_ enabled: Bool) -> DTLS { self }
    public func _apply(to stack: _NWStack) { udp._apply(to: stack); stack.tls = options }
}

/// an app's framer (its NWProtocolFramerImplementation) as the application protocol
@available(iOS 26.0, *)
public struct Framer<T: FramerProtocol>: MessageProtocol, OneToOneProtocol, @unchecked Sendable {
    public typealias BelowProtocol = any NetworkProtocolOptions
    public typealias Metadata = NWProtocolFramer.Message
    public typealias ProtocolStorage = DefaultProtocolStorage
    public typealias ContentType = Data
    public typealias LegacyMessage = NWProtocolFramer.Message
    let below: any NetworkProtocolOptions
    /// the framer's options (pass values to the implementation through them)
    public var options: NWProtocolFramer.Options
    public init<Below: StreamProtocol>(@ProtocolStackBuilder<Below> _ builder: () -> Below) {
        below = builder(); options = NWProtocolFramer.Options(definition: T.definition)
    }
    public init<Below: MessageProtocol>(@ProtocolStackBuilder<Below> _ builder: () -> Below) {
        below = builder(); options = NWProtocolFramer.Options(definition: T.definition)
    }
    public init<Below: StreamProtocol>(using framer: T.Type, @ProtocolStackBuilder<Below> _ builder: () -> Below) {
        below = builder(); options = NWProtocolFramer.Options(definition: T.definition)
    }
    public init<Below: MessageProtocol>(using framer: T.Type, @ProtocolStackBuilder<Below> _ builder: () -> Below) {
        below = builder(); options = NWProtocolFramer.Options(definition: T.definition)
    }
    public func _apply(to stack: _NWStack) { below._apply(to: stack); stack.framer = options }
}

@available(iOS 26.0, *)
extension NetworkChannel {
    /// a message through the framer, with the framer's message metadata
    public func send<T>(_ content: Data, lastMessage: Bool = false, metadata: NWProtocolFramer.Message? = nil,
                        @ProtocolMetadataBuilder other builder: () -> [NWProtocolMetadata] = { [] }) async throws
        where ApplicationProtocol == Framer<T> {
        let m = metadata ?? NWProtocolFramer.Message(definition: T.definition)
        try await core.send(content, context: NWConnection.ContentContext(identifier: "isim.framer", isFinal: lastMessage, metadata: [m] + builder()))
    }
    /// the next message the framer delivered
    public func receive<T>() async throws -> ApplicationProtocol.Message<Data> where ApplicationProtocol == Framer<T> {
        let (d, ctx) = try await core.readMessage()
        let m = (ctx?.protocolMetadata(definition: T.definition) as? NWProtocolFramer.Message) ?? NWProtocolFramer.Message(definition: T.definition)
        return (d, m)
    }
}

@available(iOS 26.0, *)
extension Framer: _NWMessageReceiving {
    public static func _receive(_ channel: NetworkChannel<Framer>) async throws -> Message<Data> { try await channel.receive() }
}

// integers off byte streams
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol: StreamProtocol {
    /// a fixed-width integer in network byte order
    public func receive<Value: NetworkFixedWidthInteger>(as type: Value.Type) async throws -> ApplicationProtocol.Message<Value> {
        let d = try await core.readExactly(MemoryLayout<Value>.size)
        let v = d.reduce(Value.zero) { ($0 << 8) | Value(truncatingIfNeeded: $1) }
        return (v, try _streamMetadata())
    }
    /// a fixed-width integer in network byte order
    public func send<Value: NetworkFixedWidthInteger>(_ value: Value, endOfStream: Bool = false,
                                                      @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) async throws {
        try await send(withUnsafeBytes(of: value.bigEndian) { Data($0) }, endOfStream: endOfStream, metadata: metadata)
    }
    public func sendIdempotent<Value: NetworkFixedWidthInteger>(_ value: Value, endOfStream: Bool = false,
                                                                @ProtocolMetadataBuilder metadata: () -> [NWProtocolMetadata] = { [] }) {
        sendIdempotent(withUnsafeBytes(of: value.bigEndian) { Data($0) }, endOfStream: endOfStream, metadata: metadata)
    }
}

// WebSocket messages in pieces
@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol == WebSocket {
    /// sends a message in pieces: content first, then each piece the handler sends (true marks the last)
    public func startSend<Content: DataProtocol & Sendable>(_ content: Content, @ProtocolMetadataBuilder metadata builder: () -> [NWProtocolMetadata] = { [] },
                                                            handler: ((Content, Bool) async throws -> Void) async throws -> Void) async throws {
        try await _startSend(Data(content), opcode: .binary, builder()) { piece in
            try await handler { c, last in try await piece(Data(c), last) }
        }
    }
    /// sends a text message in pieces
    public func startSend(_ content: String, @ProtocolMetadataBuilder metadata builder: () -> [NWProtocolMetadata] = { [] },
                          handler: ((String, Bool) async throws -> Void) async throws -> Void) async throws {
        try await _startSend(Data(content.utf8), opcode: .text, builder()) { piece in
            try await handler { s, last in try await piece(Data(s.utf8), last) }
        }
    }
    func _startSend(_ first: Data, opcode: NWProtocolWebSocket.Opcode, _ metadata: [NWProtocolMetadata],
                    _ body: (@escaping (Data, Bool) async throws -> Void) async throws -> Void) async throws {
        let ctx = NWConnection.ContentContext(identifier: "isim.websocket", metadata: [NWProtocolWebSocket.Metadata(opcode: opcode)] + metadata)
        try await core.send(first, context: ctx, isComplete: false)
        let done = _NWBox(false)
        try await body { [core] piece, last in
            guard !done.value else { throw NWError.posix(.EINVAL) }
            done.value = last
            try await core.send(piece, context: ctx, isComplete: last)
        }
        if !done.value { try await core.send(Data(), context: ctx, isComplete: true) }
    }
    /// receives messages in pieces: the handler asks for at least / at most a number of bytes of the current message
    public func startReceive(_ handler: ((Int, Int) async throws -> ApplicationProtocol.Message<Data>) async throws -> Void) async throws {
        let p = _NWPendingMessage()
        try await handler { [self] minimum, maximum in
            if !p.started || p.data.isEmpty {
                let (d, m) = try await receive()
                p.data = d; p.meta = m; p.started = true
            }
            let n = Swift.min(Swift.max(minimum, 1), Swift.max(maximum, 1), p.data.count)
            let piece = p.data.prefix(n)
            p.data.removeFirst(piece.count)
            return (Data(piece), p.meta ?? NWProtocolWebSocket.Metadata(opcode: .binary))
        }
    }
}

final class _NWBox<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }
final class _NWPendingMessage: @unchecked Sendable { var data = Data(); var meta: NWProtocolWebSocket.Metadata?; var started = false }
