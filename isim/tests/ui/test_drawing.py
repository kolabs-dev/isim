"""SwiftUI drawing and animation (HelloDrawing): custom Shape/Path rendering, even-odd fill, gradients (linear, radial,
angular, elliptical, Color.gradient, foregroundStyle, background), dashed strokes, trim, strokeBorder, uneven corners,
clipShape(custom), Canvas (transform, opacity, clip, text), projection effects, shape transforms; then animatable
trim/custom shape/color/gradient checked half-way through a 2 s linear animation, TimelineView ticks, phaseAnimator and
keyframeAnimator. Port of tests/ui/drawing.sh: pixels from one screenshot per state; the mid-animation screenshot keeps
its timing."""
import re
import time

from isimtest import count, rgb


def white(c): return c[0] > 235 and c[1] > 235 and c[2] > 235
def dark(c): return c[0] < 60 and c[1] < 60 and c[2] < 60
def purple(c): return c[0] > 130 and c[2] > 180 and c[1] < 120


SHAPES = [   # (check, [(x, y, predicate on (r, g, b))])
    ("custom Shape path(in:) filled", [(70, 160, lambda c: c[0] > 200 and c[1] < 100 and c[2] < 100), (25, 85, white)]),
    ("Path with even-odd fill leaves a hole", [(150, 90, lambda c: c[2] > 200 and c[0] < 60), (190, 130, white)]),
    ("Ellipse", [(320, 110, lambda c: c[1] > 150 and c[0] < 120 and c[2] < 120), (263, 83, white)]),
    ("LinearGradient view (leading->trailing)", [(22, 220, lambda c: c[0] > 230 and c[2] < 30),
                                                 (178, 220, lambda c: c[2] > 230 and c[0] < 30),
                                                 (100, 220, lambda c: 90 < c[0] < 170 and 90 < c[2] < 170)]),
    ("RadialGradient fill", [(240, 240, lambda c: c[0] > 220 and c[1] > 220), (276, 240, lambda c: c[0] < 70 and c[1] < 70)]),
    ("AngularGradient (0 red, 120 green, 240 blue)", [(370, 240, lambda c: c[0] > 200 and c[1] < 60 and c[2] < 60),
                                                      (325, 266, lambda c: c[1] > 150 and c[0] < 100 and c[2] < 100),
                                                      (325, 214, lambda c: c[2] > 150 and c[0] < 100 and c[1] < 100)]),
    ("dashed stroke (StrokeStyle dash)", [(25, 300, lambda c: c[0] < 70 and c[1] < 70 and c[2] < 70), (35, 300, white)]),
    ("UnevenRoundedRectangle", [(203, 303, white), (277, 303, lambda c: c[0] > 230 and 110 < c[1] < 180 and c[2] < 60)]),
    ("trim(from:to:) stroke (bottom half only)", [(340, 370, purple), (340, 290, white)]),
    ("strokeBorder draws inside the frame", [(60, 384, purple), (60, 420, white)]),
    ("clipShape with a custom shape", [(125, 385, white), (160, 450, lambda c: c[1] > 140 and c[2] > 160 and c[0] < 120)]),
    ("Canvas fill + translateBy", [(225, 385, lambda c: c[0] > 240 and c[1] < 20 and c[2] < 20),
                                   (315, 395, lambda c: 110 < c[1] < 150 and c[0] < 20 and c[2] < 20)]),
    ("Canvas opacity", [(240, 460, lambda c: 100 < c[0] < 150 and c[2] > 240)]),
    ("Canvas clip + linear gradient shading", [(360, 450, lambda c: c[0] > 230 and c[2] < 80), (322, 422, white)]),
    ("Color.gradient (lighter at the top)", [(70, 482, lambda c: c[2] > 200), (70, 518, lambda c: c[2] > 200)]),
    ("foregroundStyle(LinearGradient) on a shape", [(142, 500, lambda c: c[0] > 230 and c[1] < 40),
                                                    (238, 500, lambda c: c[0] > 230 and c[1] > 220)]),
    ("EllipticalGradient", [(320, 500, lambda c: c[1] > 200), (262, 482, lambda c: c[1] < 70)]),
    ("background(LinearGradient)", [(22, 602, lambda c: c[1] > 200 and c[2] > 200 and c[0] < 60),
                                    (22, 628, lambda c: c[0] > 200 and c[2] > 200 and c[1] < 60)]),
    ("rotation3DEffect (y axis, 60 degrees)", [(30, 560, white), (70, 560, lambda c: c[1] > 150 and c[0] < 120)]),
    ("transformEffect (translation)", [(145, 560, white), (225, 560, lambda c: c[2] > 200 and c[0] < 60)]),
    ("Shape.rotation (diamond past its frame)", [(310, 537, lambda c: c[0] > 200 and c[1] < 100), (283, 548, white)]),
    ("AnyShape(Capsule())", [(190, 615, lambda c: c[2] > 150 and c[0] < 120 and c[1] < 120), (141, 601, white)]),
    ("Shape.offset", [(320, 660, lambda c: 120 < c[0] < 200 and c[1] > 90 and c[2] < 120), (285, 660, white)]),
    ("InsettableShape.inset(by:)", [(145, 655, white), (170, 680, lambda c: c[1] > 180 and c[2] > 150 and c[0] < 120)]),
    ("ImagePaint tiles an image (20 pt symbol)", [(230, 710, dark), (250, 710, dark), (230, 730, dark), (221, 701, white)]),
    ("Canvas draws an image", [(360, 400, dark), (360, 385, white)]),
    ("custom GeometryEffect (shear)", [(22, 702, purple), (22, 738, white), (42, 738, purple)]),
    ("Core Graphics even-odd fill and line dash", [(40, 770, white), (24, 754, lambda c: c[0] > 230 and c[1] < 40),
                                                   (75, 770, dark), (85, 770, white), (95, 770, dark)]),
]


