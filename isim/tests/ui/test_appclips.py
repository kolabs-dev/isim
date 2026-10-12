"""App Clips with HelloAppClip (an Xcode project: the full app and its App Clip target, built by `isim build`).

- the build: the App Clip (product type ...application.on-demand-install-capable) embedded in HelloAppClip.app/AppClips/,
  its NSAppClip Info.plist dictionary and entitlements (parent-application-identifiers, on-demand-install-capable,
  appclips: associated domain, the app group shared with the full app);
- `isim boot`: an invocation (`appclip URL`: a scanned code; `openurl`: a link) shows the App Clip card (local
  experience or default experience), its button launches the App Clip with an NSUserActivity of type
  NSUserActivityTypeBrowsingWeb and the URL; location confirmation against the simulated location; ephemeral
  notifications; the App Library's Recently Added; `appclip expire` deletes its data; with the full app installed the
  default experience opens the full app, which finds the App Clip's order in their app group;
- `isim run` with _XCAppClipURL (Xcode's way to debug an invocation), the 8-hour ephemeral notification window,
  SKOverlay.AppClipConfiguration recommending the full app."""
import json
import plistlib
import subprocess
import os
from pathlib import Path

import pytest
from isimtest import APPS, ISIM, near, rgb, screen_frames

APP = "dev.isim.samples.HelloAppClip"
CLIP = f"{APP}.Clip"
FULL = APPS / "HelloAppClip.app"
CLIP_APP = FULL / "AppClips" / "HelloAppClipClip.app"
URL = "https://clip.hello.isim.dev/order"
SHOTS = os.environ.get("ISIM_APPCLIP_SHOTS")         # optional: also keep the screenshots there (docs, PRs)

pytestmark = pytest.mark.skipif(not CLIP_APP.is_dir(), reason="HelloAppClip.app is not built")


