"""Settings > Privacy & Security and Notifications (isim boot): apps appear under the services they asked for (the answers
in their own defaults), turning access off terminates the running app (as on iOS) and is what the app reads next
launch; Notifications lists apps that asked, with Allow Notifications and the alert kinds; an app's own page shows
its permissions."""
import plistlib
import re

CAMERA, PUSH = "dev.isim.samples.HelloCamera", "dev.isim.samples.HelloPush"


def prefs(data, bundle):
    path = next(p for p in data.rglob(f"{bundle}.plist") if "/Library/Preferences/" in str(p))
    return plistlib.loads(path.read_bytes())


def settings(dev):
    dev.send("terminate dev.isim.settings")
    dev.send("launch dev.isim.settings")


def test_privacy_and_notifications(launch, device_data):
    dev = launch(None, install=["HelloCamera", "HelloPush"])
    dev.wait_view(rf"id=app-{re.escape(CAMERA)}")
    dev.send(f"launch {CAMERA}")
    dev.wait_view(r"text=Allow")
    dev.send("taptext Allow")
    dev.wait_log(r"access true")
    dev.send("home")
    dev.send(f"launch {PUSH}")
    dev.wait_view(r"text=Allow")
    dev.send("taptext Allow")
    dev.wait_log(r"authorization granted=true")
    dev.send("home")
    assert prefs(device_data, CAMERA).get("_ISIMPrivacy.camera") == 3, "the camera answer is in the app's defaults"

    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-privacy")
    page = dev.wait_view(r"id=settings-privacy-camera")
    assert all(f"id=settings-privacy-{s}" in page for s in ("location", "tracking", "contacts", "photos", "microphone")), \
        "the services in iOS's order"
    dev.tap_id("settings-privacy-camera")
    dev.wait_view(rf"id=settings-privacy-camera-{re.escape(CAMERA)} text=on")
    dev.screenshot("privacy-camera")
    dev.tap_id(f"settings-privacy-camera-{CAMERA}")
    dev.wait_log(rf"Settings: {re.escape(CAMERA)} camera turned off: the app is terminated")
    dev.wait_view(rf"id=settings-privacy-camera-{re.escape(CAMERA)} text=off")
    assert prefs(device_data, CAMERA).get("_ISIMPrivacy.camera") == 2, "denied (AVAuthorizationStatus 2)"

    settings(dev)                                                        # Notifications > HelloPush
    dev.wait_tap_id("settings-notifications")
    dev.wait_tap_id(f"settings-notifications-{PUSH}")
    page = dev.wait_view(r"id=settings-notifications-badges text=on")
    assert "id=settings-notifications-allow text=on" in page and "id=settings-notifications-banners text=on" in page
    dev.screenshot("notifications")
    dev.tap_id("settings-notifications-badges")
    dev.wait_view(r"id=settings-notifications-badges text=off")
    assert prefs(device_data, PUSH).get("_ISIMNotificationOptions") == 6, "badges off: alert + sound"

    settings(dev)                                                        # the app's own page: its permissions
    dev.wait_tap_id(f"settings-app-{CAMERA}")
    page = dev.wait_view(r"id=settings-app-camera")
    assert "id=settings-app-camera text=off" in page, "the app's page shows its camera access"
    dev.tap_id("settings-app-camera")
    dev.wait_view(r"id=settings-app-camera text=on")
    assert prefs(device_data, CAMERA).get("_ISIMPrivacy.camera") == 3, "turned back on from the app's page"
    assert dev.quit() == 0
