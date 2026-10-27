#!/usr/bin/env python3
"""Small build actions that Ninja edges run (python3 buildlib/act.py ACTION ...). Every action leaves an output's
modification time alone when its content did not change, so Ninja (restat) skips whatever depends on it.

  sync STAMP [--tree SRC DST [--exclude GLOB]...] [--file SRC DST]...
      mirror files into place (DST paths are files or directories); remove files no longer mapped from the
      directories it owns; touch STAMP when anything changed
  keep OUT... -- CMD...     run CMD; outputs whose content is unchanged get their old modification time back
  reldeps DEPFILE -- CMD... run CMD, then make the paths in its dependency file DEPFILE relative (swiftc writes absolute)
  stamp STAMP PATH...       write STAMP (a content hash of PATHs: files, directory trees or globs) only when it changes
  tbd RUNTIME INSTALL_NAME OUT   a .tbd stub listing the exports of one of isim-runtime's host libraries
  copy SRC DST              copy when the content differs (keeps the executable bit)
  replace SRC DST OLD NEW   copy SRC to DST with every OLD replaced by NEW (a build copy of an upstream source)
"""
import fnmatch
import hashlib
import os
import shutil
import subprocess
import sys


def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def same(a, b):
    try:
        if os.path.getsize(a) != os.path.getsize(b):
            return False
    except OSError:
        return False
    return file_hash(a) == file_hash(b)


def copy_if_changed(src, dst):
    """copy src to dst unless dst already has the same content; returns True when it wrote"""
    if same(src, dst):
        if os.access(src, os.X_OK) != os.access(dst, os.X_OK):
            shutil.copymode(src, dst)
        return False
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    tmp = f"{dst}.tmp{os.getpid()}"
    shutil.copyfile(src, tmp)
    shutil.copymode(src, tmp)
    os.replace(tmp, dst)
    return True


def write_if_changed(path, text):
    data = text.encode() if isinstance(text, str) else text
    try:
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = f"{path}.tmp{os.getpid()}"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)
    return True


def tree_files(root, excludes=()):
    """relative paths of the files under root, sorted"""
    out = []
    for d, dirs, files in os.walk(root, followlinks=True):
        dirs[:] = sorted(x for x in dirs if x not in (".git", "__pycache__"))
        for f in sorted(files):
            rel = os.path.relpath(os.path.join(d, f), root)
            if not any(fnmatch.fnmatch(rel, e) or fnmatch.fnmatch(f, e) for e in excludes):
                out.append(rel)
    return out


def parse_sync(args):
    """--tree SRC DST [--exclude G]... / --file SRC DST  ->  ({dst: src}, [owned dirs])"""
    mapping, owned, i, last = {}, [], 0, None
    while i < len(args):
        a = args[i]
        if a == "--tree":
            last = [args[i + 1], args[i + 2], []]
            owned.append(last)
            i += 3
        elif a == "--exclude":
            last[2].append(args[i + 1])
            i += 2
        elif a == "--file":
            mapping[args[i + 2]] = args[i + 1]
            i += 3
        else:
            raise SystemExit(f"sync: unexpected {a}")
    trees = {}
    for src, dst, ex in owned:
        for rel in tree_files(src, ex):
            trees[os.path.join(dst, rel)] = os.path.join(src, rel)
    trees.update(mapping)                                   # single files override tree entries
    return trees, [d for _, d, _ in owned]


def cmd_sync(args):
    stamp, rest = args[0], args[1:]
    mapping, owned = parse_sync(rest)
    changed = False
    for dst, src in mapping.items():
        changed |= copy_if_changed(src, dst)
    for d in owned:                                         # files no longer mapped
        for rel in tree_files(d) if os.path.isdir(d) else ():
            p = os.path.join(d, rel)
            if p not in mapping:
                os.remove(p)
                changed = True
    if changed or not os.path.exists(stamp):
        os.makedirs(os.path.dirname(stamp), exist_ok=True)
        with open(stamp, "w"):
            pass
    return 0