def install(data, app):
    p = subprocess.run([str(ISIM), "install", str(app)], env=dict(os.environ, ISIM_DATA=str(data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    assert p.returncode == 0, p.stdout
    return p.stdout


def keep(img, name):
    if SHOTS:
        Path(SHOTS).mkdir(parents=True, exist_ok=True)
        img.save(Path(SHOTS) / f"{name}.png")


def lookup_fixture(tmp):
    """the App Store listing of the full app (ISIM_APPSTORE_LOOKUP_URL: by bundle ID for an App Clip's overlay)"""
    from PIL import Image
    Image.new("RGB", (100, 100), (240, 120, 40)).save(tmp / "icon.png")
    (tmp / f"lookup-{APP}.json").write_text(json.dumps({"resultCount": 1, "results": [{
        "trackId": 1555000111, "trackName": "Hello App Clip", "sellerName": "isim samples", "formattedPrice": "Free",
        "primaryGenreName": "Food & Drink", "averageUserRating": 4.8, "userRatingCount": 52,
        "artworkUrl100": (tmp / "icon.png").as_uri()}]}))
    return {"ISIM_APPSTORE_LOOKUP_URL": (tmp / "lookup-{id}.json").as_uri().replace("%7B", "{").replace("%7D", "}")}


def frame(dev, ident):
    """the frame of a system element (the App Clip card's parts) from `dump`"""
    m = dev.wait_dump(rf"\((-?[\d.]+) (-?[\d.]+); ([\d.]+) x ([\d.]+)\) id={ident}\b")
    return tuple(float(v) for v in m.groups())


def test_appclip_build():
    """isim build embeds the App Clip like Xcode's Embed App Clips phase, with its Info.plist and entitlements"""
    info = plistlib.load(open(CLIP_APP / "Info.plist", "rb"))
    assert info["CFBundleIdentifier"] == CLIP and info["CFBundlePackageType"] == "APPL"
    assert info["NSAppClip"] == {"NSAppClipRequestEphemeralUserNotification": True, "NSAppClipRequestLocationConfirmation": True}
    assert (CLIP_APP / "HelloAppClipClip").is_file()
    ent = plistlib.load(open(CLIP_APP / "archived-expanded-entitlements.xcent", "rb"))
    assert ent["com.apple.developer.parent-application-identifiers"] == [APP]       # no team: $(AppIdentifierPrefix) is empty
    assert ent["com.apple.developer.on-demand-install-capable"] is True
    assert ent["com.apple.developer.associated-domains"] == ["appclips:clip.hello.isim.dev"]
    full = plistlib.load(open(FULL / "archived-expanded-entitlements.xcent", "rb"))
    assert ent["com.apple.security.application-groups"] == full["com.apple.security.application-groups"]
    assert "NSAppClip" not in plistlib.load(open(FULL / "Info.plist", "rb"))
    assert not (FULL / "Info.plist.orig").exists() and not (CLIP_APP / "AppClips").exists()


@pytest.mark.os_matrix
def test_appclip_invocations(launch, device_data, tmp_path, ios):
    """the App Clip card (look per iOS version), the launch with the invocation, location confirmation, ephemeral
    notifications, the App Library, expiry, and the full app replacing the App Clip"""
    from PIL import Image
    glass = int(float(ios[0] or 18)) >= 26
    header = tmp_path / "header.png"                      # the local experience's header image (3:2, orange)
    Image.new("RGB", (900, 600), (255, 140, 30)).save(header)
    out = install(device_data, CLIP_APP)
    assert "an App Clip: not on the Home Screen" in out, out
    dev = launch(None, env=lookup_fixture(tmp_path))
    dev.wait_log(r"SpringBoard: \d+ app\(s\)")
    assert not dev.has(r"SpringBoard: .*Smoothie Bar"), "App Clips are not on the home screen"

    # a local experience (Settings > Developer > Local Experiences): the card shows its title, subtitle, verb, image
    dev.send(f"appclip register {URL}/ {CLIP} Open|Order a Smoothie|Fresh fruit, blended to order|{header}")
    dev.wait_log(r"SpringBoard: local App Clip experience")
    dev.send(f"appclip {URL}/mango")                      # scanning an App Clip Code
    dev.wait_log(rf"SpringBoard: App Clip card for {CLIP} \({URL}/mango, local experience, from a code\)")
    dev.wait_log(r"isim shell: App Clip card “Order a Smoothie” \(Open; iOS \d+ look\)")
    dev.wait_dump(r"id=appclip-title text=Order a Smoothie")
    dev.wait_dump(r"id=appclip-subtitle text=Fresh fruit, blended to order")
    dev.wait_dump(r"id=appclip-notifications text=Notifications allowed for 8 hours")
    dev.wait_dump(r"id=appclip-location text=Can verify your location")
    card, button = frame(dev, "appclip-card"), frame(dev, "appclip-open")
    shot = dev.wait_shot_still()
    keep(shot, f"appclip-card-ios{int(float(ios[0] or 18))}")
    W, H = shot.size
    cx, cy, cw, ch = card
    assert cy + ch <= H and cy > H / 3, (card, H)          # a card at the bottom
    assert near(rgb(shot, cx + cw / 2, cy + 40), (255, 140, 30), 30), "the header image at the top of the card"
    bx, by, bw, bh = button
    assert near(rgb(shot, bx + 40, by + bh / 2), (0, 122, 255), 60), "the blue call-to-action button"
    corner = rgb(shot, bx + 5, by + 5)
    if glass:
        assert not near(corner, (0, 122, 255), 40), "iOS 26+: a capsule button (its corner is outside)"
    else:
        assert near(corner, (0, 122, 255), 40), "iOS 17/18: a rounded-rectangle button"
        assert min(rgb(shot, cx + 12, by - 8)) > 245, "iOS 17/18: an opaque white card"
    assert sum(rgb(shot, W / 2, 30)) < sum((255, 255, 255)) - 120, "the screen behind the card is dimmed"

    dev.tap_id("appclip-open")
    dev.wait_log(rf"SpringBoard: App Clip Smoothie Bar opens {URL}/mango")
    dev.wait_log(rf"HelloAppClipClip: invoked with {URL}/mango \(payload {URL}/mango\)")
    dev.wait_view(r"id=clip-item text=Order: mango")
    dev.wait_view(r"id=clip-launches text=Launch 1")
    keep(dev.wait_shot_still(), f"appclip-launched-ios{int(float(ios[0] or 18))}")
    dev.tap_id("clip-confirm")                            # the simulated location is Apple Park: at the shop
    dev.wait_view(r"id=clip-location text=Location: at the shop")
    dev.send("location 40.7128 -74.0060")
    dev.tap_id("clip-confirm")
    dev.wait_view(r"id=clip-location text=Location: not at the shop")
    dev.send("location 37.3349 -122.00902")
    dev.tap_id("clip-notify")                             # allowed on the card: ephemeral, no prompt
    dev.wait_view(r"id=clip-notifications text=Notifications: ephemeral")
    dev.wait_log(r"HelloAppClipClip: notification scheduled \(ok\)")
    assert not dev.has(r"Would Like to Send You Notifications")

    # the App Library's Recently Added; from there the App Clip gets its last invocation URL
    dev.send("home")
    dev.send("homepage library")
    x, y, w, h = screen_frames(dev.wait_view(rf"id=applibrary-recent-{CLIP}\b"))[f"applibrary-recent-{CLIP}"]
    dev.tap(x + w / 2, y + h / 2)
    dev.wait_log(rf"SpringBoard: App Clip Smoothie Bar from the App Library, with its last invocation {URL}/mango")
    dev.wait_log(rf"HelloAppClipClip: invoked with {URL}/mango", count=2)

    # iOS deletes an App Clip's data after a while without use
    dev.send(f"appclip expire {CLIP}")
    dev.wait_log(rf"SpringBoard: App Clip {CLIP} removed after inactivity: its data is deleted \(container, app group group\.{APP}\)")
    assert not (device_data / "Containers" / CLIP).exists()

    # a link to the App Clip's appclips: domain, no local experience: the default experience (the App Clip's name)
    dev.send("appclip unregister all")
    dev.wait_log(r"SpringBoard: 1 local App Clip experience\(s\) removed")
    dev.send(f"openurl {URL}/kiwi")
    dev.wait_log(rf"SpringBoard: App Clip card for {CLIP} \({URL}/kiwi, default experience, from a link\)")
    dev.wait_dump(r"id=appclip-title text=Smoothie Bar")
    dev.wait_dump(r"id=appclip-subtitle text=clip\.hello\.isim\.dev")
    dev.tap_id("appclip-location")                        # turn location confirmation off on the card
    dev.wait_log(r"App Clip card: location confirmation off")
    dev.tap_id("appclip-open")
    dev.wait_view(r"id=clip-item text=Order: kiwi")
    dev.wait_view(r"id=clip-launches text=Launch 1")      # its data was deleted: a fresh start
    dev.tap_id("clip-confirm")
    dev.wait_view(r"id=clip-location text=Location: not allowed")
    dev.wait_log(r"isim AppClip: location confirmation disallowed: turned off on the App Clip card")

    # the full app installed: the default experience opens it (iOS: it replaces the App Clip); it finds the order
    install(device_data, FULL)
    dev.send("home")
    dev.send(f"appclip {URL}/kiwi")
    dev.wait_log(rf"SpringBoard: Hello App Clip is installed: it opens {URL}/kiwi instead of its App Clip")
    dev.wait_view(rf"id=full-invocation text=Full app invoked with {URL}/kiwi")
    dev.wait_view(r"id=full-order text=Order from the App Clip: kiwi")
    assert dev.quit() == 0


def test_appclip_xcode_url(launch, tmp_path):
    """`isim run` of the App Clip with _XCAppClipURL: launched with the URL, no card (like Xcode); the 8 hours of
    ephemeral notifications run out; SKOverlay.AppClipConfiguration shows the full app's App Store listing"""
    env = dict(lookup_fixture(tmp_path), _XCAppClipURL=f"{URL}/banana", ISIM_APPCLIP_EPHEMERAL_SECONDS="6")
    app = launch(CLIP_APP, env=env)
    app.wait_log(rf"isim: App Clip launched with _XCAppClipURL {URL}/banana")
    app.wait_view(r"id=clip-item text=Order: banana")
    app.tap_id("clip-confirm")                            # not a scanned code: location confirmation is not allowed
    app.wait_view(r"id=clip-location text=Location: not allowed")
    app.wait_log(r"location confirmation disallowed: the invocation \(xcode\) did not come from an App Clip Code")
    app.tap_id("clip-notify")
    app.wait_view(r"id=clip-notifications text=Notifications: ephemeral")
    app.tap_id("clip-overlay")
    app.wait_view(r"id=sk-overlay-title text=Hello App Clip")
    app.wait_log(r"SKOverlay presented for app 1555000111 \(Hello App Clip\)")
    keep(app.wait_shot_still(), "appclip-skoverlay")
    app.tap_id("sk-overlay-close")
    app.wait_log(r"SKOverlay dismissed")

    def expired():                                       # the window (shortened to 6 s) ends: not determined again
        app.tap_id("clip-notify")
        return "text=Notifications: notDetermined" in app.view_dump()
    app.wait_until(expired, timeout=60, what="the ephemeral authorization to end", poll=0.5)
    assert app.quit() == 0


def test_appclip_local_experience_settings(launch, device_data):
    """Settings > Developer > Local Experiences registers an experience the home screen then uses for the card"""
    install(device_data, CLIP_APP)
    dev = launch(None)
    dev.wait_log(r"SpringBoard: \d+ app\(s\)")
    assert not dev.has(r"SpringBoard: \d+ app\(s\): .*Smoothie Bar")
    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-developer")
    dev.wait_tap_id("settings-local-experiences")
    dev.wait_tap_id("settings-register-experience")
    for ident, text in (("experience-url", f"{URL}/"), ("experience-bundle", CLIP), ("experience-title", "Smoothies"),
                        ("experience-subtitle", "Order at the counter")):
        dev.wait_tap_id(ident)
        dev.type(text)
    dev.wait_tap_id("experience-save")
    dev.wait_log(rf"Settings: registered the local experience {URL}/ -> {CLIP}")
    dev.wait_view(rf"id=settings-experience-{URL}/")
    dev.send(f"appclip {URL}/lemon nfc")                     # an NFC tag
    dev.wait_log(rf"SpringBoard: App Clip card for {CLIP} \({URL}/lemon, local experience, from an NFC tag\)")
    dev.wait_dump(r"id=appclip-title text=Smoothies")
    dev.tap_id("appclip-close")
    dev.wait_log(r"SpringBoard: App Clip card dismissed")
    assert dev.quit() == 0
