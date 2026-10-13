// Network framework message protocols: NWProtocolWebSocket (a client against ws_server.py, and an NWListener
// WebSocket server with an NWConnection client in this process), NWProtocolFramer (a type-length-value framer with a
// handshake of its own on both ends) and NWConnectionGroup (UDP multicast, two group members in this process).
import Foundation
import Network
import Security

/// waits for a connection or listener to become ready (or fail)
func waitReady(_ c: NWConnection, _ what: String) -> Bool {
    let sem = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var ok = false
    c.stateUpdateHandler = { s in
        switch s {
        case .ready: ok = true; sem.signal()
        case .failed(let e), .waiting(let e): print("\(what): \(e)"); sem.signal()
        default: break
        }
    }
    c.start(queue: DispatchQueue(label: what))
    _ = sem.wait(timeout: .now() + 10)
    return ok
}

func receiveMessage(_ c: NWConnection) -> (Data?, NWConnection.ContentContext?, NWError?) {
    let sem = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var out: (Data?, NWConnection.ContentContext?, NWError?) = (nil, nil, nil)
    c.receiveMessage { d, ctx, _, e in out = (d, ctx, e); sem.signal() }
    if sem.wait(timeout: .now() + 10) == .timedOut { return (nil, nil, .posix(.ETIMEDOUT)) }
    return out
}

func sendMessage(_ c: NWConnection, _ d: Data?, _ ctx: NWConnection.ContentContext) -> NWError? {
    let sem = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var err: NWError?
    c.send(content: d, contentContext: ctx, isComplete: true, completion: .contentProcessed { e in err = e; sem.signal() })
    _ = sem.wait(timeout: .now() + 10)
    return err
}

func wsContext(_ op: NWProtocolWebSocket.Opcode, _ configure: (NWProtocolWebSocket.Metadata) -> Void = { _ in }) -> NWConnection.ContentContext {
    let m = NWProtocolWebSocket.Metadata(opcode: op)
    configure(m)
    return NWConnection.ContentContext(identifier: "ws", metadata: [m])
}
func wsMeta(_ ctx: NWConnection.ContentContext?) -> NWProtocolWebSocket.Metadata? {
    ctx?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
}

// MARK: - WebSocket client against ws_server.py

