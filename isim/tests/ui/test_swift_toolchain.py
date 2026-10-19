"""The Swift toolchain isim compiles with (issue #478). The SDK's Swift modules are compiled .swiftmodule files, which load
only in the compiler that built them, so `isim toolchain` picks exactly Swift 6.2.4: ISIM_SWIFT_TOOLCHAIN (a toolchain
directory), else swiftly's 6.2.4 (`isim toolchain install`), else a swiftc on PATH that is 6.2.4; another version is
refused with a message, never used. The toolchain runs on the host, so sources and products can be anywhere."""
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
