"""HelloGlass: iOS 26 Liquid Glass in UIKit over colourful stripes. A UIGlassContainerEffect's circles merge into one
shape when they move closer than its spacing (smooth union, drawn per frame so they morph); UISlider track
configurations (ticks that snap, a neutral value, the thumbless style) and the classic slider customisation (value
images, thumb images per state, trackRect / thumbRect); capsule segmented control; UIView.cornerConfiguration
(container-concentric, uniform top) and effectiveRadius(corner:); bar items sharing one glass capsule."""
import pytest
from isimtest import near, rgb

GAP = (171, 141)           # above where circles 0 and 1 touch once merged: outside both circles, inside their union


def thumb_x(el, value, thumb_w):
    """the default thumb's centre for value (0...1) on a slider element (track inset 2, thumb inset w/2 - 2)"""
    x0, w, inset = el.x + 2, el.w - 4, thumb_w / 2 - 2
    return x0 + inset + value * (w - 2 * inset)


@pytest.mark.os_matrix
def test_slider_customisation(launch, ios):
    """value images, a custom thumb image per state, trackRect / thumbRect: every iOS version"""
    app = launch("HelloGlass")
    m = app.wait_log(r"^glass custom track 30 (\d+) thumb (\d+) 26 images true true$")
    track_w, thumb = int(m.group(1)), int(m.group(2))
    assert abs(thumb - (30 + 11 + 0.5 * (track_w - 22))) <= 1, "thumbRect: the middle of the thumb's travel"
    app.wait_log(r"^glass ready")
    app.wait_still()
    x = 20 + thumb                                                     # the slider is at x 20; thumbRect is in its bounds
    assert near(rgb(app.screenshot("custom"), x, 487), (0, 0, 0), 40), "the custom (black) thumb image is drawn"
    app.drag(x, 487, x + 70, 487)
    app.wait_log(r"^glass custom 0\.[67]\d$")                          # dragging the custom thumb
    assert app.quit() == 0


def test_glass(launch):
    app = launch("HelloGlass", os_version="26.0")
    app.wait_log(r"^glass track config ticks 5 snaps true neutral 0\.5 style true$")
    app.wait_log(r"^glass corners outer 32\.0 inner 20\.0 top 28\.0 0\.0 capsule 30\.0$")   # concentric: 32 - 12
    app.wait_log(r"^glass config true corners\(topLeft: containerConcentric")
    app.wait_log(r"^glass ready$")
    dump = app.wait_still()
    assert dump.count("__IsimBarGlass") == 1, "the share and more items share one glass capsule"
    before = app.screenshot("before")
    assert not near(rgb(before, 32, 602), (88, 86, 214), 40), "the inner view's corner is rounded (concentric)"
    assert near(rgb(before, 21, 591), rgb(before, 21, 570), 30), "the outer view's corner shows the stripes"

    app.tap_id("merge")
    app.wait_log(r"^glass merged$")
    app.wait_still()
    after = app.screenshot("after")
    b, a = rgb(before, *GAP), rgb(after, *GAP)
    assert sum(a) > sum(b) + 60, f"the merged glass fills the gap between the circles ({b} -> {a})"

    ticks = app.wait_for(id="ticks")
    y = ticks.y + ticks.h / 2
    app.drag(thumb_x(ticks, 0.5, 38), y, thumb_x(ticks, 0.68, 38), y)
    app.wait_log(r"^glass ticks 0\.75$")                               # snaps to the nearest tick
    slider = app.wait_for(id="thumbless")
    y = slider.y + slider.h / 2
    app.drag(slider.x + slider.w * 0.2, y, slider.x + slider.w * 0.3, y)
    app.wait_log(r"^glass thumbless 0\.[23]\d$")                      # thumbless: the finger drags anywhere
    seg = app.wait_for(id="segments")
    app.tap(seg.x + seg.w / 2, seg.y + seg.h / 2)                      # the middle segment
    app.wait_log(r"^glass segment 1$")
    assert app.quit() == 0


