"""The device window on Wayland: isim 0.23.0 showed nothing there. It turned off SDL's accelerated window surface on every
video driver (to stop the X11 window from being created twice), but Wayland has no software window framebuffer in SDL,
so the window had no surface, was never drawn and never appeared. This test boots a device on a headless Weston
compositor (pixman renderer) with SDL's Wayland driver, and checks what the compositor itself shows (its screenshot):
the window, with the toolbar and the device. Needs weston and weston-screenshooter; skipped without them."""
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest
from PIL import Image

from isimtest import App

C_BAR = (34, 35, 39)            # the toolbar


@pytest.fixture
def wayland(tmp_path):
    if not (shutil.which("weston") and shutil.which("weston-screenshooter")):
        pytest.skip("weston is not installed (a headless Wayland compositor)")
    run = tmp_path / "run"
    run.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(run))
    env.pop("DISPLAY", None)
    p = subprocess.Popen(["weston", "--backend=headless", "--renderer=pixman", "--socket=isim-test", "--width=900",
                          "--height=1100", "--debug", "--idle-time=0"],
                         env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    end = time.monotonic() + 20
    while not (run / "isim-test").exists():
        if p.poll() is not None or time.monotonic() > end:
            p.kill()
            pytest.skip("weston did not start")
        time.sleep(0.05)
    yield run
    p.terminate()
    p.wait(10)


def compositor_shot(run: Path, out: Path) -> Image.Image:
    for f in out.glob("wayland-screenshot*.png"):
        f.unlink()
    env = dict(os.environ, XDG_RUNTIME_DIR=str(run), WAYLAND_DISPLAY="isim-test")
    subprocess.run(["weston-screenshooter"], cwd=out, env=env, capture_output=True, timeout=30)
    shots = sorted(out.glob("wayland-screenshot*.png"))
    assert shots, "weston-screenshooter wrote no screenshot"
    return Image.open(shots[-1]).convert("RGB")


def test_window_shows_on_wayland(tmp_path, wayland):
    data = tmp_path / "data"
    data.mkdir()
    env = {"ISIM_HEADLESS": None, "ISIM_SCRIPT": None, "DISPLAY": None, "XDG_RUNTIME_DIR": str(wayland),
           "WAYLAND_DISPLAY": "isim-test", "SDL_VIDEO_DRIVER": "wayland", "ISIM_MUTE": "1"}
    with App(None, data=data, device="iphone15", os_version="17", env=env) as dev:
        dev.wait_view(r"id=home-dock")
        assert not dev.has(r"isim window: no window surface"), dev.log[-2000:]

        def drawn():
            img = compositor_shot(wayland, tmp_path)
            bar = sum(1 for x in range(0, img.width, 3) for y in range(0, img.height, 3)
                      if all(abs(a - b) <= 4 for a, b in zip(img.getpixel((x, y)), C_BAR)))
            return bar > 300 and img                 # the toolbar strip is on screen
        dev.wait_until(drawn, what="the window drawn on the Wayland compositor (its toolbar on screen)")
        dev.send("window tap rotate")                # still answers after being shown
        dev.wait_log(r"^isim window: rotate left$")
        assert dev.quit() == 0
