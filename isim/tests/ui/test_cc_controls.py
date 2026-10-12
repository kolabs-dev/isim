"""Control Center controls (iOS 18 ControlWidget) under `isim boot` (HelloFocusControls): the widget extension
describes its controls; Control Center's edit mode (+) offers them in the "Add a Control" gallery with the system
controls; added controls run their App Intent in the extension (a toggle's SetValueIntent gets the new value; the
value provider gives the new state back), can be resized and removed; the app's ControlCenter.reloadControls and
currentControls; a control on the Lock Screen and on the Action button. iOS 17 has no app controls (and no edit
button). Screenshots also go to ISIM_SHOTS_DIR when it is set."""
import os
import re

import pytest

from isimtest import mean_rgb

APP = "dev.isim.samples.HelloFocusControls"
LAMP, COUNT = f"{APP}.lamp", f"{APP}.count"


def keep(img, name):
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))
    return img


def frame(dump_line):
    m = re.search(r"\(([-\d.]+) ([-\d.]+); ([\d.]+) x ([\d.]+)\)", dump_line)
    return tuple(float(v) for v in m.groups())


@pytest.mark.os_matrix
def test_controls(launch, ios):
    v = int(ios[0] or 18)
    dev = launch(None, install=["HelloFocusControls"], env={"ISIM_NOTIFICATION_PERMISSION": "allow"})
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    if v < 18:                                                           # ControlWidget is iOS 18+
        dev.send("controlcenter")
        cc = dev.wait_dump(r"id=cc-flashlight[^\n]*(?:\n.*)*")
        assert "id=cc-edit" not in cc.group(0) and "cc-control-" not in cc.group(0), "iOS 17: no edit mode, no app controls"
        assert "control(s) from" not in dev.log, "iOS 17: the system does not ask for controls"
        assert dev.quit() == 0
        return
    dev.wait_log(rf"isim shell: 2 control\(s\) from .*HelloFocusControls\.app")
    dev.send("controlcenter")
    dev.wait_dump(r"id=cc-edit")
    dev.tap_id("cc-edit")
    dev.wait_log(r"Control Center edit mode")
    dev.wait_dump(r"id=cc-add-control")
    dev.tap_id("cc-add-control")
    dev.wait_log(r"Control Center gallery \(2 app controls\)")
    dev.wait_dump(r"id=cc-gallery-system-lowpower")
    gallery = dev.wait_dump(rf"id=cc-gallery-{re.escape(LAMP)} text=Desk Lamp(?:\n.*)*id=cc-gallery-system-lowpower")
    keep(dev.wait_shot_still(), f"controls-gallery-ios{v}")
    assert f"id=cc-gallery-{COUNT} text=Counter" in gallery.group(0) and "id=cc-gallery-system-lowpower" in gallery.group(0), \
        "the gallery lists the app's controls (display names) and system controls"
    dev.tap_id(f"cc-gallery-{LAMP}")
    dev.wait_log(rf"added control {re.escape(LAMP)} \(Focus Lamp\)")
    dev.wait_dump(r"id=cc-add-control")
    dev.tap_id("cc-add-control")
    dev.wait_dump(rf"id=cc-gallery-{re.escape(COUNT)}")
    dev.tap_id(f"cc-gallery-{COUNT}")
    dev.wait_log(rf"added control {re.escape(COUNT)}")
    dev.wait_dump(rf"id=cc-resize-{re.escape(LAMP)}")
    dev.tap_id(f"cc-resize-{LAMP}")
    dev.wait_log(rf"control {re.escape(LAMP)} is medium \(2x1\)")
    keep(dev.wait_shot_still(), f"controls-edit-ios{v}")
    dev.tap_id("cc-edit-background")
    dev.wait_log(r"Control Center edit mode ended")
    off = dev.wait_dump(rf"IsimControlButton [^\n]*id=cc-control-{re.escape(LAMP)} text=Lamp: Off")
    dev.tap_id(f"cc-control-{LAMP}")
    dev.wait_log(rf"Control Center runs control {re.escape(LAMP)} \(Focus Lamp\): turn on")
    dev.wait_log(r"HelloFocusControls: lamp on")
    dev.wait_log(rf"control {re.escape(LAMP)} \(toggle\): Lamp Bright \[on\]")
    on = dev.wait_dump(rf"IsimControlButton [^\n]*id=cc-control-{re.escape(LAMP)} text=Lamp: Bright")
    x, y, w, h = frame(on.group(0))
    shot = keep(dev.wait_shot(lambda s: sum(mean_rgb(s, (x + w * 0.55, y + h * 0.15, w * 0.35, 6))) / 3 > 200,
                              "the lamp module is on (light platter)"), f"controls-cc-ios{v}")
    dev.tap_id(f"cc-control-{COUNT}")
    dev.wait_log(r"HelloFocusControls: count 1")
    dev.wait_dump(rf"id=cc-control-{re.escape(COUNT)} text=Count 1")
    dev.tap_id("cc-background")

    dev.send(f"launch {APP}")                                             # the app: reloadControls, currentControls
    dev.wait_tap_id("toggleLamp")
    dev.wait_log(r"app set lamp off")
    dev.wait_log(rf"SpringBoard: reloading controls \({re.escape(LAMP)}\)")
    dev.wait_log(rf"control {re.escape(LAMP)} \(toggle\): Lamp Off \[off\]")
    dev.tap_id("currentControls")
    dev.wait_log(r"HelloFocusControls: current controls count, lamp$")
    dev.send("home")

    dev.send(f"lockcontrol left {LAMP}")                                  # the Lock Screen's left button
    dev.wait_log(rf"Lock Screen left button: {re.escape(LAMP)}")
    dev.send("lock")
    dev.wait_dump(r"id=lock-control-left text=Lamp")
    dev.tap_id("lock-control-left")
    dev.wait_log(rf"Lock Screen \(left\) runs control {re.escape(LAMP)}")
    dev.wait_log(r"HelloFocusControls: lamp on", count=2)
    dev.wait_dump(r"id=lock-control-left text=Lamp: on")
    keep(dev.wait_shot_still(), f"controls-lock-ios{v}")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")

    dev.send("actionbutton")                                              # iPhone 16 Pro / iPhone 17: Silent Mode
    dev.wait_log(r"Silent Mode on")
    dev.send(f"actionbutton assign {COUNT}")
    dev.wait_log(rf"Action button: {re.escape(COUNT)}")
    dev.send("actionbutton")
    dev.wait_log(rf"Action button runs control {re.escape(COUNT)} \(Focus Lamp\) — Count up")
    dev.wait_log(r"HelloFocusControls: count 2")

    dev.send("controlcenter")                                             # remove the counter again
    dev.wait_dump(r"id=cc-edit")
    dev.tap_id("cc-edit")
    dev.wait_dump(rf"id=cc-remove-{re.escape(COUNT)}")
    dev.tap_id(f"cc-remove-{COUNT}")
    dev.wait_log(rf"removed control {re.escape(COUNT)}")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert re.search(r"isim WidgetKit: 2 control\(s\)", log), "the extension describes its controls"
    assert "SpringBoard: running control" in log and "isim WidgetKit: running control" in log, \
        "a tap runs the control's intent in the widget extension"
    assert off and shot, "the control's state is drawn"
