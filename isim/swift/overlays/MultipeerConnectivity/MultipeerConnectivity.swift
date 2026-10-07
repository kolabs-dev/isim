// isim MultipeerConnectivity: peers, sessions, advertising, browsing and invitations between apps on the same
// isim device (or within one app), over loopback TCP.
//
// Adapted: there is no Wi-Fi/Bluetooth peer-to-peer radio. Advertisers register in isim's local service registry
// (the Network framework's Bonjour stand-in, $ISIM_DATA/Library/isim/Bonjour, type "_<serviceType>._tcp"), browsers
// find them there, and invited peers talk over a local TCP connection: data (reliable and unreliable alike),
// resources (files) and peer state changes work; byte streams (startStream) and security identities do not.
// MCBrowserViewController shows the nearby peers in an iOS-style list.
@_exported import Foundation
import UIKit
import Network

public let kMCSessionMinimumNumberOfPeers = 2
public let kMCSessionMaximumNumberOfPeers = 8

open class MCPeerID: NSObject, NSCopying, @unchecked Sendable {
    public let displayName: String
    let _id: String
    public init(displayName myDisplayName: String) {
        precondition(!myDisplayName.isEmpty && myDisplayName.utf8.count <= 63, "Invalid displayName passed to MCPeerID")
        displayName = myDisplayName; _id = UUID().uuidString
        super.init()
    }
    init(displayName: String, id: String) { self.displayName = displayName; _id = id; super.init() }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? MCPeerID)?._id == _id }
    open override var hash: Int { _id.hashValue }
    open override var description: String { "<MCPeerID: \(displayName)>" }
}

public enum MCSessionState: Int, Sendable, CustomStringConvertible {
    case notConnected = 0, connecting, connected
    public var description: String { ["notConnected", "connecting", "connected"][rawValue] }
}
public enum MCSessionSendDataMode: Int, Sendable { case reliable = 0, unreliable }
public enum MCEncryptionPreference: Int, Sendable { case optional = 0, required, none }

public let MCErrorDomain = "MCErrorDomain"
public struct MCError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknown = 0, notConnected, invalidParameter, unsupported, timedOut, cancelled, unavailable }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { MCErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: "\(code)"] }
}

public protocol MCSessionDelegate: AnyObject {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState)
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID)
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID)
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress)
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?)
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void)
}
extension MCSessionDelegate {
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) { certificateHandler(true) }
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

