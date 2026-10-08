"""SF Symbols effects on UIImageView (HelloSymbolEffects, UIKit, per iOS version): scale (held until removed, by
pixels), disappear / appear (by pixels), bounce with a repeat count, pulse and its removal, variable colour, replace
content transition (setSymbolImage); iOS 18 wiggle, rotate (continuous, removed), breathe (periodic); iOS 26 draw off /
on. iOS 17 has no wiggle/rotate/breathe, iOS 18 no draw off/on. Port of tests/ui/symboleffects.sh."""
from isimtest import count

HEART = (0, 100, 140, 240)


def red(c): return c[0] > 200 and c[1] < 90 and c[2] < 90
def blue(c): return c[2] > 200 and c[0] < 80


def shot_until(app, name, box, pred, cond, what):
    return app.wait_until(lambda: (lambda n: [n] if cond(n) else None)(count(app.screenshot(name), box, pred)),
                          what=what)[0]


def test_ios26(launch):
    app = launch("HelloSymbolEffects", os_version="26")
    start = app.screenshot("start")
    heart0, star0 = count(start, HEART, red), count(start, (150, 120, 250, 220), blue)
    assert heart0 > 300 and star0 > 300, f"the symbols draw: heart {heart0}, star {star0}"
    app.wait_tap("scaleUp")
    heart1 = shot_until(app, "scaled", HEART, red, lambda n: n * 100 > heart0 * 135,
                        f"scale.up holds the symbol larger (pixels from {heart0})")
    app.tap_id("scaleOff")
    app.wait_log(r"scale removed true")
    app.wait_log(r"heart: transform identity true, alpha 1\.00")         # scale removed until removal
    app.tap_id("hide")
    app.wait_log(r"disappeared true")
    shot_until(app, "hidden", (140, 100, 260, 240), blue, lambda n: n < 20, "disappear hides the symbol (pixels)")
    app.tap_id("show")
    app.wait_log(r"appeared true")
    app.wait_log(r"star: transform identity true, alpha 1\.00")          # appear brings it back
    app.tap_id("bounce")
    app.wait_log(r"bouncing bell: transform identity false")
    app.wait_log(r"bounce finished true")
    app.wait_log(r"bell: transform identity true, alpha 1\.00")          # bounce animates, repeats and completes
    app.tap_id("pulse")
    app.wait_log(r"pulsing alpha below 1 true")
    app.wait_log(r"pulse ended false")
    app.wait_log(r"pulse removed true")
    app.wait_log(r"heart: transform identity true, alpha 1\.00", count=2)  # pulse until removed, alpha back
    app.tap_id("variable")
    app.wait_log(r"variable color finished true")                       # variable colour (non-repeating) completes
    app.tap_id("replace")
    app.wait_log(r"replaced true, transition true, image moon true")
    shot_until(app, "replaced", (150, 120, 250, 220), blue, lambda n: n > 200, "setSymbolImage(.replace) swaps the image")
    app.tap_id("wiggle")
    app.wait_log(r"wiggling bell: transform identity false")
    app.wait_log(r"wiggle finished true")
    app.tap_id("rotate")
    app.wait_log(r"rotating bell: transform identity false")
    app.wait_log(r"rotate ended false")
    app.wait_log(r"rotate removed true")                                 # rotate: continuous until removed
    app.tap_id("breathe")
    app.wait_log(r"breathe finished true")                               # breathe (periodic)
    app.tap_id("drawOff")
    app.wait_log(r"drawn off true")
    shot_until(app, "drawn-off", (140, 100, 260, 240), blue, lambda n: n < 20, "iOS 26 draw off (pixels)")
    app.tap_id("drawOn")
    app.wait_log(r"drawn on true")                                       # iOS 26 draw on
    assert app.quit() == 0


def test_ios17(launch):
    app = launch("HelloSymbolEffects", os_version="17", device="iphone15")   # a device that shipped with iOS 17
    app.wait_tap("bounce")
    app.wait_log(r"bounce finished true")                                # iOS 17: bounce works ...
    app.tap_id("wiggle").tap_id("rotate").tap_id("breathe")
    for effect in ("wiggle", "rotate", "breathe"):
        app.wait_log(rf"{effect} unavailable")                           # ... no iOS 18 effects
    assert app.quit() == 0


def test_ios18(launch):
    app = launch("HelloSymbolEffects", os_version="18")
    app.wait_tap("wiggle")
    app.wait_log(r"wiggle finished true")                                # iOS 18: wiggle works ...
    app.tap_id("drawOff")
    app.wait_log(r"draw off unavailable")                                # ... no draw off
    assert app.quit() == 0
