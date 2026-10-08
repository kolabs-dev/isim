// Networking self-test on isim (no Internet needed): URLComponents/URLQueryItem, URL resolution, URLRequest,
// HTTPURLResponse, HTTPCookie, URLCache, BSD sockets (a tiny HTTP server in this process serves the requests),
// URLSession (completion handlers, delegates, async/await, download/upload, redirects, cookies, cache,
// errors, cancellation, bytes.lines, Combine), file:/data: URLs and NWPathMonitor.
import Foundation
import Combine
import Network

nonisolated(unsafe) var failures = 0, checks = 0
let checkLock = NSLock()
func check(_ ok: Bool, _ what: String) {
    checkLock.lock(); defer { checkLock.unlock() }
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

// MARK: - a minimal HTTP/1.1 server on BSD sockets (one thread per connection, Connection: close)
final class MiniServer: @unchecked Sendable {
    let fd: Int32
    let port: UInt16
    let lock = NSLock()
    var hits: [String: Int] = [:]
    var lastHeaders: [String: String] = [:]

    init?() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        self.fd = fd
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = UInt32(0x7f000001).bigEndian
        let ok = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard ok == 0, listen(fd, 16) == 0 else { return nil }
        var bound = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &bound) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
        port = UInt16(bigEndian: bound.sin_port)
        Thread.detachNewThread { self.acceptLoop() }
    }
    var base: String { "http://127.0.0.1:\(port)" }
    func acceptLoop() {
        while true {
            let c = accept(fd, nil, nil)
            if c < 0 { return }
            Thread.detachNewThread { self.serve(c) }
        }
    }
    func readRequest(_ c: Int32) -> (String, String, [String: String], [UInt8])? {
        var buf = [UInt8](), chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = recv(c, &chunk, chunk.count, 0)
            if n <= 0 { return nil }
            buf += chunk[0..<n]
            if let end = find(buf, Array("\r\n\r\n".utf8)) {
                let head = String(decoding: buf[0..<end], as: UTF8.self).components(separatedBy: "\r\n")
                let parts = head[0].split(separator: " ").map(String.init)
                guard parts.count >= 2 else { return nil }
                var headers: [String: String] = [:]
                for line in head.dropFirst() { if let i = line.firstIndex(of: ":") { headers[line[..<i].lowercased()] = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces) } }
                var body = Array(buf[(end + 4)...])
                let want = Int(headers["content-length"] ?? "0") ?? 0
                while body.count < want { let n = recv(c, &chunk, chunk.count, 0); if n <= 0 { break }; body += chunk[0..<n] }
                return (parts[0], parts[1], headers, body)
            }
        }
    }
    func find(_ h: [UInt8], _ n: [UInt8]) -> Int? {
        guard h.count >= n.count else { return nil }
        for i in 0...(h.count - n.count) where Array(h[i..<(i + n.count)]) == n { return i }
        return nil
    }
    func respond(_ c: Int32, _ status: String, _ headers: [String], _ body: [UInt8]) {
        var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        for h in headers { head += h + "\r\n" }
        head += "\r\n"
        let out = Array(head.utf8) + body
        var sent = 0
        while sent < out.count { let n = out[sent...].withUnsafeBytes { send(c, $0.baseAddress, $0.count, 0) }; if n <= 0 { break }; sent += n }
    }
    func serve(_ c: Int32) {
        defer { close(c) }
        guard let (method, target, headers, body) = readRequest(c) else { return }
        let path = String(target.split(separator: "?", maxSplits: 1).first ?? "")
        lock.lock(); hits[path, default: 0] += 1; lastHeaders = headers; let hitCount = hits[path]!; lock.unlock()
        switch path {
        case "/json":
            respond(c, "200 OK", ["Content-Type: application/json; charset=utf-8"], Array(#"{"name":"isim","version":2,"tags":["ios","linux"]}"#.utf8))
        case "/text":
            respond(c, "200 OK", ["Content-Type: text/plain"], Array("hello from the mini server".utf8))
        case "/headers":
            let ua = headers["user-agent"] ?? "", custom = headers["x-custom"] ?? "", lang = headers["accept-language"] ?? ""
            respond(c, "200 OK", ["Content-Type: text/plain"], Array("ua=\(ua)|custom=\(custom)|lang=\(lang)|query=\(target)".utf8))
        case "/echo":
            respond(c, "201 Created", ["Content-Type: application/octet-stream", "X-Method: \(method)", "X-Content-Type: \(headers["content-type"] ?? "")"], body)
        case "/redirect":
            respond(c, "302 Found", ["Location: /json"], [])
        case "/redirect-post":
            respond(c, "303 See Other", ["Location: /echo"], [])
        case "/loop":
            respond(c, "302 Found", ["Location: /loop"], [])
        case "/cookie/set":
            respond(c, "200 OK", ["Set-Cookie: session=abc123; Path=/", "Set-Cookie: theme=dark; Max-Age=3600; Path=/cookie"], Array("ok".utf8))
        case "/cookie/get":
            respond(c, "200 OK", ["Content-Type: text/plain"], Array((headers["cookie"] ?? "none").utf8))
        case "/missing":
            respond(c, "404 Not Found", ["Content-Type: text/plain"], Array("nope".utf8))
        case "/slow":
            Thread.sleep(forTimeInterval: 3)
            respond(c, "200 OK", [], Array("late".utf8))
        case "/etag":
            if headers["if-none-match"] == "\"v1\"" { respond(c, "304 Not Modified", ["ETag: \"v1\""], []) }
            else { respond(c, "200 OK", ["ETag: \"v1\"", "Cache-Control: no-cache", "Content-Type: text/plain"], Array("etag body \(hitCount)".utf8)) }
        case "/fresh":
            respond(c, "200 OK", ["Cache-Control: max-age=60", "Content-Type: text/plain"], Array("fresh \(hitCount)".utf8))
        case "/big":
            respond(c, "200 OK", ["Content-Type: application/octet-stream"], (0..<300_000).map { UInt8($0 % 251) })
        case "/lines":
            respond(c, "200 OK", ["Content-Type: text/plain"], Array("alpha\nbeta\r\n\ngamma".utf8))
        default:
            respond(c, "404 Not Found", [], [])
        }
    }
}

final class DataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    var received = Data(), response: URLResponse?, completed: Error?? = nil, redirects = 0
    let done = DispatchSemaphore(value: 0)
    var onDelegateQueue = true
    let queue: OperationQueue
    init(queue: OperationQueue) { self.queue = queue }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        self.response = response; onDelegateQueue = onDelegateQueue && OperationQueue.current === queue
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        received.append(data); onDelegateQueue = onDelegateQueue && OperationQueue.current === queue
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        redirects += 1; completionHandler(request)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { completed = .some(error); done.signal() }
}
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var size = -1, progress = 0, finished = false
    let done = DispatchSemaphore(value: 0)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        size = FileManager.default.contents(atPath: location.path)?.count ?? -2
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress += 1
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { finished = error == nil; done.signal() }
}

