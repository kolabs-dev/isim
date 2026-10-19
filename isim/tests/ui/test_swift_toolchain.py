"""The Swift toolchain isim compiles with (issue #478). The SDK's Swift modules are compiled .swiftmodule files, which load
only in the compiler that built them, so `isim toolchain` picks exactly Swift 6.2.4: ISIM_SWIFT_TOOLCHAIN (a toolchain
directory, or `docker`), else swiftly's 6.2.4, else a swiftc on PATH that is 6.2.4, else the swift:6.2.4 Docker image;
another version is refused with a message, never used. A local toolchain compiles what the image compiles, and
`isim build` (Package.swift manifests, a package macro target) works with each."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest
from isimtest import ISIM, ROOT, exclusive, need_apps

SDK = ROOT / "out/sdk"
VERSION = "6.2.4"
IMAGE = f"swift:{VERSION}"


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
    """an environment with no Swift and no Docker: only the programs the isim script needs on PATH, an empty swiftly"""
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
        (bin_ / name).symlink_to(target)

    run.put_on_path = put_on_path
    return run


def test_resolution(sandbox, tmp_path):
    rc, out = sandbox("toolchain", "which")
    assert rc == 1 and "needs Swift 6.2.4" in out and "isim toolchain install" in out, out

    docker = tmp_path / "fake-docker"
    docker.write_text("#!/bin/sh\nexit 1\n")                  # `docker image inspect` finds no image
    docker.chmod(0o755)
    sandbox.put_on_path("docker", docker)
    rc, out = sandbox("toolchain", "which")
    assert rc == 0 and out.strip() == f"docker {VERSION} {IMAGE}", out
    rc, out = sandbox("toolchain", "status")
    assert rc == 0 and f"Docker image {IMAGE} (missing; no local Swift {VERSION} toolchain)" in out, out

    old = fake_toolchain(tmp_path / "old", "6.1")              # a swiftc on PATH of another version: not used, and said so
    sandbox.put_on_path("swiftc", old / "bin" / "swiftc")
    rc, out = sandbox("toolchain", "status")
    assert rc == 0 and f"Docker image {IMAGE}" in out and f"not used: swiftc on PATH ({old}) is Swift version 6.1" in out, out

    on_path = fake_toolchain(tmp_path / "onpath", VERSION)
    (tmp_path / "bin" / "swiftc").unlink()
    sandbox.put_on_path("swiftc", on_path / "bin" / "swiftc")
    rc, out = sandbox("toolchain", "which")
    assert rc == 0 and out.strip() == f"local {VERSION} {on_path}", out

    swiftly = fake_toolchain(tmp_path / "swiftly" / VERSION, VERSION)   # swiftly's comes before PATH's
    rc, out = sandbox("toolchain", "status")
    assert rc == 0 and out.startswith(f"Swift {VERSION}: local toolchain {swiftly} (swiftly)"), out

    mine = fake_toolchain(tmp_path / "mine", VERSION)          # ISIM_SWIFT_TOOLCHAIN first: the toolchain or its usr/
    for given in (mine.parent, mine):
        rc, out = sandbox("toolchain", "which", ISIM_SWIFT_TOOLCHAIN=str(given))
        assert rc == 0 and out.strip() == f"local {VERSION} {mine}", out
    rc, out = sandbox("toolchain", "which", ISIM_SWIFT_TOOLCHAIN="docker")
    assert rc == 0 and out.strip() == f"docker {VERSION} {IMAGE}", out

    for bad, msg in ((old.parent, "is Swift version 6.1 (swift-6.1-RELEASE); isim needs Swift 6.2.4 exactly"),
                     (tmp_path / "nothing", "is not a Swift toolchain")):
        rc, out = sandbox("toolchain", "which", ISIM_SWIFT_TOOLCHAIN=str(bad))
        assert rc == 1 and msg in out, out
        rc, out = sandbox("swiftc", "-c", "x.swift", ISIM_SWIFT_TOOLCHAIN=str(bad))   # isim swiftc uses the same choice
        assert rc == 1 and msg in out, out


def local_toolchain():
    """the local Swift 6.2.4 toolchain `isim toolchain` finds here (its usr directory), or None"""
    env = {k: v for k, v in os.environ.items() if k != "ISIM_SWIFT_TOOLCHAIN"}
    if os.environ.get("ISIM_SWIFT_TOOLCHAIN", "docker") != "docker":
        env["ISIM_SWIFT_TOOLCHAIN"] = os.environ["ISIM_SWIFT_TOOLCHAIN"]
    out = subprocess.run([str(ISIM), "toolchain", "which"], env=env, capture_output=True, text=True).stdout.split()
    return out[2] if out and out[0] == "local" else None


def need_both():
    if not (SDK / "usr/lib/swift/SwiftUI.swiftmodule").is_dir():
        pytest.skip("the SDK's Swift overlays are not built")
    tc = local_toolchain()
    if not tc:
        pytest.skip(f"no local Swift {VERSION} toolchain (isim toolchain install)")
    if not shutil.which("docker") or subprocess.run(["docker", "image", "inspect", IMAGE], capture_output=True).returncode:
        pytest.skip(f"no Docker image {IMAGE}")
    return tc


SOURCE = """import SwiftUI

