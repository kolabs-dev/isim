"""The trait system (HelloAppearance, UIKit): UITraitCollection API (style-only collections, traitsFrom,
modifyingTraits, containsTraits, hasDifferentColorAppearance), a custom Swift trait through traitOverrides on a
controller (read by a dynamic color and while laying out), registerForTraitChanges for the appearance and the custom
trait, traitCollectionDidChange with the previous traits; overrideUserInterfaceStyle on a parent controller (its
child), on a view (traitOverrides) and the presented controller of a dark controller; asset-catalog colors and images
with Any/Dark/High Contrast variants (UIImageAsset, the variant per traits); the accent color as the default tint; live
`appearance dark` / `contrast on`; materials per appearance and vibrancy; UIAppearance proxies (plain, per-state,
contained, bar items) and own values winning; Debug > Simulate Memory Warning. Colours by pixels.
Port of tests/ui/appearance.sh."""
import pytest
from isimtest import rgb, runs_x


def near(*want):
    return lambda c: all(abs(a - b) <= 6 for a, b in zip(c, want))


def black(c): return c[0] < 10 and c[1] < 10 and c[2] < 10
def red(c): return c[0] > 220 and c[1] < 40 and c[2] < 40
def blue(c): return c[2] > 220 and c[0] < 40 and c[1] < 40


def shot_when(app, name, x, y, pred):
    """a screenshot once (x, y) satisfies pred (the redraw after a trait change)"""
    return app.wait_until(lambda: (lambda s: s if pred(rgb(s, x, y)) else None)(app.screenshot(name)),
                          what=f"{name}: pixel {x},{y}")


def is_(img, x, y, pred):
    return pred(rgb(img, x, y))


@pytest.mark.os_matrix
def test_appearance(launch, ios):
    app = launch("HelloAppearance")
    app.wait_log(r"traits: root light, dark host dark, theme swatch ocean")
    light = shot_when(app, "light", 60, 140, near(51, 102, 204))
    log = app.log
    assert "traits: style-only dark, idiom -1, size class 0" in log and "traits: merged light h1" in log and \
        "traits: modified level 1 keeps dark" in log and "traits: contains true / false, color differs true" in log, \
        "UITraitCollection API (style-only, traitsFrom, modifyingTraits, contains, color appearance)"
    assert "traits: custom ocean, default plain, color #003399" in log, \
        "custom trait: UITraitCollection(mutations:), default value, dynamic color"
    assert "colors: systemBlue light #007AFF dark #0A84FF dark+HC #409CFF" in log and \
        "colors: Brand light #3366CC dark #FFCC00 dark+HC #FFEE88 light+HC #002266" in log and \
        "colors: performAsCurrent label #FFFFFF" in log, "system colors and asset colors per appearance and contrast"
    assert "images: Badge asset true, light 10 dark 12, config dark 12" in log and \
        "images: registered light 4 dark 6" in log, "dynamic images: asset catalog variants, configuration, UIImageAsset"
    orange = sum(e - s for s, e in runs_x(light, 400, 20, 120, lambda c: c[0] > 220 and 90 < c[1] < 130 and c[2] < 40))
    assert "traits: system color traits 5, accent #FF6600" in log and "accent tint #FF6600" in log and orange > 8, \
        f"accent color is UIColor.tintColor and the default tint ({orange} px)"
    assert "current in layout darkHost: dark theme ocean" in log and "current in layout theme: light theme ocean" in log, \
        "UITraitCollection.current while laying out (overrides and custom trait)"
    assert "child traits: dark, view dark" in log, "traitOverrides / parent override / child controller"
    assert is_(light, 150, 140, near(255, 204, 0)) and is_(light, 240, 140, near(0, 102, 255)) and \
        is_(light, 80, 200, black), "light: asset color, dark override, custom trait color, dark child"
    assert is_(light, 40, 260, red) and is_(light, 100, 260, blue), "light: image variants (auto red, dark override blue)"
    assert is_(light, 60, 330, lambda c: c[0] > 200 and c[1] > 170 and c[2] > 170) and \
        is_(light, 180, 315, lambda c: c[0] < 130 and c[1] < 100 and c[2] < 100) and \
        is_(light, 220, 330, lambda c: min(c) > 200), \
        "materials: light stays light, dark stays dark; vibrant content takes the vibrant color"
    assert is_(light, 35, 455, near(175, 82, 222)), "UIAppearance: switch tint by pixels"
    assert "proxies: switch #AF52DE, button #FF2D55, segments #FF3B30/#007AFF, progress #34C759" in log and \
        "proxies: label #A2845E own #34C759, bar item #30B0C7 #5856D6 own #FF9500" in log, \
        "UIAppearance: plain, per-state, contained, progress, bar items; own values win"

    app.send("appearance dark")
    app.wait_log(r"controller traits light -> dark contrast 0")
    app.wait_log(r"view theme traits light -> dark")
    app.wait_log(r"registration: style light -> dark, swatch #FFCC00")   # live appearance: traitCollectionDidChange
    dark = shot_when(app, "dark", 60, 140, near(255, 204, 0))
    assert is_(dark, 240, 140, near(0, 51, 153)) and is_(dark, 40, 260, blue) and is_(dark, 80, 200, black), \
        "dark: asset color, custom trait color, image variant follow"

    app.send("contrast on")
    app.wait_log(r"controller traits dark -> dark contrast 1")
    contrast = shot_when(app, "contrast", 60, 140, near(255, 238, 136))
    assert is_(contrast, 150, 140, near(255, 238, 136)), "contrast on: high-contrast variants"

    app.wait_tap("theme")
    app.wait_log(r"theme -> forest \(overrides contain theme: true\)")
    app.wait_log(r"registration: theme ocean -> forest")
    shot_when(app, "theme", 240, 140, near(0, 153, 51))                  # custom trait change: color

    app.send("memorywarning")
    for who in ("app delegate", "notification", "root controller", "child controller"):
        app.wait_log(rf"memory warning: {who}")
    app.send("contrast off").send("appearance light")
    app.wait_log(r"registration: style dark -> light")
    back = shot_when(app, "back", 60, 140, near(51, 102, 204))
    assert is_(back, 40, 260, red), "back to light"

    app.wait_tap("present")
    app.wait_log(r"presented traits: dark")
    shot_when(app, "presented", 200, 600, black)                         # a controller presented by a dark child is dark
    assert app.quit() == 0
