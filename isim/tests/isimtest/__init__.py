"""isimtest: drive isim apps from Python tests.

An `App` runs one app headless (`isim run --headless --control FIFO`) on scratch device data and talks to it
through the live control channel: every script command (docs/SCRIPTING.md) is a method or `app.send(...)`. Instead
of fixed sleeps, tests wait for conditions: an element in the accessibility snapshot (`dump FILE`, the format
XCUITest uses), a line in the app's log, or the process exiting.

    with App("HelloNavigation") as app:
        app.wait_for(id="book-3").tap()
        app.wait_for(label="Details of book 3")
        assert app.wait_log("detail 3 appears")
"""
from __future__ import annotations

import fcntl
import os
import re
import subprocess
import tempfile
import threading
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # isim/ (this file: isim/tests/isimtest/__init__.py)
ISIM = ROOT / "out" / "bin" / "isim"
APPS = ROOT / "out" / "apps"
DEFAULT_DEVICE = os.environ.get("ISIM_TEST_DEVICE", "iphone16pro")
TIMEOUT = float(os.environ.get("ISIM_TEST_WAIT", "10")) * float(os.environ.get("ISIM_WAIT_SCALE", "1"))


@dataclass
class Element:
    """One line of the accessibility snapshot (see frameworks/UIKit/UIAXSnapshot.m)."""
    depth: int
    type: str
    x: float
    y: float
    w: float
    h: float
    id: str
    label: str
    value: str
    placeholder: str
    flags: str
    app: "App | None" = None

    @property
    def center(self) -> tuple[float, float]:
        return self.x + self.w / 2, self.y + self.h / 2

    @property
    def enabled(self) -> bool:
        return "e" in self.flags

    def tap(self) -> "Element":
        x, y = self.center
        self.app.send(f"tap {x:.1f} {y:.1f}")
        return self


def _unescape(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"t": "\t", "n": "\n", "r": "\r"}.get(m.group(1), m.group(1)), s)


def parse_snapshot(text: str) -> list[Element]:
    out = []
    for line in text.splitlines():
        f = line.split("\t")
        if len(f) < 11:
            f += [""] * (11 - len(f))
        try:
            out.append(Element(int(f[0]), f[1], float(f[2]), float(f[3]), float(f[4]), float(f[5]),
                               *(_unescape(x) for x in f[6:10]), f[10]))
        except ValueError:
            continue
    return out


@dataclass
class View:
    """One line of the view-tree dump (`dump views FILE`): class, frame in its superview, id and text."""
    depth: int
    cls: str
    x: float
    y: float
    w: float
    h: float
    hidden: bool
    id: str
    text: str
    line: str


_VIEW_RX = re.compile(r"^( *)(\S+) \(([-\d.e]+) ([-\d.e]+); ([-\d.e]+) x ([-\d.e]+)\)(.*)$")


def parse_views(text: str) -> list[View]:
    out = []
    for line in text.splitlines():
        m = _VIEW_RX.match(line)
        if not m:
            continue
        rest = m.group(7)
        ident = re.search(r" id=(\S+)", rest)
        txt = re.search(r" text=(.*?)(?: ax=\"|$)", rest)
        out.append(View(len(m.group(1)) // 2, m.group(2), *(float(m.group(i)) for i in range(3, 7)),
                        " hidden" in rest.split(" id=")[0], ident.group(1) if ident else "",
                        txt.group(1) if txt else "", line))
    return out


class WaitTimeout(AssertionError):
    pass


