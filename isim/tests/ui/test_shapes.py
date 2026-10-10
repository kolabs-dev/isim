"""SwiftUI shapes, styles and animation timing (HelloShapes): path boolean operations and strokedPath, line
operations, fill().stroke(), gradient text, ContainerRelativeShape in a containerShape, MeshGradient, Color.mix and
Color.Resolved, custom timing curves, springs and repeatCount."""
import re
import time

import pytest


def window_rect(dump, ident):
    """The window frame of the view with this id: its own frame plus its ancestors' origins."""
    lines = dump.splitlines()
    i = next(k for k, line in enumerate(lines) if re.search(rf" id={re.escape(ident)}\b", line))
    depth = lambda line: len(line) - len(line.lstrip())
    rx = lambda line: tuple(float(v) for v in re.search(r"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\)", line).groups())
    x, y, w, h = rx(lines[i])
    d = depth(lines[i])
    for k in range(i - 1, -1, -1):
        if depth(lines[k]) < d:
            d = depth(lines[k])
            px, py, _, _ = rx(lines[k])
            x += px; y += py
    return x, y, w, h


def px(img, rect, dx, dy):
    """The colour at (dx, dy) inside a rect (window points)."""
    return img.getpixel((int(rect[0] + dx), int(rect[1] + dy)))[:3]


blue = lambda c: c[2] > 200 and c[0] < 60 and c[1] < 160
white = lambda c: min(c) > 240


def test_path_operations(launch):
    app = launch("HelloShapes")
    app.wait_view(r"id=line-ops")
    app.wait_log(r"^line ")
    app.wait_still()
    dump = app.view_dump()
    img = app.screenshot("path-ops")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    # two 80 pt circles, the second 40 pt to the right
    assert "union 0 0 120 80" in log, "union: the bounds of both circles"
    assert "intersection 40 5 40 69" in log, "intersection: the lens between x 40 and 80 (crossings at y 5.4 and 74.6)"
    assert "subtracting 0 0 60 80" in log, "subtracting: the left crescent"
    assert "stroked 5 5 110 70 inside=false edge=true" in log, "strokedPath: a 10 pt ring around the rectangle"
    assert "line 30 40 60 0" in log, "lineIntersection: the part of the line inside the circle"
    u, i, s, x, st = (window_rect(dump, k) for k in ("union", "intersection", "subtracting", "xor", "stroked"))
    assert blue(px(img, u, 20, 40)) and blue(px(img, u, 60, 40)) and blue(px(img, u, 100, 40)), "union fills both circles"
    assert blue(px(img, i, 60, 40)) and white(px(img, i, 20, 40)) and white(px(img, i, 100, 40)), "intersection: only the lens"
    assert blue(px(img, s, 20, 40)) and white(px(img, s, 60, 40)) and white(px(img, s, 100, 40)), "subtracting: the lens cut out"
    assert blue(px(img, x, 20, 40)) and white(px(img, x, 60, 40)) and blue(px(img, x, 100, 40)), "symmetricDifference: both but the lens"
    assert blue(px(img, st, 10, 40)) and white(px(img, st, 60, 40)), "strokedPath filled: the ring, not the inside"
    sh = window_rect(dump, "shape-ops")
    purple = lambda c: c[0] > 150 and c[2] > 180 and c[1] < 120
    assert purple(px(img, sh, 40, 40)) and white(px(img, sh, 4, 4)), "Rectangle().intersection(Circle()): the circle"
    ln = window_rect(dump, "line-ops")
    orange = lambda c: c[0] > 230 and 100 < c[1] < 180 and c[2] < 60
    assert orange(px(img, ln, 60, 40)) and white(px(img, ln, 15, 40)) and white(px(img, ln, 105, 40)), \
        "Shape.lineIntersection: the stroke only inside the circle"


