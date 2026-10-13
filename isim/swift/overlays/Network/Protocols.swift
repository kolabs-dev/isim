// isim Network framework: message protocols on top of a connection's TCP (or TLS) byte stream —
// NWProtocolWebSocket (RFC 6455, client and server: handshake, masking, fragmentation, ping/pong, close codes,
// sub-protocols) and NWProtocolFramer (an app's own framing: the NWProtocolFramerImplementation callbacks run on the
// connection's queues, as on iOS). Adapted: one message protocol per connection (the top of the
// application-protocol stack); a framer's partial deliveries are joined into whole messages.
@_exported import Foundation

// MARK: - the message layer of a connection

/// a protocol between the app and the byte stream: started once the transport is up, then it frames sends and receives
protocol _NWMessageLayer: AnyObject {
    var definition: NWProtocolDefinition { get }
    /// runs before the connection is ready (handshakes); an error fails the connection
    func start(_ c: NWConnection) -> NWError?
    func send(_ c: NWConnection, _ content: Data?, _ context: NWConnection.ContentContext, _ isComplete: Bool) -> NWError?
    /// one whole message (blocking, on the connection's read queue)
    func receive(_ c: NWConnection) -> (Data?, NWConnection.ContentContext?, Bool, NWError?)
    func metadata() -> NWProtocolMetadata?
    func stop(_ c: NWConnection)
}

extension NWConnection {
    /// the message protocol the parameters ask for, if any (WebSocket or a framer)
    static func _messageLayer(_ p: NWParameters, server: Bool) -> _NWMessageLayer? {
        for o in p.defaultProtocolStack.applicationProtocols {
            if let ws = o as? NWProtocolWebSocket.Options { return _NWWebSocketLayer(ws, server: server) }
            if let f = o as? NWProtocolFramer.Options { return _NWFramerLayer(f) }
        }
        return nil
    }
}

/// bytes read from the transport and not yet consumed by the message layer
final class _NWByteReader {
    var buffer = Data()
    var eof = false
    var error: NWError?
    /// reads more from the transport (blocking); false at end of stream or on an error
    func fill(_ c: NWConnection) -> Bool {
        guard !eof, error == nil else { return false }
        let r = c._transportRead(max: 65536)
        if let d = r.0, !d.isEmpty { buffer.append(d); return true }
        if let e = r.2 { error = e } else { eof = true }
        return false
    }
    /// exactly n bytes, or nil if the stream ends first
    func take(_ n: Int, _ c: NWConnection) -> Data? {
        while buffer.count < n { if !fill(c) { return nil } }
        let d = buffer.prefix(n)
        buffer.removeFirst(n)
        return Data(d)
    }
    /// up to and including a terminator (HTTP headers)
    func takeThrough(_ terminator: Data, limit: Int, _ c: NWConnection) -> Data? {
        while true {
            let b = [UInt8](buffer), t = [UInt8](terminator)
            if b.count >= t.count, let i = (0...(b.count - t.count)).first(where: { b[$0..<$0 + t.count].elementsEqual(t) }) {
                let d = Data(b[0..<i + t.count])
                buffer = Data(b[(i + t.count)...])
                return d
            }
            if buffer.count > limit || !fill(c) { return nil }
        }
    }
    var failure: NWError { error ?? .posix(.ECONNRESET) }
}

// MARK: - WebSocket

public enum NWProtocolWebSocket {
    public static let definition = NWProtocolDefinition("websocket")

    public enum Opcode: Int, Sendable {
        case cont = 0x0, text = 0x1, binary = 0x2, close = 0x8, ping = 0x9, pong = 0xA
    }
    public enum CloseCode: Equatable, Hashable, Sendable {
        public enum Defined: UInt16, Sendable {
            case normalClosure = 1000, goingAway = 1001, protocolError = 1002, unsupportedData = 1003, noStatusReceived = 1005
            case abnormalClosure = 1006, invalidFramePayloadData = 1007, policyViolation = 1008, messageTooBig = 1009
            case mandatoryExtension = 1010, internalServerError = 1011, tlsHandshake = 1015
        }
        case protocolCode(Defined)
        case applicationCode(UInt16)
        case privateCode(UInt16)
        public init?(rawValue: UInt16) {
            if let d = Defined(rawValue: rawValue) { self = .protocolCode(d) }
            else if (3000...3999).contains(rawValue) { self = .applicationCode(rawValue) }
            else if (4000...4999).contains(rawValue) { self = .privateCode(rawValue) }
            else { return nil }
        }
        public var rawValue: UInt16 {
            switch self { case .protocolCode(let d): return d.rawValue; case .applicationCode(let c), .privateCode(let c): return c }
        }
    }
    public enum Version: Sendable { case version13 }

