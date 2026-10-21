# GameKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 77.2% of Apple's iOS API (584 of 756, exact) · **Rows:** 24: 19 ✅ 3 🟡 2 ❌ · **iOS:** 3.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [GameKit](https://developer.apple.com/documentation/gamekit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** a local Game Center network (an `$ISIM_GAMECENTER` directory, loopback TCP between devices) with `isim-GameCenter.json` metadata and test players (`isim gamecenter`).
- **Objective-C:** `#import <GameKit/GameKit.h>`, `-framework GameKit` (`isim/sdk-src/Frameworks/GameKit`, [#559](https://github.com/kolabs-dev/isim/issues/559)). The headers sit over the overlay's classes, which are `@objc(GK…)` with Apple's selectors. Swift-only members (enums, the delegate and listener protocols) have internal Objective-C entry points (`swift/overlays/GameKit/ObjC.swift`). An Objective-C delegate or `GKLocalPlayerListener` is held through a Swift box that forwards to Apple's Objective-C protocol, weakly as on iOS. The classes are not subclassable from Objective-C; the matchmakers and the friend request composer are `UINavigationController`s, as on iOS.
- Guide: [GAMECENTER.md](../GAMECENTER.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GKLocalPlayer.local.authenticateHandler` | ✅ | ≤17 | signed-in state from Settings > Game Center; "Welcome back" banner |
| Objective-C: `GKLocalPlayer` / `GKPlayer` (authentication, photos, friends, listeners: `GKLocalPlayerListener` and its parts), `GKLeaderboard`, `GKLeaderboardEntry`, `GKLeaderboardScore`, `GKLeaderboardSet`, `GKAchievement`, `GKAchievementDescription`, `GKGameCenterViewController`, `GKAccessPoint`, `GKMatchmaker`, `GKMatch`, `GKMatchRequest`, `GKInvite`, `GKMatchmakerViewController`, `GKTurnBasedMatch`, `GKTurnBasedParticipant`, `GKTurnBasedExchange` / `Reply`, `GKTurnBasedMatchmakerViewController`, `GKSavedGame`, `GKChallenge` and its subclasses, `GKFriendRequestComposeViewController`, `GKGameActivity` / `Definition` (iOS 26), `GKErrorDomain` and `GKErrorCode`, the turn and exchange timeouts | ✅ | ≤17 | adapted: the Swift classes under Apple's Objective-C names and selectors; Objective-C delegates and listeners through forwarding boxes; the matchmakers and the friend request composer are `UINavigationController`s, as on iOS. Tested (GameKitObjCTest: sign-in, a ranked leaderboard, achievements, saved games, a turn-based match to its end, a challenge to the listener, the dashboard's and matchmaker's delegates) |
| Player identity (`alias`, `displayName`, `gamePlayerID`, `teamPlayerID`, `isEqual`, guest players) | ✅ | ≤17 | nickname from Settings; ids are the player's id on the local network (`A:_…`, `T:_…`), one per device |
| Player photos (`loadPhoto`) | ✅ | ≤17 | generated monogram (initials on a gray circle), like the default Game Center avatar |
| Leaderboards: `GKLeaderboard.submitScore`, `loadLeaderboards`, `loadEntries` | ✅ | ≤17 | every player's best score (the other isim devices and test players), ranked by the configured sort order (ties: earlier first); `range`, total player count, `.friendsOnly`, `loadEntries(for: players)`, today / week scopes; `formattedScore` from the configured format: integer, fixed point, elapsed time (seconds, minutes, centiseconds), money (unverified), suffix; scores live on the local network, so they outlive the app |
| Recurring leaderboards (`type`, `startDate`, `nextStartDate`, `duration`, `loadPreviousOccurrence`) | ✅ | ≤17 | local occurrences from `start` + `duration` in the configuration (any ISO 8601 duration, e.g. PT6S for tests); dashboard shows "resets in" |
| Leaderboard sets (`GKLeaderboardSet`, `GKGameCenterViewController(leaderboardSetID:)`) | ✅ | ≤17 | from the configuration; shown in the dashboard |
| Leaderboard / set images (`loadImage`) | ✅ | ≤17 | image file or asset from the configuration, else a generated placeholder (leaderboard, set); sizes checked |
| Achievements: `GKAchievement.report`, `loadAchievements`, `resetAchievements`, completion banner | ✅ | ≤17 | local |
| `GKAchievementDescription` (titles, descriptions, points, hidden, images) | ✅ | ≤17 | from the configuration; images: configured file or generated medal; `rarityPercent` is nil |
| Dashboard UI (`GKGameCenterViewController`, leaderboards/achievements/sets states) | ✅ | ≤17 | iOS-style SwiftUI dashboard; achievement descriptions and points; not-started configured achievements listed, hidden ones hidden |
| `GKAccessPoint` | ✅ | ≤17 | floating monogram bubble at the configured corner while active and signed in; tapping opens the dashboard; hidden while Game Center UI is shown; `showHighlights` ignored |
| Friends (`loadFriends`, `loadFriendsAuthorizationStatus`, recent players) | ✅ | ≤17 | friendships on the local network; the friends-list prompt (iOS 14.5+; `ISIM_GAMECENTER_FRIENDS_PERMISSION` answers it) needs `NSGKFriendListUsageDescription` (`friendListDescriptionMissing` without it); `loadFriends(identifiedBy:)`; recent players are the players met in matches; every friend can be challenged |
| Friend requests (`GKFriendRequestComposeViewController`, `presentFriendRequestCreator`) | ✅ | ≤17 | sent to the player with that nickname (an email or phone number: the part before "@"); test players accept at once, a device's player accepts or declines in Settings > Game Center (or `isim gamecenter accept-friend`) |
| Saved games (`saveGameData`, `fetchSavedGames`, `deleteSavedGames`, `resolveConflictingSavedGames`, `GKLocalPlayerListener`) | ✅ | ≤17 | stored in the device data (`Library/GameCenter/<bundle id>`), survives app deletion; conflicts come from `isim gamecenter <app> conflict` (no second device) |
| Real-time multiplayer (`GKMatchmaker`, `GKMatch`, `GKMatchmakerViewController`) | 🟡 | ≤17 | adapted: automatching between the isim devices running the game (same `playerGroup`, within every request's min / max), invites to friends (banner → `player(_:didAccept:)`, `recipientResponseHandler`, `match(for: invite)`), the matchmaker (find players, invite a friend, join from an invite); `GKMatch` data over loopback TCP (reliable and unreliable alike), player state changes, `expectedPlayerCount`, disconnect, `chooseBestHostingPlayer`; hosted matches (`findPlayers`), `addPlayers` and nearby browsing unverified; `playerAttributes` roles, rematch, voice chat ❌. `GKMatchmakerViewController`, `GKTurnBasedMatchmakerViewController` and `GKFriendRequestComposeViewController` are `UINavigationController`s, as on iOS (since 0.28; their root is the SwiftUI sheet, which draws its own bar) |
| Turn-based multiplayer (`GKTurnBasedMatch`, `GKTurnBasedMatchmakerViewController`) | 🟡 | ≤17 | matches shared on the local network: automatching into a match's open seat (else a new match, local player first), `endTurn`, `endMatchInTurn` with outcomes (and with scores / achievements), `loadMatches`, `loadMatchData`; turn events and `matchEnded` reach the other participants' listeners; the matchmaker lists the player's matches; invited recipients, `acceptInvite` / `declineInvite`, `saveCurrentTurn`, quitting, `remove`, `rematch` unverified; exchanges and timeouts: see their rows |
| Challenges, invites | 🟡 | ≤17 | score and achievement challenges between friends: received (banner, `didReceive`, tapping it `wantsToPlay`), `loadReceivedChallenges`, `decline`, completed by beating the score or earning the achievement (`didComplete`; the issuer gets `issuedChallengeWasCompleted`), composers on `GKLeaderboard.Entry` and `GKAchievement`; `isim gamecenter … challenge` sends one from a test player; real-time invites: see real-time multiplayer; Missing: iOS 26 challenge definitions (`GKChallengeDefinition`) |
| Game activities (`GKGameActivityDefinition`, `GKGameActivity`, `GKLocalPlayerListener.player(_:wantsToPlay:completionHandler:)`) | ✅ | 26.0 | adapted: definitions from the configuration's `activities`; start / pause / resume / end (ending posts the activity's scores and achievements), party codes (alphabet, validation); the Games app's request comes from `isim gamecenter <app> activity <id> [party code]`; `findMatch` (party code → player group) and `checkPendingGameActivityExistence` unverified |
| Turn-based exchanges (`GKTurnBasedExchange`: `sendExchange(to:data:localizableMessageKey:arguments:timeout:)`, `reply`, `cancel`, `status`, `replies`, `sender`, `recipients`, `data`, `message`, dates; `GKTurnBasedExchangeReply`, `GKTurnBasedExchangeStatus`; `GKTurnBasedMatch.exchanges` / `activeExchanges` / `completedExchanges`, `saveMergedMatch(_:withResolvedExchanges:)`, `exchangeDataMaximumSize`, `exchangeMaxInitiatedExchangesPerPlayer`; the listener's `receivedExchangeRequest` / `receivedExchangeCancellation` / `receivedExchangeReplies`; `GKExchangeTimeoutDefault` / `None`) | ✅ | ≤17 | adapted: exchanges are kept in the match on isim's local Game Center network; between active participants, out of turn; once every recipient replied (or the exchange timed out) the sender and the current participant get the replies, and merging resolves them (they leave the match), as do cancelled ones; isim's limits: 2048 bytes of data, 5 active exchanges per sender; tested (HelloGameCenter: request, reply, merge, cancel) |
| Turn timeouts (`endTurn(withNextParticipants:turnTimeout:match:)`, `participantQuitInTurn`, `GKTurnBasedParticipant.timeoutDate`, `GKTurnTimeoutDefault` / `None`) and exchange timeouts | ✅ | ≤17 | adapted: enforced by the running apps of the match's participants (checked once a second; iOS's servers do it whether or not an app runs): an expired turn passes to the next participant of the list `endTurn` was given that still plays, with the same timeout, and everyone gets a turn event; when the list runs out the turn stays where it is; an expired exchange completes with the replies it has; tested (HelloGameCenter: a 1 s turn passed on and back) |
| `GKMatchmakingMode` (`GKMatchmakerViewController.matchmakingMode`, `GKTurnBasedMatchmakerViewController.matchmakingMode`) | ✅ | ≤17 | adapted: `.automatchOnly` offers only Find Players (Start a New Match), `.inviteOnly` only invites to friends, `.nearbyOnly` only invites to nearby players (the other isim devices browsing for nearby players or showing a nearby-only sheet); `.default` both; tested (HelloGameCenter: automatch-only and invite-only sheets, an invite from the invite-only turn-based sheet) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `GKVoiceChat` (1 type; with its members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `GKGameActivityListener` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
172 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var parentWindow: UIWindow?`](https://developer.apple.com/documentation/gamekit/gkaccesspoint/parentwindow)
- [`func triggerForArcade(handler: (() -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkaccesspoint/triggerforarcade(handler:))
- [`func triggerForChallenges(handler: (() -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkaccesspoint/triggerforchallenges(handler:))
- [`func triggerForFriending(handler: (() -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkaccesspoint/triggerforfriending(handler:))
- [`func triggerForPlayTogether(handler: (() -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkaccesspoint/triggerforplaytogether(handler:))
- [`var player: GKPlayer`](https://developer.apple.com/documentation/gamekit/gkachievement/player)
- [`func selectChallengeablePlayers([GKPlayer], withCompletionHandler: (([GKPlayer]?, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkachievement/selectchallengeableplayers(_:withcompletionhandler:))
- [`var activityIdentifier: String`](https://developer.apple.com/documentation/gamekit/gkachievementdescription/activityidentifier)
- [`var activityProperties: [String : String]`](https://developer.apple.com/documentation/gamekit/gkachievementdescription/activityproperties)
- [`GKChallengeDefinition`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition)
- [`var details: String?`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/details)
- [`var durationOptions: [DateComponents]`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/durationoptions)
- [`var groupIdentifier: String?`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/groupidentifier)
- [`func hasActiveChallenges(completionHandler: (Bool, (any Error)?) -> Void)`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/hasactivechallenges(completionhandler:))
- [`var identifier: String`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/identifier)
- [`var isRepeatable: Bool`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/isrepeatable)
- [`var leaderboard: GKLeaderboard?`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/leaderboard)
- [`class func loadChallengeDefinitions(completionHandler: ([GKChallengeDefinition]?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/loadchallengedefinitions(completionhandler:))
- [`func loadImage(completionHandler: (UIImage?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/loadimage(completionhandler:))
- [`var releaseState: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/releasestate)
- [`var title: String`](https://developer.apple.com/documentation/gamekit/gkchallengedefinition/title)
- [`func player(GKPlayer, didComplete: GKChallenge, issuedByFriend: GKPlayer)`](https://developer.apple.com/documentation/gamekit/gkchallengelistener/player(_:didcomplete:issuedbyfriend:))
- [`func player(GKPlayer, didReceive: GKChallenge)`](https://developer.apple.com/documentation/gamekit/gkchallengelistener/player(_:didreceive:))
- [`func player(GKPlayer, issuedChallengeWasCompleted: GKChallenge, byFriend: GKPlayer)`](https://developer.apple.com/documentation/gamekit/gkchallengelistener/player(_:issuedchallengewascompleted:byfriend:))
- [`func player(GKPlayer, wantsToPlay: GKChallenge)`](https://developer.apple.com/documentation/gamekit/gkchallengelistener/player(_:wantstoplay:))
- [`GKConnectionState`](https://developer.apple.com/documentation/gamekit/gkconnectionstate)
- [`case connected`](https://developer.apple.com/documentation/gamekit/gkconnectionstate/connected)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/gamekit/gkconnectionstate/init(rawvalue:))
- [`case notConnected`](https://developer.apple.com/documentation/gamekit/gkconnectionstate/notconnected)
- [`static var apiNotAvailable: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/apinotavailable)
- [`static var apiObsolete: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/apiobsolete)
- [`static var appUnlisted: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/appunlisted)
- [`static var authenticationInProgress: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/authenticationinprogress)
- [`static var cancelled: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/cancelled)
- [`static var challengeInvalid: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/challengeinvalid)
- [`case debugMode`](https://developer.apple.com/documentation/gamekit/gkerror/code/debugmode)
- [`case debugMode`](https://developer.apple.com/documentation/gamekit/gkerror/code/debugmode)
- [`static var communicationsFailure: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/communicationsfailure)
- [`static var connectionTimeout: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/connectiontimeout)
- [`static var debugMode: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/debugmode)
- [`static var friendListDenied: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/friendlistdenied)
- [`static var friendListDescriptionMissing: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/friendlistdescriptionmissing)
- [`static var friendListRestricted: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/friendlistrestricted)
- [`static var friendRequestNotAvailable: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/friendrequestnotavailable)
- [`static var gameSessionRequestInvalid: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/gamesessionrequestinvalid)
- [`static var gameUnrecognized: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/gameunrecognized)
- [`static var iCloudUnavailable: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/icloudunavailable)
- [`static var invalidCredentials: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/invalidcredentials)
- [`static var invalidParameter: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/invalidparameter)
- [`static var invalidPlayer: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/invalidplayer)
- [`static var invitationsDisabled: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/invitationsdisabled)
- [`static var lockdownMode: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/lockdownmode)
- [`static var matchNotConnected: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/matchnotconnected)
- [`static var matchRequestInvalid: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/matchrequestinvalid)
- [`static var notAuthenticated: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/notauthenticated)
- [`static var notAuthorized: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/notauthorized)
- [`static var notSupported: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/notsupported)
- [`static var parentalControlsBlocked: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/parentalcontrolsblocked)
- [`static var playerPhotoFailure: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/playerphotofailure)
- [`static var playerStatusExceedsMaximumLength: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/playerstatusexceedsmaximumlength)
- [`static var playerStatusInvalid: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/playerstatusinvalid)
- [`static var restrictedToAutomatch: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/restrictedtoautomatch)
- [`static var scoreNotSet: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/scorenotset)
- [`static var turnBasedInvalidParticipant: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/turnbasedinvalidparticipant)
- [`static var turnBasedInvalidState: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/turnbasedinvalidstate)
- [`static var turnBasedInvalidTurn: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/turnbasedinvalidturn)
- [`static var turnBasedMatchDataTooLarge: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/turnbasedmatchdatatoolarge)
- [`static var turnBasedTooManySessions: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/turnbasedtoomanysessions)
- [`static var ubiquityContainerUnavailable: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/ubiquitycontainerunavailable)
- [`static var underage: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/underage)
- [`static var unexpectedConnection: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/unexpectedconnection)
- [`static var unknown: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/unknown)
- [`static var userDenied: GKError.Code`](https://developer.apple.com/documentation/gamekit/gkerror/userdenied)
- [`GKFriendsAuthorizationStatus`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus)
- [`case authorized`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus/authorized)
- [`case denied`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus/denied)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus/init(rawvalue:))
- [`case notDetermined`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus/notdetermined)
- [`case restricted`](https://developer.apple.com/documentation/gamekit/gkfriendsauthorizationstatus/restricted)
- [`func findPlayersForHostedMatch(completionHandler: ([GKPlayer]?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/gamekit/gkgameactivity/findplayersforhostedmatch(completionhandler:))
- [`case active`](https://developer.apple.com/documentation/gamekit/gkgameactivity/state-swift.enum/active)
- [`case ended`](https://developer.apple.com/documentation/gamekit/gkgameactivity/state-swift.enum/ended)
- [`init?(rawValue: UInt)`](https://developer.apple.com/documentation/gamekit/gkgameactivity/state-swift.enum/init(rawvalue:))
- [`case initialized`](https://developer.apple.com/documentation/gamekit/gkgameactivity/state-swift.enum/initialized)
- [`case paused`](https://developer.apple.com/documentation/gamekit/gkgameactivity/state-swift.enum/paused)
- [`var playerRange: (any RangeExpression)?`](https://developer.apple.com/documentation/gamekit/gkgameactivitydefinition/playerrange)
- [`var releaseState: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkgameactivitydefinition/releasestate)
- [`GKGameActivityListener`](https://developer.apple.com/documentation/gamekit/gkgameactivitylistener)
- [`func player(GKPlayer, wantsToPlay: GKGameActivity, completionHandler: (Bool) -> Void)`](https://developer.apple.com/documentation/gamekit/gkgameactivitylistener/player(_:wantstoplay:completionhandler:))
- [`func player(GKPlayer, didAccept: GKInvite)`](https://developer.apple.com/documentation/gamekit/gkinviteeventlistener/player(_:didaccept:))
- [`func player(GKPlayer, didRequestMatchWithRecipients: [GKPlayer])`](https://developer.apple.com/documentation/gamekit/gkinviteeventlistener/player(_:didrequestmatchwithrecipients:))
- [`static var inviteeResponseAccepted: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseaccepted)
- [`static var inviteeResponseAccepted: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseaccepted)
- [`static var inviteeResponseDeclined: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsedeclined)
- [`static var inviteeResponseDeclined: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsedeclined)
- [`static var inviteeResponseFailed: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsefailed)
- [`static var inviteeResponseFailed: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsefailed)
- [`static var inviteeResponseIncompatible: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseincompatible)
- [`static var inviteeResponseIncompatible: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseincompatible)
- [`static var inviteeResponseNoAnswer: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsenoanswer)
- [`static var inviteeResponseNoAnswer: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponsenoanswer)
- [`static var inviteeResponseUnableToConnect: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseunabletoconnect)
- [`static var inviteeResponseUnableToConnect: GKInviteRecipientResponse`](https://developer.apple.com/documentation/gamekit/gkinviterecipientresponse/inviteeresponseunabletoconnect)
- [`var activityIdentifier: String`](https://developer.apple.com/documentation/gamekit/gkleaderboard/activityidentifier)
- [`var activityProperties: [String : String]`](https://developer.apple.com/documentation/gamekit/gkleaderboard/activityproperties)
- [`var isHidden: Bool`](https://developer.apple.com/documentation/gamekit/gkleaderboard/ishidden)
- [`var leaderboardDescription: String`](https://developer.apple.com/documentation/gamekit/gkleaderboard/leaderboarddescription)
- [`var releaseState: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkleaderboard/releasestate)
- [`func fetchItems(forIdentityVerificationSignature: ((URL?, Data?, Data?, UInt64, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gklocalplayer/fetchitems(foridentityverificationsignature:))
- [`var isPresentingFriendRequestViewController: Bool`](https://developer.apple.com/documentation/gamekit/gklocalplayer/ispresentingfriendrequestviewcontroller)
- [`func loadDefaultLeaderboardIdentifier(completionHandler: ((String?, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gklocalplayer/loaddefaultleaderboardidentifier(completionhandler:))
- [`func setDefaultLeaderboardIdentifier(String, completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gklocalplayer/setdefaultleaderboardidentifier(_:completionhandler:))
- [`func voiceChat(withName: String) -> GKVoiceChat?`](https://developer.apple.com/documentation/gamekit/gkmatch/voicechat(withname:))
- [`GKMatchedPlayers`](https://developer.apple.com/documentation/gamekit/gkmatchedplayers)
- [`var playerProperties: [GKPlayer : [String : Any]]?`](https://developer.apple.com/documentation/gamekit/gkmatchedplayers/playerproperties)
- [`var players: [GKPlayer]`](https://developer.apple.com/documentation/gamekit/gkmatchedplayers/players)
- [`var properties: [String : Any]?`](https://developer.apple.com/documentation/gamekit/gkmatchedplayers/properties)
- [`func findMatchedPlayers(GKMatchRequest, withCompletionHandler: (GKMatchedPlayers?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/gamekit/gkmatchmaker/findmatchedplayers(_:withcompletionhandler:))
- [`func queryQueueActivity(String, withCompletionHandler: ((Int, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkmatchmaker/queryqueueactivity(_:withcompletionhandler:))
- [`func startGroupActivity(playerHandler: (GKPlayer) -> Void)`](https://developer.apple.com/documentation/gamekit/gkmatchmaker/startgroupactivity(playerhandler:))
- [`func stopGroupActivity()`](https://developer.apple.com/documentation/gamekit/gkmatchmaker/stopgroupactivity())
- [`GKMatchType`](https://developer.apple.com/documentation/gamekit/gkmatchtype)
- [`case hosted`](https://developer.apple.com/documentation/gamekit/gkmatchtype/hosted)
- [`init?(rawValue: UInt)`](https://developer.apple.com/documentation/gamekit/gkmatchtype/init(rawvalue:))
- [`case peerToPeer`](https://developer.apple.com/documentation/gamekit/gkmatchtype/peertopeer)
- [`case turnBased`](https://developer.apple.com/documentation/gamekit/gkmatchtype/turnbased)
- [`let GKPlayerIDNoLongerAvailable: String`](https://developer.apple.com/documentation/gamekit/gkplayeridnolongeravailable)
- [`GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate)
- [`GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/gamekit/gkreleasestate/init(rawvalue:))
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/gamekit/gkreleasestate/init(rawvalue:))
- [`static var prereleased: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate/prereleased)
- [`static var prereleased: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate/prereleased)
- [`static var released: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate/released)
- [`static var released: GKReleaseState`](https://developer.apple.com/documentation/gamekit/gkreleasestate/released)
- [`func player(GKPlayer, didModifySavedGame: GKSavedGame)`](https://developer.apple.com/documentation/gamekit/gksavedgamelistener/player(_:didmodifysavedgame:))
- [`func player(GKPlayer, hasConflictingSavedGames: [GKSavedGame])`](https://developer.apple.com/documentation/gamekit/gksavedgamelistener/player(_:hasconflictingsavedgames:))
- [`func challengeComposeController(withMessage: String?, players: [GKPlayer]?, completion: GKChallengeComposeHandler?) -> UIViewController`](https://developer.apple.com/documentation/gamekit/gkscore/challengecomposecontroller(withmessage:players:completion:))
- [`class func report([GKLeaderboardScore], withEligibleChallenges: [GKChallenge], withCompletionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkscore/report(_:witheligiblechallenges:withcompletionhandler:)-2tycl)
- [`let GKSessionErrorDomain: String`](https://developer.apple.com/documentation/gamekit/gksessionerrordomain)
- [`let GKSessionErrorDomain: String`](https://developer.apple.com/documentation/gamekit/gksessionerrordomain)
- [`GKTransportType`](https://developer.apple.com/documentation/gamekit/gktransporttype)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/gamekit/gktransporttype/init(rawvalue:))
- [`case reliable`](https://developer.apple.com/documentation/gamekit/gktransporttype/reliable)
- [`case unreliable`](https://developer.apple.com/documentation/gamekit/gktransporttype/unreliable)
- [`func player(GKPlayer, didRequestMatchWithOtherPlayers: [GKPlayer])`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:didrequestmatchwithotherplayers:))
- [`func player(GKPlayer, matchEnded: GKTurnBasedMatch)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:matchended:))
- [`func player(GKPlayer, receivedExchangeCancellation: GKTurnBasedExchange, for: GKTurnBasedMatch)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:receivedexchangecancellation:for:))
- [`func player(GKPlayer, receivedExchangeReplies: [GKTurnBasedExchangeReply], forCompletedExchange: GKTurnBasedExchange, for: GKTurnBasedMatch)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:receivedexchangereplies:forcompletedexchange:for:))
- [`func player(GKPlayer, receivedExchangeRequest: GKTurnBasedExchange, for: GKTurnBasedMatch)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:receivedexchangerequest:for:))
- [`func player(GKPlayer, receivedTurnEventFor: GKTurnBasedMatch, didBecomeActive: Bool)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:receivedturneventfor:didbecomeactive:))
- [`func player(GKPlayer, wantsToQuitMatch: GKTurnBasedMatch)`](https://developer.apple.com/documentation/gamekit/gkturnbasedeventlistener/player(_:wantstoquitmatch:))
- [`func sendReminder(to: [GKTurnBasedParticipant], localizableMessageKey: String, arguments: [String], completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/gamekit/gkturnbasedmatch/sendreminder(to:localizablemessagekey:arguments:completionhandler:))
- [`GKVoiceChat`](https://developer.apple.com/documentation/gamekit/gkvoicechat)
- [`var isActive: Bool`](https://developer.apple.com/documentation/gamekit/gkvoicechat/isactive)
- [`class func isVoIPAllowed() -> Bool`](https://developer.apple.com/documentation/gamekit/gkvoicechat/isvoipallowed())
- [`var name: String`](https://developer.apple.com/documentation/gamekit/gkvoicechat/name)
- [`var players: [GKPlayer]`](https://developer.apple.com/documentation/gamekit/gkvoicechat/players)
- [`GKVoiceChat.PlayerState`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate)
- [`case connected`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/connected)
- [`case connecting`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/connecting)
- [`case disconnected`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/disconnected)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/init(rawvalue:))
- [`case silent`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/silent)
- [`case speaking`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playerstate/speaking)
- [`var playerVoiceChatStateDidChangeHandler: (GKPlayer, GKVoiceChat.PlayerState) -> Void`](https://developer.apple.com/documentation/gamekit/gkvoicechat/playervoicechatstatedidchangehandler)
- [`func setPlayer(GKPlayer, muted: Bool)`](https://developer.apple.com/documentation/gamekit/gkvoicechat/setplayer(_:muted:))
- [`func start()`](https://developer.apple.com/documentation/gamekit/gkvoicechat/start())
- [`func stop()`](https://developer.apple.com/documentation/gamekit/gkvoicechat/stop())
- [`var volume: Float`](https://developer.apple.com/documentation/gamekit/gkvoicechat/volume)
- [`let GKVoiceChatServiceErrorDomain: String`](https://developer.apple.com/documentation/gamekit/gkvoicechatserviceerrordomain)
- [`let GKVoiceChatServiceErrorDomain: String`](https://developer.apple.com/documentation/gamekit/gkvoicechatserviceerrordomain)

</details>
<!-- /generated:missing -->
