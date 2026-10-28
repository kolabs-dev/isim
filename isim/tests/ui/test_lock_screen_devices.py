"""The lock screen per device (issue #125): Face ID iPhones show "Swipe up to open" and the flashlight and camera
buttons (or the chosen controls) in the bottom corners; the iPhone SE, which has a Home button, shows "Press home to
open" and no buttons; iPads show "Swipe up to open" and no buttons. Checked in the shell's `dump` (system UI:
os_matrix)."""
import re

import pytest

CASES = [("iphone16pro", "Swipe up to open", True), ("iphonese", "Press home to open", False),
         ("ipadmini", "Swipe up to open", False)]


@pytest.mark.os_matrix
@pytest.mark.parametrize("device,hint,buttons", CASES, ids=[c[0] for c in CASES])
def test_lock_screen_devices(launch, ios, device, hint, buttons):
    osv = ios[0]
    if device == "iphone16pro" and osv and str(osv).split(".")[0] == "17":
        device = "iphone15"                                # the iPhone 16 Pro needs iOS 18
    dev = launch(None, device=device, os_version=osv)
    dev.wait_log(r"SpringBoard: page 1 of")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_dump(rf"id=lock-hint text={re.escape(hint)}\b")
    dev.wait_dump(r"id=lock-clock\b")                       # a second, whole dump of the lock screen
    dump = dev.log[dev.log.rindex("id=lock-clock"):]
    assert ("id=lock-control-left" in dump) == buttons and ("id=lock-control-right" in dump) == buttons, \
        f"{device}: the bottom corner buttons {'shown' if buttons else 'absent'}"
    assert dev.quit() == 0, "exits cleanly"