    /// what a client asked for in its opening handshake (server side)
    public struct Request: Sendable {
        public let subprotocols: [String]?
        public let additionalHeaders: [(name: String, value: String)]?
    }
    /// a server's answer to the opening handshake
    public struct Response: Sendable {
        public enum Status: Sendable { case accept, reject }
        public var status: Status
        public var subprotocol: String?
        public var additionalHeaders: [(name: String, value: String)]?
        public init(status: Status, subprotocol: String?, additionalHeaders: [(name: String, value: String)]?) {
            self.status = status; self.subprotocol = subprotocol; self.additionalHeaders = additionalHeaders
        }
    }

    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public let version: Version
        public var autoReplyPing = false
        public var maximumMessageSize = 0                 /* 0: no limit */
        public var skipHandshake = false
        var headers: [(name: String, value: String)] = []
        var subprotocols: [String] = []
        var requestHandler: (queue: DispatchQueue, handler: (Request) -> Response)?
        public init(_ version: Version = .version13) { self.version = version; super.init() }
        public func setAdditionalHeaders(_ additionalHeaders: [(name: String, value: String)]) { headers = additionalHeaders }
        public func setSubprotocols(_ subprotocols: [String]) { self.subprotocols = subprotocols }
        public func setClientRequestHandler(_ queue: DispatchQueue, handler: @escaping (Request) -> Response) { requestHandler = (queue, handler) }
    }

    public final class Metadata: NWProtocolMetadata, @unchecked Sendable {
        public let opcode: Opcode
        public var closeCode: CloseCode = .protocolCode(.normalClosure)
        public var additionalServerHeaders: [(name: String, value: String)]?
        public internal(set) var serverResponse: Response?
        var pongHandler: (queue: DispatchQueue, handler: (NWError?) -> Void)?
        public init(opcode: Opcode) { self.opcode = opcode; super.init(); _definition = NWProtocolWebSocket.definition }
        public func setPongHandler(_ queue: DispatchQueue, handler: @escaping (NWError?) -> Void) { pongHandler = (queue, handler) }
    }
}

final class _NWWebSocketLayer: _NWMessageLayer {
    let options: NWProtocolWebSocket.Options
    let server: Bool
    let reader = _NWByteReader()
    let sendLock = NSLock()
    var fragmentOpcode: NWProtocolWebSocket.Opcode?          /* a message being sent in pieces */
    var pongHandlers: [(queue: DispatchQueue, handler: (NWError?) -> Void)] = []
    var closeSent = false, closeReceived = false
    var response: NWProtocolWebSocket.Response?
    var definition: NWProtocolDefinition { NWProtocolWebSocket.definition }
    init(_ o: NWProtocolWebSocket.Options, server: Bool) { options = o; self.server = server }

    static let guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    static func accept(_ key: String) -> String { Data(_NWSHA1.hash(Data((key + guid).utf8))).base64EncodedString() }

    func start(_ c: NWConnection) -> NWError? {
        if options.skipHandshake { return nil }
        return server ? serverHandshake(c) : clientHandshake(c)
    }

    func headerLines(_ d: Data) -> (String, [(String, String)]) {
        let lines = String(decoding: d, as: UTF8.self).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        let fields: [(String, String)] = lines.dropFirst().compactMap { l in
            guard let i = l.firstIndex(of: ":") else { return nil }
            return (String(l[..<i]).trimmingCharacters(in: .whitespaces), String(l[l.index(after: i)...]).trimmingCharacters(in: .whitespaces))
        }
        return (lines.first ?? "", fields)
    }

