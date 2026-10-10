// isim Foundation: URLSessionWebSocketTask over the host libcurl's WebSocket support (self-authored).
// A reader thread receives frames once connected; sends before the connection opens wait for it.
import isim_host

public protocol URLSessionWebSocketDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?)
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}
extension URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {}
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
}

extension URLSession {
    public func webSocketTask(with url: URL) -> URLSessionWebSocketTask { webSocketTask(with: URLRequest(url: url)) }
    public func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask {
        var r = URLRequest(url: url)
        if !protocols.isEmpty { r.setValue(protocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol") }
        return webSocketTask(with: r)
    }
    public func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask { _add(URLSessionWebSocketTask(self, request)) }
}

open class URLSessionWebSocketTask: URLSessionTask, @unchecked Sendable {
    public enum Message: Sendable {
        case data(Data)
        case string(String)
    }
    public enum CloseCode: Int, Sendable {
        case invalid = 0, normalClosure = 1000, goingAway = 1001, protocolError = 1002, unsupportedData = 1003, noStatusReceived = 1005,
             abnormalClosure = 1006, invalidFramePayloadData = 1007, policyViolation = 1008, messageTooBig = 1009,
             mandatoryExtensionMissing = 1010, internalServerError = 1011, tlsHandshakeFailure = 1015
    }
    public var maximumMessageSize = 1_048_576
    public var closeCode: CloseCode { _lock.lock(); defer { _lock.unlock() }; return _closeCode }
    public var closeReason: Data? { _lock.lock(); defer { _lock.unlock() }; return _closeReason }

    var _ws: OpaquePointer?
    var _closeCode: CloseCode = .invalid
    var _closeReason: Data?
    var _openError: Error?
    var _opened = false
    let _openSignal = DispatchSemaphore(value: 0)
    var _inbox: [Message] = []
    var _waiting: [(Result<Message, Error>) -> Void] = []
    var _pongs: [(Error?) -> Void] = []
    var _readerError: Error?

    static func _notConnected() -> Error {
        NSError(domain: "NSPOSIXErrorDomain", code: 57, userInfo: [NSLocalizedDescriptionKey: "Socket is not connected"])
    }

    override func _main() {
        guard var url = originalRequest?.url else { _finish(URLError(.badURL)); return }
        // ws/wss as given; http(s) URLs are accepted like on iOS
        if url.scheme == "http" || url.scheme == "https", var c = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            c.scheme = url.scheme == "https" ? "wss" : "ws"; url = c.url ?? url
        }
        var headers = (originalRequest?._headers ?? []).map { "\($0.0): \($0.1)" }
        if let jar = _session.configuration.httpCookieStorage, _session.configuration.httpShouldSetCookies,
           var hc = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            hc.scheme = url.scheme == "wss" ? "https" : "http"     // cookies match the http(s) origin
            if let http = hc.url, let cookies = jar.cookies(for: http), !cookies.isEmpty {
                headers.append("Cookie: " + cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "))
            }
        }
        var err: Int32 = 0, head: UnsafeMutablePointer<CChar>? = nil
        let ws = isim_ws_open_ex(url.absoluteString, headers.joined(separator: "\n"), originalRequest?.timeoutInterval ?? 60, &err, &head)
        // the server's response (101, or the refusal), and the subprotocol it chose
        var negotiated: String? = nil
        if let head {
            let raw = String(cString: head); free(head)
            let status = raw.split(separator: " ", maxSplits: 2).dropFirst().first.flatMap { Int($0) } ?? 0
            let (version, fields) = URLSessionTask._parseHeaders(raw)
            negotiated = fields.first { $0.0.caseInsensitiveCompare("Sec-WebSocket-Protocol") == .orderedSame }?.1
            _setResponse(HTTPURLResponse(_url: url, statusCode: status, httpVersion: version ?? "HTTP/1.1", headers: fields))
        }
        _lock.lock()
        if let ws, _cancelled { isim_ws_close(ws); _lock.unlock(); _openSignal.signal(); _finish(nil); return }
        _ws = ws; _opened = ws != nil
        if ws == nil { _openError = URLError._make(Int(err), url: url) }
        _lock.unlock()
        _openSignal.signal()
        guard let ws else { _failAll(_openError!); _finish(_openError); return }
        if let d = _sessionTaskDelegate as? URLSessionWebSocketDelegate {
            let proto = negotiated
            _session.delegateQueue.addOperation { d.urlSession(self._session, webSocketTask: self, didOpenWithProtocol: proto) }
        }
        // reader
        while true {
            var kind: Int32 = 0, data: UnsafeMutablePointer<UInt8>? = nil, len = 0
            let rc = isim_ws_recv(ws, &kind, &data, &len)
            if rc != 0 {
                let e: Error = _isCancelled ? URLError(.cancelled) : URLSessionWebSocketTask._notConnected()
                _lock.lock(); if _closeCode == .invalid && !_cancelled { _closeCode = .abnormalClosure }; _lock.unlock()
                _failAll(e)
                _finish(_isCancelled ? nil : URLError._make(rc == -999 ? NSURLErrorCancelled : Int(rc), url: url))
                return
            }
            let bytes = Data(UnsafeBufferPointer(start: data, count: len))
            free(data)
            switch kind {
            case 1: _deliver(.string(String(decoding: bytes, as: UTF8.self)))
            case 2: _deliver(.data(bytes))
            case 10:
                _lock.lock(); let p = _pongs.isEmpty ? nil : _pongs.removeFirst(); _lock.unlock()
                if let p { _session.delegateQueue.addOperation { p(nil) } }
            case 8:     // peer closed: code (2 bytes, big endian) + reason
                let code = bytes.count >= 2 ? Int(bytes[0]) << 8 | Int(bytes[1]) : 1005
                let reason = bytes.count > 2 ? bytes.subdata(in: 2..<bytes.count) : nil
                _lock.lock(); _closeCode = CloseCode(rawValue: code) ?? .normalClosure; _closeReason = reason; _lock.unlock()
                if let d = _sessionTaskDelegate as? URLSessionWebSocketDelegate {
                    let c = closeCode
                    _onQueue { d.urlSession(self._session, webSocketTask: self, didCloseWith: c, reason: reason) }
                }
                _failAll(URLSessionWebSocketTask._notConnected())
                _lock.lock(); _ws = nil; _lock.unlock()
                isim_ws_close(ws)
                _finish(nil)
                return
            default: break        // pings are answered by libcurl
            }
        }
    }

    func _deliver(_ m: Message) {
        _lock.lock()
        if _waiting.isEmpty { _inbox.append(m); _lock.unlock(); return }
        let h = _waiting.removeFirst()
        _lock.unlock()
        _session.delegateQueue.addOperation { h(.success(m)) }
    }
    func _failAll(_ e: Error) {
        _lock.lock()
        _readerError = e
        let w = _waiting, p = _pongs
        _waiting = []; _pongs = []
        _lock.unlock()
        for h in w { _session.delegateQueue.addOperation { h(.failure(e)) } }
        for h in p { _session.delegateQueue.addOperation { h(e) } }
    }
    /// waits for the connection (sends right after resume() are allowed)
    func _socket() -> OpaquePointer? {
        _lock.lock()
        if !_opened && _openError == nil && _state != .completed && !_cancelled {
            _lock.unlock(); _openSignal.wait(); _openSignal.signal(); _lock.lock()
        }
        let ws = _ws
        _lock.unlock()
        return ws
    }

    open func send(_ message: Message, completionHandler: @escaping @Sendable (Error?) -> Void) {
        Thread.detachNewThread {
            let err: Error?
            if let ws = self._socket() {
                let rc: Int32
                switch message {
                case .string(let s): let b = Array(s.utf8); rc = b.withUnsafeBytes { isim_ws_send(ws, 1, $0.baseAddress, $0.count) }
                case .data(let d): rc = d.withUnsafeBytes { isim_ws_send(ws, 2, $0.baseAddress, $0.count) }
                }
                err = rc == 0 ? nil : URLSessionWebSocketTask._notConnected()
            } else { err = URLSessionWebSocketTask._notConnected() }
            self._session.delegateQueue.addOperation { completionHandler(err) }
        }
    }
    open func receive(completionHandler: @escaping @Sendable (Result<Message, Error>) -> Void) {
        _lock.lock()
        if !_inbox.isEmpty { let m = _inbox.removeFirst(); _lock.unlock(); _session.delegateQueue.addOperation { completionHandler(.success(m)) }; return }
        if let e = _readerError ?? (_state == .completed ? URLSessionWebSocketTask._notConnected() : nil) {
            _lock.unlock(); _session.delegateQueue.addOperation { completionHandler(.failure(e)) }; return
        }
        _waiting.append(completionHandler)
        _lock.unlock()
    }
    open func sendPing(pongReceiveHandler: @escaping @Sendable (Error?) -> Void) {
        Thread.detachNewThread {
            guard let ws = self._socket() else { self._session.delegateQueue.addOperation { pongReceiveHandler(URLSessionWebSocketTask._notConnected()) }; return }
            self._lock.lock(); self._pongs.append(pongReceiveHandler); self._lock.unlock()
            if isim_ws_send(ws, 9, nil, 0) != 0 { self._failAll(URLSessionWebSocketTask._notConnected()) }
        }
    }
    open func send(_ message: Message) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            send(message) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func receive() async throws -> Message {
        try await withCheckedThrowingContinuation { k in receive { k.resume(with: $0) } }
    }
    /// sends a close frame with the code and reason, then closes the connection
    open func cancel(with closeCode: CloseCode, reason: Data?) {
        _lock.lock(); _closeCode = closeCode; _closeReason = reason; let ws = _ws; _lock.unlock()
        if let ws {
            var payload = [UInt8(closeCode.rawValue >> 8 & 0xff), UInt8(closeCode.rawValue & 0xff)]
            if let reason { payload += Array(reason) }
            _ = payload.withUnsafeBytes { isim_ws_send(ws, 8, $0.baseAddress, $0.count) }
        }
        cancel()
    }
    override func _cancelHook() {
        _lock.lock(); let ws = _ws; _ws = nil; _lock.unlock()
        _openSignal.signal()
        if let ws { isim_ws_close(ws) }
    }
}