def test_fills(launch):
    app = launch("HelloShapes", env={"PAGE": "fills"})
    app.wait_view(r"id=no-container")
    app.wait_still()
    dump = app.view_dump()
    img = app.screenshot("fills")
    assert app.quit() == 0, "exits cleanly"
    fs = window_rect(dump, "fill-stroke")
    red = lambda c: c[0] > 220 and c[1] < 90 and c[2] < 90
    yellow = lambda c: c[0] > 230 and c[1] > 180 and c[2] < 60
    assert yellow(px(img, fs, 50, 50)) and red(px(img, fs, 50, 2)), "fill(.yellow).stroke(.red): the fill with the stroke on its edge"
    # gradient text: the glyphs run from red (leading) to blue (trailing)
    gx, gy, gw, gh = window_rect(dump, "grad-text")
    ink = [(x, img.getpixel((x, y))[:3]) for x in range(int(gx), int(gx + gw)) for y in range(int(gy), int(gy + gh))
           if not white(img.getpixel((x, y))[:3])]
    left = [c for x, c in ink if x < gx + gw * 0.2]
    right = [c for x, c in ink if x > gx + gw * 0.8]
    avg = lambda cs, k: sum(c[k] for c in cs) / len(cs)
    assert left and right and avg(left, 0) > avg(left, 2) + 60 and avg(right, 2) > avg(right, 0) + 60, \
        "Text with a LinearGradient foregroundStyle: red to blue across the glyphs"
    # ContainerRelativeShape: 20 pt inside a 40 pt rounded rectangle, a 20 pt radius; without a container, a rectangle
    (rx, ry, rw, rh), nc = window_rect(dump, "relative"), window_rect(dump, "no-container")
    rel = (rx + 20, ry + 20, rw - 40, rh - 40)                           # (the id is on the padded view)
    blu = lambda c: c[2] > 200 and c[0] < 60
    assert not blu(px(img, rel, 2, 2)) and blu(px(img, rel, 8, 8)) and blu(px(img, rel, rel[2] / 2, 1)), \
        "ContainerRelativeShape takes the container's rounded shape (concentric radius 20)"
    assert not blu(px(img, rel, 3, 3)) and blu(px(img, rel, 12, 12)), "the corner is rounded with about 20 pt"
    green = lambda c: c[1] > 150 and c[0] < 110 and c[2] < 120
    assert green(px(img, nc, 1, 1)), "outside a container shape: the rectangle"


def test_mesh_gradient(launch):
    app = launch("HelloShapes", env={"PAGE": "mesh"})
    app.wait_view(r"id=mix-perceptual")
    app.wait_log(r"^resolved ")
    app.wait_still()
    dump = app.view_dump()
    img = app.screenshot("mesh")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    assert "mix device 0.50 0.00 0.50" in log, "Color.mix in .device: the sRGB components halfway"
    assert "mix perceptual 0.55 0.33 0.64" in log, "Color.mix (.perceptual): halfway in Oklab"
    assert "resolved 0.25 0.50 1.00" in log, "Color.resolve(in:)"
    m = window_rect(dump, "mesh")
    tl, tr, bl, br = (px(img, m, dx, dy) for dx, dy in ((3, 3), (m[2] - 4, 3), (3, m[3] - 4), (m[2] - 4, m[3] - 4)))
    assert tl[0] > 200 and tl[1] < 100, f"top leading red {tl}"
    assert tr[1] > 160 and tr[0] < 120, f"top trailing green {tr}"
    assert bl[2] > 200 and bl[0] < 80, f"bottom leading blue {bl}"
    assert br[0] > 200 and br[1] > 160 and br[2] < 80, f"bottom trailing yellow {br}"
    c = px(img, m, m[2] / 2, m[3] / 2)
    assert all(60 < v < 200 for v in c), f"the middle blends the four colours {c}"
    mf = window_rect(dump, "mesh-fill")
    top, bottom = px(img, mf, 40, 8), px(img, mf, 40, 72)
    assert white(px(img, mf, 3, 3)) and top[0] > 200 and top[2] < 100 and bottom[2] > 200 and bottom[0] < 100, \
        f"a MeshGradient as a shape style fills the circle ({top} at the top, {bottom} at the bottom)"
    dev, per = px(img, window_rect(dump, "mix-device"), 30, 30), px(img, window_rect(dump, "mix-perceptual"), 30, 30)
    assert dev != per and sum(per) > sum(dev), f"perceptual mixing is lighter than device mixing ({dev} vs {per})"


COLOURS = {"linear": (255, 59, 48), "custom": (0, 122, 255), "spring": (52, 199, 89), "repeat": (255, 149, 0), "interp": (175, 82, 222)}


