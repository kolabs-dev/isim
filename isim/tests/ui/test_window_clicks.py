"""The simulator window's controls clicked with a real mouse (issue #142), on every device preset and every iOS version
it runs: the toolbar, the bezel's hardware buttons, the device menu and its restart dialog, and the More menu's forms.

Unlike test_window.py (script commands, headless), each device here has a real window on a virtual X display (Xvfb)
and is started like `isim boot` from a terminal: no launch script. Clicks and typing are X input events (XTest:
tests/fixtures/xinput), so they go through SDL's event loop, the chrome's hit testing and the script dispatcher exactly as
a person's clicks do. After every control the device must still run, the window must log the control's command
(`isim window: COMMAND`) and nothing may have reached the dispatcher garbled ("bad script command"): a click on Rotate or
Lock used to crash a device started without a script.

The iOS version: --os (CI's per-version jobs), all four with OS_MATRIX=1 / --os-matrix, else 18. Devices: every preset
that runs that version. Needs Xvfb and the X11 + XTest libraries (the CI image has them); skipped without them.
"""
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from isimtest import App, ROOT, TIMEOUT, need_apps

pytestmark = pytest.mark.os_matrix
XINPUT_SRC = Path(__file__).resolve().parent.parent / "fixtures" / "xinput" / "xinput.c"
VERSIONS = ("17", "18", "26", "27")


