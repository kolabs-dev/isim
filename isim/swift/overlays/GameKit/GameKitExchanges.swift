// isim GameKit: turn-based exchanges (GKTurnBasedExchange, GKTurnBasedExchangeReply, saveMergedMatch), turn and
// exchange timeouts, and the matchmaking modes of the matchmaker sheets. Self-authored, iOS API names.
// Adapted: exchanges live in the match's file on isim's local Game Center network, next to the turn. Timeouts are
// enforced by the running apps of the match's participants (the first one to see an expired turn or exchange acts on
// it, under the match file's lock), so they take effect while one of those apps runs; iOS's servers do it always.
import SwiftUI

public enum GKMatchmakingMode: Int, Sendable {
    /// automatch and invites
    case `default` = 0
    /// only players nearby (on isim: the other devices browsing for nearby players or showing a nearby-only sheet)
    case nearbyOnly = 1
    case automatchOnly = 2
    case inviteOnly = 3
}

/// a day
public let GKExchangeTimeoutDefault: TimeInterval = 86400
/// never times out
public let GKExchangeTimeoutNone: TimeInterval = 31449600

public enum GKTurnBasedExchangeStatus: Int8, Sendable { case unknown = 0, active = 1, complete = 2, resolved = 3, canceled = 4 }

/// A request one participant sends others in a turn-based match, out of turn (a trade, a vote); the current
/// participant merges the answered ones into the match data.
@objc(GKTurnBasedExchange) @objcMembers open class GKTurnBasedExchange: NSObject, @unchecked Sendable {
    let _rec: [String: Any]
    let _match: GKTurnBasedMatch
    init(_ rec: [String: Any], match: GKTurnBasedMatch) { _rec = rec; _match = match }
    open var exchangeID: String { _rec["id"] as? String ?? "" }
    open var sender: GKTurnBasedParticipant { _match._participant(_rec["sender"] as? String) }
    open var recipients: [GKTurnBasedParticipant] { (_rec["recipients"] as? [String] ?? []).map { _match._participant($0) } }
    open var status: GKTurnBasedExchangeStatus { GKTurnBasedExchangeStatus(rawValue: Int8(_rec["status"] as? Int ?? 0)) ?? .unknown }
    open var message: String? { _rec["message"] as? String }
    open var data: Data? { (_rec["data"] as? String).flatMap { Data(base64Encoded: $0) } }
    open var sendDate: Date { Date(timeIntervalSince1970: _rec["sent"] as? Double ?? 0) }
    open var timeoutDate: Date? { (_rec["timeout"] as? Double).map { Date(timeIntervalSince1970: $0) } }
    open var completionDate: Date? { (_rec["completed"] as? Double).map { Date(timeIntervalSince1970: $0) } }
    open var replies: [GKTurnBasedExchangeReply]? {
        let r = _rec["replies"] as? [[String: Any]] ?? []
        return r.isEmpty ? nil : r.map { GKTurnBasedExchangeReply($0, match: _match) }
    }
    open override var description: String { "<GKTurnBasedExchange \(exchangeID) status \(status.rawValue) from \(sender.player?.alias ?? "-")>" }