def test_curves_and_springs(launch):
    app = launch("HelloShapes", env={"PAGE": "curves", "DURATION": "3"})
    app.wait_view(r"id=interp")
    app.wait_log(r"^critical ")
    app.wait_still()
    dump = app.view_dump()
    rows = {k: int(window_rect(dump, k)[1] + 20) for k in COLOURS}
    near = lambda c, k: sum(abs(a - b) for a, b in zip(c, k)) < 60

    def xs(img):
        out = {}
        for k, y in rows.items():
            hit = [x for x in range(img.width) if near(img.getpixel((x, y))[:3], COLOURS[k])]
            out[k] = hit[0] if hit else None
        return out
    start = xs(app.screenshot())
    app.tap_id("go")
    frames, end = [], time.monotonic() + 15
    while time.monotonic() < end:
        f = xs(app.screenshot())
        frames.append(f)
        if len(frames) > 8 and all(fr == f for fr in frames[-6:]) and f["linear"] != start["linear"]:
            break
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    assert re.search(r"^curve 0\.029 0\.133 0\.630", log, re.M), "UnitCurve.bezier: the cubic Bézier's value"
    assert "spring peak 1.254" in log, "Spring(duration:bounce:) overshoots"
    assert "critical 1.000" in log, "Spring(mass:stiffness:damping:): the damping ratio"
    final = frames[-1]
    dist = final["linear"] - start["linear"]
    assert dist > 200, f"the boxes move ({start} -> {final})"
    p = lambda f, k: (f[k] - start[k]) / dist
    mid = [f for f in frames if None not in f.values() and 0.35 < p(f, "linear") < 0.65]
    assert mid, "frames halfway through the linear move"
    assert all(p(f, "custom") < 0.3 for f in mid), "timingCurve(0.9, 0, 1, 1): far behind linear halfway"
    assert max(p(f, "spring") for f in frames if f["spring"] is not None) > 1.15, "spring(bounce: 0.6) overshoots"
    rep = [p(f, "repeat") for f in frames if f["repeat"] is not None]
    peak = next(i for i, v in enumerate(rep) if v > 0.9)
    assert min(rep[peak:]) < 0.2 and rep[-1] > 0.98, "repeatCount(3, autoreverses: true): out, back, out again"
    inter = [p(f, "interp") for f in frames if f["interp"] is not None]
    assert max(inter) > 1.2 and min(inter[inter.index(max(inter)):]) < 0.95, "interpolatingSpring oscillates around the target"
    assert all(abs(p(final, k) - 1) < 0.03 for k in COLOURS), "every animation ends at the target"


SLOTS = {"opacity": (255, 0, 0), "scale": (0, 153, 0), "slide": (0, 0, 255), "move": (255, 128, 0), "offset": (128, 0, 128),
         "push": (0, 128, 128), "asymmetric": (153, 77, 0), "combined": (255, 0, 255)}


def alpha_of(c, k):
    """How much of colour k (over white) pixel c is, or None when c is not a mix of k and white."""
    i = max(range(3), key=lambda j: 255 - k[j])
    a = (255 - c[i]) / (255 - k[i])
    if a < 0.08:
        return None
    return a if all(abs(255 - a * (255 - k[j]) - c[j]) < 18 for j in range(3)) else None


def boxes(img, rects):
    """Per slot: the bounding box of its colour (window points) around the slot and the colour's strength there."""
    out = {}
    for name, (x, y, w, h) in rects.items():
        hits = [(px, py, a) for px in range(int(x - 70), int(x + w + 70), 2) for py in range(int(y - 60), int(y + h + 60), 2)
                if 0 <= px < img.width and 0 <= py < img.height and (a := alpha_of(img.getpixel((px, py))[:3], SLOTS[name])) is not None]
        if len(hits) < 6:
            out[name] = None
            continue
        xs, ys = [p[0] for p in hits], [p[1] for p in hits]
        out[name] = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys), max(p[2] for p in hits))
    return out


def record(app, rects, until):
    frames, end = [], time.monotonic() + 12
    while time.monotonic() < end:
        frames.append(boxes(app.screenshot(), rects))
        if len(frames) > 6 and until(frames[-1]) and frames[-1] == frames[-2] == frames[-3]:
            break
    return frames


