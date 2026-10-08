"""Remote notifications under `isim boot` (HelloPush): registration (device token), payloads from the `push` script
command and from `isim push` (with "Simulator Target Bundle"), delivery in the foreground (willPresent, banner), in the
background (the shell's banner, content-available background fetch) and to an app that is not running (the system
shows it; tapping launches the app with the notification; content-available launches it in the background), the
Notification Service extension (modified title, image attachment thumbnail, serviceExtensionTimeWillExpire), the
expanded notification with the Notification Content extension's view and the category's actions (text input reply,
foreground action, custom dismiss action), home-screen badges (from pushes and setBadgeCount), and suspension of the
backgrounded app with wake-ups for pushes and local notifications. Port of tests/ui/push.sh."""
import os
import re
import subprocess

from isimtest import ISIM, ROOT, count_px

APP = "dev.isim.samples.HelloPush"
P = ROOT / "samples" / "HelloPush" / "payloads"
ENV = {"ISIM_NOTIFICATION_PERMISSION": "allow", "ISIM_SUSPEND_SECONDS": "2", "ISIM_NOTIFICATION_SERVICE_SECONDS": "1"}
BADGE = (103, 69, 10, 22)                                              # the app icon's badge on the home screen


def fuzzy(target, fuzz):
    """ImageMagick-style -fuzz match: RGB distance within `fuzz` of the full range."""
    lim = 3 * (fuzz * 255) ** 2
    return lambda c: sum((a - b) ** 2 for a, b in zip(c, target)) <= lim


RED, PURPLE, ORANGE = fuzzy((0xff, 0x3b, 0x30), 0.12), fuzzy((0x99, 0x33, 0xe6), 0.12), fuzzy((0xff, 0x8c, 0x00), 0.10)


def push(dev, payload):
    dev.send(f"push {APP} {P / payload}")


def test_push_running(launch):
    """The app running: foreground, then background and suspended."""
    dev = launch(None, install=["HelloPush"], env=ENV)
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloPush: device token ")
    push(dev, "message.apns")
    dev.wait_log(r"delivered “msg-1” in the foreground")
    dev.wait_view(r"id=isim-notification-banner")                      # the in-app banner shows the push
    dev.screenshot("foreground")
    dev.send("home")
    home = dev.wait_shot(lambda s: count_px(s, BADGE, RED) > 60, "home-screen badge from the push (aps.badge 3)")
    dev.wait_log(r"isim shell: suspended HelloPush.app")
    push(dev, "background.apns")
    dev.wait_log(r"didReceiveRemoteNotification finished")
    push(dev, "service.apns")
    dev.wait_log(r"remote notification “svc-1”")
    banner = dev.wait_shot(lambda s: count_px(s, (330, 80, 60, 60), PURPLE) > 200,
                           "the banner shows the attachment thumbnail")
    push(dev, "slow.apns")
    dev.wait_log(r"delivered “slow-1” after serviceExtensionTimeWillExpire")
    dev.send("notifications")
    dev.wait_dump(r"id=nc-item-msg-1")
    dev.send("holdid nc-item-msg-1 0.8")
    dev.wait_log(r"SpringBoard: expanded notification msg-1 \(")
    expanded = dev.wait_shot(lambda s: count_px(s, (10, 90, 380, 150), ORANGE) > 5000,
                             "expanded notification: the content extension's view")
    dev.wait_dump(r"IsimNotificationAction.*id=nx-action-reply text=Reply")
    dev.wait_shot_still()                                              # the expanded card is in place
    dev.tap_id("nx-action-reply")
    dev.wait_dump(r"id=nx-reply-field")
    dev.type("Hi there")
    dev.send("key return")
    dev.wait_log(r"response reply to “Hello” id=msg-1 text=Hi there")
    dev.send("notifications")
    dev.wait_dump(r"id=nc-item-svc-1")
    dev.send("holdid nc-item-svc-1 0.8")
    dev.wait_log(r"SpringBoard: expanded notification svc-1 \(")      # the content extension has rendered
    dev.wait_dump(r"id=nx-background")
    dev.wait_shot_still()
    dev.tap_id("nx-background")
    dev.wait_log(r"response com.apple.UNNotificationDismissActionIdentifier")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("local")
    dev.wait_log(r"scheduled local-1")
    dev.send("home")
    dev.wait_log(r"delivered “local-1” in the background", timeout=20)
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log

    def has(s):
        return s in log
    assert re.search(r"HelloPush: device token [0-9a-f]{64} \(32 bytes\) registered=true", log), \
        "registration gives a 32-byte device token"
    assert has("willPresent “Hello” push=true category=MESSAGE") and \
        has("didReceiveRemoteNotification state=foreground item=m1") and \
        has("delivered “msg-1” in the foreground (banner)"), "foreground push: willPresent (push trigger) + fetch handler"
    assert has("SpringBoard: badge 3 on HelloPush") and count_px(home, BADGE, RED) > 60, \
        "home-screen badge from the push (aps.badge 3)"
    assert has("didReceiveRemoteNotification state=background item=b1") and \
        has("background task 1 (remote notification) began") and \
        has("didReceiveRemoteNotification finished (newData)"), \
        "content-available in the background: fetch as a background task"
    assert has("isim shell: suspended HelloPush.app") and has("resumed HelloPush.app (system event)"), \
        "the backgrounded app is suspended, a push resumes it"
    assert has("Notification Service extension delivered “svc-1” (title “Photo [modified]”, 1 attachment(s))") and \
        has("remote notification “svc-1” (modified by the service extension)"), \
        "service extension modifies the content and attaches an image"
    assert has("notification banner from") and count_px(banner, (330, 80, 60, 60), PURPLE) > 200, \
        "the banner shows the attachment thumbnail"
    assert has("PushService: serviceExtensionTimeWillExpire") and \
        has("delivered “slow-1” after serviceExtensionTimeWillExpire (title “Slow [modified] (expired)”"), \
        "serviceExtensionTimeWillExpire: the extension's last content"
    assert has("PushContent: didReceive msg-1 (MESSAGE)") and \
        has("expanded notification msg-1: 4 action(s), content extension view") and \
        re.search(r"IsimNotificationAction.*id=nx-action-reply text=Reply", log) and \
        count_px(expanded, (10, 90, 380, 150), ORANGE) > 5000, "long press expands: content extension view + 4 actions"
    assert has("notification action reply on msg-1 with text: Hi there") and \
        has("response reply to “Hello” id=msg-1 text=Hi there state=background"), \
        "text input action reaches the backgrounded app"
    assert has("expanded notification svc-1: 4 action(s)") and \
        has("response com.apple.UNNotificationDismissActionIdentifier to “Photo [modified]”"), \
        "category without a content extension: actions only; custom dismiss"
    assert has("resumed HelloPush.app (a local notification is due)") and \
        has("delivered “local-1” in the background"), "a local notification due while suspended wakes the app"


