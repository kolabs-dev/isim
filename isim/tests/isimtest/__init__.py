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

import errno
import fcntl
import os
import re
import shutil
import signal
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


def screen_frames(text: str) -> dict[str, tuple[float, float, float, float]]:
    """{accessibility id: (x, y, w, h)} in screen points from a view-tree dump (App.view_dump()): frames are summed up
    the superview chain, and scroll views' "text=offset Y" moves their subviews (transforms are not applied). The
    first view with an id wins."""
    res, stack = {}, []                                # (depth, abs x, abs y, scroll offset)
    for v in parse_views(text):
        while stack and stack[-1][0] >= v.depth:
            stack.pop()
        px, py, sy = stack[-1][1:] if stack else (0, 0, 0)
        ax, ay = px + v.x, py + v.y - sy
        off = re.search(r"text=offset (-?[\d.e+-]+),", v.line)
        stack.append((v.depth, ax, ay, float(off.group(1)) if off else 0))
        if v.id and v.id not in res:
            res[v.id] = (ax, ay, v.w, v.h)
    return res


def visible_ids(text: str) -> set[str]:
    """The accessibility identifiers in a view-tree dump of views that are neither hidden themselves nor inside a
    hidden view (what `tapid` can reach)."""
    out, stack = set(), []                             # (depth, hidden)
    for v in parse_views(text):
        while stack and stack[-1][0] >= v.depth:
            stack.pop()
        hidden = v.hidden or bool(stack and stack[-1][1])
        stack.append((v.depth, hidden))
        if v.id and not hidden:
            out.add(v.id)
    return out


def visible(ident: str):
    """A wait_view condition: a visible view with accessibilityIdentifier `ident` (see visible_ids), e.g.
    app.wait_view(visible("sheet-grabber"), gone=True) waits until a dismissed sheet's views are gone or hidden."""
    return lambda text: ident in visible_ids(text)


def grep(text: str, pattern: str, before: int = 0, after: int = 0) -> str:
    """The lines of `text` matching the regex `pattern`, each with `before` / `after` lines of context (like
    grep -B / -A), joined with newlines: e.g. what a view-tree dump shows right below a view."""
    lines, out = text.splitlines(), []
    for i, line in enumerate(lines):
        if re.search(pattern, line):
            out += lines[max(0, i - before):i + after + 1]
    return "\n".join(out)


class WaitTimeout(AssertionError):
    pass


def _descendants(pid: int) -> list[int]:
    """pid and all its descendant processes (isim boot: the shell and the apps it launched)."""
    children: dict[int, list[int]] = {}
    for d in os.listdir("/proc"):
        if d.isdigit():
            try:
                stat = Path(f"/proc/{d}/stat").read_text()
                children.setdefault(int(stat.rsplit(")", 1)[1].split()[1]), []).append(int(d))
            except (OSError, IndexError, ValueError):
                pass
    out, todo = [], [pid]
    while todo:
        p = todo.pop()
        out.append(p)
        todo += children.get(p, [])
    return out


