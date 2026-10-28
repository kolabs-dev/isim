// isim GameKit: the Objective-C interface (sdk-src/Frameworks/GameKit, issue #559). The classes are @objc(GK…) and
// @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are internal
// Objective-C entry points, under Apple's selectors, for what uses Swift-only types: the enums (their raw values in
// Objective-C), and the delegate and listener protocols, which are Swift protocols here. An Objective-C delegate or
// listener is held through a Swift box that forwards to Apple's Objective-C protocol of the same name (declared below
// as Objective-C sees it), weakly like iOS.
import UIKit
import ObjectiveC

// MARK: - Apple's Objective-C protocols

@objc(GKMatchDelegate) protocol _GKObjCMatchDelegate: NSObjectProtocol {
    @objc(match:didReceiveData:fromRemotePlayer:) optional func match(_ m: GKMatch, didReceiveData data: Data, fromRemotePlayer p: GKPlayer)
    @objc(match:didReceiveData:forRecipient:fromRemotePlayer:)
    optional func match(_ m: GKMatch, didReceiveData data: Data, forRecipient r: GKPlayer, fromRemotePlayer p: GKPlayer)
    @objc(match:player:didChangeConnectionState:) optional func match(_ m: GKMatch, player: GKPlayer, didChangeConnectionState s: Int)
    @objc(match:didFailWithError:) optional func match(_ m: GKMatch, didFailWithError e: Error?)
    @objc(match:shouldReinviteDisconnectedPlayer:) optional func match(_ m: GKMatch, shouldReinviteDisconnectedPlayer p: GKPlayer) -> Bool
}
@objc(GKMatchmakerViewControllerDelegate) protocol _GKObjCMatchmakerDelegate: NSObjectProtocol {
    @objc(matchmakerViewControllerWasCancelled:) optional func matchmakerViewControllerWasCancelled(_ vc: GKMatchmakerViewController)
    @objc(matchmakerViewController:didFailWithError:) optional func matchmakerViewController(_ vc: GKMatchmakerViewController, didFailWithError e: Error)
    @objc(matchmakerViewController:didFindMatch:) optional func matchmakerViewController(_ vc: GKMatchmakerViewController, didFindMatch m: GKMatch)
    @objc(matchmakerViewController:didFindHostedPlayers:)
    optional func matchmakerViewController(_ vc: GKMatchmakerViewController, didFindHostedPlayers p: [GKPlayer])
    @objc(matchmakerViewController:hostedPlayerDidAccept:)
    optional func matchmakerViewController(_ vc: GKMatchmakerViewController, hostedPlayerDidAccept p: GKPlayer)
}
@objc(GKTurnBasedMatchmakerViewControllerDelegate) protocol _GKObjCTurnBasedMatchmakerDelegate: NSObjectProtocol {
    @objc(turnBasedMatchmakerViewControllerWasCancelled:)
    optional func turnBasedMatchmakerViewControllerWasCancelled(_ vc: GKTurnBasedMatchmakerViewController)
    @objc(turnBasedMatchmakerViewController:didFailWithError:)
    optional func turnBasedMatchmakerViewController(_ vc: GKTurnBasedMatchmakerViewController, didFailWithError e: Error)
    @objc(turnBasedMatchmakerViewController:didFindMatch:)
    optional func turnBasedMatchmakerViewController(_ vc: GKTurnBasedMatchmakerViewController, didFindMatch m: GKTurnBasedMatch)
}
@objc(GKFriendRequestComposeViewControllerDelegate) protocol _GKObjCFriendRequestDelegate: NSObjectProtocol {
    @objc(friendRequestComposeViewControllerDidFinish:) optional func friendRequestComposeViewControllerDidFinish(_ vc: GKFriendRequestComposeViewController)
}
// MARK: - boxes