struct Info: Decodable, Equatable { let name: String; let version: Int; let tags: [String] }

func has(_ s: String, _ sub: String) -> Bool { s.components(separatedBy: sub).count > 1 }
func code(_ e: Error?) -> Int { (e as? URLError)?.code.rawValue ?? (e.map { ($0 as NSError).code } ?? 0) }

/// URLSessionWebSocketTask against ws_server.py (see its docstring for the scenarios)
func webSocketChecks(base: String, what: String) async {
    func text(_ m: URLSessionWebSocketTask.Message?) -> String? { if case .string(let s)? = m { return s }; return nil }
    func bytes(_ m: URLSessionWebSocketTask.Message?) -> Data? { if case .data(let d)? = m { return d }; return nil }
    var req = URLRequest(url: URL(string: "\(base)/ws?client=isim")!)
    req.setValue("hello", forHTTPHeaderField: "X-Isim")
    req.setValue("chat, superchat", forHTTPHeaderField: "Sec-WebSocket-Protocol")
    let task = URLSession.shared.webSocketTask(with: req)
    task.resume()
    do {
        try await task.send(.string("hello isim"))
        check(text(try await task.receive()) == "echo: hello isim", "\(what): text message echo")
        try await task.send(.string("headers?"))
        let h = text(try await task.receive())
        check(h == "x-isim=hello proto=chat query=client=isim", "\(what): request headers, Sec-WebSocket-Protocol and the query reach the server (\(h ?? "nil"))")
        try await task.send(.data(Data([0, 1, 2, 254, 255])))
        check(bytes(try await task.receive()) == Data([0, 1, 2, 254, 255]), "\(what): binary message echo")
        try await task.send(.string("fragment"))
        let f = text(try await task.receive())
        check(f == "frag-1 frag-2 frag-3", "\(what): a message in three fragments, with pings between them, is joined (\(f ?? "nil"))")
        try await task.send(.string("pongs?"))
        check(text(try await task.receive()) == "pongs: 2", "\(what): the server's pings are answered with pongs carrying their payload")
        try await task.send(.string("big"))
        let big = bytes(try await task.receive())
        check(big?.count == 70000 && big?.enumerated().allSatisfy { $0.element == UInt8($0.offset % 251) } == true,
              "\(what): a 70000-byte message (64-bit length) arrives intact (\(big?.count ?? -1))")
        let pong = await withCheckedContinuation { (c: CheckedContinuation<Error?, Never>) in task.sendPing { c.resume(returning: $0) } }
        check(pong == nil, "\(what): sendPing gets the server's pong (\(String(describing: pong)))")
        try await task.send(.string("close"))
        do { _ = try await task.receive(); check(false, "\(what): receive after the server's close throws") }
        catch { check(task.closeReason == Data("bye".utf8), "\(what): the server's close frame ends the task with its reason (\(task.closeCode.rawValue))") }
    } catch { check(false, "\(what): WebSocket exchange threw \(error)") }
    task.cancel(with: .normalClosure, reason: nil)

    // a server that refuses the upgrade (HTTP 403): the task fails with badServerResponse
    let refused = URLSession.shared.webSocketTask(with: URL(string: "\(base)/refuse")!)
    refused.resume()
    do { _ = try await refused.receive(); check(false, "\(what): a refused upgrade fails") }
    catch { check(code(error) == NSURLErrorBadServerResponse, "\(what): a refused upgrade fails with badServerResponse (\(code(error)))") }
}

