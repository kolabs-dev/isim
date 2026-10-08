"""SwiftUI visual effects (HelloEffects): colour filters, blend modes, blur, content shadows, alpha masks, clipped(),
compositingGroup, contentShape hit testing, an animated grayscale, visualEffect and scrollTransition while scrolling;
then sensoryFeedback (logged haptics), privacy redaction, a context menu with a preview, persistentSystemOverlays(.hidden)
(the home indicator fades) and, on the device shell, defersSystemGestures (the first swipe up from the bottom stays in
the app). Checked by pixels (frames from the view tree) and the logs. Port of tests/ui/effects.sh and effects_check.py;
mid-animation states are polled for (screenshots until one shows the animation part-way), not sampled at a fixed
time, so a loaded machine that renders few frames still sees them."""
import re
import time

from isimtest import TIMEOUT, parse_views, rgb, screen_frames, visible


def near(p, q, tol=14):
    return all(abs(a - b) <= tol for a, b in zip(p, q))


def px(img, x, y):                                       # nearest pixel, as effects_check.py measured
    return rgb(img, round(x), round(y))


def test_effects(launch):
    app = launch("HelloEffects")
    t0 = app.wait_view(r"id=t-fade\b")
    start = app.screenshot("start")
    f = screen_frames(t0)
    missing = [t for t in ("t-gray", "t-hue", "t-shadow", "t-fade", "row-2") if t not in f]
    assert not missing, f"the tree lists the effect tiles: missing {missing}"

    def at(img, tid, dx=30, dy=30):
        x, y, _, _ = f[tid]
        return px(img, x + dx, y + dy)

    checks = [
        ("grayscale(1): red becomes its luminance grey", near(at(start, "t-gray"), (54, 54, 54))),
        ("saturation(0) = grey", near(at(start, "t-sat"), (54, 54, 54))),
        ("brightness(0.5) lifts black to mid grey", near(at(start, "t-bright"), (128, 128, 128))),
        ("contrast(0) flattens to mid grey", near(at(start, "t-contrast"), (128, 128, 128))),
        ("hueRotation(120°) turns red green", (lambda p: p[1] > 80 and p[0] < 40 and p[2] < 40)(at(start, "t-hue"))),
        ("colorMultiply(blue) on white", near(at(start, "t-mult"), (0, 0, 255))),
        ("colorInvert() on white", near(at(start, "t-invert"), (0, 0, 0))),
        ("luminanceToAlpha: black becomes transparent (yellow shows)", near(at(start, "t-luma"), (255, 255, 0))),
        ("blendMode(.multiply): cyan × yellow = green", near(at(start, "t-blend"), (0, 255, 0))),
    ]
    c, edge, out = at(start, "t-blur"), at(start, "t-blur", 30, 46), at(start, "t-blur", 30, 58)
    checks.append(("blur: soft red edge spreading past the frame",
                   c[0] > 200 and c[1] < 140 and edge[0] > 230 and 20 < edge[1] < 235 and out[1] > edge[1]))
    s, body = at(start, "t-shadow", 48, 48), at(start, "t-shadow")
    checks.append(("shadow follows the content shape (a circle), offset",
                   max(s) < 70 and near(body, (0, 0, 255), 30) and min(at(start, "t-shadow", 4, 4)) > 230))
    l, r = at(start, "t-mask", 4, 30), at(start, "t-mask", 57, 30)
    checks.append(("mask(LinearGradient) fades by alpha", l[0] > 230 and l[1] < 40 and min(r) > 215))
    inside, outside = at(start, "t-clip"), at(start, "t-clip", 30, 55)
    checks.append(("clipped() cuts the overflowing child", inside[1] > 150 and inside[0] < 60 and min(outside) > 230))
    lft, mid = at(start, "t-group", 6, 30), at(start, "t-group", 30, 30)
    checks.append(("compositingGroup + opacity: blue covers red inside the group",
                   near(lft, (255, 128, 128), 20) and near(mid, (128, 128, 255), 20)))
    failed = [what for what, ok in checks if not ok]
    assert not failed, f"effect tiles: {failed}"

    app.tap_id("t-shape-corner")
    app.sleep(0.3)                                                       # a tap that must not count
    app.tap_id("t-shape")
    app.wait_log(r"shape tapped 1")
    app.wait_tap_id("fade")
    halfway = lambda s: (lambda p: 100 < p[0] < 220 and 12 < p[1] < 50)(at(s, "t-fade"))
    grey = lambda s: near(at(s, "t-fade"), (54, 54, 54))
    app.shot_during(halfway, grey, "withAnimation interpolates grayscale (half-way)")   # during the 2 s animation
    app.send("swipeid row-2 0 -50 0.6")
    app.wait_log(r"^row0 visible false")                                 # onScrollVisibilityChange (iOS 18)
    app.wait_log(r"^scroll row 1")                                       # onScrollGeometryChange (iOS 18)
    app.sleep(0.6)                                                       # the scroll has settled
    end = app.wait_shot(grey, "the animation ends fully grey")
    t1 = app.view_dump()
    assert not app.has(r"shape tapped 2"), "contentShape(Circle()): the corner does not take the tap, the centre does"

    vals = [int(v) for v in re.findall(r"ve row2 (-?\d+)", app.log)]
    assert vals and vals[0] == 80, f"visualEffect reads frame(in: .scrollView) (80 before scrolling): {vals[:3]}"
    off = 80 - vals[-1]
    assert off > 20, f"visualEffect follows scrolling: offset {off}"
    f1 = screen_frames(t1)
    top, x0 = f1["row-2"][1] + off - 80, f1["row-2"][0] + 10
    k = int(off // 40)
    want = 255 * (off - 40 * k) / 40
    p = px(end, x0, top + 1)
    assert abs(p[0] - want) < 45 and p[2] > 230, \
        f"scrollTransition: the row leaving the top fades with its hidden fraction: {p} want r~{want:.0f} (offset {off})"
    solid = px(end, x0, top + (40 * (k + 1) - off) + 20)
    assert solid[0] < 30 and solid[2] > 230, f"scrollTransition: fully visible rows stay at identity: {solid}"

    # the second page
    app.wait_tap_id("next")
    t2 = app.wait_view(r"id=bounce-star\b")
    app.sleep(0.5)                                                       # pushed
    more = app.screenshot("more")
    t2 = app.view_dump()
    f2 = screen_frames(t2)
    bs, ct = f2.get("bounce-star"), f2.get("count-text")
    assert bs and ct, f"the symbol and the count in the tree: {bs} {ct}"
    orange = lambda c: c[0] > 200 and 100 < c[1] < 190 and c[2] < 80

    def ink(img, r):
        x, y, w, h = r
        return sum(1 for i in range(-8, int(w) + 8) for j in range(-8, int(h) + 8) if orange(px(img, x + i, y + j)))

    def numeric(d):                                                      # the old count text fading out
        return [v for v in parse_views(d) if v.cls == "UIImageView" and abs(v.h - ct[3]) < 1 and "alpha<1" in v.line]
    app.tap_id("haptic")
    t3 = bounce = None                                                   # mid-transition: polled until both are seen
    end_ = time.monotonic() + TIMEOUT
    while (t3 is None or bounce is None) and time.monotonic() < end_:
        if t3 is None and numeric(d := app.view_dump()):
            t3 = d
        if bounce is None and ink(s := app.screenshot("bounce"), bs) > ink(more, bs) * 1.15:
            bounce = s
    app.wait_log(r"haptic notification \(success\)")
    app.sleep(0.4)
    app.tap_id("haptic")
    app.sleep(0.3)
    app.tap_id("redact")
    indicator = lambda s: px(s, s.width / 2, s.height - 10.5)
    # the home indicator fades 2 s after the last touch
    red = app.wait_shot(lambda s: min(indicator(s)) > 200,
                        "persistentSystemOverlays(.hidden): the home indicator fades 2 s after the last touch")
    t4 = app.view_dump()
    ph = f2.get("pulse-heart")
    heart = lambda s: px(s, ph[0] + ph[2] / 2, ph[1] + ph[3] / 2)
    pulse1 = app.screenshot("pulse1")
    pulse2 = app.wait_shot(lambda s: abs(heart(s)[1] - heart(pulse1)[1]) > 20,
                           "symbolEffect(.pulse) changes the opacity over time")

    fr = screen_frames(t4)
    assert all(t in fr for t in ("private-image", "private-text", "public-text")), f"the redaction views: {list(fr)[:20]}"
    centre = lambda img, tid: px(img, fr[tid][0] + fr[tid][2] / 2, fr[tid][1] + fr[tid][3] / 2)
    p = centre(red, "private-image")
    assert abs(p[0] - p[2]) < 20 and 150 < p[0] < 225, f"privacySensitive image redacted (grey box): {p}"
    p = centre(red, "private-text")
    assert abs(p[0] - p[2]) < 20 and 150 < p[0] < 225, f"privacySensitive text redacted (grey bar): {p}"
    x, y, w, h = fr["public-text"]
    dark = sum(1 for i in range(int(w)) if max(px(red, x + i, y + h / 2)) < 90)
    assert dark > 3, f"other text stays readable: {dark} dark pixels"

    assert t3, "contentTransition(.numericText) animates the old text out"
    assert bounce, f"symbolEffect(.bounce, value:) scales the symbol: {ink(more, bs)} -> no larger frame"
    c1, c2 = heart(pulse1), heart(pulse2)
    assert abs(c1[1] - c2[1]) > 20, f"symbolEffect(.pulse) changes the opacity over time: {c1} {c2}"
    on, off_ = px(more, more.width / 2, more.height - 10.5), px(red, red.width / 2, red.height - 10.5)
    assert max(on) < 60, f"persistentSystemOverlays(.hidden): the home indicator shows after a touch: {on}"
    assert min(off_) > 200, f"persistentSystemOverlays(.hidden): the home indicator fades 2 s after the last touch: {off_}"

    app.send("swipeid swipe-row-A -120 0 0.3")
    app.wait_tap_id("swipe-Flag")
    app.wait_log(r"swipe: flag A")                                       # swipeActions outside a List (iOS 27 form)
    app.send("holdid menu-source 0.8")
    tree = app.wait_view(r"id=isim-menu-preview\b")
    assert "id=menu-Copy" in tree, "contextMenu(menuItems:preview:) shows the preview with the menu"
    app.wait_tap_id("menu-Copy")
    app.wait_log(r"menu: copy")
    assert app.count(r"haptic notification \(success\)") == 2 and app.count(r"haptic impact \(heavy") == 1, \
        "sensoryFeedback plays on trigger changes (logged haptics)"
    assert app.quit() == 0


def test_defers_system_gestures(launch):
    dev = launch(None, install=["HelloEffects"])
    dev.send("launch dev.isim.samples.HelloEffects")
    dev.wait_opened("HelloEffects")
    dev.wait_tap_id("next")
    dev.wait_view(visible("menu-source"))
    root = dev.snapshot()[0]
    x, y = root.w / 2, root.h - 6
    dev.drag(x, y, x, 600)
    dev.sleep(0.8)                                                       # a swipe home would be over by now
    assert "id=menu-source" in dev.view_dump(), "defersSystemGestures: the first swipe from the bottom stays in the app"
    dev.drag(x, y, x, 600)
    dev.wait_log(r"isim shell: home")                                    # a second swipe goes home
    assert dev.quit() == 0
