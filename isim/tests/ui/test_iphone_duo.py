"""iPhone Duo (issue #115): the preset is the cover display (466 x 678 pt, iOS 27.1 and later, a status bar strip down
the right edge); script `fold open|closed` switches to the inner display (951 x 669 pt) and back. Apps resize through
UIKit's size transition (regular x regular on the inner display), so does the home screen; apps linked against an Apple
SDK older than iOS 27.1 keep the cover's size, letterboxed with black borders."""
import os
import re
import shutil
import struct
import subprocess

from isimtest import APPS, ISIM, count_px, need_apps, rgb

OS = "27.1"
COVER, INNER = (466, 678), (951, 669)
ROTATION = "dev.isim.samples.HelloRotation"


def sized(app, size):
    return app.wait_until(lambda: (lambda s: s if s.size == size else None)(app.screenshot()),
                          what=f"a {size[0]}x{size[1]} screenshot")


def test_duo_pairing(tmp_path):
    """Like Xcode: iPhone Duo needs iOS 27.1; isim devices lists it."""
    need_apps("HelloRotation")
    e = dict(os.environ, ISIM_DATA=str(tmp_path), ISIM_HEADLESS="1", ISIM_SCRIPT="quit")
    e.pop("ISIM_OS_VERSION", None)
    p = subprocess.run([str(ISIM), "run", str(APPS / "HelloRotation.app"), "--device", "iphoneduo", "--os", "27"], env=e,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    assert p.returncode == 2 and "iPhone Duo requires iOS 27.1 or later" in p.stdout, p.stdout
    d = subprocess.run([str(ISIM), "devices"], env=e, stdout=subprocess.PIPE, text=True, timeout=60).stdout
    assert re.search(r"^iphoneduo +iPhone Duo +27.1$", d, re.M), d


def test_duo_fold_app(launch):
    """The app alone: the cover display, unfolded (the inner display, regular x regular) and folded again."""
    app = launch("HelloRotation", device="iphoneduo", os_version=OS)
    cover = sized(app, COVER)
    sw = 84                                                # the status bar strip on the right: the time at its top
    assert count_px(cover, (COVER[0] - sw, 8, sw, 22), lambda c: max(c) > 200 or max(c) < 60) > 20, "the time in the strip"
    app.send("fold open")
    app.wait_log(r"^will transition to 951x669")
    app.wait_log(r"^transitioned: view 951x669, safe left 0 bottom 20")
    app.wait_log(r"^traits h=2 v=2")                       # regular x regular on the inner display
    sized(app, INNER)
    app.send("fold closed")
    app.wait_log(r"^transitioned: view 466x678, safe left 0 bottom 34")
    app.wait_log(r"^traits h=1 v=2")
    sized(app, COVER)
    assert app.quit() == 0, "exits cleanly"


def old_sdk_copy(dest):
    """HelloRotation as if linked against Apple's iOS 18 SDK: a copy whose LC_BUILD_VERSION says sdk 18.0 (isim's own
    SDK says 0.0). A test fixture for the letterbox rule only; the binary is still isim's."""
    app = dest / "HelloRotation.app"
    shutil.copytree(APPS / "HelloRotation.app", app)
    exe = app / "HelloRotation"
    data = bytearray(exe.read_bytes())
    ncmds = struct.unpack_from("<I", data, 16)[0]
    off = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, off)
        if cmd == 0x32:                                    # LC_BUILD_VERSION: platform, minos, sdk
            struct.pack_into("<I", data, off + 16, 0x120000)
        off += size
    exe.write_bytes(bytes(data))
    return app


def test_duo_fold_system(launch, tmp_path):
    """Under the shell: the home screen and a resizing app take the inner display; an old-SDK app is letterboxed."""
    old = old_sdk_copy(tmp_path)
    data = tmp_path / "device"
    p = subprocess.run([str(ISIM), "install", str(old)], env=dict(os.environ, ISIM_DATA=str(data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    assert p.returncode == 0, p.stdout
    dev = launch(None, device="iphoneduo", os_version=OS, data=data)
    dev.wait_log(r"SpringBoard: page 1 of")
    dev.send("fold open")
    dev.wait_log(r"isim shell: unfolded, inner display \(951x669\)")
    dev.wait_log(r"SpringBoard\[\d+:\w+\] isim: screen 951x669 \(unfolded\)")
    sized(dev, INNER)
    dev.send(f"launch {ROTATION}")
    dev.wait_log(r"isim: launching .*HelloRotation")
    black = lambda c: max(c) < 8
    borders = lambda s: count_px(s, (4, 250, 100, 150), black) == 100 * 150 and \
        count_px(s, (INNER[0] - 104, 250, 100, 150), black) == 100 * 150
    shot = dev.wait_shot(lambda s: s.size == INNER and borders(s), "black borders left and right (letterboxed)")
    assert count_px(shot, (300, 200, 350, 250), lambda c: max(c) > 200) > 10000, "the app between them"
    assert not dev.has(r"^will transition to 951x669"), "the old-SDK app keeps the cover's size"
    dev.send("fold closed")
    dev.wait_log(r"isim shell: folded, cover display \(466x678\)")
    sized(dev, COVER)
    dev.send("fold open")                                  # unfolded while it runs: letterboxed again
    dev.wait_shot(lambda s: s.size == INNER and borders(s), "letterboxed again")
    assert not dev.has(r"^will transition to"), "the old-SDK app never resized"
    assert dev.quit() == 0, "exits cleanly"
