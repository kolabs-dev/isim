"""The system UI drawn by the shell (`isim boot`): lock screen (apps go to the background, notifications are listed,
unlock), Notification Center (pull down from the top, open a notification, clear), Control Center (pull down from the
top-right corner; Wi-Fi off makes NWPathMonitor unsatisfied, Dark Mode changes the appearance, orientation lock
ignores rotations, Focus hides banners) and the app switcher (cards in recent order, swipe up to close, tap to switch).
System UI parts are only in `dump` output (wait_dump). Port of tests/ui/systemui.sh."""
import re

from isimtest import mean_rgb

SECURITY, SYSTEM = "dev.isim.samples.HelloSecurity", "dev.isim.samples.HelloSystem"


def after(log, marker):
    """The log from the first line containing `marker` on."""
    i = log.find(marker)
    return log[i:] if i >= 0 else ""


def test_systemui(launch):
    dev = launch(None, install=["HelloSystem", "HelloSecurity"], env={"ISIM_NOTIFICATION_PERMISSION": "allow"})
    dev.send(f"launch {SECURITY}")
    dev.wait_tap_id("notify")
    dev.wait_log(r"notify scheduled")
    dev.send(f"launch {SYSTEM}")
    dev.wait_log(r"HelloSystem: scene connected")
    dev.wait_log(r"HelloSystem: network satisfied")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_log(r"listed on the lock screen: Security demo")
    lock_dump = dev.wait_dump(r"IsimNotification .* id=nc-item-backup text=Security demo")
    lock = dev.wait_shot(lambda s: sum(mean_rgb(s, (11, 370, 380, 70))) / 3 / 255 > 0.8,
                         "lock screen clock and notification drawn (pixels)")
    dev.drag(200, 860, 200, 600, 0.3)                                    # swipe up: unlock
    dev.wait_log(r"isim shell: unlocked")
    dev.wait_log(r"HelloSystem: scene foreground")
    dev.drag(120, 4, 120, 320, 0.3)                                      # pull down from the top
    dev.wait_log(r"isim shell: Notification Center")
    dev.screenshot("notification-center")
    dev.wait_dump(r"IsimNotificationCenter")
    dev.tap_id("nc-item-backup")
    dev.wait_log(r"opened backup action default")

    dev.wait_tap_id("notify")
    dev.wait_log(r"notify scheduled", count=2)
    dev.send("home")
    dev.wait_log(r"notification banner from .*HelloSecurity", timeout=15)
    dev.send(f"launch {SYSTEM}")
    dev.wait_log(r"HelloSystem: scene foreground", count=2)
    dev.send("switcher")
    dev.wait_log(r"app switcher \(")
    dev.screenshot("switcher")
    switcher = dev.wait_dump(r"^IsimAppSwitcher.*(?:\n.*){3}")
    dev.send("swipeid switcher-HelloSecurity 0 -300 0.3")
    dev.wait_log(r"HelloSecurity.app exited")
    dev.tap_id("switcher-HelloSystem")
    dev.wait_log(r"switched to .*HelloSystem.app")
    dev.wait_shot_still()                                              # the switcher has closed
    dev.drag(380, 4, 380, 320, 0.3)                                      # pull down from the top-right corner
    dev.wait_dump(r"id=cc-wifi text=on")
    cc = dev.wait_shot(lambda s: (c := mean_rgb(s, (52, 242, 6, 6)))[2] > 0.8 * 255 and c[0] < 0.3 * 255,
                       "Control Center drawn (pixels: blue Wi-Fi button)")
    dev.tap_id("cc-wifi")
    dev.wait_log(r"HelloSystem: network unsatisfied")
    dev.tap_id("cc-dark")
    dev.wait_log(r"HelloSystem: appearance dark")
    dev.tap_id("cc-orientation")
    dev.tap_id("cc-focus")
    dev.screenshot("control-center-on")
    dev.tap_id("cc-background")
    dev.send("rotate left")
    dev.wait_log(r"rotation ignored \(orientation lock\)")
    dev.send("controlcenter")
    dev.wait_dump(r"id=cc-wifi")
    dev.tap_id("cc-wifi")
    dev.wait_log(r"HelloSystem: network satisfied", count=2)
    dev.tap_id("cc-background")
    dev.send("notifications")
    dev.wait_log(r"isim shell: Notification Center", count=2)
    dev.wait_dump(r"id=nc-clear")
    dev.tap_id("nc-clear")
    dev.wait_log(r"cleared \d+ notification")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log

    assert "isim shell: locked" in log and "HelloSystem: scene background" in after(log, "isim shell: locked"), \
        "lock: the foreground app goes to the background"
    assert "listed on the lock screen: Security demo" in log and "IsimLockScreen" in log and lock_dump, \
        "lock screen lists a notification delivered while locked"
    assert lock, "lock screen clock and notification drawn (pixels)"
    assert "HelloSystem: scene foreground" in after(log, "isim shell: unlocked"), \
        "swipe up unlocks; the app returns to the foreground"
    assert "isim shell: Notification Center (1 notification)" in log and "IsimNotificationCenter" in log, \
        "pull down from the top: Notification Center"
    assert "opened notification backup from Notification Center" in log and "opened backup action default" in log, \
        "opening the notification reopens its app (didReceive)"
    cards = [c for c in re.findall(r"id=(switcher-\S+)", switcher.group(0)) if c != "switcher-background"]
    assert "app switcher (2 apps)" in log and cards[:2] == ["switcher-HelloSecurity", "switcher-HelloSystem"], \
        f"app switcher: cards in recent order (newest on top) {cards}"
    assert re.search(r"closed .*HelloSecurity.app from the app switcher", log) and "HelloSecurity.app exited" in log, \
        "swipe a card up: the app is closed"
    assert re.search(r"switched to .*HelloSystem.app", log), "tap a card: switch to that app"
    assert "IsimControlCenter" in log and "id=cc-wifi text=on" in log, "pull down from the top-right: Control Center"
    assert "network offline (Control Center)" in log and \
        "HelloSystem: network unsatisfied" in after(log, "network offline") and \
        "HelloSystem: network satisfied" in after(log, "network online"), \
        "Wi-Fi off: NWPathMonitor unsatisfied; on: satisfied"
    assert "SpringBoard: appearance dark" in log and "HelloSystem: appearance dark" in after(log, "Dark Mode on"), \
        "Dark Mode: apps switch appearance"
    assert "rotation ignored (orientation lock)" in log, "orientation lock ignores rotation"
    assert cc, "Control Center drawn (pixels: blue Wi-Fi button; iOS 18 layout)"
    assert "Notification Center (1 notification)" in log and "cleared 1 notification(s)" in log, \
        "Notification Center: a second notification listed, cleared"
