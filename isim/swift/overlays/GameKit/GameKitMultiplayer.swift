// isim GameKit multiplayer (adapted): real-time and turn-based matches between the players of isim's local Game Center
// network (GameCenterNetwork.swift), that is the isim devices on this computer running the same game.
//
// Real-time: findMatch leaves a ticket in games/<bundle id>/realtime/tickets; whichever seeking player sees enough
// compatible tickets (same playerGroup, within every request's min/max players) makes the match
// (realtime/matches/<id>.json) and hands it to the others. Each player of a GKMatch listens on a loopback TCP port
// (recorded in the match file) and connects to the others; data goes over those links in order (reliable and
// unreliable alike). Invites (request recipients, the matchmaker's friend list) reach the friend's device as a banner;
// tapping it is GKLocalPlayerListener.player(_:didAccept:).
//
// Turn-based: matches are files (games/<bundle id>/turnbased/<id>.json) that every participant reads and updates under
// a lock; turn changes and endings reach the other participants' apps through their inbox (turn events).
// Not supported: playerAttributes role matching, rematch of real-time matches, turn-based exchanges, voice chat.
import UIKit
import SwiftUI
import Network

// MARK: - Requests and invites

open class GKMatchRequest: NSObject {
    public enum MatchType: UInt, Sendable { case peerToPeer = 0, hosted = 1, turnBased = 2 }
    open var minPlayers = 2
    open var maxPlayers = 4
    open var defaultNumberOfPlayers = 2
    open var playerGroup = 0
    open var playerAttributes: UInt32 = 0
    open var inviteMessage: String?
    open var recipients: [GKPlayer]?
    open var queueName: String?
    open var properties: [String: Any]?
    open var recipientProperties: [GKPlayer: [String: Any]]?
    open var restrictToAutomatch = false
    /// how each invited player answered
    open var recipientResponseHandler: ((GKPlayer, GKInviteRecipientResponse) -> Void)?
    public class func maxPlayersAllowedForMatch(of matchType: MatchType) -> Int { matchType == .turnBased ? 16 : 4 }
}

public enum GKInviteRecipientResponse: Int, Sendable { case accepted = 0, declined = 1, failed = 2, incompatible = 3, unableToConnect = 4, noAnswer = 5 }

/// An invitation to a real-time match from another player.
open class GKInvite: NSObject {
    var _match = "", _from = "", _group = 0, _hosted = false
    open var sender: GKPlayer { GKPlayer._make(_from) }
    open var isHosted: Bool { _hosted }
    open var playerGroup: Int { _group }
    open var playerAttributes: UInt32 { 0 }
}

// MARK: - Real-time matches

public protocol GKMatchDelegate: AnyObject {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer)
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState)
    func match(_ match: GKMatch, didFailWithError error: Error?)
    func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer)
    func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool
}
extension GKMatchDelegate {
    public func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {}
    public func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {}
    public func match(_ match: GKMatch, didFailWithError error: Error?) {}
    public func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {}
    public func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool { false }
}
public enum GKPlayerConnectionState: Int, Sendable { case unknown = 0, connected = 1, disconnected = 2 }

/// one framed TCP link to another player: [4-byte length][1-byte kind][payload]
final class _GCLink: @unchecked Sendable {
    enum Kind: UInt8 { case hello = 1, data = 2, bye = 3 }
    let conn: NWConnection
    let queue = DispatchQueue(label: "isim.GKMatch.link")
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

/// A real-time match with other isim devices: data over loopback TCP, player state changes, disconnect.
/// Delegate calls arrive on the main queue.
open class GKMatch: NSObject, @unchecked Sendable {
    public enum SendDataMode: Int, Sendable { case reliable = 0, unreliable = 1 }
    weak open var delegate: GKMatchDelegate?
    var _id = ""
    let lock = NSLock()
    var listener: NWListener?
    var inbound: [String: _GCLink] = [:]
    var outbound: [String: _GCLink] = [:]
    var connecting: Set<String> = []
    /// every open link (inbound ones before their hello too), kept until it closes
    var links: [ObjectIdentifier: _GCLink] = [:]
    var connected: [String] = []
    var expected = 1
    var ended = false
    var whenComplete: [() -> Void] = []
    /// the connected remote players
    open var players: [GKPlayer] { lock.lock(); let c = connected; lock.unlock(); return c.map(GKPlayer._make) }
    /// players still to connect (invited or matched, not yet connected)
    open var expectedPlayerCount: Int { lock.lock(); defer { lock.unlock() }; return max(0, expected - 1 - connected.count) }
    open var properties: [String: Any]? { nil }
    open var playerProperties: [GKPlayer: [String: Any]]? { nil }

    open func send(_ data: Data, to players: [GKPlayer], dataMode mode: SendDataMode) throws {
        lock.lock(); let ls = players.map { outbound[$0._id] }; let ok = players.allSatisfy { connected.contains($0._id) }; lock.unlock()
        guard !players.isEmpty, ok else { throw GKError(code: .matchNotConnected) }
        for l in ls { l?.send(.data, data) }
    }
    open func sendData(toAllPlayers data: Data, with mode: SendDataMode) throws {
        lock.lock(); let ls = connected.compactMap { outbound[$0] }; lock.unlock()
        guard !ls.isEmpty else { throw GKError(code: .matchNotConnected) }
        for l in ls { l.send(.data, data) }
    }
    /// Leaves the match: the other players see this player disconnect.
    open func disconnect() {
        lock.lock(); guard !ended else { lock.unlock(); return }; ended = true
        let ls = Array(links.values); let l = listener; listener = nil; lock.unlock()
        for k in ls { k.send(.bye, Data()) { _ in k.close() } }
        l?.cancel()
        _GCNet.tickers["match-\(_id)"] = nil
        _GCNet.update(_GCRealtime.matchFile(_id)) { d in
            var ports = d["ports"] as? [String: Int] ?? [:]; ports[_GCNet.me] = nil; d["ports"] = ports
            d["left"] = (d["left"] as? [String] ?? []) + [_GCNet.me]
            return true
        }
        NSLog("isim GameKit: left match %@", _id)
    }
    /// The player best placed to host: on one computer every link is as good, so the lowest player id.
    open func chooseBestHostingPlayer(completionHandler: @escaping (GKPlayer?) -> Void) {
        lock.lock(); let ids = connected + [_GCNet.me]; lock.unlock()
        let best = ids.min().map(GKPlayer._make)
        DispatchQueue.main.async { completionHandler(best) }
    }
    open func chooseBestHostingPlayer() async -> GKPlayer? { await withCheckedContinuation { k in chooseBestHostingPlayer { k.resume(returning: $0) } } }
    open func rematch(completionHandler: ((GKMatch?, Error?) -> Void)? = nil) { DispatchQueue.main.async { completionHandler?(nil, GKError.unsupported) } }

    // MARK: engine

