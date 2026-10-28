// isim GameKit: game activities (iOS 26). On a device, activity definitions come from App Store Connect and players
// start activities from the Games app or a party link. On isim (adapted) the definitions are the `activities` of the
// app's isim-GameCenter.json, and `isim gamecenter <app> activity <id> [party code] [key=value ...]` plays the part of
// the Games app: the running game gets GKLocalPlayerListener.player(_:wantsToPlay:completionHandler:).
// Ending an activity posts its leaderboard scores and reports its achievements, like iOS.
import UIKit

@available(iOS 26.0, *)
public enum GKGameActivityPlayStyle: Int, Sendable { case unspecified = 0, synchronous = 1, asynchronous = 2 }

@available(iOS 26.0, *)

/// An activity the game offers (from the configuration's `activities`).
@available(iOS 26.0, *)
@objc(GKGameActivityDefinition) open class GKGameActivityDefinition: NSObject {
    let def: _GCActivityDef
    init(_ d: _GCActivityDef) { def = d }
    @objc open var identifier: String { def.id }
    @objc open var groupIdentifier: String? { def.group }
    @objc open var title: String { def.title }
    @objc open var details: String? { def.details }
    @objc open var defaultProperties: [String: String] { def.properties }
    @objc open var fallbackURL: URL? { def.fallbackURL.flatMap { URL(string: $0) } }
    @objc open var supportsPartyCode: Bool { def.partyCode }
    @objc open var maxPlayers: NSNumber? { def.maxPlayers.map { NSNumber(value: $0) } }
    @objc open var minPlayers: NSNumber? { def.minPlayers.map { NSNumber(value: $0) } }
    @objc open var supportsUnlimitedPlayers: Bool { def.unlimited }
    open var playStyle: GKGameActivityPlayStyle {
        switch def.playStyle { case "synchronous": return .synchronous; case "asynchronous": return .asynchronous; default: return .unspecified }
    }
    @objc open override var description: String { "<GKGameActivityDefinition \(identifier) \"\(title)\">" }
    @objc public class func loadGameActivityDefinitions(completionHandler: @escaping ([GKGameActivityDefinition]?, Error?) -> Void) {
        loadGameActivityDefinitions(IDs: nil, completionHandler: completionHandler)
    }
    @nonobjc public class func loadGameActivityDefinitions() async throws -> [GKGameActivityDefinition] { _GCConfig.activities.map(GKGameActivityDefinition.init) }
    @objc public class func loadGameActivityDefinitions(IDs: [String]?, completionHandler: @escaping ([GKGameActivityDefinition]?, Error?) -> Void) {
        let list = _GCConfig.activities.filter { IDs?.contains($0.id) ?? true }.map(GKGameActivityDefinition.init)
        DispatchQueue.main.async { completionHandler(list, nil) }
    }
    @nonobjc public class func loadGameActivityDefinitions(IDs: [String]?) async throws -> [GKGameActivityDefinition] {
        _GCConfig.activities.filter { IDs?.contains($0.id) ?? true }.map(GKGameActivityDefinition.init)
    }
    /// the achievements the activity is about
    @objc open func loadAchievementDescriptions(completionHandler: @escaping ([GKAchievementDescription]?, Error?) -> Void) {
        let list = _GCConfig.achievements.filter { def.achievements.contains($0.id) }.map(GKAchievementDescription.init)
        DispatchQueue.main.async { completionHandler(list, nil) }
    }
    @nonobjc open func loadAchievementDescriptions() async throws -> [GKAchievementDescription] {
        _GCConfig.achievements.filter { def.achievements.contains($0.id) }.map(GKAchievementDescription.init)
    }
    /// the leaderboards the activity is about
    @objc open func loadLeaderboards(completionHandler: @escaping ([GKLeaderboard]?, Error?) -> Void) {
        let list = def.leaderboards.map { GKLeaderboard.make($0) }
        DispatchQueue.main.async { completionHandler(list, nil) }
    }
    @nonobjc open func loadLeaderboards() async throws -> [GKLeaderboard] { def.leaderboards.map { GKLeaderboard.make($0) } }
    /// The activity's image from the configuration, or a generated placeholder.
    @objc open func loadImage(completionHandler: @escaping (UIImage?, Error?) -> Void) {
        let img = _GCImages.bundleImage(def.image) ?? _GCImages.leaderboard("activity-\(def.id)")
        DispatchQueue.main.async { completionHandler(img, nil) }
    }
    @nonobjc open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.bundleImage(def.image) ?? _GCImages.leaderboard("activity-\(def.id)") else { throw GKError._unsupported }
        return i
    }
}

