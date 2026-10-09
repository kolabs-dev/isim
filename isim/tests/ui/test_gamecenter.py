"""isim's local Game Center (HelloGameCenter, isim-GameCenter.json).

test_gamecenter: one device with test players (`isim gamecenter player add`): sign-in, the access point (shown top
trailing; tapping it opens the dashboard; hidden while Game Center UI is up), scores on classic / low-is-best (with a
configured image) / recurring (6 s period) / fixed-point leaderboards ranked across players (ranges, friends only,
formatted scores), a leaderboard set and its image, achievement descriptions + points in the dashboard, loadPhoto
(generated monogram), the friends permission prompt and friends, the friend request composer (a test player accepts),
challenges (received from a test player and completed by beating the score; sent from the composer), saving a game,
the matchmaker (nobody else is looking). Then `isim gamecenter ... conflict` adds a version from another device; run 2
fetches saved games, gets the conflict and resolves it.

test_gamecenter_settings: Settings > Game Center lists friend requests from other players (accept, decline) and the
friends.

test_gamecenter_activities: game activities under iOS 26 (definitions, start / end, a request from
`isim gamecenter ... activity` with a party code).

test_gamecenter_multiplayer: two devices (Pat and Sam) on one local network: a friend request accepted with
`isim gamecenter accept-friend`, an automatched real-time match (data, disconnect), an invite from the matchmaker
accepted from the banner, and a turn-based match played to the end."""
import os
import plistlib
import re
import subprocess

from isimtest import ISIM, visible

APP = "dev.isim.samples.HelloGameCenter"


