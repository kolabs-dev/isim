#!/usr/bin/env python3
"""Content-hash build steps: skip a step whose inputs (file contents) and command are unchanged since its last
successful run, and whose outputs exist. Unlike timestamps, this works across checkouts and restored CI caches.

  fresh.py run NAME [--in PATH...] [--out PATH...] [--key TEXT...] -- COMMAND...
      run COMMAND unless out/stamps/NAME matches; record the stamp when COMMAND succeeds
  fresh.py check NAME ... / fresh.py record NAME ...   the same test, for shell functions: exit 0 when up to date /
                                 record success (same arguments as run, without running anything)
  fresh.py hash PATH...          print the content hash of files / directories (recursive)
  fresh.py objects OBJDIR SRC... print the sources whose object (OBJDIR/<name>.o) is missing or stale, judged by the
                                 clang dependency file OBJDIR/<name>.o.d; `fresh.py objects-done OBJDIR SRC...` records them

Hashes of unchanged files are cached in out/stamps/.hashcache (by path, size and modification time).
"""
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAMPS = os.path.join(ROOT, "out", "stamps")
CACHE_PATH = os.path.join(STAMPS, ".hashcache")
_cache = None
_dirty = False


def _load():
    global _cache
    if _cache is None:
        try:
            with open(CACHE_PATH) as f:
                _cache = json.load(f)
        except (OSError, ValueError):
            _cache = {}
    return _cache


def _save():
    if _dirty:
        os.makedirs(STAMPS, exist_ok=True)
        tmp = CACHE_PATH + f".{os.getpid()}"
        with open(tmp, "w") as f:
            json.dump(_cache, f)
        os.replace(tmp, CACHE_PATH)


def file_hash(path):
    global _dirty
    st = os.stat(path)
    key = f"{st.st_size}:{st.st_mtime_ns}"
    c = _load()
    ent = c.get(path)
    if ent and ent[0] == key:
        return ent[1]
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    c[path] = [key, h.hexdigest()]
    _dirty = True
    return c[path][1]


def tree_hash(paths, keys=()):
    h = hashlib.sha256()
    for k in keys:
        h.update(b"key\0" + k.encode() + b"\0")
    for p in paths:
        p = os.path.abspath(p)
        if os.path.isdir(p):
            for d, dirs, files in os.walk(p):
                dirs[:] = sorted(x for x in dirs if x not in (".git", "__pycache__"))
                for f in sorted(files):
                    fp = os.path.join(d, f)
                    if os.path.isfile(fp):
                        h.update(os.path.relpath(fp, p).encode() + b"\0" + file_hash(fp).encode() + b"\0")
        elif os.path.isfile(p):
            h.update(p.encode() + b"\0" + file_hash(p).encode() + b"\0")
        else:
            h.update(p.encode() + b"\0missing\0")
    return h.hexdigest()


def _parse(argv):
    name, ins, outs, keys, i = argv[0], [], [], [], 1
    mode = ins
    while i < len(argv) and argv[i] != "--":
        if argv[i] == "--in":
            mode = ins
        elif argv[i] == "--out":
            mode = outs
        elif argv[i] == "--key":
            mode = keys
        else:
            mode.append(argv[i])
        i += 1
    return name, ins, outs, keys, argv[i + 1:]


def _stamp(name, ins, keys, command):
    return os.path.join(STAMPS, name), tree_hash(ins, keys + [" ".join(command)])


def _fresh(name, ins, outs, keys, command):
    stamp, h = _stamp(name, ins, keys, command)
    try:
        with open(stamp) as f:
            old = f.read().strip()
    except OSError:
        old = ""
    return old == h and all(os.path.exists(o) for o in outs), stamp, h


def _record(stamp, h):
    os.makedirs(os.path.dirname(stamp), exist_ok=True)
    with open(stamp, "w") as f:
        f.write(h + "\n")


def cmd_check(argv):
    """exit 0 when NAME is up to date (same --in contents, --key values; --out paths exist)"""
    name, ins, outs, keys, command = _parse(argv)
    ok, _, _ = _fresh(name, ins, outs, keys, command)
    _save()
    return 0 if ok else 1


def cmd_record(argv):
    name, ins, outs, keys, command = _parse(argv)
    stamp, h = _stamp(name, ins, keys, command)
    _record(stamp, h)
    _save()
    return 0


def cmd_run(argv):
    name, ins, outs, keys, command = _parse(argv)
    ok, stamp, h = _fresh(name, ins, outs, keys, command)
    _save()
    if ok:
        print(f"up to date: {name}")
        return 0
    rc = subprocess.call(command)
    if rc == 0:
        _record(stamp, h)
    return rc


def _deps(objdir, src):
    d = os.path.join(objdir, os.path.basename(src) + ".o.d")
    try:
        text = open(d).read().replace("\\\n", " ")
    except OSError:
        return None
    parts = text.split(":", 1)
    return [x for x in parts[1].split()] if len(parts) == 2 else None


def _obj_hash(objdir, src, flags):
    deps = _deps(objdir, src)
    if deps is None:
        return None
    return tree_hash([src] + deps, [flags])


def cmd_objects(argv, done=False):
    objdir, flags, srcs = argv[0], os.environ.get("FRESH_FLAGS", ""), argv[1:]
    stale = []
    for s in srcs:
        o = os.path.join(objdir, os.path.basename(s) + ".o")
        hf = o + ".hash"
        if done:
            h = _obj_hash(objdir, s, flags)
            if h:
                with open(hf, "w") as f:
                    f.write(h)
            continue
        try:
            old = open(hf).read().strip()
        except OSError:
            old = ""
        if not os.path.exists(o) or not old or old != _obj_hash(objdir, s, flags):
            stale.append(s)
    _save()
    if not done:
        print("\n".join(stale))
    return 0


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == "run":
        return cmd_run(argv[1:])
    if argv[0] == "check":
        return cmd_check(argv[1:])
    if argv[0] == "record":
        return cmd_record(argv[1:])
    if argv[0] == "hash":
        print(tree_hash(argv[1:]))
        _save()
        return 0
    if argv[0] == "objects":
        return cmd_objects(argv[1:])
    if argv[0] == "objects-done":
        return cmd_objects(argv[1:], done=True)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