class App:
    """One headless app run on its own device data. Use as a context manager (quits and reaps the process)."""

    def __init__(self, name: str | Path | None, *, device: str | None = None, os_version: str | None = None,
                 data: Path | None = None, env: dict | None = None, args: list[str] | None = None,
                 install: list[str] = (), animations: bool = True, launch_screen: bool | str = False):
        """name: an app in out/apps, or the Path of an .app bundle. name=None boots the device (`isim boot`: the home
        screen, system UI and `launch BUNDLE_ID`) with the `install` apps (names in out/apps) installed first.
        animations=False: ISIM_ANIMATIONS=0, animations finish at once (faster, for tests that only check end
        states). launch_screen=True: show the app's launch screen (skipped by default: ISIM_SKIP_LAUNCH_SCREEN) and
        start once it has faded out; launch_screen="visible": start while it is still shown (to check it)."""
        self.launch_screen = launch_screen
        self.bundle = None if name is None else name if isinstance(name, Path) else APPS / f"{name}.app"
        assert self.bundle is None or self.bundle.is_dir(), f"{self.bundle} is not built"
        label = self.bundle.stem if self.bundle else "boot"
        # working files (control FIFO, snapshots, screenshots): next to the test's scratch device data (pytest's tmp_path,
        # kept for a failed run), else a directory of our own, removed by quit()
        self._own_tmp = data is None
        base = Path(data).parent if data else ROOT / "out"
        self.tmp = Path(tempfile.mkdtemp(prefix=f"isimtest-{label}-", dir=base))
        self.data = data or Path(os.environ.get("ISIM_DATA") or self.tmp / "data")
        if install:
            install_apps(self.data, *install)
        self.fifo = self.tmp / "control"
        os.mkfifo(self.fifo)
        # the local Game Center network (players shared by isim devices): a scratch one next to the device data, shared
        # by the devices of one test (their data directories are siblings)
        e = dict(os.environ, ISIM_DATA=str(self.data), ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1",
                 ISIM_DEVICE=device or DEFAULT_DEVICE, ISIM_SCRIPT="wait 0", ISIM_GAMECENTER=str(self.data.parent / "gamecenter"))
        e.setdefault("ISIM_DICTIONARIES", "none")           # the built-in word lists only, whatever the host has installed
        if os_version:
            e["ISIM_OS_VERSION"] = str(os_version)
        if not launch_screen:
            e["ISIM_SKIP_LAUNCH_SCREEN"] = "1"
        if not animations:
            e["ISIM_ANIMATIONS"] = "0"
        e.update(env or {})
        self._lines: list[str] = []
        self._cv = threading.Condition()
        what = ["run", str(self.bundle)] if self.bundle else ["boot"]
        self.proc = subprocess.Popen([str(ISIM), *what, "--control", str(self.fifo), *(args or [])],
                                     env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                     errors="replace")
        self._reader = threading.Thread(target=self._read, daemon=True)
        self._reader.start()
        self._ctl = self._open_control()
        self._n = 0

    def _open_control(self, timeout: float = 60):
        """The write end of the control FIFO. A plain open() blocks until the app opens the read end, forever if the app
        dies first (a crash while loading, an unresolved symbol): open without blocking and retry while the app runs."""
        end = time.monotonic() + timeout * float(os.environ.get("ISIM_WAIT_SCALE", "1"))
        while True:
            try:
                fd = os.open(self.fifo, os.O_WRONLY | os.O_NONBLOCK)
            except OSError as e:                                   # ENXIO: no reader yet
                if e.errno != errno.ENXIO:
                    raise
                status = self.proc.poll()
                if status is not None or time.monotonic() > end:
                    self._reader.join(2)
                    with self._cv:
                        tail = "\n".join(self._lines[-30:])
                    if status is None:
                        self.proc.kill()
                    what = f"exited with status {status}" if status is not None else f"did not open it within {timeout:g} s"
                    raise WaitTimeout(f"the app {what} before opening its control channel\n{tail}") from None
                time.sleep(0.02)
                continue
            fcntl.fcntl(fd, fcntl.F_SETFL, fcntl.fcntl(fd, fcntl.F_GETFL) & ~os.O_NONBLOCK)   # writes block as before
            return os.fdopen(fd, "w")

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
                    raise self._timeout(f"no {pattern!r} (x{count}) in the app log after {timeout:g} s\n"
                                      + "\n".join(self._lines[-30:]))
                self._cv.wait(min(left, 0.2))

    def _timeout(self, message: str) -> WaitTimeout:
        """A WaitTimeout that also carries every thread's stack of the still-running app processes (the runtime prints
        them on SIGRTMIN+5): shows whether the app hung (deadlock, busy loop) or was only slow."""
        if self.proc.poll() is not None or os.environ.get("ISIM_NO_STACK_DUMP"):
            return WaitTimeout(message)
        pids = []
        for pid in _descendants(self.proc.pid):             # only isim-runtime handles the signal (it kills others)
            try:
                if os.readlink(f"/proc/{pid}/exe").endswith("/isim-runtime"):
                    pids.append(pid)
            except OSError:
                pass
        with self._cv:
            start = len(self._lines)
        for pid in pids:
            try:
                os.kill(pid, signal.SIGRTMIN + 5)
            except OSError:
                pass
        end = time.monotonic() + 3
        with self._cv:
            while self._lines[start:].count("isim: ---- end of thread stacks ----") < len(pids) and time.monotonic() < end:
                self._cv.wait(0.1)
            stacks = self._lines[start:]
        if stacks:
            message += "\n---- app thread stacks at the timeout ----\n" + "\n".join(stacks[-400:])
        return WaitTimeout(message)

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
        raise self._timeout(f"no snapshot after {timeout:g} s\n" + "\n".join(self._lines[-30:]))

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
        raise self._timeout(f"no view dump after {timeout:g} s\n" + "\n".join(self._lines[-30:]))

    def wait_view(self, pattern, gone: bool = False, timeout: float = TIMEOUT, what: str | None = None) -> str:
        """Poll the view tree until the regex `pattern` matches a line of it (gone=True: until none does); return
        that view dump. For checks on `dump` output, e.g. wait_view(r"id=total text=3 items"). `pattern` can also be
        a function of the dump text (e.g. lambda d: "id=a" in d and "id=b" not in d), `what` names it in errors."""
        test = pattern if callable(pattern) else re.compile(pattern, re.M).search
        end = time.monotonic() + timeout
        while True:
            text = self.view_dump()
            if bool(test(text)) != gone:
                return text
            if time.monotonic() > end:
                raise self._timeout(f"{what or ('still' if gone else 'no') + ' ' + repr(pattern) + ' in the view tree'}"
                                  f" after {timeout:g} s\n"
                                  + "\n".join(l for l in text.splitlines() if " id=" in l or " text=" in l)[-4000:])
            time.sleep(0.05)

    def wait_dump(self, pattern: str, timeout: float = TIMEOUT) -> re.Match:
        """Send `dump` (the view tree printed into the app's output, as shell scripts used it) until the regex
        `pattern` matches output printed since this call; return the match. Under `isim boot` this form also lists the
        system UI the shell draws (lock screen, Notification and Control Center, app switcher, Dynamic Island,
        notification banners), which
        `dump views FILE` (view_dump) leaves out."""
        rx = re.compile(pattern, re.M)
        with self._cv:
            start = len(self._lines)
        end = time.monotonic() + timeout
        while True:
            self.send("dump")
            settle = min(end, time.monotonic() + 0.5)
            with self._cv:
                while True:
                    m = rx.search("\n".join(self._lines[start:]))
                    if m:
                        return m
                    left = settle - time.monotonic()
                    if left <= 0:
                        break
                    self._cv.wait(left)
            if time.monotonic() > end:
                raise self._timeout(f"no {pattern!r} in a dump after {timeout:g} s\n" + "\n".join(self._lines[-40:]))

    def wait_still(self, quiet: float = 0.4, timeout: float = TIMEOUT) -> str:
        """Wait until the view tree has not changed for `quiet` seconds (scrolling decelerated, a transition ended:
        UIKit transitions move layers, not frames, so their end shows only as their temporary views going away).
        Returns that dump."""
        end = time.monotonic() + timeout
        last, since = self.view_dump(), time.monotonic()
        while True:
            time.sleep(0.1)
            text = self.view_dump()
            if text != last:
                last, since = text, time.monotonic()
            elif time.monotonic() - since >= quiet:
                return text
            if time.monotonic() > end:
                raise self._timeout(f"the view tree still changes after {timeout:g} s")

    def wait_tap_id(self, ident: str, timeout: float = TIMEOUT) -> "App":
        """Wait until a visible view with accessibilityIdentifier `ident` is in the view tree, then `tapid` it (for
        views the accessibility snapshot does not list, e.g. some SwiftUI controls). If the app reports the view not
        tappable yet ("no visible view", e.g. while a hidden ancestor or a transition covers it), tap again."""
        end = time.monotonic() + timeout
        self.wait_view(rf"^(?!.* hidden id=).* id={re.escape(ident)}( text=.*| ax=.*)?$", timeout=timeout)
        miss = rf"no visible view with accessibilityIdentifier '{re.escape(ident)}'"
        while True:
            before = self.count(miss)
            self.tap_id(ident)
            self.view_dump()                        # handled after the tap: a miss is logged by then
            time.sleep(0.03)
            if self.count(miss) == before:
                return self
            if time.monotonic() > end:
                raise self._timeout(f"{ident!r} is not tappable after {timeout:g} s")
            time.sleep(0.1)

    def count(self, pattern: str) -> int:
        """How many lines of the app's output so far match the regex `pattern`."""
        rx = re.compile(pattern)
        with self._cv:
            return sum(1 for line in self._lines if rx.search(line))

    def has(self, pattern: str) -> bool:
        """Whether the regex `pattern` (multiline: ^ and $ match at line ends) occurs in the output so far."""
        return re.search(pattern, self.log, re.M) is not None

    def between(self, start: str, end: str) -> str:
        """The output from the first line matching `start` through the next line matching `end` (sed -n /a/,/b/p)."""
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
        """Wait for the process to end by itself (an app that quits); return its exit code."""
        try:
            self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            raise self._timeout(f"still running after {timeout:g} s\n" + "\n".join(self._lines[-30:]))
        self._reader.join(5)
        return self.proc.returncode

    OPEN_ANIMATION = 0.5                       # runtime/shell.inc: an app opens in 0.5 s; touches are dropped meanwhile

    def wait_opened(self, app: str, count: int = 1) -> "App":
        """Under `isim boot`: wait until the shell has launched (or resumed) APP.app and its 0.5 s open animation is
        over, so touches reach the app (and the swipe-up-to-go-home gesture works)."""
        self.wait_log(rf"isim shell: (launched .*/|resumed ){re.escape(app)}\.app", count=count)
        return self.sleep(self.OPEN_ANIMATION + 0.05)

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
                raise self._timeout(f"{'still' if gone else 'no'} element {what} after {timeout:g} s")
            time.sleep(0.05)

    def wait_until(self, condition, timeout: float = TIMEOUT, what: str = "condition", poll: float = 0.05):
        """Poll `condition()` (e.g. a lambda reading snapshot() or views()) until it returns a truthy value."""
        end = time.monotonic() + timeout
        while True:
            v = condition()
            if v:
                return v
            if time.monotonic() > end:
                raise self._timeout(f"{what} not met after {timeout:g} s\n" + "\n".join(self._lines[-20:]))
            time.sleep(poll)

    def screenshot(self, name: str = "shot"):
        """A screenshot as a PIL image (points = pixels: ISIM_SHOT_SCALE=1)."""
        from PIL import Image
        self._n += 1
        path = self.tmp / f"{name}-{self._n}.png"
        self.send(f"shot {path}")
        self.wait_log(re.escape(f"screenshot {path}"), timeout=TIMEOUT)
        return Image.open(path).convert("RGB")

    def wait_shot_still(self, timeout: float = TIMEOUT):
        """Take screenshots until two in a row are the same (an animation of what the shell draws, which the view
        tree does not show, has ended) and return the last."""
        last = self.screenshot()
        end = time.monotonic() + timeout
        while True:
            img = self.screenshot()
            if img.tobytes() == last.tobytes():
                return img
            if time.monotonic() > end:
                raise self._timeout(f"the screen still changes after {timeout:g} s")
            last = img

    def wait_shot(self, pred, what: str = "screenshot condition", timeout: float = TIMEOUT):
        """Take screenshots until pred(image) holds and return that image (pixels that change after an action)."""
        return self.wait_until(lambda: img if pred(img := self.screenshot()) else None, timeout, what)

    def shot_during(self, mid, done, what: str = "a frame part-way through the animation", timeout: float = TIMEOUT):
        """Take screenshots right after starting an animation until one shows it part-way (mid(image)) and return
        that image; fail if the end state (done(image)) shows first. Mid-animation checks poll rather than sleep a
        fixed time: on a loaded machine the app renders few frames and a fixed-time sample can land past the end."""
        end = time.monotonic() + timeout
        while True:
            img = self.screenshot()
            if mid(img):
                return img
            if done is not None and done(img):
                raise WaitTimeout(f"{what}: the animation ended before a part-way frame was captured")
            if time.monotonic() > end:
                raise WaitTimeout(f"{what}: not seen after {timeout:g} s\n" + "\n".join(self._lines[-20:]))

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
        if self._own_tmp:
            shutil.rmtree(self.tmp, ignore_errors=True)
        return self.proc.returncode

    def __enter__(self) -> "App":
        self.wait_log(r"isim: launching ", timeout=TIMEOUT * 3)
        if self.launch_screen == "visible":
            return self
        self.wait_for(type="window", timeout=TIMEOUT * 3)          # the app has a window on screen
        if self.find(id="launch-screen"):                          # launch_screen=True: wait until it fades out
            self.wait_log(r"isim: launch screen hidden", timeout=TIMEOUT)
        return self

    def __exit__(self, *exc):
        self.quit()


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
        e["ISIM_GAMECENTER"] = str(Path(data).parent / "gamecenter")
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
    fails = "\n".join(line for line in r.output.splitlines()[:-40] if line.startswith("FAIL"))   # those before the tail
    assert passed == total and r.returncode == 0, f"{name}: {passed}/{total} passed (exit {r.returncode})\n{fails}\n{tail}"
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


