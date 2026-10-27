"""The device shell (isim boot) on scratch device data: home screen, Settings (Display & Brightness > Dark), app launch,
swipe up to go home, long press > Remove App > Delete. Port of tests/ui/boot.sh."""
import pytest
from isimtest import mean_rgb, screen_frames, visible


def screen_size(app):
    root = app.snapshot()[0]
    return root.w, root.h


@pytest.mark.os_matrix
def test_boot(launch, ios, device_data):
    dev = launch(None, install=["HelloSwiftUI", "HelloCounter"])
    assert dev.has(r"SpringBoard: 5 app\(s\): Safari, Settings, Shortcuts, Hello SwiftUI, HelloCounter"), "home screen lists installed apps"

    dev.wait_view(r"id=app-dev\.isim\.settings")
    dev.wait_still()
    frames = screen_frames(dev.view_dump())
    dock = sorted((f[0], i) for i, f in frames.items() if i in ("app-dev.isim.settings", "app-dev.isim.safari", "app-dev.isim.shortcuts"))
    assert [i for _, i in dock][-1:] == ["app-dev.isim.settings"], f"Settings is the dock's last (rightmost) app ({dock})"
    x, y, w, h = frames["app-dev.isim.settings"]
    s = (w - 8) / 2 if h > w else w / 2 - 4                              # the icon square (a label may hang below)
    r, g, b = mean_rgb(dev.screenshot("home"), (x + w / 2 - s / 2, y + 4, s, s))
    assert max(r, g, b) - min(r, g, b) < 16 and 60 < r < 220, f"Settings has its grey gear icon, not a placeholder ({r:.0f}, {g:.0f}, {b:.0f})"
    dev.wait_tap_id("app-dev.isim.settings")
    dev.wait_log(r"launching Settings \(dev\.isim\.settings\)")             # Settings launches from its icon
    dev.wait_tap_id("settings-appearance" if int(str(ios[0] or "18").split(".")[0]) >= 27 else "settings-display")   # iOS 27: Appearance
    dev.wait_tap_id("settings-dark")
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    dev.wait_until(lambda: prefs.exists() and b"<string>Dark</string>" in prefs.read_bytes(),
                   what="Dark appearance saved globally")
    dev.send("home")
    dev.wait_log(r"isim shell: home")

    dev.wait_tap_id("app-dev.isim.samples.HelloSwiftUI")
    dev.wait_log(r"launched .*HelloSwiftUI\.app \(pid")                      # apps launch as separate processes
    dev.wait_opened("HelloSwiftUI")
    dev.wait_tap_id("increment")
    dev.wait_log(r"count 0 -> 1")
    w, h = screen_size(dev)
    dev.drag(w / 2, h - 7, w / 2, h - 250, 0.3)
    dev.wait_log(r"isim shell: home", count=2)                              # swipe up from the bottom goes home

    dev.wait_view(visible("app-dev.kolabs.isim.HelloCounter"))
    dev.send("holdid app-dev.kolabs.isim.HelloCounter 0.8")
    dev.wait_tap_id("menu-remove")
    dev.wait_tap_id("alert-Delete")
    dev.wait_log(r"deleting HelloCounter")                                  # long press > Remove App > Delete
    dev.wait_until(lambda: not (device_data / "Applications/HelloCounter.app").exists(), what="HelloCounter deleted")
    assert dev.quit() == 0, "shell exits cleanly"