class App:
    """One headless app run on its own device data. Use as a context manager (quits and reaps the process)."""

    def __init__(self, name: str | Path | None, *, device: str | None = None, os_version: str | None = None,
                 data: Path | None = None, env: dict | None = None, args: list[str] | None = None,
                 install: list[str] = ()):
        """name: an app in out/apps, or the Path of an .app bundle. name=None boots the device (`isim boot`: the home
        screen, system UI and `launch BUNDLE_ID`) with the `install` apps (names in out/apps) installed first."""
        self.bundle = None if name is None else name if isinstance(name, Path) else APPS / f"{name}.app"
        assert self.bundle is None or self.bundle.is_dir(), f"{self.bundle} is not built"
        label = self.bundle.stem if self.bundle else "boot"
        self.tmp = Path(tempfile.mkdtemp(prefix=f"isimtest-{label}-", dir=ROOT / "out"))
        self.data = data or Path(os.environ.get("ISIM_DATA") or self.tmp / "data")
        if install:
            install_apps(self.data, *install)
        self.fifo = self.tmp / "control"
        os.mkfifo(self.fifo)
        e = dict(os.environ, ISIM_DATA=str(self.data), ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1",
                 ISIM_DEVICE=device or DEFAULT_DEVICE, ISIM_SCRIPT="wait 0")
        if os_version:
            e["ISIM_OS_VERSION"] = str(os_version)
        e.update(env or {})
        self._lines: list[str] = []
        self._cv = threading.Condition()
        what = ["run", str(self.bundle)] if self.bundle else ["boot"]
        self.proc = subprocess.Popen([str(ISIM), *what, "--control", str(self.fifo), *(args or [])],
                                     env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                     errors="replace")
        self._reader = threading.Thread(target=self._read, daemon=True)
        self._reader.start()
        self._ctl = open(self.fifo, "w")
        self._n = 0

    # ---- process output ----
    def _read(self):
        for line in self.proc.stdout:
            with self._cv:
                self._lines.append(line.rstrip("\n"))
                self._cv.notify_all()
        with self._cv:
            self._cv.notify_all()

    @property
    def log(self) -> str:
        with self._cv:
            return "\n".join(self._lines)

    def wait_log(self, pattern: str, timeout: float = TIMEOUT, count: int = 1) -> re.Match:
        """Wait until `pattern` (a regex) has appeared `count` times in the app's output; return the last match."""
        rx = re.compile(pattern, re.M)
        end = time.monotonic() + timeout
        with self._cv:
            while True:
                found = list(rx.finditer("\n".join(self._lines)))
                if len(found) >= count:
                    return found[count - 1]
                left = end - time.monotonic()
                if left <= 0 or (self.proc.poll() is not None and not self._reader.is_alive()):
                    raise WaitTimeout(f"no {pattern!r} (x{count}) in the app log after {timeout:g} s\n"
                                      + "\n".join(self._lines[-30:]))
                self._cv.wait(min(left, 0.2))

    # ---- commands ----
    def send(self, command: str) -> "App":
        self._ctl.write(command + "\n")
        self._ctl.flush()
        return self

    def tap(self, x: float, y: float) -> "App":
        return self.send(f"tap {x} {y}")

    def tap_id(self, ident: str) -> "App":
        return self.send(f"tapid {ident}")

    def tap_text(self, text: str) -> "App":
        return self.send(f"taptext {text}")

    def drag(self, x1, y1, x2, y2, seconds: float = 0.3) -> "App":
        return self.send(f"drag {x1} {y1} {x2} {y2} {seconds}")

    def type(self, text: str) -> "App":
        return self.send(f"type {text}")

    def sleep(self, seconds: float) -> "App":
        """A real pause (animations that must finish); prefer wait_for / wait_log."""
        time.sleep(seconds * float(os.environ.get("ISIM_WAIT_SCALE", "1")))
        return self

    # ---- observing the screen ----
    def snapshot(self, timeout: float = TIMEOUT) -> list[Element]:
        """The current accessibility tree (one `dump FILE` round trip)."""
        self._n += 1
        path = self.tmp / f"snap{self._n}.txt"
        self.send(f"dump {path}")
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if path.exists():
                text = path.read_text(errors="replace")
                if text.endswith("\n") or text == "":
                    els = parse_snapshot(text)
                    for el in els:
                        el.app = self
                    return els
            if self.proc.poll() is not None:
                break
            time.sleep(0.02)
        raise WaitTimeout(f"no snapshot after {timeout:g} s\n" + "\n".join(self._lines[-30:]))

    def views(self, timeout: float = TIMEOUT) -> list[View]:
        """The app's view tree (`dump views FILE`): every view with its class, frame, id and text."""
        return parse_views(self.view_dump(timeout))

    def view_dump(self, timeout: float = TIMEOUT) -> str:
        """The view tree as text, as the `dump` script command prints it (one view per line, indented)."""
        self._n += 1
        path = self.tmp / f"views{self._n}.txt"
        self.send(f"dump views {path}")
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if path.exists():
                return path.read_text(errors="replace")
            if self.proc.poll() is not None:
                break
            time.sleep(0.02)
        raise WaitTimeout(f"no view dump after {timeout:g} s\n" + "\n".join(self._lines[-30:]))

    def wait_view(self, pattern: str, gone: bool = False, timeout: float = TIMEOUT) -> str:
        """Poll the view tree until the regex `pattern` matches a line of it (gone=True: until none does); return
        that view dump. For checks on `dump` output, e.g. wait_view(r"id=total text=3 items")."""
        rx = re.compile(pattern, re.M)
        end = time.monotonic() + timeout
        while True:
            text = self.view_dump()
            if bool(rx.search(text)) != gone:
                return text
            if time.monotonic() > end:
                raise WaitTimeout(f"{'still' if gone else 'no'} {pattern!r} in the view tree after {timeout:g} s\n"
                                  + "\n".join(l for l in text.splitlines() if " id=" in l or " text=" in l)[-4000:])
            time.sleep(0.05)

    def wait_tap_id(self, ident: str, timeout: float = TIMEOUT) -> "App":
        """Wait until a visible view with accessibilityIdentifier `ident` is in the view tree, then `tapid` it (for
        views the accessibility snapshot does not list, e.g. some SwiftUI controls)."""
        self.wait_view(rf"^(?!.* hidden id=).* id={re.escape(ident)}( text=.*| ax=.*)?$", timeout=timeout)
        return self.tap_id(ident)

    def count(self, pattern: str) -> int:
        """How many lines of the app's output so far match the regex `pattern`."""
        rx = re.compile(pattern)
        with self._cv:
            return sum(1 for line in self._lines if rx.search(line))

    def find(self, *, id: str | None = None, label: str | None = None, type: str | None = None,
             snapshot: list[Element] | None = None) -> Element | None:
        for el in snapshot if snapshot is not None else self.snapshot():
            if (id is None or el.id == id) and (label is None or re.search(label, el.label)) and \
               (type is None or el.type == type):
                return el
        return None

    def wait_for(self, *, id: str | None = None, label: str | None = None, type: str | None = None,
                 gone: bool = False, timeout: float = TIMEOUT) -> Element | None:
        """Poll the snapshot until a matching element is present (or, with gone=True, absent)."""
        end = time.monotonic() + timeout
        while True:
            el = self.find(id=id, label=label, type=type)
            if (el is None) == gone:
                return el
            if time.monotonic() > end:
                what = ", ".join(f"{k}={v!r}" for k, v in (("id", id), ("label", label), ("type", type)) if v)
                raise WaitTimeout(f"{'still' if gone else 'no'} element {what} after {timeout:g} s")
            time.sleep(0.05)

    def screenshot(self, name: str = "shot"):
        """A screenshot as a PIL image (points = pixels: ISIM_SHOT_SCALE=1)."""
        from PIL import Image
        self._n += 1
        path = self.tmp / f"{name}-{self._n}.png"
        self.send(f"shot {path}")
        self.wait_log(re.escape(f"screenshot {path}"), timeout=TIMEOUT)
        return Image.open(path).convert("RGB")

    def wait_shot(self, pred, what: str = "screenshot condition", timeout: float = TIMEOUT):
        """Take screenshots until pred(image) holds and return that image (pixels that change after an action)."""
        return poll(lambda: img if pred(img := self.screenshot()) else None, what, timeout)

    # ---- lifetime ----
    def quit(self, timeout: float = 20) -> int:
        if self.proc.poll() is None:
            try:
                self.send("quit")
            except BrokenPipeError:
                pass
            try:
                self.proc.wait(timeout)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        self._reader.join(5)
        for f in (self._ctl, self.proc.stdout):
            try:
                f.close()
            except (OSError, ValueError):
                pass
        return self.proc.returncode

    def __enter__(self) -> "App":
        self.wait_log(r"isim: launching ", timeout=TIMEOUT * 3)
        try:                                   # the launch screen covers the app until it fades out
            self.wait_log(r"isim: launch screen hidden", timeout=5)
        except WaitTimeout:
            pass
        return self

    def __exit__(self, *exc):
        self.quit()