func nwWebSocketClientChecks(port: String) {
    let params = NWParameters.tcp
    let ws = NWProtocolWebSocket.Options()
    ws.autoReplyPing = true
    ws.setSubprotocols(["v9.unknown", "chat"])
    ws.setAdditionalHeaders([(name: "X-Isim", value: "nw")])
    params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
    let c = NWConnection(to: .url(URL(string: "ws://127.0.0.1:\(port)/ws?client=nw")!), using: params)
    guard waitReady(c, "nw-ws") else { check(false, "NWProtocolWebSocket: a client connection to ws_server.py is ready"); return }
    let meta = c.metadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
    check(meta?.serverResponse?.subprotocol == "chat", "NWProtocolWebSocket: the server's chosen subprotocol (\(meta?.serverResponse?.subprotocol ?? "nil"))")
    _ = sendMessage(c, Data("hello nw".utf8), wsContext(.text))
    var r = receiveMessage(c)
    check(r.0.map { String(decoding: $0, as: UTF8.self) } == "echo: hello nw" && wsMeta(r.1)?.opcode == .text, "NWProtocolWebSocket: a text message and its echo")
    _ = sendMessage(c, Data("headers?".utf8), wsContext(.text))
    r = receiveMessage(c)
    let h = r.0.map { String(decoding: $0, as: UTF8.self) }
    check(h == "x-isim=nw proto=chat query=client=nw", "NWProtocolWebSocket: additional headers, subprotocols and the URL's query reach the server (\(h ?? "nil"))")
    _ = sendMessage(c, Data([1, 2, 3, 255]), wsContext(.binary))
    r = receiveMessage(c)
    check(r.0 == Data([1, 2, 3, 255]) && wsMeta(r.1)?.opcode == .binary, "NWProtocolWebSocket: a binary message")
    _ = sendMessage(c, Data("fragment".utf8), wsContext(.text))
    r = receiveMessage(c)
    check(r.0.map { String(decoding: $0, as: UTF8.self) } == "frag-1 frag-2 frag-3", "NWProtocolWebSocket: fragments are joined, the server's pings answered (autoReplyPing)")
    _ = sendMessage(c, Data("pongs?".utf8), wsContext(.text))
    r = receiveMessage(c)
    check(r.0.map { String(decoding: $0, as: UTF8.self) } == "pongs: 2", "NWProtocolWebSocket: autoReplyPing sends pongs with the ping's payload")
    // the pong is read while the connection receives (as an app's receive loop does)
    let pong = DispatchSemaphore(value: 0)
    _ = sendMessage(c, Data("p".utf8), wsContext(.ping) { $0.setPongHandler(DispatchQueue(label: "pong")) { _ in pong.signal() } })
    _ = sendMessage(c, Data("big".utf8), wsContext(.text))
    r = receiveMessage(c)
    check(r.0?.count == 70000, "NWProtocolWebSocket: a 70000-byte message (64-bit length)")
    check(pong.wait(timeout: .now() + 5) == .success, "NWProtocolWebSocket: a ping's pong handler runs")
    _ = sendMessage(c, Data("close".utf8), wsContext(.text))
    r = receiveMessage(c)
    check(wsMeta(r.1)?.opcode == .close && wsMeta(r.1)?.closeCode == .privateCode(4001) && r.0 == Data("bye".utf8),
          "NWProtocolWebSocket: the server's close frame arrives with its code and reason (\(String(describing: wsMeta(r.1)?.closeCode)))")
    c.cancel()
}

// MARK: - WebSocket server (NWListener) and client in this process

func nwWebSocketServerChecks() {
    let sp = NWParameters.tcp
    let sws = NWProtocolWebSocket.Options()
    sws.setClientRequestHandler(DispatchQueue(label: "ws-req")) { req in
        let chosen = req.subprotocols?.first { $0 == "isim.v2" }
        return NWProtocolWebSocket.Response(status: chosen == nil ? .reject : .accept, subprotocol: chosen, additionalHeaders: [(name: "X-Server", value: "isim")])
    }
    sp.defaultProtocolStack.applicationProtocols.insert(sws, at: 0)
    guard let listener = try? NWListener(using: sp, on: .any) else { check(false, "NWListener with NWProtocolWebSocket"); return }
    let ready = DispatchSemaphore(value: 0)
    listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
    listener.newConnectionHandler = { conn in
        conn.start(queue: DispatchQueue(label: "ws-server-conn"))
        @Sendable func loop() {
            conn.receiveMessage { d, ctx, _, e in
                guard e == nil, let meta = wsMeta(ctx) else { return }
                switch meta.opcode {
                case .text: conn.send(content: Data(("server: " + String(decoding: d ?? Data(), as: UTF8.self)).utf8), contentContext: wsContext(.text), completion: .idempotent)
                case .binary: conn.send(content: Data((d ?? Data()).reversed()), contentContext: wsContext(.binary), completion: .idempotent)
                case .close: return
                default: break
                }
                loop()
            }
        }
        loop()
    }
    listener.start(queue: DispatchQueue(label: "ws-listener"))
    guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port else { check(false, "NWListener (WebSocket) is ready"); return }

    func client(_ proto: String) -> NWConnection {
        let p = NWParameters.tcp
        let o = NWProtocolWebSocket.Options()
        o.setSubprotocols([proto])
        p.defaultProtocolStack.applicationProtocols.insert(o, at: 0)
        return NWConnection(to: .url(URL(string: "ws://127.0.0.1:\(port.rawValue)/chat")!), using: p)
    }
    let c = client("isim.v2")
    check(waitReady(c, "ws-client"), "NWListener WebSocket server: the opening handshake (Sec-WebSocket-Accept) completes")
    let meta = c.metadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
    check(meta?.serverResponse?.subprotocol == "isim.v2", "NWListener WebSocket server: setClientRequestHandler chooses the subprotocol")
    _ = sendMessage(c, Data("hi".utf8), wsContext(.text))
    var r = receiveMessage(c)
    check(r.0.map { String(decoding: $0, as: UTF8.self) } == "server: hi", "NWListener WebSocket server: unmasks the client's text and answers")
    _ = sendMessage(c, Data([1, 2, 3]), wsContext(.binary))
    r = receiveMessage(c)
    check(r.0 == Data([3, 2, 1]), "NWListener WebSocket server: binary messages both ways")
    _ = sendMessage(c, nil, wsContext(.close) { $0.closeCode = .applicationCode(3001) })
    r = receiveMessage(c)
    check(wsMeta(r.1)?.opcode == .close && wsMeta(r.1)?.closeCode == .applicationCode(3001), "NWListener WebSocket server: the close handshake echoes the code")
    c.cancel()

    let rejected = client("other")
    check(!waitReady(rejected, "ws-rejected"), "NWListener WebSocket server: a rejected request fails the client's connection")
    rejected.cancel()
    listener.cancel()
}

