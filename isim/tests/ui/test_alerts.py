"""Notification presentation under `isim boot` (HelloAlerts): local notifications of an app that is no longer running,
delivered by the system (the home screen's scheduler; the app's pending list and delivered list afterwards); sounds
(a custom sound file from the app bundle, Silent Mode); Notification Center stacks by thread with the category's
summary format (expanding and collapsing a stack); passive notifications (listed, no banner) and critical alerts
(through Silent Mode); the interactive Notification Content extension (taps on its view, the media button, its own
actions answered with didReceive(_:completionHandler:): keep, dismiss, forward to the app). System UI: os_matrix.
Screenshots also go to ISIM_SHOTS_DIR when it is set."""
import os
import re

import pytest

APP = "dev.isim.samples.HelloAlerts"
ENV = {"ISIM_NOTIFICATION_PERMISSION": "allow"}
SOUND = r"(played|\(no audio device\))"

pytestmark = pytest.mark.os_matrix


def keep(img, name):
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))
    return img


def shown_after(dev, marker):
    """the shell shows a frame the extension rendered after the log line `marker`"""
    def ok():
        log = dev.log
        frames = re.findall(r"Notification Content extension rendered \S+ x \S+ \(frame (\d+)\)", log[log.rfind(marker):])
        return frames and f"isim shell: content extension frame {frames[-1]}" in log
    dev.wait_until(ok, what=f"a content extension frame rendered after {marker}")


def started(launch):
    dev = launch(None, install=["HelloAlerts"], env=ENV)
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloAlerts: authorization granted=true")
    return dev


def test_delivered_while_not_running(launch):
    dev = started(launch)
    dev.tap_id("later")
    dev.wait_log(r"HelloAlerts: added later-1 error=nil")
    dev.send(f"terminate {APP}")                                  # gone before it is due: the system delivers it
    dev.wait_log(r"isim shell: local notification later-1 for \S+ which is not running: the system delivers it")
    dev.wait_log(rf"isim shell: notification sound ping.wav from HelloAlerts.app {SOUND}")
    dev.wait_log(r"SpringBoard: delivered the local notification later-1 of \S+ \(not running\)")
    dev.send("notifications")
    dev.nc_item("later-1")
    keep(dev.wait_shot_still(), "system-delivered")
    dev.send("home")
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloAlerts: pending \[\]")                     # taken off the pending list, listed as delivered
    dev.wait_log(r'HelloAlerts: delivered \["later-1"\]')


def test_stacks_and_levels(launch):
    dev = started(launch)
    dev.send("silent on")                                         # the Ring/Silent switch
    dev.wait_log(r"isim shell: Silent Mode on")
    dev.tap_id("chat")
    dev.wait_log(r"HelloAlerts: willPresent chat-3")
    dev.wait_log(r"isim shell: notification sound default from HelloAlerts.app not played \(Silent Mode\)")
    dev.tap_id("passive")                                         # both due in 1 s, delivered in the background
    dev.tap_id("critical")
    dev.wait_log(r"HelloAlerts: added critical-1 error=nil")
    dev.send("home")
    dev.wait_log(r"isim shell: passive notification from \S+ listed quietly: Weekly summary")
    dev.wait_log(r"isim shell: critical alert from \S+")
    dev.wait_log(rf"isim shell: notification sound default from HelloAlerts.app {SOUND} \(critical alert\)")   # through Silent Mode
    dev.send("silent off")
    dev.wait_log(r"isim shell: Silent Mode off")

    dev.send("notifications")                                     # Ann's thread is a stack; the other two the app's
    dev.wait_dump(r"IsimNotificationStack .* id=nc-group-chat-3 text=Ann \(2 more messages from Ann\)")
    dev.wait_dump(r"IsimNotificationStack .* id=nc-group-critical-1 text=Severe weather \(1 more notification\)")
    keep(dev.wait_shot_still(), "stack")
    dev.tap_id("nc-group-chat-3")                                  # expands: every message and Show Less
    dev.wait_dump(r"id=nc-item-chat-1 ")
    dev.wait_dump(r"id=nc-less-chat-3 text=Show Less")
    keep(dev.wait_shot_still(), "stack-expanded")
    dev.tap_id("nc-less-chat-3")
    dev.wait_dump(r"id=nc-group-chat-3")


def test_interactive_content_extension(launch):
    dev = started(launch)
    dev.tap_id("poll")
    dev.wait_log(r"HelloAlerts: willPresent poll-1")
    dev.send("notifications")
    dev.send("holdid nc-item-poll-1 0.8")
    dev.wait_log(r"AlertsPoll: didReceive poll-1")
    dev.wait_dump(r"IsimNotificationAction.*id=nx-action-close text=Close")    # the extension's own actions
    m = dev.wait_dump(r"IsimNotificationExtensionView \((\S+) (\S+); ")
    x, y = float(m.group(1)), float(m.group(2))
    dev.tap(x + 66, y + 106)                                      # its Vote button (16, 86; 100 x 40)
    dev.wait_log(r"AlertsPoll: vote tapped \(1\)")
    dev.tap_id("nx-media")
    dev.wait_log(r"AlertsPoll: mediaPlay")
    dev.wait_dump(r"IsimNotificationMediaButton .* id=nx-media text=Pause")
    shown_after(dev, "AlertsPoll: mediaPlay")                     # drawn again: "Votes: 1 ♪"
    keep(dev.wait_shot_still(), "content-extension")
    dev.tap_id("nx-action-yes")                                   # .doNotDismiss: stays expanded
    dev.wait_log(r"AlertsPoll: response yes")
    dev.wait_dump(r"id=nx-action-yes")
    dev.tap_id("nx-action-open")                                  # .dismissAndForwardAction: to the app
    dev.wait_log(r"AlertsPoll: response open")
    dev.wait_log(r"HelloAlerts: didReceive poll-1 action=open")