def test_push_not_running(launch, device_data):
    """The app is not running: the system shows the push; then `isim push` while the device runs; badges."""
    dev = launch(None, install=["HelloPush"], env=ENV)                 # a first run allows notifications
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloPush: device token ")
    assert dev.quit() == 0, "exits cleanly"
    dev = launch(None, env=ENV)
    push(dev, "message.apns")
    dev.wait_log(r"push msg-1 for Push")
    dev.wait_log(r"notification banner from")
    dev.screenshot("system-banner")
    dev.send("notifications")
    dev.wait_dump(r"id=nc-item-msg-1")
    dev.tap_id("nc-item-msg-1")
    dev.wait_log(r"response com.apple.UNNotificationDefaultActionIdentifier")
    dev.send("home")
    assert dev.quit() == 0, "exits cleanly"
    log2 = dev.log

    dev = launch(None, env=ENV)
    push(dev, "background.apns")
    dev.wait_log(r"didReceiveRemoteNotification state=background item=b1")
    cli = subprocess.run([str(ISIM), "push", str(P / "news.apns")], env=dict(os.environ, ISIM_DATA=str(device_data)),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
    dev.wait_log(r"push news-1 for Push")
    dev.wait_dump(r"badge-dev.isim.samples.HelloPush.*text=7")
    dev.screenshot("news-badge")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("badge5")
    dev.wait_log(r"badge 5 on HelloPush")
    dev.send("home")
    badge5 = dev.wait_shot(lambda s: count_px(s, BADGE, RED) > 60, "setBadgeCount shows the badge")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("badge0")
    dev.wait_log(r"badge cleared")
    dev.send("home")
    badge0 = dev.wait_shot(lambda s: count_px(s, BADGE, RED) < 10, "setBadgeCount clears the badge")
    assert dev.quit() == 0, "exits cleanly"
    log3 = dev.log
    both = log2 + "\n" + log3 + "\n" + cli

    def has(s):
        return s in both
    shown = log2[:log2.index("opened notification msg-1")] if "opened notification msg-1" in log2 else log2
    assert "push msg-1 for Push (alert, badge 3, sound)" in log2 and "notification banner from" in log2 and \
        not re.search(r"launched .*HelloPush.app", shown), "not running: the system shows the push and lists it"
    assert has("didFinishLaunching state=inactive remote=m1") and \
        has("response com.apple.UNNotificationDefaultActionIdentifier to “Hello” id=msg-1"), \
        "tapping it launches the app with the notification"
    assert has("launched in the background") and has("didFinishLaunching state=background remote=b1") and \
        has("didReceiveRemoteNotification state=background item=b1"), \
        "content-available launches the closed app in the background"
    assert has(f"isim push: sent to {APP}") and has("push news-1 for Push (alert, badge 7)") and \
        re.search(r"badge-dev.isim.samples.HelloPush.*text=7", log3), \
        "isim push with Simulator Target Bundle while the device runs"
    assert has("app icon badge 5") and has("badge 5 on HelloPush") and count_px(badge5, BADGE, RED) > 60 and \
        count_px(badge0, BADGE, RED) < 10, "setBadgeCount shows and clears the badge"
