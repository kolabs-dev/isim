"""The device shell (isim boot) on scratch device data: home screen, Settings (Display & Brightness > Dark), app launch,
swipe up to go home, long press > Remove App > Delete. Port of tests/ui/boot.sh."""
import pytest


def screen_size(app):
    root = app.snapshot()[0]
    return root.w, root.h


@pytest.mark.os_matrix
def test_boot(boot, ios, device_data):
    dev = boot(apps=["HelloSwiftUI", "HelloCounter"])
    assert dev.has(r"SpringBoard: 3 app\(s\): Settings, Hello SwiftUI, HelloCounter"), "home screen lists installed apps"

    dev.wait_tap("app-dev.isim.settings")
    dev.wait_log(r"launching Settings \(dev\.isim\.settings\)")             # Settings launches from its icon
    dev.wait_tap("settings-display")
    dev.wait_tap("settings-dark")
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    dev.wait_until(lambda: prefs.exists() and b"<string>Dark</string>" in prefs.read_bytes(),
                   what="Dark appearance saved globally")
    dev.home()
    dev.wait_log(r"isim shell: home")

    dev.wait_tap("app-dev.isim.samples.HelloSwiftUI")
    dev.wait_log(r"launched .*HelloSwiftUI\.app \(pid")                      # apps launch as separate processes
    dev.wait_opened("HelloSwiftUI")
    dev.wait_tap("increment")
    dev.wait_log(r"count 0 -> 1")
    w, h = screen_size(dev)
    dev.drag(w / 2, h - 7, w / 2, h - 250, 0.3)
    dev.wait_log(r"isim shell: home", count=2)                              # swipe up from the bottom goes home

    dev.wait_view("app-dev.kolabs.isim.HelloCounter")
    dev.send("holdid app-dev.kolabs.isim.HelloCounter 0.8")
    dev.wait_tap("menu-remove")
    dev.wait_tap("alert-Delete")
    dev.wait_log(r"deleting HelloCounter")                                  # long press > Remove App > Delete
    dev.wait_until(lambda: not (device_data / "Applications/HelloCounter.app").exists(), what="HelloCounter deleted")
    assert dev.quit() == 0, "shell exits cleanly"
