"""HelloSafari's issue #423 parts under `isim boot`: sharing an SFAddToHomeScreenActivityItem offers Add to Home Screen
(iOS 17.4), whose sheet saves a web clip (Library/WebClips) that the home screen shows and opens; SFSafariSettings (iOS 26)
opens Safari's Export Browsing Data and Extensions pages in Settings; SLComposeViewController and SLRequest (Social) with
no social accounts, as in the Simulator; a configuration's ActivityButton is kept."""
import plistlib
import re

import pytest

SAFARI = "dev.isim.samples.HelloSafari"
pytestmark = pytest.mark.os_matrix


def open_app(dev):
    dev.send(f"launch {SAFARI}")
    dev.wait_view(r"id=home-screen")
    dev.wait_still()


def test_add_to_home_screen(launch, device_data, ios):
    version = float(ios[0] or 18)
    dev = launch(None, install=["HelloSafari"])
    dev.wait_view(rf"id=app-{SAFARI}")
    open_app(dev)
    dev.tap_id("home-screen")
    if version < 17.4:
        dev.wait_log(r"add to home screen needs iOS 17.4")
        return
    dev.wait_tap_id("share-Add to Home Screen")
    sheet = dev.wait_view(r"id=add-home-add")
    assert re.search(r"id=add-home-name text=\"?Hello Web", sheet), "the item's title is the suggested name"
    dev.wait_still()
    dev.screenshot("add-to-home-screen")
    dev.tap_id("add-home-add")
    dev.wait_log(r"isim: added Hello Web \(http://127\.0\.0\.1:8765/\) to the Home Screen")
    dev.wait_log(r"share finished com\.apple\.UIKit\.activity\.AddToHomeScreen completed=true")
    clips = list((device_data / "Library/WebClips").glob("*.webclip"))
    assert len(clips) == 1, "one web clip saved"
    info = plistlib.loads((clips[0] / "Info.plist").read_bytes())
    assert info["Title"] == "Hello Web" and info["URL"] == "http://127.0.0.1:8765/", "title and URL saved"
    assert (clips[0] / "icon.png").stat().st_size > 0, "the item's icon saved"

    dev.send("home")
    clip = f"app-webclip.{clips[0].stem}"
    dev.wait_view(rf"id={clip}")
    dev.wait_still()
    dev.screenshot("home-web-clip")
    dev.tap_id(clip)
    dev.wait_log(r"SpringBoard: web clip Hello Web opens http://127\.0\.0\.1:8765/")


def test_safari_settings_and_social(launch, ios):
    version = float(ios[0] or 18)
    dev = launch(None, install=["HelloSafari"])
    dev.wait_view(rf"id=app-{SAFARI}")
    open_app(dev)
    dev.tap_id("social")
    dev.wait_log(r"social available=false")
    dev.wait_log(r"social result=0")                    # no Twitter account: the composer is cancelled at once
    dev.wait_log(r"social request POST body=status=hi%20isim")
    dev.wait_view(r"id=status text=post cancelled")

    dev.tap_id("safari-settings")
    if version < 26:
        dev.wait_log(r"SFSafariSettings needs iOS 26")
        return
    dev.wait_log(r"safari autofill enabled=true")
    dev.wait_log(r"safari export settings error none")
    dev.wait_view(r"id=settings-safari-export-save")
    dev.wait_still()
    dev.screenshot("settings-safari-export")
    dev.tap_id("settings-safari-export-save")
    dev.wait_log(r"Settings: Safari browsing data exported \(Bookmarks, History, Extensions\)")
    dev.wait_view(r"text=Exported")
    dev.send("taptext OK")
    dev.wait_view(r"text=Exported", gone=True)
    dev.send("terminate dev.isim.settings")               # Settings > Apps > Safari: AutoFill off, which the app reads
    dev.send("launch dev.isim.settings")
    dev.wait_view(r"id=settings-safari")
    dev.tap_id("settings-safari")
    dev.wait_tap_id("settings-safari-autofill")
    dev.wait_view(r"id=settings-safari-autofill .*off")
    dev.send("home")
    open_app(dev)
    dev.tap_id("safari-settings")
    dev.wait_log(r"safari autofill enabled=false")

    dev.send("home")
    open_app(dev)
    dev.tap_id("safari-extensions")
    if version < 26.2:
        dev.wait_log(r"SFSafariSettings extensions need iOS 26.2")
        return
    dev.wait_log(r"safari extensions settings error none")
    page = dev.wait_view(rf"id=settings-safari-extension-{SAFARI}\.Blocker")
    assert "Blocker — HelloSafari" in page, "the app's content blocker is listed as installed"
    assert re.search(r"id=settings-safari-extension-dev\.example\.Missing", page), "a requested extension no app has: not installed"
    dev.wait_still()
    dev.screenshot("settings-safari-extensions")