def white(c) -> bool:
    return all(v > 235 for v in c[:3])


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
    """[(start, end)] (end exclusive) of horizontal runs on row y, x0 <= x < x1, where pred((r, g, b)) holds."""
    px = img.load()
    return _runs([px[x, int(y)][:3] for x in range(int(x0), int(x1))], int(x0), pred)


def runs_y(img, x, y0, y1, pred) -> list[tuple[int, int]]:
    """[(start, end)] of vertical runs in column x, y0 <= y < y1, where pred((r, g, b)) holds."""
    px = img.load()
    return _runs([px[int(x), y][:3] for y in range(int(y0), int(y1))], int(y0), pred)


def first_y(img, x, y0, y1, pred) -> int | None:
    """The first y from y0 towards y1 (either direction) where pred((r, g, b)) holds, or None."""
    step = 1 if y1 >= y0 else -1
    for y in range(int(y0), int(y1), step):
        if pred(rgb(img, x, y)):
            return y
    return None


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


def install_apps(data: Path, *names: str):
    """`isim install` apps (names in out/apps) on the device data `data` (for App(None, ...): `isim boot`)."""
    p = subprocess.run([str(ISIM), "install", *(str(APPS / f"{n}.app") for n in names)],
                       env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True)
    assert p.returncode == 0, f"isim install {' '.join(names)}: {p.stdout}"


@contextmanager
def local_server(script: Path, log: Path, args=("0",)):
    """Run a sample's local server (`python3 server.py 0` prints "PORT <n>" when ready) and yield its port; its
    stderr (the request log) goes to `log`. `args` replace the "0" (e.g. tls_echo.py DIR). Stopped at the end."""
    import sys
    with open(log, "w") as err:
        p = subprocess.Popen([sys.executable, str(script), *map(str, args)], stdout=subprocess.PIPE, stderr=err,
                             text=True)
        try:
            line = p.stdout.readline()
            assert line.startswith("PORT "), f"{script} did not start: {line!r} {Path(log).read_text()}"
            yield int(line.split()[1])
        finally:
            p.kill()
            p.wait()
            p.stdout.close()