// MARK: - framer: a type-length-value protocol with a hello handshake

final class TLVFramer: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: TLVFramer.self)
    static var label: String { "TLV" }
    var sentHello = false
    init(framer: NWProtocolFramer.Instance) {}
    /// both ends say "TLV1" and wait for the other's before the connection is ready
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        framer.writeOutput(data: Data("TLV1".utf8))
        return .willMarkReady
    }
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            if !sentHello {
                var hello: Data?
                guard framer.parseInput(minimumIncompleteLength: 4, maximumLength: 4, parse: { b, _ in
                    guard let b else { return 0 }
                    hello = Data(b); return 4
                }) else { return 4 }
                guard hello == Data("TLV1".utf8) else { framer.markFailed(error: .posix(.EPROTO)); return 0 }
                sentHello = true
                framer.markReady()
                continue
            }
            var type: UInt8 = 0, length = 0
            guard framer.parseInput(minimumIncompleteLength: 5, maximumLength: 5, parse: { b, _ in
                guard let b, b.count >= 5 else { return 0 }
                type = b[0]; length = Int(b[1]) << 24 | Int(b[2]) << 16 | Int(b[3]) << 8 | Int(b[4])
                return 5
            }) else { return 5 }
            let m = NWProtocolFramer.Message(definition: TLVFramer.definition)
            m["type"] = type
            if !framer.deliverInputNoCopy(length: length, message: m, isComplete: true) { return 0 }
        }
    }
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        let type = message["type"] as? UInt8 ?? 0
        let n = UInt32(messageLength)
        framer.writeOutput(data: Data([type, UInt8(n >> 24), UInt8((n >> 16) & 0xff), UInt8((n >> 8) & 0xff), UInt8(n & 0xff)]))
        try? framer.writeOutputNoCopy(length: messageLength)
    }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}
}

func tlvContext(_ type: UInt8) -> NWConnection.ContentContext {
    let m = NWProtocolFramer.Message(definition: TLVFramer.definition)
    m["type"] = type
    return NWConnection.ContentContext(identifier: "tlv", metadata: [m])
}

