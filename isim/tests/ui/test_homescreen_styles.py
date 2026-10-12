"""Home Screen icon appearance under `isim boot`: edit mode > Edit > Customize (iOS 18+) — dark icons (the app's own
dark variant; a derived one for an icon without it) with the wallpaper dimmed, tinted icons in a hue (the slider),
large icons without names; the choice is saved (com.apple.springboard defaults) and comes back after a restart; the
script's `iconstyle`; iOS 26 offers clear icons on the glass dock; iOS 17 has no icon appearance (+ adds a widget)."""
import re

import pytest
from isimtest import count_px, mean_rgb, screen_frames

SYSTEM, COUNTER = "dev.isim.samples.HelloSystem", "dev.kolabs.isim.HelloCounter"


BLUE = lambda c: c[2] > c[0] + 80                                       # noqa: E731
RED = lambda c: c[0] > c[2] + 80                                        # noqa: E731


def icon_box(dump, bundle):
    """The icon square of an app (in window points), from its HSIcon frame and icon size."""
    f = screen_frames(dump)[f"app-{bundle}"]
    m = re.search(rf"^( +)HSIcon \([^)]*\) id=app-{re.escape(bundle)}\n\1  UIImageView \([-0-9.]+ [-0-9.]+; ([0-9.]+) x", dump, re.M)
    s = float(m.group(2)) if m else 60
    return (f[0] + (f[2] - s) / 2, f[1], s, s)


def inner(box, k=0.3):
    x, y, w, h = box
    return (x + w * k, y + h * k, w * (1 - 2 * k), h * (1 - 2 * k))


def lum(img, box):
    return sum(mean_rgb(img, box)) / 3


def customize(dev):
    """edit mode > Edit > Customize"""
    if not re.search(r"^(?!.* hidden id=).* id=home-edit\b", dev.view_dump(), re.M):   # not in edit mode yet
        dev.send(f"holdid app-{SYSTEM} 0.8")
        dev.wait_tap_id("menu-edit")
    dev.wait_tap_id("home-edit")
    dev.wait_tap_id("menu-Customize")
    dev.wait_view(r"id=customize-sheet")
    dev.wait_still()


