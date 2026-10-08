#!/usr/bin/env python3
"""Build, test and package isim.

  build.py [build] [TARGET...] [-j N] [-v] [-k]   build (default: everything); targets: runtime, sdk-c, swift,
                                                   overlays, apps, or any output path (e.g. out/apps/HelloTable.app/HelloTable)
  build.py test [PYTEST ARGS...]                   run the tests (pytest over tests/), e.g. test -k navigation
  build.py ci [build|test]                         what CI runs: fetch, build, check, ABI check (build), then all
                                                   tests (test); both phases when none is given
  build.py fetch                                   fetch the pinned third-party sources (third_party/)
  build.py package VERSION                         package a release into dist/isim-VERSION-linux-x86_64.tar.gz
  build.py graph                                   only write out/build.ninja

The build is a Ninja graph (written to out/build.ninja by buildlib/): every step reruns only when its inputs changed,
and independent steps run in parallel. Ninja comes from PATH or is installed into out/pyenv with the test packages
(requirements.txt).

Environment for test: ISIM_TEST_JOBS (parallel workers; default half the CPUs, 2-16; 1 = one at a time),
ISIM_TEST_RETRY=0 (no rerun of failed tests; by default a failure is rerun once and reported as flaky if it then
passes), OS_MATRIX=1 (also run the os_matrix tests under iOS 17, 18, 26 and 27)."""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ROOT)
VENV = os.path.join(ROOT, "out", "pyenv")
REQ = os.path.join(ROOT, "requirements.txt")
sys.path.insert(0, ROOT)


def venv():
    """out/pyenv with requirements.txt installed (re-installed when the file changes)"""
    py, stamp = os.path.join(VENV, "bin", "python"), os.path.join(VENV, "requirements.txt")
    want = open(REQ).read()
    if not os.path.exists(py) or not os.path.exists(stamp) or open(stamp).read() != want:
        print(f"build.py: installing the Python packages into {VENV}", flush=True)
        subprocess.run([sys.executable, "-m", "venv", VENV], check=True)
        subprocess.run([os.path.join(VENV, "bin", "pip"), "install", "-q", "-r", REQ], check=True)
        with open(stamp, "w") as f:
            f.write(want)
    return VENV


def ninja_binary():
    from buildlib import ninja
    exe = ninja.find_ninja(VENV)
    if not exe:
        venv()
        exe = ninja.find_ninja(VENV)
    if not exe:
        raise SystemExit("build.py: no ninja (install ninja-build, or pip install ninja)")
    return exe


def graph():
    from buildlib import graph as g
    os.chdir(ROOT)
    c = g.generate(ROOT)
    for note in c.notes:
        print(f"build.py: {note}")
    return c


def build(args, ci=False):
    jobs, verbose, keep_going, targets = None, False, False, []
    it = iter(args)
    for a in it:
        if a == "-j":
            jobs = int(next(it))
        elif a.startswith("-j"):
            jobs = int(a[2:])
        elif a == "-v":
            verbose = True
        elif a == "-k":
            keep_going = True
        else:
            targets.append(a)
    from buildlib import ninja
    exe = ninja_binary()
    state = os.path.join(ROOT, "out", "srcstate.json")
    if ci:                         # a restored build cache: unchanged sources get their recorded timestamps back
        n = ninja.restore_mtimes(REPO, state)
        print(f"build.py: {n} unchanged sources keep their cached timestamps")
    graph()
    rc = ninja.run(exe, ROOT, targets, jobs=jobs, verbose=verbose, keep_going=keep_going)
    if rc == 0 and ci:
        ninja.record_mtimes(REPO, state)
    return rc