@main struct Main {
    static func main() async {
        // MARK: URLComponents / URLQueryItem
        var c = URLComponents(string: "https://user:pw@example.com:8443/a%20b/c?q=swift%20ui&n=1#frag")!
        check(c.scheme == "https" && c.user == "user" && c.password == "pw" && c.host == "example.com" && c.port == 8443, "URLComponents parses scheme/user/password/host/port")
        check(c.path == "/a b/c" && c.percentEncodedPath == "/a%20b/c" && c.fragment == "frag", "URLComponents path decoding (\(c.path))")
        check(c.queryItems == [URLQueryItem(name: "q", value: "swift ui"), URLQueryItem(name: "n", value: "1")], "URLComponents.queryItems decodes")
        c.queryItems = [URLQueryItem(name: "q", value: "a&b=c d+e"), URLQueryItem(name: "flag", value: nil)]
        check(c.percentEncodedQuery == "q=a%26b%3Dc%20d+e&flag", "queryItems setter encodes & = space, keeps + (\(c.percentEncodedQuery ?? "nil"))")
        var b = URLComponents()
        b.scheme = "http"; b.host = "127.0.0.1"; b.port = 8080; b.path = "/api/items"; b.queryItems = [URLQueryItem(name: "page", value: "2")]
        check(b.url?.absoluteString == "http://127.0.0.1:8080/api/items?page=2", "URLComponents builds a URL (\(b.string ?? "nil"))")
        var bad = URLComponents(); bad.host = "h"; bad.path = "relative"
        check(bad.url == nil && URLComponents(string: "http://a b") == nil, "invalid components -> nil")
        check(URLComponents(string: "http://[::1]:8080/x")?.host == "::1" && URL(string: "http://[::1]:9/x")?.port == 9, "IPv6 literal hosts")
        let rel = URL(string: "../v2/items?x=1", relativeTo: URL(string: "http://h:8080/api/v1/list"))
        check(rel?.absoluteString == "http://h:8080/api/v2/items?x=1", "URL(string:relativeTo:) keeps the port, resolves .. (\(rel?.absoluteString ?? "nil"))")
        check(URL(string: "http://x.com/s")!.appending(queryItems: [URLQueryItem(name: "k", value: "v w")]).absoluteString == "http://x.com/s?k=v%20w", "URL.appending(queryItems:)")
        check(URL(string: "a b", encodingInvalidCharacters: true)?.absoluteString == "a%20b", "URL(string:encodingInvalidCharacters:)")

        // MARK: URLRequest / HTTPURLResponse
        var req = URLRequest(url: URL(string: "http://x/")!)
        check(req.httpMethod == "GET" && req.timeoutInterval == 60 && req.cachePolicy == .useProtocolCachePolicy, "URLRequest defaults")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.addValue("b", forHTTPHeaderField: "X-A"); req.addValue("c", forHTTPHeaderField: "x-a")
        check(req.value(forHTTPHeaderField: "content-type") == "application/json" && req.value(forHTTPHeaderField: "X-A") == "b,c", "URLRequest headers are case-insensitive, addValue appends")
        let hr = HTTPURLResponse(url: URL(string: "http://x/f.json")!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=UTF-8", "Content-Length": "12"])!
        check(hr.statusCode == 404 && hr.mimeType == "application/json" && hr.textEncodingName == "utf-8" && hr.expectedContentLength == 12 &&
              hr.value(forHTTPHeaderField: "content-length") == "12" && hr.suggestedFilename == "f.json", "HTTPURLResponse fields")
        check(HTTPURLResponse.localizedString(forStatusCode: 404) == "not found", "HTTPURLResponse.localizedString(forStatusCode:)")

        // MARK: HTTPCookie
        let u = URL(string: "http://shop.example.com/cart/view")!
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "a=1; Path=/; Expires=Wed, 21 Oct 2037 07:28:00 GMT, b=2; Domain=example.com; Secure; HttpOnly"], for: u)
        check(cookies.count == 2 && cookies[0].name == "a" && cookies[0].expiresDate != nil && cookies[1].domain == ".example.com" && cookies[1].isSecure && cookies[1].isHTTPOnly,
              "HTTPCookie parses Set-Cookie (expires comma, domain, flags)")
        check(cookies[0].path == "/" && HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] == "a=1; b=2", "HTTPCookie.requestHeaderFields")
        check(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "x=1; Domain=evil.com"], for: u).isEmpty, "cookies for a foreign domain are rejected")

        // MARK: sockets
        var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>? = nil
        let gai = getaddrinfo("localhost", "80", &hints, &res)
        var resolved = ""
        if gai == 0, let r = res, let sa = r.pointee.ai_addr {
            sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var a = sin.pointee.sin_addr; var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &a, &buf, socklen_t(buf.count)); resolved = String(cString: buf) + ":\(UInt16(bigEndian: sin.pointee.sin_port))"
            }
            check(r.pointee.ai_family == AF_INET && sa.pointee.sa_family == sa_family_t(AF_INET) && resolved == "127.0.0.1:80", "getaddrinfo(localhost) with Darwin addrinfo/sockaddr layout (\(resolved))")
            freeaddrinfo(res)
        } else { check(false, "getaddrinfo(localhost) (\(gai))") }
        var in6 = in6_addr(); var s6 = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        check(inet_pton(AF_INET6, "fe80::1", &in6) == 1 && inet_ntop(AF_INET6, &in6, &s6, socklen_t(s6.count)) != nil && String(cString: s6) == "fe80::1", "inet_pton/inet_ntop AF_INET6 (Darwin family 30)")
        var numeric = addrinfo(); numeric.ai_flags = AI_NUMERICHOST
        check(getaddrinfo("not-an-address", nil, &numeric, &res) == EAI_NONAME && EAI_NONAME == 8, "getaddrinfo error codes are Darwin's (EAI_NONAME 8)")
        let refused = socket(AF_INET, SOCK_STREAM, 0)
        var dead = sockaddr_in(); dead.sin_family = sa_family_t(AF_INET); dead.sin_port = UInt16(1).bigEndian; dead.sin_addr.s_addr = UInt32(0x7f000001).bigEndian
        let rc = withUnsafePointer(to: &dead) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(refused, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        check(rc == -1 && errno == ECONNREFUSED && ECONNREFUSED == 61, "connect() to a closed port -> ECONNREFUSED (Darwin errno 61)")
        close(refused)
        var pair: [Int32] = [0, 0]
        if socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0 {
            _ = send(pair[0], "ping", 4, 0)
            var pfd = pollfd(fd: pair[1], events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, 1000)
            var rb = [UInt8](repeating: 0, count: 8)
            let n = recv(pair[1], &rb, 8, 0)
            check(ready == 1 && pfd.revents & Int16(POLLIN) != 0 && n == 4 && String(decoding: rb[0..<4], as: UTF8.self) == "ping", "socketpair + send/recv + poll")
            var e: Int32 = 0
            check(recv(pair[1], &rb, 8, Int32(MSG_DONTWAIT)) == -1 && { e = errno; return e == EAGAIN }(), "MSG_DONTWAIT on an empty socket -> EAGAIN (35)")
            _ = send(pair[1], "pong", 4, 0)
            var set = fd_set()
            withUnsafeMutableBytes(of: &set.fds_bits) { $0.bindMemory(to: Int32.self)[Int(pair[0]) / 32] |= Int32(1) << (pair[0] % 32) }
            var tv = timeval(tv_sec: 1, tv_usec: 0)
            let sel = select(pair[0] + 1, &set, nil, nil, &tv)
            check(sel == 1, "select() reports a readable socket")
            var rbuf = [UInt8](repeating: 0, count: 8)
            _ = read(pair[0], &rbuf, 8)                      // "pong"
            var rcvTimeout = timeval(tv_sec: 0, tv_usec: 100_000)
            let so = setsockopt(pair[0], SOL_SOCKET, SO_RCVTIMEO, &rcvTimeout, socklen_t(MemoryLayout<timeval>.size))
            let t0 = Date()
            let r = read(pair[0], &rbuf, 8)
            let readErr = errno, waited = Date().timeIntervalSince(t0)
            check(so == 0 && r == -1 && readErr == EAGAIN && waited > 0.05 && waited < 1, "SO_RCVTIMEO (Darwin timeval) + read() errno EAGAIN (\(readErr), \(waited)s)")
            close(pair[0]); close(pair[1])
        } else { check(false, "socketpair") }
        var ifs: UnsafeMutablePointer<ifaddrs>? = nil
        var loopback = false
        if getifaddrs(&ifs) == 0 {
            var p = ifs
            while let a = p {
                if let sa = a.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET), a.pointee.ifa_flags & UInt32(IFF_LOOPBACK) != 0 {
                    sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { loopback = $0.pointee.sin_addr.s_addr == UInt32(0x7f000001).bigEndian }
                }
                p = a.pointee.ifa_next
            }
            freeifaddrs(ifs)
        }
        check(loopback, "getifaddrs lists the IPv4 loopback interface")

        guard let server = MiniServer() else { check(false, "mini server (socket/bind/listen)"); exit(1) }
        check(server.port > 0, "socket/bind/listen/getsockname on 127.0.0.1 (port \(server.port))")
        let base = server.base

        // MARK: URLSession: completion handler on the delegate queue
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var chOK = false, chQueue = false
        URLSession.shared.dataTask(with: URL(string: base + "/json")!) { data, response, error in
            let info = data.flatMap { try? JSONDecoder().decode(Info.self, from: $0) }
            chOK = error == nil && (response as? HTTPURLResponse)?.statusCode == 200 && info == Info(name: "isim", version: 2, tags: ["ios", "linux"])
            chQueue = !Thread.isMainThread && OperationQueue.current === URLSession.shared.delegateQueue
            sem.signal()
        }.resume()
        sem.wait()
        check(chOK, "dataTask(with:completionHandler:) + JSONDecoder")
        check(chQueue, "completion handler runs on the session's background delegateQueue")

        // MARK: async/await
        do {
            let (data, resp) = try await URLSession.shared.data(from: URL(string: base + "/text")!)
            let http = resp as? HTTPURLResponse
            check(String(data: data, encoding: .utf8) == "hello from the mini server" && http?.mimeType == "text/plain" && http?.expectedContentLength == 26, "async data(from:)")
        } catch { check(false, "async data(from:) threw \(error)") }
        do {
            var r = URLRequest(url: URL(string: base + "/headers?x=1&y=two")!)
            r.setValue("yes", forHTTPHeaderField: "X-Custom")
            let (data, _) = try await URLSession.shared.data(for: r)
            let s = String(decoding: data, as: UTF8.self)
            check(s.hasPrefix("ua=SwiftNetworkTest/1 isim|custom=yes|lang=") && s.hasSuffix("query=/headers?x=1&y=two"), "data(for:) sends request headers + User-Agent (\(s))")
        } catch { check(false, "data(for:) threw \(error)") }
        do {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.httpAdditionalHeaders = ["X-Custom": "from-config", "User-Agent": "Custom/2"]
            let (data, _) = try await URLSession(configuration: cfg).data(from: URL(string: base + "/headers")!)
            check(String(decoding: data, as: UTF8.self).hasPrefix("ua=Custom/2|custom=from-config|"), "httpAdditionalHeaders (\(String(decoding: data, as: UTF8.self)))")
        } catch { check(false, "httpAdditionalHeaders threw \(error)") }
        do {
            var r = URLRequest(url: URL(string: base + "/echo")!)
            r.httpMethod = "PUT"; r.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            let (data, resp) = try await URLSession.shared.upload(for: r, from: Data("payload ✓".utf8))
            let h = resp as! HTTPURLResponse
            check(h.statusCode == 201 && h.value(forHTTPHeaderField: "x-method") == "PUT" && h.value(forHTTPHeaderField: "X-Content-Type") == "text/plain" &&
                  String(data: data, encoding: .utf8) == "payload ✓", "upload(for:from:) with PUT + body")
        } catch { check(false, "upload threw \(error)") }
        do {
            var r = URLRequest(url: URL(string: base + "/echo")!)
            r.httpMethod = "POST"; r.httpBody = Data(#"{"a":1}"#.utf8)
            let (data, resp) = try await URLSession.shared.data(for: r)
            check((resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Method") == "POST" && data == Data(#"{"a":1}"#.utf8), "POST with httpBody")
        } catch { check(false, "POST threw \(error)") }
        do {
            let (data, resp) = try await URLSession.shared.data(from: URL(string: base + "/missing")!)
            check((resp as? HTTPURLResponse)?.statusCode == 404 && data == Data("nope".utf8), "HTTP 404 is a response, not an error")
        } catch { check(false, "404 threw \(error)") }
        do {
            let (data, resp) = try await URLSession.shared.data(from: URL(string: base + "/redirect")!)
            check(resp.url?.path == "/json" && (try? JSONDecoder().decode(Info.self, from: data))?.name == "isim", "redirects are followed (\(resp.url?.absoluteString ?? ""))")
        } catch { check(false, "redirect threw \(error)") }
        do {
            var r = URLRequest(url: URL(string: base + "/redirect-post")!); r.httpMethod = "POST"; r.httpBody = Data("x".utf8)
            let (_, resp) = try await URLSession.shared.data(for: r)
            check((resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Method") == "GET", "303 turns POST into GET")
        } catch { check(false, "303 threw \(error)") }
        do { _ = try await URLSession.shared.data(from: URL(string: base + "/loop")!); check(false, "redirect loop") }
        catch { check(code(error) == NSURLErrorHTTPTooManyRedirects, "redirect loop -> .httpTooManyRedirects") }

        // MARK: errors
        do { _ = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:1/")!); check(false, "refused") }
        catch { check((error as? URLError)?.code == .cannotConnectToHost, "connection refused -> URLError.cannotConnectToHost (\(code(error)))") }
        do { _ = try await URLSession.shared.data(from: URL(string: "http://no-such-host.invalid/")!); check(false, "dns") }
        catch { check((error as? URLError)?.code == .cannotFindHost, "unknown host -> URLError.cannotFindHost (\(code(error)))") }
        let quick = URLSessionConfiguration.ephemeral; quick.timeoutIntervalForRequest = 1
        do { _ = try await URLSession(configuration: quick).data(from: URL(string: base + "/slow")!); check(false, "timeout") }
        catch {
            check((error as? URLError)?.code == .timedOut && (error as? URLError)?.failingURL?.path == "/slow", "idle timeout -> URLError.timedOut with failingURL (\(code(error)))")
            check(error.localizedDescription == "The request timed out." && (error as NSError).domain == NSURLErrorDomain, "URLError bridges to NSError (domain, localizedDescription)")
        }
        do { _ = try await URLSession.shared.data(from: URL(string: "gopher://x/")!); check(false, "scheme") }
        catch { check((error as? URLError)?.code == .unsupportedURL, "unsupported scheme -> .unsupportedURL") }
        let ct = URLSession.shared.dataTask(with: URL(string: base + "/slow")!) { _, _, e in
            check((e as? URLError)?.code == .cancelled, "cancel() -> completion with URLError.cancelled"); sem.signal()
        }
        ct.resume()
        check(ct.state == .running, "task state running after resume()")
        ct.cancel()
        sem.wait()
        check(ct.state == .completed, "task state completed after cancel")
        let asyncCancel = Task { try await URLSession.shared.data(from: URL(string: base + "/slow")!) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        asyncCancel.cancel()
        do { _ = try await asyncCancel.value; check(false, "async cancel") }
        catch { check((error as? URLError)?.code == .cancelled, "Task cancellation cancels data(from:)") }
        do {
            _ = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:1/")!); check(false, "catch pattern")
        } catch URLError.cannotConnectToHost { check(true, "catch URLError.cannotConnectToHost pattern") }
        catch { check(false, "catch pattern (\(error))") }

        // MARK: cookies
        do {
            _ = try await URLSession.shared.data(from: URL(string: base + "/cookie/set")!)
            let (d1, _) = try await URLSession.shared.data(from: URL(string: base + "/cookie/get")!)
            let names = HTTPCookieStorage.shared.cookies(for: URL(string: base + "/cookie/get")!)?.map(\.name).sorted() ?? []
            check(String(decoding: d1, as: UTF8.self) == "theme=dark; session=abc123" && names == ["session", "theme"], "Set-Cookie stored and sent back (\(String(decoding: d1, as: UTF8.self)))")
            let (d2, _) = try await URLSession.shared.data(from: URL(string: base + "/headers")!)
            _ = d2
            let (d3, _) = try await URLSession(configuration: .ephemeral).data(from: URL(string: base + "/cookie/get")!)
            check(String(decoding: d3, as: UTF8.self) == "none", "ephemeral sessions have their own cookie jar")
            let persisted = FileManager.default.contents(atPath: NSHomeDirectory() + "/Library/Cookies/Cookies.json").map { String(decoding: $0, as: UTF8.self) } ?? ""
            check(has(persisted, "theme") && !has(persisted, "abc123"), "persistent cookies saved in the container, session cookies not")
        } catch { check(false, "cookies threw \(error)") }

        // MARK: cache
        do {
            let cache = URLCache(memoryCapacity: 1 << 20, diskCapacity: 0)
            let cfg = URLSessionConfiguration.default; cfg.urlCache = cache
            let s = URLSession(configuration: cfg)
            let (a, _) = try await s.data(from: URL(string: base + "/fresh")!)
            let (b, _) = try await s.data(from: URL(string: base + "/fresh")!)
            check(a == b && String(decoding: a, as: UTF8.self) == "fresh 1", "max-age response served from URLCache")
            let (e1, _) = try await s.data(from: URL(string: base + "/etag")!)
            let (e2, r2) = try await s.data(from: URL(string: base + "/etag")!)
            server.lock.lock(); let inm = server.lastHeaders["if-none-match"]; let etagHits = server.hits["/etag"]; server.lock.unlock()
            check(e1 == e2 && (r2 as? HTTPURLResponse)?.statusCode == 200 && inm == "\"v1\"" && etagHits == 2, "ETag revalidation: 304 -> cached body")
            var noCache = URLRequest(url: URL(string: base + "/fresh")!); noCache.cachePolicy = .reloadIgnoringLocalCacheData
            let (c3, _) = try await s.data(for: noCache)
            check(String(decoding: c3, as: UTF8.self) == "fresh 2", ".reloadIgnoringLocalCacheData skips the cache")
            check(cache.cachedResponse(for: URLRequest(url: URL(string: base + "/fresh")!)) != nil && cache.currentMemoryUsage > 0, "URLCache.cachedResponse(for:)")
            cache.removeAllCachedResponses()
            var only = URLRequest(url: URL(string: base + "/fresh")!); only.cachePolicy = .returnCacheDataDontLoad
            do { _ = try await s.data(for: only); check(false, "returnCacheDataDontLoad") }
            catch { check((error as? URLError)?.code == .resourceUnavailable, ".returnCacheDataDontLoad without a cached response fails") }
        } catch { check(false, "cache threw \(error)") }

        // MARK: delegates
        let dq = OperationQueue(); dq.maxConcurrentOperationCount = 1
        let dd = DataDelegate(queue: dq)
        let ds = URLSession(configuration: .default, delegate: dd, delegateQueue: dq)
        ds.dataTask(with: URL(string: base + "/redirect")!).resume()
        dd.done.wait()
        check(dd.completed != nil && dd.completed! == nil && (dd.response as? HTTPURLResponse)?.statusCode == 200 && (try? JSONDecoder().decode(Info.self, from: dd.received)) != nil,
              "URLSessionDataDelegate: didReceive response/data, didCompleteWithError(nil)")
        check(dd.redirects == 1 && dd.onDelegateQueue, "delegate sees the redirect; callbacks on the delegateQueue")
        ds.finishTasksAndInvalidate()
        let dl = DownloadDelegate()
        let dls = URLSession(configuration: .default, delegate: dl, delegateQueue: nil)
        dls.downloadTask(with: URL(string: base + "/big")!).resume()
        dl.done.wait()
        check(dl.finished && dl.size == 300_000 && dl.progress >= 1, "URLSessionDownloadDelegate: didWriteData + didFinishDownloadingTo (\(dl.size) bytes, \(dl.progress) progress)")
        dls.invalidateAndCancel()
        nonisolated(unsafe) var dlOK = false
        URLSession.shared.downloadTask(with: URL(string: base + "/text")!) { url, _, e in
            dlOK = e == nil && url.flatMap { FileManager.default.contents(atPath: $0.path) } == Data("hello from the mini server".utf8); sem.signal()
        }.resume()
        sem.wait()
        check(dlOK, "downloadTask(with:completionHandler:) temp file")
        do {
            let (file, _) = try await URLSession.shared.download(from: URL(string: base + "/big")!)
            check(FileManager.default.contents(atPath: file.path)?.count == 300_000, "async download(from:)")
            try? FileManager.default.removeItem(at: file)
        } catch { check(false, "download threw \(error)") }

        // MARK: bytes / lines
        do {
            let (bytes, resp) = try await URLSession.shared.bytes(from: URL(string: base + "/lines")!)
            var lines: [String] = []
            for try await line in bytes.lines { lines.append(line) }
            check((resp as? HTTPURLResponse)?.statusCode == 200 && lines == ["alpha", "beta", "gamma"], "bytes(from:).lines (\(lines))")
        } catch { check(false, "bytes threw \(error)") }

        // MARK: Combine
        nonisolated(unsafe) var pubName = "", pubDone = false
        let cancellable = URLSession.shared.dataTaskPublisher(for: URL(string: base + "/json")!)
            .map { (try? JSONDecoder().decode(Info.self, from: $0.data))?.name ?? "" }
            .sink(receiveCompletion: { if case .finished = $0 { pubDone = true }; sem.signal() }, receiveValue: { pubName = $0 })
        sem.wait()
        check(pubName == "isim" && pubDone, "dataTaskPublisher + decode + sink")
        cancellable.cancel()
        nonisolated(unsafe) var pubErr = 0
        let c2 = URLSession.shared.dataTaskPublisher(for: URL(string: "http://127.0.0.1:1/")!)
            .sink(receiveCompletion: { if case .failure(let e) = $0 { pubErr = e.code.rawValue }; sem.signal() }, receiveValue: { _ in })
        sem.wait()
        check(pubErr == NSURLErrorCannotConnectToHost, "dataTaskPublisher fails with URLError")
        c2.cancel()

        // MARK: file: and data: URLs
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "/net-test.json")
        try? Data(#"{"name":"file","version":1,"tags":[]}"#.utf8).write(to: tmp)
        do {
            let (d, r) = try await URLSession.shared.data(from: tmp)
            check((try? JSONDecoder().decode(Info.self, from: d))?.name == "file" && r.mimeType == "application/json" && !(r is HTTPURLResponse), "file: URL through URLSession")
            let (d2, r2) = try await URLSession.shared.data(from: URL(string: "data:text/plain;base64,aGVsbG8=")!)
            check(String(decoding: d2, as: UTF8.self) == "hello" && r2.mimeType == "text/plain", "data: URL")
        } catch { check(false, "file/data URL threw \(error)") }

        // MARK: NWPathMonitor
        let monitor = NWPathMonitor()
        nonisolated(unsafe) var firstPath: NWPath? = nil
        monitor.pathUpdateHandler = { p in if firstPath == nil { firstPath = p; sem.signal() } }
        monitor.start(queue: DispatchQueue(label: "path"))
        let got = sem.wait(timeout: .now() + 5) == .success
        let expected = ProcessInfo.processInfo.environment["ISIM_NETWORK"] == "offline" ? NWPath.Status.unsatisfied : .satisfied
        check(got && firstPath?.status == expected && monitor.currentPath.status == expected, "NWPathMonitor reports the host's connectivity (\(firstPath?.debugDescription ?? "none"))")
        monitor.cancel()

        // MARK: URLSessionWebSocketTask (isim's own RFC 6455 client; ws_server.py, started by test_swift_network.py)
        let env = ProcessInfo.processInfo.environment
        if let port = env["ISIM_TEST_WS_PORT"] {
            await webSocketChecks(base: "ws://127.0.0.1:\(port)", what: "ws")
        } else { check(false, "WebSocket server port (ISIM_TEST_WS_PORT; run through test_swift_network.py)") }
        if let port = env["ISIM_TEST_WSS_PORT"] {                  // TLS: a throwaway certificate for localhost (SSL_CERT_FILE)
            await webSocketChecks(base: "wss://localhost:\(port)", what: "wss")
        }

        print("network test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
