"""HelloScenes under `isim boot` (SwiftUI): @UIApplicationDelegateAdaptor (launch + forwarded callbacks, its scene
delegate class gets the quick action), @SceneStorage restored after a restart, .userActivity indexed for Spotlight and
.onContinueUserActivity, .backgroundTask(.appRefresh) launched in the background, openWindow on iPhone (ignored) and
on iPad (the detail WindowGroup; dismissWindow goes back). Port of tests/ui/scenes.sh."""
import re

APP = "dev.isim.samples.HelloScenes"


def test_scenes(launch):
    dev = launch(None, install=["HelloScenes"])
    dev.send(f"launch {APP}")
    dev.wait_tap_id("bump")
    dev.wait_view(r"text=Count 1")
    dev.tap_id("bump")
    dev.wait_view(r"text=Count 2")
    dev.tap_id("schedule")
    dev.wait_log(r"scheduled refresh")
    dev.tap_id("openDetail")
    dev.wait_log(r"openWindow\(id: detail\) ignored")
    dev.send("home")
    dev.wait_log(r"HelloScenes: adaptor didEnterBackground")
    dev.send("spotlight")
    dev.wait_view(r"id=spotlight-field")
    dev.type("scenes")
    dev.wait_log(r"Spotlight “scenes”: ")
    dev.wait_tap_id(f"spotlight-item-activity_{APP}.re")
    dev.wait_log(r"HelloScenes: continued ")
    dev.wait_view(r"text=Continued Scenes recipe")
    dev.send("home")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    dev.wait_still()
    dev.send(f"holdid app-{APP} 0.8")
    dev.wait_tap_id(f"menu-shortcut:{APP}.new")
    dev.wait_log(r"scene delegate quick action ")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert f"HelloScenes: adaptor didFinishLaunching (foreground)" in log, "@UIApplicationDelegateAdaptor: didFinishLaunching"
    assert "HelloScenes: adaptor didEnterBackground" in log, "adaptor gets forwarded callbacks (didEnterBackground)"
    assert f"scene delegate quick action {APP}.new" in log, "adaptor scene delegate class gets the quick action"
    assert "Spotlight “scenes”: 1 app(s), 1 item(s)" in log and "HelloScenes: continued Scenes recipe pancakes" in log, \
        ".userActivity indexed; Spotlight -> .onContinueUserActivity"
    assert "supportsMultipleWindows false" in log and "openWindow(id: detail) ignored" in log, \
        "openWindow on iPhone does nothing"

    dev = launch(None)                                                 # restart: @SceneStorage restored
    dev.send(f"launch {APP}")
    dev.wait_log(r"restored \d+ @SceneStorage value")
    dev.wait_view(r"text=Count 2", what="@SceneStorage restored after a restart")
    assert dev.quit() == 0, "exits cleanly"
    assert "restored 1 @SceneStorage value(s)" in dev.log, "@SceneStorage restored after a restart"

    dev = launch(None)                                                 # a background launch for the refresh task
    dev.send(f"bgtask {APP} {APP}.refresh")
    dev.wait_log(r"HelloScenes: SwiftUI background refresh ran")
    assert dev.quit() == 0, "exits cleanly"
    assert "adaptor didFinishLaunching (background)" in dev.log and "no launch handler" not in dev.log, \
        ".backgroundTask(.appRefresh) runs in a background launch"

    dev = launch(None, device="ipadpro11")                             # iPad: the detail WindowGroup
    dev.send(f"launch {APP}")
    dev.wait_tap_id("openDetail")
    dev.wait_view(r"id=detailTitle")
    dev.wait_still()
    dev.screenshot("ipad-detail")
    dev.tap_id("closeDetail")
    dev.wait_log(r"dismissWindow -> main")
    dev.view_dump()
    assert dev.quit() == 0, "exits cleanly"
    assert "supportsMultipleWindows true" in dev.log, "iPad: openWindow shows the detail WindowGroup; dismissWindow"