    /// Starts listening and connecting to the match's other players.
    func start() {
        do {
            let p = NWParameters.tcp
            p.acceptLocalOnly = true
            let l = try NWListener(using: p)
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: DispatchQueue(label: "isim.GKMatch.listener"))
            listener = l
            let port = Int(l.port?.rawValue ?? 0)
            _GCNet.update(_GCRealtime.matchFile(_id)) { d in
                var ports = d["ports"] as? [String: Int] ?? [:]; ports[_GCNet.me] = port; d["ports"] = ports
                return true
            }
            NSLog("isim GameKit: match %@: listening on port %ld", _id, port)
        } catch {
            NSLog("isim GameKit: match %@: cannot listen (%@)", _id, "\(error)")
            DispatchQueue.main.async { self.delegate?.match(self, didFailWithError: GKError(code: .communicationsFailure)) }
            return
        }
        _GCNet.tickers["match-\(_id)"] = { [weak self] in self?.tick() }
        tick()
    }
    /// connects to players whose port is known; counts the expected players
    func tick() {
        guard let d = _GCNet.readDict(_GCRealtime.matchFile(_id)) else { return }
        let players = d["players"] as? [String] ?? [], invited = d["invited"] as? [String] ?? []
        let ports = d["ports"] as? [String: Int] ?? [:], left = Set(d["left"] as? [String] ?? [])
        lock.lock()
        expected = players.filter { !left.contains($0) || connected.contains($0) }.count + invited.count
        let todo = players.filter { $0 != _GCNet.me && !left.contains($0) && outbound[$0] == nil && !connecting.contains($0) && ports[$0] != nil }
        for p in todo { connecting.insert(p) }
        let done = expected - 1 - connected.count <= 0
        lock.unlock()
        for p in todo { connect(p, port: ports[p]!) }
        if done { fireComplete() }
    }
    func connect(_ pid: String, port: Int) {
        NSLog("isim GameKit: match %@: connecting to %@ (port %ld)", _id, _GCNet.player(pid)?.alias ?? pid, port)
        let c = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)
        let link = _GCLink(c)
        c.stateUpdateHandler = { [weak self, weak link] st in
            guard let self, let link else { return }
            if case .ready = st {
                link.send(.hello, Data(_GCNet.me.utf8))
                self.lock.lock(); self.outbound[pid] = link; self.connecting.remove(pid); self.lock.unlock()
                self.check(pid)
            } else if case .failed(let e) = st {
                NSLog("isim GameKit: match %@: connection to %@ failed (%@)", self._id, pid, "\(e)")
                self.lock.lock(); self.connecting.remove(pid); self.lock.unlock()
            }
        }
        lock.lock(); links[ObjectIdentifier(link)] = link; lock.unlock()
        link.onClose = { [weak self, weak link] in
            guard let self else { return }
            if let link { self.lock.lock(); self.links[ObjectIdentifier(link)] = nil; self.lock.unlock() }
            self.lost(pid)
        }
        link.start()
    }
    func accept(_ c: NWConnection) {
        let link = _GCLink(c)
        var from: String?
        link.onFrame = { [weak self, weak link] k, d in
            guard let self, let link else { return }
            switch k {
            case .hello:
                let pid = String(decoding: d, as: UTF8.self)
                from = pid
                self.lock.lock(); self.inbound[pid] = link; self.lock.unlock()
                self.check(pid)
            case .data:
                guard let pid = from else { return }
                DispatchQueue.main.async {
                    let p = GKPlayer._make(pid)
                    self.delegate?.match(self, didReceive: d, fromRemotePlayer: p)
                    self.delegate?.match(self, didReceive: d, forRecipient: GKLocalPlayer.local, fromRemotePlayer: p)
                }
            case .bye: link.close()
            }
        }
        lock.lock(); links[ObjectIdentifier(link)] = link; lock.unlock()
        link.onClose = { [weak self, weak link] in
            guard let self else { return }
            if let link { self.lock.lock(); self.links[ObjectIdentifier(link)] = nil; self.lock.unlock() }
            if let pid = from { self.lost(pid) }
        }
        link.start()
    }
    /// a player is connected once links go both ways
    func check(_ pid: String) {
        lock.lock()
        let now = inbound[pid] != nil && outbound[pid] != nil && !connected.contains(pid) && !ended
        if now { connected.append(pid) }
        let done = expected - 1 - connected.count <= 0
        lock.unlock()
        guard now else { return }
        _GCNet.met([pid])
        NSLog("isim GameKit: match %@: %@ connected", _id, _GCNet.player(pid)?.alias ?? pid)
        DispatchQueue.main.async {
            self.delegate?.match(self, player: GKPlayer._make(pid), didChange: .connected)
            if done { self.fireComplete() }
        }
    }
    func lost(_ pid: String) {
        lock.lock()
        let was = connected.contains(pid)
        connected.removeAll { $0 == pid }
        let a = inbound.removeValue(forKey: pid), b = outbound.removeValue(forKey: pid)
        lock.unlock()
        a?.close(); b?.close()
        guard was else { return }
        NSLog("isim GameKit: match %@: %@ disconnected", _id, _GCNet.player(pid)?.alias ?? pid)
        DispatchQueue.main.async { self.delegate?.match(self, player: GKPlayer._make(pid), didChange: .disconnected) }
    }
    func fireComplete() {
        lock.lock(); let w = whenComplete; whenComplete = []; lock.unlock()
        for f in w { DispatchQueue.main.async { f() } }
    }
    /// runs `f` once every expected player is connected
    func whenAllConnected(_ f: @escaping () -> Void) {
        lock.lock(); let done = expected - 1 - connected.count <= 0 && !connected.isEmpty; if !done { whenComplete.append(f) }; lock.unlock()
        if done { DispatchQueue.main.async { f() } }
    }
}

enum _GCRealtime {
    static func dir(_ sub: String) -> String { _GCNet.gamePath("realtime", sub) }
    static func matchFile(_ id: String) -> String { (dir("matches") as NSString).appendingPathComponent("\(id).json") }
    static func ticketFile(_ pid: String) -> String { (dir("tickets") as NSString).appendingPathComponent("\(pid).json") }
    static func newMatch(players: [String], invited: [String], group: Int, hosted: Bool) -> String {
        let id = UUID().uuidString
        _GCNet.write(matchFile(id), ["id": id, "players": players, "invited": invited, "group": group, "hosted": hosted,
                                     "created": Date().timeIntervalSince1970, "ports": [String: Int](), "responses": [String: Int]()])
        return id
    }
    static func join(_ id: String) -> GKMatch {
        let m = GKMatch()
        m._id = id
        m.start()
        return m
    }

