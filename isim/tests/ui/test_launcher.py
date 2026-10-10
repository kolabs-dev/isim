"""The desktop launcher (issue #144) and the CLI that reaches a running device: the app icon the build renders, the
default control FIFO every device reads (no --control), `isim send`, `isim open` (focus a running device, or boot one;
`.apns` files become pushes), `isim openurl` without --control, `isim desktop install|uninstall` (desktop entry,
icons, MIME type) and install.sh's options."""
import os
import shutil
import subprocess
import threading
import time
from pathlib import Path

import pytest
from PIL import Image

from isimtest import ISIM, ROOT, TIMEOUT

ICONS = ROOT / "out" / "share" / "icons" / "hicolor"
APP_ID = "dev.isim.Simulator"


def until(cond, what, timeout=TIMEOUT * 3, log=None):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        v = cond()
        if v:
            return v
        time.sleep(0.05)
    raise AssertionError(f"timed out waiting for {what}" + (f"\n--- device output ---\n{log()[-4000:]}" if log else ""))


def cli(*args, env, timeout=60):
    return subprocess.run([str(ISIM), *map(str, args)], env=env, capture_output=True, text=True, timeout=timeout)


@pytest.fixture
def env(device_data, tmp_path):
    """Scratch device data and runtime dir (where the default control FIFO goes); headless."""
    run = tmp_path / "run"
    run.mkdir(mode=0o700)
    e = dict(os.environ, ISIM_DATA=str(device_data), XDG_RUNTIME_DIR=str(run), ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1",
             ISIM_SKIP_LAUNCH_SCREEN="1")
    for k in ("ISIM_CONTROL", "ISIM_CONTROL_AUTO", "ISIM_SCRIPT", "ISIM_DEVICE", "ISIM_OS_VERSION"):
        e.pop(k, None)
    return e


