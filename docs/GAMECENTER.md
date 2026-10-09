# Local Game Center and StoreKit testing on isim

isim has no connection to Apple's servers. Game Center and the App Store are simulated on the device,
the way Xcode's StoreKit testing simulates purchases. Nothing here is signed by Apple and nothing is sent anywhere.

## Game Center configuration (`isim-GameCenter.json`)

On a real device, leaderboard titles, achievement descriptions, points, leaderboard sets and game activities come
from App Store Connect. isim reads them from a JSON file instead. The format is isim's own; Apple does not define it.

- Put `isim-GameCenter.json` next to the `.xcodeproj` (or up to two folders below it). `isim build` copies it into
  the app bundle. Samples built by hand copy it themselves (see HelloGameCenter in `isim/buildlib/apps.py`).
- The Info.plist key `ISIMGameCenterConfiguration` can name another file in the bundle.
- Without the file, everything still works: titles come from the identifiers
  (`dev.example.highest_level` becomes "Highest Level"), there are no points, descriptions, sets or activities.

```json
{
  "leaderboards": [
    { "id": "dev.example.high_score", "title": "High Score", "type": "classic", "sortOrder": "high" },
    { "id": "dev.example.daily", "title": "Daily Run", "type": "recurring",
      "start": "2025-01-01T00:00:00Z", "duration": "P1D" },
    { "id": "dev.example.fastest", "title": "Fastest Clear", "sortOrder": "low", "format": "elapsedTime",
      "unit": "centiseconds", "image": "fastest.png" },
    { "id": "dev.example.jump", "title": "Longest Jump", "format": "fixedPoint", "decimals": 2, "suffix": " m" }
  ],
  "leaderboardSets": [
    { "id": "dev.example.season1", "title": "Season 1", "leaderboards": ["dev.example.high_score", "dev.example.fastest"] }
  ],
  "achievements": [
    { "id": "dev.example.first_win", "title": "First Win", "points": 10,
      "unachievedDescription": "Win a game.", "achievedDescription": "You won your first game.",
      "hidden": false, "replayable": false, "image": "first_win.png", "groupIdentifier": null }
  ],
  "activities": [
    { "id": "dev.example.duel", "title": "Duel", "details": "Beat a friend’s high score.", "supportsPartyCode": true,
      "minPlayers": 2, "maxPlayers": 2, "playStyle": "synchronous", "defaultProperties": { "arena": "forest" },
      "leaderboards": ["dev.example.high_score"], "achievements": ["dev.example.first_win"] }
  ]
}
```

| Key | Meaning |
|---|---|
| `leaderboards[].type` | `classic` (default) or `recurring` |
| `start`, `duration` | recurring leaderboards: the first occurrence starts at `start` (UTC) and each one lasts `duration` (ISO 8601: `P1D`, `P1W`, `PT1H`; short ones like `PT6S` help in tests) |
| `sortOrder` | `high` (default; the best score is the highest) or `low` |
| `format` | how `GKLeaderboard.Entry.formattedScore` shows a score: `integer` (default, `1,500`), `fixedPoint` (`decimals`, default 2: 731 is `7.31`), `elapsedTime` (`unit`: what one point is, `seconds` (default), `minutes` or `centiseconds`: 42 seconds is `0:42`), `money` (hundredths of `currency`, default `USD`); `suffix` is appended |
| `image` | an image file in the bundle (or asset name). Otherwise isim draws a placeholder |
| `achievements[].hidden` | hidden achievements stay out of the dashboard until they are reported |
| `activities` | iOS 26 game activities (`GKGameActivityDefinition`): `title`, `details`, `groupIdentifier`, `supportsPartyCode`, `minPlayers`, `maxPlayers`, `supportsUnlimitedPlayers`, `playStyle` (`synchronous`, `asynchronous`), `defaultProperties`, `fallbackURL`, `image`, and the `leaderboards` and `achievements` the activity is about |

## The local Game Center network

There is no Game Center server, so the isim devices on this computer play the part of each other's Game Center:
each device data directory (`ISIM_DATA`) is one player, with the nickname from Settings > Game Center, and every
device shares one directory, the **local Game Center network**: `ISIM_GAMECENTER`, default
`~/.local/share/isim-gamecenter`. Tests use a scratch one.

- **Leaderboards** list every player's best score, ranked by the leaderboard's sort order, with `.friendsOnly` for the
  local player and their friends.
- **Friends**: `loadFriends` asks first, like iOS 14.5 and later (the app needs `NSGKFriendListUsageDescription`).
  The friend request composer sends the request to the player with that nickname. The other player accepts or
  declines in **Settings > Game Center**, where requests and friends are listed (or with `isim gamecenter accept-friend`).