def presets():
    """[(device id, first iOS major it runs)] from isim-runtime --list-devices"""
    exe = ROOT / "out" / "bin" / "isim-runtime"
    if not exe.exists():
        return []
    out = subprocess.run([str(exe), "--list-devices"], capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines()[1:]:
        parts = line.split()
        versions = re.findall(r"\b(\d+)\.\d+\b", line)
        if parts and versions:
            rows.append((parts[0], int(versions[0])))
    return rows


def pytest_generate_tests(metafunc):
    if "case" not in metafunc.fixturenames:
        return
    opt = metafunc.config.getoption("--os")
    versions = [str(opt).split(".")[0]] if opt else list(VERSIONS) if metafunc.config.getoption("--os-matrix") else ["18"]
    cases = [(d, v) for v in versions for d, first in presets() if int(v) >= first]
    metafunc.parametrize("case", cases, ids=[f"{d}-ios{v}" for d, v in cases])


@pytest.fixture(scope="session")
def xinput(tmp_path_factory):
    if not shutil.which("Xvfb"):
        pytest.skip("Xvfb is not installed (a virtual X display for the window)")
    exe = tmp_path_factory.mktemp("xinput") / "xinput"
    r = subprocess.run(["cc", "-O1", "-o", str(exe), str(XINPUT_SRC), "-lX11", "-lXtst"], capture_output=True, text=True)
    if r.returncode:
        pytest.skip(f"cannot build the X input helper (X11 / XTest headers): {r.stderr[-300:]}")
    return exe


@pytest.fixture
def display(xinput):
    """a virtual X display of this test's own (one window on it)"""
    r, w = os.pipe()
    p = subprocess.Popen(["Xvfb", "-displayfd", str(w), "-screen", "0", "1800x1500x24", "-nolisten", "tcp"],
                         pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    num = b""
    with os.fdopen(r, "rb") as f:
        while not num.endswith(b"\n"):
            c = f.read(1)
            if not c:
                break
            num += c
    if not num.strip():
        p.kill()
        pytest.skip("Xvfb did not start")
    yield f":{num.decode().strip()}"
    p.terminate()
    p.wait(10)


class Window:
    """a windowed device driven with real X input"""

    def __init__(self, dev: App, xinput: Path, display: str):
        self.dev, self.xinput, self.env = dev, xinput, dict(os.environ, DISPLAY=display)

    def x(self, *args) -> str:
        r = subprocess.run([str(self.xinput), *map(str, args)], env=self.env, capture_output=True, text=True, timeout=30)
        assert r.returncode == 0, f"xinput {args}: {r.stderr}"
        return r.stdout

    def size(self) -> tuple[int, int]:
        _, _, w, h = map(int, self.x("where").split())
        return w, h

    def ready(self):
        """wait until the window is on screen at the size of its current layout (after a boot or a restart)"""
        def shown():
            more = self.controls().get("more")
            if not more:
                return False
            r = subprocess.run([str(self.xinput), "where"], env=self.env, capture_output=True, text=True)
            return r.returncode == 0 and int(r.stdout.split()[2]) == more[0] + 6 + 16
        self.dev.wait_until(shown, what="the window on screen with its toolbar")

    def controls(self) -> dict[str, tuple[int, int]]:
        """the controls shown now and their centres (window points), from `window els`"""
        n = self.dev.count(r"isim window: controls")
        self.dev.send("window els")
        line = self.dev.wait_log(r"isim window: controls(.*)", count=n + 1).group(1)
        return {m.group(1): (int(m.group(2)), int(m.group(3))) for m in re.finditer(r" (\S+)@(-?\d+),(-?\d+)", line)}

    def click(self, ident: str, *expect: str, shift: bool = False):
        """click a control by its id (where it is drawn now) and wait for the commands it should log"""
        els = self.controls()
        assert ident in els, f"no control {ident!r} shown; shown: {sorted(els)}"
        clicked = rf"^isim window: click {re.escape(ident)}$"
        n, counts = self.dev.count(clicked), [self.dev.count(e) for e in expect]
        self.x("click", *els[ident], *(["shift"] if shift else []))
        self.dev.wait_log(clicked, count=n + 1)
        for e, n in zip(expect, counts):
            self.dev.wait_log(e, count=n + 1)
        self.healthy()

    def healthy(self):
        assert self.dev.proc.poll() is None, "the device stopped\n" + self.dev.log[-3000:]
        bad = re.findall(r"bad script command near.*|Segmentation fault.*|isim: crash.*|SIGSEGV.*|SIGABRT.*", self.dev.log)
        assert not bad, f"{bad[:3]}\n" + self.dev.log[-3000:]

    def state(self) -> str:
        n = self.dev.count(r"isim window: state ")
        self.dev.send("window state")
        return self.dev.wait_log(r"isim window: state (.*)", count=n + 1).group(1)

    def wait_state(self, pattern: str) -> str:
        return self.dev.wait_until(lambda: re.search(pattern, s := self.state()) and s, what=f"window state {pattern}")


def boot(tmp_path, device, version, display, install=()):
    data = tmp_path / "data"
    data.mkdir()
    shots = tmp_path / "Pictures"
    shots.mkdir()
    env = {"ISIM_HEADLESS": None, "ISIM_SCRIPT": None, "DISPLAY": display, "SDL_VIDEO_DRIVER": "x11",
           "WAYLAND_DISPLAY": None, "ISIM_MUTE": "1", "ISIM_SCREENSHOT_DIR": str(shots),
           "ISIM_NOTIFICATION_PERMISSION": "allow"}
    return App(None, data=data, device=device, os_version=version, install=list(install), env=env)


def test_every_control(case, tmp_path, xinput, display):
    """every control of the window, clicked, on one device and iOS version"""
    device, version = case
    need_apps("HelloSystem")
    with boot(tmp_path, device, version, display, install=["HelloSystem"]) as dev:
        win = Window(dev, xinput, display)
        win.ready()
        dev.wait_view(r"id=home-dock")
        s = win.state()
        assert f"device={device}" in s or device == "ipad", s
        assert f"ios={version}" in s, s

        # toolbar
        win.click("home", r"^isim window: home$")
        win.click("lock", r"^isim window: lock$")
        win.wait_state(r"locked=1")
        win.click("lock", r"^isim window: unlock$")
        win.wait_state(r"locked=0")
        win.click("rotate", r"^isim window: rotate left$")
        win.click("rotate", r"^isim window: rotate right$", shift=True)
        win.click("appearance", r"^isim window: appearance dark$")
        win.wait_state(r"appearance=dark")
        win.click("appearance", r"^isim window: appearance light$")
        win.wait_state(r"appearance=light")
        win.click("shot", r"^isim window: shot \S+\.png$", r"isim host: screenshot \S+\.png")

        # the bezel's hardware buttons (the side or top button locks; again unlocks)
        els = win.controls()
        side = "hw.top" if "hw.top" in els else "hw.side"
        win.click(side, r"^isim window: lock$")
        win.wait_state(r"locked=1")
        win.click(side, r"^isim window: unlock$")
        win.wait_state(r"locked=0")
        win.click("hw.volup", r"^isim window: volume up$")
        win.click("hw.voldown", r"^isim window: volume down$")
        if "hw.action" in els:
            win.click("hw.action", r"^isim window: actionbutton$")
        if "hw.silent" in els:
            win.click("hw.silent", r"^isim window: silent$")
        if "hw.home" in els:
            win.click("hw.home", r"^isim window: home$")

        # More
        win.click("more")
        win.click("more.shake", r"^isim window: shake$")
        win.click("more")
        win.click("more.memorywarning", r"^isim window: memorywarning$")
        win.click("more")
        win.click("more.location")
        win.click("place.2")
        win.click("loc.set", r"^isim window: location 51\.507351 -0\.127758$")
        win.wait_state(r"location=51\.507351 -0\.127758")
        win.click("more")
        win.click("more.location")
        win.click("loc.none", r"^isim window: location none$")
        win.click("more")
        win.click("more.openurl")
        win.x("type", "hellosystem://clicked")
        win.click("url.open", r"^isim window: openurl hellosystem://clicked$")
        dev.wait_log(r"HelloSystem: .*hellosystem://clicked")
        win.click("home", r"^isim window: home$")
        win.click("more")
        win.click("more.push")
        win.click("push.send", r"^isim window: push dev\.isim\.samples\.HelloSystem \S+$")
        dev.wait_log(r"SpringBoard: push \S+ for System")
        win.click("more")
        win.click("more.push")
        win.click("push.help")
        win.click("help.back")
        win.click("back")
        win.click("more")                            # closes the More menu
        assert "menu=none" in win.state()

        # device menu: bezel off and on (the window shrinks and grows back), zoom, Apply… -> Cancel
        w0, h0 = win.size()
        win.click("device")
        win.click("bezel", r"isim window: bezel off")
        dev.wait_until(lambda: win.size()[1] < h0, what="a smaller window without the bezel")
        win.click("bezel", r"isim window: bezel on")
        dev.wait_until(lambda: win.size() == (w0, h0), what="the bezel back")
        win.click("zoom.minus")
        win.click("apply", r"isim window: restart dialog")
        win.click("dialog.cancel", r"isim window: restart cancelled")
        s = win.state()
        assert "dialog=0" in s and f"ios={version}" in s, s

        # a tap on the screen goes to the device, not the chrome
        w, h = win.size()
        n = dev.count(r"isim window: click")
        win.x("click", w // 2, h // 2)
        win.healthy()
        assert dev.count(r"isim window: click") == n
        assert dev.quit() == 0


def test_restart_from_window(tmp_path, xinput, display):
    """Apply… -> Restart with real clicks: the window closes, the device boots again with the new iOS version and
    zoom, and its window works (a click on Rotate)"""
    with boot(tmp_path, "iphone15", "17", display) as dev:
        win = Window(dev, xinput, display)
        win.ready()
        win.click("device")
        win.click("os.18")
        win.click("zoom.minus")
        win.click("apply", r"isim window: restart dialog")
        win.click("dialog.restart", r"isim window: restart: device iphone15, iOS 18\.0, zoom 0\.75")
        win.wait_state(r"device=iphone15 ios=18 zoom=0\.75")
        win.ready()                                  # the new window
        win.click("rotate", r"^isim window: rotate left$")
        assert dev.quit() == 0