def test_transitions(launch):
    app = launch("HelloShapes", env={"PAGE": "transitions", "DURATION": "2"})
    app.wait_view(r"id=slot-combined")
    app.wait_still()
    dump = app.view_dump()
    rects = {k: window_rect(dump, f"slot-{k}") for k in SLOTS}
    app.tap_id("toggle")
    ins = record(app, rects, lambda f: all(b and b[4] > 0.95 and b[2] > 54 for b in f.values()))
    final = ins[-1]
    app.tap_id("toggle")
    rem = record(app, rects, lambda f: all(b is None for b in f.values()))
    assert app.quit() == 0, "exits cleanly"
    assert all(final[k] and abs(final[k][2] - 58) < 4 for k in SLOTS), f"every square ends in place ({final})"
    seen = lambda frames, k, pred: any(f[k] and pred(f[k], final[k]) for f in frames)
    faded = lambda b, e: b[4] < 0.8
    full = lambda b, e: abs(b[2] - e[2]) < 4
    small = lambda b, e: 4 < b[2] < e[2] - 12
    for frames, phase in ((ins, "insertion"), (rem, "removal")):
        assert seen(frames, "opacity", lambda b, e: faded(b, e) and full(b, e)), f".opacity fades ({phase})"
        assert not seen(frames, "opacity", small), f".opacity does not scale ({phase})"
        assert seen(frames, "scale", lambda b, e: small(b, e) and abs((b[0] + b[2] / 2) - (e[0] + e[2] / 2)) < 4), f".scale grows / shrinks about the centre ({phase})"
        assert seen(frames, "move", lambda b, e: full(b, e) and b[1] < e[1] - 8), f".move(edge: .top) comes from / goes to the top ({phase})"
        assert seen(frames, "offset", lambda b, e: full(b, e) and b[0] > e[0] + 8), f".offset(x: 40) ({phase})"
        assert seen(frames, "combined", lambda b, e: faded(b, e) and small(b, e)), f".opacity.combined(with: .scale) ({phase})"
    assert seen(ins, "slide", lambda b, e: b[0] < e[0] - 8) and seen(rem, "slide", lambda b, e: b[0] > e[0] + 8), \
        ".slide: in from the leading edge, out to the trailing edge"
    assert seen(ins, "push", lambda b, e: b[0] > e[0] + 8 and faded(b, e)) and seen(rem, "push", lambda b, e: b[0] < e[0] - 8 and faded(b, e)), \
        ".push(from: .trailing): in from the trailing edge, out to the leading one, fading"
    assert seen(ins, "asymmetric", small) and not seen(ins, "asymmetric", lambda b, e: faded(b, e) and full(b, e)), ".asymmetric: inserted with .scale"
    assert seen(rem, "asymmetric", lambda b, e: faded(b, e) and full(b, e)) and not seen(rem, "asymmetric", small), ".asymmetric: removed with .opacity"


def test_matched_geometry(launch):
    app = launch("HelloShapes", env={"PAGE": "matched", "DURATION": "2"})
    app.wait_view(r"id=card-small")
    app.wait_still()
    dump = app.view_dump()
    small = window_rect(dump, "card-small")
    blue_ = lambda c: c[2] - c[0] > 100                                  # (the two cards cross-fade over each other)

    def card(img):
        hits = [(x, y) for x in range(0, img.width, 2) for y in range(int(small[1] - 10), int(small[1] + 240), 2) if blue_(img.getpixel((x, y))[:3])]
        return (min(p[0] for p in hits), min(p[1] for p in hits), max(p[0] for p in hits) - min(p[0] for p in hits),
                max(p[1] for p in hits) - min(p[1] for p in hits)) if hits else None
    app.tap_id("grow")
    frames, end = [], time.monotonic() + 10
    while time.monotonic() < end:
        frames.append(card(app.screenshot()))
        if len(frames) > 6 and frames[-1] and frames[-1][2] > 190 and frames[-1] == frames[-2] == frames[-3]:
            break
    bx, by, bw, bh = window_rect(app.view_dump(), "card-big")              # (the id is on the frame around the 200 x 120 card)
    big = (bx + bw - 200, by + bh - 120, 200, 120)
    # the highlight (isSource: false) takes the selected tab's frame
    app.tap_id("tab-2")
    tab = app.wait_view(r"id=highlight")
    end = time.monotonic() + 8
    while time.monotonic() < end and window_rect(app.view_dump(), "highlight") != window_rect(app.view_dump(), "tab-2"):
        app.wait_still()
    dump = app.view_dump()
    app.screenshot("matched")
    assert app.quit() == 0, "exits cleanly"
    mid = [f for f in frames if f and small[2] + 20 < f[2] < big[2] - 20]
    assert mid, f"the card grows through in-between sizes ({frames})"
    assert all(small[0] - 2 <= f[0] <= big[0] + 2 and small[1] - 2 <= f[1] <= big[1] + 2 for f in mid), \
        f"matchedGeometryEffect: the inserted card moves from the removed one's frame to its own ({small} {big} {mid})"
    assert window_rect(dump, "highlight") == window_rect(dump, "tab-2"), "isSource: false follows the source's frame"
    assert window_rect(dump, "highlight")[2] > window_rect(dump, "tab-0")[2] + 20, "...including its size"
