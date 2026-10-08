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

    def __init__(self, name: str, *, device: str | None = None, os_version: str | None = None,
                 data: Path | None = None, env: dict | None = None, args: list[str] | None = None,
                 bundle: Path | str | None = None, animations: bool = True, launch_screen: bool = False):
        """animations=False: ISIM_ANIMATIONS=0, animations finish at once (faster, for tests that only check end
        states). launch_screen=True: show the app's launch screen (skipped by default: ISIM_SKIP_LAUNCH_SCREEN).
        `bundle` runs another bundle than out/apps/NAME.app (an .appex, a modified copy, a test fixture)."""
        self.bundle = Path(bundle) if bundle else APPS / f"{name}.app"
        assert self.bundle.exists(), f"{self.bundle} is not built"
        self._start(name, [str(ISIM), "run", str(self.bundle)], device, os_version, data, env, args, animations,
                    launch_screen)

    def _start(self, name, command, device, os_version, data, env, args, animations=True, launch_screen=False):
        self.tmp = Path(tempfile.mkdtemp(prefix=f"isimtest-{name}-", dir=ROOT / "out"))
        self.data = Path(data or os.environ.get("ISIM_DATA") or self.tmp / "data")
        self.fifo = self.tmp / "control"
        os.mkfifo(self.fifo)
        e = dict(os.environ, ISIM_DATA=str(self.data), ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1",
                 ISIM_DEVICE=device or DEFAULT_DEVICE, ISIM_SCRIPT="wait 0")
        if os_version:
            e["ISIM_OS_VERSION"] = str(os_version)
        if not launch_screen:
            e["ISIM_SKIP_LAUNCH_SCREEN"] = "1"
        if not animations:
            e["ISIM_ANIMATIONS"] = "0"
        e.update(env or {})
        self._lines: list[str] = []
        self._cv = threading.Condition()
        self.proc = subprocess.Popen([*command, "--control", str(self.fifo), *(args or [])],
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

    def count(self, pattern: str) -> int:
        """How many times `pattern` (a regex, multiline) occurs in the app's output so far."""
        return len(re.findall(pattern, self.log, re.M))

    def has(self, pattern: str) -> bool:
        return re.search(pattern, self.log, re.M) is not None

    def between(self, start: str, end: str) -> str:
        """The output from the first line matching `start` through the next line matching `end` (like sed -n /a/,/b/p)."""
        out, on = [], False
        for line in self.log.splitlines():
            if not on and re.search(start, line):
                on = True
            if on:
                out.append(line)
                if len(out) > 1 and re.search(end, line):
                    break
        return "\n".join(out)

    def wait_exit(self, timeout: float = TIMEOUT) -> int:
        """Wait for the process to end by itself (an app that quits, a scripted run); return its exit code."""
        try:
            self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            raise WaitTimeout(f"still running after {timeout:g} s\n" + "\n".join(self._lines[-30:]))
        self._reader.join(5)
        return self.proc.returncode

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

    def drag(self, x1, y1, x2, y2, seconds: float = 0.3, hold: float | None = None) -> "App":
        """drag over `seconds`; `hold` keeps the finger down that long at the end (e.g. at a home-screen edge)"""
        return self.send(f"drag {x1} {y1} {x2} {y2} {seconds}" + (f" {hold}" if hold is not None else ""))

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

    def tree(self, timeout: float = TIMEOUT) -> str:
        """The app's view tree as text (`dump views FILE`, the format the `dump` script command prints): one line per
        view, `Class (x y; w x h) [hidden] [alpha<1] [id=ID] [text=TEXT]`, indented two spaces per level."""
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

    def views(self, timeout: float = TIMEOUT) -> list[View]:
        """The app's view tree (`dump views FILE`): every view with its class, frame, id and text."""
        return parse_views(self.tree(timeout))

    def wait_tree(self, pattern: str, *, gone: bool = False, timeout: float = TIMEOUT) -> str:
        """Poll the view tree until a line matches `pattern` (a regex; or, with gone=True, none does); return the
        tree text."""
        rx = re.compile(pattern, re.M)
        end = time.monotonic() + timeout
        while True:
            text = self.tree()
            if (rx.search(text) is None) == gone:
                return text
            if time.monotonic() > end:
                raise WaitTimeout(f"{'still' if gone else 'no'} view matching {pattern!r} after {timeout:g} s\n{text}")
            time.sleep(0.05)

    def wait_view(self, ident: str, *, gone: bool = False, timeout: float = TIMEOUT) -> str:
        """Wait until the view tree has a visible view with accessibilityIdentifier `ident` (neither it nor an
        ancestor hidden; or, with gone=True, until there is none). Unlike wait_for, this finds views the accessibility
        snapshot folds into a larger element (e.g. SwiftUI controls inside list rows). Returns the tree text."""
        end = time.monotonic() + timeout
        while True:
            text = self.tree()
            if (ident in visible_ids(text)) != gone:
                return text
            if time.monotonic() > end:
                raise WaitTimeout(f"{'still' if gone else 'no'} visible view id={ident!r} after {timeout:g} s\n{text}")
            time.sleep(0.05)

    def wait_tap(self, ident: str, timeout: float = TIMEOUT) -> "App":
        """Wait for the view with accessibilityIdentifier `ident` (wait_view), then tap it (`tapid`)."""
        self.wait_view(ident, timeout=timeout)
        return self.tap_id(ident)

    def wait_settled(self, *, id: str | None = None, label: str | None = None, interval: float = 0.15,
                     timeout: float = TIMEOUT) -> Element:
        """Wait until a matching element is present and its frame stays the same across two snapshots `interval`
        seconds apart (scrolling has decelerated, an animation has ended); return it."""
        end = time.monotonic() + timeout
        last = None
        while True:
            el = self.find(id=id, label=label)
            frame = el and (el.x, el.y, el.w, el.h)
            if el and frame == last:
                return el
            if time.monotonic() > end:
                raise WaitTimeout(f"element id={id!r} label={label!r} not settled after {timeout:g} s ({frame})")
            last = frame
            time.sleep(interval)

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

    def wait_until(self, condition, timeout: float = TIMEOUT, what: str = "condition", poll: float = 0.05):
        """Poll `condition()` (e.g. a lambda reading snapshot() or views()) until it returns a truthy value."""
        end = time.monotonic() + timeout
        while True:
            v = condition()
            if v:
                return v
            if time.monotonic() > end:
                raise WaitTimeout(f"{what} not met after {timeout:g} s\n" + "\n".join(self._lines[-20:]))
            time.sleep(poll)

    def screenshot(self, name: str = "shot"):
        """A screenshot as a PIL image (points = pixels: ISIM_SHOT_SCALE=1)."""
        from PIL import Image
        self._n += 1
        path = self.tmp / f"{name}-{self._n}.png"
        self.send(f"shot {path}")
        self.wait_log(re.escape(f"screenshot {path}"), timeout=TIMEOUT)
        return Image.open(path).convert("RGB")

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
        try:
            self._ctl.close()
        except OSError:
            pass
        return self.proc.returncode

    def __enter__(self) -> "App":
        self.wait_log(r"isim: launching ", timeout=TIMEOUT * 3)
        self.wait_for(type="window", timeout=TIMEOUT * 3)          # the app has a window on screen
        if self.find(id="launch-screen"):                          # launch_screen=True: wait until it fades out
            self.wait_log(r"isim: launch screen hidden", timeout=TIMEOUT)
        return self

    def __exit__(self, *exc):
        self.quit()


class Device(App):
    """The device shell (`isim boot --headless --control FIFO`): home screen, Settings, system UI and installed apps,
    with the same API as App. `apps` (names in out/apps or bundle paths) are installed into the device data first.
    Snapshots, view trees and screenshots are of the foreground app (the home screen when no app is open).

        with Device(apps=["HelloSystem"]) as dev:
            dev.launch("dev.isim.samples.HelloSystem").wait_for(id="bump").tap()
            dev.home()
    """

    def __init__(self, *, apps=(), device: str | None = None, os_version: str | None = None,
                 data: Path | None = None, env: dict | None = None, args: list[str] | None = None,
                 animations: bool = True, launch_screen: bool = False):
        data = Path(data or os.environ.get("ISIM_DATA") or tempfile.mkdtemp(prefix="isimtest-device-", dir=ROOT / "out"))
        if apps:
            install(data, *apps)
        self.bundle = None
        self._start("device", [str(ISIM), "boot"], device, os_version, data, env, args, animations, launch_screen)

    def launch(self, bundle_id: str) -> "Device":
        """Open an installed app (the `launch` script command)."""
        return self.send(f"launch {bundle_id}")

    def home(self) -> "Device":
        return self.send("home")

    OPEN_ANIMATION = 0.5                       # runtime/shell.inc: an app opens in 0.5 s; touches are dropped meanwhile

    def wait_opened(self, app: str, count: int = 1) -> "Device":
        """Wait until the shell has launched (or resumed) APP.app and its 0.5 s open animation is over, so touches reach
        it (and the swipe-up gesture works)."""
        self.wait_log(rf"isim shell: (launched .*/|resumed ){re.escape(app)}\.app", count=count)
        return self.sleep(self.OPEN_ANIMATION + 0.05)

    def __enter__(self) -> "Device":
        self.wait_log(r"SpringBoard: \d+ app\(s\)", timeout=TIMEOUT * 3)
        return self


def install(data: Path, *apps) -> None:
    """Install apps (names in out/apps, or bundle paths) into device data, like `isim install`."""
    bundles = [str(a if "/" in str(a) else APPS / f"{a}.app") for a in apps]
    subprocess.run([str(ISIM), "install", *bundles], env=dict(os.environ, ISIM_DATA=str(data)), check=True,
                   stdout=subprocess.DEVNULL)


# ---- whole-run helpers ----
@dataclass
class Run:
    """Result of running an app to completion (scripted, or a self-test)."""
    returncode: int
    output: str
    stderr: str = ""                                   # with run_app(split_stderr=True); otherwise in output

    def lines(self, pattern: str) -> list[str]:
        rx = re.compile(pattern)
        return [l for l in self.output.splitlines() if rx.search(l)]


def run_app(name: str, *, script: str | None = None, timeout: float = 120, data: Path | None = None,
            env: dict | None = None, args: list[str] | None = None, device: str | None = None,
            os_version: str | None = None, standalone: bool = True, executable: bool = False,
            split_stderr: bool = False) -> Run:
    """Run an app (or a test binary in out/apps) until it exits; with `script`, headless with that script.
    executable=True runs the bundle's executable directly (test binaries without an Info.plist).
    split_stderr=True keeps stderr (NSLog, os_log) apart from stdout: Run.stderr."""
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
                       stderr=subprocess.PIPE if split_stderr else subprocess.STDOUT, text=True, errors="replace",
                       timeout=timeout)
    return Run(p.returncode, p.stdout, p.stderr or "")


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