def test(args, verbose=False):
    py = os.path.join(venv(), "bin", "python")
    jobs = os.environ.get("ISIM_TEST_JOBS")
    jobs = int(jobs) if jobs else max(2, min(16, (os.cpu_count() or 4) // 2))
    cmd = [py, "-m", "pytest", f"--basetemp={ROOT}/out/pytest", "-v" if verbose else "-q"]
    if jobs > 1:
        cmd += ["-n", str(jobs), "--dist", "loadgroup", "--maxschedchunk", "1"]
    if os.environ.get("ISIM_TEST_RETRY", "1") != "0":
        cmd += ["--reruns", "1"]
    if os.environ.get("OS_MATRIX") == "1":
        cmd.append("--os-matrix")
    return subprocess.call(cmd + args, cwd=os.path.join(ROOT, "tests"))


def ci(args):
    """CI, in two phases (separate workflow steps, so each shows its own time): `build` fetches, builds, checks that
    the optional parts exist and runs the ABI check; `test` runs every test. Runs in the isim/ci image with the
    host's Docker socket."""
    phases = [a for a in args if a in ("build", "test")] or ["build", "test"]
    if "build" in phases:
        rc = ci_build([a for a in args if a not in ("build", "test")])
        if rc:
            return rc
    if "test" in phases:
        return ci_test()
    return 0


def ci_build(args):
    subprocess.run(["git", "config", "--global", "--add", "safe.directory", "*"])
    if not os.path.isdir(os.path.join(REPO, "third_party", "swift", "stdlib")):
        fetch([])
    if subprocess.run(["docker", "image", "inspect", "swift:6.2"], capture_output=True).returncode:
        subprocess.run(["docker", "pull", "-q", "swift:6.2"], check=True)
    rc = build(args, ci=True)
    if rc:
        return rc
    # optional parts are left out quietly when a tool is missing; in CI they must exist, or their tests would be skipped
    for f in ("out/sdk/usr/lib/swift/libswiftCore.dylib", "out/sdk/usr/lib/swift/libswiftSwiftUI.dylib", "out/bin/isim-webkit",
              "out/apps/HelloSwiftUI.app/HelloSwiftUI", "out/apps/CoreDataTest.app/CoreDataTest",
              "out/apps/ObjCLiteralsTest.app/ObjCLiteralsTest"):
        if not os.path.exists(os.path.join(ROOT, f)):
            print(f"CI: {f} was not built")
            return 1
    return subprocess.call([sys.executable, "tools/abi-check.py"], cwd=ROOT)


def ci_test():
    """every test, one line per test as it finishes (progress in the CI log), then out/test-summary.md (the workflow
    adds it to the run's summary page) and an error annotation per failed test"""
    import re
    started = re.compile(r"^[\w./-]+\.py::\S+\s*$")
    xml = os.path.join(ROOT, "out", "test-results.xml")
    with open(os.path.join(ROOT, "out", "test.log"), "w") as log:
        p = subprocess.Popen([sys.executable, __file__, "test", "--ci-verbose", f"--junitxml={xml}", "-o", "junit_family=xunit1"],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=dict(os.environ, PYTHONUNBUFFERED="1"))
        for line in p.stdout:
            if started.match(line):     # pytest -v with workers prints a test's id when it starts and again with
                continue                # its result: keep only the result line
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)
        rc = p.wait()
    from buildlib import report
    report.summarize(xml, os.path.join(ROOT, "out", "test.log"), os.path.join(ROOT, "out", "test-summary.md"), REPO)
    return rc


def fetch(args):
    from buildlib import fetch as f
    return f.fetch(os.path.join(REPO, "third_party"))


def package(args):
    from buildlib import package as p
    if len(args) != 1:
        raise SystemExit("usage: build.py package VERSION")
    os.chdir(ROOT)
    return p.package(ROOT, args[0], graph())


def main(argv):
    cmds = {"build": build, "test": lambda a: test([x for x in a if x != "--ci-verbose"], "--ci-verbose" in a), "ci": ci, "fetch": fetch, "package": package,
            "graph": lambda a: (graph(), 0)[1]}
    if argv and argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    if argv and argv[0] in cmds:
        return cmds[argv[0]](argv[1:])
    return build(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