- **Challenges**: friends challenge each other to beat a score or earn an achievement (the composers on
  `GKLeaderboard.Entry` and `GKAchievement`). The challenged player gets a banner (tapping it is `wantsToPlay`). The
  challenge completes when they post a better score or complete the achievement, and its issuer is told.
- **Real-time matches**: devices running the same game automatch (same `playerGroup`, within each request's player
  counts). They can also invite friends, from `GKMatchRequest.recipients` or the matchmaker's slots: the friend gets a
  banner, and tapping it is `player(_:didAccept:)`. The players of a `GKMatch` connect over loopback TCP. Data is
  delivered in order whatever the send mode.
- **Turn-based matches** are shared files: a new match takes the next player who looks for one into its open seat.
  Turn changes and endings reach the other participants' running apps as turn events.
- **Game activities** (iOS 26): the Games app's part, a player choosing an activity or joining a party, is played by
  `isim gamecenter <app> activity`.
- **Test players** are players with no device behind them, made with `isim gamecenter player add`. They accept
  friend requests at once, and `isim gamecenter` posts their scores and sends their challenges. They cannot play
  matches; run a second device for that:

```bash
ISIM_DATA=/tmp/pat isim run MyGame.app &        # set each device's nickname in Settings > Game Center
ISIM_DATA=/tmp/sam isim run MyGame.app &
```

## Where Game Center data lives

- Scores are kept per game on the local Game Center network (`games/<bundle id>/scores`), so they survive deleting
  the app, as on Game Center. isim before 0.13 kept them in the app's preferences; they move over the first time the
  game signs in.
- Achievements are kept per app in the app container's preferences.
- Saved games (`GKLocalPlayer.saveGameData`) are kept in the device data, under
  `$ISIM_DATA/Library/GameCenter/<bundle id>/SavedGames`, so they survive deleting the app, as iCloud saves do.
- The device's player id is in `$ISIM_DATA/Library/GameCenter/player.json`.

```
isim gamecenter players                          players on the local network (devices and test players)
isim gamecenter player add|remove <nickname>     add or remove a test player
isim gamecenter friends                          this device's friends and friend requests
isim gamecenter befriend <nickname> [<nickname>] make two players friends (default: with this device's player)
isim gamecenter request-friend <nickname> [msg]  a test player asks this device's player to be friends
isim gamecenter accept-friend <nickname>         accept a friend request (as Settings > Game Center does)
isim gamecenter <app> score <nickname> <leaderboard> <value> [context]   post a score for a player
isim gamecenter <app> scores                     every player's scores in the game
isim gamecenter <app> challenge <nickname> score <leaderboard> <value> [message]
isim gamecenter <app> challenge <nickname> achievement <id> [message]    challenge this device's player
isim gamecenter <app> challenges                 the game's challenges
isim gamecenter <app> matches                    the game's turn-based matches
isim gamecenter <app> activity <id> [party code] [key=value ...]   play a game activity, as from the Games app
isim gamecenter <app> saved-games                list saved games and their versions
isim gamecenter <app> conflict <name> [text]     add a version "from another device" (to test conflict resolution)
isim gamecenter <app> reset                      erase the app's saved games and this player's scores
```

Not simulated: voice chat, turn-based exchanges, `playerAttributes` roles, real-time rematch, iOS 26 challenge
definitions. Nothing is signed or verified by Apple.

## StoreKit testing

- Products, subscription groups and offers come from the `.storekit` file that the scheme selects
  (Xcode: Scheme > Run > Options > StoreKit Configuration).
- Subscriptions renew on an accelerated clock. isim reads the `.storekit` settings `_timeRate`, using the order of
  `SKTestSession.TimeRate`. Set `ISIM_STOREKIT_TIME_RATE` to override it, for example:
  - `month=4`: one month lasts 4 s (other periods scale)
  - `renewal=10`: every period lasts 10 s
  - a TimeRate name, such as `monthlyRenewalEveryThirtySeconds`
- Offer codes are the `codeOffers` of the `.storekit` file. You redeem one by typing its reference name or ID.
- Promotional offer signatures are not checked.
- Refund requests are approved as soon as they are submitted.
- The app receipt and every JWS are local and **unsigned**.

The ledger is `Library/isim/StoreKit/ledger.json` in the app container. `isim storekit` plays the part of
Xcode's Transaction Manager. A running app picks up its changes within half a second:

```
isim storekit <app> list
isim storekit <app> refund <transaction id>
isim storekit <app> expire|cancel|resume <group id | product id | transaction id>
isim storekit <app> billing-issue <group> on|off
isim storekit <app> delete <transaction id>
isim storekit <app> clear
```

`<app>` is a bundle identifier, an `.app` path or an installed app's name. The device data is `ISIM_DATA`
(default `~/.local/share/isim`).