    /// The matchmaking pass run by every seeking player: refresh our ticket; if someone made our match, done; else
    /// make one when enough compatible players are seeking.
    static func seekTick(_ done: @escaping (String?) -> Void) {
        let lockPath = dir("tickets")
        let mid: String? = _GCNet.locked(lockPath) {
            let mine = ticketFile(_GCNet.me)
            guard var me = _GCNet.readDict(mine) else { return nil }
            if let m = me["match"] as? String { _GCNet.remove(mine); return m }
            let now = Date().timeIntervalSince1970
            me["seen"] = now
            _GCNet.write(mine, me)
            let group = me["group"] as? Int ?? 0, hosted = me["hosted"] as? Bool ?? false
            let tickets = _GCNet.list(dir("tickets")).filter { $0.hasSuffix(".json") }
                .compactMap { _GCNet.readDict((dir("tickets") as NSString).appendingPathComponent($0)) }
                .filter { $0["match"] == nil && now - ($0["seen"] as? Double ?? 0) < 3 && ($0["group"] as? Int ?? 0) == group && ($0["hosted"] as? Bool ?? false) == hosted }
                .sorted { ($0["created"] as? Double ?? 0) < ($1["created"] as? Double ?? 0) }
            var chosen: [[String: Any]] = []
            for t in tickets {
                let next = chosen + [t]
                if next.count <= next.map({ $0["max"] as? Int ?? 4 }).min()! { chosen = next }
            }
            let need = chosen.map { $0["min"] as? Int ?? 2 }.max() ?? 2
            guard chosen.count >= need, chosen.contains(where: { ($0["pid"] as? String) == _GCNet.me }) else { return nil }
            let pids = chosen.compactMap { $0["pid"] as? String }
            let id = newMatch(players: pids, invited: [], group: group, hosted: hosted)
            for p in pids where p != _GCNet.me {
                var t = _GCNet.readDict(ticketFile(p)) ?? [:]; t["match"] = id; _GCNet.write(ticketFile(p), t)
            }
            _GCNet.remove(mine)
            NSLog("isim GameKit: matchmaking made match %@ for %ld players", id, pids.count)
            return id
        }
        if let mid { _GCNet.tickers["seek"] = nil; done(mid) }
    }
    static func seek(_ r: GKMatchRequest, hosted: Bool, _ done: @escaping (String?) -> Void) {
        let now = Date().timeIntervalSince1970
        _GCNet.locked(dir("tickets")) {
            _GCNet.write(ticketFile(_GCNet.me), ["pid": _GCNet.me, "min": r.minPlayers, "max": r.maxPlayers, "group": r.playerGroup,
                                                 "hosted": hosted, "created": now, "seen": now])
        }
        NSLog("isim GameKit: looking for %ld-%ld players (group %ld)", r.minPlayers, r.maxPlayers, r.playerGroup)
        _GCNet.tickers["seek"] = { seekTick(done) }
        seekTick(done)
    }
    static func stopSeeking() {
        _GCNet.tickers["seek"] = nil
        _GCNet.locked(dir("tickets")) { _GCNet.remove(ticketFile(_GCNet.me)) }
    }

    /// Invites players to a new match hosted by the local player; returns the match id.
    static func invite(_ r: GKMatchRequest, recipients: [GKPlayer], into existing: String? = nil) -> String {
        let ids = recipients.map { $0._id }
        let id = existing ?? newMatch(players: [_GCNet.me], invited: [], group: r.playerGroup, hosted: false)
        _GCNet.update(matchFile(id)) { d in d["invited"] = Array(Set((d["invited"] as? [String] ?? []) + ids)); return true }
        for p in recipients {
            _GCNet.post(p._id, ["kind": "invite", "invite": id, "from": _GCNet.me, "group": r.playerGroup, "message": r.inviteMessage ?? ""])
            NSLog("isim GameKit: invited %@ to match %@", p.alias, id)
        }
        // answers reach the request's recipientResponseHandler
        if let h = r.recipientResponseHandler {
            var told = Set<String>()
            _GCNet.tickers["invite-\(id)"] = {
                guard let d = _GCNet.readDict(matchFile(id)) else { return }
                let resp = d["responses"] as? [String: Int] ?? [:]
                for (p, v) in resp where ids.contains(p) && !told.contains(p) {
                    told.insert(p)
                    h(GKPlayer._make(p), GKInviteRecipientResponse(rawValue: v) ?? .failed)
                }
                if told.count == ids.count { _GCNet.tickers["invite-\(id)"] = nil }
            }
        }
        return id
    }
    /// An invited player answers: accepted (joins the match's players) or declined.
    static func respond(_ id: String, accept: Bool) {
        _GCNet.update(matchFile(id)) { d in
            var invited = d["invited"] as? [String] ?? []
            invited.removeAll { $0 == _GCNet.me }
            d["invited"] = invited
            if accept { d["players"] = (d["players"] as? [String] ?? []).filter { $0 != _GCNet.me } + [_GCNet.me] }
            var r = d["responses"] as? [String: Int] ?? [:]; r[_GCNet.me] = accept ? 0 : 1; d["responses"] = r
            return true
        }
        NSLog("isim GameKit: invite to match %@ %@", id, accept ? "accepted" : "declined")
    }
}

