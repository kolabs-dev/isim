# Local Game Center and StoreKit testing on isim

isim has no connection to Apple's servers. Game Center and the App Store are simulated on the device,
the way Xcode's StoreKit testing simulates purchases. Nothing here is signed by Apple and nothing is sent anywhere.

## Game Center configuration (`isim-GameCenter.json`)

On a real device, leaderboard titles, achievement descriptions, points and leaderboard sets come from
App Store Connect. isim reads them from a JSON file instead. The format is isim's own; Apple does not define it.

- Put `isim-GameCenter.json` next to the `.xcodeproj` (or up to two folders below it). `isim build` copies it into
  the app bundle. Samples built by hand copy it themselves (see `isim/samples/HelloGameCenter/build.sh`).
- The Info.plist key `ISIMGameCenterConfiguration` can name another file in the bundle.
- Without the file, everything still works: titles come from the identifiers
  (`dev.example.highest_level` becomes "Highest Level"), there are no points, descriptions or sets.

```json
{
  "leaderboards": [
    { "id": "dev.example.high_score", "title": "High Score", "type": "classic", "sortOrder": "high" },
    { "id": "dev.example.daily", "title": "Daily Run", "type": "recurring",
      "start": "2025-01-01T00:00:00Z", "duration": "P1D" },
    { "id": "dev.example.fastest", "title": "Fastest Clear", "sortOrder": "low", "format": "elapsedTime",
      "image": "fastest.png" }
  ],
  "leaderboardSets": [
    { "id": "dev.example.season1", "title": "Season 1", "leaderboards": ["dev.example.high_score", "dev.example.fastest"] }
  ],
  "achievements": [
    { "id": "dev.example.first_win", "title": "First Win", "points": 10,
      "unachievedDescription": "Win a game.", "achievedDescription": "You won your first game.",
      "hidden": false, "replayable": false, "image": "first_win.png", "groupIdentifier": null }
  ]
}
```

| Key | Meaning |
|---|---|
| `leaderboards[].type` | `classic` (default) or `recurring` |
| `start`, `duration` | recurring leaderboards: the first occurrence starts at `start` (UTC) and each one lasts `duration` (ISO 8601: `P1D`, `P1W`, `PT1H`; short ones like `PT6S` help in tests) |
| `sortOrder` | `high` (default; the best score is the highest) or `low` |
| `image` | an image file in the bundle (or asset name). Otherwise isim draws a placeholder |
| `achievements[].hidden` | hidden achievements stay out of the dashboard until they are reported |

## Where Game Center data lives

- Scores and achievements are kept per app in the app container's preferences.
- Saved games (`GKLocalPlayer.saveGameData`) are kept in the device data, under
  `$ISIM_DATA/Library/GameCenter/<bundle id>/SavedGames`, so they survive deleting the app, as iCloud saves do.
- There is one player per device (Settings > Game Center). The friends list is empty, friend requests are
  never sent, and matchmaking finds nobody.

```
isim gamecenter <app> saved-games              list saved games and their versions
isim gamecenter <app> conflict <name> [text]   add a version "from another device" (to test conflict resolution)
isim gamecenter <app> reset                    erase the app's saved games
```

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