class Device:
    """`isim boot` started like the launcher would: no --control, no script."""

    def __init__(self, env):
        self.proc = subprocess.Popen([str(ISIM), "boot"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, errors="replace")
        self.lines = []
        threading.Thread(target=lambda: self.lines.extend(self.proc.stdout), daemon=True).start()

    def log(self):
        return "".join(self.lines)

    def stop(self):
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait(10)


@pytest.fixture
def device(env):
    d = Device(env)
    yield d
    d.stop()


def test_icons_built():
    """build.py renders the icon at every hicolor size (the small variant up to 32 px) plus the scalable SVG."""
    for s in (16, 24, 32, 48, 64, 128, 256, 512):
        png = ICONS / f"{s}x{s}" / "apps" / f"{APP_ID}.png"
        assert png.is_file(), f"{png} is missing"
        img = Image.open(png).convert("RGBA")
        assert img.size == (s, s)
        assert img.getpixel((0, 0))[3] < 64, f"{s} px: transparent corner"          # the tile's rounded corner
        assert img.getpixel((s // 2, s // 2))[3] == 255, f"{s} px: opaque middle"
    assert (ICONS / "scalable" / "apps" / f"{APP_ID}.svg").is_file()


def test_send_open_openurl_default_control(env, device, tmp_path):
    """A device started without --control reads a FIFO of its own; isim send / open / openurl find it through the
    device data, and the FIFO is gone once the device quits."""
    data = Path(env["ISIM_DATA"])
    rec = data / "Library" / "isim" / "control"
    until(rec.is_file, "the device data to record the control FIFO")
    pid, fifo = rec.read_text().split("\n")[:2]
    assert int(pid) == device.proc.pid, "the recorded pid is the device's (the CLI execs the runtime)"
    assert Path(fifo).parent == Path(env["XDG_RUNTIME_DIR"]) / "isim" and Path(fifo).is_fifo()

    shot = tmp_path / "s.png"
    until(lambda: cli("send", f"shot {shot}", env=env).returncode == 0, "isim send to reach the device", log=device.log)
    until(shot.is_file, "the screenshot sent with isim send", log=device.log)

    r = cli("open", env=env)
    assert r.returncode == 0, r.stderr
    until(lambda: "isim host: focus: no window (headless)" in device.log(), "isim open to send focus", log=device.log)

    r = cli("open", "--device", "iphonese", env=env)                  # a running device is not replaced
    assert r.returncode == 0 and "already running" in r.stderr, r.stderr

    r = cli("openurl", "https://example.com/", env=env)
    assert r.returncode == 0, r.stderr

    assert cli("send", "quit", env=env).returncode == 0
    assert device.proc.wait(TIMEOUT * 3) == 0
    assert not Path(fifo).exists(), "the device removes its default FIFO when it quits"

    r = cli("send", "home", env=env)
    assert r.returncode == 1 and "no device is running" in r.stderr
    r = cli("openurl", "myapp://x", env=env)
    assert r.returncode == 1 and "no device is running" in r.stderr


def test_explicit_control_is_recorded(env, tmp_path):
    """--control FIFO still works, and isim send finds that FIFO too."""
    fifo = tmp_path / "ctl"
    p = subprocess.Popen([str(ISIM), "boot", "--control", str(fifo)], env=env, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)
    try:
        rec = Path(env["ISIM_DATA"]) / "Library" / "isim" / "control"
        until(lambda: rec.is_file() and rec.read_text().split("\n")[1] == str(fifo), "the given FIFO to be recorded")
        until(lambda: cli("send", "quit", env=env).returncode == 0, "isim send through --control's FIFO")
        assert p.wait(TIMEOUT * 3) == 0
        assert fifo.is_fifo(), "a FIFO given with --control is left in place"
    finally:
        if p.poll() is None:
            p.kill()


def test_open_boots_and_queues_apns(env, tmp_path):
    """With no device running, isim open boots one (with the device options); an .apns file is queued for it."""
    payload = tmp_path / "hello.apns"
    payload.write_text('{"Simulator Target Bundle": "dev.example.app", "aps": {"alert": "Hi"}}')
    r = cli("open", "--device", "iphonese", "--script", "wait 0.2; quit", str(payload), env=env, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "queued for dev.example.app" in r.stdout
    assert (Path(env["ISIM_DATA"]) / "Library" / "isim" / "shell.pid").is_file(), "isim open booted the device"
    r = cli("open", str(tmp_path / "App.app"), env=env)
    assert r.returncode == 2 and "only .apns" in r.stderr


def test_desktop_install_uninstall(tmp_path):
    """isim desktop install writes a valid desktop entry (Exec through this isim, the app id, actions, the .apns MIME
    type), the icons and the MIME package into XDG_DATA_HOME; uninstall removes them."""
    share = tmp_path / "share"
    e = dict(os.environ, HOME=str(tmp_path / "home"), XDG_DATA_HOME=str(share), ISIM_INSTALL_DIR=str(tmp_path / "lib"))
    r = cli("desktop", "install", env=e)
    assert r.returncode == 0, r.stderr
    entry = share / "applications" / f"{APP_ID}.desktop"
    text = entry.read_text()
    exe = (ROOT / "out" / "bin" / "isim").resolve()
    for line in (f'Exec="{exe}" open %f', f"TryExec={exe}", f"Icon={APP_ID}", f"StartupWMClass={APP_ID}",
                 "MimeType=application/x-apns+json;", "Name=isim Simulator", "Actions=iphone15;iphonese;ipadair11;",
                 "[Desktop Action iphonese]", f'Exec="{exe}" open --device iphonese'):
        assert line in text.splitlines(), f"{line!r} in the desktop entry:\n{text}"
    for s in (16, 48, 256, 512):
        assert (share / "icons" / "hicolor" / f"{s}x{s}" / "apps" / f"{APP_ID}.png").is_file()
    assert (share / "icons" / "hicolor" / "scalable" / "apps" / f"{APP_ID}.svg").is_file()
    assert '<glob pattern="*.apns"/>' in (share / "mime" / "packages" / f"{APP_ID}.xml").read_text()
    if shutil.which("desktop-file-validate"):
        v = subprocess.run(["desktop-file-validate", str(entry)], capture_output=True, text=True)
        assert v.returncode == 0, v.stdout + v.stderr

    r = cli("desktop", "uninstall", env=e)
    assert r.returncode == 0, r.stderr
    assert not entry.exists() and not (share / "mime" / "packages" / f"{APP_ID}.xml").exists()
    assert not list((share / "icons" / "hicolor").glob(f"*/apps/{APP_ID}.*"))
    assert cli("desktop", "bogus", env=e).returncode == 2


def test_desktop_install_release_uses_current(tmp_path):
    """From an installed release (ISIM_INSTALL_DIR/<version>/bin/isim) the entry runs isim through `current`, so isim
    update / isim use keep it working."""
    lib = tmp_path / "lib"
    rel = lib / "9.9.9"
    (rel / "bin").mkdir(parents=True)
    shutil.copy(ISIM, rel / "bin" / "isim")
    shutil.copytree(ROOT / "out" / "share" / "icons", rel / "share" / "icons")
    (lib / "current").symlink_to("9.9.9")
    share = tmp_path / "share"
    e = dict(os.environ, HOME=str(tmp_path / "home"), XDG_DATA_HOME=str(share), ISIM_INSTALL_DIR=str(lib))
    r = subprocess.run([str(rel / "bin" / "isim"), "desktop", "install"], env=e, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    text = (share / "applications" / f"{APP_ID}.desktop").read_text()
    assert f'Exec="{lib}/current/bin/isim" open %f' in text.splitlines(), text


def test_install_sh_options():
    """install.sh rejects unknown options before downloading anything (--no-desktop and a version are accepted)."""
    r = subprocess.run(["bash", str(ROOT.parent / "install.sh"), "--bogus"], capture_output=True, text=True, timeout=30)
    assert r.returncode == 2 and "unknown option --bogus" in r.stderr