def gamecenter(data, *args):
    p = subprocess.run([str(ISIM), "gamecenter", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60,
                       env=dict(os.environ, ISIM_DATA=str(data), ISIM_GAMECENTER=str(data.parent / "gamecenter")))
    assert p.returncode == 0, p.stdout
    return p.stdout


def nickname(data, name):
    prefs = data / "Library/Preferences/.GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True, exist_ok=True)
    prefs.write_bytes(plistlib.dumps({"ISIMGameCenterNickname": name}))


def test_gamecenter(launch, device_data):
    for args in (("player", "add", "Alex"), ("player", "add", "Sam"), ("befriend", "Alex"),
                 (APP, "score", "Alex", "dev.isim.gc.high_score", "1500"), (APP, "score", "Alex", "dev.isim.gc.fastest", "45"),
                 (APP, "score", "Sam", "dev.isim.gc.high_score", "800")):
        gamecenter(device_data, *args)
    app = launch("HelloGameCenter", animations=False)
    app.wait_log(r"authenticated: true")
    app.wait_log(r"player: Player scoped=true")
    app.wait_log(r"access point shown \(top trailing\)")
    trees = [app.wait_view(r"^UIWindow \(338 66; 48 x 48\)$")]          # the access point, top trailing
    app.wait_tap_id("scores")
    app.wait_log(r"scores posted")
    app.tap_id("achievements")
    app.wait_log(r"achievements reported true")
    app.tap_id("metadata")
    app.wait_log(r"^set image ")
    app.wait_log(r"leaderboard image .*: \d+x\d+", count=4)
    log = app.log
    assert re.search(r'achievement description: dev\.isim\.gc\.first_win "First Win" 10 points hidden=false "Win a game\."', log) \
        and re.search(r'dev\.isim\.gc\.secret "Secret Door" 50 points hidden=true', log), "achievement descriptions from config"
    assert 'leaderboard: dev.isim.gc.high_score "High Score" type=classic best=1200 players=3' in log and \
        'leaderboard: dev.isim.gc.fastest "Fastest Clear" type=classic best=42 players=2' in log, \
        "leaderboard titles, types, best scores, players"
    # the 1200 just posted is in the current 6 s occurrence or (after a reset) in the previous one
    assert ('leaderboard: dev.isim.gc.daily "Daily Run" type=recurring best=1200 players=1 period=6s' in log
            and "previous occurrence best=-1" in log) or \
           ('leaderboard: dev.isim.gc.daily "Daily Run" type=recurring best=-1 players=0 period=6s' in log
            and "previous occurrence best=1200" in log), "recurring leaderboard: 6 s occurrences"
    assert 'set: dev.isim.gc.set.season1 "Season 1" boards=dev.isim.gc.high_score,dev.isim.gc.fastest' in log
    assert "leaderboard image dev.isim.gc.fastest: 64x64" in log, "configured leaderboard image (fastest.svg)"
    assert "leaderboard image dev.isim.gc.high_score: 120x120" in log and "set image dev.isim.gc.set.season1: 120x120" in log, \
        "generated leaderboard and set placeholders"

    app.tap_id("entries")
    app.wait_log(r"^friends only dev\.isim\.gc\.distance")
    log = app.log
    assert "entries dev.isim.gc.high_score: 1. Alex 1,500; 2. Player 1,200; 3. Sam 800 | me=#2 of 3" in log, "ranked across players"
    assert "range 2 dev.isim.gc.high_score: 2. Player" in log, "entries in a range"
    assert "friends only dev.isim.gc.high_score: Alex,Player of 2" in log, "friends-only scope"
    assert "entries dev.isim.gc.fastest: 1. Player 0:42; 2. Alex 0:45 | me=#1 of 2" in log, "low is best; elapsed time format"
    assert "entries dev.isim.gc.distance: 1. Player 7.31 m | me=#1 of 1" in log, "fixed-point format with a suffix"

    app.wait_tap_id("gc-access-point")
    app.wait_log(r"access point opens Game Center")
    trees.append(app.wait_view(r"id=gc-achievements-summary text=1 of 2 Completed · 10 points"))
    assert "text=#2 · 1,200" in trees[-1], "the dashboard shows the local player's rank"
    app.wait_tap_id("gc-achievements")
    trees.append(app.wait_view(r"text=40% complete · 25 points"))
    assert "text=You won your first game." in trees[-1] and "text=Collect 100 gems." in trees[-1], \
        "dashboard achievements: titles, descriptions"
    app.tap_id("gc-back")
    app.wait_tap_id("gc-board-dev.isim.gc.high_score")
    trees.append(app.wait_view(r"id=gc-board-players text=3 players"))
    for rank, name, score in ((1, "Alex", "1,500"), (2, "Player", "1,200"), (3, "Sam", "800")):
        assert re.search(rf"id=gc-entry-{rank}\b", trees[-1]) and f"text={name}" in trees[-1] and f"text={score}" in trees[-1], \
            "the leaderboard page ranks every player"
    app.tap_id("gc-done")
    app.wait_view(visible("gc-done"), gone=True)

    app.wait_tap_id("set")
    trees.append(app.wait_view(r"id=gc-board-dev\.isim\.gc\.high_score\b"))
    assert "text=Season 1" in trees[-1] and "text=Fastest Clear" in trees[-1], "leaderboard set page"
    app.wait_tap_id("gc-board-dev.isim.gc.fastest")
    trees.append(app.wait_view(r"text=0:45"))
    app.tap_id("gc-done")
    app.wait_log(r"dashboard closed")                                    # the dashboard closes via its delegate

    app.wait_tap_id("photo")
    app.wait_log(r"photo: 128x128 true")
    app.wait_log(r"friends authorization: 0")
    app.wait_view(r"Allow “Game Center” to access your Game Center friends\?")   # the permission prompt (iOS 14.5+)
    app.tap_text("OK")
    app.wait_log(r"friends: 1 Alex$")
    app.wait_log(r"friends authorization: 3")
    app.wait_tap_id("friend-request")
    app.wait_tap_id("gc-friend-to")
    app.type("sam")
    app.wait_view(r"text=sam")
    app.tap_id("gc-friend-send")
    app.wait_log(r"friend request to Sam accepted \(test player\)")      # a test player accepts at once
    app.wait_view(visible("gc-friend-send"), gone=True)
    app.tap_id("photo")
    app.wait_log(r"friends: 2 Alex,Sam$")

    # a challenge from a test player: the banner, wantsToPlay, completed by beating the score
    gamecenter(device_data, APP, "challenge", "Alex", "score", "dev.isim.gc.high_score", "1300", "Beat this")
    app.wait_log(r'challenge received: score from Alex "Beat this"')
    app.wait_tap_id("gc-banner")
    app.wait_log(r"wants to play challenge: beat 1,300")
    app.tap_id("challenges")
    app.wait_log(r"challenges: score from Alex state=1$")
    app.tap_id("beat")
    app.wait_log(r"challenge completed: issued by Alex state=2")
    app.tap_id("challenges")
    app.wait_log(r"challenges: $")
    # a challenge sent from the composer
    app.tap_id("challenge")
    app.wait_tap_id("gc-challenge-friend-Alex")
    app.tap_id("gc-challenge-send")
    app.wait_log(r"challenge sent=true to Alex")
    challenges = gamecenter(device_data, APP, "challenges")
    assert re.search(r"Alex\s+-> Player\s+beat 1300 on dev\.isim\.gc\.high_score\s+completed", challenges) and \
        re.search(r"Player\s+-> Alex\s+earn dev\.isim\.gc\.first_win\s+pending", challenges), challenges

    app.wait_tap_id("save")
    app.wait_log(r"saved: slot1 on iPhone true")
    assert (device_data / f"Library/GameCenter/{APP}/SavedGames/slot1/versions.json").is_file(), \
        "saved game stored in device data"
    app.wait_tap_id("match")
    app.wait_tap_id("gc-match-find")
    app.wait_log(r"looking for 2-2 players")
    trees.append(app.wait_view(r"id=gc-match-note text=Finding Players…"))  # nobody else is looking
    app.tap_id("gc-match-cancel")
    app.wait_log(r"matchmaker cancelled")
    app.tap_id("activities")
    app.wait_log(r"game activities need iOS 26")                         # iOS 18: no GKGameActivity
    assert not any("text=Secret Door" in t for t in trees), "the hidden achievement stays hidden"
    assert app.quit() == 0

    conflict = gamecenter(device_data, APP, "conflict", "slot1", "from the iPad")
    assert "now has 2 versions" in conflict, conflict
    app = launch("HelloGameCenter", animations=False)
    app.wait_log(r"authenticated: true")                                 # signed in before fetching
    app.wait_tap_id("fetch")
    app.wait_log(r"saved games conflict: 2 versions of slot1 from Other Device,iPhone")   # conflict detected
    app.wait_log(r"resolved: 1 saved game")
    app.wait_log(r"resolved data: merged")
    app.tap_id("fetch")
    app.wait_log(r"fetched: slot1@iPhone$")                              # conflict resolved
    assert app.quit() == 0
    saves = gamecenter(device_data, APP, "saved-games")
    assert sum("slot1" in l for l in saves.splitlines()) == 1, f"one saved game left: {saves}"


def test_gamecenter_settings(launch, device_data):
    for args in (("player", "add", "Alex"), ("player", "add", "Kim"), ("request-friend", "Alex", "Let's play"), ("request-friend", "Kim")):
        gamecenter(device_data, *args)
    dev = launch(None)
    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-gamecenter")
    page = dev.wait_view(r"id=settings-gamecenter-accept-Kim")
    assert "text=Let's play" in page and "text=No Friends" in page, "requests with their message; no friends yet"
    dev.tap_id("settings-gamecenter-accept-Alex")
    dev.wait_view(r"id=settings-gamecenter-friend-Alex")
    dev.tap_id("settings-gamecenter-decline-Kim")
    dev.wait_view(visible("settings-gamecenter-decline-Kim"), gone=True)
    friends = gamecenter(device_data, "friends")
    assert "friend   Alex" in friends and "request" not in friends and "Kim" not in friends, friends
    assert dev.quit() == 0


def test_gamecenter_activities(launch, device_data):
    app = launch("HelloGameCenter", animations=False, os_version="26")
    app.wait_log(r"authenticated: true")
    app.wait_tap_id("activities")
    app.wait_log(r'activity definition: dev\.isim\.gc\.activity\.duel "Duel" party=true players=2-2 style=1')
    app.wait_log(r"activity leaderboards: dev\.isim\.gc\.high_score$")
    app.wait_log(r"activity started: state=1 party code valid=true")
    # the Games app (isim gamecenter ... activity) asks the game to play an activity with a party code
    gamecenter(device_data, APP, "activity", "dev.isim.gc.activity.duel", "ABCD-2345", "arena=sea")
    app.wait_log(r'wants to play activity dev\.isim\.gc\.activity\.duel "Duel" party=ABCD-2345 arena=sea')
    app.wait_log(r"activity ended: state=4 scores=1 achievements=1")
    app.wait_log(r"activity dev\.isim\.gc\.activity\.duel handled")
    app.wait_log(r"score 3000 submitted to dev\.isim\.gc\.high_score")     # ending posts the activity's score
    app.wait_log(r"achievement dev\.isim\.gc\.first_win 100%")
    assert re.search(r"dev\.isim\.gc\.high_score: Player 3000", gamecenter(device_data, APP, "scores"))


def test_gamecenter_multiplayer(launch, tmp_path):
    pat, sam = tmp_path / "pat", tmp_path / "sam"
    nickname(pat, "Pat")
    nickname(sam, "Sam")
    a = launch("HelloGameCenter", data=pat, animations=False)
    b = launch("HelloGameCenter", data=sam, animations=False)
    a.wait_log(r"player: Pat scoped=true")
    b.wait_log(r"player: Sam scoped=true")

    # a friend request from Pat's device, accepted on Sam's
    a.wait_tap_id("friend-request")
    a.wait_tap_id("gc-friend-to")
    a.type("Sam")
    a.wait_view(r"text=Sam")
    a.tap_id("gc-friend-send")
    a.wait_log(r"friend request sent to Sam")
    b.wait_log(r"friend request from Pat")
    assert "request  from Pat" in gamecenter(sam, "friends")
    gamecenter(sam, "accept-friend", "Pat")
    a.wait_view(visible("gc-friend-send"), gone=True)
    a.tap_id("photo")
    a.wait_view(r"Allow “Game Center” to access your Game Center friends\?")
    a.tap_text("OK")
    a.wait_log(r"friends: 1 Sam$")

    # automatch: both look for a 2-player match, connect, exchange data; Sam leaves
    a.tap_id("automatch")
    b.wait_tap_id("automatch")
    a.wait_log(r"findMatch: match=true error=false")
    b.wait_log(r"findMatch: match=true error=false")
    a.wait_log(r"match player Sam state=1 players=1 expecting=0")
    b.wait_log(r"match player Pat state=1 players=1 expecting=0")
    a.tap_id("send")
    b.wait_log(r"received: hello from Pat from Pat")
    b.tap_id("send")
    a.wait_log(r"received: hello from Sam from Sam")
    b.tap_id("leave")
    a.wait_log(r"match player Sam state=2 players=0")
    a.tap_id("leave")

    # an invite from the matchmaker: Sam taps the banner and joins
    a.tap_id("match")
    a.wait_tap_id("gc-match-slot-1")
    a.wait_tap_id("gc-match-invite-Sam")
    b.wait_log(r"invite from Pat")
    b.wait_tap_id("gc-banner")
    b.wait_log(r"invite accepted from Pat")
    a.wait_log(r"invite response from Sam: 0")
    a.wait_log(r"matchmaker found: Sam")
    b.wait_log(r"matchmaker found: Pat")
    a.wait_view(visible("gc-match-cancel"), gone=True)
    b.wait_view(visible("gc-match-cancel"), gone=True)
    b.tap_id("send")
    a.wait_log(r"received: hello from Sam from Sam")
    a.tap_id("photo")
    a.wait_log(r"recent players: Sam$")
    a.tap_id("leave")
    b.tap_id("leave")

    # turn-based: Pat starts, Sam is automatched into the open seat, Pat ends the match
    a.tap_id("turn-based")
    a.wait_tap_id("gc-match-find")
    a.wait_log(r"turn event: my turn active=true data=-")
    a.wait_view(visible("gc-match-find"), gone=True)
    a.tap_id("take-turn")
    a.wait_log(r"ended turn: Pat error=none status=3")                   # matching: the second seat is open
    b.tap_id("turn-based")
    b.wait_tap_id("gc-match-find")
    b.wait_log(r"turn event: my turn active=true data=Pat")
    b.wait_view(visible("gc-match-find"), gone=True)
    b.tap_id("take-turn")
    b.wait_log(r"ended turn: Pat,Sam error=none status=1")
    a.wait_log(r"turn event: my turn active=false data=Pat,Sam")
    a.tap_id("end-match")
    a.wait_log(r"ended match: error=none status=2")
    b.wait_log(r"turn-based match ended: my outcome=3 data=Pat,Sam")      # Sam lost
    b.tap_id("load-matches")
    b.wait_log(r"matches: 2:Pat\+Sam$")
    assert re.search(r"Pat, Sam\s+ended\s+data='Pat,Sam'", gamecenter(pat, APP, "matches"))
