// isim Foundation: URLSessionStreamTask, a TCP connection (TLS with startSecureConnection()) read and written in pieces,
// over Foundation's socket streams (Stream.getStreamsToHost, frameworks/Foundation/Streams.m). Self-authored, iOS API
// names. Adapted: the connection is made at the first read, write or captureStreams(), so startSecureConnection() before
// then gives TLS from the start; TLS cannot begin on a connection that has already exchanged data (STARTTLS), and
// stopSecureConnection() does nothing. Reads poll the input stream; a write's timeout covers connecting, not sending.

public protocol URLSessionStreamDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask)
    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask)
    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask)
    func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream)
}
extension URLSessionStreamDelegate {
    public func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {}
    public func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {}
    public func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {}
    public func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {}
}

extension URLSession {
    /// A TCP connection to `hostname` on `port`, made when the task first reads or writes.
    public func streamTask(withHostName hostname: String, port: Int) -> URLSessionStreamTask {
        _add(URLSessionStreamTask(self, host: hostname, port: port))
    }
}

@objc(NSURLSessionStreamTask) open class URLSessionStreamTask: URLSessionTask, @unchecked Sendable {
    let _host: String
    let _port: Int
    let _io = NSLock()
    var _input: InputStream?
    var _output: OutputStream?
    var _connected = false, _secure = false, _captured = false, _ended = false
    var _readClosed = false, _writeClosed = false
    var _buffer = Data()
    var _ioError: Error?
    let _reads = DispatchQueue(label: "NSURLSessionStreamTask.read")
    let _writes = DispatchQueue(label: "NSURLSessionStreamTask.write")

    init(_ session: URLSession, host: String, port: Int) {
        _host = host; _port = port
        super.init(session, nil)
    }
    var _streamDelegate: URLSessionStreamDelegate? { _sessionTaskDelegate as? URLSessionStreamDelegate }

