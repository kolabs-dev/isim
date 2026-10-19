"""Core Animation layer features (HelloCoreAnimation, -layers), one page each: contents (contentsCenter 9-slice,
contentsRect, contentsScale, gravities), CATextLayer truncation, CAEmitterLayer sub-cells and 3D emission,
CATransformLayer (a shared 3D space) against a flattening layer, CAScrollLayer (scroll(to:), scrollMode,
scrollRectToVisible, visibleRect), CATransition kinds paused half-way, CAValueFunction (basic and keyframe),
shouldRasterize / rasterizationScale, and filters / compositingFilter (not applied, like iOS)."""
from isimtest import count_px, near, rgb

BLACK, WHITE, GRAY = (0, 0, 0), (255, 255, 255), (170, 170, 170)
RED, BLUE, GREEN, ORANGE = (255, 0, 0), (0, 0, 255), (0, 255, 0), (255, 128, 0)


def is_(img, x, y, colour, tol=30):
    return near(rgb(img, x, y), colour, tol)


def page(launch, name, ready):
    app = launch("HelloCoreAnimation", args=["-layers"], env={"PAGE": name})
    app.wait_log(ready)
    app.wait_still()
    return app


def test_contents(launch):
    app = page(launch, "contents", r"^contents ready")
    img = app.screenshot("contents")
    assert app.quit() == 0
    # contentsCenter: the 10 pt frame keeps its width when the layer (20, 100, 150 x 90) is stretched
    assert is_(img, 25, 145, BLACK) and is_(img, 35, 145, WHITE) and is_(img, 95, 105, BLACK) and is_(img, 95, 120, WHITE), \
        "contentsCenter (9-slice): corners and edges stay 10 pt"
    # the same image without it scales as a whole: the frame is 50 pt wide, 30 pt high
    assert is_(img, 255, 145, BLACK) and is_(img, 315, 125, BLACK) and is_(img, 295, 145, WHITE), "without contentsCenter: scaled"
    assert is_(img, 25, 275, BLUE) and is_(img, 165, 275, BLUE), "contentsRect: only the right (blue) half, stretched"
    assert is_(img, 295, 275, RED) and is_(img, 310, 275, GRAY) and is_(img, 295, 290, GRAY), \
        "contentsScale 2, gravity center: a 40 px image is 20 pt, centred"
    assert is_(img, 25, 365, RED) and is_(img, 25, 440, GRAY) and is_(img, 60, 365, GRAY), \
        "gravity bottomLeft is the top left on iOS (Core Animation's gravities are y-up)"
    assert is_(img, 260, 363, GRAY) and is_(img, 260, 405, RED) and is_(img, 330, 405, BLUE) and is_(img, 260, 447, GRAY), \
        "resizeAspect: the 2:1 image fills the width, centred vertically (7.5 pt bars)"


def test_text_truncation(launch):
    app = page(launch, "text", r"^text attributed:")
    img = app.screenshot("text")
    assert app.quit() == 0
    log = app.log
    assert "text none: The quick brown fox jumps over the lazy dog" in log, "none: drawn whole"
    assert "text start: …" in log and "lazy dog\n" in log.split("text start: ")[1].split("text middle")[0], "start: …, the end"
    mid = log.split("text middle: ")[1].split("\n")[0]
    assert mid.startswith("The quick") and "…" in mid and mid.endswith("dog"), f"middle: the start … the end ({mid})"
    end = log.split("text end: ")[1].split("\n")[0]
    assert end.startswith("The quick brown") and end.endswith("…"), f"end: the start … ({end})"
    wrapped = log.split("text wrapped: ")[1].split("\n")[0]
    assert wrapped.endswith("…") and "again" not in wrapped and len(wrapped) > len(end), \
        f"wrapped: as many lines as fit the height, ending with … ({wrapped})"
    rich = log.split("text attributed: ")[1].split("\n")[0]
    assert "…" in rich and rich.endswith("dog"), f"an attributed string is truncated too ({rich})"
    ink = lambda c: sum(c) < 400                                                         # noqa: E731
    assert count_px(img, (191, 100, 60, 24), ink) == 0, "none: the text is cut off at the layer's bounds"
    assert count_px(img, (20, 100, 170, 24), ink) > 50, "none: drawn"


def test_emitter_sub_cells(launch):
    app = page(launch, "emitter", r"^emitter rockets>0")
    img = app.screenshot("emitter")
    assert app.quit() == 0
    assert "emitter rockets>0 true trails>0 true out>0 true" in app.log, "rockets, their trails and the 3D cell all live"
    red = lambda c: c[0] > 180 and c[1] < 90 and c[2] < 90                              # noqa: E731
    blue = lambda c: c[2] > 180 and c[0] < 90 and c[1] < 90                             # noqa: E731
    assert count_px(img, (0, 100, 200, 450), red) > 150, "rockets with red trails (the trail cells inherit the colour)"
    assert count_px(img, (0, 0, 200, 90), red) == 0, "the rockets have not left the screen"
    near_point = count_px(img, (280, 280, 40, 40), blue)
    assert near_point > 10 and count_px(img, (200, 0, 202, 600), blue) <= near_point + 4, \
        "emissionLatitude π/2: the particles fly at the viewer and stay at the emitter point on screen"


