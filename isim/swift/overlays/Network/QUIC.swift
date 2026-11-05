// isim Network (issue #851): the structured QUIC API (iOS 26): QUIC connections, their streams and datagrams. Stub
// for now: isim has no QUIC transport yet (the host's OpenSSL 3.0 has none), so a QUIC connection fails with ENOTSUP
// and opening streams or datagrams throws it; the types, options and metadata are Apple's.
import Foundation

/// QUIC over UDP: a multiplexed connection of streams (and datagrams)
@available(iOS 26.0, *)
public struct QUIC: MultiplexProtocol, Sendable {
    public typealias BelowProtocol = UDP
    public typealias Metadata = NWProtocolQUIC.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    var udp = UDP()
    nonisolated(unsafe) var options: NWProtocolQUIC.Options
    public init(alpn: [String]) { options = NWProtocolQUIC.Options(alpn: alpn) }
    public init(alpn: [String], @ProtocolStackBuilder<UDP> _ builder: () -> UDP) { options = NWProtocolQUIC.Options(alpn: alpn); udp = builder() }
    private func with(_ f: (NWProtocolQUIC.Options) -> Void) -> QUIC {
        let o = NWProtocolQUIC.Options(alpn: options.alpn), a = options
        o.direction = a.direction; o.isDatagram = a.isDatagram; o.idleTimeout = a.idleTimeout; o.maxUDPPayloadSize = a.maxUDPPayloadSize
        o.initialMaxData = a.initialMaxData; o.initialMaxStreamDataBidirectionalLocal = a.initialMaxStreamDataBidirectionalLocal
        o.initialMaxStreamDataBidirectionalRemote = a.initialMaxStreamDataBidirectionalRemote
        o.initialMaxStreamDataUnidirectional = a.initialMaxStreamDataUnidirectional
        o.initialMaxStreamsBidirectional = a.initialMaxStreamsBidirectional; o.initialMaxStreamsUnidirectional = a.initialMaxStreamsUnidirectional
        o.maxDatagramFrameSize = a.maxDatagramFrameSize
        f(o); var c = self; c.options = o; return c
    }
    public func idleTimeout(_ timeout: Int) -> QUIC { with { $0.idleTimeout = timeout } }
    public func maxUDPPayloadSize(_ size: Int) -> QUIC { with { $0.maxUDPPayloadSize = size } }
    public func initialMaxData(_ initialMaxData: Int) -> QUIC { with { $0.initialMaxData = initialMaxData } }
    public func initialMaxStreamDataBidirectionalLocal(_ initialMaxStreamDataBidiLocal: Int) -> QUIC { with { $0.initialMaxStreamDataBidirectionalLocal = initialMaxStreamDataBidiLocal } }
    public func initialMaxStreamDataBidirectionalRemote(_ initialMaxStreamDataBidiRemote: Int) -> QUIC { with { $0.initialMaxStreamDataBidirectionalRemote = initialMaxStreamDataBidiRemote } }
    public func initialMaxStreamDataUnidirectional(_ initialMaxStreamDataUni: Int) -> QUIC { with { $0.initialMaxStreamDataUnidirectional = initialMaxStreamDataUni } }
    public func initialMaxBidirectionalStreams(_ initialMaxStreamsBidi: Int) -> QUIC { with { $0.initialMaxStreamsBidirectional = initialMaxStreamsBidi } }
    public func initialMaxUnidirectionalStreams(_ initialMaxStreamDataUni: Int) -> QUIC { with { $0.initialMaxStreamsUnidirectional = initialMaxStreamDataUni } }
    public func maxDatagramFrameSize(_ size: Int) -> QUIC { with { $0.maxDatagramFrameSize = size; $0.isDatagram = size > 0 } }

    /// the connection's TLS 1.3 settings
    public struct TLS: Sendable {
        let quic: QUIC
        private func with(_ f: (sec_protocol_options_t) -> Void) -> QUIC { f(quic.options.securityProtocolOptions); return quic }
        public func localIdentity(_ identity: sec_identity_t) -> QUIC { with { sec_protocol_options_set_local_identity($0, identity) } }
        public func peerAuthentication(_ preference: Network.TLS.PeerAuthentication) -> QUIC {
            with { sec_protocol_options_set_peer_authentication_required($0, preference == .required) }
        }
        public func certificateValidator(_ handler: @escaping @Sendable (sec_protocol_metadata_t, sec_trust_t) async -> Bool) -> QUIC {
            with { o in sec_protocol_options_set_verify_block(o, { m, t, complete in Task { complete(await handler(m, t)) } }, DispatchQueue.global()) }
        }
        public func cipherSuites(_ suites: [tls_ciphersuite_t]) -> QUIC { with { o in for s in suites { sec_protocol_options_append_tls_ciphersuite(o, s) } } }
        public func ciphersuiteGroups(_ groups: [tls_ciphersuite_group_t]) -> QUIC { with { o in for g in groups { sec_protocol_options_append_tls_ciphersuite_group(o, g) } } }
    }
    public var tls: QUIC.TLS { TLS(quic: self) }

    public func _apply(to stack: _NWStack) { udp._apply(to: stack); stack.quic = options }