/// One play of an activity: start, pause, resume, end; the scores and achievement progress it collects are posted
/// when it ends.
@available(iOS 26.0, *)
@objc(GKGameActivity) open class GKGameActivity: NSObject {
    /// An activity's state: initialized, active, paused or ended.
    @objc(GKGameActivityState) public enum State: UInt, Sendable { case initialized = 0, active = 1, paused = 2, ended = 4 }
    @objc public let identifier: String
    @objc public let activityDefinition: GKGameActivityDefinition
    @objc open var properties: [String: String]
    open private(set) var state: GKGameActivity.State = .initialized
    @objc open internal(set) var partyCode: String?
    @objc open var partyURL: URL? { partyCode.map { URL(string: "https://games.apple.com/party/\($0)")! } }
    @objc public let creationDate = Date()
    @objc open private(set) var startDate: Date?
    @objc open private(set) var lastResumeDate: Date?
    @objc open private(set) var endDate: Date?
    @objc var played: TimeInterval = 0
    /// time spent active (pauses excluded)
    @objc open var duration: TimeInterval { played + (state == .active ? lastResumeDate.map { Date().timeIntervalSince($0) } ?? 0 : 0) }
    @objc var scores: [String: GKLeaderboardScore] = [:]
    @objc var progress: [String: Double] = [:]
    @objc open var achievements: Set<GKAchievement> {
        Set(progress.map { id, p in let a = GKAchievement(identifier: id); a.percentComplete = p; return a })
    }
    @objc open var leaderboardScores: Set<GKLeaderboardScore> { Set(scores.values) }

    @objc public init(definition: GKGameActivityDefinition) {
        identifier = UUID().uuidString
        activityDefinition = definition
        properties = definition.defaultProperties
        super.init()
    }

    /// Party codes: two groups of four characters from this alphabet ("ABCD-2345").
    @objc public class var validPartyCodeAlphabet: [String] { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".map { String($0) } }
    @objc public class func isValidPartyCode(_ partyCode: String) -> Bool {
        let parts = partyCode.uppercased().split(separator: "-", omittingEmptySubsequences: false)
        let alphabet = Set(validPartyCodeAlphabet.joined())
        return parts.count == 2 && parts.allSatisfy { $0.count == 4 && $0.allSatisfy { alphabet.contains($0) } }
    }
    @objc static func newPartyCode() -> String {
        let a = validPartyCodeAlphabet
        return (0..<2).map { _ in (0..<4).map { _ in a.randomElement()! }.joined() }.joined(separator: "-")
    }
    /// Starts an activity of the definition (with a party code when it supports them).
    @objc public class func start(definition: GKGameActivityDefinition, partyCode: String) throws -> GKGameActivity {
        guard definition.supportsPartyCode, isValidPartyCode(partyCode) else { throw GKError(code: .invalidParameter) }
        let a = GKGameActivity(definition: definition)
        a.partyCode = partyCode.uppercased()
        a.start()
        return a
    }
    @objc public class func start(definition: GKGameActivityDefinition) throws -> GKGameActivity {
        let a = GKGameActivity(definition: definition)
        a.start()
        return a
    }
    /// Whether the Games app (on isim: `isim gamecenter … activity`) has asked to play an activity that no listener
    /// took yet.
    @objc public class func checkPendingGameActivityExistence(completionHandler: @escaping (Bool) -> Void) {
        let pending = _GCActivities.pending
        DispatchQueue.main.async { completionHandler(pending) }
    }
    @nonobjc public class func checkPendingGameActivityExistence() async -> Bool { _GCActivities.pending }