def test_icon_appearance(launch, device_data):
    dev = launch(None, install=["HelloSystem", "HelloCounter"])
    home = dev.wait_view(rf"id=app-{re.escape(SYSTEM)}")
    dev.wait_still()
    home = dev.view_dump()
    sys_box, counter_box = icon_box(home, SYSTEM), icon_box(home, COUNTER)
    light = dev.screenshot("light")
    customize(dev)
    dev.wait_log(r"SpringBoard: Customize \(light, small icons\)")
    dev.screenshot("customize")

    dev.tap_id("customize-style-dark")
    dev.wait_log(r"SpringBoard: icon appearance dark, small icons")
    dev.tap_id("customize-dismiss")
    dev.wait_view(r"id=customize-sheet", gone=True)
    dev.wait_still()
    dark = dev.screenshot("dark")
    tree = dev.view_dump()
    assert re.search(r"^ +UIView \([^)]*\) id=home-wallpaper-dim$", tree, re.M), "dark: the wallpaper is dimmed (not hidden)"
    assert lum(dark, inner(sys_box)) < lum(light, inner(sys_box)) - 30, "dark: the app's own dark icon variant"
    assert lum(dark, inner(counter_box)) < lum(light, inner(counter_box)) - 30, "dark: a derived dark icon for an app without one"

    customize(dev)
    dev.tap_id("customize-style-tinted")
    dev.wait_log(r"SpringBoard: icon appearance tinted #5999FF, small icons")
    dev.wait_view(r"id=customize-tint")
    dev.wait_still()
    dev.screenshot("customize-tinted")
    dev.tap_id("customize-dismiss")
    dev.wait_view(r"id=customize-sheet", gone=True)
    dev.wait_still()
    tinted = dev.screenshot("tinted")
    assert count_px(tinted, inner(counter_box, 0.1), BLUE) > 60 and count_px(tinted, inner(counter_box, 0.1), RED) == 0, \
        "tinted: the glyph in the tint (blue) on a dark tile"
    customize(dev)
    x, y, w, h = screen_frames(dev.view_dump())["customize-tint"]
    dev.drag(x + w * 0.6, y + h / 2, x, y + h / 2, 0.3)                # the thumb (hue 0.6: blue) to 0: red
    dev.wait_log(r"SpringBoard: icon appearance tinted #FF[0-9A-F]{4}, small icons")
    x, y, w, h = screen_frames(dev.view_dump())["customize-size"]
    dev.tap(x + w * 0.75, y + h / 2)                                     # Large
    dev.wait_log(r"SpringBoard: icon appearance tinted #FF[0-9A-F]{4}, large icons")
    dev.tap_id("customize-dismiss")
    dev.wait_view(r"id=customize-sheet", gone=True)
    dev.tap_id("home-done")
    dev.wait_view(r"hidden id=home-done")
    dev.wait_still()
    large = dev.view_dump()
    big = icon_box(large, SYSTEM)
    assert big[2] == 72, f"large icons: 60 → 72 pt ({big})"
    assert not re.search(r"UILabel \([^)]*\) text=HelloCounter", large), "large icons have no names"
    assert dev.quit() == 0, "exits cleanly"
    prefs = next(device_data.rglob("com.apple.springboard.plist")).read_text()
    assert "<string>tinted</string>" in prefs and "<string>large</string>" in prefs, "saved in the springboard defaults"

    dev = launch(None)                                                   # restart: the appearance is restored
    again = dev.wait_view(rf"id=app-{re.escape(SYSTEM)}")
    dev.wait_still()
    again = dev.view_dump()
    restored = dev.screenshot("restored")
    box = icon_box(again, COUNTER)
    assert box[2] == 72 and count_px(restored, inner(box, 0.1), RED) > 60 and count_px(restored, inner(box, 0.1), BLUE) == 0, \
        "tinted (red) large icons after a restart"
    dev.send("iconstyle automatic small")                                # the script command
    dev.wait_log(r"SpringBoard: icon appearance automatic, small icons")
    dev.wait_view(lambda d: icon_box(d, SYSTEM)[2] == 60, what="small icons again")
    assert dev.quit() == 0


@pytest.mark.os_matrix
def test_icon_appearance_per_version(launch, ios):
    os_version = ios[0] or "18"
    major = int(str(os_version).split(".")[0])
    dev = launch(None, install=["HelloSystem"])
    dev.wait_view(rf"id=app-{re.escape(SYSTEM)}")
    dev.wait_still()
    dev.send(f"holdid app-{SYSTEM} 0.8")
    dev.wait_tap_id("menu-edit")
    tree = dev.wait_view(r"id=home-(edit|add-widget)\b")
    if major < 18:
        assert "id=home-add-widget" in tree and "id=home-edit" not in tree, "iOS 17: + adds a widget, no Customize"
        dev.send("iconstyle dark")
        dev.wait_log(r"icon appearance 'dark' needs iOS 18 or later")
        assert dev.quit() == 0
        return
    dev.tap_id("home-edit")
    dev.wait_tap_id("menu-Customize")
    sheet = dev.wait_view(r"id=customize-sheet")
    names = re.findall(r"id=customize-style-(\w+)", sheet)
    if major >= 26:
        assert names == ["light", "dark", "clear", "tinted"], f"iOS 26+: Default, Dark, Clear, Tinted ({names})"
        dev.tap_id("customize-style-clear")
        dev.wait_log(r"SpringBoard: icon appearance clear, small icons")
    else:
        assert names == ["automatic", "dark", "light", "tinted"], f"iOS 18: Automatic, Dark, Light, Tinted ({names})"
    assert dev.quit() == 0