def test_drawing(launch):
    app = launch("HelloDrawing")
    app.wait_log(r"symbol size 20x20")
    shapes = app.screenshot("shapes")
    failed = [(what, x, y, rgb(shapes, x, y)) for what, pts in SHAPES for x, y, pred in pts if not pred(rgb(shapes, x, y))]
    assert not failed, f"shape pixels: {failed}"
    assert rgb(shapes, 70, 482)[0] > rgb(shapes, 70, 518)[0], "Color.gradient (lighter at the top)"
    n = 160 * 40
    reds = count(shapes, (220, 750, 380, 790), lambda c: c[0] > 0.8 * 255 and c[1] < 0.3 * 255 and c[2] < 0.3 * 255)
    blues = count(shapes, (220, 750, 380, 790), lambda c: c[2] > 0.8 * 255 and c[0] < 0.3 * 255)
    assert reds / n > 0.04 and blues == 0, f"Text with a gradient style uses its first color ({reds} red, {blues} blue)"
    log = app.log
    for line in ("path description: 0 0 m 100 0 l 100 50 l h", "path bounds: (0.0, 0.0, 100.0, 50.0)",
                 "path contains inside: true outside: false", "trimmed: 0 0 m 100 0 l 100 100 l",
                 "from CGPath bounds: (0.0, 0.0, 20.0, 20.0)", "parsed: 0 0 m 10 0 l 10 10 l h", "arc end: 0,10"):
        assert line in log, f"Path API: {line}"
    assert "timeline duration 2.0 at 0.5: 5.0 at 1.5: true end: 0.0" in log and "unit curve easeIn 0.5: true" in log, \
        "KeyframeTimeline values, UnitCurve"

    app.wait_tap("next")
    trees = [app.wait_tree(r"text=tick [0-9]")]
    app.sleep(0.3)                                                        # the page transition ends
    m0 = app.screenshot("motion0")
    assert white(rgb(m0, 70, 220)), "animated trim starts empty"
    assert rgb(m0, 110, 430)[0] < 60 and max(rgb(m0, 110, 430)) < 60 and white(rgb(m0, 98, 402)), "Canvas arc stroke"
    app.tap_id("animate")
    t0 = time.monotonic()
    time.sleep(max(0.0, t0 + 1.0 - time.monotonic()))                     # ~1 s into the 2 s linear animation
    mid = app.screenshot("motion-mid")
    app.tap_id("bounce")
    t1 = time.monotonic()
    assert purple(rgb(mid, 70, 220)) and white(rgb(mid, 70, 121)), "animated trim is half-way"
    assert rgb(mid, 200, 140)[2] > 200 and rgb(mid, 200, 140)[0] < 60 and white(rgb(mid, 356, 140)), \
        "custom Animatable shape interpolates"
    c0, c = rgb(m0, 170, 215), rgb(mid, 170, 215)
    assert c0[0] > 200 and c0[2] < 60 and 50 < c[0] < 210 and 50 < c[2] < 210, f"shape color interpolates {c0} {c}"
    g0, g = rgb(m0, 225, 190), rgb(mid, 225, 190)
    assert g0[2] > 200 and g0[0] < 60 and g[0] > 60 and g[2] < 200, f"gradient stops interpolate {g0} {g}"
    assert rgb(m0, 40, 520)[1] > 150 and rgb(m0, 40, 520)[0] < 120 and white(rgb(mid, 40, 520)) and \
        rgb(mid, 140, 520)[1] > 150 and rgb(mid, 140, 520)[0] < 120, "AnimatableModifier interpolates (half-way)"
    time.sleep(max(0.0, t1 + 1.6 - time.monotonic()))
    end = app.screenshot("motion-end")
    trees.append(app.tree())
    assert purple(rgb(end, 70, 121)) and rgb(end, 356, 140)[2] > 200 and rgb(end, 356, 140)[0] < 60 and \
        rgb(end, 170, 215)[2] > 200 and rgb(end, 170, 215)[0] < 60, "animations end at the new values"
    assert rgb(end, 240, 520)[1] > 150 and rgb(end, 240, 520)[0] < 120 and white(rgb(end, 140, 520)), \
        "AnimatableModifier ends at the new value"
    app.wait_log(r"^keyframe 50")
    app.wait_until(lambda: re.findall(r"^keyframe .*", app.log, re.M)[-1] == "keyframe 0", timeout=5,
                   what="keyframeAnimator runs on trigger and ends at 0")
    ticks = {m for t in trees for m in re.findall(r"text=tick [0-9]*", t)}
    assert len(ticks) >= 2, f"TimelineView(.periodic) re-renders: {ticks}"
    log = app.log
    assert "animation timeline 30 frames, live: true" in log, "TimelineView(.animation) updates per frame"
    assert len(re.findall(r"^phase 0", log, re.M)) >= 2 and re.search(r"^phase 1", log, re.M) and \
        re.search(r"^phase 2", log, re.M), "phaseAnimator cycles through phases"
    assert "bounce tapped" in log and re.search(r"^keyframe 30", log, re.M), "keyframeAnimator runs on trigger"
    assert app.quit() == 0