/// Finds real-time matches: automatching with the other isim devices running the game, or invites.
open class GKMatchmaker: NSObject {
    nonisolated(unsafe) static let instance = GKMatchmaker()
    open class func shared() -> GKMatchmaker { instance }
    var finding: ((GKMatch?, Error?) -> Void)?
    /// Automatches (no recipients) or invites the request's recipients. The match comes back as soon as it is made;
    /// players then connect (`expectedPlayerCount`, `match(_:player:didChange:)`).
    open func findMatch(for request: GKMatchRequest, withCompletionHandler h: ((GKMatch?, Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { h?(nil, GKError.notAuthenticated) }; return }
        guard request.minPlayers >= 2, request.maxPlayers >= request.minPlayers, request.maxPlayers <= 4 else {
            DispatchQueue.main.async { h?(nil, GKError(code: .matchRequestInvalid)) }; return
        }
        if let r = request.recipients, !r.isEmpty {
            let id = _GCRealtime.invite(request, recipients: r)
            let m = _GCRealtime.join(id)
            DispatchQueue.main.async { h?(m, nil) }
            return
        }
        finding = h
        _GCRealtime.seek(request, hosted: false) { [weak self] mid in
            guard let self, let mid else { return }
            let f = self.finding; self.finding = nil
            f?(_GCRealtime.join(mid), nil)
        }
    }
    open func findMatch(for request: GKMatchRequest) async throws -> GKMatch {
        try await withCheckedThrowingContinuation { k in findMatch(for: request) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Hosted matches: the players found (the game connects them itself).
    open func findPlayers(forHostedRequest request: GKMatchRequest, withCompletionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { h?(nil, GKError.notAuthenticated) }; return }
        _GCRealtime.seek(request, hosted: true) { mid in
            guard let mid, let d = _GCNet.readDict(_GCRealtime.matchFile(mid)) else { return }
            let others = (d["players"] as? [String] ?? []).filter { $0 != _GCNet.me }
            _GCNet.met(others)
            h?(others.map(GKPlayer._make), nil)
        }
    }
    open func findPlayers(forHostedRequest request: GKMatchRequest) async throws -> [GKPlayer] {
        try await withCheckedThrowingContinuation { k in findPlayers(forHostedRequest: request) { p, e in if let p { k.resume(returning: p) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Joins the match an invite is for.
    open func match(for invite: GKInvite, completionHandler h: ((GKMatch?, Error?) -> Void)? = nil) {
        _GCRealtime.respond(invite._match, accept: true)
        let m = _GCRealtime.join(invite._match)
        DispatchQueue.main.async { h?(m, nil) }
    }
    open func match(for invite: GKInvite) async throws -> GKMatch {
        try await withCheckedThrowingContinuation { k in match(for: invite) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Invites more players into a match.
    open func addPlayers(to match: GKMatch, matchRequest: GKMatchRequest, completionHandler h: ((Error?) -> Void)? = nil) {
        _ = _GCRealtime.invite(matchRequest, recipients: matchRequest.recipients ?? [], into: match._id)
        DispatchQueue.main.async { h?(nil) }
    }
    open func cancel() {
        _GCRealtime.stopSeeking()
        let f = finding; finding = nil
        if let f { DispatchQueue.main.async { f(nil, GKError(code: .cancelled)) } }
    }
    open func cancelPendingInvite(to player: GKPlayer) {}
    open func finishMatchmaking(for match: GKMatch) {}
    var browsing: ((GKPlayer, Bool) -> Void)?
    var nearby: Set<String> = []
    /// Nearby players: the other devices browsing in the same game.
    open func startBrowsingForNearbyPlayers(handler: ((GKPlayer, Bool) -> Void)? = nil) {
        browsing = handler
        _GCNet.tickers["nearby"] = { [weak self] in
            guard let self else { return }
            let now = Date().timeIntervalSince1970, dir = _GCRealtime.dir("nearby")
            _GCNet.write((dir as NSString).appendingPathComponent("\(_GCNet.me).json"), ["seen": now])
            let here = Set(_GCNet.list(dir).filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.filter { p in
                p != _GCNet.me && now - (_GCNet.readDict((dir as NSString).appendingPathComponent("\(p).json"))?["seen"] as? Double ?? 0) < 2
            })
            for p in here.subtracting(self.nearby) { self.browsing?(GKPlayer._make(p), true) }
            for p in self.nearby.subtracting(here) { self.browsing?(GKPlayer._make(p), false) }
            self.nearby = here
        }
    }
    open func stopBrowsingForNearbyPlayers() {
        _GCNet.tickers["nearby"] = nil; browsing = nil; nearby = []
        _GCNet.remove((_GCRealtime.dir("nearby") as NSString).appendingPathComponent("\(_GCNet.me).json"))
    }
    /// players looking for a match in this game right now
    open func queryActivity(completionHandler: ((Int, Error?) -> Void)? = nil) {
        let n = _GCNet.list(_GCRealtime.dir("tickets")).filter { $0.hasSuffix(".json") }.count
        DispatchQueue.main.async { completionHandler?(n, nil) }
    }
    open func queryPlayerGroupActivity(_ playerGroup: Int, withCompletionHandler completionHandler: ((Int, Error?) -> Void)? = nil) {
        let n = _GCNet.list(_GCRealtime.dir("tickets")).filter { $0.hasSuffix(".json") }
            .compactMap { _GCNet.readDict((_GCRealtime.dir("tickets") as NSString).appendingPathComponent($0)) }.filter { ($0["group"] as? Int ?? 0) == playerGroup }.count
        DispatchQueue.main.async { completionHandler?(n, nil) }
    }
}

// MARK: - Matchmaker UI

public protocol GKMatchmakerViewControllerDelegate: AnyObject {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController)
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error)
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch)
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindHostedPlayers players: [GKPlayer])
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, hostedPlayerDidAccept player: GKPlayer)
}
extension GKMatchmakerViewControllerDelegate {
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {}
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindHostedPlayers players: [GKPlayer]) {}
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, hostedPlayerDidAccept player: GKPlayer) {}
}

/// The matchmaking sheet: the local player, a slot per player to find; Find Players automatches with the other isim
/// devices, a slot's Invite lists friends to invite. The delegate gets the match once every player is connected.
open class GKMatchmakerViewController: UINavigationControllerStandIn {
    weak open var matchmakerDelegate: GKMatchmakerViewControllerDelegate?
    public let matchRequest: GKMatchRequest
    open var isHosted = false
    open var canStartWithMinimumPlayers = false
    let invite: GKInvite?
    let model = _GCMatchmakerModel()
    public init?(matchRequest request: GKMatchRequest) { matchRequest = request; invite = nil; super.init(nibName: nil, bundle: nil) }
    public init?(invite: GKInvite) { matchRequest = GKMatchRequest(); self.invite = invite; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { matchRequest = GKMatchRequest(); invite = nil; super.init(nibName: nil, bundle: nil) }
    open func setHostedPlayer(_ player: GKPlayer, didConnect connected: Bool) {}
    open func addPlayers(to match: GKMatch) {}
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        model.request = matchRequest
        model.slots = max(1, matchRequest.maxPlayers - 1)
        model.found = { [weak self] m in
            guard let self else { return }
            NSLog("isim GameKit: matchmaker found a match with %ld players", m.players.count + 1)
            self.matchmakerDelegate?.matchmakerViewController(self, didFind: m)
        }
        model.foundHosted = { [weak self] ps in
            guard let self else { return }
            self.matchmakerDelegate?.matchmakerViewController(self, didFindHostedPlayers: ps)
        }
        model.hosted = isHosted
        NSLog("isim GameKit: matchmaker for %ld-%ld players", matchRequest.minPlayers, matchRequest.maxPlayers)
        embed(_GCMatchmakerView(model: model) { [weak self] in
            guard let self else { return }
            self.model.cancel()
            if let inv = self.invite, self.model.match == nil { _GCRealtime.respond(inv._match, accept: false) }
            if let d = self.matchmakerDelegate { d.matchmakerViewControllerWasCancelled(self) } else { self.dismiss(animated: true, completion: nil) }
        })
        if let invite { model.join(invite) }
        else if let r = matchRequest.recipients, !r.isEmpty { model.invite(r) }
    }
}

final class _GCMatchmakerModel: ObservableObject {
    var request = GKMatchRequest()
    var hosted = false
    @Published var slots = 1
    @Published var status = ""
    @Published var searching = false
    @Published var invited: [GKPlayer] = []
    @Published var joined: [GKPlayer] = []
    @Published var picking = false
    var match: GKMatch?
    var found: ((GKMatch) -> Void)?
    var foundHosted: (([GKPlayer]) -> Void)?
    /// automatch
    func find() {
        searching = true; status = "Finding Players…"
        if hosted {
            GKMatchmaker.shared().findPlayers(forHostedRequest: request) { [weak self] ps, _ in
                MainActor.assumeIsolated {
                    guard let self, let ps else { return }
                    self.joined = ps; self.searching = false; self.status = "Players Found"
                    self.foundHosted?(ps)
                }
            }
            return
        }
        GKMatchmaker.shared().findMatch(for: request) { [weak self] m, _ in
            MainActor.assumeIsolated { if let self, let m { self.watch(m) } }
        }
    }
    func invite(_ players: [GKPlayer]) {
        picking = false
        invited += players
        status = "Waiting for Players…"
        if let m = match { _ = _GCRealtime.invite(request, recipients: players, into: m._id); return }
        let r = request
        let user = r.recipientResponseHandler
        r.recipientResponseHandler = { [weak self] p, resp in
            MainActor.assumeIsolated {
                self?.invited.removeAll { $0.isEqual(p) }
                if resp == .accepted { self?.joined.append(p) }
            }
            user?(p, resp)
        }
        r.recipients = players
        GKMatchmaker.shared().findMatch(for: r) { [weak self] m, _ in
            MainActor.assumeIsolated { if let self, let m { self.watch(m) } }
        }
    }
    func join(_ inv: GKInvite) {
        status = "Joining \(inv.sender.alias)’s game…"; searching = true
        GKMatchmaker.shared().match(for: inv) { [weak self] m, _ in
            MainActor.assumeIsolated { if let self, let m { self.watch(m) } }
        }
    }
    /// shows players as they connect; reports the match once all are in
    func watch(_ m: GKMatch) {
        match = m
        _GCNet.tickers["matchmaker-ui"] = { [weak self, weak m] in
            MainActor.assumeIsolated {
                guard let self, let m else { return }
                let ps = m.players
                if ps.count != self.joined.count { self.joined = ps }
            }
        }
        m.whenAllConnected { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                _GCNet.tickers["matchmaker-ui"] = nil
                self.joined = m.players; self.searching = false; self.status = "Ready"
                self.found?(m)
            }
        }
    }
    func cancel() {
        _GCNet.tickers["matchmaker-ui"] = nil
        if searching && match == nil { GKMatchmaker.shared().cancel() }
    }
}

