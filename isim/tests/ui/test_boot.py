"""The device shell (isim boot) on scratch device data: home screen, Settings (Display & Brightness > Dark), app launch,
swipe up to go home, long press > Remove App > Delete. Port of tests/ui/boot.sh."""
import pytest
from isimtest import visible


def screen_size(app):
    root = app.snapshot()[0]
    return root.w, root.h


@pytest.mark.os_matrix
def test_boot(launch, ios, device_data):
    dev = launch(None, install=["HelloSwiftUI", "HelloCounter"])
    assert dev.has(r"SpringBoard: 4 app\(s\): Safari, Settings, Hello SwiftUI, HelloCounter"), "home screen lists installed apps"

    dev.wait_tap_id("app-dev.isim.settings")
    dev.wait_log(r"launching Settings \(dev\.isim\.settings\)")             # Settings launches from its icon
    dev.wait_tap_id("settings-display")
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
