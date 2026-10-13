// isim MultipeerConnectivity: peers, sessions, advertising, browsing and invitations between apps on the same
// isim device (or within one app) and other isim devices on the network, over TCP.
//
// Adapted: there is no Wi-Fi/Bluetooth peer-to-peer radio. Advertisers are Bonjour services of type
// "_<serviceType>._tcp" (the Network framework: isim's local registry, $ISIM_DATA/Library/isim/Bonjour, and
// multicast DNS on the host's network unless ISIM_MDNS=0), browsers find them there, and invited peers talk over a
// TCP connection: data (reliable and unreliable alike), resources (files), byte streams (startStream: the peer gets
// an InputStream) and peer state changes. Security identities: the peers exchange their certificate chains during
// the invitation, each proves it holds its identity's private key (a signature over the other's nonce) and the
// session delegate's session(_:didReceiveCertificate:fromPeer:certificateHandler:) accepts or refuses the peer.
// The link itself is not encrypted, and isim peers do not talk to real iOS devices (Apple's MultipeerConnectivity
// wire protocol is private). MCBrowserViewController shows the nearby peers in an iOS-style list;
// MCAdvertiserAssistant asks with the system's invitation alert.
@_exported import Foundation
import UIKit
import Network
import Security

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
    enum Kind: UInt8 { case hello = 1, invite = 2, accept = 3, decline = 4, data = 5, resource = 6, bye = 7, proof = 8,
                       streamOpen = 9, streamData = 10, streamClose = 11 }
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
    var observers: [(MCPeerID, MCSessionState) -> Void] = []                    /* MCBrowserViewController */
    var inStreams: [String: (out: OutputStream, queue: DispatchQueue)] = [:]   /* "<peer>/<stream id>" */
    var nextStream: UInt32 = 1

    public init(peer myPeerID: MCPeerID, securityIdentity identity: [Any]?, encryptionPreference: MCEncryptionPreference) {
        self.myPeerID = myPeerID; securityIdentity = identity; self.encryptionPreference = encryptionPreference
        super.init()
    }
    public convenience init(peer myPeerID: MCPeerID) { self.init(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional) }

    func _state(_ p: MCPeerID, _ s: MCSessionState) {
        lock.lock(); let obs = observers; lock.unlock()
        callbackQueue.async { [weak self] in guard let self else { return }; self.delegate?.session(self, peer: p, didChange: s) }
        if !obs.isEmpty { DispatchQueue.main.async { for o in obs { o(p, s) } } }
    }
    /// the identity's certificate chain (leaf first) as DER, for the invitation
    var _certificates: [Data] {
        guard let a = securityIdentity, let id = a.first as? SecIdentity else { return [] }
        var leaf: SecCertificate?
        guard SecIdentityCopyCertificate(id, &leaf) == errSecSuccess, let leaf else { return [] }
        return [SecCertificateCopyData(leaf) as Data] + a.dropFirst().compactMap { ($0 as? SecCertificate).map { SecCertificateCopyData($0) as Data } }
    }
    /// a signature over the peer's nonce with the identity's private key (proof of holding it)
    func _sign(_ nonce: Data) -> Data? {
        guard let a = securityIdentity, let id = a.first as? SecIdentity else { return nil }
        var key: SecKey?
        guard SecIdentityCopyPrivateKey(id, &key) == errSecSuccess, let key else { return nil }
        let ec = ((SecKeyCopyAttributes(key) as? [String: Any])?[kSecAttrKeyType as String] as? String) == (kSecAttrKeyTypeEC as String)
        return SecKeyCreateSignature(key, ec ? .ecdsaSignatureMessageX962SHA256 : .rsaSignatureMessagePKCS1v15SHA256, nonce as CFData, nil) as Data?
    }
    /// checks the peer's certificates (its proof over our nonce first), then asks the delegate
    func _checkPeer(_ hello: _MCHello, nonce: Data, peer: MCPeerID, _ done: @escaping (Bool) -> Void) {
        let certs = (hello.cert ?? []).compactMap { Data(base64Encoded: $0) }.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
        if let leaf = certs.first {
            guard let sig = hello.sig.flatMap({ Data(base64Encoded: $0) }), let key = SecCertificateCopyKey(leaf),
                  SecKeyVerifySignature(key, .ecdsaSignatureMessageX962SHA256, nonce as CFData, sig as CFData, nil)
                    || SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, nonce as CFData, sig as CFData, nil) else {
                print("isim: MultipeerConnectivity: \(peer.displayName) does not hold its certificate's key: refused")
                done(false); return
            }
        }
        callbackQueue.async { [weak self] in
            guard let self else { return }
            guard let d = self.delegate else { done(true); return }
            var answered = false
            d.session(self, didReceiveCertificate: certs.isEmpty ? nil : certs, fromPeer: peer) { ok in
                guard !answered else { return }
                answered = true
                done(ok)
            }
        }
    }
    /// adopt a link whose invitation was accepted
    func _attach(_ link: _MCLink, peer: MCPeerID) {
        lock.lock(); links[peer._id] = link; peers[peer._id] = peer; lock.unlock()
        link.onFrame = { [weak self] k, d in self?._frame(k, d, from: peer) }
        link.onClose = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let had = self.links.removeValue(forKey: peer._id) != nil
            let streams = self.inStreams.filter { $0.key.hasPrefix(peer._id + "/") }
            for k in streams.keys { self.inStreams[k] = nil }
            self.lock.unlock()
            for (_, v) in streams { v.queue.async { v.out.close() } }
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
        case .bye: lock.lock(); let l = links[p._id]; lock.unlock(); l?.close()
        case .streamOpen:
            guard d.count >= 4 else { return }
            let sid = d.prefix(4).withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
            let name = String(decoding: d.dropFirst(4), as: UTF8.self)
            var i: InputStream?, o: OutputStream?
            Stream.getBoundStreams(withBufferSize: 1 << 22, inputStream: &i, outputStream: &o)
            guard let i, let o else { return }
            o.open()
            lock.lock(); inStreams["\(p._id)/\(sid)"] = (o, DispatchQueue(label: "isim.MCSession.stream")); lock.unlock()
            callbackQueue.async { [weak self] in guard let self else { return }; self.delegate?.session(self, didReceive: i, withName: name, fromPeer: p) }
        case .streamData, .streamClose:
            guard d.count >= 4 else { return }
            let sid = d.prefix(4).withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
            let key = "\(p._id)/\(sid)"
            lock.lock(); let st = inStreams[key]; if k == .streamClose { inStreams[key] = nil }; lock.unlock()
            guard let st else { return }
            let body = Data(d.dropFirst(4))
            st.queue.async {
                if k == .streamClose { st.out.close(); return }
                var off = 0
                while off < body.count {
                    let n = body.withUnsafeBytes { b in st.out.write(b.bindMemory(to: UInt8.self).baseAddress! + off, maxLength: body.count - off) }
                    if n <= 0 { return }                         /* the app closed its input stream */
                    off += n
                }
            }
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
    /// a byte stream to the peer: what the app writes to the returned OutputStream reaches the peer's InputStream
    /// (session(_:didReceive:withName:fromPeer:)); closing it ends the peer's stream
    open func startStream(withName streamName: String, toPeer peerID: MCPeerID) throws -> OutputStream {
        lock.lock()
        let l = links[peerID._id]
        let sid = nextStream; nextStream += 1
        lock.unlock()
        guard let l else { throw MCError(.notConnected) }
        var i: InputStream?, o: OutputStream?
        Stream.getBoundStreams(withBufferSize: 65536, inputStream: &i, outputStream: &o)
        guard let i, let o else { throw MCError(.unknown) }
        let head = withUnsafeBytes(of: sid.bigEndian) { Data($0) }
        l.send(.streamOpen, head + Data(streamName.utf8))
        let t = Thread {
            i.open()
            var buf = [UInt8](repeating: 0, count: 16384)
            while !l.closed {
                let n = i.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                l.send(.streamData, head + Data(buf[0..<n]))
            }
            i.close()
            l.send(.streamClose, head)
        }
        t.name = "isim.MCSession.stream"
        t.start()
        return o
    }
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

/// an invitation or its answer: the peer, the invitation's context, its certificate chain (base64 DER, leaf first), a
/// nonce for the other side to sign and its signature over the other side's nonce
struct _MCHello: Codable {
    let name: String, id: String, context: String?
    var cert: [String]? = nil, nonce: String? = nil, sig: String? = nil
}
func _mcNonce() -> Data { Data((0..<16).map { _ in UInt8.random(in: 0...255) }) }

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
            p.acceptLocalOnly = ProcessInfo.processInfo.environment["ISIM_MDNS"] == "0"   /* peers on the network find it by mDNS */
            let l = try NWListener(using: p)
            var txt = discoveryInfo ?? [:]
            txt["_mc.name"] = myPeerID.displayName; txt["_mc.id"] = myPeerID._id
            l.service = NWListener.Service(name: "\(myPeerID.displayName)-\(myPeerID._id.prefix(8))", type: "_\(serviceType)._tcp", txtRecord: NWTXTRecord(txt))
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: DispatchQueue(label: "isim.MCAdvertiser"))
            listener = l
            print("isim: MultipeerConnectivity: advertising \(myPeerID.displayName) for \(serviceType) (\(p.acceptLocalOnly ? "local registry" : "local registry and multicast DNS"))")
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
                    // answer with our certificates and a signature over the inviter's nonce, then wait for the
                    // inviter's proof over ours; frames that come before the session takes the link wait for it
                    let nonce = _mcNonce()
                    var me = _MCHello(name: session.myPeerID.displayName, id: session.myPeerID._id, context: nil)
                    me.cert = session._certificates.map { $0.base64EncodedString() }
                    me.nonce = nonce.base64EncodedString()
                    me.sig = h.nonce.flatMap { Data(base64Encoded: $0) }.flatMap { session._sign($0) }?.base64EncodedString()
                    var early: [(_MCLink.Kind, Data)] = [], proved = false
                    let lock = NSLock()
                    link.onFrame = { k2, d2 in
                        lock.lock()
                        if proved || k2 != .proof { early.append((k2, d2)); lock.unlock(); return }
                        proved = true
                        lock.unlock()
                        var proof = h
                        proof.sig = (try? JSONDecoder().decode(_MCHello.self, from: d2))?.sig
                        session._checkPeer(proof, nonce: nonce, peer: peer) { ok in
                            guard ok else { link.send(.bye, Data()) { _ in link.close() }; return }
                            link.send(.hello, Data())                 /* both sides accepted: connected */
                            session._attach(link, peer: peer)
                            lock.lock(); let queued = early; early = []; lock.unlock()
                            for (k3, d3) in queued { session._frame(k3, d3, from: peer) }
                        }
                    }
                    link.send(.accept, (try? JSONEncoder().encode(me)) ?? Data())
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
        let nonce = _mcNonce()
        var attached = false
        link.onFrame = { k, d in
            switch k {
            case .accept:
                guard !settled, let h = try? JSONDecoder().decode(_MCHello.self, from: d) else { return }
                settled = true
                // the invitee's certificates and its signature over our nonce; then our proof over its nonce
                session._checkPeer(h, nonce: nonce, peer: peerID) { ok in
                    guard ok else { link.send(.bye, Data()) { _ in link.close() }; return }
                    var proof = _MCHello(name: session.myPeerID.displayName, id: session.myPeerID._id, context: nil)
                    proof.sig = h.nonce.flatMap { Data(base64Encoded: $0) }.flatMap { session._sign($0) }?.base64EncodedString()
                    link.send(.proof, (try? JSONEncoder().encode(proof)) ?? Data())
                }
            case .hello: attached = true; session._attach(link, peer: peerID)   /* the invitee accepted our certificate too */
            case .bye: link.close()
            case .decline: finish(false)
            default: break
            }
        }
        link.onClose = {                                          /* closed before both sides accepted: not connected */
            if !settled { finish(false) } else if !attached { attached = true; session._state(peerID, .notConnected) }
        }
        link.start()
        var me = _MCHello(name: session.myPeerID.displayName, id: session.myPeerID._id, context: context?.base64EncodedString())
        me.cert = session._certificates.map { $0.base64EncodedString() }
        me.nonce = nonce.base64EncodedString()
        link.send(.invite, (try? JSONEncoder().encode(me)) ?? Data())
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

