"""Two fingers (HelloMultiTouch): scripted pinch / rotate2 / twofinger drive UIPinchGestureRecognizer,
UIRotationGestureRecognizer and a 2-touch UIPanGestureRecognizer recognized together (card transform in pixels); a
multipleTouchEnabled view sees both UITouches in UIEvent.allTouches; UIScrollView pinch zooming and double-tap
zoomToRect (zoomScale, contentSize, zoomed pixels); hover drives UIHoverGestureRecognizer; on iPad a pointer
interaction gets its region request and the highlight effect. Port of tests/ui/multitouch.sh."""
from isimtest import rgb, runs_x


def orange(c):
    return c[0] > 230 and 120 < c[1] < 175 and c[2] < 40


def squares(img):
    """median width of the teal checker squares along row 640 (20 pt unzoomed)"""
    rs = sorted(e - s for s, e in runs_x(img, 640, 22, 380, lambda c: c[2] > 150 and c[0] < 120 and c[1] > 140))
    return rs[len(rs) // 2] if rs else 0


def test_multitouch(launch):
    app = launch("HelloMultiTouch")
    start = app.screenshot("start")
    assert not orange(rgb(start, 50, 250)), "the card starts small"
    a = squares(start)
    assert 19 <= a <= 21, f"checker squares are 20 pt before zooming: {a}"

    app.send("pinch 201 250 2 0.5")
    s = float(app.wait_log(r"pinch ended scale ([0-9.]+)").group(1))
    assert app.has(r"^pinch began with 2 touches"), "pinch recognizer sees two touches"
    assert 1.9 < s < 2.1, f"pinch scale 2.0 (fingers 100 -> 200 pt): {s}"
    assert orange(rgb(app.screenshot("pinch"), 50, 250)), "card scaled in pixels"

    app.send("rotate2 201 250 45 0.5")
    d = abs(int(app.wait_log(r"rotation ended (-?[0-9]+) degrees").group(1)))
    assert 44 <= d <= 46, f"rotation 45 degrees: {d}"
    app.send("twofinger 201 250 80 0 0.5")
    x = int(app.wait_log(r"two-finger pan ended at ([0-9]+)").group(1))
    assert 60 <= x <= 81, f"two-finger pan (minimumNumberOfTouches 2): {x}"

    app.send("pinch 201 450 1.5 0.3")
    app.wait_log(r"^touchpad ended 1 touch, 2 in event")
    assert app.has(r"^touchpad began 1 touch, 2 down"), "multipleTouchEnabled view gets the 2nd touch"

    app.send("pinch 201 620 2.5 0.6")
    app.wait_log(r"^zoom ended scale 2\.50, content 905 x 550")      # scroll view pinch zoom 2.5x
    assert app.has(r"^zoom began")
    b = squares(app.screenshot("zoom"))
    assert 48 <= b <= 52, f"zoomed content in pixels (20 -> 50 pt squares): {b}"

    app.tap(150, 600).tap(150, 600)
    app.wait_log(r"^zoom ended scale 1\.00, content 362 x 220")      # double tap: setZoomScale(1)
    app.sleep(0.5)                                                    # past the double-tap interval: a new double tap
    app.tap(150, 600).tap(150, 600)
    app.wait_log(r"^zoom ended scale 4\.00, content 1448 x 880")     # then zoomToRect 4x

    app.send("hover 100 770").send("hover 120 775").send("hover 100 300")
    app.wait_log(r"^hover ended")
    assert app.has(r"^hover began") and app.has(r"^hover at 100,35"), "hover began / moved / ended"
    assert app.count(r"^pinch ended") == 1 and app.count(r"^rotation ended") == 1, "pinch/rotate don't fire on a pan"
    assert not app.has(r"pointer region requested"), "no pointer effects on iPhone"
    assert app.quit() == 0


def test_pointer_ipad(launch):
    app = launch("HelloMultiTouch", device="ipad")
    app.send("hover 300 300")
    app.sleep(0.2)
    app.send("hover 600 770")
    app.wait_log(r"^pointer entered button")
    assert app.has(r"^pointer region requested"), "iPad pointer: region + enter"
    app.wait_view(r"id=isim-pointer-effect\b")                        # highlight platter
    app.send("hover 300 300")
    app.wait_view(r"id=isim-pointer-effect\b", gone=True)             # then gone
    assert app.quit() == 0