    /// the streams, connected on first use (with TLS when startSecureConnection() came first)
    func _streams() -> (InputStream, OutputStream)? {
        _io.lock(); defer { _io.unlock() }
        if let i = _input, let o = _output { return _ioError == nil ? (i, o) : nil }
        if _ioError != nil || _isCancelled { return nil }
        var i: InputStream?, o: OutputStream?
        Stream.getStreamsToHost(withName: _host, port: _port, inputStream: &i, outputStream: &o)
        guard let i, let o else { _ioError = URLError._make(NSURLErrorCannotConnectToHost, url: nil); return nil }
        if _secure { _ = i.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue, forKey: .socketSecurityLevelKey) }
        i.open(); o.open()
        _input = i; _output = o; _connected = true
        return (i, o)
    }
    /// a stream error as a URL error
    func _failure(_ s: Stream) -> Error {
        let e = s.streamError as NSError?
        if e?.domain == NSOSStatusErrorDomain { return URLError._make(NSURLErrorSecureConnectionFailed, url: nil, detail: e?.localizedDescription) }
        if e?.domain == NSPOSIXErrorDomain && e?.code == 61 { return URLError._make(NSURLErrorCannotConnectToHost, url: nil) }
        return URLError._make(NSURLErrorNetworkConnectionLost, url: nil, detail: e?.localizedDescription)
    }

    /// Reads at least `minBytes` (unless the connection ends first) and at most `maxBytes`. The handler gets the data,
    /// whether the end of the stream was reached, and an error (URLError.timedOut after `timeout` seconds; 0: none).
    open func readData(ofMinLength minBytes: Int, maxLength maxBytes: Int, timeout: TimeInterval,
                       completionHandler: @escaping @Sendable (Data?, Bool, Error?) -> Void) {
        let deadline = timeout > 0 ? Date(timeIntervalSinceNow: timeout) : nil
        _reads.async {
            let finish: (Data?, Bool, Error?) -> Void = { d, eof, e in self._session.delegateQueue.addOperation { completionHandler(d, eof, e) } }
            self._io.lock(); let closed = self._readClosed || self._captured; self._io.unlock()
            if closed { finish(nil, false, URLError._make(NSURLErrorNetworkConnectionLost, url: nil)); return }
            guard let (input, _) = self._streams() else {
                self._io.lock(); let e = self._ioError; self._io.unlock()
                finish(nil, false, self._isCancelled ? URLError._make(NSURLErrorCancelled, url: nil) : e); return
            }
            var chunk = [UInt8](repeating: 0, count: 65536)
            while true {
                self._io.lock()
                let have = self._buffer.count, ended = self._ended
                self._io.unlock()
                if have >= max(minBytes, 1) || (ended && have > 0) || (ended && minBytes == 0) { break }
                if ended { finish(nil, true, nil); return }
                if self._isCancelled { finish(nil, false, URLError._make(NSURLErrorCancelled, url: nil)); return }
                if input.hasBytesAvailable {
                    let n = input.read(&chunk, maxLength: chunk.count)
                    self._io.lock()
                    if n > 0 { self._buffer.append(contentsOf: chunk[0..<n]) } else if n == 0 { self._ended = true }
                    self._io.unlock()
                    if n > 0 { self._lock.lock(); self._received += Int64(n); self._lock.unlock() }
                    if n < 0 { finish(nil, false, self._failure(input)); return }
                    continue
                }
                switch input.streamStatus {
                case .atEnd, .closed: self._io.lock(); self._ended = true; self._io.unlock(); continue
                case .error: finish(nil, false, self._failure(input)); return
                default: break
                }
                if let deadline, Date() >= deadline { finish(nil, false, URLError._make(NSURLErrorTimedOut, url: nil)); return }
                usleep(5_000)
            }
            self._io.lock()
            let n = min(maxBytes, self._buffer.count)
            let data = self._buffer.prefix(n)
            self._buffer.removeFirst(n)
            let atEnd = self._ended && self._buffer.isEmpty
            self._io.unlock()
            finish(Data(data), atEnd, nil)
        }
    }
    open func readData(ofMinLength minBytes: Int, maxLength maxBytes: Int, timeout: TimeInterval) async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { c in
            readData(ofMinLength: minBytes, maxLength: maxBytes, timeout: timeout) { d, eof, e in
                if let e { c.resume(throwing: e) } else { c.resume(returning: (d, eof)) }
            }
        }
    }

    /// Writes `data`; the handler runs once it is all written (or with the error).
    open func write(_ data: Data, timeout: TimeInterval, completionHandler: @escaping @Sendable (Error?) -> Void) {
        _writes.async {
            let finish: (Error?) -> Void = { e in self._session.delegateQueue.addOperation { completionHandler(e) } }
            self._io.lock(); let closed = self._writeClosed || self._captured; self._io.unlock()
            if closed { finish(URLError._make(NSURLErrorNetworkConnectionLost, url: nil)); return }
            guard let (_, output) = self._streams() else {
                self._io.lock(); let e = self._ioError; self._io.unlock()
                finish(self._isCancelled ? URLError._make(NSURLErrorCancelled, url: nil) : e); return
            }
            let deadline = timeout > 0 ? Date(timeIntervalSinceNow: timeout) : nil
            while output.streamStatus == .opening || output.streamStatus == .notOpen {      /* connecting (and the TLS handshake) */
                if self._isCancelled { finish(URLError._make(NSURLErrorCancelled, url: nil)); return }
                if let deadline, Date() >= deadline { finish(URLError._make(NSURLErrorTimedOut, url: nil)); return }
                usleep(2_000)
            }
            if output.streamStatus == .error { finish(self._failure(output)); return }
            var sent = 0
            let bytes = [UInt8](data)
            while sent < bytes.count {
                if self._isCancelled { finish(URLError._make(NSURLErrorCancelled, url: nil)); return }
                let n = bytes[sent...].withUnsafeBufferPointer { output.write($0.baseAddress!, maxLength: $0.count) }
                if n < 0 { finish(self._failure(output)); return }
                if n == 0 { usleep(1_000); continue }
                sent += n
                self._lock.lock(); self._sent += Int64(n); self._lock.unlock()
            }
            finish(nil)
        }
    }
    open func write(_ data: Data, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            write(data, timeout: timeout) { e in if let e { c.resume(throwing: e) } else { c.resume() } }
        }
    }

    /// Hands the connection, after the reads and writes already asked for, to the delegate's
    /// urlSession(_:streamTask:didBecome:outputStream:) as a pair of open streams; the task then completes.
    open func captureStreams() {
        _reads.async {
            self._writes.sync {}
            guard let (i, o) = self._streams() else { return }
            self._io.lock(); self._captured = true; let left = self._buffer; self._buffer = Data(); self._io.unlock()
            let input: InputStream = left.isEmpty ? i : _PrefixedInputStream(left, i)
            if let d = self._streamDelegate { self._onQueue { d.urlSession(self._session, streamTask: self, didBecome: input, outputStream: o) } }
            self._finish(nil)
        }
    }
    /// Ends reading: pending reads finish first, then the delegate's readClosedFor.
    open func closeRead() {
        _reads.async {
            self._io.lock(); let first = !self._readClosed; self._readClosed = true; let both = self._writeClosed; self._io.unlock()
            guard first else { return }
            if let d = self._streamDelegate { self._onQueue { d.urlSession(self._session, readClosedFor: self) } }
            if both { self._close() }
        }
    }
    /// Ends writing (the peer sees the end of the stream) after the pending writes.
    open func closeWrite() {
        _writes.async {
            self._io.lock(); let first = !self._writeClosed; self._writeClosed = true; let both = self._readClosed; let o = self._output; self._io.unlock()
            guard first else { return }
            o?.close()
            if let d = self._streamDelegate { self._onQueue { d.urlSession(self._session, writeClosedFor: self) } }
            if both { self._close() }
        }
    }
    /// TLS for the connection: when called before the first read or write, the connection is made with TLS (the host
    /// name checked against the server's certificate); later, the reads and writes that follow fail.
    open func startSecureConnection() {
        _io.lock()
        if _connected { _ioError = URLError._make(NSURLErrorSecureConnectionFailed, url: nil, detail: "isim: TLS cannot start on a connection already in use") }
        else { _secure = true }
        _io.unlock()
    }
    /// Does nothing on isim (TLS stays on until the connection ends).
    open func stopSecureConnection() {}

    func _close() {
        _io.lock(); let i = _input, o = _output; _io.unlock()
        i?.close(); o?.close()
        _finish(nil)
    }
    override func _cancelHook() {
        _io.lock(); let i = _input, o = _output; _io.unlock()
        i?.close(); o?.close()
        Thread.detachNewThread { self._finish(nil) }
    }
    override func _main() {}
}

/// the captured input stream: bytes the task had already read, then the connection's
final class _PrefixedInputStream: InputStream {
    var prefix: Data
    let rest: InputStream
    init(_ prefix: Data, _ rest: InputStream) { self.prefix = prefix; self.rest = rest; super.init(data: Data()) }
    override func open() {}
    override func close() { rest.close() }
    override var streamStatus: Stream.Status { prefix.isEmpty ? rest.streamStatus : .open }
    override var streamError: Error? { rest.streamError }
    override var hasBytesAvailable: Bool { !prefix.isEmpty || rest.hasBytesAvailable }
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard !prefix.isEmpty else { return rest.read(buffer, maxLength: len) }
        let n = min(len, prefix.count)
        prefix.copyBytes(to: buffer, count: n)
        prefix.removeFirst(n)
        return n
    }
    override func property(forKey key: Stream.PropertyKey) -> Any? { rest.property(forKey: key) }
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { rest.setProperty(property, forKey: key) }
}
