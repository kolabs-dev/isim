// Sample: networking below and around URLSession on isim — Network framework (NWListener + NWConnection TCP echo,
// UDP echo, TLS client to a local server with a self-signed certificate: default trust fails, an app verify
// block accepts it; refused connections, DNS failures, Bonjour advertising + NWBrowser + connecting to a
// service), MultipeerConnectivity between two sessions of this app, and URLSession authentication challenges
// (Basic, Digest, credential storage), server-trust challenge, task metrics, progress and resumable downloads. With
// -structured (iOS 26): NetworkListener, NetworkConnection, withNetworkConnection and NetworkBrowser over TCP, UDP,
// WebSocket, TLV and Coder stacks, and a Bonjour service found by a NetworkBrowser.
//   isim run out/apps/HelloConnections.app -server http://127.0.0.1:P -tls PORT   (samples/HelloWeb/server.py, tls_echo.py)
import UIKit
import Network
import MultipeerConnectivity
import Security

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
        let mcui = ProcessInfo.processInfo.arguments.contains("-mcui")
        window?.rootViewController = UINavigationController(rootViewController: mcui ? MCUIViewController() : ResultsViewController())
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
        if ProcessInfo.processInfo.arguments.contains("-mdns") { await mdns(); report("done", "mdns"); return }
        if ProcessInfo.processInfo.arguments.contains("-structured") {
            if #available(iOS 26.0, *) { await structured() } else { report("structured", "needs iOS 26") }
            report("done", "structured"); return
        }
        await tcpEcho()
        await reports()
        await cAPI()
        await udpEcho()
        await refused()
        await dnsFailure()
        await tlsTests()
        await bonjour()
        await multipeer()
        await multipeerIdentities()
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
    /// an establishment report (the name resolution and TCP handshake), a data transfer report, a discontiguous receive
    func reports() async {
        do {
            let l = try echoListener(.tcp)
            guard let port = l.port else { report("reports", "no port"); return }
            let c = NWConnection(host: "localhost", port: port, using: .tcp)
            let pending = c.startDataTransferReport()
            guard await c.waitReady() == .ready else { report("reports", "not ready"); return }
            _ = await c.sendAsync(Data("report me".utf8))
            let got: DispatchData? = await withCheckedContinuation { k in
                c.receiveDiscontiguous(minimumIncompleteLength: 14, maximumLength: 14) { d, _, _, _ in k.resume(returning: d) }
            }
            let est: NWConnection.EstablishmentReport? = await withCheckedContinuation { k in c.requestEstablishmentReport(queue: .global()) { k.resume(returning: $0) } }
            let transfer: NWConnection.DataTransferReport = await withCheckedContinuation { k in pending.collect(queue: .global()) { k.resume(returning: $0) } }
            let hs = est?.handshakes.map(\.definition.name).joined(separator: ",") ?? "-"
            let res = est?.resolutions.first.map { "\($0.source) \($0.endpointCount > 0 ? "ok" : "none")" } ?? "-"
            let path = transfer.aggregatePathReport
            report("reports", "\(got.map { String(decoding: Data($0), as: UTF8.self) } ?? "nil") handshakes=\(hs) resolution=\(res) "
                   + "sent=\(path.sentApplicationByteCount) received=\(path.receivedApplicationByteCount) interface=\(path.interface.type)")
            c.cancel()
        } catch { report("reports", "listener error \(error)") }
    }
    /// Network's C API from Swift (nw_*): a connection to the echo listener, a final message, the server's close
    func cAPI() async {
        do {
            let l = try echoListener(.tcp)
            guard let port = l.port else { report("c api", "no port"); return }
            let endpoint = nw_endpoint_create_host("127.0.0.1", String(port.rawValue))
            let parameters = nw_parameters_create_secure_tcp(_nw_parameters_configure_protocol_disable) { options in
                nw_tcp_options_set_no_delay(options, true)
            }
            let c = nw_connection_create(endpoint, parameters)
            nw_connection_set_queue(c, .main)
            let result: String = await withCheckedContinuation { k in
                nw_connection_set_state_changed_handler(c) { state, error in
                    if state == nw_connection_state_ready {
                        let remote = nw_connection_copy_current_path(c).flatMap { nw_path_copy_effective_remote_endpoint($0) }
                        let ok = remote.map { nw_endpoint_get_port($0) == port.rawValue } ?? false
                        nw_connection_send(c, nil, _nw_content_context_final_send, true) { _ in }
                        nw_connection_receive(c, 1, 64) { _, _, complete, e in
                            k.resume(returning: "ready remote=\(ok ? "ok" : "-") type=\(nw_endpoint_get_type(endpoint) == nw_endpoint_type_address) closed=\(complete) error=\(e == nil ? "none" : "\(nw_error_get_error_code(e!))")")
                            nw_connection_cancel(c)
                        }
                    } else if state == nw_connection_state_failed || state == nw_connection_state_waiting {
                        k.resume(returning: "state \(state.rawValue) error \(error.map { nw_error_get_error_code($0) } ?? 0)")
                        nw_connection_cancel(c)
                    }
                }
                nw_connection_start(c)
            }
            report("c api", result)
        } catch { report("c api", "listener error \(error)") }
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

    /// -mdns (with ISIM_MDNS=1): Bonjour on the network — another machine (samples/HelloConnections/mdns_peer.py)
    /// finds this app's service by multicast DNS and talks to it; the app finds the peer's service and talks to it
    func mdns() async {
        do {
            let l = try NWListener(using: .tcp)
            l.service = NWListener.Service(name: "isim App", type: "_isimapp._tcp", txtRecord: NWTXTRecord(["from": "isim"]))
            l.serviceRegistrationUpdateHandler = { change in if case .add(let ep) = change { log("mdns: registered \(ep)") } }
            l.newConnectionHandler = { c in
                c.start(queue: .global())
                c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { d, _, _, _ in
                    let text = d.map { String(decoding: $0, as: UTF8.self) } ?? ""
                    log("mdns: app service got \(text)")
                    c.send(content: Data("isim:\(text)".utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in })
                }
            }
            l.start(queue: .global())
            listeners.append(l)
            let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_isimpy._tcp", domain: nil), using: .tcp)
            let found: NWBrowser.Result? = await withCheckedContinuation { k in
                let once = Once()
                b.browseResultsChangedHandler = { results, _ in if let r = results.first { once.run { k.resume(returning: r) } } }
                b.start(queue: .global())
                DispatchQueue.global().asyncAfter(deadline: .now() + 15) { once.run { k.resume(returning: nil) } }
            }
            b.cancel()
            guard let found else { report("mdns", "no peer found"); return }
            var txt = "-"; if case .bonjour(let t) = found.metadata { txt = t["from"] ?? "-" }
            let c = NWConnection(to: found.endpoint, using: .tcp)
            _ = await c.waitReady()
            _ = await c.sendAsync(Data("hello from isim".utf8))
            let (d, _, _) = await c.receiveAsync(22)
            report("mdns", "found \(found.endpoint) from=\(txt) reply=\(d.map { String(decoding: $0, as: UTF8.self) } ?? "nil")")
            c.cancel()
        } catch { report("mdns", "\(error)") }
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
            if s == "pong" {                                      // then a byte stream Alice -> Bob
                guard let out = try? session.startStream(withName: "chunks", toPeer: peerID) else { self.finishMC("no stream"); return }
                out.open()
                for part in ["streamed ", "bytes"] { _ = Array(part.utf8).withUnsafeBufferPointer { out.write($0.baseAddress!, maxLength: $0.count) } }
                out.close()
            }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        let me = session.myPeerID.displayName
        Thread.detachNewThread {
            stream.open()
            var all = [UInt8](), buf = [UInt8](repeating: 0, count: 64)
            while true { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; all += buf[0..<n] }
            stream.close()
            DispatchQueue.main.async {
                self.mcEvents.append("\(me) stream \(streamName) from \(peerID.displayName): \(String(decoding: all, as: UTF8.self))")
                self.finishMC("ok")
            }
        }
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    /// sessions with security identities (-p12 FILE, password "isim"): Carol and Dave exchange and accept each
    /// other's certificates; Dave refuses Eve, who has none
    let identities = IdentityPeers()
    func multipeerIdentities() async {
        guard let path = arg("-p12"), let p12 = FileManager.default.contents(atPath: path) else { report("multipeer identities", "skipped (no -p12)"); return }
        var items: CFArray?
        _ = SecPKCS12Import(p12 as CFData, [kSecImportExportPassphrase as String: "isim"] as CFDictionary, &items)
        guard let item = (items as? [[String: Any]])?.first, let id = item[kSecImportItemIdentity as String] as? SecIdentity else {
            report("multipeer identities", "no identity in the p12"); return
        }
        report("multipeer identities", await identities.run(id))
    }

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

final class IdentityPeers: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, @unchecked Sendable {
    let carol = MCPeerID(displayName: "Carol"), dave = MCPeerID(displayName: "Dave"), eve = MCPeerID(displayName: "Eve")
    var carolSession: MCSession!, daveSession: MCSession!, eveSession: MCSession!
    var advertiser: MCNearbyServiceAdvertiser?, browsers: [MCNearbyServiceBrowser] = []
    var events: [String] = [], done: CheckedContinuation<String, Never>?
    let lock = NSLock()
    func note(_ e: String) {
        lock.lock(); events.append(e); let all = events, k = done
        let finished = all.contains("Carol connected to Dave") && all.contains("Eve not connected to Dave")
        if finished { done = nil }
        lock.unlock()
        if finished { k?.resume(returning: all.sorted().joined(separator: "; ")) }
    }
    func run(_ id: SecIdentity) async -> String {
        carolSession = MCSession(peer: carol, securityIdentity: [id], encryptionPreference: .required)
        daveSession = MCSession(peer: dave, securityIdentity: [id], encryptionPreference: .required)
        eveSession = MCSession(peer: eve, securityIdentity: nil, encryptionPreference: .required)
        for s in [carolSession!, daveSession!, eveSession!] { s.delegate = self }
        advertiser = MCNearbyServiceAdvertiser(peer: dave, discoveryInfo: nil, serviceType: "isim-secure")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        return await withCheckedContinuation { k in
            lock.lock(); done = k; lock.unlock()
            DispatchQueue.main.async {
                for p in [self.carol, self.eve] {
                    let b = MCNearbyServiceBrowser(peer: p, serviceType: "isim-secure")
                    b.delegate = self; b.startBrowsingForPeers(); self.browsers.append(b)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self else { return }
                self.lock.lock(); let k = self.done; self.done = nil; let all = self.events; self.lock.unlock()
                k?.resume(returning: all.sorted().joined(separator: "; ") + " (timeout)")
            }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: browser.myPeerID == carol ? carolSession : eveSession, withContext: nil, timeout: 5)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, daveSession) }
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        let cn = (certificate?.first as? SecCertificate).flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "none"
        note("\(session.myPeerID.displayName) got certificate \(cn) from \(peerID.displayName)")
        certificateHandler(cn != "none")                          // only peers with a certificate
    }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected, session === carolSession { note("Carol connected to Dave") }
        if state == .notConnected, session === eveSession { note("Eve not connected to Dave") }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

/// -mcui: the system UI of MultipeerConnectivity in one app — Bob advertises with MCAdvertiserAssistant (its
/// invitation alert), Alice picks him in MCBrowserViewController
final class MCUIViewController: UIViewController, MCBrowserViewControllerDelegate, MCAdvertiserAssistantDelegate, MCSessionDelegate {
    let alice = MCSession(peer: MCPeerID(displayName: "Alice")), bob = MCSession(peer: MCPeerID(displayName: "Bob"))
    var assistant: MCAdvertiserAssistant?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Multipeer"
        view.backgroundColor = .systemBackground
        alice.delegate = self; bob.delegate = self
        assistant = MCAdvertiserAssistant(serviceType: "isim-ui", discoveryInfo: nil, session: bob)
        assistant?.delegate = self
        assistant?.start()
        let b = UIButton(type: .system, primaryAction: UIAction(title: "Browse for Peers") { [weak self] _ in
            guard let self else { return }
            let vc = MCBrowserViewController(serviceType: "isim-ui", session: self.alice)
            vc.delegate = self
            self.present(vc, animated: true)
        })
        b.accessibilityIdentifier = "mc-browse"
        b.frame = CGRect(x: 40, y: 200, width: view.bounds.width - 80, height: 44)
        view.addSubview(b)
    }
    func browserViewControllerDidFinish(_ vc: MCBrowserViewController) {
        log("mcui: browser finished peers=\(alice.connectedPeers.map(\.displayName).joined(separator: ","))")
        vc.dismiss(animated: true)
    }
    func browserViewControllerWasCancelled(_ vc: MCBrowserViewController) { log("mcui: browser cancelled"); vc.dismiss(animated: true) }
    func advertiserAssistantWillPresentInvitation(_ a: MCAdvertiserAssistant) { log("mcui: assistant will present invitation") }
    func advertiserAssistantDidDismissInvitation(_ a: MCAdvertiserAssistant) { log("mcui: assistant dismissed invitation") }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        log("mcui: \(session.myPeerID.displayName) \(state) \(peerID.displayName)")
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - -structured: the iOS 26 Network API

final class StateLog: @unchecked Sendable {
    let lock = NSLock(); var items: [String] = []
    func add(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var joined: String { lock.lock(); defer { lock.unlock() }; return items.joined(separator: ",") }
}

/// a game's messages, sent with Coder
struct GameMessage: Codable, Sendable, Equatable {
    var move: String
    var score: Int
}

@available(iOS 26.0, *)
extension Runner {
    /// starts a listener, returns its port once it is ready (the listener runs until the task is cancelled)
    func serve<P: NetworkProtocolOptions>(_ listener: NetworkListener<P>, _ handler: @escaping @Sendable (NetworkConnection<P>) async throws -> Void) async -> (UInt16, Task<Void, Never>) {
        let (ready, sink) = AsyncStream<UInt16>.makeStream()
        listener.onStateUpdate { l, state in
            switch state {
            case .ready: sink.yield(l.port?.rawValue ?? 0); sink.finish()
            case .failed, .cancelled: sink.finish()
            default: break
            }
        }
        let task = Task { do { try await listener.run(handler) } catch {} }
        var port: UInt16 = 0
        for await p in ready { port = p }
        return (port, task)
    }
    func endpoint(_ port: UInt16) -> NWEndpoint { .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!) }

    func structured() async {
        // a byte stream: TCP echo, with the connection's state updates
        do {
            let (port, task) = await serve(try NetworkListener { TCP().noDelay(true) }) { c in
                let (data, _) = try await c.receive(atLeast: 1, atMost: 100)
                try await c.send(Data("echo:".utf8) + data)
            }
            let states = StateLog()
            let c = NetworkConnection(to: endpoint(port)) { TCP() }
                .onStateUpdate { _, s in states.add("\(s)") }
            try await c.send(Data("hello".utf8))
            let (reply, _) = try await c.receive(exactly: 10)
            report("structured tcp", "\(String(decoding: reply, as: UTF8.self)) state=\(c.state == .ready ? "ready" : "-") states=\(states.joined) remote=\(c.remoteEndpoint != nil)")
            task.cancel()
        } catch { report("structured tcp", "error \(error)") }

        // integers in network byte order, and the channel's data transfer and establishment reports
        do {
            let (port, task) = await serve(try NetworkListener { TCP() }) { c in
                let (n, _) = try await c.receive(as: UInt32.self)
                try await c.send(n + 1)
            }
            let c = NetworkConnection(to: endpoint(port)) { TCP() }
            try await c.send(UInt32(41_999))
            let (n, _) = try await c.receive(as: UInt32.self)
            let transfer = try await c.dataTransferReport().aggregatePathReport
            let est = try await c.establishmentReport()
            report("structured integers", "\(n) sent=\(transfer.sentApplicationByteCount) received=\(transfer.receivedApplicationByteCount) handshakes=\(est.handshakes.count)")
            task.cancel()
        } catch { report("structured integers", "error \(error)") }

        // TLV: typed messages; the server answers type + 1 with the bytes reversed
        do {
            let (port, task) = await serve(try NetworkListener { TLV { TCP() } }) { c in
                for try await (data, metadata) in c.messages {
                    try await c.send(Data(data.reversed()), type: metadata.type + 1)
                }
            }
            let reply = try await withNetworkConnection(to: endpoint(port), using: { TLV { TCP() } }) { c in
                try await c.send(Data("ping".utf8), type: 7)
                return try await c.receive()
            }
            report("structured tlv", "type=\(reply.metadata.type) \(String(decoding: reply.content, as: UTF8.self))")
            task.cancel()
        } catch { report("structured tlv", "error \(error)") }

        // Coder: Codable messages as JSON
        do {
            let (port, task) = await serve(try NetworkListener { Coder(GameMessage.self, using: .json) { TCP() } }) { c in
                for try await (message, _) in c.messages { try await c.send(GameMessage(move: message.move.uppercased(), score: message.score * 2)) }
            }
            let c = NetworkConnection(to: endpoint(port)) { Coder(GameMessage.self, using: .json) { TCP() } }
            try await c.send(GameMessage(move: "e4", score: 21))
            let first = try await c.receive().content
            try await c.send(GameMessage(move: "d4", score: 5))
            let second = try await c.receive().content
            report("structured coder", "\(first.move) \(first.score), \(second.move) \(second.score)")
            task.cancel()
        } catch { report("structured coder", "error \(error)") }

        // UDP datagrams
        do {
            let (port, task) = await serve(try NetworkListener { UDP() }) { c in
                let (d, _) = try await c.receive()
                try await c.send(Data("echo:".utf8) + d)
            }
            let c = NetworkConnection(to: endpoint(port)) { UDP() }
            try await c.send(Data("datagram".utf8))
            let (reply, _) = try await c.receive()
            report("structured udp", String(decoding: reply, as: UTF8.self))
            task.cancel()
        } catch { report("structured udp", "error \(error)") }

        // WebSocket text messages
        do {
            let (port, task) = await serve(try NetworkListener { WebSocket { TCP() } }) { c in
                for try await (d, metadata) in c.messages where metadata.opcode == .text {
                    try await c.send("echo:" + String(decoding: d, as: UTF8.self))
                }
            }
            let c = NetworkConnection(to: endpoint(port)) { WebSocket { TCP() } }
            try await c.send("over websocket")
            let (reply, metadata) = try await c.receive()
            report("structured websocket", "\(String(decoding: reply, as: UTF8.self)) opcode=\(metadata.opcode == .text ? "text" : "other")")
            task.cancel()
        } catch { report("structured websocket", "error \(error)") }

        // Bonjour: a listener advertises a service, a NetworkBrowser finds it, a connection goes to what it found
        do {
            let listener = try NetworkListener(for: .bonjour(name: "Chess Board", type: "_isimchess._tcp", txtRecord: NWTXTRecord(["variant": "blitz"]))) {
                Coder(GameMessage.self, using: .json) { TCP() }
            }
            let (_, task) = await serve(listener) { c in
                for try await (message, _) in c.messages { try await c.send(GameMessage(move: "reply to " + message.move, score: 1)) }
            }
            let found = try await NetworkBrowser(for: .bonjour("_isimchess._tcp", includeTxtRecord: true)).run { endpoints -> NetworkBrowser<Bonjour>.RunResult<Bonjour.Endpoint> in
                endpoints.first.map { .finish($0) } ?? .continue
            }
            let c = NetworkConnection(to: found) { Coder(GameMessage.self, using: .json) { TCP() } }
            try await c.send(GameMessage(move: "Nf3", score: 0))
            let reply = try await c.receive().content
            report("structured bonjour", "found \(found.name) \(found.type) variant=\(found.txtRecord["variant"] ?? "-") reply=\(reply.move) service=\(listener.service?.name ?? "-")")
            task.cancel()
        } catch { report("structured bonjour", "error \(error)") }

        // a connection refused: it waits (.waiting(ECONNREFUSED)), as NWConnection does, until the task is cancelled
        let seen = StateLog()
        let refused = NetworkConnection(to: endpoint(1)) { TCP() }
            .onStateUpdate { _, s in if case .waiting(let e) = s { seen.add("\(e)") } }
        let send = Task { do { try await refused.send(Data("x".utf8)); return "sent" } catch { return error is CancellationError ? "cancelled" : "\(error)" } }
        for _ in 0..<100 where seen.joined.isEmpty { try? await Task.sleep(nanoseconds: 50_000_000) }
        send.cancel()
        report("structured refused", "waiting \(seen.joined.isEmpty ? "-" : "ECONNREFUSED") send \(await send.value) state \(refused.state == .waiting(.posix(.ECONNREFUSED)) ? "waiting" : "\(refused.state)")")
    }
}