def white(c) -> bool:
    return all(v > 235 for v in c[:3])


def count(img, box, pred) -> int:
    """How many pixels in box (x0, y0, x1, y1; end exclusive, in points) satisfy pred((r, g, b))."""
    x0, y0, x1, y1 = (int(v) for v in box)
    px = img.load()
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(px[x, y][:3]))


def _runs(values, start, pred):
    out, s = [], None
    for i, c in enumerate(values):
        if pred(c):
            if s is None:
                s = start + i
        elif s is not None:
            out.append((s, start + i))
            s = None
    if s is not None:
        out.append((s, start + len(values)))
    return out


def runs_x(img, y, x0, x1, pred) -> list[tuple[int, int]]:
    """[(start, end)] (end exclusive) of horizontal runs on row y where pred((r, g, b)) holds."""
    px = img.load()
    return _runs([px[x, int(y)][:3] for x in range(int(x0), int(x1))], int(x0), pred)


def runs_y(img, x, y0, y1, pred) -> list[tuple[int, int]]:
    px = img.load()
    return _runs([px[int(x), y][:3] for y in range(int(y0), int(y1))], int(y0), pred)


def first_y(img, x, y0, y1, pred) -> int | None:
    """The first y from y0 towards y1 (either direction) where pred((r, g, b)) holds, or None."""
    step = 1 if y1 >= y0 else -1
    for y in range(int(y0), int(y1), step):
        if pred(rgb(img, x, y)):
            return y
    return None


