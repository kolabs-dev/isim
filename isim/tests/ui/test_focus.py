"""Focus under `isim boot` (HelloFocusControls): the Focus modes in Control Center (the module toggles, its title opens
the list), the script `focus`; while a Focus is on, notifications from apps it does not allow are delivered quietly
(Notification Center, no banner) and time-sensitive ones break through; the Focus status for apps
(INFocusStatusCenter); Settings > Focus: allowed apps and Focus filters (the app's SetFocusFilterIntent with its
parameters) — turning the Focus on runs the filter's perform() in the app (launched in the background when it is not
running) and its notification predicate quiets non-matching notifications; turning it off runs perform() with the
defaults; `current`. Screenshots also go to ISIM_SHOTS_DIR when it is set."""
import os
import re

APP = "dev.isim.samples.HelloFocusControls"
SETTINGS = "dev.isim.settings"


def keep(img, name):
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))
    return img


def settings(dev):
    dev.send(f"terminate {SETTINGS}")
    dev.send(f"launch {SETTINGS}")


def notify(dev, *buttons):
    """tap the app's notify buttons, then go home before the notifications fire (2 s later)"""
    dev.send(f"launch {APP}")
    for b in buttons:
        pattern = rf"HelloFocusControls: scheduled {b[6:].lower()}"
        n = dev.count(pattern)
        dev.wait_tap_id(b)
        dev.wait_log(pattern, count=n + 1)
    dev.send("home")


def test_focus(launch, device_data):
    dev = launch(None, install=["HelloFocusControls"],
                 env={"ISIM_NOTIFICATION_PERMISSION": "allow", "ISIM_FOCUS_STATUS_PERMISSION": "allow"})
    dev.wait_log(r"SpringBoard: Focus Lamp has 1 Focus filter")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    # Control Center: the Focus module and the list of modes
    dev.send("controlcenter")
    dev.wait_dump(r"id=cc-focus-modes text=Focus")
    dev.tap_id("cc-focus-modes")
    dev.wait_log(r"isim shell: Focus modes")
    modes = dev.wait_dump(r"id=cc-focus-dnd text=off(?:\n.*){3}")
    assert all(f"id=cc-focus-{m}" in modes.group(0) for m in ("personal", "work", "sleep")), "the four Focus modes"
    dev.tap_id("cc-focus-work")
    dev.wait_log(r"isim shell: Focus Work on")
    dev.wait_dump(r"id=cc-focus-work text=on")
    keep(dev.wait_shot_still(), "focus-list")
    dev.tap_id("cc-page-background")
    dev.wait_dump(r"id=cc-focus text=Work")
    dev.tap_id("cc-focus")                                                # the module's icon: off
    dev.wait_log(r"isim shell: Focus off \(was Work\)")
    dev.tap_id("cc-background")

    # Do Not Disturb: the app is not allowed; its time-sensitive notification breaks through
    dev.send("focus dnd")
    dev.wait_log(r"isim shell: Focus Do Not Disturb on")
    notify(dev, "notifyHome", "notifyUrgent")
    dev.wait_log(r"notification from HelloFocusControls\.app silenced \(Focus Do Not Disturb\): Focus Lamp")
    dev.wait_log(r"time-sensitive notification from HelloFocusControls\.app breaks through Focus Do Not Disturb")
    dev.wait_log(r"notification banner from .*HelloFocusControls\.app")
    dev.send("notifications")
    dev.wait_dump(r"id=nc-item-home")
    keep(dev.wait_shot_still(), "focus-silenced")
    dev.send("home")
    dev.send("lock")
    dev.wait_dump(r"id=lock-focus text=Do Not Disturb")
    keep(dev.wait_shot_still(), "focus-lock-screen")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")

    dev.send(f"launch {APP}")                                             # INFocusStatusCenter
    dev.wait_tap_id("focusStatus")
    dev.wait_log(r"focus status authorization 3, isFocused yes")
    dev.send("home")

    # Settings > Focus > Work: allow the app, add its Focus filter
    settings(dev)
    dev.wait_tap_id("settings-focus")
    dev.wait_view(r"id=settings-focus-sleep")
    keep(dev.wait_shot_still(), "settings-focus")
    dev.tap_id("settings-focus-work")
    dev.wait_tap_id("focus-apps")
    dev.wait_tap_id(f"focus-app-{APP}")
    dev.wait_view(rf"id=focus-app-{re.escape(APP)} text=on")
    settings(dev)
    dev.wait_tap_id("settings-focus")
    dev.wait_tap_id("settings-focus-work")
    dev.wait_tap_id("focus-add-filter")
    dev.wait_tap_id(f"focus-filter-app-{APP}")
    dev.wait_tap_id("focus-param-workOnly")
    dev.wait_view(r"id=focus-param-workOnly text=on")
    dev.tap_id("focus-param-account-work")
    dev.wait_view(r"id=focus-param-account-work")
    keep(dev.wait_shot_still(), "settings-focus-filter-options")
    dev.wait_tap_id("focus-filter-add")
    dev.wait_log(r"Settings: Focus filter Set Lamp Focus of Focus Lamp added for work: account=work, workOnly=(true|1)")
    dev.wait_view(r"id=focus-filter-add\b", gone=True)                  # the sheet closed, back on the Focus page
    dev.wait_view(rf"id=focus-filter-{re.escape(APP)}")
    keep(dev.wait_shot_still(), "settings-focus-filter")

    # Work on: the filter runs in the app (not running: launched in the background)
    dev.send(f"terminate {APP}")
    dev.wait_log(r"terminated .*HelloFocusControls\.app \(system\)")
    dev.send("focus work")
    dev.wait_log(r"SpringBoard: Focus Work on: running the Focus filter Set Lamp Focus of Focus Lamp")
    dev.wait_log(r"HelloFocusControls\.app launched in the background")
    dev.wait_log(r"HelloFocusControls: focus filter perform workOnly=true account=work note=-")
    dev.wait_log(r"isim AppIntents: notification filter SELF IN")
    notify(dev, "notifyHome", "notifyWork")
    dev.wait_log(r"notification from HelloFocusControls\.app silenced by its Focus filter \(Focus Work\)")
    dev.wait_log(r"notification from HelloFocusControls\.app allowed during Focus Work")
    dev.wait_log(r"notification banner from .*HelloFocusControls\.app", count=2)
    dev.send(f"launch {APP}")
    dev.wait_tap_id("readFilter")
    dev.wait_log(r"current filter work work-only")
    dev.send("home")

    # off: perform() with the defaults (the app is running)
    dev.send("focus off")
    dev.wait_log(r"isim shell: Focus off \(was Work\)")
    dev.wait_log(r"Focus filter Set Lamp Focus \(Work off\): perform\(\)")
    dev.wait_log(r"HelloFocusControls: focus filter perform workOnly=false account=home")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("focusStatus")
    dev.wait_log(r"isFocused no")
    assert dev.quit() == 0, "exits cleanly"
    focus = (device_data / "Library/isim/Focus/Allowed.txt").read_text()
    assert "work\t" in focus and "HelloFocusControls.app" in focus, "Settings writes the allowed apps for the shell"