struct _GCMatchmakerView: View {
    @ObservedObject var model: _GCMatchmakerModel
    let cancel: () -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    _GCPlayerRow(name: _GC.alias, detail: "Ready")
                    ForEach(0..<model.slots, id: \.self) { i in slot(i) }
                } header: { Text(verbatim: "\(model.request.minPlayers)–\(model.request.maxPlayers) Players") } footer: {
                    Text(verbatim: model.status.isEmpty ? "Find players, or invite friends. Players are the other isim devices running this game on this computer." : model.status)
                        .accessibilityIdentifier("gc-match-note")
                }
                if model.picking {
                    Section {
                        let friends = _GCNet.friendIDs().map(GKPlayer._make).filter { f in f.isInvitable && !model.invited.contains(f) && !model.joined.contains(f) }
                        if friends.isEmpty { Text(verbatim: "No friends to invite.").foregroundStyle(.secondary) }
                        ForEach(friends, id: \._id) { f in
                            Button { model.invite([f]) } label: { _GCPlayerRow(name: f.alias, detail: "Invite") }
                                .accessibilityIdentifier("gc-match-invite-\(f.alias)")
                        }
                    } header: { Text(verbatim: "Friends") }
                }
                Section {
                    Button { model.find() } label: { Text(verbatim: "Find Players").frame(maxWidth: .infinity) }
                        .disabled(model.searching || !model.invited.isEmpty)
                        .accessibilityIdentifier("gc-match-find")
                }
            }
            .navigationTitle("Game Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() }.accessibilityIdentifier("gc-match-cancel") } }
        }
    }
    @ViewBuilder func slot(_ i: Int) -> some View {
        if i < model.joined.count {
            _GCPlayerRow(name: model.joined[i].alias, detail: "Connected").accessibilityIdentifier("gc-match-slot-\(i + 1)")
        } else if i - model.joined.count < model.invited.count {
            _GCPlayerRow(name: model.invited[i - model.joined.count].alias, detail: "Invited").accessibilityIdentifier("gc-match-slot-\(i + 1)")
        } else {
            Button { if !model.searching { model.picking.toggle() } } label: {
                HStack(spacing: 12) {
                    ZStack { Circle().fill(_GCStyle.fill); Image(systemName: model.searching ? "magnifyingglass" : "plus").foregroundStyle(.secondary) }.frame(width: 40, height: 40)
                    Text(verbatim: model.searching ? "Finding Players…" : "Invite a Friend").foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("gc-match-slot-\(i + 1)")
        }
    }
}

struct _GCPlayerRow: View {
    let name: String, detail: String
    var body: some View {
        HStack(spacing: 12) {
            _GCAvatar(name: name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Text(verbatim: detail).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Turn-based matches

public let GKTurnTimeoutDefault: TimeInterval = 604800
public let GKTurnTimeoutNone: TimeInterval = 31449600

/// A participant of a turn-based match: a player, or an empty seat still being automatched.
open class GKTurnBasedParticipant: NSObject {
    public enum Status: Int, Sendable { case unknown = 0, invited = 1, declined = 2, matching = 3, active = 4, done = 5 }
    var _rec: [String: Any] = [:]
    var _outcome: GKTurnBasedMatch.Outcome?
    open var player: GKPlayer? { (_rec["pid"] as? String).map(GKPlayer._make) }
    open var lastTurnDate: Date? { (_rec["lastTurn"] as? Double).map { Date(timeIntervalSince1970: $0) } }
    open var status: Status { Status(rawValue: _rec["status"] as? Int ?? 0) ?? .unknown }
    open var timeoutDate: Date? { (_rec["timeout"] as? Double).map { Date(timeIntervalSince1970: $0) } }
    /// set before ending the match or quitting
    open var matchOutcome: GKTurnBasedMatch.Outcome {
        get { _outcome ?? GKTurnBasedMatch.Outcome(rawValue: _rec["outcome"] as? Int ?? 0) ?? .none }
        set { _outcome = newValue }
    }
    var pid: String? { _rec["pid"] as? String }
}

/// A turn-based match, kept on isim's local Game Center network and shared by its participants.
open class GKTurnBasedMatch: NSObject, @unchecked Sendable {
    public enum Status: Int, Sendable { case unknown = 0, open = 1, ended = 2, matching = 3 }
    public enum Outcome: Int, Sendable { case none = 0, quit = 1, won = 2, lost = 3, tied = 4, timeExpired = 5, first = 6, second = 7, third = 8, fourth = 9, customRange = 16711680 }
    var _id = ""
    var _rec: [String: Any] = [:]
    var _parts: [GKTurnBasedParticipant] = []
    static func _make(_ rec: [String: Any]) -> GKTurnBasedMatch {
        let m = GKTurnBasedMatch(); m._id = rec["id"] as? String ?? ""; m._apply(rec); return m
    }
    func _apply(_ rec: [String: Any]) {
        _rec = rec
        let ps = rec["participants"] as? [[String: Any]] ?? []
        if _parts.count != ps.count { _parts = ps.map { _ in GKTurnBasedParticipant() } }
        for (p, r) in zip(_parts, ps) { p._rec = r; p._outcome = nil }
    }
    open var matchID: String { _id }
    open var creationDate: Date { Date(timeIntervalSince1970: _rec["created"] as? Double ?? 0) }
    open var participants: [GKTurnBasedParticipant] { _parts }
    open var status: Status {
        if (_rec["ended"] as? Bool) == true { return .ended }
        return _parts.contains { $0.status == .matching } ? .matching : .open
    }
    open var currentParticipant: GKTurnBasedParticipant? {
        let i = _rec["current"] as? Int ?? -1
        return status != .ended && i >= 0 && i < _parts.count ? _parts[i] : nil
    }
    open var matchData: Data? { (_rec["data"] as? String).flatMap { Data(base64Encoded: $0) } }
    open var matchDataMaximumSize: Int { 65536 }
    open var message: String? {
        get { _rec["message"] as? String }
        set { _rec["message"] = newValue }
    }
    open func setLocalizableMessageWithKey(_ key: String, arguments: [String]?) {
        let f = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        message = (arguments ?? []).reduce(f) { s, a in s.replacingOccurrences(of: "%@", with: a, options: [], range: s.range(of: "%@")) }
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? GKTurnBasedMatch)?._id == _id }
    open override var hash: Int { _id.hashValue }
    open override var description: String { "<GKTurnBasedMatch \(_id) status \(status.rawValue) current \(currentParticipant?.player?.alias ?? "-")>" }
    var myIndex: Int? { _parts.firstIndex { $0.pid == _GCNet.me } }

    // MARK: finding and loading

    /// Automatches into a match waiting for a player (its next seat is open), or creates one with the local player
    /// taking the first turn; with recipients, they are invited to the new match.
    public class func find(for request: GKMatchRequest, withCompletionHandler h: @escaping (GKTurnBasedMatch?, Error?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { h(nil, GKError.notAuthenticated) }; return }
        guard request.minPlayers >= 2, request.maxPlayers >= request.minPlayers, request.maxPlayers <= 16 else {
            DispatchQueue.main.async { h(nil, GKError(code: .matchRequestInvalid)) }; return
        }
        let me = _GCNet.me, now = Date().timeIntervalSince1970
        let recipients = (request.recipients ?? []).map { $0._id }
        let rec: [String: Any] = _GCNet.locked(_GCTurns.dir) {
            if recipients.isEmpty {
                for f in _GCNet.list(_GCTurns.dir) where f.hasSuffix(".json") {
                    guard var m = _GCNet.readDict((_GCTurns.dir as NSString).appendingPathComponent(f)), (m["ended"] as? Bool) != true,
                          (m["group"] as? Int ?? 0) == request.playerGroup else { continue }
                    var ps = m["participants"] as? [[String: Any]] ?? []
                    let cur = m["current"] as? Int ?? -1
                    guard cur >= 0, cur < ps.count, ps[cur]["pid"] == nil, (ps[cur]["status"] as? Int) == GKTurnBasedParticipant.Status.matching.rawValue,
                          !ps.contains(where: { ($0["pid"] as? String) == me }) else { continue }
                    ps[cur]["pid"] = me; ps[cur]["status"] = GKTurnBasedParticipant.Status.active.rawValue
                    m["participants"] = ps
                    _GCTurns.save(m)
                    NSLog("isim GameKit: turn-based: joined match %@", m["id"] as? String ?? "")
                    return m
                }
            }
            let n = max(request.minPlayers, min(request.maxPlayers, max(request.defaultNumberOfPlayers, recipients.count + 1)))
            var ps: [[String: Any]] = [["pid": me, "status": GKTurnBasedParticipant.Status.active.rawValue]]
            for r in recipients.prefix(n - 1) { ps.append(["pid": r, "status": GKTurnBasedParticipant.Status.invited.rawValue]) }
            while ps.count < n { ps.append(["status": GKTurnBasedParticipant.Status.matching.rawValue]) }
            let id = UUID().uuidString
            let m: [String: Any] = ["id": id, "created": now, "group": request.playerGroup, "participants": ps, "current": 0, "version": 0,
                                    "message": request.inviteMessage ?? ""]
            _GCTurns.save(m)
            NSLog("isim GameKit: turn-based: new match %@ for %ld players", id, n)
            return m
        }
        let match = _make(rec)
        _GCNet.met(match._parts.compactMap { $0.pid })
        DispatchQueue.main.async { h(match, nil) }
    }
    public class func find(for request: GKMatchRequest) async throws -> GKTurnBasedMatch {
        try await withCheckedThrowingContinuation { k in find(for: request) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// The local player's matches (not removed).
    public class func loadMatches(completionHandler: (([GKTurnBasedMatch]?, Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler?(nil, GKError.notAuthenticated) }; return }
        let list = _GCTurns.mine().map(_make)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    public class func loadMatches() async throws -> [GKTurnBasedMatch] {
        try await withCheckedThrowingContinuation { k in loadMatches { l, e in if let l { k.resume(returning: l) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    public class func load(withID matchID: String, withCompletionHandler h: ((GKTurnBasedMatch?, Error?) -> Void)? = nil) {
        let m = _GCTurns.read(matchID).map(_make)
        DispatchQueue.main.async { h?(m, m == nil ? GKError(code: .invalidParameter) : nil) }
    }
    public class func load(withID matchID: String) async throws -> GKTurnBasedMatch {
        try await withCheckedThrowingContinuation { k in load(withID: matchID) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Reloads the match (data, participants, turn).
    open func loadMatchData(completionHandler h: ((Data?, Error?) -> Void)? = nil) {
        if let r = _GCTurns.read(_id) { _apply(r) }
        let d = matchData
        DispatchQueue.main.async { h?(d, nil) }
    }
    open func loadMatchData() async throws -> Data? { await withCheckedContinuation { k in loadMatchData { d, _ in k.resume(returning: d) } } }

    // MARK: turns

    /// Updates the match file under its lock; `body` returns an error to refuse the change.
    func change(_ body: @escaping (inout [String: Any], Int?) -> GKError?, done h: ((Error?) -> Void)?) {
        var err: GKError?
        let rec = _GCNet.update(_GCTurns.file(_id)) { d in
            guard !d.isEmpty else { err = GKError(code: .invalidParameter); return false }
            let mine = (d["participants"] as? [[String: Any]] ?? []).firstIndex { ($0["pid"] as? String) == _GCNet.me }
            if let e = body(&d, mine) { err = e; return false }
            d["version"] = (d["version"] as? Int ?? 0) + 1
            return true
        }
        if err == nil || !rec.isEmpty { _apply(rec) }
        DispatchQueue.main.async { h?(err) }
    }
    func outcomes(_ d: inout [String: Any]) {
        var ps = d["participants"] as? [[String: Any]] ?? []
        for (i, p) in _parts.enumerated() where i < ps.count { if let o = p._outcome { ps[i]["outcome"] = o.rawValue } }
        d["participants"] = ps
    }
    static func dataTooLarge(_ data: Data) -> GKError? { data.count > 65536 ? GKError(code: .turnBasedMatchDataTooLarge) : nil }

    /// Ends the local player's turn: saves the data and passes the turn to the first next participant still playing.
    open func endTurn(withNextParticipants nextParticipants: [GKTurnBasedParticipant], turnTimeout timeout: TimeInterval, match matchData: Data, completionHandler h: ((Error?) -> Void)? = nil) {
        let next = nextParticipants.compactMap { p in _parts.firstIndex { $0 === p } }
        let msg = message
        var to: String?
        change({ d, mine in
            if let e = GKTurnBasedMatch.dataTooLarge(matchData) { return e }
            guard (d["ended"] as? Bool) != true else { return GKError(code: .turnBasedInvalidState) }
            guard let mine, (d["current"] as? Int) == mine else { return GKError(code: .turnBasedInvalidTurn) }
            var ps = d["participants"] as? [[String: Any]] ?? []
            guard let n = next.first(where: { i in let s = ps[i]["status"] as? Int ?? 0; return s != GKTurnBasedParticipant.Status.done.rawValue && s != GKTurnBasedParticipant.Status.declined.rawValue }) else {
                return GKError(code: .turnBasedInvalidParticipant)
            }
            let now = Date().timeIntervalSince1970
            ps[mine]["lastTurn"] = now
            ps[n]["timeout"] = now + timeout
            d["participants"] = ps; d["current"] = n; d["data"] = matchData.base64EncodedString(); d["message"] = msg ?? ""
            self.outcomes(&d)
            to = ps[n]["pid"] as? String
            return nil
        }, done: { e in
            if e == nil {
                NSLog("isim GameKit: turn-based: turn passed to %@", to.flatMap { _GCNet.player($0)?.alias } ?? "the next player found")
                _GCTurns.notify(self, kind: "turn")
            }
            h?(e)
        })
    }
    open func endTurn(withNextParticipants nextParticipants: [GKTurnBasedParticipant], turnTimeout timeout: TimeInterval, match matchData: Data) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in endTurn(withNextParticipants: nextParticipants, turnTimeout: timeout, match: matchData) { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Saves the data without ending the turn (the others get a turn event).
    open func saveCurrentTurn(withMatch matchData: Data, completionHandler h: ((Error?) -> Void)? = nil) {
        change({ d, mine in
            if let e = GKTurnBasedMatch.dataTooLarge(matchData) { return e }
            guard let mine, (d["current"] as? Int) == mine else { return GKError(code: .turnBasedInvalidTurn) }
            d["data"] = matchData.base64EncodedString()
            return nil
        }, done: { e in if e == nil { _GCTurns.notify(self, kind: "turn") }; h?(e) })
    }
    open func saveCurrentTurn(withMatch matchData: Data) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in saveCurrentTurn(withMatch: matchData) { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Ends the match on the local player's turn; every participant needs an outcome.
    open func endMatchInTurn(withMatch matchData: Data, completionHandler h: ((Error?) -> Void)? = nil) {
        change({ d, mine in
            if let e = GKTurnBasedMatch.dataTooLarge(matchData) { return e }
            guard let mine, (d["current"] as? Int) == mine, (d["ended"] as? Bool) != true else { return GKError(code: .turnBasedInvalidTurn) }
            self.outcomes(&d)
            var ps = d["participants"] as? [[String: Any]] ?? []
            guard ps.allSatisfy({ ($0["outcome"] as? Int ?? 0) != 0 || $0["pid"] == nil }) else { return GKError(code: .turnBasedInvalidState) }
            for i in ps.indices where ps[i]["pid"] != nil { ps[i]["status"] = GKTurnBasedParticipant.Status.done.rawValue }
            ps[mine]["lastTurn"] = Date().timeIntervalSince1970
            d["participants"] = ps; d["ended"] = true; d["data"] = matchData.base64EncodedString()
            return nil
        }, done: { e in
            if e == nil { NSLog("isim GameKit: turn-based: match %@ ended", self._id); _GCTurns.notify(self, kind: "matchEnded") }
            h?(e)
        })
    }
    open func endMatchInTurn(withMatch matchData: Data) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in endMatchInTurn(withMatch: matchData) { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Ends the match, posting the scores and reporting the achievements of the local player.
    open func endMatchInTurn(withMatch matchData: Data, leaderboardScores scores: [GKLeaderboardScore], achievements: [Any], completionHandler h: ((Error?) -> Void)? = nil) {
        for s in scores where s.player === GKLocalPlayer.local || s.player.isEqual(GKLocalPlayer.local) {
            GKLeaderboard.submitScore(s.value, context: s.context, player: GKLocalPlayer.local, leaderboardIDs: [s.leaderboardID]) { _ in }
        }
        let a = achievements.compactMap { $0 as? GKAchievement }
        if !a.isEmpty { GKAchievement.report(a, withCompletionHandler: nil) }
        endMatchInTurn(withMatch: matchData, completionHandler: h)
    }
    /// Quits on the local player's turn, passing it on.
    open func participantQuitInTurn(with matchOutcome: Outcome, nextParticipants: [GKTurnBasedParticipant], turnTimeout timeout: TimeInterval, match matchData: Data, completionHandler h: ((Error?) -> Void)? = nil) {
        let next = nextParticipants.compactMap { p in _parts.firstIndex { $0 === p } }
        change({ d, mine in
            guard let mine, (d["current"] as? Int) == mine else { return GKError(code: .turnBasedInvalidTurn) }
            var ps = d["participants"] as? [[String: Any]] ?? []
            ps[mine]["status"] = GKTurnBasedParticipant.Status.done.rawValue; ps[mine]["outcome"] = matchOutcome.rawValue
            ps[mine]["lastTurn"] = Date().timeIntervalSince1970
            let n = next.first { i in (ps[i]["status"] as? Int ?? 0) != GKTurnBasedParticipant.Status.done.rawValue }
            d["participants"] = ps; d["current"] = n ?? -1; d["data"] = matchData.base64EncodedString()
            if let n { ps[n]["timeout"] = Date().timeIntervalSince1970 + timeout; d["participants"] = ps }
            return nil
        }, done: { e in if e == nil { _GCTurns.notify(self, kind: "turn") }; h?(e) })
    }
    open func participantQuitInTurn(with matchOutcome: Outcome, nextParticipants: [GKTurnBasedParticipant], turnTimeout timeout: TimeInterval, match matchData: Data) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in participantQuitInTurn(with: matchOutcome, nextParticipants: nextParticipants, turnTimeout: timeout, match: matchData) { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Quits while it is another participant's turn.
    open func participantQuitOutOfTurn(with matchOutcome: Outcome, withCompletionHandler h: ((Error?) -> Void)? = nil) {
        change({ d, mine in
            guard let mine, (d["current"] as? Int) != mine else { return GKError(code: .turnBasedInvalidState) }
            var ps = d["participants"] as? [[String: Any]] ?? []
            ps[mine]["status"] = GKTurnBasedParticipant.Status.done.rawValue; ps[mine]["outcome"] = matchOutcome.rawValue
            d["participants"] = ps
            return nil
        }, done: { e in if e == nil { _GCTurns.notify(self, kind: "turn") }; h?(e) })
    }
    open func participantQuitOutOfTurn(with matchOutcome: Outcome) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in participantQuitOutOfTurn(with: matchOutcome) { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Removes an ended (or quit) match from the local player's list.
    open func remove(completionHandler h: ((Error?) -> Void)? = nil) {
        change({ d, mine in
            guard let mine else { return GKError(code: .turnBasedInvalidParticipant) }
            let ps = d["participants"] as? [[String: Any]] ?? []
            guard (d["ended"] as? Bool) == true || (ps[mine]["status"] as? Int) == GKTurnBasedParticipant.Status.done.rawValue else { return GKError(code: .turnBasedInvalidState) }
            d["removed"] = (d["removed"] as? [String] ?? []) + [_GCNet.me]
            return nil
        }, done: h)
    }
    open func remove() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in remove { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    /// Accepts or declines an invitation to this match.
    open func acceptInvite(completionHandler h: ((GKTurnBasedMatch?, Error?) -> Void)? = nil) { answer(true) { e in h?(e == nil ? self : nil, e) } }
    open func acceptInvite() async throws -> GKTurnBasedMatch {
        try await withCheckedThrowingContinuation { k in acceptInvite { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    open func declineInvite(completionHandler h: ((Error?) -> Void)? = nil) { answer(false, h) }
    open func declineInvite() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in declineInvite { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    func answer(_ yes: Bool, _ h: ((Error?) -> Void)?) {
        change({ d, mine in
            var ps = d["participants"] as? [[String: Any]] ?? []
            guard let mine, (ps[mine]["status"] as? Int) == GKTurnBasedParticipant.Status.invited.rawValue else { return GKError(code: .turnBasedInvalidState) }
            ps[mine]["status"] = (yes ? GKTurnBasedParticipant.Status.active : .declined).rawValue
            d["participants"] = ps
            return nil
        }, done: h)
    }
    /// A new match with the same participants (the others are invited).
    open func rematch(completionHandler h: ((GKTurnBasedMatch?, Error?) -> Void)? = nil) {
        let r = GKMatchRequest()
        let others = _parts.compactMap { $0.player }.filter { !($0 === GKLocalPlayer.local) && !$0.isEqual(GKLocalPlayer.local) }
        r.minPlayers = max(2, _parts.count); r.maxPlayers = max(2, _parts.count); r.recipients = others
        GKTurnBasedMatch.find(for: r) { m, e in h?(m, e) }
    }
}

/// A score for `endMatchInTurn(withMatch:leaderboardScores:achievements:)`.
open class GKLeaderboardScore: NSObject {
    open var player: GKPlayer = GKLocalPlayer.local
    open var value = 0
    open var context = 0
    open var leaderboardID = ""
}

enum _GCTurns {
    static var dir: String { _GCNet.gamePath("turnbased") }
    static func file(_ id: String) -> String { (dir as NSString).appendingPathComponent("\(id).json") }
    static func read(_ id: String) -> [String: Any]? { _GCNet.readDict(file(id)) }
    static func save(_ m: [String: Any]) { _GCNet.write(file(m["id"] as? String ?? UUID().uuidString), m) }
    static func mine() -> [[String: Any]] {
        _GCNet.list(dir).filter { $0.hasSuffix(".json") }.compactMap { _GCNet.readDict((dir as NSString).appendingPathComponent($0)) }
            .filter { m in
                (m["participants"] as? [[String: Any]] ?? []).contains { ($0["pid"] as? String) == _GCNet.me }
                    && !(m["removed"] as? [String] ?? []).contains(_GCNet.me)
            }
            .sorted { ($0["created"] as? Double ?? 0) < ($1["created"] as? Double ?? 0) }
    }
    /// tells the other participants' apps the match changed
    static func notify(_ m: GKTurnBasedMatch, kind: String) {
        for p in m._parts { if let pid = p.pid, pid != _GCNet.me { _GCNet.post(pid, ["kind": kind, "match": m._id]) } }
    }
}

// MARK: - Turn-based UI

public protocol GKTurnBasedMatchmakerViewControllerDelegate: AnyObject {
    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController)
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error)
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFind match: GKTurnBasedMatch)
}
extension GKTurnBasedMatchmakerViewControllerDelegate {
    public func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFind match: GKTurnBasedMatch) {}
}

/// The turn-based matchmaker: the player's matches (your turn / their turn / ended) and Start a New Match. A chosen
/// or new match reaches the listeners as `player(_:receivedTurnEventFor:didBecomeActive: true)`.
open class GKTurnBasedMatchmakerViewController: UINavigationControllerStandIn {
    weak open var turnBasedMatchmakerDelegate: GKTurnBasedMatchmakerViewControllerDelegate?
    public let matchRequest: GKMatchRequest
    open var showExistingMatches = true
    open var matchmakingMode = 0
    public init(matchRequest request: GKMatchRequest) { matchRequest = request; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { matchRequest = GKMatchRequest(); super.init(nibName: nil, bundle: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let matches = showExistingMatches ? _GCTurns.mine().map(GKTurnBasedMatch._make) : []
        embed(_GCTurnBasedView(matches: matches, start: { [weak self] in
            guard let self else { return }
            GKTurnBasedMatch.find(for: self.matchRequest) { m, e in
                if let m { self.chose(m) } else if let e { self.turnBasedMatchmakerDelegate?.turnBasedMatchmakerViewController(self, didFailWithError: e) }
            }
        }, open: { [weak self] m in self?.chose(m) }, cancel: { [weak self] in
            guard let self else { return }
            if let d = self.turnBasedMatchmakerDelegate { d.turnBasedMatchmakerViewControllerWasCancelled(self) } else { self.dismiss(animated: true, completion: nil) }
        }))
    }
    func chose(_ m: GKTurnBasedMatch) {
        NSLog("isim GameKit: turn-based matchmaker chose match %@", m.matchID)
        turnBasedMatchmakerDelegate?.turnBasedMatchmakerViewController(self, didFind: m)
        MainActor.assumeIsolated { _GCEvents.deliver { l in l.player(GKLocalPlayer.local, receivedTurnEventFor: m, didBecomeActive: true) } }
    }
}

struct _GCTurnBasedView: View {
    let matches: [GKTurnBasedMatch]
    let start: () -> Void, open: (GKTurnBasedMatch) -> Void, cancel: () -> Void
    func line(_ m: GKTurnBasedMatch) -> String {
        if m.status == .ended { return "Ended" }
        if let c = m.currentParticipant {
            if c.pid == _GCNet.me { return "Your Turn" }
            return c.player.map { "\($0.alias)’s Turn" } ?? "Waiting for a Player"
        }
        return "Waiting"
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: start) { Text(verbatim: "Start a New Match").frame(maxWidth: .infinity) }.accessibilityIdentifier("gc-match-find")
                }
                if !matches.isEmpty {
                    Section {
                        ForEach(matches, id: \._id) { m in
                            Button { open(m) } label: {
                                let others = m.participants.compactMap { $0.player }.filter { !$0.isEqual(GKLocalPlayer.local) }.map { $0.alias }
                                _GCPlayerRow(name: others.first ?? "?", detail: (others.isEmpty ? "Waiting for a Player" : others.joined(separator: ", ")) + " · " + line(m))
                            }
                            .accessibilityIdentifier("gc-turn-match-\(m.matchID)")
                        }
                    } header: { Text(verbatim: "Matches") }
                }
            }
            .navigationTitle("Turn-Based Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() }.accessibilityIdentifier("gc-match-cancel") } }
        }
    }
}

// MARK: - Events

@MainActor enum _GCMultiplayer {
    static func installHandlers() {
        _GCNet.handlers["invite"] = { e in
            MainActor.assumeIsolated {
                let inv = GKInvite()
                inv._match = e["invite"] as? String ?? ""; inv._from = e["from"] as? String ?? ""; inv._group = e["group"] as? Int ?? 0
                let from = inv.sender.alias
                NSLog("isim GameKit: invite from %@", from)
                _GCBanner.show(title: "\(from) invited you to play", subtitle: _GCApp.name, kind: .other(from)) {
                    _GCEvents.deliver { l in l.player(GKLocalPlayer.local, didAccept: inv) }
                }
            }
        }
        for kind in ["turn", "matchEnded"] {
            _GCNet.handlers[kind] = { e in
                MainActor.assumeIsolated {
                    guard let rec = _GCTurns.read(e["match"] as? String ?? "") else { return }
                    let m = GKTurnBasedMatch._make(rec)
                    if kind == "matchEnded" {
                        NSLog("isim GameKit: turn-based match %@ ended", m.matchID)
                        _GCEvents.deliver { l in l.player(GKLocalPlayer.local, matchEnded: m) }
                    } else {
                        NSLog("isim GameKit: turn event for match %@ (%@)", m.matchID, m.currentParticipant?.pid == _GCNet.me ? "your turn" : "updated")
                        _GCEvents.deliver { l in l.player(GKLocalPlayer.local, receivedTurnEventFor: m, didBecomeActive: false) }
                    }
                }
            }
        }
    }
}
