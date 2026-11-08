#!/usr/bin/env python3
"""isim crashlog: the crash reports (.ips) the device's apps wrote, like the Simulator's crash logs in
~/Library/Logs/DiagnosticReports. isim writes one when an app crashes (a signal, or an uncaught Objective-C
exception): $ISIM_DATA/Library/Logs/DiagnosticReports/<Process>-<date>.ips, Apple's two-part format (a JSON header line,
then the JSON report).

  isim crashlog [list]            the reports, newest first: index, date, process, exception
  isim crashlog show [N|FILE]     one report (default: the newest) as text, like Xcode's crash log view
  isim crashlog show ... --json   the report's JSON as written
  isim crashlog path              the folder
  isim crashlog clear             delete the reports
"""
import glob
import json
import os
import shutil
import subprocess
import sys

DATA = os.environ.get("ISIM_DATA") or os.path.expanduser("~/.local/share/isim")
DIR = os.path.join(DATA, "Library", "Logs", "DiagnosticReports")


def reports():
    return sorted(glob.glob(os.path.join(DIR, "*.ips")), key=os.path.getmtime, reverse=True)


def load(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        header = f.readline()
        body = f.read()
    return json.loads(header), json.loads(body)


def summary(body):
    e = body.get("exception", {})
    s = f"{e.get('type', '?')} ({e.get('signal', '?')})"
    reason = body.get("exceptionReason")
    if reason:
        s += f" {reason.get('name')}: {reason.get('reason')}"
    return s


HOST_DIR = os.path.dirname(os.path.realpath(__file__))     # isim-runtime and the host binaries next to this script


def host_symbols(frames, images):
    """{frame index: "function (file:line)"} for frames in isim's own host binaries that have no symbol (static
    functions of isim-runtime, which ships with debug info), resolved with addr2line; inlined calls are joined with
    " <- " (innermost first). Empty when addr2line is not installed."""
    tool = shutil.which("addr2line") or shutil.which("llvm-addr2line")
    wanted = {}
    for i, f in enumerate(frames):
        if f.get("symbol") or "imageIndex" in f:
            continue
        path = os.path.join(HOST_DIR, f.get("imageName", ""))
        if tool and f.get("imageName") and os.path.isfile(path):
            off = f.get("imageOffset", 0) - (1 if i else 0)         # a return address: the call is the byte before
            wanted.setdefault(path, []).append((i, off))
    out = {}
    for path, items in wanted.items():
        try:
            r = subprocess.run([tool, "-a", "-f", "-i", "-C", "-e", path] + [hex(o) for _, o in items],
                               capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.SubprocessError):
            continue
        groups, cur = [], None
        for line in r.stdout.splitlines():
            if line.startswith("0x"):
                cur = []
                groups.append(cur)
            elif cur is not None:
                cur.append(line.strip())
        for (i, _), g in zip(items, groups):
            pairs = [(g[k], os.path.basename(g[k + 1])) for k in range(0, len(g) - 1, 2) if g[k] != "??"]
            if pairs:
                out[i] = " <- ".join(f"{fn} ({loc})" for fn, loc in pairs)
    return out


def frame_lines(frames, images):
    out = []
    resolved = host_symbols(frames, images)
    for i, f in enumerate(frames):
        if "imageIndex" in f and f["imageIndex"] < len(images):
            img = images[f["imageIndex"]]
            name, base = img.get("name", "?"), img.get("base", 0)
        else:
            name, base = f.get("imageName", "???"), 0
        addr = base + f.get("imageOffset", 0) if base else f.get("imageOffset", 0)
        sym = f"{f['symbol']} + {f.get('symbolLocation', 0)}" if f.get("symbol") else resolved.get(i) or f"{name} + {f.get('imageOffset', 0)}"
        out.append(f"{i:<4}{name:<32}\t0x{addr:x} {sym}")
    return out


def show(path, as_json):
    header, body = load(path)
    if as_json:
        print(json.dumps(header))
        print(json.dumps(body, indent=2))
        return
    e, t = body.get("exception", {}), body.get("termination", {})
    images = body.get("usedImages", [])
    print(f"Incident Identifier: {body.get('incident', '')}")
    print(f"Hardware Model:      {body.get('modelCode', '')}")
    print(f"Process:             {body.get('procName', '')} [{body.get('pid', '')}]")
    print(f"Path:                {body.get('procPath', '')}")
    bi = body.get("bundleInfo", {})
    print(f"Identifier:          {bi.get('CFBundleIdentifier', '')}")
    print(f"Version:             {bi.get('CFBundleShortVersionString', '')} ({bi.get('CFBundleVersion', '')})")
    print(f"Parent Process:      {body.get('parentProc', '')}")
    print()
    print(f"Date/Time:           {body.get('captureTime', '')}")
    print(f"OS Version:          {body.get('osVersion', {}).get('train', '')} (isim)")
    print()
    sub = f" ({e['subtype']})" if e.get("subtype") else ""
    print(f"Exception Type:  {e.get('type', '')} ({e.get('signal', '')}){sub}")
    print(f"Exception Codes: {e.get('codes', '')}")
    print(f"Termination Reason: {t.get('namespace', '')} {t.get('code', '')} {t.get('indicator', '')}")
    asi = body.get("asi")
    if asi:
        print()
        print("Application Specific Information:")
        for lines in asi.values():
            for line in lines:
                print(line)
    if body.get("lastExceptionBacktrace"):
        print()
        print("Last Exception Backtrace:")
        print("\n".join(frame_lines(body["lastExceptionBacktrace"], images)))
    for i, th in enumerate(body.get("threads", [])):
        print()
        q = f"::  Dispatch queue: {th['queue']}" if th.get("queue") else ":"
        print(f"Thread {body.get('faultingThread', 0)} Crashed{q}" if th.get("triggered") else f"Thread {i}{q}")
        print("\n".join(frame_lines(th.get("frames", []), images)))
    print()
    print("Binary Images:")
    for img in images:
        print(f"0x{img.get('base', 0):x} - 0x{img.get('base', 0) + img.get('size', 0) - 1:x} {img.get('name', '')} x86_64 <{img.get('uuid', '').replace('-', '').lower()}> {img.get('path', '')}")


def main(argv):
    cmd = argv[0] if argv else "list"
    as_json = "--json" in argv
    args = [a for a in argv[1:] if a != "--json"]
    if cmd == "path":
        print(DIR)
    elif cmd == "list":
        rs = reports()
        if not rs:
            print(f"isim: no crash reports in {DIR}")
        for i, p in enumerate(rs, 1):
            try:
                header, body = load(p)
                print(f"{i:<3} {body.get('captureTime', '')[:19]}  {body.get('procName', '?'):<24} {summary(body)}  {os.path.basename(p)}")
            except (ValueError, OSError) as err:
                print(f"{i:<3} {os.path.basename(p)}: unreadable ({err})")
    elif cmd == "show":
        rs = reports()
        target = args[0] if args else "1"
        if target.isdigit():
            n = int(target)
            if not 1 <= n <= len(rs):
                sys.exit(f"isim: no crash report {n} ({len(rs)} in {DIR})")
            path = rs[n - 1]
        else:
            path = target if os.path.exists(target) else os.path.join(DIR, target)
            if not os.path.exists(path):
                sys.exit(f"isim: no crash report {target}")
        show(path, as_json)
    elif cmd == "clear":
        rs = reports()
        for p in rs:
            os.remove(p)
        print(f"isim: removed {len(rs)} crash report(s)")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