func nwFramerChecks() {
    func params() -> NWParameters {
        let p = NWParameters.tcp
        p.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: TLVFramer.definition), at: 0)
        return p
    }
    guard let listener = try? NWListener(using: params(), on: .any) else { check(false, "NWListener with NWProtocolFramer"); return }
    let ready = DispatchSemaphore(value: 0)
    listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
    listener.newConnectionHandler = { conn in
        conn.start(queue: DispatchQueue(label: "tlv-server-conn"))
        @Sendable func loop() {
            conn.receiveMessage { d, ctx, _, e in
                guard e == nil, let d else { return }
                let type = (ctx?.protocolMetadata(definition: TLVFramer.definition) as? NWProtocolFramer.Message)?["type"] as? UInt8 ?? 0
                // answer with type + 100 and the payload upper-cased
                conn.send(content: Data(String(decoding: d, as: UTF8.self).uppercased().utf8), contentContext: tlvContext(type + 100), completion: .idempotent)
                loop()
            }
        }
        loop()
    }
    listener.start(queue: DispatchQueue(label: "tlv-listener"))
    guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port else { check(false, "NWListener (framer) is ready"); return }
    let c = NWConnection(host: "127.0.0.1", port: port, using: params())
    check(waitReady(c, "tlv-client"), "NWProtocolFramer: start(.willMarkReady) and a handshake in handleInput, then markReady")
    for (type, text) in [(UInt8(1), "first"), (UInt8(7), "second message"), (UInt8(9), "")] {
        _ = sendMessage(c, Data(text.utf8), tlvContext(type))
        let r = receiveMessage(c)
        let back = (r.1?.protocolMetadata(definition: TLVFramer.definition) as? NWProtocolFramer.Message)?["type"] as? UInt8
        check(r.2 == nil && (r.0.map { String(decoding: $0, as: UTF8.self) } ?? "") == text.uppercased() && back == type + 100,
              "NWProtocolFramer: message \(type) framed by handleOutput, parsed by handleInput with its metadata (\(back.map(String.init) ?? "nil"))")
    }
    c.cancel()
    listener.cancel()
}

// MARK: - multicast group

