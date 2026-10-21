"""CoreHaptics and GameController from Objective-C (GamesObjCTest.app, issue #548): #import <CoreHaptics/CoreHaptics.h> and
<GameController/GameController.h> over the Swift overlays. Haptics: the capability (no Taptic Engine, audio), patterns
from events, a parameter curve and a dictionary (and its export), a refused pattern's CHHapticErrorDomain error, a player
and an advanced player with its completion, the engine's finished handler and AHAP data. Game controllers: a snapshot
gamepad (values, handlers, the subscript, the player index), the host keyboard's keyChangedHandler through
keydown/keyup, and a GCVirtualController whose A button the test taps."""
from isimtest import need_apps


def test_games_objc(launch):
    need_apps("GamesObjCTest")
    app = launch("GamesObjCTest")
    p = "GamesObjC: "
    app.wait_log(p + r"capability haptics 0 audio 1 pan -1\.\.1")
    app.wait_log(p + r"engine started 1 pattern 0\.25 events HapticTransient AudioContinuous curve AudioVolumeControl points 2")
    app.wait_log(p + r"player started 1 error none")
    app.wait_log(p + r"dictionary pattern yes exported 1 events")
    app.wait_log(p + r"bad pattern refused domain com\.apple\.CoreHaptics code -4822")
    app.wait_log(p + r"advanced started 1 rate 2")
    app.wait_log(p + r"ahap played 1")
    app.wait_log(p + r"advanced finished error none")
    app.wait_log(p + r"players finished")
    app.wait_log(p + r"snapshot 1 buttons \d+ A 1 pressed Button A stick 0\.50,-0\.25 handler 0\.50 subscript A player 1 micro yes")
    app.wait_log(p + r"virtual connected error none controller Virtual Controller")
    app.wait_log(p + r"controller connected: Virtual Controller extended=1 category=Virtual Controller")
    app.wait_log(p + r"keyboard Keyboard has right 1")
    app.send("keydown right")
    app.wait_log(p + r"key right down any 1")
    app.send("keyup right")
    app.wait_log(p + r"key right up any 0")
    app.wait_still()
    app.tap(310, 794)                                                  # the virtual controller's A button (as test_spritekit)
    app.wait_log(p + r"virtual A pressed")
    app.wait_log(p + r"virtual A released")
    assert app.quit() == 0