# ---- view-tree helpers ----
def visible_ids(tree) -> set[str]:
    """The accessibility identifiers of the views in a view tree that are not hidden themselves or by an ancestor
    (what `tapid` can reach)."""
    views = parse_views(tree) if isinstance(tree, str) else tree
    out, stack = set(), []                             # (depth, hidden)
    for v in views:
        while stack and stack[-1][0] >= v.depth:
            stack.pop()
        hidden = v.hidden or bool(stack and stack[-1][1])
        stack.append((v.depth, hidden))
        if v.id and not hidden:
            out.add(v.id)
    return out


def frames(tree) -> dict[str, tuple[float, float, float, float]]:
    """Screen frames {id: (x, y, w, h)} of the identified views in a view tree (App.tree() text or App.views()).
    Tree frames are relative to the superview; scroll views ('text=offset Y, ...') move their subviews. View
    transforms are not applied. The first view with an id wins."""
    views = parse_views(tree) if isinstance(tree, str) else tree
    res, stack = {}, []                                # (depth, abs x, abs y, scroll offset y)
    for v in views:
        while stack and stack[-1][0] >= v.depth:
            stack.pop()
        px, py, sy = stack[-1][1:] if stack else (0, 0, 0)
        ax, ay = px + v.x, py + v.y - sy
        off = re.match(r"offset (-?[\d.e+-]+),", v.text)
        stack.append((v.depth, ax, ay, float(off.group(1)) if off else 0))
        if v.id and v.id not in res:
            res[v.id] = (ax, ay, v.w, v.h)
    return res


