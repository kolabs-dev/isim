#!/usr/bin/env python3
"""isim preview — render an app's #Preview to a PNG, like Xcode's canvas does for one preview.

  isim preview <App.app> --list                     list the app's previews (index, name, file:line)
  isim preview <App.app> [NAME|INDEX] [-o FILE.png] [--device D] [--os N] [--dark] [--wait S]
                                                    render one preview (default the first) to FILE.png

isim's PreviewsMacros plugin gives each #Preview an exported entry point, isim_preview_<hex of "file|line|name">;
this tool finds them in the app's executable and runs the app alone (headless) in preview mode (ISIM_PREVIEW): UIKit
shows the preview's view controller instead of launching the app, laid out by its traits (the device, its size that
fits or a fixed size on a grey canvas), and the screen is saved."""
import argparse
import os
import plistlib
import struct
import subprocess
import sys
import tempfile


def symbols(path):
    """The names of the symbols in a 64-bit Mach-O file (LC_SYMTAB), or of its x86_64 slice in a fat file."""
    data = open(path, "rb").read()
    off = 0
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic in (0xbebafeca, 0xcafebabe):                       # fat: the x86_64 slice
        n = struct.unpack_from(">I", data, 4)[0]
        for i in range(n):
            cpu, _, o, _, _ = struct.unpack_from(">iiIII", data, 8 + i * 20)
            if cpu == 0x01000007:
                off = o
    if struct.unpack_from("<I", data, off)[0] != 0xfeedfacf:
        sys.exit(f"isim preview: {path} is not a 64-bit Mach-O executable")
    ncmds = struct.unpack_from("<I", data, off + 16)[0]
    p = off + 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, p)
        if cmd == 0x2:                                          # LC_SYMTAB
            symoff, nsyms, stroff, _ = struct.unpack_from("<IIII", data, p + 8)
            for i in range(nsyms):
                strx = struct.unpack_from("<I", data, off + symoff + i * 16)[0]
                end = data.index(b"\0", off + stroff + strx)
                yield data[off + stroff + strx:end].decode("utf-8", "replace")
        p += size


def previews(exe):
    out = []
    for s in set(symbols(exe)):
        name = s.lstrip("_")
        if not name.startswith("isim_preview_"):
            continue
        try:
            file, line, title = bytes.fromhex(name[len("isim_preview_"):]).decode("utf-8").split("|", 2)
        except ValueError:
            continue
        out.append({"symbol": name, "file": file, "line": int(line), "name": title})
    return sorted(out, key=lambda p: (p["file"], p["line"]))


def main():
    ap = argparse.ArgumentParser(prog="isim preview", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("app")
    ap.add_argument("which", nargs="?", help="the preview's name or index (default: the first)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("-o", "--out")
    ap.add_argument("--device")
    ap.add_argument("--os")
    ap.add_argument("--dark", action="store_true")
    ap.add_argument("--wait", type=float, default=1.5, help="seconds to let the preview settle before the screenshot")
    a = ap.parse_args()
    app = a.app.rstrip("/")
    exe = app
    if os.path.isdir(app):
        exe = os.path.join(app, plistlib.load(open(os.path.join(app, "Info.plist"), "rb"))["CFBundleExecutable"])
    found = previews(exe)
    if a.list:
        for i, p in enumerate(found):
            print(f"{i}\t{p['name'] or '(unnamed)'}\t{p['file']}:{p['line']}")
        return
    if not found:
        sys.exit(f"isim preview: {app} has no #Preview")
    pick = found[0]
    if a.which is not None:
        if a.which.isdigit() and int(a.which) < len(found):
            pick = found[int(a.which)]
        else:
            named = [p for p in found if p["name"] == a.which]
            if not named:
                sys.exit(f"isim preview: no preview named {a.which!r} (isim preview {app} --list)")
            pick = named[0]
    out = os.path.abspath(a.out or f"{os.path.splitext(os.path.basename(app))[0]}-preview.png")
    env = dict(os.environ, ISIM_PREVIEW=pick["symbol"], ISIM_HEADLESS="1", ISIM_STANDALONE="1",
               ISIM_SCRIPT=f"wait {a.wait}\nshot {out}\nquit")
    if a.device:
        env["ISIM_DEVICE"] = a.device
    if a.os:
        env["ISIM_OS_VERSION"] = a.os
    if a.dark:
        env["ISIM_APPEARANCE"] = "dark"
    isim = os.path.join(os.path.dirname(os.path.abspath(__file__)), "isim")
    print(f"isim preview: {pick['name'] or '(unnamed)'} ({pick['file']}:{pick['line']}) -> {out}")
    r = subprocess.run([isim, "run", app], env=env)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit(f"isim preview: rendering failed (exit {r.returncode})")


if __name__ == "__main__":
    main()
