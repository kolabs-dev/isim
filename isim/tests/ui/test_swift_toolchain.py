"""The Swift toolchain isim compiles with (issue #478). The SDK's Swift modules are compiled .swiftmodule files, which load
only in the compiler that built them, so `isim toolchain` picks exactly Swift 6.2.4: ISIM_SWIFT_TOOLCHAIN (a toolchain
directory), else swiftly's 6.2.4 (`isim toolchain install`), else a swiftc on PATH that is 6.2.4; another version is
refused with a message, never used. The toolchain runs on the host, so sources and products can be anywhere.
A toolchain whose swift driver cannot run (a missing system library) is reported, and `isim cc` links with LLVM's
clang and lld, never a Swift toolchain's (Apple's fork of lld refuses to link for iOS)."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest
from isimtest import ISIM, ROOT

SDK = ROOT / "out/sdk"
VERSION = "6.2.4"


def fake_toolchain(where: Path, version: str) -> Path:
    """a directory laid out like a Swift toolchain (usr/bin/swift-frontend, swiftc) whose compiler reports `version`"""
    b = where / "usr" / "bin"
    b.mkdir(parents=True)
    (b / "swift-frontend").write_text(f'#!/bin/sh\necho "Swift version {version} (swift-{version}-RELEASE)"\n'
                                      'echo "Target: x86_64-unknown-linux-gnu"\n')
    (b / "swift-frontend").chmod(0o755)
    (b / "swiftc").symlink_to("swift-frontend")
    (b / "swift").symlink_to("swift-frontend")
    return where / "usr"


@pytest.fixture
def sandbox(tmp_path):
    """an environment with no Swift: only the programs the isim script needs on PATH, an empty swiftly"""
    bin_ = tmp_path / "bin"
    bin_.mkdir()
    for p in ("bash", "sh", "dirname", "readlink", "realpath", "head", "sed", "grep", "cat", "env", "mktemp", "rm"):
        if shutil.which(p):
            (bin_ / p).symlink_to(shutil.which(p))
    env = {k: v for k, v in os.environ.items() if not k.startswith(("SWIFTLY_", "ISIM_SWIFT_TOOLCHAIN"))}
    env.update(PATH=str(bin_), SWIFTLY_TOOLCHAINS_DIR=str(tmp_path / "swiftly"), HOME=str(tmp_path / "home"))

    def run(*args, **extra):
        p = subprocess.run([str(ISIM), *args], env={**env, **extra}, capture_output=True, text=True, timeout=60)
        return p.returncode, p.stdout + p.stderr

    def put_on_path(name, target):
        (bin_ / name).unlink(missing_ok=True)
        (bin_ / name).symlink_to(target)

    run.put_on_path = put_on_path
    return run


def test_resolution(sandbox, tmp_path):
    rc, out = sandbox("toolchain", "which")
    assert rc == 1 and "needs Swift 6.2.4" in out and "isim toolchain install" in out, out

    old = fake_toolchain(tmp_path / "old", "6.1")              # a swiftc on PATH of another version: not used, and said so
    sandbox.put_on_path("swiftc", old / "bin" / "swiftc")
    rc, out = sandbox("toolchain", "status")
    assert rc == 1 and f"not used: swiftc on PATH ({old}) is Swift version 6.1" in out, out

    on_path = fake_toolchain(tmp_path / "onpath", VERSION)
    sandbox.put_on_path("swiftc", on_path / "bin" / "swiftc")
    rc, out = sandbox("toolchain", "which")
    assert rc == 0 and out.strip() == str(on_path), out
    rc, out = sandbox("toolchain", "status")
    assert rc == 0 and out.strip() == f"Swift {VERSION}: {on_path} (swiftc on PATH)", out

    swiftly = fake_toolchain(tmp_path / "swiftly" / VERSION, VERSION)   # swiftly's comes before PATH's
    rc, out = sandbox("toolchain", "status")
    assert rc == 0 and out.strip() == f"Swift {VERSION}: {swiftly} (swiftly)", out

    mine = fake_toolchain(tmp_path / "mine", VERSION)          # ISIM_SWIFT_TOOLCHAIN first: the toolchain or its usr/
    for given in (mine.parent, mine, os.path.relpath(mine, tmp_path)):
        p = subprocess.run([str(ISIM), "toolchain", "which"], cwd=tmp_path, capture_output=True, text=True,
                           env={**os.environ, "ISIM_SWIFT_TOOLCHAIN": str(given)})
        assert p.returncode == 0 and p.stdout.strip() == str(mine), p.stdout + p.stderr     # absolute, for children

    for bad, msg in ((old.parent, "is Swift version 6.1 (swift-6.1-RELEASE); isim needs Swift 6.2.4 exactly"),
                     (tmp_path / "nothing", "is not a Swift toolchain")):
        rc, out = sandbox("toolchain", "which", ISIM_SWIFT_TOOLCHAIN=str(bad))
        assert rc == 1 and msg in out, out
        rc, out = sandbox("swiftc", "-c", "x.swift", ISIM_SWIFT_TOOLCHAIN=str(bad))   # isim swiftc uses the same choice
        assert rc == 1 and msg in out, out


def executable(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(0o755)
    return path


def test_swift_cannot_run(sandbox, tmp_path):
    """a 6.2.4 toolchain whose swift driver lacks a system library (swiftly's Ubuntu build on Arch: libncurses.so.6):
    status and install say what is missing instead of calling it ready"""
    tc = fake_toolchain(tmp_path / "swiftly" / VERSION, VERSION)
    (tc / "bin" / "swift").unlink()
    executable(tc / "bin" / "swift", f'#!/bin/sh\necho "{tc}/bin/swift: error while loading shared libraries: '
               'libncurses.so.6: cannot open shared object file: No such file or directory" >&2\nexit 127\n')
    rc, out = sandbox("toolchain", "status")
    assert rc == 1 and f"Swift {VERSION}: {tc} (swiftly)" in out, out
    assert f"{tc}/bin/swift cannot run: libncurses.so.6 is missing" in out and "libncursesw.so.6" in out, out
    rc, out = sandbox("toolchain", "install")
    assert rc == 1 and "is installed" in out and "libncurses.so.6 is missing" in out, out
    rc, out = sandbox("toolchain", "which")                    # compiling Swift does not need the driver
    assert rc == 0 and out.strip() == str(tc), out


def test_cc_skips_swift_toolchain_clang(sandbox, tmp_path):
    """isim cc links with LLVM's clang and lld: swiftly's proxies (clang, ld64.lld on PATH) and a Swift toolchain's own
    are skipped, since Apple's fork of lld refuses to link for iOS"""
    def fake(d: Path, name: str) -> Path:
        return executable(d / name, f'#!/bin/sh\necho "{name} $0 $*"\n')
    swiftly = tmp_path / "swiftly-bin"
    fake(swiftly, "swiftly")
    for tool in ("clang", "ld64.lld"):
        (swiftly / tool).symlink_to("swiftly")
    tc = fake_toolchain(tmp_path / "tc", VERSION) / "bin"
    fake(tc, "clang"), fake(tc, "ld64.lld")
    llvm = tmp_path / "llvm"
    fake(llvm, "clang"), fake(llvm, "ld64.lld")
    lone = tmp_path / "lone"                                    # a clang without lld next to it
    fake(lone, "clang")

    def path(*dirs):                                            # Swift's first, as swiftly sets PATH up
        return os.pathsep.join(map(str, (swiftly, tc, *dirs, tmp_path / "bin")))

    rc, out = sandbox("cc", "x.o", "-o", "x", PATH=path(llvm))
    assert rc == 0 and out.startswith(f"clang {llvm}/clang ") and f"--ld-path={llvm}/ld64.lld" in out, out
    rc, out = sandbox("cc", "-c", "x.m", PATH=path(llvm))       # compiles do not link
    assert rc == 0 and out.startswith(f"clang {llvm}/clang ") and "--ld-path" not in out, out
    rc, out = sandbox("cc", "x.o", PATH=path(lone, llvm))       # lld from PATH, past swiftly's
    assert rc == 0 and out.startswith(f"clang {lone}/clang ") and f"--ld-path={llvm}/ld64.lld" in out, out
    rc, out = sandbox("cc", "x.o", PATH=path(lone, llvm), CLANG=str(llvm / "clang"))   # CLANG first
    assert rc == 0 and out.startswith(f"clang {llvm}/clang ") and f"--ld-path={llvm}/ld64.lld" in out, out

    rc, out = sandbox("cc", "x.o", PATH=path())                 # only a Swift toolchain's clang: said so
    assert rc == 1 and f"the clang on PATH, {swiftly}/clang, is a Swift toolchain's" in out, out
    rc, out = sandbox("cc", "x.o", PATH=path(lone))             # only a Swift toolchain's lld
    assert rc == 1 and "linking needs LLVM's lld" in out, out


def need_toolchain():
    if not (SDK / "usr/lib/swift/SwiftUI.swiftmodule").is_dir():
        pytest.skip("the SDK's Swift overlays are not built")
    if subprocess.run([str(ISIM), "toolchain", "which"], capture_output=True).returncode:
        pytest.skip(f"no Swift {VERSION} toolchain (isim toolchain install)")


SOURCE = """import SwiftUI

struct ProbeView: View {
    @State private var count = 0
    var body: some View { Button("Count \\(count)") { count += 1 } }
}

#Preview { ProbeView() }

@main struct ProbeApp: App { var body: some Scene { WindowGroup { ProbeView() } } }
"""


def test_compile_outside_workspace():
    """isim swiftc in a folder outside the isim tree, with relative paths: SwiftUI against the SDK, #Preview expanded by
    isim's macro plugin in the host compiler"""
    need_toolchain()
    with tempfile.TemporaryDirectory(prefix="isim-swiftc-") as d:
        d = Path(d)
        (d / "Probe.swift").write_text(SOURCE)
        p = subprocess.run([str(ISIM), "swiftc", "-parse-as-library", "-module-name", "Probe", "-c", "Probe.swift",
                            "-o", "probe.o"], cwd=d, capture_output=True, text=True, timeout=600)
        assert p.returncode == 0 and (d / "probe.o").is_file(), p.stdout + p.stderr
        nm = shutil.which("llvm-nm") or shutil.which("nm")
        syms = subprocess.run([nm, "-j", str(d / "probe.o")], capture_output=True, text=True, check=True).stdout
        assert "Preview" in syms and "ProbeView" in syms, "the #Preview macro expanded"