struct ProbeView: View {
    @State private var count = 0
    var body: some View { Button("Count \\(count)") { count += 1 } }
}

#Preview { ProbeView() }

@main struct ProbeApp: App { var body: some Scene { WindowGroup { ProbeView() } } }
"""


def symbols(obj: Path):
    nm = shutil.which("llvm-nm") or shutil.which("nm")
    return subprocess.run([nm, "-j", str(obj)], capture_output=True, text=True, check=True).stdout.split()


def test_local_compiles_like_docker(tmp_path):
    """the same compile with the local toolchain and in the image: the same object (the compiler leaves 16 bytes that
    differ from run to run even with one toolchain, so the symbols and the size are compared), #Preview's macro plugin
    loaded by both"""
    tc = need_both()
    src = tmp_path / "Probe.swift"
    src.write_text(SOURCE)
    objs = {}
    for mode in (tc, "docker"):
        o = tmp_path / ("docker.o" if mode == "docker" else "local.o")
        p = subprocess.run([str(ISIM), "swiftc", "-parse-as-library", "-module-name", "Probe", "-c", str(src), "-o", str(o)],
                           cwd=tmp_path, env=dict(os.environ, ISIM_SWIFT_TOOLCHAIN=mode), capture_output=True, text=True,
                           timeout=600)
        assert p.returncode == 0, p.stdout + p.stderr
        objs[mode] = o
    local, docker = objs[tc], objs["docker"]
    assert local.stat().st_size == docker.stat().st_size
    assert symbols(local) == symbols(docker)
    assert any("Preview" in s for s in symbols(local)), "the #Preview macro expanded"


def docker_sees(path: Path):
    """whether the Docker daemon sees this host path (not when the tests run in a container that shares only the
    workspace with the host's Docker, as on CI)"""
    marker = path / ".isim-docker-probe"
    marker.write_text("x")
    r = subprocess.run(["docker", "run", "--rm", "--mount", f"type=bind,src={path},dst=/probe,readonly", IMAGE,
                        "cat", "/probe/.isim-docker-probe"], capture_output=True, text=True)
    marker.unlink()
    return r.returncode == 0 and r.stdout == "x"


def test_relative_output_outside_workspace():
    """`isim swiftc -o rel.o` in a folder outside the isim tree: the image's container mounts that folder writable
    (it mounted only absolute output paths writable before), and the local toolchain needs no mounts at all"""
    if not (SDK / "usr/lib/swift/Swift.swiftmodule").is_dir():
        pytest.skip("the SDK's Swift modules are not built")
    with tempfile.TemporaryDirectory(prefix="isim-swiftc-") as d:
        d = Path(d)
        (d / "Rel.swift").write_text("public func rel() -> Int { 7 }\n")
        modes = [m for m in (local_toolchain(), "docker") if m]
        if "docker" in modes and not (shutil.which("docker") and docker_sees(d)):
            modes.remove("docker")
        if not modes:
            pytest.skip("neither a local Swift toolchain nor a Docker daemon that sees this folder")
        for mode in modes:
            p = subprocess.run([str(ISIM), "swiftc", "-parse-as-library", "-c", "Rel.swift", "-o", "rel.o"], cwd=d,
                               env=dict(os.environ, ISIM_SWIFT_TOOLCHAIN=mode), capture_output=True, text=True, timeout=600)
            assert p.returncode == 0 and (d / "rel.o").is_file(), (mode, p.stdout + p.stderr)
            (d / "rel.o").unlink()


@pytest.mark.parametrize("mode", ["local", "docker"])
def test_build_with_toolchain(mode, launch, device_data, tmp_path):
    """isim build of HelloToolchain (local packages read from their Package.swift, a package macro target built as a
    compiler plugin) with each toolchain, and the app runs"""
    need_apps("HelloToolchain")
    tc = need_both()
    work = tmp_path / "work"
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_SWIFT_TOOLCHAIN=tc if mode == "local" else "docker")
    with exclusive("toolchain-build"):
        p = subprocess.run([str(ISIM), "build", "-project", "HelloToolchain.xcodeproj", "-target", "HelloToolchain",
                            "-o", str(work)], cwd=ROOT / "samples/HelloToolchain", env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, errors="replace", timeout=1800)
    assert p.returncode == 0, p.stdout[-3000:]
    assert "macro target, built as a compiler plugin" in p.stdout, p.stdout[-3000:]
    app = launch(work / "HelloToolchain.app")
    app.wait_log(r"HelloToolchain macros: Model\.mathKitSum\(\) \* 2 = 10, 3 flavors")
    app.quit()