/// one framed TCP link to a remote peer: [4-byte length][1-byte kind][payload]
final class _MCLink: @unchecked Sendable {
    enum Kind: UInt8 { case hello = 1, invite = 2, accept = 3, decline = 4, data = 5, resource = 6, bye = 7 }
    let conn: NWConnection
    let queue = DispatchQueue(label: "isim.MCLink")
    var onFrame: ((Kind, Data) -> Void)?
    var onClose: (() -> Void)?
    var closed = false
    init(_ c: NWConnection) { conn = c }
    func start() { conn.start(queue: queue); readFrame() }
    func send(_ k: Kind, _ d: Data, done: ((Error?) -> Void)? = nil) {
        var hdr = Data(count: 5)
        let n = UInt32(d.count).bigEndian
        withUnsafeBytes(of: n) { hdr.replaceSubrange(0..<4, with: $0) }
        hdr[4] = k.rawValue
        conn.send(content: hdr + d, completion: .contentProcessed { e in done?(e) })
    }
    func readFrame() {
        conn.receive(minimumIncompleteLength: 5, maximumLength: 5) { [weak self] h, _, complete, err in
            guard let self else { return }
            guard let h, h.count == 5, err == nil else { self.close(); return }
            let n = Int(UInt32(bigEndian: h.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
            let kind = Kind(rawValue: h[h.startIndex + 4]) ?? .bye
            if n == 0 { self.onFrame?(kind, Data()); if complete { self.close() } else { self.readFrame() }; return }
            self.conn.receive(minimumIncompleteLength: n, maximumLength: n) { b, _, c2, e2 in
                guard let b, e2 == nil else { self.close(); return }
                self.onFrame?(kind, b)
                if c2 { self.close() } else { self.readFrame() }
            }
        }
    }
    func close() {
        guard !closed else { return }
        closed = true
        conn.cancel()
        onClose?()
    }
}

open class MCSession: NSObject, @unchecked Sendable {
    open weak var delegate: MCSessionDelegate?
    public let myPeerID: MCPeerID
    public let securityIdentity: [Any]?
    public let encryptionPreference: MCEncryptionPreference
    open var connectedPeers: [MCPeerID] { lock.lock(); defer { lock.unlock() }; return links.keys.compactMap { id in peers[id] } }
    let lock = NSLock()
    var links: [String: _MCLink] = [:]
    var peers: [String: MCPeerID] = [:]
    let callbackQueue = DispatchQueue(label: "com.apple.MCSession.callback")   /* like iOS, delegate calls are not on the main queue */

    public init(peer myPeerID: MCPeerID, securityIdentity identity: [Any]?, encryptionPreference: MCEncryptionPreference) {
        self.myPeerID = myPeerID; securityIdentity = identity; self.encryptionPreference = encryptionPreference
        super.init()
    }
    public convenience init(peer myPeerID: MCPeerID) { self.init(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional) }

    func _state(_ p: MCPeerID, _ s: MCSessionState) {
        callbackQueue.async { [weak self] in guard let self else { return }; self.delegate?.session(self, peer: p, didChange: s) }
    }
    /// adopt a link whose invitation was accepted
    func _attach(_ link: _MCLink, peer: MCPeerID) {
        lock.lock(); links[peer._id] = link; peers[peer._id] = peer; lock.unlock()
        link.onFrame = { [weak self] k, d in self?._frame(k, d, from: peer) }
        link.onClose = { [weak self] in
            guard let self else { return }
            self.lock.lock(); let had = self.links.removeValue(forKey: peer._id) != nil; self.lock.unlock()
            if had { self._state(peer, .notConnected) }
        }
        _state(peer, .connected)
    }
    func _frame(_ k: _MCLink.Kind, _ d: Data, from p: MCPeerID) {
        switch k {
        case .data: callbackQueue.async { [weak self] in guard let self else { return }; self.delegate?.session(self, didReceive: d, fromPeer: p) }
        case .resource:
            guard let nl = d.firstIndex(of: 0) else { return }
            let name = String(decoding: d[d.startIndex..<nl], as: UTF8.self), body = d[(nl + 1)...]
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MCResource-\(UUID().uuidString.prefix(8))-\(name)")
            let pr = Progress(totalUnitCount: Int64(body.count))
            callbackQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.session(self, didStartReceivingResourceWithName: name, fromPeer: p, with: pr)
                let ok = (try? Data(body).write(to: url)) != nil
                pr.completedUnitCount = Int64(body.count)
                self.delegate?.session(self, didFinishReceivingResourceWithName: name, fromPeer: p, at: ok ? url : nil, withError: ok ? nil : MCError(.unknown))
            }
        case .bye: links[p._id]?.close()
        default: break
        }
    }

    open func send(_ data: Data, toPeers peerIDs: [MCPeerID], with mode: MCSessionSendDataMode) throws {
        lock.lock(); let ls = peerIDs.map { links[$0._id] }; lock.unlock()
        guard !peerIDs.isEmpty, ls.allSatisfy({ $0 != nil }) else { throw MCError(.notConnected) }
        for l in ls { l?.send(.data, data) }
    }
    @discardableResult
    open func sendResource(at resourceURL: URL, withName resourceName: String, toPeer peerID: MCPeerID, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) -> Progress? {
        lock.lock(); let l = links[peerID._id]; lock.unlock()
        guard let l, let body = try? Data(contentsOf: resourceURL) else {
            callbackQueue.async { completionHandler?(MCError(l == nil ? .notConnected : .invalidParameter)) }; return nil
        }
        let p = Progress(totalUnitCount: Int64(body.count))
        l.send(.resource, Data(resourceName.utf8) + Data([0]) + body) { e in p.completedUnitCount = Int64(body.count); self.callbackQueue.async { completionHandler?(e) } }
        return p
    }
    open func startStream(withName streamName: String, toPeer peerID: MCPeerID) throws -> OutputStream { throw MCError(.unsupported) }
    open func disconnect() {
        lock.lock(); let ls = Array(links.values); lock.unlock()
        for l in ls { l.send(.bye, Data()) { _ in l.close() } }
    }
    open func nearbyConnectionData(forPeer peerID: MCPeerID, withCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) {
        completionHandler(nil, MCError(.unsupported))
    }
    open func connectPeer(_ peerID: MCPeerID, withNearbyConnectionData data: Data) {}
    open func cancelConnectPeer(_ peerID: MCPeerID) {}
}

// MARK: - advertising

public protocol MCNearbyServiceAdvertiserDelegate: AnyObject {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void)
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error)
}
extension MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

struct _MCHello: Codable { let name: String, id: String, context: String? }

func _mcValidType(_ t: String) -> Bool {
    let ok = t.count >= 1 && t.count <= 15 && t.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") } && !t.hasPrefix("-") && !t.hasSuffix("-")
    return ok
}