# ---- whole-run helpers ----
@dataclass
class Run:
    """Result of running an app to completion (scripted, or a self-test)."""
    returncode: int
    output: str

    def lines(self, pattern: str) -> list[str]:
        rx = re.compile(pattern)
        return [l for l in self.output.splitlines() if rx.search(l)]


def run_app(name: str, *, script: str | None = None, timeout: float = 120, data: Path | None = None,
            env: dict | None = None, args: list[str] | None = None, device: str | None = None,
            os_version: str | None = None, standalone: bool = True, executable: bool = False) -> Run:
    """Run an app (or a test binary in out/apps) until it exits; with `script`, headless with that script.
    executable=True runs the bundle's executable directly (test binaries without an Info.plist)."""
    bundle = APPS / f"{name}.app"
    assert bundle.is_dir(), f"{bundle} is not built"
    target = bundle / name if executable else bundle
    e = dict(os.environ)
    if data is not None:
        e["ISIM_DATA"] = str(data)
    if standalone:
        e["ISIM_STANDALONE"] = "1"
    if script is not None:
        e.update(ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1", ISIM_SCRIPT=script, ISIM_DEVICE=device or DEFAULT_DEVICE)
    if os_version:
        e["ISIM_OS_VERSION"] = str(os_version)
    e.update(env or {})
    p = subprocess.run([str(ISIM), "run", str(target), *(args or [])], env=e, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, errors="replace", timeout=timeout)
    return Run(p.returncode, p.stdout)


def selftest(name: str, *, timeout: float = 120, **kw) -> Run:
    """Run an in-app self-test that ends with '<what>: N/M passed'; fail with its output unless all passed."""
    r = run_app(name, timeout=timeout, **kw)
    m = list(re.finditer(r"(\d+)/(\d+) passed", r.output))
    tail = "\n".join(r.output.splitlines()[-40:])
    assert m, f"{name}: no 'N/M passed' line (exit {r.returncode})\n{tail}"
    passed, total = int(m[-1].group(1)), int(m[-1].group(2))
    assert passed == total and r.returncode == 0, f"{name}: {passed}/{total} passed (exit {r.returncode})\n{tail}"
    return r


# ---- pixels ----
def rgb(img, x: float, y: float) -> tuple[int, int, int]:
    """The colour at (x, y) in points (screenshots are taken at 1 px per point)."""
    return img.getpixel((int(x), int(y)))[:3]


def near(c, target, tolerance: int = 24) -> bool:
    return all(abs(a - b) <= tolerance for a, b in zip(c, target))


def is_red(c) -> bool:
    r, g, b = c[:3]
    return r > 180 and g < 90 and b < 90


def close(img, x: float, y: float, target, d2: float = 2500) -> bool:
    """The colour at (x, y) is within a squared RGB distance d2 of target."""
    return sum((a - b) ** 2 for a, b in zip(rgb(img, x, y), target)) < d2


def count_px(img, box, pred) -> int:
    """How many pixels in box = (x, y, w, h) satisfy pred((r, g, b))."""
    x, y, w, h = map(int, box)
    px = img.load()
    return sum(1 for j in range(y, y + h) for i in range(x, x + w) if pred(px[i, j][:3]))


def mean_rgb(img, box) -> tuple[float, float, float]:
    """The mean colour (0-255 per channel) of box = (x, y, w, h)."""
    from PIL import ImageStat
    x, y, w, h = map(int, box)
    return tuple(ImageStat.Stat(img.crop((x, y, x + w, y + h)).convert("RGB")).mean)


# ---- test helpers ----
def need_apps(*names):
    """Skip unless these apps (out/apps/NAME.app) are built."""
    missing = [n for n in names if not (APPS / f"{n}.app").is_dir()]
    if missing:
        import pytest
        pytest.skip(f"not built: {', '.join(missing)}")


@contextmanager
def exclusive(key: str):
    """Serialize tests that share files (out/test-data/<key>, out/test-shots/<key>) across xdist workers."""
    d = ROOT / "out" / "test-locks"
    d.mkdir(parents=True, exist_ok=True)
    with open(d / f"{key}.lock", "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def poll(fn, what: str, timeout: float = TIMEOUT, interval: float = 0.05):
    """Call fn() until it returns something truthy and return that (e.g. a screenshot once a pixel changed)."""
    end = time.monotonic() + timeout
    while True:
        v = fn()
        if v:
            return v
        if time.monotonic() > end:
            raise WaitTimeout(f"{what}: not after {timeout:g} s")
        time.sleep(interval)


def install_apps(data: Path, *names: str):
    """`isim install` apps (names in out/apps) on the device data `data` (for App(None, ...): `isim boot`)."""
    p = subprocess.run([str(ISIM), "install", *(str(APPS / f"{n}.app") for n in names)],
                       env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True)
    assert p.returncode == 0, f"isim install {' '.join(names)}: {p.stdout}"


@contextmanager
def local_server(script: Path, log: Path):
    """Run a sample's local server (`python3 server.py 0` prints "PORT <n>" when ready) and yield its port; its
    stderr (the request log) goes to `log`. Stopped at the end."""
    import sys
    with open(log, "w") as err:
        p = subprocess.Popen([sys.executable, str(script), "0"], stdout=subprocess.PIPE, stderr=err, text=True)
        try:
            line = p.stdout.readline()
            assert line.startswith("PORT "), f"{script} did not start: {line!r} {Path(log).read_text()}"
            yield int(line.split()[1])
        finally:
            p.kill()
            p.wait()
            p.stdout.close()


