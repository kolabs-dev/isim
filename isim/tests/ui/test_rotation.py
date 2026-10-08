"""Rotation (HelloRotation): turning the device (script `rotate`), Info.plist supported orientations,
viewWillTransition(to:with:) + coordinator, size classes, side safe areas and the landscape screen shape,
requestGeometryUpdate, setNeedsUpdateOfSupportedInterfaceOrientations; an app without UISupportedInterfaceOrientations
stays portrait. Port of tests/ui/rotation.sh (iPhone 16 Pro sizes)."""
from isimtest import rgb


def shot_of_size(app, size):
    return app.wait_until(lambda: (lambda s: s if s.size == size else None)(app.screenshot()),
                          what=f"a {size[0]}x{size[1]} screenshot")


def test_rotate(launch):
    app = launch("HelloRotation")
    app.send("rotate left")
    app.wait_log(r"^transitioned: view 874x402, safe left 62 bottom 21, scene 3")   # landscape safe areas + scene
    assert app.has(r"^device orientation 3"), "device orientation notification"
    assert app.has(r"^will transition to 874x402"), "viewWillTransition to landscape"
    assert app.has(r"^traits h=1 v=1"), "compact height size class"
    assert "UIView (62 351; 750 x 30) id=bar" in app.tree(), "safe-area layout follows"
    landscape = shot_of_size(app, (874, 402))                         # landscape screen (through the shell)
    assert rgb(landscape, 28, 200) == (0, 0, 0), "the landscape screen shape (black sensor housing)"
    app.wait_tap("lock")
    app.wait_log(r"^will transition to 402x874")                     # locking to portrait turns back
    shot_of_size(app, (402, 874))
    assert app.quit() == 0


def test_request_geometry_update(launch):
    app = launch("HelloRotation")
    app.wait_tap("force")
    app.wait_log(r"^will transition to 874x402")                     # requestGeometryUpdate forces landscape
    shot_of_size(app, (874, 402))
    assert app.quit() == 0


def test_portrait_only_app(launch):
    app = launch("HelloTable")                                       # no UISupportedInterfaceOrientations
    app.send("rotate left")
    app.sleep(0.8)                                                   # nothing happens: no condition to wait on
    assert app.screenshot().size == (402, 874), "an app without the plist key stays portrait"
    assert not app.has(r"interface orientation 3")
    assert app.quit() == 0
