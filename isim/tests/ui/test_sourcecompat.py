"""Source-compatibility patterns from real apps (HelloSourceCompat). Port of tests/ui/sourcecompat.sh: pixel checks
use Pillow on one screenshot instead of one ImageMagick process per pixel."""


def is_red(px):
    r, g, b = px
    return r > 180 and g < 90 and b < 90


def test_source_compat(launch):
    app = launch("HelloSourceCompat")
    app.wait_log(r"^compat scene phase active")                       # Scene.onChange(of: scenePhase, initial:)
    app.wait_log(r"^compat statics true bundle=dev.isim.samples.HelloSourceCompat")   # Color/Bundle statics

    star = app.wait_for(id="star-text")
    favorites = app.find(id="favorites")
    assert favorites and favorites.label.endswith("Favorites")        # Text(Image) + Text: one label
    canvas = app.find(id="canvas")
    shot = app.screenshot()
    assert is_red(shot.getpixel(tuple(map(int, star.center)))), "Text(Image) symbol in the text colour"
    assert is_red(shot.getpixel(tuple(map(int, canvas.center)))), "Canvas draws Text(Image)"

    drag = app.find(id="drag-area")
    x, y = drag.center
    app.drag(x - 80, y, x + 80, y, 0.3)
    app.wait_log(r"^compat drag 1")                                     # gesture(cond ? DragGesture() : nil)
    app.wait_for(id="disable").tap()
    app.wait_log(r"^compat drag disabled")
    app.drag(x - 80, y, x + 80, y, 0.3)
    app.wait_for(id="haptic").tap()
    app.wait_log(r"^compat haptic")                                     # impactOccurred(intensity:)
    assert "compat drag 2" not in app.log, "gesture(nil) installs nothing"
    assert app.quit() == 0