open class MCNearbyServiceAdvertiser: NSObject, @unchecked Sendable {
    open weak var delegate: MCNearbyServiceAdvertiserDelegate?
    public let myPeerID: MCPeerID
    public let discoveryInfo: [String: String]?
    public let serviceType: String
    var listener: NWListener?
    var pending: [_MCLink] = []
    public init(peer myPeerID: MCPeerID, discoveryInfo info: [String: String]?, serviceType: String) {
        precondition(_mcValidType(serviceType), "Invalid serviceType passed to MCNearbyServiceAdvertiser")
        self.myPeerID = myPeerID; discoveryInfo = info; self.serviceType = serviceType
        super.init()
    }
    open func startAdvertisingPeer() {
        guard listener == nil else { return }
        do {
            let p = NWParameters.tcp
            p.acceptLocalOnly = true
            let l = try NWListener(using: p)
            var txt = discoveryInfo ?? [:]
            txt["_mc.name"] = myPeerID.displayName; txt["_mc.id"] = myPeerID._id
            l.service = NWListener.Service(name: "\(myPeerID.displayName)-\(myPeerID._id.prefix(8))", type: "_\(serviceType)._tcp", txtRecord: NWTXTRecord(txt))
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: DispatchQueue(label: "isim.MCAdvertiser"))
            listener = l
            print("isim: MultipeerConnectivity: advertising \(myPeerID.displayName) for \(serviceType) (local registry)")
        } catch {
            DispatchQueue.main.async { self.delegate?.advertiser(self, didNotStartAdvertisingPeer: error) }
        }
    }
    open func stopAdvertisingPeer() { listener?.cancel(); listener = nil }
    func accept(_ c: NWConnection) {
        let link = _MCLink(c)
        pending.append(link)
        link.onFrame = { [weak self, weak link] k, d in
            guard let self, let link, k == .invite, let h = try? JSONDecoder().decode(_MCHello.self, from: d) else { return }
            let peer = MCPeerID(displayName: h.name, id: h.id)
            let ctx = h.context.flatMap { Data(base64Encoded: $0) }
            var answered = false
            DispatchQueue.main.async {
                self.delegate?.advertiser(self, didReceiveInvitationFromPeer: peer, withContext: ctx) { accept, session in
                    guard !answered else { return }
                    answered = true
                    self.pending.removeAll { $0 === link }
                    guard accept, let session else { link.send(.decline, Data()) { _ in link.close() }; return }
                    let me = (try? JSONEncoder().encode(_MCHello(name: session.myPeerID.displayName, id: session.myPeerID._id, context: nil))) ?? Data()
                    link.send(.accept, me)
                    session._attach(link, peer: peer)
                }
            }
        }
        link.start()
    }
}

// MARK: - browsing

public protocol MCNearbyServiceBrowserDelegate: AnyObject {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?)
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID)
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error)
}
extension MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}

open class MCNearbyServiceBrowser: NSObject, @unchecked Sendable {
    open weak var delegate: MCNearbyServiceBrowserDelegate?
    public let myPeerID: MCPeerID
    public let serviceType: String
    var browser: NWBrowser?
    var found: [String: (peer: MCPeerID, endpoint: NWEndpoint)] = [:]
    public init(peer myPeerID: MCPeerID, serviceType: String) {
        precondition(_mcValidType(serviceType), "Invalid serviceType passed to MCNearbyServiceBrowser")
        self.myPeerID = myPeerID; self.serviceType = serviceType
        super.init()
    }
    open func startBrowsingForPeers() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_\(serviceType)._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in self?.update(results) }
        b.start(queue: .main)
        browser = b
    }
    open func stopBrowsingForPeers() { browser?.cancel(); browser = nil }
    func update(_ results: Set<NWBrowser.Result>) {
        var now: [String: (MCPeerID, NWEndpoint, [String: String])] = [:]
        for r in results {
            guard case .bonjour(let txt) = r.metadata, let id = txt["_mc.id"], let name = txt["_mc.name"], id != myPeerID._id else { continue }
            var info = txt.dictionary; info["_mc.id"] = nil; info["_mc.name"] = nil
            now[id] = (found[id]?.peer ?? MCPeerID(displayName: name, id: id), r.endpoint, info)
        }
        for (id, v) in found where now[id] == nil { found[id] = nil; delegate?.browser(self, lostPeer: v.peer) }
        for (id, v) in now where found[id] == nil {
            found[id] = (v.0, v.1)
            delegate?.browser(self, foundPeer: v.0, withDiscoveryInfo: v.2.isEmpty ? nil : v.2)
        }
    }
    open func invitePeer(_ peerID: MCPeerID, to session: MCSession, withContext context: Data?, timeout: TimeInterval) {
        guard let ep = found[peerID._id]?.endpoint else { session._state(peerID, .notConnected); return }
        session._state(peerID, .connecting)
        let link = _MCLink(NWConnection(to: ep, using: .tcp))
        var settled = false
        let finish: (Bool) -> Void = { ok in
            guard !settled else { return }
            settled = true
            if !ok { link.close(); session._state(peerID, .notConnected) }
        }
        link.onFrame = { k, d in
            switch k {
            case .accept: settled = true; session._attach(link, peer: peerID)
            case .decline: finish(false)
            default: break
            }
        }
        link.onClose = { finish(false) }
        link.start()
        let me = (try? JSONEncoder().encode(_MCHello(name: session.myPeerID.displayName, id: session.myPeerID._id, context: context?.base64EncodedString()))) ?? Data()
        link.send(.invite, me)
        DispatchQueue.main.asyncAfter(deadline: .now() + (timeout > 0 ? timeout : 30)) { finish(false) }
    }
}

