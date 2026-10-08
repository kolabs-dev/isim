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

import os
import re
import subprocess
import tempfile
import threading
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # isim/
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


class WaitTimeout(AssertionError):
    pass


class App:
    """One headless app run on its own device data. Use as a context manager (quits and reaps the process)."""

    def __init__(self, name: str, *, device: str | None = None, os_version: str | None = None,
                 data: Path | None = None, env: dict | None = None, args: list[str] | None = None):
        self.bundle = APPS / f"{name}.app"
        assert self.bundle.is_dir(), f"{self.bundle} is not built"
        self.tmp = Path(tempfile.mkdtemp(prefix=f"isimtest-{name}-", dir=ROOT / "out"))
        self.data = data or Path(os.environ.get("ISIM_DATA") or self.tmp / "data")
        self.fifo = self.tmp / "control"
        os.mkfifo(self.fifo)
        e = dict(os.environ, ISIM_DATA=str(self.data), ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1",
                 ISIM_DEVICE=device or DEFAULT_DEVICE, ISIM_SCRIPT="wait 0")
        if os_version:
            e["ISIM_OS_VERSION"] = str(os_version)
        e.update(env or {})
        self._lines: list[str] = []
        self._cv = threading.Condition()
        self.proc = subprocess.Popen([str(ISIM), "run", str(self.bundle), "--control", str(self.fifo), *(args or [])],
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
        try:                                   # the launch screen covers the app until it fades out
            self.wait_log(r"isim: launch screen hidden", timeout=5)
        except WaitTimeout:
            pass
        return self

    def __exit__(self, *exc):
        self.quit()