    /// Withdraws an active or completed exchange (the sender only); the recipients are told.
    open func cancel(withLocalizableMessageKey key: String, arguments: [String], completionHandler h: ((Error?) -> Void)? = nil) {
        let id = exchangeID, msg = _GCExchanges.localized(key, arguments)
        var gone: [String: Any] = [:]
        _match.change({ d, _ in
            var xs = d["exchanges"] as? [[String: Any]] ?? []
            guard let i = xs.firstIndex(where: { ($0["id"] as? String) == id }) else { return GKError(code: .invalidParameter) }
            guard (xs[i]["sender"] as? String) == _GCNet.me else { return GKError(code: .turnBasedInvalidParticipant) }
            let st = xs[i]["status"] as? Int ?? 0
            guard st == Int(GKTurnBasedExchangeStatus.active.rawValue) || st == Int(GKTurnBasedExchangeStatus.complete.rawValue) else {
                return GKError(code: .turnBasedInvalidState)
            }
            xs[i]["status"] = Int(GKTurnBasedExchangeStatus.canceled.rawValue)
            if !msg.isEmpty { xs[i]["message"] = msg }
            gone = xs.remove(at: i)                      // a cancelled exchange leaves the match
            d["exchanges"] = xs
            return nil
        }, done: { [m = _match] e in
            if e == nil {
                NSLog("isim GameKit: turn-based: exchange %@ cancelled", id)
                _GCExchanges.notify(m, gone, what: "cancel", to: gone["recipients"] as? [String] ?? [])
            }
            h?(e)
        })
    }
    @nonobjc open func cancel(withLocalizableMessageKey key: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            cancel(withLocalizableMessageKey: key, arguments: arguments) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }

    /// Answers the exchange (a recipient, once); when every recipient answered, the sender and the current
    /// participant get the replies.
    open func reply(withLocalizableMessageKey key: String, arguments: [String], data: Data, completionHandler h: ((Error?) -> Void)? = nil) {
        let id = exchangeID, msg = _GCExchanges.localized(key, arguments), max = _match.exchangeDataMaximumSize
        var done: [String: Any]?
        _match.change({ d, _ in
            guard data.count <= max else { return GKError(code: .turnBasedMatchDataTooLarge) }
            var xs = d["exchanges"] as? [[String: Any]] ?? []
            guard let i = xs.firstIndex(where: { ($0["id"] as? String) == id }) else { return GKError(code: .invalidParameter) }
            var x = xs[i]
            let me = _GCNet.me
            guard (x["recipients"] as? [String] ?? []).contains(me) else { return GKError(code: .turnBasedInvalidParticipant) }
            var rs = x["replies"] as? [[String: Any]] ?? []
            guard (x["status"] as? Int) == Int(GKTurnBasedExchangeStatus.active.rawValue), !rs.contains(where: { ($0["pid"] as? String) == me }) else {
                return GKError(code: .turnBasedInvalidState)
            }
            rs.append(["pid": me, "message": msg, "data": data.base64EncodedString(), "date": Date().timeIntervalSince1970])
            x["replies"] = rs
            if rs.count >= (x["recipients"] as? [String] ?? []).count { _GCExchanges.complete(&x); done = x }
            xs[i] = x; d["exchanges"] = xs
            return nil
        }, done: { [m = _match] e in
            if e == nil, let x = done { _GCExchanges.completed(m, x) }
            h?(e)
        })
    }
    @nonobjc open func reply(withLocalizableMessageKey key: String, arguments: [String], data: Data) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            reply(withLocalizableMessageKey: key, arguments: arguments, data: data) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
}