// MARK: - UI

public protocol MCBrowserViewControllerDelegate: AnyObject {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController)
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController)
    func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) -> Bool
}
extension MCBrowserViewControllerDelegate {
    public func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) -> Bool { true }
}

/// The nearby-peers sheet: tap a peer to invite it; Done when connected.
open class MCBrowserViewController: UIViewController, MCNearbyServiceBrowserDelegate, UITableViewDataSource, UITableViewDelegate {
    open weak var delegate: MCBrowserViewControllerDelegate?
    public let browser: MCNearbyServiceBrowser?
    public let session: MCSession
    open var minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
    open var maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers
    var peers: [MCPeerID] = []
    var states: [MCPeerID: String] = [:]
    let table = UITableView(frame: .zero, style: .insetGrouped)
    public init(browser: MCNearbyServiceBrowser, session: MCSession) {
        self.browser = browser; self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    public convenience init(serviceType: String, session: MCSession) {
        self.init(browser: MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: serviceType), session: session)
    }
    public required init?(coder: NSCoder) { fatalError() }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let bar = UINavigationBar(frame: .zero)
        let item = UINavigationItem(title: "Choose a Device")
        item.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        item.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        bar.items = [item]
        bar.translatesAutoresizingMaskIntoConstraints = false
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "peer")
        view.addSubview(table); view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor), table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor), table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    open override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); browser?.stopBrowsingForPeers() }
    @objc func cancelTapped() { delegate?.browserViewControllerWasCancelled(self) }
    @objc func doneTapped() { delegate?.browserViewControllerDidFinish(self) }
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard delegate?.browserViewController(self, shouldPresentNearbyPeer: peerID, withDiscoveryInfo: info) ?? true else { return }
        peers.append(peerID); table.reloadData()
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { peers.removeAll { $0 == peerID }; table.reloadData() }
    public func numberOfSections(in tableView: UITableView) -> Int { 1 }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { peers.count }
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Nearby Devices" }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "peer", for: indexPath)
        let p = peers[indexPath.row]
        c.textLabel?.text = p.displayName + (states[p].map { " — \($0)" } ?? "")
        c.accessibilityIdentifier = "mc-peer-\(p.displayName)"
        return c
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let p = peers[indexPath.row]
        states[p] = "Connecting"
        tableView.reloadData()
        browser?.invitePeer(p, to: session, withContext: nil, timeout: 30)
    }
}

/// Advertises with the system's invitation alert ("<peer> wants to connect" — Decline / Accept).
open class MCAdvertiserAssistant: NSObject, MCNearbyServiceAdvertiserDelegate {
    public let session: MCSession
    public let discoveryInfo: [String: String]?
    public let serviceType: String
    open weak var delegate: AnyObject?
    let advertiser: MCNearbyServiceAdvertiser
    public init(serviceType: String, discoveryInfo info: [String: String]?, session: MCSession) {
        self.serviceType = serviceType; discoveryInfo = info; self.session = session
        advertiser = MCNearbyServiceAdvertiser(peer: session.myPeerID, discoveryInfo: info, serviceType: serviceType)
        super.init()
        advertiser.delegate = self
    }
    open func start() { advertiser.startAdvertisingPeer() }
    open func stop() { advertiser.stopAdvertisingPeer() }
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                           invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let a = UIAlertController(title: "“\(peerID.displayName)” wants to connect.", message: nil, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in invitationHandler(false, nil) })
        a.addAction(UIAlertAction(title: "Accept", style: .default) { [session] _ in invitationHandler(true, session) })
        var top = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(a, animated: true)
    }
}