    func clientHandshake(_ c: NWConnection) -> NWError? {
        var path = "/", host = "localhost"
        switch c.endpoint {
        case .url(let u):
            path = u.path.isEmpty ? "/" : u.path
            if let q = u.query { path += "?" + q }
            host = u.host ?? host
            if let p = u.port { host += ":\(p)" }
        case .hostPort(let h, let p): host = "\(h):\(p)"
        default: break
        }
        var key = [UInt8](repeating: 0, count: 16)
        var rng = SystemRandomNumberGenerator()
        for i in key.indices { key[i] = rng.next() }
        let k = Data(key).base64EncodedString()
        var req = "GET \(path) HTTP/1.1\r\nHost: \(host)\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: \(k)\r\nSec-WebSocket-Version: 13\r\n"
        if !options.subprotocols.isEmpty { req += "Sec-WebSocket-Protocol: \(options.subprotocols.joined(separator: ", "))\r\n" }
        for h in options.headers { req += "\(h.name): \(h.value)\r\n" }
        req += "\r\n"
        if let e = c._transportWrite(Data(req.utf8)) { return e }
        guard let head = reader.takeThrough(Data("\r\n\r\n".utf8), limit: 65536, c) else { return reader.failure }
        let (status, fields) = headerLines(head)
        func field(_ n: String) -> String? { fields.first { $0.0.lowercased() == n.lowercased() }?.1 }
        guard status.split(separator: " ").dropFirst().first == "101" else {
            print("isim: NWConnection WebSocket: the server answered \"\(status)\"")
            return .posix(.ECONNREFUSED)
        }
        guard field("Sec-WebSocket-Accept") == Self.accept(k) else { return .posix(.EPROTO) }
        response = NWProtocolWebSocket.Response(status: .accept, subprotocol: field("Sec-WebSocket-Protocol"),
                                                additionalHeaders: fields.map { (name: $0.0, value: $0.1) })
        return nil
    }