    @objc open func start() {
        guard state == .initialized else { return }
        if activityDefinition.supportsPartyCode && partyCode == nil { partyCode = GKGameActivity.newPartyCode() }
        state = .active; startDate = Date(); lastResumeDate = startDate
        NSLog("isim GameKit: activity %@ started%@", activityDefinition.identifier, partyCode.map { " (party code \($0))" } ?? "")
    }
    @objc open func pause() {
        guard state == .active else { return }
        played += lastResumeDate.map { Date().timeIntervalSince($0) } ?? 0
        state = .paused
        NSLog("isim GameKit: activity %@ paused", activityDefinition.identifier)
    }
    @objc open func resume() {
        guard state == .paused else { return }
        state = .active; lastResumeDate = Date()
        NSLog("isim GameKit: activity %@ resumed", activityDefinition.identifier)
    }
    /// Ends the activity: its scores are submitted and its achievement progress reported.
    @objc open func end() {
        guard state == .active || state == .paused else { return }
        if state == .active { played += lastResumeDate.map { Date().timeIntervalSince($0) } ?? 0 }
        state = .ended; endDate = Date()
        for s in scores.values { GKLeaderboard.submitScore(s.value, context: s.context, player: GKLocalPlayer.local, leaderboardIDs: [s.leaderboardID]) { _ in } }
        if !progress.isEmpty { GKAchievement.report(Array(achievements), withCompletionHandler: nil) }
        NSLog("isim GameKit: activity %@ ended after %.1f s (%ld scores, %ld achievements)", activityDefinition.identifier, played, scores.count, progress.count)
    }
    @objc(setScoreOnLeaderboard:toScore:context:) open func setScore(on leaderboard: GKLeaderboard, to score: Int, context: UInt) {
        let s = GKLeaderboardScore()
        s.leaderboardID = leaderboard.baseLeaderboardID; s.value = score; s.context = Int(context)
        scores[leaderboard.baseLeaderboardID] = s
    }
    @objc(setScoreOnLeaderboard:toScore:) open func setScore(on leaderboard: GKLeaderboard, to score: Int) { setScore(on: leaderboard, to: score, context: 0) }
    @objc(scoreOnLeaderboard:) open func score(on leaderboard: GKLeaderboard) -> GKLeaderboardScore? { scores[leaderboard.baseLeaderboardID] }
    @objc(removeScoresFromLeaderboards:) open func removeScores(from leaderboards: [GKLeaderboard]) { for b in leaderboards { scores[b.baseLeaderboardID] = nil } }
    @objc(setProgressOnAchievement:toPercentComplete:) open func setProgress(on achievement: GKAchievement, to percentComplete: Double) { progress[achievement.identifier] = min(100, max(0, percentComplete)) }
    @objc open func setAchievementCompleted(_ achievement: GKAchievement) { progress[achievement.identifier] = 100 }
    @objc(progressOnAchievement:) open func progress(on achievement: GKAchievement) -> Double { progress[achievement.identifier] ?? 0 }
    @objc open func removeAchievements(_ achievements: [GKAchievement]) { for a in achievements { progress[a.identifier] = nil } }
    /// A match request for the activity's player counts (nil for single-player activities).
    @objc open func makeMatchRequest() -> GKMatchRequest? {
        guard let max = activityDefinition.def.maxPlayers, max > 1 else { return nil }
        let r = GKMatchRequest()
        r.minPlayers = Swift.max(2, activityDefinition.def.minPlayers ?? 2); r.maxPlayers = Swift.min(4, max)
        if let code = partyCode { r.queueName = "party-\(code)" }
        return r
    }
    /// Finds a real-time match for the activity: players with the same party code are matched together.
    @objc open func findMatch(completionHandler: @escaping (GKMatch?, Error?) -> Void) {
        guard let r = makeMatchRequest() else { DispatchQueue.main.async { completionHandler(nil, GKError(code: .matchRequestInvalid)) }; return }
        r.playerGroup = partyCode.map { abs($0.hashValue % 1_000_000) + 1 } ?? 0
        GKMatchmaker.shared().findMatch(for: r, withCompletionHandler: completionHandler)
    }
    @nonobjc open func findMatch() async throws -> GKMatch {
        try await withCheckedThrowingContinuation { k in findMatch { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    @objc open override var description: String { "<GKGameActivity \(activityDefinition.identifier) state \(state.rawValue)\(partyCode.map { " party \($0)" } ?? "")>" }
}

enum _GCActivities {
    nonisolated(unsafe) static var pending = false
    /// `isim gamecenter … activity`: the player chose an activity in the Games app
    @MainActor static func requested(_ e: [String: Any]) {
        guard #available(iOS 26.0, *) else { NSLog("isim GameKit: game activities need iOS 26 (--os 26)"); return }
        let id = e["definition"] as? String ?? ""
        guard let d = _GCConfig.activities.first(where: { $0.id == id }) else { NSLog("isim GameKit: no game activity %@ in the configuration", id); return }
        let a = GKGameActivity(definition: GKGameActivityDefinition(d))
        for (k, v) in e["properties"] as? [String: String] ?? [:] { a.properties[k] = v }
        if let code = e["partyCode"] as? String, !code.isEmpty { a.partyCode = code.uppercased() }
        NSLog("isim GameKit: the player wants to play activity %@%@", id, a.partyCode.map { " (party code \($0))" } ?? "")
        pending = GKLocalPlayer.local.listeners.isEmpty
        _GCEvents.deliver { l in
            pending = false
            if let f = l.player(_:wantsToPlay:completionHandler:) {
                f(GKLocalPlayer.local, a) { handled in NSLog("isim GameKit: activity %@ %@", id, handled ? "handled" : "not handled") }
            } else { NSLog("isim GameKit: activity %@ not handled (no listener method)", id) }
        }
    }
}
