// isim GameKit, iOS 26 and the rest of the API (issue #394): release states, challenge definitions, activity metadata
// on leaderboards and achievements, the access point's destinations, identity verification signatures (adapted: signed
// with a key kept in the device data), matched players and queue activity for server-hosted games, and the legacy
// match / voice / session types. Voice chat is unavailable, as in Apple's Simulator.
import UIKit
internal import CryptoKit

// MARK: - Release states

/// Whether a leaderboard, achievement, activity or challenge is released to players or only to testers.
@available(iOS 18.4, *)
public struct GKReleaseState: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let released = GKReleaseState(rawValue: 1)
    public static let prereleased = GKReleaseState(rawValue: 2)
    static func of(_ prereleased: Bool) -> GKReleaseState { prereleased ? .prereleased : .released }
}

extension GKLeaderboard {
    var _def: _GCBoardDef { _GCConfig.board(baseLeaderboardID) }
    /// the description from App Store Connect (isim-GameCenter.json: "description")
    @objc open var leaderboardDescription: String { _def.details }
    @objc open var isHidden: Bool { _def.hidden }
    @available(iOS 18.4, *) public var releaseState: GKReleaseState { .of(_def.prereleased) }
    @available(iOS 18.4, *) @objc(releaseState) var _isimReleaseState: UInt { releaseState.rawValue }
    /// the game activity the leaderboard belongs to
    @available(iOS 26.0, *) @objc open var activityIdentifier: String { _def.activity }
    @available(iOS 26.0, *) @objc open var activityProperties: [String: String] { _def.activityProperties }
}

extension GKAchievementDescription {
    var _def: _GCAchievementDef? { _GCConfig.achievement(identifier) }
    @available(iOS 26.0, *) @objc open var activityIdentifier: String { _def?.activity ?? "" }
    @available(iOS 26.0, *) @objc open var activityProperties: [String: String] { _def?.activityProperties ?? [:] }
}

@available(iOS 26.0, *)
extension GKGameActivityDefinition {
    public var releaseState: GKReleaseState { .of(def.prereleased) }
    @objc(releaseState) var _isimReleaseState: UInt { releaseState.rawValue }
    /// the number of players the activity supports (nil: not set)
    public var playerRange: (any RangeExpression<Int>)? {
        if supportsUnlimitedPlayers { return (def.minPlayers ?? 1)... }
        guard let lo = def.minPlayers, let hi = def.maxPlayers, lo <= hi else { return nil }
        return lo...hi
    }
    @objc(playerRange) var _isimPlayerRange: NSRange {
        guard let lo = def.minPlayers else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(location: lo, length: supportsUnlimitedPlayers ? Int.max - lo : max(0, (def.maxPlayers ?? lo) - lo + 1))
    }
}

// MARK: - Challenge definitions (iOS 26)

/// A challenge players can start from the Games app, on one of the game's leaderboards (isim-GameCenter.json:
/// "challenges").
@available(iOS 26.0, *)
@objc(GKChallengeDefinition) open class GKChallengeDefinition: NSObject, @unchecked Sendable {
    let def: _GCChallengeDef
    init(_ d: _GCChallengeDef) { def = d }
    @objc open var identifier: String { def.id }
    @objc open var groupIdentifier: String? { def.group }
    @objc open var title: String { def.title }
    @objc open var details: String? { def.details }
    @objc open var durationOptions: [DateComponents] { def.durations }
    @objc open var isRepeatable: Bool { def.repeatable }
    @objc open var leaderboard: GKLeaderboard? { def.leaderboard.map { GKLeaderboard.make($0) } }
    public var releaseState: GKReleaseState { .of(def.prereleased) }
    @objc(releaseState) var _isimReleaseState: UInt { releaseState.rawValue }
    open override var description: String { "<GKChallengeDefinition \(identifier): \(title)>" }

    @objc open class func loadChallengeDefinitions(completionHandler: @escaping ([GKChallengeDefinition]?, Error?) -> Void) {
        let list = _GCConfig.challenges.map(GKChallengeDefinition.init)
        DispatchQueue.main.async { completionHandler(list, nil) }
    }
    @nonobjc open class var all: [GKChallengeDefinition] { get async throws { _GCConfig.challenges.map(GKChallengeDefinition.init) } }
    /// whether players are taking part in this challenge now (isim-GameCenter.json: "active")
    @objc open func hasActiveChallenges(completionHandler: @escaping (Bool, Error?) -> Void) {
        let a = def.active
        DispatchQueue.main.async { completionHandler(a, nil) }
    }
    @nonobjc open var hasActiveChallenges: Bool { get async throws { def.active } }
    @objc open func loadImage(completionHandler: @escaping (UIImage?, Error?) -> Void) {
        let img = _GCImages.leaderboard(def.leaderboard ?? def.id)
        DispatchQueue.main.async { completionHandler(img, nil) }
    }
    @nonobjc open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.leaderboard(def.leaderboard ?? def.id) else { throw GKError._unsupported }
        return i
    }
}