    func serverHandshake(_ c: NWConnection) -> NWError? {
        guard let head = reader.takeThrough(Data("\r\n\r\n".utf8), limit: 65536, c) else { return reader.failure }
        let (_, fields) = headerLines(head)
        func field(_ n: String) -> String? { fields.first { $0.0.lowercased() == n.lowercased() }?.1 }
        guard let key = field("Sec-WebSocket-Key"), field("Upgrade")?.lowercased() == "websocket" else {
            _ = c._transportWrite(Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n".utf8))
            return .posix(.EPROTO)
        }
        let offered = field("Sec-WebSocket-Protocol").map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let request = NWProtocolWebSocket.Request(subprotocols: offered, additionalHeaders: fields.map { (name: $0.0, value: $0.1) })
        var answer = NWProtocolWebSocket.Response(status: .accept, subprotocol: offered?.first { options.subprotocols.contains($0) }, additionalHeaders: nil)
        if let h = options.requestHandler { answer = h.queue.sync { h.handler(request) } }
        guard answer.status == .accept else {
            _ = c._transportWrite(Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n".utf8))
            return .posix(.ECONNREFUSED)
        }
        var resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(Self.accept(key))\r\n"
        if let p = answer.subprotocol { resp += "Sec-WebSocket-Protocol: \(p)\r\n" }
        for h in (answer.additionalHeaders ?? []) + options.headers { resp += "\(h.name): \(h.value)\r\n" }
        resp += "\r\n"
        response = answer
        return c._transportWrite(Data(resp.utf8))
    }

    /// one frame on the wire (clients mask, servers do not)
    func frame(_ op: NWProtocolWebSocket.Opcode, _ payload: Data, fin: Bool) -> Data {
        var out = Data([(fin ? 0x80 : 0) | UInt8(op.rawValue)])
        let mask: UInt8 = server ? 0 : 0x80
        let n = payload.count
        if n < 126 { out.append(mask | UInt8(n)) }
        else if n < 65536 { out.append(mask | 126); out.append(UInt8(n >> 8)); out.append(UInt8(n & 0xff)) }
        else { out.append(mask | 127); for s in stride(from: 56, through: 0, by: -8) { out.append(UInt8((UInt64(n) >> UInt64(s)) & 0xff)) } }
        if server { out.append(payload); return out }
        var key = [UInt8](repeating: 0, count: 4)
        var rng = SystemRandomNumberGenerator()
        for i in 0..<4 { key[i] = rng.next() }
        out.append(contentsOf: key)
        var p = [UInt8](payload)
        for i in p.indices { p[i] ^= key[i & 3] }
        out.append(contentsOf: p)
        return out
    }

    func send(_ c: NWConnection, _ content: Data?, _ context: NWConnection.ContentContext, _ isComplete: Bool) -> NWError? {
        let meta = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
        let op = meta?.opcode ?? .binary
        let payload = content ?? Data()
        sendLock.lock(); defer { sendLock.unlock() }
        switch op {
        case .close:
            if closeSent { return nil }
            closeSent = true
            var code = Data([UInt8((meta?.closeCode.rawValue ?? 1000) >> 8), UInt8((meta?.closeCode.rawValue ?? 1000) & 0xff)])
            code.append(payload)
            return c._transportWrite(frame(.close, code, fin: true))
        case .ping, .pong:
            if op == .ping, let h = meta?.pongHandler { pongHandlers.append(h) }
            return c._transportWrite(frame(op, payload.prefix(125), fin: true))
        default:
            if options.maximumMessageSize > 0 && payload.count > options.maximumMessageSize { return .posix(.EMSGSIZE) }
            let wireOp: NWProtocolWebSocket.Opcode = fragmentOpcode == nil ? (op == .cont ? .binary : op) : .cont
            if fragmentOpcode == nil && !isComplete { fragmentOpcode = wireOp }
            if isComplete { fragmentOpcode = nil }
            if payload.isEmpty && content == nil && !isComplete { return nil }
            return c._transportWrite(frame(wireOp, payload, fin: isComplete))
        }
    }

    func receive(_ c: NWConnection) -> (Data?, NWConnection.ContentContext?, Bool, NWError?) {
        var message = Data()
        var messageOp: NWProtocolWebSocket.Opcode?
        while true {
            guard let h = reader.take(2, c) else {
                return (nil, nil, closeReceived, closeReceived ? nil : reader.failure)
            }
            let fin = h[h.startIndex] & 0x80 != 0
            guard let op = NWProtocolWebSocket.Opcode(rawValue: Int(h[h.startIndex] & 0x0f)) else { return (nil, nil, false, .posix(.EPROTO)) }
            let masked = h[h.startIndex + 1] & 0x80 != 0
            var len = UInt64(h[h.startIndex + 1] & 0x7f)
            if len == 126 { guard let e = reader.take(2, c) else { return (nil, nil, false, reader.failure) }; len = UInt64(e[e.startIndex]) << 8 | UInt64(e[e.startIndex + 1]) }
            else if len == 127 { guard let e = reader.take(8, c) else { return (nil, nil, false, reader.failure) }; len = e.reduce(0) { $0 << 8 | UInt64($1) } }
            let key = masked ? reader.take(4, c).map { [UInt8]($0) } : nil
            if options.maximumMessageSize > 0 && Int(len) + message.count > options.maximumMessageSize { return (nil, nil, false, .posix(.EMSGSIZE)) }
            guard var payload = reader.take(Int(len), c).map({ [UInt8]($0) }) else { return (nil, nil, false, reader.failure) }
            if let key { for i in payload.indices { payload[i] ^= key[i & 3] } }
            let data = Data(payload)
            switch op {
            case .ping:
                if options.autoReplyPing { sendLock.lock(); _ = c._transportWrite(frame(.pong, data, fin: true)); sendLock.unlock(); continue }
                return (data, context(.ping), true, nil)
            case .pong:
                sendLock.lock(); let h = pongHandlers.isEmpty ? nil : pongHandlers.removeFirst(); sendLock.unlock()
                if let h { h.queue.async { h.handler(nil) }; continue }
                return (data, context(.pong), true, nil)
            case .close:
                closeReceived = true
                let code = data.count >= 2 ? UInt16(data[data.startIndex]) << 8 | UInt16(data[data.startIndex + 1]) : 1005
                sendLock.lock()
                if !closeSent { closeSent = true; _ = c._transportWrite(frame(.close, data.prefix(2), fin: true)) }
                sendLock.unlock()
                let ctx = context(.close)
                (ctx.protocolMetadata.first as? NWProtocolWebSocket.Metadata)?.closeCode = NWProtocolWebSocket.CloseCode(rawValue: code) ?? .protocolCode(.noStatusReceived)
                return (data.count > 2 ? data.dropFirst(2) : nil, ctx, true, nil)
            case .text, .binary:
                messageOp = op; message = data
            case .cont:
                message.append(data)
            }
            if fin { return (message, context(messageOp ?? .binary), true, nil) }
        }
    }

    func context(_ op: NWProtocolWebSocket.Opcode) -> NWConnection.ContentContext {
        NWConnection.ContentContext(identifier: "websocket", metadata: [NWProtocolWebSocket.Metadata(opcode: op)])
    }
    func metadata() -> NWProtocolMetadata? {
        let m = NWProtocolWebSocket.Metadata(opcode: .cont)
        m.serverResponse = response
        return m
    }
    func stop(_ c: NWConnection) {
        sendLock.lock(); defer { sendLock.unlock() }
        if !closeSent && !closeReceived { closeSent = true; _ = c._transportWrite(frame(.close, Data([0x03, 0xe8]), fin: true)) }
    }
}

/// SHA-1 (RFC 3174), for the WebSocket accept key
enum _NWSHA1 {
    static func hash(_ data: Data) -> [UInt8] {
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
        var m = [UInt8](data)
        let bitLen = UInt64(m.count) * 8
        m.append(0x80)
        while m.count % 64 != 56 { m.append(0) }
        for s in stride(from: 56, through: 0, by: -8) { m.append(UInt8((bitLen >> UInt64(s)) & 0xff)) }
        func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 { (x << n) | (x >> (32 - n)) }
        var w = [UInt32](repeating: 0, count: 80)
        for chunk in stride(from: 0, to: m.count, by: 64) {
            for i in 0..<16 {
                let b = chunk + i * 4
                w[i] = UInt32(m[b]) << 24 | UInt32(m[b + 1]) << 16 | UInt32(m[b + 2]) << 8 | UInt32(m[b + 3])
            }
            for i in 16..<80 { w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1) }
            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4]
            for i in 0..<80 {
                let (f, k): (UInt32, UInt32) = i < 20 ? ((b & c) | (~b & d), 0x5A827999) : i < 40 ? (b ^ c ^ d, 0x6ED9EBA1)
                    : i < 60 ? ((b & c) | (b & d) | (c & d), 0x8F1BBCDC) : (b ^ c ^ d, 0xCA62C1D6)
                let t = rotl(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d; d = c; c = rotl(b, 30); b = a; a = t
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d; h[4] = h[4] &+ e
        }
        return h.flatMap { v in (0..<4).map { UInt8((v >> UInt32(24 - $0 * 8)) & 0xff) } }
    }
}

// MARK: - framer

/// an app's own message protocol (iOS 13): the connection calls these on its queues
public protocol NWProtocolFramerImplementation: AnyObject {
    static var definition: NWProtocolFramer.Definition { get }
    static var label: String { get }
    init(framer: NWProtocolFramer.Instance)
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult
    func handleInput(framer: NWProtocolFramer.Instance) -> Int
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool)
    func wakeup(framer: NWProtocolFramer.Instance)
    func stop(framer: NWProtocolFramer.Instance) -> Bool
    func cleanup(framer: NWProtocolFramer.Instance)
}

public enum NWProtocolFramer {
    public final class Definition: NWProtocolDefinition, @unchecked Sendable {
        let implementation: NWProtocolFramerImplementation.Type
        public init(implementation: NWProtocolFramerImplementation.Type) {
            self.implementation = implementation
            super.init(implementation.label)
        }
    }
    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public let definition: Definition
        var values: [String: Any] = [:]
        public init(definition: Definition) { self.definition = definition; super.init() }
        public subscript(key: String) -> Any? { get { values[key] } set { values[key] = newValue } }
    }
    public enum StartResult: Sendable { case ready, willMarkReady }

