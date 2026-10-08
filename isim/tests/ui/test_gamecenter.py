"""isim's local Game Center (HelloGameCenter, isim-GameCenter.json). Run 1: sign-in, the access point (shown top
trailing; tapping it opens the dashboard; hidden while Game Center UI is up), scores on classic / low-is-best /
recurring (6 s period) leaderboards and a leaderboard set, achievement descriptions + points in the dashboard,
loadPhoto (generated monogram), friends, the friend request composer, saving a game, the matchmaker (finds nobody).
Then `isim gamecenter ... conflict` adds a version from another device; run 2 fetches saved games, gets the conflict
and resolves it. Port of tests/ui/gamecenter.sh (animations off: only end states are checked)."""
import os
import re
import subprocess

from isimtest import ISIM, visible

APP = "dev.isim.samples.HelloGameCenter"


def gamecenter(data, *args):
    p = subprocess.run([str(ISIM), "gamecenter", APP, *args], env=dict(os.environ, ISIM_DATA=str(data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    return p.stdout


def test_gamecenter(launch, device_data):
    app = launch("HelloGameCenter", animations=False)
    app.wait_log(r"authenticated: true")
    app.wait_log(r"access point shown \(top trailing\)")
    trees = [app.wait_view(r"^UIWindow \(338 66; 48 x 48\)$")]          # the access point, top trailing
    app.wait_tap_id("scores")
    app.wait_log(r"scores posted")
    app.tap_id("achievements")
    app.wait_log(r"achievements reported true")
    app.tap_id("metadata")
    app.wait_log(r'^set: ')
    app.wait_log(r"leaderboard image .*: true", count=3)
    log = app.log
    assert re.search(r'achievement description: dev\.isim\.gc\.first_win "First Win" 10 points hidden=false "Win a game\."', log) \
        and re.search(r'dev\.isim\.gc\.secret "Secret Door" 50 points hidden=true', log), "achievement descriptions from config"
    assert 'leaderboard: dev.isim.gc.high_score "High Score" type=classic best=1200 players=1' in log and \
        'leaderboard: dev.isim.gc.fastest "Fastest Clear" type=classic best=42' in log, \
        "leaderboard titles, types, best scores"
    # the 1200 just posted is in the current 6 s occurrence or (after a reset) in the previous one
    assert ('leaderboard: dev.isim.gc.daily "Daily Run" type=recurring best=1200 players=1 period=6s' in log
            and "previous occurrence best=-1" in log) or \
           ('leaderboard: dev.isim.gc.daily "Daily Run" type=recurring best=-1 players=0 period=6s' in log
            and "previous occurrence best=1200" in log), "recurring leaderboard: 6 s occurrences"
    assert 'set: dev.isim.gc.set.season1 "Season 1" boards=dev.isim.gc.high_score,dev.isim.gc.fastest' in log
    assert app.count(r"leaderboard image .*: true") == 3, "leaderboard set + images"

    app.wait_tap_id("gc-access-point")
    app.wait_log(r"access point opens Game Center")
    trees.append(app.wait_view(r"id=gc-achievements-summary text=1 of 2 Completed · 10 points"))
    app.wait_tap_id("gc-achievements")
    trees.append(app.wait_view(r"text=40% complete · 25 points"))
    assert "text=You won your first game." in trees[-1] and "text=Collect 100 gems." in trees[-1], \
        "dashboard achievements: titles, descriptions"
    app.tap_id("gc-done")
    app.wait_view(visible("gc-done"), gone=True)

    app.wait_tap_id("set")
    trees.append(app.wait_view(r"id=gc-board-dev\.isim\.gc\.high_score\b"))
    assert "text=Season 1" in trees[-1] and "text=Fastest Clear" in trees[-1], "leaderboard set page"
    app.wait_tap_id("gc-board-dev.isim.gc.fastest")
    app.sleep(0.3)
    trees.append(app.view_dump())
    app.tap_id("gc-done")
    app.wait_log(r"dashboard closed")                                    # the dashboard closes via its delegate

    app.wait_tap_id("photo")
    app.wait_log(r"photo: 128x128 true")
    app.wait_log(r"friends: 0")                                          # player photo + empty friends list
    app.wait_tap_id("friend-request")
    app.wait_tap_id("gc-friend-to")
    app.type("pat@example.com")
    app.wait_view(r"pat@example\.com")
    app.tap_id("gc-friend-send")
    app.wait_log(r"friend request to pat@example\.com not sent")        # the composer (not sent)

    app.wait_tap_id("save")
    app.wait_log(r"saved: slot1 on iPhone true")
    assert (device_data / f"Library/GameCenter/{APP}/SavedGames/slot1/versions.json").is_file(), \
        "saved game stored in device data"
    app.wait_tap_id("match")
    app.wait_tap_id("gc-match-find")
    app.wait_log(r"findMatch: match=false error=true")
    trees.append(app.wait_view(r"id=gc-match-note text=No players found"))   # the matchmaker finds nobody
    app.tap_id("gc-match-cancel")
    app.wait_log(r"matchmaker cancelled")
    assert not any("text=Secret Door" in t for t in trees), "the hidden achievement stays hidden"
    assert app.quit() == 0

    conflict = gamecenter(device_data, "conflict", "slot1", "from the iPad")
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
    saves = gamecenter(device_data, "saved-games")
    assert sum("slot1" in l for l in saves.splitlines()) == 1, f"one saved game left: {saves}"