# ---- test helpers ----
def need_apps(*names):
    """Skip unless these apps (out/apps/NAME.app) are built."""
    missing = [n for n in names if not (APPS / f"{n}.app").is_dir()]
    if missing:
        import pytest
        pytest.skip(f"not built: {', '.join(missing)}")


@dataclass
class Server:
    """A local helper server started by `server()`: its port, process and log file (its stderr)."""
    port: int
    proc: subprocess.Popen
    log_path: Path

    @property
    def log(self) -> str:
        return self.log_path.read_text(errors="replace") if self.log_path.exists() else ""

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.port}"


@contextmanager
def server(*command, log: Path, timeout: float = 10):
    """Run a local server (e.g. samples/HelloWeb/server.py 0) that prints "PORT <n>" on stdout once it listens;
    yield a Server; stop it at the end. Its stderr goes to `log`."""
    with open(log, "w") as err:
        proc = subprocess.Popen([str(c) for c in command], stdout=subprocess.PIPE, stderr=err, text=True, cwd=ROOT)
    try:
        port = None
        end = time.monotonic() + timeout
        while port is None and time.monotonic() < end:
            line = proc.stdout.readline()
            if not line:
                break
            m = re.match(r"PORT (\d+)", line)
            port = m and int(m.group(1))
        assert port, f"{command} did not start: {log.read_text(errors='replace')[-2000:]}"
        yield Server(port, proc, log)
    finally:
        proc.kill()
        proc.wait()


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


