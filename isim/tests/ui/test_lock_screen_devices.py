"""The lock screen per device (issue #125): Face ID iPhones show "Swipe up to open" and the flashlight and camera
buttons (or the chosen controls) in the bottom corners; the iPhone SE, which has a Home button, shows "Press home to
open" and no buttons; iPads show "Swipe up to open" and no buttons. Checked in the shell's `dump` (system UI:
os_matrix)."""
import re

import pytest

CASES = [("iphone16pro", "Swipe up to open", True), ("iphonese", "Press home to open", False),
         ("ipadmini", "Swipe up to open", False)]


def whole_dump(dev):
    """The lock screen's elements from a dump known to be complete: one a later dump's header follows (a dump's lines
    may still be arriving when the log is read, #766). Asks for another dump when there is none yet."""
    heads = [m.start() for m in re.finditer(r"^IsimLockScreen \(", dev.log, re.M)]
    if len(heads) >= 2:
        return dev.log[heads[-2]:heads[-1]]
    dev.send("dump")
    return None


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
    dump = dev.wait_until(lambda: whole_dump(dev), what="a whole dump of the lock screen", poll=0.3)
    assert ("id=lock-control-left" in dump) == buttons and ("id=lock-control-right" in dump) == buttons, \
        f"{device}: the bottom corner buttons {'shown' if buttons else 'absent'}"
    assert dev.quit() == 0, "exits cleanly"