    /// one stream of a QUIC connection
    public final class Stream<ApplicationProtocol: NetworkProtocolOptions>: NetworkChannel<ApplicationProtocol>, @unchecked Sendable {
        public final let parent: NetworkConnection<QUIC>
        public final var directionality: QUICStream.Directionality { _directionality }
        public final var initiator: QUICStream.Initiator { _initiator }
        public final var streamID: UInt64 { _id }
        /// the error code the stream is closed with
        public final var streamApplicationErrorCode: UInt64 = 0
        let _directionality: QUICStream.Directionality, _initiator: QUICStream.Initiator, _id: UInt64
        init(parent: NetworkConnection<QUIC>, core: _NWChannelCore, application: ApplicationProtocol, id: UInt64,
             directionality: QUICStream.Directionality, initiator: QUICStream.Initiator) {
            self.parent = parent; _id = id; _directionality = directionality; _initiator = initiator
            super.init(core: core, application: application)
        }
    }
    /// the datagrams of a QUIC connection
    public final class Datagrams<ApplicationProtocol: NetworkProtocolOptions>: NetworkChannel<ApplicationProtocol>, @unchecked Sendable {
        public final let parent: NetworkConnection<QUIC>
        init(parent: NetworkConnection<QUIC>, core: _NWChannelCore, application: ApplicationProtocol) {
            self.parent = parent
            super.init(core: core, application: application)
        }
    }
}

/// a QUIC stream as a byte stream
@available(iOS 26.0, *)
public struct QUICStream: StreamProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = QUIC
    public typealias Metadata = NWProtocolQUIC.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    /// whether a stream carries data both ways
    public enum Directionality: Sendable, Hashable { case bidirectional, unidirectional }
    /// which side opened a stream
    public enum Initiator: Sendable, Hashable { case client, server }
    public func _apply(to stack: _NWStack) {}
}

/// QUIC datagrams (RFC 9221)
@available(iOS 26.0, *)
public struct QUICDatagram: DatagramProtocol, OneToOneProtocol, Sendable {
    public typealias BelowProtocol = QUIC
    public typealias Metadata = NWProtocolQUIC.Metadata
    public typealias ProtocolStorage = DefaultProtocolStorage
    public func _apply(to stack: _NWStack) {}
}

@available(iOS 26.0, *)
extension NetworkConnection where ApplicationProtocol == QUIC {
    var _quicMetadata: NWProtocolQUIC.Metadata {
        (core.conn.metadata(definition: NWProtocolQUIC.definition) as? NWProtocolQUIC.Metadata) ?? NWProtocolQUIC.Metadata()
    }
    /// opens a stream (isim: QUIC is not available yet, so this throws ENOTSUP once the connection fails)
    public final func openStream(directionality: QUICStream.Directionality = .bidirectional) async throws -> QUIC.Stream<QUICStream> {
        try await core.ready()
        throw NWError.posix(.ENOTSUP)
    }
    public final func openStream<NewApplicationProtocol>(directionality: QUICStream.Directionality = .bidirectional,
                                                         @ProtocolStackBuilder<NewApplicationProtocol> _ prepending: (QUICStream) -> NewApplicationProtocol)
        async throws -> QUIC.Stream<NewApplicationProtocol> {
        try await core.ready()
        throw NWError.posix(.ENOTSUP)
    }
    /// runs handler for each stream the peer opens
    public final func inboundStreams(_ handler: @escaping @Sendable (QUIC.Stream<QUICStream>) async throws -> Void) async throws {
        try await core.ready()
        throw NWError.posix(.ENOTSUP)
    }
    public final func inboundStreams<NewApplicationProtocol>(@ProtocolStackBuilder<NewApplicationProtocol> prepending: @escaping (QUICStream) -> NewApplicationProtocol,
                                                             _ handler: @escaping @Sendable (QUIC.Stream<NewApplicationProtocol>) async throws -> Void) async throws {
        try await core.ready()
        throw NWError.posix(.ENOTSUP)
    }
    /// the connection's datagrams
    public final var datagrams: QUIC.Datagrams<QUICDatagram> {
        get async throws {
            try await core.ready()
            throw NWError.posix(.ENOTSUP)
        }
    }
    public final var applicationError: NWProtocolQUIC.ApplicationError {
        get { _quicMetadata.applicationError }
        set { _quicMetadata.applicationError = newValue }
    }
    public final var keepalive: NWProtocolQUIC.Metadata.KeepAliveBehavior {
        get { _quicMetadata.keepAlive }
        set { _quicMetadata.keepAlive = newValue }
    }
    public final var negotiatedALPN: String? { _quicMetadata.negotiatedALPN }
    public final var remoteIdleTimeout: Int { _quicMetadata.remoteIdleTimeout }
    public final var remoteMaxStreamsBidirectional: Int { _quicMetadata.remoteMaxStreamsBidirectional }
    public final var remoteMaxStreamsUnidirectional: Int { _quicMetadata.remoteMaxStreamsUnidirectional }
    public final var usableDatagramFrameSize: Int { _quicMetadata.usableDatagramFrameSize }
    public final var securityProtocolMetadata: sec_protocol_metadata_t { _quicMetadata.securityProtocolMetadata }
}

@available(iOS 26.0, *)
extension NetworkChannel where ApplicationProtocol == QUICStream {
    @discardableResult
    public func onPathUpdate(_ handler: @escaping @Sendable (NetworkChannel<ApplicationProtocol>, NWPath) -> Void) -> Self {
        core.conn.pathUpdateHandler = { [weak self] p in if let self { handler(self, p) } }; return self
    }
    @discardableResult
    public func onViabilityUpdate(_ handler: @escaping @Sendable (NetworkChannel<ApplicationProtocol>, Bool) -> Void) -> Self {
        core.conn.viabilityUpdateHandler = { [weak self] v in if let self { handler(self, v) } }; return self
    }
    @discardableResult
    public func onBetterPathUpdate(_ handler: @escaping @Sendable (NetworkChannel<ApplicationProtocol>, Bool) -> Void) -> Self {
        core.conn.betterPathUpdateHandler = { [weak self] v in if let self { handler(self, v) } }; return self
    }
}
