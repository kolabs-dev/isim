"""HelloWindows (UIKit scenes): on iPad with UIApplicationSupportsMultipleScenes, a new scene for a user activity next
to the requesting one (split view widths after sizeRestrictions), scene lifecycle callbacks and notifications,
didUpdateCoordinateSpace with per-scene size classes, requestSceneSessionDestruction, a prominent scene from
activateSceneSession(for:) sending the others to the background, an existing session activated again, rotation,
UIScene.open; the open sessions restored on the next launch; on iPhone new scenes are refused. UIDevice battery and
identifierForVendor. Port of tests/ui/windows.sh."""
import re

from isimtest import rgb

PAD = "ipadpro11"
WHITE = lambda c: c[0] > 240 and c[1] > 240 and c[2] > 240           # noqa: E731
BLACK = lambda c: c[0] < 20 and c[1] < 20 and c[2] < 20               # noqa: E731
YELLOW = lambda c: c[0] > 230 and c[1] > 180 and c[2] < 60            # noqa: E731


def vendor(log):
    m = re.search(r"vendor ([0-9A-F-]*)", log)
    return m.group(1) if m else ""


def test_windows(launch, tmp_path):
    app = launch("HelloWindows", device=PAD)
    app.wait_log(r"supportsMultipleScenes")
    app.wait_tap_id("openDetail")
    app.wait_log(r"detail7 connected")
    split = app.wait_view(lambda d: "UIWindow (0 0; 275 x 1210)" in d and "UIWindow (285 0; 549 x 1210)" in d,
                          what="split view: widths after the minimum size")
    app.wait_log(r"detail window 285 549")
    split_shot = app.wait_shot(lambda s: WHITE(rgb(s, 100, 600)) and BLACK(rgb(s, 280, 600)) and
                               YELLOW(rgb(s, 500, 600)), "split view pixels: both scenes and the divider")
    app.tap_id("count")
    app.wait_log(r"count 1")
    app.tap_id("closeDetail")
    app.wait_log(r"discarded 1 session")
    app.wait_log(r"main1 geometry 275 -> 834 x 1210")
    app.wait_still()
    app.tap_id("openDetail")
    app.wait_log(r"detail7 connected", count=2)
    app.wait_still()
    app.tap_id("openProminent")
    app.wait_log(r"main3 connected")
    app.wait_log(r"main1 background")
    app.wait_still()
    app.tap_id("showAll")
    app.wait_log(r"main3 geometry 834 -> 412 x 1210")
    two = app.wait_view(r"UIWindow \(422 0; 412 x 1210\)")
    app.wait_still()
    app.screenshot("two")
    app.tap_id("sessions")
    app.wait_log(r"open sessions ")
    app.tap_id("openURL")
    app.wait_log(r"scene open url ")
    app.send("rotate landscapeleft")
    app.wait_log(r"main3 geometry 412 -> 600 x 834")
    landscape = app.wait_view(r"UIWindow \(610 0; 600 x 834\)")
    app.screenshot("landscape")
    app.send("rotate portrait")
    app.wait_log(r"main3 geometry 600 -> ")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    dumps = "\n".join((split, two, landscape))

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"HelloWindows: supportsMultipleScenes true"), "supportsMultipleScenes: iPad yes"
    assert has(r"detail7 connected \(Detail\) for dev.isim.samples.HelloWindows.detail, item 7, size restrictions 500"), \
        "a new scene for a user activity (its configuration, size restrictions)"
    assert has(r"main1 geometry 834 -> 275 x 1210, portrait -> portrait, size class regular -> compact, frame x 0") and \
        has(r"detail window 285 549, size class compact"), "split view: per-scene size classes"
    assert split_shot, "split view pixels: both scenes and the divider"
    assert has(r"detail7 foreground") and has(r"notification willEnterForeground detail7") and \
        has(r"notification didActivate detail7") and has(r"notification willConnect"), "scene lifecycle and notifications"
    assert has(r"detail7 disconnected") and has(r"notification didDisconnect detail7") and \
        has(r"discarded 1 session\(s\)") and has(r"main1 geometry 275 -> 834 x 1210"), \
        "destruction: disconnect, discarded session, the other scene takes the screen"
    assert has(r"main3 connected \(Default Configuration\)") and has(r"main1 background") and \
        has(r"notification didEnterBackground main1") and has(r"notification willDeactivate detail7") and \
        has(r"isim: scenes: isim-[0-9A-F]+ \(background\), isim-[0-9A-F]+ \(background\), isim-[0-9A-F]+ \(0..834\)"), \
        "prominent scene (activateSceneSession(for:)) sends the others to the background"
    assert has(r"activating scene session") and has(r"main3 geometry 834 -> 412 x 1210") and \
        has(r"main1 foreground") and "UIWindow (422 0; 412 x 1210)" in dumps, \
        "an existing session activated again comes back beside the current one"
    assert has(r'open sessions \["detail7", "main1", "main3"\], scenes \["detail7=2", "main1=0", "main3=0"\]'), \
        "open sessions and activation states"
    assert has(r"scene open url false"), "UIScene.open (no app for the URL)"
    assert has(r"main3 geometry 412 -> 600 x 834, portrait -> landscape") and "UIWindow (610 0; 600 x 834)" in dumps, \
        "rotation: scenes resize, delegates get the old orientation"
    assert has(r"battery 1.0 state 3"), "UIDevice: battery"

    app = launch("HelloWindows", device=PAD)                          # same device data: sessions restored
    app.wait_log(r"isim: restoring 3 scene sessions")
    restored = app.wait_view(r"UIWindow \(0 0; 412 x 1210\)")
    app.wait_tap_id("sessions")
    app.wait_log(r"open sessions ")
    app.tap_id("showDetail")
    app.wait_log(r"detail7 connected \(Detail\) for restoration, item 7")
    restored_shot = app.wait_shot(lambda s: YELLOW(rgb(s, 500, 600)),
                                  "a restored background session connects when activated")
    assert app.quit() == 0, "exits cleanly"
    log2 = app.log
    assert re.search(r"main1 connected \(Default Configuration\), restored 1", log2) and \
        "UIWindow (0 0; 412 x 1210)" in restored and \
        re.search(r'open sessions \["detail7", "main1", "main3"\], scenes \["main1=0", "main3=0"\]', log2), \
        "sessions restored on the next launch (split order, state restoration)"
    assert restored_shot, "a restored background session connects when activated (its configuration and state)"

    (tmp_path / "phone").mkdir()
    phone = launch("HelloWindows", data=tmp_path / "phone", env={"ISIM_BATTERY": "0.5 charging"})
    phone.wait_tap_id("openDetail")
    phone.wait_log(r"open detail failed: UISceneErrorDomain 0")         # iPhone: MultipleScenesNotSupported
    phone.tap_id("openURL")
    phone.wait_log(r"scene open url ")
    assert phone.quit() == 0, "exits cleanly"
    plog = phone.log
    assert "HelloWindows: supportsMultipleScenes false" in plog, "supportsMultipleScenes: iPhone no"
    assert "scene open url false" in plog, "UIScene.open (no app for the URL)"
    v1, v2 = vendor(log), vendor(log2)
    assert "battery 0.5 state 2" in plog and v1 and v1 == v2 and v1 not in plog, \
        "UIDevice: battery (ISIM_BATTERY), identifierForVendor stable per device"