    /// per-message values (the framer's metadata on a ContentContext)
    public final class Message: NWProtocolMetadata, @unchecked Sendable {
        var values: [String: Any] = [:]
        public init(definition: Definition) { super.init(); _definition = definition }
        public convenience init(instance: Instance) { self.init(definition: instance.layer.options.definition) }
        public subscript(key: String) -> Any? { get { values[key] } set { values[key] = newValue } }
    }

    /// the framer's handle on its connection
    public final class Instance: CustomDebugStringConvertible, @unchecked Sendable {
        unowned let layer: _NWFramerLayer
        init(_ l: _NWFramerLayer) { layer = l }
        public var parameters: NWParameters { layer.connection?.parameters ?? NWParameters() }
        public var remote: NWEndpoint? { layer.connection?.endpoint }
        public var local: NWEndpoint? { layer.connection.flatMap { $0.fd >= 0 ? _NWSock.local($0.fd) : nil } }
        public var options: NWProtocolFramer.Options { layer.options }
        public var debugDescription: String { "[framer \(layer.options.definition.name)]" }

        /// look at the bytes received so far: parse gets up to maximumLength of them (nil when there are none) and
        /// returns how many it consumed. False (and parse is not called) while fewer than minimumIncompleteLength are there
        @discardableResult
        public func parseInput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
            let r = layer.reader
            guard r.buffer.count >= minimumIncompleteLength else { return false }
            let n = Swift.min(r.buffer.count, maximumLength)
            var chunk = [UInt8](r.buffer.prefix(n))
            let used = chunk.withUnsafeMutableBytes { b in parse(n == 0 ? nil : b, r.eof) }
            r.buffer.removeFirst(Swift.max(0, Swift.min(used, n)))
            return true
        }
        public func deliverInput(data: Data, message: Message, isComplete: Bool) { layer.deliver(data, message, isComplete) }
        /// deliver the next length received bytes as (part of) a message; waits for them to arrive
        @discardableResult
        public func deliverInputNoCopy(length: Int, message: Message, isComplete: Bool) -> Bool {
            guard let c = layer.connection, let d = layer.reader.take(length, c) else { return false }
            layer.deliver(d, message, isComplete)
            return true
        }
        @discardableResult
        public func parseOutput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
            guard layer.pendingOutput.count >= minimumIncompleteLength else { return false }
            let n = Swift.min(layer.pendingOutput.count, maximumLength)
            var chunk = [UInt8](layer.pendingOutput.prefix(n))
            let used = chunk.withUnsafeMutableBytes { b in parse(n == 0 ? nil : b, layer.outputComplete) }
            layer.pendingOutput.removeFirst(Swift.max(0, Swift.min(used, n)))
            return true
        }
        public func writeOutput(data: Data) { layer.write(data) }
        public func writeOutput<Content: Sequence>(data: Content) where Content.Element == UInt8 { layer.write(Data(data)) }
        /// pass length bytes of the message being sent through unchanged
        public func writeOutputNoCopy(length: Int) throws {
            guard length <= layer.pendingOutput.count else { throw NWError.posix(.EINVAL) }
            layer.write(Data(layer.pendingOutput.prefix(length)))
            layer.pendingOutput.removeFirst(length)
        }
        public func passThroughInput() { layer.passInput = true }
        public func passThroughOutput() { layer.passOutput = true }
        public func markReady() { layer.markReady() }
        public func markFailed(error: NWError?) { layer.markFailed(error) }
        public func prependApplicationProtocol(options: NWProtocolOptions) {}
        public func scheduleWakeup(wakeupTime: DispatchTime) { layer.scheduleWakeup(wakeupTime) }
        public func async(execute: @escaping () -> Void) { layer.connection?.ioQueue.async(execute: execute) }
    }
}