def cmd_keep(args):
    i = args.index("--")
    outs, cmd = args[:i], args[i + 1:]
    before = {}
    for o in outs:
        if os.path.isfile(o):
            st = os.stat(o)
            before[o] = (file_hash(o), st.st_atime_ns, st.st_mtime_ns)
    rc = subprocess.call(cmd)
    if rc == 0:
        for o, (h, at, mt) in before.items():
            if os.path.isfile(o) and file_hash(o) == h:
                os.utime(o, ns=(at, mt))
    return rc


def cmd_reldeps(args):
    """run a command, then make the paths in its dependency file relative to the isim directory (where Ninja runs):
    swiftc writes absolute ones, which Ninja would take for files no edge makes, so a header synced into the SDK in
    the same build would not make the compile dirty until the next build (issue #608)"""
    i = args.index("--")
    depfile, cmd = args[0], args[i + 1:]
    rc = subprocess.call(cmd)
    if rc == 0 and os.path.isfile(depfile):
        with open(depfile) as f:
            text = f.read()
        rel = text.replace(os.getcwd() + os.sep, "")
        if rel != text:
            with open(depfile, "w") as f:
                f.write(rel)
    return rc


def tree_hash(paths):
    h = hashlib.sha256()
    for p in paths:
        if os.path.isdir(p):
            for rel in tree_files(p):
                h.update(f"{p}/{rel}\0{file_hash(os.path.join(p, rel))}\0".encode())
        elif os.path.isfile(p):
            h.update(f"{p}\0{file_hash(p)}\0".encode())
        else:
            h.update(f"{p}\0missing\0".encode())
    return h.hexdigest()


def swift_module_api(lib, iface):
    """what apps compile against in each Name.swiftmodule of lib: its printed public interface (iface/Name.swiftinterface)
    when it has one (library evolution), else the binary module, which changes with any edit to the module"""
    import glob
    out = []
    for d in sorted(glob.glob(f"{lib}/*.swiftmodule")):
        i = os.path.join(iface, os.path.basename(d)[:-len(".swiftmodule")] + ".swiftinterface")
        out += [i] if os.path.isfile(i) else sorted(glob.glob(f"{d}/*.swiftmodule")) + sorted(glob.glob(f"{d}/*.swiftinterface"))
    return out


def cmd_stamp(args):
    """a hash of files (paths, globs, or swift-api:LIB:IFACE, see swift_module_api), rewritten only when it changes"""
    import glob
    paths = []
    for a in args[1:]:
        if a.startswith("swift-api:"):
            paths += swift_module_api(*a.split(":")[1:3])
        else:
            paths += sorted(glob.glob(a)) if "*" in a else [a]
    write_if_changed(args[0], tree_hash(paths) + "\n")
    return 0


TBD = """--- !tapi-tbd
# GENERATED by isim/build.py from isim-runtime's host tables. Not an Apple SDK file.
tbd-version:     4
targets:         [ x86_64-ios-simulator ]
install-name:    '{name}'
exports:
  - targets:     [ x86_64-ios-simulator ]
    symbols:     [ {syms} ]
...
"""


def cmd_tbd(args):
    runtime, name, out = args
    lines = subprocess.run([runtime, "--print-exports", name], check=True, capture_output=True, text=True).stdout
    syms = ", ".join(l.split()[0] for l in lines.splitlines() if l.strip())
    write_if_changed(out, TBD.format(name=name, syms=syms))
    return 0


def cmd_replace(args):
    src, dst, pairs = args[0], args[1], args[2:]
    with open(src, encoding="utf-8") as f:
        text = f.read()
    for old, new in zip(pairs[::2], pairs[1::2]):
        text = text.replace(old, new)
    write_if_changed(dst, text)
    return 0


def main(argv):
    actions = {"sync": cmd_sync, "keep": cmd_keep, "reldeps": cmd_reldeps, "stamp": cmd_stamp, "tbd": cmd_tbd,
               "copy": lambda a: (copy_if_changed(a[0], a[1]), 0)[1], "replace": cmd_replace}
    if not argv or argv[0] not in actions:
        print(__doc__)
        return 2
    return actions[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
