"""Scene, window, screen and app members (HelloSceneExtras): Settings URLs, the default-browser check, the status bar
manager, windowing behaviours, system protection, activation conditions (content routed to the scene that prefers
it), screen modes / EDR / the fixed coordinate space, the window's aspect-fit safe area guide (iOS 26), Mac geometry
preferences failing as a UISceneError, an activation action's alternate on iPhone, the window drag interaction,
Shake to Undo (script `shake`), the scene delegate's orientations and the orientation lock (iOS 26); under
`isim boot`, protected data follows the lock screen."""
import pytest

BUNDLE = "dev.isim.samples.HelloSceneExtras"


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_scene_extras(launch, ios):
    v = major(ios)
    app = launch("HelloSceneExtras")
    app.wait_log(r"^sx ready can undo true Move$")
    log = app.log
    w, h = map(int, app.wait_log(r"^sx fixed bounds (\d+)x(\d+)$").groups())    # the device's portrait size
    assert "sx urls app-settings: app-settings:notifications can open true" in log
    assert "sx protected true shake to edit true" in log
    if "sx default browser" in log:                                     # iOS 18.2 and later
        assert "sx default browser false" in log
    if v >= 18:
        assert "sx windowing closable true protection false pointer lock none" in log
    assert "sx status bar hidden false height 54 style 0" in log, "iPhone with the Dynamic Island: 54 pt"
    assert "sx status bar style now 1" in log, "the top view controller's style"
    assert "sx continue dev.isim.doc doc-1" in log, "the scene that prefers the content gets the activity"
    assert f"sx modes 1 preferred {w * 3}x{h * 3} ratio 1 current same true" in log
    assert "sx edr 1 1 overscan true latency 0 mirrored true reference true" in log
    assert "sx geometry error true" in log, "Mac preferences fail, bridged to UISceneError"
    if v >= 26:
        assert f"sx aspect fit {w}x{w} square true fits true centred true" in log

    # an activation action on iPhone runs its alternate; the window drag interaction reports the pan
    app.tap_id("open")
    app.wait_log(r"^sx alternate action$")
    if v >= 26:
        app.drag(50, 250, 150, 260, 0.3)
        app.wait_log(r"isim: window drag \d+,\d+")

    # the scene delegate allows landscape (the Info.plist doesn't); the fixed space stays portrait-up
    app.send("rotate landscapeleft")
    app.wait_log(rf"^sx rotated 3 {h}x{w} fixed point {w - 20},10$")
    if v >= 26:
        app.wait_log(r"^sx orientation locked true$")
        app.send("rotate portrait")                                      # locked: the interface stays in landscape
        app.send("shake")
    else:
        app.send("rotate portrait")
        app.wait_log(rf"^sx rotated 1 {w}x{h} fixed point 10,20$")
        app.send("shake")
    # Shake to Undo offers the last change
    app.wait_log(r'isim: shake to undo alert "Undo Move"')
    app.tap_id("alert-Undo")
    app.wait_log(r"^sx undone count 0$")
    if v >= 26:
        assert "sx rotated 1" not in app.log, "the orientation lock kept landscape"
    assert app.quit() == 0


def test_scene_extras_protected_data(launch):
    dev = launch(None, install=["HelloSceneExtras"])
    dev.send(f"launch {BUNDLE}")
    dev.wait_log(r"sx ready can undo true")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_log(r"sx protected data will become unavailable true")
    dev.wait_log(r"isim: protected data unavailable")
    dev.drag(200, 860, 200, 600, 0.3)                                    # swipe up: unlock
    dev.wait_log(r"sx protected data available true")