func nwConnectionGroupChecks() {
    let port = NWEndpoint.Port(rawValue: UInt16(40000 + getpid() % 20000))!
    guard let group = try? NWMulticastGroup(for: [.hostPort(host: "239.255.43.21", port: port)]) else {
        check(false, "NWMulticastGroup(for:) with a multicast address"); return
    }
    check((try? NWMulticastGroup(for: [.hostPort(host: "10.0.0.1", port: port)])) == nil, "NWMulticastGroup rejects a unicast address")
    let a = NWConnectionGroup(with: group, using: .udp), b = NWConnectionGroup(with: group, using: .udp)
    let got = DispatchSemaphore(value: 0), replied = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var heard = "", answer = ""
    b.setReceiveHandler { message, content, _ in
        let s = String(decoding: content ?? Data(), as: UTF8.self)
        guard s.hasPrefix("hello") else { return }
        heard = s; got.signal()
        message.reply(content: Data("hi back".utf8))
    }
    a.setReceiveHandler { _, content, _ in
        let s = String(decoding: content ?? Data(), as: UTF8.self)
        if s == "hi back" { answer = s; replied.signal() }
    }
    let readyA = DispatchSemaphore(value: 0), readyB = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var failed: NWError?
    a.stateUpdateHandler = { s in if case .ready = s { readyA.signal() }; if case .failed(let e) = s { failed = e; readyA.signal() } }
    b.stateUpdateHandler = { s in if case .ready = s { readyB.signal() }; if case .failed(let e) = s { failed = e; readyB.signal() } }
    a.start(queue: DispatchQueue(label: "group-a")); b.start(queue: DispatchQueue(label: "group-b"))
    _ = readyA.wait(timeout: .now() + 5); _ = readyB.wait(timeout: .now() + 5)
    guard failed == nil else { check(false, "NWConnectionGroup joins 239.255.43.21 (\(failed!))"); return }
    a.send(content: Data("hello group".utf8)) { _ in }
    check(got.wait(timeout: .now() + 5) == .success && heard == "hello group", "NWConnectionGroup: a member hears the group's multicast (\(heard))")
    // a sender outside the group (its own port: members in one process share the group port): the reply comes back to it
    let s = socket(AF_INET, SOCK_DGRAM, 0)
    var to = sockaddr_in(); to.sin_family = sa_family_t(AF_INET); to.sin_port = port.rawValue.bigEndian
    to.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    _ = inet_pton(AF_INET, "239.255.43.21", &to.sin_addr)
    var tv = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    let hello = Array("hello from outside".utf8)
    _ = withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(s, hello, hello.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    var buf = [UInt8](repeating: 0, count: 64)
    let n = recv(s, &buf, buf.count, 0)
    close(s)
    answer = n > 0 ? String(decoding: buf[0..<n], as: UTF8.self) : "nothing (\(errno))"
    check(answer == "hi back", "NWConnectionGroup: Message.reply answers the sender by unicast (\(answer))")
    _ = replied
    a.cancel(); b.cancel()
    check(a.state == .cancelled, "NWConnectionGroup.cancel")
}

// MARK: - TLS and DTLS listeners (server identities), client certificates, the peer's chain in sec_trust_t

func nwTLSChecks(server: SecIdentity, client: SecIdentity, serverDER: Data) {
    // the server: its identity, ALPN, client certificates required (its verify block sees the client's chain)
    nonisolated(unsafe) var clientSubject = ""
    func serverOptions() -> NWProtocolTLS.Options {
        let o = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(o.securityProtocolOptions, sec_identity_create(server)!)
        sec_protocol_options_add_tls_application_protocol(o.securityProtocolOptions, "isim/1")
        sec_protocol_options_set_peer_authentication_required(o.securityProtocolOptions, true)
        sec_protocol_options_set_verify_block(o.securityProtocolOptions, { meta, _, done in
            sec_protocol_metadata_access_peer_certificate_chain(meta) { c in
                if clientSubject.isEmpty { clientSubject = (SecCertificateCopySubjectSummary(sec_certificate_copy_ref(c).takeRetainedValue()) as String?) ?? "" }
            }
            done(clientSubject == "isim-client")
        }, DispatchQueue(label: "server-verify"))
        return o
    }
    // the client: pins the server's certificate from the trust object, presents its own identity
    nonisolated(unsafe) var pinned = false
    func clientOptions() -> NWProtocolTLS.Options {
        let o = NWProtocolTLS.Options()
        sec_protocol_options_add_tls_application_protocol(o.securityProtocolOptions, "isim/1")
        sec_protocol_options_set_local_identity(o.securityProtocolOptions, sec_identity_create(client)!)
        sec_protocol_options_set_verify_block(o.securityProtocolOptions, { _, trust, done in
            let t = sec_trust_copy_ref(trust).takeRetainedValue()
            let leaf = (SecTrustCopyCertificateChain(t) as? [SecCertificate])?.first
            pinned = leaf.map { SecCertificateCopyData($0) as Data } == serverDER
            done(pinned)
        }, DispatchQueue(label: "client-verify"))
        return o
    }
    func echoListener(_ params: NWParameters, _ what: String) -> NWListener? {
        guard let l = try? NWListener(using: params, on: .any) else { check(false, "\(what): NWListener with a server identity"); return nil }
        let ready = DispatchSemaphore(value: 0)
        l.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        l.newConnectionHandler = { conn in
            conn.start(queue: DispatchQueue(label: "\(what)-conn"))
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { d, _, _, _ in
                guard let d else { return }
                conn.send(content: Data("echo ".utf8) + d, completion: .idempotent)
            }
        }
        l.start(queue: DispatchQueue(label: what))
        _ = ready.wait(timeout: .now() + 5)
        return l
    }

    // TLS over TCP
    if let l = echoListener(NWParameters(tls: serverOptions()), "tls"), let port = l.port {
        let c = NWConnection(host: "localhost", port: port, using: NWParameters(tls: clientOptions()))
        check(waitReady(c, "tls-client"), "TLS listener: a server identity (sec_identity_create) and the handshake")
        check(pinned, "TLS: the client's verify block pins the server's certificate from sec_trust_copy_ref")
        let meta = c.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
        let alpn = meta.flatMap { sec_protocol_metadata_get_negotiated_protocol($0.securityProtocolMetadata) }.map { String(cString: $0) }
        check(alpn == "isim/1", "TLS: ALPN chosen by the server (\(alpn ?? "nil"))")
        c.send(content: Data("over tls".utf8), completion: .idempotent)
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var got = ""
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { d, _, _, _ in got = d.map { String(decoding: $0, as: UTF8.self) } ?? ""; sem.signal() }
        _ = sem.wait(timeout: .now() + 5)
        check(got == "echo over tls", "TLS listener: data both ways (\(got))")
        // (TLS 1.3: the server checks the client's certificate after the client's side of the handshake is done)
        check(clientSubject == "isim-client", "TLS listener: a required client certificate, seen by the server's verify block (\(clientSubject))")
        c.cancel()
        // a client without a certificate is refused when the server requires one
        let anon = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(anon.securityProtocolOptions, { _, _, done in done(true) }, DispatchQueue(label: "anon"))
        let c2 = NWConnection(host: "localhost", port: port, using: NWParameters(tls: anon))
        let anonOK = waitReady(c2, "tls-anon")
        nonisolated(unsafe) var refused = !anonOK
        if anonOK {   /* TLS 1.3: the server's refusal arrives after the client's handshake ends */
            let s2 = DispatchSemaphore(value: 0)
            c2.send(content: Data("x".utf8), completion: .idempotent)
            c2.receive(minimumIncompleteLength: 1, maximumLength: 10) { d, _, done, e in refused = d == nil && (done || e != nil); s2.signal() }
            _ = s2.wait(timeout: .now() + 5)
        }
        check(refused, "TLS listener: a client without the required certificate is refused")
        c2.cancel()
        l.cancel()
    }

    // DTLS over UDP
    let dtlsServer = NWProtocolTLS.Options()
    sec_protocol_options_set_local_identity(dtlsServer.securityProtocolOptions, sec_identity_create(server)!)
    if let l = echoListener(NWParameters(dtls: dtlsServer), "dtls"), let port = l.port {
        let o = NWProtocolTLS.Options()
        nonisolated(unsafe) var dtlsPinned = false
        sec_protocol_options_set_verify_block(o.securityProtocolOptions, { _, trust, done in
            let t = sec_trust_copy_ref(trust).takeRetainedValue()
            dtlsPinned = (SecTrustCopyCertificateChain(t) as? [SecCertificate])?.first.map { SecCertificateCopyData($0) as Data } == serverDER
            done(dtlsPinned)
        }, DispatchQueue(label: "dtls-verify"))
        let c = NWConnection(host: "127.0.0.1", port: port, using: NWParameters(dtls: o))
        check(waitReady(c, "dtls-client") && dtlsPinned, "DTLS: a handshake with the listener's identity over UDP, the server's certificate in sec_trust_t")
        let meta = c.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
        let version = meta.map { sec_protocol_metadata_get_negotiated_tls_protocol_version($0.securityProtocolMetadata) }
        c.send(content: Data("over dtls".utf8), completion: .idempotent)
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var got = ""
        c.receiveMessage { d, _, _, _ in got = d.map { String(decoding: $0, as: UTF8.self) } ?? ""; sem.signal() }
        _ = sem.wait(timeout: .now() + 10)
        check(got == "echo over dtls" && version == .DTLSv12, "DTLS: datagrams both ways (\(got)), DTLS 1.2 negotiated (\(String(describing: version)))")
        c.cancel()
        l.cancel()
    }
}

/// QUIC is declared for apps to build against; isim has none, so a QUIC connection fails with ENOTSUP
func nwQUICChecks() {
    let c = NWConnection(host: "127.0.0.1", port: 443, using: NWParameters(quic: NWProtocolQUIC.Options(alpn: ["h3"])))
    let sem = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var err: NWError?
    c.stateUpdateHandler = { if case .failed(let e) = $0 { err = e; sem.signal() } }
    c.start(queue: DispatchQueue(label: "quic"))
    _ = sem.wait(timeout: .now() + 5)
    check(err == .posix(.ENOTSUP), "NWProtocolQUIC: not available, a QUIC connection fails with ENOTSUP (\(String(describing: err)))")
    c.cancel()
}