final class _NWFramerLayer: _NWMessageLayer {
    let options: NWProtocolFramer.Options
    var impl: NWProtocolFramerImplementation?
    var instance: NWProtocolFramer.Instance!
    weak var connection: NWConnection?
    let reader = _NWByteReader()
    var delivered: [(Data, NWProtocolFramer.Message)] = []
    var partial: (Data, NWProtocolFramer.Message)?
    var pendingOutput = Data(), outputComplete = true
    var outBuffer: Data?                                  /* collected while handleOutput runs */
    var passInput = false, passOutput = false
    let readyCond = NSCondition()
    var ready = false, failed: NWError?
    var definition: NWProtocolDefinition { options.definition }
    init(_ o: NWProtocolFramer.Options) { options = o; instance = NWProtocolFramer.Instance(self) }

    func start(_ c: NWConnection) -> NWError? {
        connection = c
        let i = options.definition.implementation.init(framer: instance)
        impl = i
        if i.start(framer: instance) == .ready { return nil }
        // the framer marks itself ready (after a handshake of its own): run its input until it does
        while true {
            readyCond.lock(); let r = ready, f = failed; readyCond.unlock()
            if let f { return f }
            if r { return nil }
            let before = reader.buffer.count
            _ = i.handleInput(framer: instance)
            readyCond.lock(); let r2 = ready, f2 = failed; readyCond.unlock()
            if f2 != nil || r2 { continue }
            if reader.buffer.count == before && !reader.fill(c) { return reader.failure }
        }
    }
    func markReady() { readyCond.lock(); ready = true; readyCond.broadcast(); readyCond.unlock() }
    func markFailed(_ e: NWError?) {
        let err = e ?? .posix(.ECONNABORTED)
        readyCond.lock(); failed = err; readyCond.unlock()
        if let c = connection, c.state == .ready { c.setState(.failed(err)) }
    }
    func deliver(_ d: Data, _ m: NWProtocolFramer.Message, _ complete: Bool) {
        if var p = partial { p.0.append(d); partial = complete ? nil : p; if complete { delivered.append((p.0, p.1)) }; return }
        if complete { delivered.append((d, m)) } else { partial = (d, m) }
    }
    func write(_ d: Data) {
        if outBuffer != nil { outBuffer!.append(d); return }
        _ = connection?._transportWrite(d)
    }
    func scheduleWakeup(_ t: DispatchTime) {
        connection?.ioQueue.asyncAfter(deadline: t) { [weak self] in
            guard let self, let i = self.impl else { return }
            i.wakeup(framer: self.instance)
        }
    }

