// Sample: networking below and around URLSession on isim — Network framework (NWListener + NWConnection TCP echo,
// UDP echo, TLS client to a local server with a self-signed certificate: default trust fails, an app verify
// block accepts it; refused connections, DNS failures, Bonjour advertising + NWBrowser + connecting to a
// service), MultipeerConnectivity between two sessions of this app, and URLSession authentication challenges
// (Basic, Digest, credential storage), server-trust challenge, task metrics, progress and resumable downloads.
//   isim run out/apps/HelloConnections.app -server http://127.0.0.1:P -tls PORT   (samples/HelloWeb/server.py, tls_echo.py)
import UIKit
import Network
import MultipeerConnectivity

func log(_ s: String) { FileHandle.standardError.write(Data(("HelloConnections: " + s + "\n").utf8)) }   // unbuffered

func arg(_ name: String) -> String? {
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: name), i + 1 < a.count { return a[i + 1] }
    return nil
}
let server = arg("-server") ?? "http://127.0.0.1:8765"
let tlsPort = UInt16(arg("-tls") ?? "0") ?? 0

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ResultsViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class ResultsViewController: UITableViewController {
    var rows: [(String, String)] = []
    let runner = Runner()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Connections"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        runner.report = { [weak self] name, result in
            DispatchQueue.main.async {
                log("\(name): \(result)")
                self?.rows.append((name, result)); self?.tableView.reloadData()
            }
        }
        Task { await runner.runAll() }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        let cfg = c.defaultContentConfiguration()
        cfg.text = rows[indexPath.row].0; cfg.secondaryText = rows[indexPath.row].1
        c.contentConfiguration = cfg
        return c
    }
}

/// runs NWConnection callbacks as async calls
extension NWConnection {
    func waitReady(timeout: Double = 5) async -> NWConnection.State {
        await withCheckedContinuation { (k: CheckedContinuation<NWConnection.State, Never>) in
            let once = Once()
            stateUpdateHandler = { s in
                switch s {
                case .ready, .failed, .waiting, .cancelled: once.run { k.resume(returning: s) }
                default: break
                }
            }
            start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { once.run { k.resume(returning: .setup) } }
        }
    }
    func sendAsync(_ d: Data) async -> NWError? {
        await withCheckedContinuation { k in send(content: d, completion: .contentProcessed { k.resume(returning: $0) }) }
    }
    func receiveAsync(_ n: Int) async -> (Data?, Bool, NWError?) {
        await withCheckedContinuation { k in receive(minimumIncompleteLength: n, maximumLength: n) { d, _, c, e in k.resume(returning: (d, c, e)) } }
    }
}
final class Once: @unchecked Sendable {
    let lock = NSLock(); var done = false
    func run(_ f: () -> Void) { lock.lock(); defer { lock.unlock() }; if !done { done = true; f() } }
}

final class Runner: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, @unchecked Sendable {
    var report: (String, String) -> Void = { _, _ in }
    var listeners: [NWListener] = []

    func runAll() async {
        await tcpEcho()
        await udpEcho()
        await refused()
        await dnsFailure()
        await tlsTests()
        await bonjour()
        await multipeer()
        await basicAuth()
        await digestAuth()
        await serverTrust()
        await metricsAndProgress()
        await resumableDownload()
        report("done", "all scenarios ran")
    }