def glass_spread(img, el):
    """how much the stripes behind a glass circle still show: the colour range along its middle row"""
    y = el.y + el.h / 2
    row = [rgb(img, el.x + 16 + i, y) for i in range(int(el.w) - 32)]
    return sum(max(p[c] for p in row) - min(p[c] for p in row) for c in range(3))


@pytest.mark.parametrize("os_version", ["26.0", "27.0"])
def test_glass_tint(launch, os_version):
    """the Liquid Glass setting (issue #336; script glasstint, like Settings): the clearest glass shows the stripes
    behind it most, the most tinted least; 0.5 is the default look"""
    app = launch("HelloGlass", os_version=os_version)
    app.wait_log(r"^glass ready$")
    app.wait_still()
    circle = app.wait_for(id="circle0")
    default = glass_spread(app.screenshot("default"), circle)
    app.send("glasstint 0")
    app.wait_log(r"isim: glasstint 0\.00")
    app.wait_still()
    clear = glass_spread(app.screenshot("clear"), circle)
    app.send("glasstint 1")
    app.wait_log(r"isim: glasstint 1\.00")
    app.wait_still()
    tinted = glass_spread(app.screenshot("tinted"), circle)
    assert clear > default + 20 > tinted + 40, f"clear {clear} > default {default} > tinted {tinted}"
    assert app.quit() == 0


def test_glass_ios27_edge(launch):
    """iOS 27's refresh: a darkened edge inside the glass's rim (iOS 26 has none)"""
    edges = {}
    for v in ("26.0", "27.0"):
        app = launch("HelloGlass", os_version=v)
        app.wait_log(r"^glass ready$")
        app.wait_still()
        c = app.wait_for(id="circle0")
        img = app.screenshot(f"edge{v[:2]}")
        cx, cy = c.x + c.w / 2, c.y + c.h / 2
        # just inside the bottom rim (the top one is lit), against the middle of the circle
        edges[v] = (sum(rgb(img, cx, c.y + c.h - 3)), sum(rgb(img, cx, cy + 10)))
        assert app.quit() == 0
    d26 = edges["26.0"][1] - edges["26.0"][0]
    d27 = edges["27.0"][1] - edges["27.0"][0]
    assert d27 > d26 + 15, f"iOS 27's edge is darker than the body, more than iOS 26's: {edges}"


@pytest.mark.parametrize("os_version", ["26.0", "27.0"])
def test_liquid_glass_settings(launch, device_data, os_version):
    """Settings: iOS 26 Display & Brightness › Liquid Glass (Clear / Tinted), iOS 27 Appearance › Liquid Glass (a slider
    from Clear to Tinted); both write ISIMLiquidGlassTint to the global domain"""
    prefs = device_data / "Library" / "Preferences" / ".GlobalPreferences.plist"
    dev = launch(None, os_version=os_version)
    dev.send("launch dev.isim.settings")
    if os_version.startswith("27"):
        dev.wait_tap_id("settings-appearance")
        dev.wait_tap_id("settings-liquid-glass")
        slider = dev.wait_for(label=r"^Clear, Tinted$")                # the list row: Clear, the slider, Tinted
        y = slider.y + slider.h / 2
        dev.drag(slider.x + slider.w / 2, y, slider.x + slider.w - 60, y)
    else:
        dev.wait_tap_id("settings-display")
        dev.wait_tap_id("settings-liquid-glass")
        dev.wait_tap_id("settings-glass-tinted")
    dev.wait_log(r"isim Settings: Liquid Glass tint (0\.9\d|1\.00)")
    dev.wait_until(lambda: prefs.exists() and "ISIMLiquidGlassTint" in prefs.read_text(errors="ignore"), what="the setting is written")
    dev.wait_still()
    dev.screenshot("liquid-glass")