    func send(_ c: NWConnection, _ content: Data?, _ context: NWConnection.ContentContext, _ isComplete: Bool) -> NWError? {
        let data = content ?? Data()
        if passOutput { return data.isEmpty ? nil : c._transportWrite(data) }
        let m = context.protocolMetadata(definition: options.definition) as? NWProtocolFramer.Message ?? NWProtocolFramer.Message(definition: options.definition)
        pendingOutput = data; outputComplete = isComplete
        outBuffer = Data()
        impl?.handleOutput(framer: instance, message: m, messageLength: data.count, isComplete: isComplete)
        let out = outBuffer ?? Data()
        outBuffer = nil; pendingOutput = Data()
        if let f = failed { return f }
        return out.isEmpty ? nil : c._transportWrite(out)
    }

    func receive(_ c: NWConnection) -> (Data?, NWConnection.ContentContext?, Bool, NWError?) {
        while delivered.isEmpty {
            if let f = failed { return (nil, nil, false, f) }
            if passInput {
                if reader.buffer.isEmpty && !reader.fill(c) { return (nil, nil, reader.eof, reader.eof ? nil : reader.failure) }
                let d = reader.buffer; reader.buffer = Data()
                return (d, .defaultMessage, true, nil)
            }
            let before = reader.buffer.count
            _ = impl?.handleInput(framer: instance)
            if !delivered.isEmpty { break }
            if reader.buffer.count == before || reader.buffer.isEmpty {
                if !reader.fill(c) {
                    if let p = partial { partial = nil; return (p.0, ctx(p.1), true, nil) }
                    return (nil, nil, reader.eof, reader.eof ? nil : reader.failure)
                }
            }
        }
        let (d, m) = delivered.removeFirst()
        return (d, ctx(m), true, nil)
    }
    func ctx(_ m: NWProtocolFramer.Message) -> NWConnection.ContentContext {
        NWConnection.ContentContext(identifier: options.definition.name, metadata: [m])
    }
    func metadata() -> NWProtocolMetadata? { nil }
    func stop(_ c: NWConnection) {
        guard let i = impl else { return }
        _ = i.stop(framer: instance)
        i.cleanup(framer: instance)
        impl = nil
    }
}