    // MARK: Network framework
    func echoListener(_ params: NWParameters) throws -> NWListener {
        let l = try NWListener(using: params)
        l.newConnectionHandler = { c in
            c.start(queue: .global())
            @Sendable func pump() {
                c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { d, _, done, err in
                    if let d, !d.isEmpty { c.send(content: Data("echo:".utf8) + d, completion: .contentProcessed { _ in }) }
                    if done || err != nil { c.cancel() } else { pump() }
                }
            }
            if params.debugDescription == "udp" {
                c.receiveMessage { d, _, _, _ in if let d { c.send(content: Data("echo:".utf8) + d, completion: .idempotent) } }
            } else { pump() }
        }
        let ready = DispatchSemaphore(value: 0)
        l.stateUpdateHandler = { if $0 == .ready { ready.signal() } }
        l.start(queue: .global())
        _ = ready.wait(timeout: .now() + 3)
        listeners.append(l)
        return l
    }
    func tcpEcho() async {
        do {
            let l = try echoListener(.tcp)
            guard let port = l.port else { report("tcp echo", "no port"); return }
            let c = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
            let st = await c.waitReady()
            guard st == .ready else { report("tcp echo", "state \(st)"); return }
            _ = await c.sendAsync(Data("hello tcp".utf8))
            let (d, _, e) = await c.receiveAsync(14)
            let remote = c.currentPath?.remoteEndpoint.map { "\($0)" } ?? "-"
            report("tcp echo", "\(d.map { String(decoding: $0, as: UTF8.self) } ?? "nil") error=\(e.map { "\($0)" } ?? "none") remote=\(remote == "127.0.0.1:\(port.rawValue)" ? "ok" : remote)")
            c.cancel()
        } catch { report("tcp echo", "listener error \(error)") }
    }
    func udpEcho() async {
        do {
            let l = try echoListener(.udp)
            guard let port = l.port else { report("udp echo", "no port"); return }
            let c = NWConnection(host: "127.0.0.1", port: port, using: .udp)
            _ = await c.waitReady()
            _ = await c.sendAsync(Data("datagram".utf8))
            let msg: Data? = await withCheckedContinuation { k in c.receiveMessage { d, _, _, _ in k.resume(returning: d) } }
            report("udp echo", msg.map { String(decoding: $0, as: UTF8.self) } ?? "nil")
            c.cancel()
        } catch { report("udp echo", "listener error \(error)") }
    }
    func refused() async {
        let c = NWConnection(host: "127.0.0.1", port: 1, using: .tcp)
        let st = await c.waitReady()
        if case .waiting(let e) = st { report("refused", "waiting \(e == .posix(.ECONNREFUSED) ? "ECONNREFUSED" : "\(e)")") } else { report("refused", "\(st)") }
        c.cancel()
    }
    func dnsFailure() async {
        let c = NWConnection(host: "no-such-host.invalid", port: 80, using: .tcp)
        let st = await c.waitReady()
        if case .waiting(.dns(let code)) = st { report("dns", "waiting dns \(code)") } else { report("dns", "\(st)") }
        c.cancel()
    }
    func tlsTests() async {
        guard tlsPort > 0 else { report("tls", "no TLS server"); return }
        // default trust: a self-signed certificate is rejected
        let strict = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: tlsPort)!, using: .tls)
        let st = await strict.waitReady()
        if case .failed(let e) = st { report("tls default trust", "failed \(e)") } else { report("tls default trust", "\(st)") }
        strict.cancel()
        // an app verify block accepts it
        let opts = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(opts.securityProtocolOptions, { _, trust, complete in complete(true) }, .global())
        sec_protocol_options_add_tls_application_protocol(opts.securityProtocolOptions, "isim-echo")
        let c = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: tlsPort)!, using: NWParameters(tls: opts))
        let st2 = await c.waitReady()
        guard st2 == .ready else { report("tls custom trust", "\(st2)"); return }
        let meta = c.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
        let version = meta.map { sec_protocol_metadata_get_negotiated_tls_protocol_version($0.securityProtocolMetadata) }
        let alpn = meta.flatMap { sec_protocol_metadata_get_negotiated_protocol($0.securityProtocolMetadata) }.map { String(cString: $0) } ?? "-"
        _ = await c.sendAsync(Data("secret".utf8))
        let (d, _, _) = await c.receiveAsync(11)
        report("tls custom trust", "\(d.map { String(decoding: $0, as: UTF8.self) } ?? "nil") version=\(version == .TLSv13 ? "TLSv1.3" : "\(String(describing: version))") alpn=\(alpn)")
        c.cancel()
    }
    func bonjour() async {
        do {
            let l = try echoListener(.tcp)
            l.service = NWListener.Service(name: "Echo Service", type: "_isimecho._tcp", txtRecord: NWTXTRecord(["v": "1"]))
            let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_isimecho._tcp", domain: nil), using: .tcp)
            let found: NWBrowser.Result? = await withCheckedContinuation { k in
                let once = Once()
                b.browseResultsChangedHandler = { results, _ in
                    if let r = results.first(where: { if case .service(let n, _, _, _) = $0.endpoint { return n == "Echo Service" }; return false }) { once.run { k.resume(returning: r) } }
                }
                b.start(queue: .global())
                DispatchQueue.global().asyncAfter(deadline: .now() + 4) { once.run { k.resume(returning: nil) } }
            }
            b.cancel()
            guard let found else { report("bonjour", "not found"); return }
            var txt = "-"; if case .bonjour(let t) = found.metadata { txt = t["v"] ?? "-" }
            let c = NWConnection(to: found.endpoint, using: .tcp)
            _ = await c.waitReady()
            _ = await c.sendAsync(Data("via bonjour".utf8))
            let (d, _, _) = await c.receiveAsync(16)
            report("bonjour", "found \(found.endpoint) txt v=\(txt) reply=\(d.map { String(decoding: $0, as: UTF8.self) } ?? "nil")")
            c.cancel(); l.cancel()
        } catch { report("bonjour", "\(error)") }
    }

    // MARK: MultipeerConnectivity
    let alice = MCPeerID(displayName: "Alice"), bob = MCPeerID(displayName: "Bob")
    lazy var aliceSession = MCSession(peer: alice, securityIdentity: nil, encryptionPreference: .required)
    lazy var bobSession = MCSession(peer: bob, securityIdentity: nil, encryptionPreference: .required)
    var advertiser: MCNearbyServiceAdvertiser?
    var mcBrowser: MCNearbyServiceBrowser?
    var mcDone: CheckedContinuation<Void, Never>?
    var mcEvents: [String] = []
    func multipeer() async {
        aliceSession.delegate = self; bobSession.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: bob, discoveryInfo: ["room": "lobby"], serviceType: "isim-chat")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        mcBrowser = MCNearbyServiceBrowser(peer: alice, serviceType: "isim-chat")
        mcBrowser?.delegate = self
        await withCheckedContinuation { k in
            mcDone = k
            DispatchQueue.main.async { self.mcBrowser?.startBrowsingForPeers() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 6) { [weak self] in self?.finishMC("timeout") }
        }
    }
    func finishMC(_ how: String) {
        DispatchQueue.main.async {
            guard let k = self.mcDone else { return }
            self.mcDone = nil
            self.report("multipeer", self.mcEvents.joined(separator: "; ") + (how == "ok" ? "" : " (\(how))"))
            self.aliceSession.disconnect(); self.advertiser?.stopAdvertisingPeer(); self.mcBrowser?.stopBrowsingForPeers()
            k.resume()
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        mcEvents.append("found \(peerID.displayName) room=\(info?["room"] ?? "-")")
        browser.invitePeer(peerID, to: aliceSession, withContext: Data("hi".utf8), timeout: 5)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        mcEvents.append("invitation from \(peerID.displayName) context=\(context.map { String(decoding: $0, as: UTF8.self) } ?? "-")")
        invitationHandler(true, bobSession)
    }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            if state == .connected {
                self.mcEvents.append("\(session.myPeerID.displayName) connected to \(peerID.displayName)")
                if session === self.aliceSession { try? session.send(Data("ping".utf8), toPeers: [peerID], with: .reliable) }
            }
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let s = String(decoding: data, as: UTF8.self)
        DispatchQueue.main.async {
            self.mcEvents.append("\(session.myPeerID.displayName) got \(s) from \(peerID.displayName)")
            if s == "ping" { try? session.send(Data("pong".utf8), toPeers: [peerID], with: .reliable) }
            if s == "pong" { self.finishMC("ok") }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: URLSession authentication
    var credentialAnswer: URLCredential?
    var challenges: [String] = []
    var trustDecision: URLSession.AuthChallengeDisposition = .performDefaultHandling
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let ps = challenge.protectionSpace
        let method = ps.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ? "basic" : ps.authenticationMethod == NSURLAuthenticationMethodHTTPDigest ? "digest" : ps.authenticationMethod
        challenges.append("\(method) realm=\(ps.realm ?? "-") failures=\(challenge.previousFailureCount)")
        if challenge.previousFailureCount > 0 { completionHandler(.cancelAuthenticationChallenge, nil); return }
        completionHandler(credentialAnswer == nil ? .performDefaultHandling : .useCredential, credentialAnswer)
    }
    func get(_ path: String, delegate: URLSessionDelegate? = nil, config: URLSessionConfiguration = .ephemeral) async -> (Int, String, Error?) {
        let s = URLSession(configuration: config, delegate: delegate ?? self, delegateQueue: nil)
        defer { s.finishTasksAndInvalidate() }
        do {
            let (d, r) = try await s.data(from: URL(string: server + path)!)
            return ((r as? HTTPURLResponse)?.statusCode ?? 0, String(decoding: d, as: UTF8.self), nil)
        } catch { return (0, "", error) }
    }
    func basicAuth() async {
        challenges = []
        credentialAnswer = URLCredential(user: "ada", password: "lovelace", persistence: .forSession)
        let (st, body, _) = await get("/basic")
        credentialAnswer = URLCredential(user: "ada", password: "wrong", persistence: .none)
        let (_, _, err) = await get("/basic")
        report("basic auth", "\(st) \(body) challenges=[\(challenges.joined(separator: ", "))] wrong=\((err as? URLError)?.code == .cancelled ? "cancelled" : "\(String(describing: err))")")
        // the credential storage's default credential answers without asking
        let cfg = URLSessionConfiguration.ephemeral
        let storage = URLCredentialStorage()
        let url = URL(string: server)!
        storage.setDefaultCredential(URLCredential(user: "ada", password: "lovelace", persistence: .forSession),
                                     for: URLProtectionSpace(host: url.host!, port: url.port!, protocol: "http", realm: "isim", authenticationMethod: NSURLAuthenticationMethodHTTPBasic))
        cfg.urlCredentialStorage = storage
        challenges = []; credentialAnswer = nil
        let (st2, body2, _) = await get("/basic", config: cfg)
        report("credential storage", "\(st2) \(body2) challenges=\(challenges.count)")
        // no delegate and no credential: the 401 response is the result
        let s = URLSession(configuration: .ephemeral)
        let r = try? await s.data(from: URL(string: server + "/basic")!)
        report("no credential", "status \((r?.1 as? HTTPURLResponse)?.statusCode ?? -1)")
    }
    func digestAuth() async {
        challenges = []
        credentialAnswer = URLCredential(user: "ada", password: "lovelace", persistence: .none)
        let (st, body, _) = await get("/digest")
        report("digest auth", "\(st) \(body) challenges=[\(challenges.joined(separator: ", "))]")
    }
    // session-wide server trust: the delegate is asked before an HTTPS request
    final class TrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
        var seen: [String] = []
        let answer: URLSession.AuthChallengeDisposition
        init(_ a: URLSession.AuthChallengeDisposition) { answer = a }
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            seen.append("\(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust ? "serverTrust" : "other") \(challenge.protectionSpace.host)")
            if answer == .useCredential, let t = challenge.protectionSpace.serverTrust { return (.useCredential, URLCredential(trust: t)) }
            return (answer, nil)
        }
    }
    func serverTrust() async {
        guard tlsPort > 0 else { return }
        // the TLS echo server speaks HTTP/1.0 too: GET /hello
        let url = URL(string: "https://localhost:\(tlsPort)/hello")!
        let strictD = TrustDelegate(.performDefaultHandling)
        let s1 = URLSession(configuration: .ephemeral, delegate: strictD, delegateQueue: nil)
        let e1: Error? = await { do { _ = try await s1.data(from: url); return nil } catch { return error } }()
        let trustD = TrustDelegate(.useCredential)
        let s2 = URLSession(configuration: .ephemeral, delegate: trustD, delegateQueue: nil)
        let r2 = try? await s2.data(from: url)
        let cancelD = TrustDelegate(.cancelAuthenticationChallenge)
        let s3 = URLSession(configuration: .ephemeral, delegate: cancelD, delegateQueue: nil)
        let e3: Error? = await { do { _ = try await s3.data(from: url); return nil } catch { return error } }()
        report("server trust", "default=\((e1 as? URLError)?.code.rawValue ?? 0) trusted=\(r2.map { String(decoding: $0.0, as: UTF8.self) } ?? "nil") cancel=\((e3 as? URLError)?.code.rawValue ?? 0) asked=\(strictD.seen.first ?? "-")")
    }

    // MARK: metrics, progress, resume
    var metrics: URLSessionTaskMetrics?
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) { self.metrics = metrics }
    var lastProgress = 0.0
    func metricsAndProgress() async {
        metrics = nil
        let s = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        let task = s.dataTask(with: URL(string: server + "/redirect")!)
        let obs = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in self?.lastProgress = p.fractionCompleted }
        await withCheckedContinuation { k in
            completion = { k.resume() }
            awaited = task
            task.resume()
        }
        obs.invalidate()
        if let m = metrics {
            let t = m.transactionMetrics
            let last = t.last
            report("metrics", "transactions=\(t.count) redirects=\(m.redirectCount) protocol=\(last?.networkProtocolName ?? "-") remote=\(last?.remoteAddress ?? "-") fetch=\(last?.resourceFetchType == .networkLoad) ordered=\(last?.responseStartDate.map { $0 >= (last?.fetchStartDate ?? $0) } ?? false) progress=\(task.progress.completedUnitCount)/\(task.progress.totalUnitCount) fraction=\(task.progress.fractionCompleted)")
        } else { report("metrics", "none") }
        s.finishTasksAndInvalidate()
    }
    var completion: (() -> Void)?
    var awaited: URLSessionTask?
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === awaited else { return }      /* e.g. the cancelled first download reports late */
        if task is URLSessionDownloadTask { downloadError = error }
        let c = completion; completion = nil; c?()
    }
    var downloadError: Error?
    var resumedAt: Int64 = -1
    var downloaded: URL?
    var downloadedSize = 0
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadedSize = (try? Data(contentsOf: location))?.count ?? -1
        let ok = (try? Data(contentsOf: location)).map { d in d.enumerated().allSatisfy { $0.element == UInt8(($0.offset * 7) & 255) } } ?? false
        downloaded = ok ? location : nil
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) { resumedAt = fileOffset }
    func resumableDownload() async {
        let s = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        let total = 800_000
        let t = s.downloadTask(with: URL(string: server + "/slowbytes/\(total)")!)
        t.resume()
        try? await Task.sleep(nanoseconds: 600_000_000)
        let rd: Data? = await withCheckedContinuation { k in t.cancel { k.resume(returning: $0) } }
        let partial = t.countOfBytesReceived
        guard let rd else { report("resume", "no resume data after \(partial) bytes"); return }
        let t2 = s.downloadTask(withResumeData: rd)
        await withCheckedContinuation { k in completion = { k.resume() }; awaited = t2; t2.resume() }
        report("resume", "partial=\(partial > 0 && partial < Int64(total)) resumedAt=\(resumedAt == partial) size=\(downloadedSize) intact=\(downloaded != nil) error=\(downloadError.map { "\($0)" } ?? "none")")
        s.finishTasksAndInvalidate()
    }
}
