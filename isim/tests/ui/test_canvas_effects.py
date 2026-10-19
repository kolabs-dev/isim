"""GraphicsContext effects (HelloCanvasEffects): the filters (grayscale, colorMatrix, alphaThreshold, alphaMultiply,
luminanceToAlpha, projectionTransform, a partial colorInvert, two filters applied in order), the multiply blend mode,
clipToLayer (plain, inverse, half opacity, text) and Canvas symbols resolved by tag. Pixels from one screenshot."""
from isimtest import count_px, rgb


def near(c, want, tol=40): return all(abs(a - b) <= tol for a, b in zip(c, want))
def white(c): return near(c, (255, 255, 255), 12)


PIXELS = [   # (what, x, y, predicate)
    ("grayscale red", 50, 130, lambda c: near(c, (54, 54, 54), 30)),
    ("colorMatrix swaps blue to red", 120, 130, lambda c: near(c, (255, 0, 0))),
    ("alphaThreshold: solid inside", 190, 130, lambda c: near(c, (0, 204, 0))),
    ("alphaThreshold: clear where alpha < 0.5", 190 + 24, 130, white),
    ("alphaMultiply: the colour", 260, 130, lambda c: near(c, (128, 0, 255))),
    ("luminanceToAlpha: white turns opaque black", 330, 130, lambda c: near(c, (0, 0, 0), 20)),
    ("projectionTransform moves the drawing", 30, 210, white),
    ("projectionTransform moves the drawing", 65, 210, lambda c: near(c, (0, 0, 255))),
    ("colorInvert(0.5) is grey", 140, 220, lambda c: near(c, (128, 128, 128), 20)),
    ("colorMultiply then colorInvert: cyan", 210, 220, lambda c: near(c, (0, 255, 255))),
    ("multiply: blue × yellow is black", 295, 220, lambda c: near(c, (0, 0, 0), 20)),
    ("multiply over white keeps yellow", 330, 220, lambda c: near(c, (255, 255, 0))),
    ("clipToLayer: inside the circle", 50, 310, lambda c: near(c, (255, 0, 0))),
    ("clipToLayer: outside the circle", 24, 284, white),
    ("clipToLayer: past the circle", 95, 310, white),
    ("inverse: not inside the circle", 140, 310, white),
    ("inverse: outside the circle", 114, 284, lambda c: near(c, (255, 0, 0))),
    ("inverse: past the circle", 185, 310, lambda c: near(c, (255, 0, 0))),
    ("clipToLayer opacity 0.5", 220, 310, lambda c: near(c, (255, 128, 128), 25)),
    ("symbol drawn at each point", 35, 385, lambda c: near(c, (255, 128, 0))),
    ("symbol drawn at each point", 155, 385, lambda c: near(c, (255, 128, 0))),
    ("between symbols", 55, 385, white),
    ("symbol at half opacity, stretched", 50, 420, lambda c: near(c, (255, 191, 128), 25)),
]


def test_canvas_effects(launch):
    app = launch("HelloCanvasEffects")
    app.wait_log(r"symbol dot 30x30 label true missing true")
    shot = app.screenshot("effects")
    failed = [(what, x, y, rgb(shot, x, y)) for what, x, y, pred in PIXELS if not pred(rgb(shot, x, y))]
    assert not failed, f"pixels: {failed}"
    colored = count_px(shot, (250, 280, 120, 60), lambda c: not white(c))
    assert 600 < colored < 120 * 60 * 0.7, f"text as a layer mask: only the letters are painted ({colored} px)"
    labels = count_px(shot, (200, 370, 120, 30), lambda c: c[2] > 150 and c[0] < 100)
    assert labels > 50, f"the Text symbol is drawn ({labels} blue px)"
    assert app.quit() == 0, "exits cleanly"
