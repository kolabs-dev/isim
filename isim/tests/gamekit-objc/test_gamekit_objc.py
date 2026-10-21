"""GameKit from Objective-C (GameKitObjCTest.app, issue #559): #import <GameKit/GameKit.h> over the GameKit Swift overlay
and isim's local Game Center, with a test player (Alex) from `isim gamecenter`. Sign-in through authenticateHandler, a
score posted and the leaderboard ranked across players, achievements reported and loaded with their descriptions, the
player's photo, the access point, a saved game, a turn-based match saved, loaded, ended and removed, a GKErrorDomain
error, a challenge from Alex reaching the Objective-C GKLocalPlayerListener (received, then played from its banner), and GKGameCenterViewController /
GKMatchmakerViewController with their Objective-C delegates."""
import os
import subprocess

from isimtest import ISIM, need_apps, visible

APP = "dev.isim.tests.GameKitObjCTest"


def gamecenter(data, *args):
    p = subprocess.run([str(ISIM), "gamecenter", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60,
                       env=dict(os.environ, ISIM_DATA=str(data), ISIM_GAMECENTER=str(data.parent / "gamecenter")))
    assert p.returncode == 0, p.stdout
    return p.stdout


def test_gamekit_objc(launch, device_data):
    need_apps("GameKitObjCTest")
    for args in (("player", "add", "Alex"), (APP, "score", "Alex", "dev.isim.gkobjc.high_score", "1500")):
        gamecenter(device_data, *args)
    app = launch("GameKitObjCTest", animations=False)
    p = "GameKitObjC: "
    app.wait_log(p + r"before sign-in authenticated 0 same 1")
    app.wait_log(p + r"authenticated 1 error none player Player invitable 1 underage 0")
    app.wait_log(p + r"access point active 1 location 1")
    app.wait_log(p + r"photo 128x128")
    app.wait_log(p + r'leaderboard dev\.isim\.gkobjc\.high_score "High Score" type 0: 1\. Alex 1,500; 2\. Player 1,200 \| me #2 of 2 context 7 error none')
    app.wait_log(p + r"achievements reported error none: dev\.isim\.gkobjc\.collector 40% completed 0, dev\.isim\.gkobjc\.first_win 100% completed 1")
    app.wait_log(p + r'descriptions 2 points 35 first "First Win" hidden 0')
    app.wait_log(p + r'saved slot1 on iPhone error none; fetched 1 data "level 3"')
    app.wait_log(p + r"max players turn-based 16 peer-to-peer 4")
    app.wait_log(p + r"turn-based status 3 participants 2 mine 4 other 3 current is me 1 error none")
    app.wait_log(p + r'saved turn error none loaded 1 data "x-o"')
    app.wait_log(p + r"ended error none status 2 outcome 2")
    app.wait_log(p + r"removed error none matches left 0")
    app.wait_log(p + r"bad request refused domain GKErrorDomain code 13 is invalid 1")
    app.wait_log(p + r"ready")

    gamecenter(device_data, APP, "challenge", "Alex", "score", "dev.isim.gkobjc.high_score", "1300", "Beat this")
    app.wait_log(p + r'challenge received from Alex "Beat this" state 1 score 1')
    app.wait_tap_id("gc-banner")                                         # the challenge's banner
    app.wait_log(p + r"wants to play challenge from Alex on dev\.isim\.gkobjc\.high_score")

    app.wait_tap_id("dashboard")
    app.wait_log(p + r"dashboard state 0")
    app.wait_tap_id("gc-done")
    app.wait_log(p + r"dashboard finished")
    app.wait_view(visible("gc-done"), gone=True)

    app.wait_tap_id("matchmaker")
    app.wait_log(p + r"matchmaker delegate 1 mode 2 players 2-2")
    app.wait_tap_id("gc-match-cancel")
    app.wait_log(p + r"matchmaker cancelled")
    assert app.quit() == 0