// MARK: - Access point

nonisolated(unsafe) private var _gkParentWindowKey = 0

extension GKAccessPoint {
    /// the window the access point appears in (nil: the key window)
    @objc open var parentWindow: UIWindow? {
        get { objc_getAssociatedObject(self, &_gkParentWindowKey) as? UIWindow }
        set { objc_setAssociatedObject(self, &_gkParentWindowKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
    /// Opens the Games overlay on the player's challenges.
    @available(iOS 26.0, *) @objc(triggerForChallengesWithHandler:) open func triggerForChallenges(handler: (() -> Void)? = nil) { trigger(state: .challenges) { handler?() } }
    /// Opens the Games overlay on adding friends.
    @available(iOS 26.0, *) @objc(triggerForFriendingWithHandler:) open func triggerForFriending(handler: (() -> Void)? = nil) { trigger(state: .localPlayerFriendsList) { handler?() } }
    /// Opens the Games overlay on playing together (isim: the dashboard).
    @available(iOS 26.0, *) @objc(triggerForPlayTogetherWithHandler:) open func triggerForPlayTogether(handler: (() -> Void)? = nil) { trigger(state: .dashboard) { handler?() } }
    /// Opens the Games overlay on Apple Arcade (isim: the dashboard).
    @available(iOS 26.0, *) @objc(triggerForArcadeWithHandler:) open func triggerForArcade(handler: (() -> Void)? = nil) { trigger(state: .dashboard) { handler?() } }
}

// MARK: - Achievements, activities, invites

extension GKAchievement {
    /// the player the achievement belongs to (isim: the local player)
    @objc open var player: GKPlayer { GKLocalPlayer.local }
    /// Of `players`, those who can be challenged to earn this achievement: the ones who have not.
    @objc(selectChallengeablePlayers:withCompletionHandler:)
    open func selectChallengeablePlayers(_ players: [GKPlayer], withCompletionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) {
        let id = identifier
        let list = players.filter { !_GCAchievementsOf.completed($0, id) }
        DispatchQueue.main.async { h?(list, nil) }
    }
    @nonobjc public func selectChallengeablePlayers(_ players: [GKPlayer]) async throws -> [GKPlayer] {
        let id = identifier
        return players.filter { !_GCAchievementsOf.completed($0, id) }
    }
}

/// other players' achievements, as they report them on the local network (games/<bundle id>/achievements/<player>.json)
enum _GCAchievementsOf {
    static func completed(_ p: GKPlayer, _ id: String) -> Bool {
        guard let d = _GCNet.readDict(_GCNet.gamePath("achievements", "\(p._id).json")) else { return false }
        return (d[id] as? Double ?? 0) >= 100
    }
}

@available(iOS 26.0, *)
extension GKGameActivity {
    /// Finds players for a hosted match of this activity (its party, through isim's local matchmaking).
    @objc(findPlayersForHostedMatchWithCompletionHandler:)
    open func findPlayersForHostedMatch(completionHandler: @escaping ([GKPlayer]?, Error?) -> Void) {
        let r = GKMatchRequest()
        r.minPlayers = activityDefinition.minPlayers.map { Int(truncating: $0) } ?? 2
        r.maxPlayers = activityDefinition.maxPlayers.map { Int(truncating: $0) } ?? 4
        r.queueName = "activity.\(activityDefinition.identifier).\(partyCode ?? "")"
        GKMatchmaker.shared().findPlayers(forHostedRequest: r) { p, e in completionHandler(p, e) }
    }
    @nonobjc public func findPlayersForHostedMatch() async throws -> [GKPlayer] {
        try await withCheckedThrowingContinuation { k in findPlayersForHostedMatch { p, e in if let p { k.resume(returning: p) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
}

extension GKInviteRecipientResponse {
    public static var inviteeResponseAccepted: GKInviteRecipientResponse { .accepted }
    public static var inviteeResponseDeclined: GKInviteRecipientResponse { .declined }
    public static var inviteeResponseFailed: GKInviteRecipientResponse { .failed }
    public static var inviteeResponseIncompatible: GKInviteRecipientResponse { .incompatible }
    public static var inviteeResponseUnableToConnect: GKInviteRecipientResponse { .unableToConnect }
    public static var inviteeResponseNoAnswer: GKInviteRecipientResponse { .noAnswer }
}

// MARK: - Local player: identity verification, default leaderboard

extension GKLocalPlayer {
    /// whether the friend request composer is on screen
    @MainActor @objc open var isPresentingFriendRequestViewController: Bool {
        var vc = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let v = vc { if v is GKFriendRequestComposeViewController { return true }; vc = v.presentedViewController }
        return false
    }

    /// The game's default leaderboard for this player (set with setDefaultLeaderboardIdentifier; else the first one in
    /// isim-GameCenter.json).
    @objc open func loadDefaultLeaderboardIdentifier(completionHandler: ((String?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { completionHandler?(nil, GKError._notAuthenticated) }; return }
        let id = UserDefaults.standard.string(forKey: "ISIMGameCenterDefaultLeaderboard") ?? _GCConfig.boards.first?.id
        DispatchQueue.main.async { completionHandler?(id, nil) }
    }
    @nonobjc public func loadDefaultLeaderboardIdentifier() async throws -> String? {
        try await withCheckedThrowingContinuation { k in loadDefaultLeaderboardIdentifier { id, e in if let e { k.resume(throwing: e) } else { k.resume(returning: id) } } }
    }
    @objc open func setDefaultLeaderboardIdentifier(_ leaderboardIdentifier: String, completionHandler: ((Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { completionHandler?(GKError._notAuthenticated) }; return }
        UserDefaults.standard.set(leaderboardIdentifier, forKey: "ISIMGameCenterDefaultLeaderboard")
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    @nonobjc public func setDefaultLeaderboardIdentifier(_ leaderboardIdentifier: String) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            setDefaultLeaderboardIdentifier(leaderboardIdentifier) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }

    /// Items a game server checks the player with: the URL of the public key's certificate, a signature, the salt and
    /// the timestamp (milliseconds). The signed data is the player's teamPlayerID, the bundle identifier, the
    /// timestamp (big-endian UInt64) and the salt, as on iOS. Adapted: Apple signs with RSA and serves its
    /// certificate from static.gc.apple.com; isim signs with ECDSA P-256 (SHA-256, X9.62 signature) with a key kept
    /// in the device data, and the URL is a file URL of its self-signed certificate (DER).
    @objc(fetchItemsForIdentityVerificationSignature:)
    open func fetchItems(forIdentityVerificationSignature completionHandler: ((URL?, Data?, Data?, UInt64, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { completionHandler?(nil, nil, nil, 0, GKError._notAuthenticated) }; return }
        let player = teamPlayerID, bundle = Bundle.main.bundleIdentifier ?? ""
        DispatchQueue.global().async {
            guard let id = _GCIdentity.identity() else {
                DispatchQueue.main.async { completionHandler?(nil, nil, nil, 0, GKError(code: .unknown)) }
                return
            }
            let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
            var salt = [UInt8](repeating: 0, count: 32)
            for i in salt.indices { salt[i] = UInt8.random(in: 0...255) }
            var payload = Data(player.utf8) + Data(bundle.utf8)
            withUnsafeBytes(of: timestamp.bigEndian) { payload.append(contentsOf: $0) }
            payload.append(contentsOf: salt)
            let signature = (try? id.key.signature(for: payload).derRepresentation) ?? Data()
            NSLog("isim GameKit: identity verification signature for %@ (%ld bytes)", player, signature.count)
            DispatchQueue.main.async { completionHandler?(id.certURL, signature, Data(salt), timestamp, nil) }
        }
    }
    @nonobjc public func fetchItemsForIdentityVerificationSignature() async throws -> (URL, Data, Data, UInt64) {
        try await withCheckedThrowingContinuation { k in
            fetchItems { url, sig, salt, ts, e in
                if let url, let sig, let salt { k.resume(returning: (url, sig, salt, ts)) } else { k.resume(throwing: e ?? GKError(code: .unknown)) }
            }
        }
    }
}

/// the device's identity verification key and certificate (device data: Library/GameCenter/identity-key.pem,
/// identity.cer)
enum _GCIdentity {
    struct Identity { let key: P256.Signing.PrivateKey; let certURL: URL }
    nonisolated(unsafe) static var cached: Identity?
    static let lock = NSLock()
    static var dir: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/GameCenter")
    }
    static func identity() -> Identity? {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        let keyPath = (dir as NSString).appendingPathComponent("identity-key.pem"), certPath = (dir as NSString).appendingPathComponent("identity.cer")
        let key: P256.Signing.PrivateKey
        if let pem = try? String(contentsOfFile: keyPath, encoding: .utf8), let k = try? P256.Signing.PrivateKey(pemRepresentation: pem),
           FileManager.default.fileExists(atPath: certPath) {
            key = k
        } else {
            key = P256.Signing.PrivateKey()
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            guard (try? key.pemRepresentation.write(toFile: keyPath, atomically: true, encoding: .utf8)) != nil,
                  FileManager.default.createFile(atPath: certPath, contents: Data(certificate(key))) else { return nil }
            NSLog("isim GameKit: made the device's identity verification key (%@)", certPath)
        }
        cached = Identity(key: key, certURL: URL(fileURLWithPath: certPath))
        return cached
    }

    // a self-signed X.509 certificate (DER) for the key, CN "isim Game Center Identity Verification"
    static func tlv(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] {
        let n = body.count
        let len: [UInt8] = n < 0x80 ? [UInt8(n)] : n < 0x100 ? [0x81, UInt8(n)] : [0x82, UInt8(n >> 8), UInt8(n & 0xff)]
        return [tag] + len + body
    }
    static func seq(_ items: [UInt8]...) -> [UInt8] { tlv(0x30, items.flatMap { $0 }) }
    static func oid(_ bytes: [UInt8]) -> [UInt8] { tlv(0x06, bytes) }
    static let ecdsaWithSHA256: [UInt8] = [0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02]
    static func time(_ d: Date) -> [UInt8] {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyyMMddHHmmss'Z'"
        return tlv(0x18, Array(f.string(from: d).utf8))
    }
    static func certificate(_ key: P256.Signing.PrivateKey) -> [UInt8] {
        let name = seq(tlv(0x31, seq(oid([0x55, 0x04, 0x03]), tlv(0x0c, Array("isim Game Center Identity Verification".utf8)))))
        var serial = [UInt8](repeating: 0, count: 8); for i in serial.indices { serial[i] = UInt8.random(in: 1...127) }
        let now = Date()
        let tbs = seq(tlv(0xa0, tlv(0x02, [2])), tlv(0x02, serial), seq(oid(ecdsaWithSHA256)), name,
                      seq(time(now.addingTimeInterval(-86400)), time(now.addingTimeInterval(20 * 365 * 86400))), name,
                      Array(key.publicKey.derRepresentation))
        let sig = (try? key.signature(for: Data(tbs)).derRepresentation) ?? Data()
        return seq(tbs, seq(oid(ecdsaWithSHA256)), tlv(0x03, [0] + Array(sig)))
    }
}

// MARK: - Matchmaking: server-hosted matches, queues, group activities

/// The kind of match a request is for.
@objc public enum GKMatchType: UInt, Sendable {
    case peerToPeer = 0
    case hosted = 1
    case turnBased = 2
}

/// Players matched for a game the developer's server hosts (findMatchedPlayers), with the properties each sent.
@available(iOS 17.2, *)
@objc(GKMatchedPlayers) open class GKMatchedPlayers: NSObject, @unchecked Sendable {
    @objc open private(set) var players: [GKPlayer] = []
    @objc open private(set) var properties: [String: Any]?
    @objc open private(set) var playerProperties: [GKPlayer: [String: Any]]?
    init(players: [GKPlayer], properties: [String: Any]?, playerProperties: [GKPlayer: [String: Any]]?) {
        self.players = players; self.properties = properties; self.playerProperties = playerProperties
    }
    open override var description: String { "<GKMatchedPlayers \(players.map(\.alias).joined(separator: ", "))>" }
}

extension GKMatchmaker {
    /// Finds players for a server-hosted game in the request's queue; the result includes the local player.
    @available(iOS 17.2, *) @objc(findMatchedPlayers:withCompletionHandler:)
    open func findMatchedPlayers(_ request: GKMatchRequest, withCompletionHandler h: @escaping (GKMatchedPlayers?, Error?) -> Void) {
        findPlayers(forHostedRequest: request) { others, e in
            guard let others else { h(nil, e); return }
            let all = [GKLocalPlayer.local as GKPlayer] + others
            var pp: [GKPlayer: [String: Any]] = [:]
            if let mine = request.properties { pp[GKLocalPlayer.local] = mine }
            h(GKMatchedPlayers(players: all, properties: request.properties, playerProperties: pp.isEmpty ? nil : pp), nil)
        }
    }
    @available(iOS 17.2, *) @nonobjc public func findMatchedPlayers(_ request: GKMatchRequest) async throws -> GKMatchedPlayers {
        try await withCheckedThrowingContinuation { k in findMatchedPlayers(request) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// How many players are looking for a match in a queue now (isim: the tickets on the local network).
    @objc(queryQueueActivity:withCompletionHandler:)
    open func queryQueueActivity(_ queueName: String, withCompletionHandler h: ((Int, Error?) -> Void)? = nil) {
        let dir = _GCRealtime.dir("tickets"), now = Date().timeIntervalSince1970
        let n = _GCNet.list(dir).filter { $0.hasSuffix(".json") }
            .compactMap { _GCNet.readDict((dir as NSString).appendingPathComponent($0)) }
            .filter { ($0["queue"] as? String ?? "") == queueName && $0["match"] == nil && now - ($0["seen"] as? Double ?? 0) < 3 }.count
        NSLog("isim GameKit: queue %@ has %ld players looking", queueName, n)
        DispatchQueue.main.async { h?(n, nil) }
    }
    @nonobjc public func queryQueueActivity(_ queueName: String) async throws -> Int {
        await withCheckedContinuation { k in queryQueueActivity(queueName) { n, _ in k.resume(returning: n) } }
    }
    /// Finds players in the player's SharePlay group. Stub: isim's Game Center does not see SharePlay calls, so no
    /// player is found.
    @objc(startGroupActivityWithPlayerHandler:)
    open func startGroupActivity(playerHandler handler: @escaping (GKPlayer) -> Void) {
        NSLog("isim GameKit: startGroupActivity: no SharePlay group on isim's local Game Center")
    }
    @objc open func stopGroupActivity() {}
}

// MARK: - Turn-based reminders

extension GKTurnBasedMatch {
    /// Reminds participants that it is their turn (isim: logged on their devices).
    @objc(sendReminderToParticipants:localizableMessageKey:arguments:completionHandler:)
    open func sendReminder(to participants: [GKTurnBasedParticipant], localizableMessageKey key: String, arguments: [String],
                           completionHandler: ((Error?) -> Void)? = nil) {
        let text = String(format: Bundle.main.localizedString(forKey: key, value: key, table: nil), arguments: arguments.map { $0 as CVarArg })
        for p in participants { if let id = p.player?._id { _GCNet.post(id, ["kind": "reminder", "from": _GCNet.me, "message": text]) } }
        NSLog("isim GameKit: turn-based: reminded %ld participant(s): %@", participants.count, text)
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    @nonobjc public func sendReminder(to participants: [GKTurnBasedParticipant], localizableMessageKey key: String, arguments: [String]) async throws {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in sendReminder(to: participants, localizableMessageKey: key, arguments: arguments) { _ in k.resume() } }
    }
}

// MARK: - Legacy session and voice types

/// GKSession's transport (deprecated framework types, kept for source compatibility).
@objc public enum GKTransportType: Int, Sendable { case unreliable = 0, reliable = 1 }
/// GKSession's peer connection state.
@objc public enum GKConnectionState: Int, Sendable { case notConnected = 0, connected = 1 }

/// Voice chat between a match's players. isim (like Apple's Simulator) has no voice chat: isVoIPAllowed() is false
/// and starting it does nothing.
@objc(GKVoiceChat) open class GKVoiceChat: NSObject, @unchecked Sendable {
    @objc(GKVoiceChatPlayerState) public enum PlayerState: Int, Sendable {
        case connected = 0, disconnected = 1, speaking = 2, silent = 3, connecting = 4
    }
    @objc public let name: String
    @objc open private(set) var players: [GKPlayer]
    @objc open var isActive = false
    @objc open var volume: Float = 1
    @objc open var playerVoiceChatStateDidChangeHandler: (GKPlayer, PlayerState) -> Void = { _, _ in }
    init(name: String, players: [GKPlayer]) { self.name = name; self.players = players }
    @objc open func start() { NSLog("isim GameKit: voice chat %@ is not available on isim", name) }
    @objc open func stop() { isActive = false }
    @objc open func setPlayer(_ player: GKPlayer, muted isMuted: Bool) {}
    @objc open class func isVoIPAllowed() -> Bool { false }
}

extension GKMatch {
    /// A voice channel for the match's players (isim: never connects).
    @objc(voiceChatWithName:) open func voiceChat(withName name: String) -> GKVoiceChat? { GKVoiceChat(name: name, players: players) }
}
