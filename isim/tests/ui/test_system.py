"""isim boot with HelloSystem: home-screen quick actions (static + dynamic, cold and warm launch), alternate app icons
(system alert, the home screen shows the new icon), URL schemes and universal links (script `openurl`, and
UIApplication.open from the app), scene state restoration across a device restart, beginBackgroundTask expiration, and
BackgroundTasks launches (`bgtask BUNDLE TASK` starts the app in the background). Port of tests/ui/system.sh."""
import math

from isimtest import count_px, visible

APP = "dev.isim.samples.HelloSystem"
ICON = f"app-{APP}"


def yellow(img):
    """pixels of the dark alternate icon's yellow S (#ffd60a, 15 % fuzz) in the icon's square"""
    return count_px(img, (36, 71, 70, 70), lambda c: math.dist(c, (255, 214, 10)) / math.sqrt(3) <= 0.15 * 255)


def test_system(launch):
    dev = launch(None, install=["HelloSystem"], env={"ISIM_BACKGROUND_TASK_SECONDS": "30"})
    dev.wait_view(visible(ICON))
    dev.send(f"holdid {ICON} 0.8")
    dev.wait_log(r"2 quick action\(s\) for System")
    tree = dev.wait_view(rf"id=menu-shortcut:{APP}\.new\b")
    assert "text=Find anything" in tree, "the icon menu lists the static quick actions above Edit Home Screen"
    assert yellow(dev.screenshot("menu")) < 20, "the primary icon is not the dark one"
    dev.tap_id(f"menu-shortcut:{APP}.new")
    dev.wait_log(rf"scene connected shortcut={APP}\.new")
    dev.wait_view(r"text=Launched by “New Note”")                         # cold launch: connectionOptions.shortcutItem
    assert dev.has(r'options=\["UIApplicationLaunchOptionsShortcutItemKey"\]'), "cold launch: launchOptions"
    dev.wait_opened("HelloSystem")
    dev.wait_tap_id("addShortcut")
    dev.wait_log(r"1 dynamic quick action\(s\) saved")
    for n in (1, 2, 3):
        dev.tap_id("bump")
        dev.wait_log(rf"HelloSystem: count {n}$")
    dev.send("home")
    dev.wait_log(r"saved scene state \(dev\.isim\.samples\.HelloSystem\.state\)")   # scene state saved when going home
    dev.wait_view(visible(ICON))
    dev.sleep(0.5)                                                       # the close animation
    dev.send(f"holdid {ICON} 0.8")
    dev.wait_log(r"3 quick action\(s\) for System")
    dev.wait_view(r"text=Favorites")                                     # dynamic quick action saved and listed
    dev.tap_id(f"menu-shortcut:{APP}.favorites")
    dev.wait_log(rf"performAction {APP}\.favorites “Favorites” n=7")     # warm: windowScene(_:performActionFor:)
    dev.wait_opened("HelloSystem", count=1)

    dev.wait_tap_id("altIcon")
    dev.wait_view(r"text=You have changed the icon for “System”\.")       # alternate icon: system alert
    dev.wait_log(r"setAlternateIconName DarkIcon error=nil now=DarkIcon")
    assert dev.has(r"supportsAlternateIcons=true")
    dev.tap_id("alert-OK")
    dev.wait_view(visible("alert-OK"), gone=True)
    dev.tap_id("primaryIcon")
    dev.wait_log(r"NoSuchIcon error=4")                                  # an unknown icon name fails
    dev.wait_tap_id("alert-OK")
    dev.wait_view(visible("alert-OK"), gone=True)
    dev.tap_id("altIcon")
    dev.wait_tap_id("alert-OK")
    dev.wait_view(visible("alert-OK"), gone=True)

    dev.tap_id("openURL")
    dev.wait_log(r"canOpenURL true")
    dev.wait_log(r"openURLContexts hellosystem://self\?from=app")
    dev.wait_log(r"open own scheme -> true")                             # the app opens its own URL scheme
    dev.send("openurl https://hello.isim.dev/items/7")
    dev.wait_log(r"SpringBoard: System opens https://hello\.isim\.dev/items/7 \(universal link\)")
    dev.wait_log(r"continue NSUserActivityTypeBrowsingWeb https://hello\.isim\.dev/items/7")   # universal link
    dev.send("openurl hellosystem://open?x=1")
    dev.wait_log(r"openURLContexts hellosystem://open\?x=1")             # custom URL scheme via openurl
    dev.send("openurl nothing://here")
    dev.wait_log(r"no app handles nothing://here")                      # unknown URL scheme not handled
    dev.wait_tap_id("schedule")
    dev.wait_log(r"submitted dev\.isim\.samples\.HelloSystem\.refresh \(refresh\)")
    dev.wait_log(r"unpermitted submit error code 3")
    dev.wait_log(r'pending \["dev\.isim\.samples\.HelloSystem\.cleanup", "dev\.isim\.samples\.HelloSystem\.refresh"\]')
    dev.send("home")
    dev.wait_log(r"isim shell: home")
    dev.wait_until(lambda: yellow(dev.screenshot("home-dark-icon")) > 100,
                   what="the home screen shows the alternate icon (dark, yellow S)")
    assert dev.quit() == 0

    # a device restart: the system ended the app, so its scene state is restored; a BackgroundTasks launch first
    dev = launch(None, env={"ISIM_BACKGROUND_TASK_SECONDS": "2"})
    dev.send(f"bgtask {APP} {APP}.refresh")
    dev.wait_log(r"launched in the background")
    dev.wait_log(r"didFinishLaunching state=background")
    dev.wait_log(r"refresh task ran \(BGAppRefreshTask\) state=background")
    dev.wait_log(rf"background task {APP}\.refresh completed \(success: true\)")   # bgtask launches the closed app
    dev.send(f"bgtask {APP} {APP}.refresh")
    dev.wait_log(rf"background task {APP}\.refresh: no pending request")  # a launched task is no longer pending
    dev.send(f"bgtask {APP} {APP}.cleanup")
    dev.wait_log(r"processing task ran \(BGProcessingTask\)")
    dev.wait_log(r"processing task expired", timeout=15)                 # processing task expires (expirationHandler)
    dev.send(f"launch {APP}")
    dev.wait_log(r"restoring scene state")
    dev.wait_log(r"restored count 3")
    dev.wait_view(r"text=Count 3")                                       # the scene connects and restores its state
    dev.wait_opened("HelloSystem")
    dev.wait_tap_id("bgTask")
    dev.wait_log(r"began background task [0-9]")
    dev.send("home")
    dev.wait_log(r"background task expired after 0 s left", timeout=15)  # beginBackgroundTask expires in the background
    assert dev.quit() == 0