def test_transform_layer(launch):
    app = page(launch, "transform", r"^transform ready")
    img = app.screenshot("transform")
    assert app.quit() == 0
    assert is_(img, 110, 190, BLUE), "a plain layer flattens its sublayers (blue over red), then turns the picture over"
    assert is_(img, 290, 190, RED), "a CATransformLayer turned half a turn: the red layer behind is now in front"
    colours = {"green": (52, 199, 89), "orange": (255, 149, 0), "purple": (175, 82, 222)}
    for name, c in colours.items():
        assert count_px(img, (100, 380, 200, 200), lambda p, c=c: near(p, c, 40)) > 800, f"the box's {name} face is drawn"


def test_scroll_layer(launch):
    app = page(launch, "scroll", r"^scroll ready")
    img = app.screenshot("scroll")
    assert app.quit() == 0
    assert is_(img, 200, 150, ORANGE, 40) and is_(img, 105, 105, ORANGE, 40), "scroll(to: 200, 100): the bottom right quadrant"
    assert is_(img, 200, 280, GREEN, 40), "scrollMode horizontally: only x scrolls (the top right quadrant)"
    assert "scroll origin 120 70 visibleRect 120 70 200 100" in app.log, "scrollRectToVisible scrolls the least; visibleRect"
    assert "scroll point origin 10 20" in app.log, "scrollPoint puts the point at the scroll layer's origin"


def test_transitions(launch):
    app = page(launch, "transition", r"^transition ready")
    img = app.screenshot("transition")
    assert app.quit() == 0
    y = 180
    fade = rgb(img, 60, y)
    assert 90 < fade[0] < 170 and 90 < fade[2] < 170 and fade[1] < 40, f"fade half-way: red and blue mixed ({fade})"
    assert is_(img, 120, y, RED) and is_(img, 190, y, BLUE), "push from the right: old (red) out to the left, new (blue) in"
    assert is_(img, 250, 145, BLUE) and is_(img, 250, 215, RED), "moveIn from the top: the new layer (blue) over the top half"
    assert is_(img, 310, y, BLUE) and is_(img, 380, y, RED), "reveal from the left: the old layer (red) slides right, uncovering blue"


def test_value_functions(launch):
    app = page(launch, "valuefn", r"^vf model identity")
    img = app.screenshot("valuefn")
    assert app.quit() == 0
    log = app.log
    assert "vf rotateZ m11 0.71 m12 0.71" in log, "rotateZ 0 → π/2 half-way: 45°"
    assert "vf translateX m41 50.00" in log, "translateX 0 → 100 half-way"
    assert "vf scale m11 1.50 m22 2.00 m33 1.00" in log, "scale [1, 1, 1] → [2, 3, 1] half-way"
    assert "vf keyframe angle 2.00" in log, "keyframe rotateZ values 0, 1, 3 at 0.75: 2 rad"
    assert "vf model identity true" in log, "the model transform is untouched"
    assert is_(img, 200, 190, RED) and is_(img, 145, 145, RED) and not is_(img, 120, 190, RED), "the bar is drawn at 45°"
    assert is_(img, 75, 350, BLUE) and not is_(img, 25, 350, BLUE), "the square drawn 50 pt to the right"


def test_rasterize_and_filters(launch):
    app = page(launch, "raster", r"^raster ready")
    img = app.screenshot("raster")
    assert app.quit() == 0
    row = [rgb(img, x, 160)[0] for x in range(40, 80)]
    assert max(row) > 200 and min(row) < 50, "1 pt stripes drawn directly"
    grey = [rgb(img, x, 160)[0] for x in range(240, 280)]
    assert all(80 < v < 180 for v in grey), f"rasterizationScale 0.25: the bitmap is too coarse for the stripes ({grey[:6]})"
    sharp = [rgb(img, x, 280)[0] for x in range(40, 80)]
    assert max(sharp) > 200 and min(sharp) < 50, "rasterized at the screen's scale: the stripes stay"
    faded = [rgb(img, x, 280)[0] for x in range(240, 280)]
    assert min(faded) > 100 and max(faded) > 200, "opacity 0.5 applies to the rasterized bitmap"
    assert "raster ready filters 1 compositing multiplyBlendMode" in app.log, "filters and compositingFilter are stored"
    assert is_(img, 120, 430, RED) and is_(img, 65, 405, RED) and is_(img, 280, 430, RED) and is_(img, 40, 430, BLUE), \
        "filters / compositingFilter are not applied on iOS: plain red over blue, sharp edges"
