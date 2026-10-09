"""The pasteboard (HelloPasteboard, UIKit): another app's content (seeded in the device's pasteboard file, as "Notes"
wrote it) — has*/types/detection never ask; a programmatic read asks "would like to paste from" (Allow Paste, then
Don't Allow Paste for the next change); Ctrl+V and UIPasteControl paste without asking; this app's own content never
asks; setObjects / item providers, item sets and data, expiring items and the changed notification's types."""
import plistlib
import re

import pytest
from isimtest import rgb


def seed(device_data, change, text):
    """another app's pasteboard content, as the general pasteboard stores it"""
    with open(device_data / "pasteboard.txt", "wb") as f:
        plistlib.dump({"changeCount": change, "token": f"seed-{change}", "origin": "dev.isim.samples.Notes",
                       "originName": "Notes", "items": [{"public.utf8-plain-text": text}]}, f)


@pytest.mark.os_matrix
def test_pasteboard(launch, device_data, ios):
    seed(device_data, 1, "https://isim.dev/docs")
    app = launch("HelloPasteboard")
    app.wait_log(r"ready: hasStrings true, types \[\"public\.utf8-plain-text\"\], items 1, paste control enabled true")
    enabled = app.screenshot("paste-control")
    assert rgb(enabled, 80, 202)[2] > 200, "the paste control is enabled (tinted) for another app's string"

    app.wait_tap_id("detect")
    app.wait_log(r"patterns: link,probable-web-url")
    app.wait_log(r"values: probable-web-url=https://isim\.dev/docs")
    assert "paste prompt" not in app.log, "checks and detection read nothing, so nothing asks"

    app.wait_tap_id("read")
    app.wait_log(r"paste prompt: “Pasteboard” would like to paste from “Notes”")
    app.wait_for(label="Allow Paste")
    app.screenshot("prompt")
    app.tap_text("Allow Paste")
    app.wait_log(r"read: https://isim\.dev/docs")
    app.wait_tap_id("read")
    app.wait_log(r"read: https://isim\.dev/docs", count=2)              # the answer holds for this change
    assert app.count(r"paste prompt:") == 1

    seed(device_data, 2, "4.5")                                         # Notes copies again
    app.wait_tap_id("read")
    app.wait_log(r"paste prompt: ", count=2)
    app.wait_for(label="Don’t Allow Paste")
    app.tap_text("Don’t Allow Paste")
    app.wait_log(r"read: nil")

    app.wait_tap_id("field")                                            # a user paste: Ctrl+V does not ask
    app.send("keydown ctrl").send("keydown v").send("keyup v").send("keyup ctrl")
    app.wait_log(r"^field: 4\.5")
    app.wait_tap_id("pasteControl")                                     # nor does the paste control
    app.wait_log(r"UIPasteControl: pasting 1 item")
    app.wait_log(r"paste control: 4\.5")
    assert app.count(r"paste prompt:") == 2

    app.wait_tap_id("copy")                                             # this app's own content never asks
    app.wait_log(r'changed: added \[\]|changed: added \["public\.utf8-plain-text"\]')
    app.wait_tap_id("read")
    app.wait_log(r"read: Hello from Paste")
    app.wait_tap_id("extras")
    app.wait_log(r'objects: 2 items, strings \["first", "second"\], providers \["public\.utf8-plain-text", "public\.utf8-plain-text"\]')
    app.wait_log(r'item sets: types \["public\.utf8-plain-text", "public\.png", "com\.example\.custom"\], custom at \[2\], data 3 bytes, image true')
    app.wait_log(r"expiring: soon gone")
    app.wait_log(r"after expiry: hasStrings false, string nil")
    assert app.count(r"paste prompt:") == 2
    stored = plistlib.loads((device_data / "pasteboard.txt").read_bytes())
    assert stored["origin"] == "dev.isim.samples.HelloPasteboard" and "expires" in stored, "shared with the device's other apps"
    assert app.quit() == 0


def test_pasteboard_denied(launch, device_data):
    """Paste from Other Apps: Deny — reads get nothing without a prompt; a user paste still works"""
    seed(device_data, 1, "secret")
    app = launch("HelloPasteboard", env={"ISIM_PASTE_PERMISSION": "deny"})
    app.wait_log(r"ready: hasStrings true")
    app.wait_tap_id("read")
    app.wait_log(r"paste from “Notes” denied \(Paste from Other Apps: Deny\)")
    app.wait_log(r"read: nil")
    app.wait_tap_id("pasteControl")
    app.wait_log(r"paste control: secret")
    assert not re.search(r"paste prompt:", app.log)
    assert app.quit() == 0


def test_pasteboard_settings(launch, device_data):
    """Settings > the app > Paste from Other Apps: Allow — the app reads another app's content without asking"""
    seed(device_data, 1, "from settings")
    dev = launch(None, install=["HelloPasteboard"])
    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-app-dev.isim.samples.HelloPasteboard")
    dev.wait_view(r"id=settings-app-paste")
    dev.wait_still()
    assert re.search(r"text=Ask", dev.view_dump()), "Ask by default"
    dev.tap_id("settings-app-paste")
    dev.wait_tap_id("settings-paste-allow")
    dev.wait_log(r"Settings: dev\.isim\.samples\.HelloPasteboard _ISIMPrivacy\.paste = allow")
    dev.wait_still()
    dev.screenshot("settings-paste")
    dev.send("launch dev.isim.samples.HelloPasteboard")
    dev.wait_log(r"ready: hasStrings true")
    dev.wait_opened("HelloPasteboard")
    dev.wait_tap_id("read")
    dev.wait_log(r"read: from settings")
    assert not re.search(r"paste prompt:", dev.log)
    assert dev.quit() == 0