/// One recipient's answer to an exchange.
@objc(GKTurnBasedExchangeReply) @objcMembers open class GKTurnBasedExchangeReply: NSObject, @unchecked Sendable {
    let _rec: [String: Any]
    let _match: GKTurnBasedMatch
    init(_ rec: [String: Any], match: GKTurnBasedMatch) { _rec = rec; _match = match }
    open var recipient: GKTurnBasedParticipant { _match._participant(_rec["pid"] as? String) }
    open var message: String? { (_rec["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } }
    open var data: Data? { (_rec["data"] as? String).flatMap { Data(base64Encoded: $0) } }
    open var replyDate: Date { Date(timeIntervalSince1970: _rec["date"] as? Double ?? 0) }
}

extension GKTurnBasedMatch {
    func _participant(_ pid: String?) -> GKTurnBasedParticipant {
        _parts.first { $0.pid != nil && $0.pid == pid } ?? { let p = GKTurnBasedParticipant(); if let pid { p._rec = ["pid": pid] }; return p }()
    }
    func _exchanges(_ keep: (GKTurnBasedExchangeStatus) -> Bool) -> [GKTurnBasedExchange]? {
        let xs = (_rec["exchanges"] as? [[String: Any]] ?? []).map { GKTurnBasedExchange($0, match: self) }.filter { keep($0.status) }
        return xs.isEmpty ? nil : xs
    }
    func _sendExchange(_ to: [GKTurnBasedParticipant], _ data: Data, _ msg: String, _ timeout: TimeInterval,
                       _ h: ((GKTurnBasedExchange?, Error?) -> Void)?) {
        let recipients = to.compactMap { $0.pid }
        let max = exchangeDataMaximumSize, most = exchangeMaxInitiatedExchangesPerPlayer
        let now = Date().timeIntervalSince1970
        var x: [String: Any] = ["id": UUID().uuidString, "sender": _GCNet.me, "recipients": recipients, "status": Int(GKTurnBasedExchangeStatus.active.rawValue),
                                "message": msg, "data": data.base64EncodedString(), "sent": now, "replies": [[String: Any]]()]
        if timeout < GKExchangeTimeoutNone { x["timeout"] = now + Swift.max(0, timeout) }
        change({ d, mine in
            guard data.count <= max else { return GKError(code: .turnBasedMatchDataTooLarge) }
            guard (d["ended"] as? Bool) != true else { return GKError(code: .turnBasedInvalidState) }
            let ps = d["participants"] as? [[String: Any]] ?? []
            let active = Set(ps.filter { ($0["status"] as? Int) == GKTurnBasedParticipant.Status.active.rawValue }.compactMap { $0["pid"] as? String })
            guard let mine, active.contains(_GCNet.me), !recipients.isEmpty, recipients.count == to.count,
                  recipients.allSatisfy({ active.contains($0) && $0 != _GCNet.me }) else { return GKError(code: .turnBasedInvalidParticipant) }
            _ = mine
            var xs = d["exchanges"] as? [[String: Any]] ?? []
            let open = xs.filter { ($0["sender"] as? String) == _GCNet.me && ($0["status"] as? Int) == Int(GKTurnBasedExchangeStatus.active.rawValue) }
            guard open.count < most else { return GKError(code: .turnBasedTooManySessions) }
            xs.append(x); d["exchanges"] = xs
            return nil
        }, done: { [self] e in
            if let e { h?(nil, e); return }
            NSLog("isim GameKit: turn-based: exchange %@ sent to %ld participants", x["id"] as? String ?? "", recipients.count)
            _GCExchanges.notify(self, x, what: "request", to: recipients)
            h?(GKTurnBasedExchange(x, match: self), nil)
        })
    }
    func _saveMerged(_ matchData: Data, _ ids: [String], _ h: ((Error?) -> Void)?) {
        change({ d, mine in
            if let e = GKTurnBasedMatch.dataTooLarge(matchData) { return e }
            guard let mine, (d["current"] as? Int) == mine, (d["ended"] as? Bool) != true else { return GKError(code: .turnBasedInvalidTurn) }
            var xs = d["exchanges"] as? [[String: Any]] ?? []
            for id in ids {
                guard let x = xs.first(where: { ($0["id"] as? String) == id }), (x["status"] as? Int) == Int(GKTurnBasedExchangeStatus.complete.rawValue) else {
                    return GKError(code: .turnBasedInvalidState)
                }
            }
            xs.removeAll { ids.contains($0["id"] as? String ?? "") }  // resolved exchanges leave the match
            d["exchanges"] = xs; d["data"] = matchData.base64EncodedString()
            return nil
        }, done: { [self] e in
            if e == nil {
                NSLog("isim GameKit: turn-based: %ld exchanges resolved", ids.count)
                _GCTurns.notify(self, kind: "turn")
            }
            h?(e)
        })
    }
}

enum _GCExchanges {
    static func localized(_ key: String, _ args: [String]) -> String {
        let f = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return args.reduce(f) { s, a in s.replacingOccurrences(of: "%@", with: a, options: [], range: s.range(of: "%@")) }
    }
    static func complete(_ x: inout [String: Any]) {
        x["status"] = Int(GKTurnBasedExchangeStatus.complete.rawValue); x["completed"] = Date().timeIntervalSince1970
    }
    /// an exchange every recipient answered (or that timed out) goes to its sender and the current participant
    static func completed(_ m: GKTurnBasedMatch, _ x: [String: Any]) {
        NSLog("isim GameKit: turn-based: exchange %@ complete", x["id"] as? String ?? "")
        var to = [x["sender"] as? String ?? ""]
        if let c = m.currentParticipant?.pid, !to.contains(c) { to.append(c) }
        notify(m, x, what: "replies", to: to)
    }
    /// tells participants' apps about an exchange (the local player's own app too, when it is one of them)
    static func notify(_ m: GKTurnBasedMatch, _ x: [String: Any], what: String, to pids: [String]) {
        for pid in pids where !pid.isEmpty { _GCNet.post(pid, ["kind": "exchange", "what": what, "match": m._id, "exchange": x]) }
    }

    @MainActor static func install() {
        _GCNet.handlers["exchange"] = { e in
            MainActor.assumeIsolated {
                guard let rec = _GCTurns.read(e["match"] as? String ?? ""), let xr = e["exchange"] as? [String: Any] else { return }
                let m = GKTurnBasedMatch._make(rec), x = GKTurnBasedExchange(xr, match: m)
                switch e["what"] as? String {
                case "request":
                    NSLog("isim GameKit: exchange request from %@", x.sender.player?.alias ?? "?")
                    _GCEvents.deliver { l in l.player(GKLocalPlayer.local, receivedExchangeRequest: x, for: m) }
                case "cancel":
                    NSLog("isim GameKit: exchange cancelled by %@", x.sender.player?.alias ?? "?")
                    _GCEvents.deliver { l in l.player(GKLocalPlayer.local, receivedExchangeCancellation: x, for: m) }
                case "replies":
                    NSLog("isim GameKit: exchange replies (%ld)", x.replies?.count ?? 0)
                    _GCEvents.deliver { l in l.player(GKLocalPlayer.local, receivedExchangeReplies: x.replies ?? [], forCompletedExchange: x, for: m) }
                default: break
                }
            }
        }
        _GCNet.tickers["turn-timeouts"] = { enforceTimeouts() }
    }

    nonisolated(unsafe) static var lastCheck = 0.0
    /// Passes expired turns on (to the next participant in the list `endTurn` got) and completes expired exchanges,
    /// in the local player's matches; checked once a second.
    static func enforceTimeouts() {
        let now = Date().timeIntervalSince1970
        guard now - lastCheck >= 1 else { return }
        lastCheck = now
        for m in _GCTurns.mine() where (m["ended"] as? Bool) != true {
            let id = m["id"] as? String ?? ""
            let ps = m["participants"] as? [[String: Any]] ?? []
            let cur = m["current"] as? Int ?? -1
            let turnExpired = cur >= 0 && cur < ps.count && (ps[cur]["timeout"] as? Double).map { $0 <= now } == true
            let expired = (m["exchanges"] as? [[String: Any]] ?? []).contains {
                ($0["status"] as? Int) == Int(GKTurnBasedExchangeStatus.active.rawValue) && ($0["timeout"] as? Double).map { $0 <= now } == true
            }
            guard turnExpired || expired else { continue }
            var passed: (from: String?, to: String?)?
            var finished: [[String: Any]] = []
            let rec = _GCNet.update(_GCTurns.file(id)) { d in
                guard !d.isEmpty, (d["ended"] as? Bool) != true else { return false }
                var changed = false
                var ps = d["participants"] as? [[String: Any]] ?? []
                let cur = d["current"] as? Int ?? -1
                if cur >= 0, cur < ps.count, let t = ps[cur]["timeout"] as? Double, t <= now {
                    var next = d["next"] as? [Int] ?? []
                    ps[cur]["timeout"] = nil
                    while let n = next.first {
                        next.removeFirst()
                        let s = n < ps.count ? ps[n]["status"] as? Int ?? 0 : GKTurnBasedParticipant.Status.done.rawValue
                        guard s != GKTurnBasedParticipant.Status.done.rawValue, s != GKTurnBasedParticipant.Status.declined.rawValue else { continue }
                        ps[n]["timeout"] = now + (d["turnTimeout"] as? Double ?? GKTurnTimeoutDefault)
                        d["current"] = n
                        passed = (ps[cur]["pid"] as? String, ps[n]["pid"] as? String)
                        break
                    }
                    if passed == nil { passed = (ps[cur]["pid"] as? String, ps[cur]["pid"] as? String) }   // the list ran out: the turn stays
                    d["next"] = next; d["participants"] = ps
                    changed = true
                }
                var xs = d["exchanges"] as? [[String: Any]] ?? []
                for i in xs.indices where (xs[i]["status"] as? Int) == Int(GKTurnBasedExchangeStatus.active.rawValue) && (xs[i]["timeout"] as? Double).map({ $0 <= now }) == true {
                    complete(&xs[i]); finished.append(xs[i]); changed = true
                }
                d["exchanges"] = xs
                if changed { d["version"] = (d["version"] as? Int ?? 0) + 1 }
                return changed
            }
            guard !rec.isEmpty else { continue }
            let match = GKTurnBasedMatch._make(rec)
            if let p = passed {
                NSLog("isim GameKit: turn-based: %@'s turn timed out, now %@", p.from.flatMap { _GCNet.player($0)?.alias } ?? "a player",
                      p.to.flatMap { _GCNet.player($0)?.alias } ?? "nobody")
                for pid in match._parts.compactMap({ $0.pid }) { _GCNet.post(pid, ["kind": "turn", "match": id]) }
            }
            for x in finished { completed(match, x) }
        }
    }
}

/// what the matchmaker sheets offer in each mode
enum _GCMatchmaking {
    static func invitable(_ mode: GKMatchmakingMode) -> [GKPlayer] {
        if mode == .nearbyOnly { return _GCRealtime.nearbyPlayers().map(GKPlayer._make).sorted { $0.alias < $1.alias } }
        return _GCNet.friendIDs().map(GKPlayer._make).filter { $0.isInvitable }.sorted { $0.alias < $1.alias }
    }
    static func note(_ mode: GKMatchmakingMode) -> String {
        switch mode {
        case .automatchOnly: return "Find players. Players are the other isim devices running this game on this computer."
        case .inviteOnly: return "Invite friends to play."
        case .nearbyOnly: return "Invite players nearby: the other isim devices looking for nearby players in this game."
        default: return "Find players, or invite friends. Players are the other isim devices running this game on this computer."
        }
    }
}

extension _GCRealtime {
    static func nearbyFile(_ pid: String) -> String { (dir("nearby") as NSString).appendingPathComponent("\(pid).json") }
    /// players whose devices browse for nearby players (or show a nearby-only sheet) right now
    static func nearbyPlayers() -> [String] {
        let now = Date().timeIntervalSince1970
        return _GCNet.list(dir("nearby")).filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.filter { p in
            p != _GCNet.me && now - (_GCNet.readDict(nearbyFile(p))?["seen"] as? Double ?? 0) < 2
        }
    }
    /// shows the local player as nearby while a nearby-only sheet is up
    static func advertiseNearby(_ on: Bool) {
        if on {
            _GCNet.tickers["nearby-sheet"] = { _GCNet.write(nearbyFile(_GCNet.me), ["seen": Date().timeIntervalSince1970]) }
        } else {
            _GCNet.tickers["nearby-sheet"] = nil
            if _GCNet.tickers["nearby"] == nil { _GCNet.remove(nearbyFile(_GCNet.me)) }
        }
    }
}