/// The nearby-peers sheet: tap a peer to invite it (its row shows Connecting, then Connected); Done is enabled once
/// the session has minimumNumberOfPeers (this device included).
open class MCBrowserViewController: UIViewController, MCNearbyServiceBrowserDelegate, UITableViewDataSource, UITableViewDelegate {
    open weak var delegate: MCBrowserViewControllerDelegate?
    public let browser: MCNearbyServiceBrowser?
    public let session: MCSession
    open var minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
    open var maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers
    var peers: [MCPeerID] = []
    var states: [MCPeerID: MCSessionState] = [:]
    let table = UITableView(frame: .zero, style: .insetGrouped)
    var doneItem: UIBarButtonItem?
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
        item.leftBarButtonItem?.accessibilityIdentifier = "mc-cancel"
        item.rightBarButtonItem?.accessibilityIdentifier = "mc-done"
        doneItem = item.rightBarButtonItem
        updateDone()
        bar.items = [item]
        bar.translatesAutoresizingMaskIntoConstraints = false
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "peer")
        view.addSubview(table); view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 56),                      /* a sheet's navigation bar */
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor), table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor), table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        session.lock.lock()
        session.observers.append { [weak self] p, st in
            guard let self, self.peers.contains(p) || st == .connected else { return }
            if !self.peers.contains(p) { self.peers.append(p) }
            self.states[p] = st
            self.table.reloadData()
            self.updateDone()
        }
        session.lock.unlock()
    }
    func updateDone() { doneItem?.isEnabled = session.connectedPeers.count + 1 >= minimumNumberOfPeers }
    open override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); browser?.stopBrowsingForPeers() }
    @objc func cancelTapped() { delegate?.browserViewControllerWasCancelled(self) }
    @objc func doneTapped() { delegate?.browserViewControllerDidFinish(self) }
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard !peers.contains(peerID), delegate?.browserViewController(self, shouldPresentNearbyPeer: peerID, withDiscoveryInfo: info) ?? true else { return }
        peers.append(peerID); table.reloadData()
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if states[peerID] != .connected { peers.removeAll { $0 == peerID } }
        table.reloadData()
    }
    public func numberOfSections(in tableView: UITableView) -> Int { 1 }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { peers.count }
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Nearby Devices" }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "peer", for: indexPath)
        let p = peers[indexPath.row]
        let cfg = UIListContentConfiguration.valueCell()
        cfg.text = p.displayName
        switch states[p] {
        case .connecting?: cfg.secondaryText = "Connecting"
        case .connected?: cfg.secondaryText = "Connected"
        case .notConnected?: cfg.secondaryText = "Declined"
        case nil: cfg.secondaryText = nil
        }
        c.contentConfiguration = cfg
        c.accessibilityIdentifier = "mc-peer-\(p.displayName)"
        return c
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let p = peers[indexPath.row]
        guard states[p] != .connecting, states[p] != .connected, session.connectedPeers.count + 1 < maximumNumberOfPeers else { return }
        states[p] = .connecting
        tableView.reloadData()
        browser?.invitePeer(p, to: session, withContext: nil, timeout: 30)
    }
}

public protocol MCAdvertiserAssistantDelegate: AnyObject {
    func advertiserAssistantWillPresentInvitation(_ advertiserAssistant: MCAdvertiserAssistant)
    func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant)
}
extension MCAdvertiserAssistantDelegate {
    public func advertiserAssistantWillPresentInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {}
    public func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {}
}

/// Advertises with the system's invitation alert ("<peer> wants to connect" — Decline / Accept).
open class MCAdvertiserAssistant: NSObject, MCNearbyServiceAdvertiserDelegate {
    public let session: MCSession
    public let discoveryInfo: [String: String]?
    public let serviceType: String
    open weak var delegate: MCAdvertiserAssistantDelegate?
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
        a.addAction(UIAlertAction(title: "Decline", style: .cancel) { [weak self] _ in
            invitationHandler(false, nil)
            if let self { self.delegate?.advertiserAssistantDidDismissInvitation(self) }
        })
        a.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self, session] _ in
            invitationHandler(true, session)
            if let self { self.delegate?.advertiserAssistantDidDismissInvitation(self) }
        })
        delegate?.advertiserAssistantWillPresentInvitation(self)
        var top = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(a, animated: true)
    }
}