final class _GKMatchDelegateBox: GKMatchDelegate {
    weak var t: _GKObjCMatchDelegate?
    init(_ t: _GKObjCMatchDelegate) { self.t = t }
    func match(_ m: GKMatch, didReceive data: Data, fromRemotePlayer p: GKPlayer) { t?.match?(m, didReceiveData: data, fromRemotePlayer: p) }
    func match(_ m: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) { t?.match?(m, player: player, didChangeConnectionState: state.rawValue) }
    func match(_ m: GKMatch, didFailWithError error: Error?) { t?.match?(m, didFailWithError: error) }
    func match(_ m: GKMatch, didReceive data: Data, forRecipient r: GKPlayer, fromRemotePlayer p: GKPlayer) {
        if let f = t?.match(_:didReceiveData:forRecipient:fromRemotePlayer:) { f(m, data, r, p) } else { t?.match?(m, didReceiveData: data, fromRemotePlayer: p) }
    }
    func match(_ m: GKMatch, shouldReinviteDisconnectedPlayer p: GKPlayer) -> Bool { t?.match?(m, shouldReinviteDisconnectedPlayer: p) ?? false }
}
final class _GKMatchmakerDelegateBox: GKMatchmakerViewControllerDelegate {
    weak var t: _GKObjCMatchmakerDelegate?
    init(_ t: _GKObjCMatchmakerDelegate) { self.t = t }
    func matchmakerViewControllerWasCancelled(_ vc: GKMatchmakerViewController) { t?.matchmakerViewControllerWasCancelled?(vc) }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, didFailWithError e: Error) { t?.matchmakerViewController?(vc, didFailWithError: e) }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, didFind m: GKMatch) { t?.matchmakerViewController?(vc, didFindMatch: m) }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, didFindHostedPlayers p: [GKPlayer]) { t?.matchmakerViewController?(vc, didFindHostedPlayers: p) }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, hostedPlayerDidAccept p: GKPlayer) { t?.matchmakerViewController?(vc, hostedPlayerDidAccept: p) }
}
final class _GKTurnBasedMatchmakerDelegateBox: GKTurnBasedMatchmakerViewControllerDelegate {
    weak var t: _GKObjCTurnBasedMatchmakerDelegate?
    init(_ t: _GKObjCTurnBasedMatchmakerDelegate) { self.t = t }
    func turnBasedMatchmakerViewControllerWasCancelled(_ vc: GKTurnBasedMatchmakerViewController) { t?.turnBasedMatchmakerViewControllerWasCancelled?(vc) }
    func turnBasedMatchmakerViewController(_ vc: GKTurnBasedMatchmakerViewController, didFailWithError e: Error) {
        t?.turnBasedMatchmakerViewController?(vc, didFailWithError: e)
    }
    func turnBasedMatchmakerViewController(_ vc: GKTurnBasedMatchmakerViewController, didFind m: GKTurnBasedMatch) {
        t?.turnBasedMatchmakerViewController?(vc, didFindMatch: m)
    }
}
final class _GKFriendRequestDelegateBox: GKFriendRequestComposeViewControllerDelegate {
    weak var t: _GKObjCFriendRequestDelegate?
    init(_ t: _GKObjCFriendRequestDelegate) { self.t = t }
    func friendRequestComposeViewControllerDidFinish(_ vc: GKFriendRequestComposeViewController) { t?.friendRequestComposeViewControllerDidFinish?(vc) }
}
enum _GKObjC {
    nonisolated(unsafe) static var boxKey = 0
    static let lock = NSLock()
    /// keeps a delegate box alive as long as its owner (the owner's Swift property is weak)
    static func keep(_ box: AnyObject?, on owner: NSObject) {
        withUnsafePointer(to: &boxKey) { objc_setAssociatedObject(owner, $0, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - players

extension GKPlayer {
    /// GKPhotoSize's raw value
    @objc(loadPhotoForSize:withCompletionHandler:) func _objcLoadPhoto(_ size: Int, withCompletionHandler h: ((UIImage?, Error?) -> Void)?) {
        loadPhoto(for: PhotoSize(rawValue: size) ?? .small, withCompletionHandler: h)
    }
}
extension GKLocalPlayer {
    @objc(loadFriendsAuthorizationStatus:) func _objcLoadFriendsAuthorizationStatus(_ h: @escaping (Int, Error?) -> Void) {
        loadFriendsAuthorizationStatus { s, e in h(s.rawValue, e) }
    }
}

// MARK: - leaderboards, Game Center UI

extension GKLeaderboard {
    @objc(type) var _objcType: Int { type.rawValue }
    @objc(loadEntriesForPlayerScope:timeScope:range:completionHandler:)
    func _objcLoadEntries(_ scope: Int, timeScope: Int, range: NSRange, completionHandler h: @escaping (Entry?, [Entry]?, Int, Error?) -> Void) {
        loadEntries(for: PlayerScope(rawValue: scope) ?? .global, timeScope: TimeScope(rawValue: timeScope) ?? .allTime, range: range, completionHandler: h)
    }
    @objc(loadEntriesForPlayers:timeScope:completionHandler:)
    func _objcLoadEntries(_ players: [GKPlayer], timeScope: Int, completionHandler h: @escaping (Entry?, [Entry]?, Error?) -> Void) {
        loadEntries(for: players, timeScope: TimeScope(rawValue: timeScope) ?? .allTime, completionHandler: h)
    }
}
extension GKGameCenterViewController {
    @objc(initWithState:) convenience init(_objcState s: Int) { self.init(state: GKGameCenterViewControllerState(rawValue: s) ?? .default) }
    @objc(initWithLeaderboardID:playerScope:timeScope:) convenience init(_objcLeaderboardID id: String, playerScope: Int, timeScope: Int) {
        self.init(leaderboardID: id, playerScope: GKLeaderboard.PlayerScope(rawValue: playerScope) ?? .global,
                  timeScope: GKLeaderboard.TimeScope(rawValue: timeScope) ?? .allTime)
    }
    @objc(viewState) var _objcViewState: Int {
        get { viewState.rawValue }
        set { viewState = GKGameCenterViewControllerState(rawValue: newValue) ?? .default }
    }
}
extension GKAccessPoint {
    @objc(location) var _objcLocation: Int {
        get { location.rawValue }
        set { location = Location(rawValue: newValue) ?? .topLeading }
    }
    @objc(triggerAccessPointWithState:handler:) func _objcTrigger(state: Int, handler: @escaping () -> Void) {
        trigger(state: GKGameCenterViewControllerState(rawValue: state) ?? .default, handler: handler)
    }
    @available(iOS 18.0, *)
    @objc(triggerAccessPointWithLeaderboardID:playerScope:timeScope:handler:)
    func _objcTrigger(leaderboardID: String, playerScope: Int, timeScope: Int, handler: @escaping () -> Void) {
        trigger(leaderboardID: leaderboardID, playerScope: GKLeaderboard.PlayerScope(rawValue: playerScope) ?? .global,
                timeScope: GKLeaderboard.TimeScope(rawValue: timeScope) ?? .allTime, handler: handler)
    }
}
extension GKFriendRequestComposeViewController {
    @objc(composeViewDelegate) var _objcComposeViewDelegate: _GKObjCFriendRequestDelegate? {
        get { (composeViewDelegate as? _GKFriendRequestDelegateBox)?.t }
        set { let b = newValue.map(_GKFriendRequestDelegateBox.init); _GKObjC.keep(b, on: self); composeViewDelegate = b }
    }
}

// MARK: - challenges, activities

extension GKChallenge {
    @objc(state) var _objcState: Int { state.rawValue }
}
@available(iOS 26.0, *) extension GKGameActivityDefinition {
    @objc(playStyle) var _objcPlayStyle: Int { playStyle.rawValue }
}
@available(iOS 26.0, *) extension GKGameActivity {
    @objc(state) var _objcState: UInt { state.rawValue }
}

// MARK: - matches

extension GKMatchRequest {
    /// GKInviteRecipientResponse's raw value
    @objc(recipientResponseHandler) var _objcRecipientResponseHandler: ((GKPlayer, Int) -> Void)? {
        get { recipientResponseHandler.map { h in { p, r in h(p, GKInviteRecipientResponse(rawValue: r) ?? .failed) } } }
        set { recipientResponseHandler = newValue.map { h in { p, r in h(p, r.rawValue) } } }
    }
    @objc(maxPlayersAllowedForMatchOfType:) class func _objcMaxPlayers(_ type: UInt) -> Int { maxPlayersAllowedForMatch(of: GKMatchType(rawValue: type) ?? .peerToPeer) }
}
extension GKMatch {
    @objc(delegate) var _objcDelegate: _GKObjCMatchDelegate? {
        get { (delegate as? _GKMatchDelegateBox)?.t }
        set { let b = newValue.map(_GKMatchDelegateBox.init); _GKObjC.keep(b, on: self); delegate = b }
    }
    @objc(sendData:toPlayers:dataMode:error:) func _objcSend(_ data: Data, toPlayers players: [GKPlayer], dataMode: Int) throws {
        try send(data, to: players, dataMode: SendDataMode(rawValue: dataMode) ?? .reliable)
    }
    @objc(sendDataToAllPlayers:withDataMode:error:) func _objcSendToAll(_ data: Data, withDataMode mode: Int) throws {
        try sendData(toAllPlayers: data, with: SendDataMode(rawValue: mode) ?? .reliable)
    }
}
extension GKMatchmakerViewController {
    @objc(matchmakerDelegate) var _objcMatchmakerDelegate: _GKObjCMatchmakerDelegate? {
        get { (matchmakerDelegate as? _GKMatchmakerDelegateBox)?.t }
        set { let b = newValue.map(_GKMatchmakerDelegateBox.init); _GKObjC.keep(b, on: self); matchmakerDelegate = b }
    }
    @objc(matchmakingMode) var _objcMatchmakingMode: Int {
        get { matchmakingMode.rawValue }
        set { matchmakingMode = GKMatchmakingMode(rawValue: newValue) ?? .default }
    }
}
extension GKTurnBasedMatchmakerViewController {
    @objc(turnBasedMatchmakerDelegate) var _objcTurnBasedMatchmakerDelegate: _GKObjCTurnBasedMatchmakerDelegate? {
        get { (turnBasedMatchmakerDelegate as? _GKTurnBasedMatchmakerDelegateBox)?.t }
        set { let b = newValue.map(_GKTurnBasedMatchmakerDelegateBox.init); _GKObjC.keep(b, on: self); turnBasedMatchmakerDelegate = b }
    }
    @objc(matchmakingMode) var _objcMatchmakingMode: Int {
        get { matchmakingMode.rawValue }
        set { matchmakingMode = GKMatchmakingMode(rawValue: newValue) ?? .default }
    }
}

// MARK: - turn-based

extension GKTurnBasedParticipant {
    @objc(status) var _objcStatus: Int { status.rawValue }
    @objc(matchOutcome) var _objcMatchOutcome: Int {
        get { matchOutcome.rawValue }
        set { matchOutcome = GKTurnBasedMatch.Outcome(rawValue: newValue) ?? .none }
    }
}
extension GKTurnBasedMatch {
    @objc(status) var _objcStatus: Int { status.rawValue }
    @objc(participantQuitInTurnWithOutcome:nextParticipants:turnTimeout:matchData:completionHandler:)
    func _objcQuitInTurn(_ outcome: Int, nextParticipants: [GKTurnBasedParticipant], turnTimeout: TimeInterval, matchData: Data,
                         completionHandler h: ((Error?) -> Void)?) {
        participantQuitInTurn(with: Outcome(rawValue: outcome) ?? .quit, nextParticipants: nextParticipants, turnTimeout: turnTimeout, match: matchData,
                              completionHandler: h)
    }
    @objc(participantQuitOutOfTurnWithOutcome:withCompletionHandler:) func _objcQuitOutOfTurn(_ outcome: Int, withCompletionHandler h: ((Error?) -> Void)?) {
        participantQuitOutOfTurn(with: Outcome(rawValue: outcome) ?? .quit, withCompletionHandler: h)
    }
}
extension GKTurnBasedExchange {
    @objc(status) var _objcStatus: Int8 { status.rawValue }
}
