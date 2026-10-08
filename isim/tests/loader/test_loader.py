"""Loader tests against isim's runtime: minimal Mach-O executables linked with LLVM and a self-authored libSystem
stub (no Apple SDK); `isim run` exit codes."""
import os
import subprocess
from pathlib import Path

import pytest
from isimtest import ISIM

HERE = Path(__file__).parent
CC = os.environ.get("CLANG", "clang")
LD = os.environ.get("LD64", "ld64.lld")
FLAGS = ["-ffreestanding", "-fno-builtin", "-O1", "-fno-stack-protector"]


@pytest.fixture(scope="module")
def binaries(tmp_path_factory):
    o = tmp_path_factory.mktemp("loader")

    def sh(*cmd):
        p = subprocess.run([str(c) for c in cmd], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        assert p.returncode == 0, f"{' '.join(map(str, cmd))}\n{p.stdout}"

    for src, target, obj in [("hello.c", "x86_64-apple-ios15.0-simulator", "hello.sim.o"),
                             ("hello.c", "arm64-apple-ios15.0", "hello.dev.o"),
                             ("unimpl.c", "x86_64-apple-ios15.0-simulator", "unimpl.sim.o"),
                             ("unimpl.c", "x86_64-apple-macos12.0", "unimpl.mac.o")]:
        sh(CC, "-target", target, *FLAGS, "-c", HERE / src, "-o", o / obj)
    tbd = HERE / "libSystem.tbd"
    sim = ["-arch", "x86_64", "-platform_version", "ios-simulator", "15.0", "0"]
    sh(LD, *sim, "-o", o / "hello.sim", o / "hello.sim.o", tbd)
    sh(LD, *sim, "-fixup_chains", "-o", o / "hello.sim.chained", o / "hello.sim.o", tbd)
    sh(LD, "-arch", "arm64", "-platform_version", "ios", "15.0", "0", "-o", o / "hello.dev", o / "hello.dev.o", tbd)
    sh(LD, *sim, "-o", o / "unimpl.sim", o / "unimpl.sim.o", tbd)
    sh(LD, "-arch", "x86_64", "-platform_version", "macos", "12.0", "0", "-o", o / "unimpl.macos", o / "unimpl.mac.o",
       tbd)
    return o


@pytest.mark.parametrize("binary,want", [
    ("hello.sim", 42),
    ("hello.sim.chained", 42),
    ("hello.dev", 127),        # arm64 device: refused
    ("unimpl.macos", 127),     # macOS platform: refused
    ("unimpl.sim", 134),       # unimplemented import: named trap + abort (SIGABRT=134)
])
def test_loader(binaries, device_data, binary, want):
    p = subprocess.run([str(ISIM), "run", str(binaries / binary)], env=dict(os.environ, ISIM_DATA=str(device_data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", timeout=60)
    got = 128 - p.returncode if p.returncode < 0 else p.returncode      # killed by a signal: the shell's 128+N
    assert got == want, f"{binary}: exit {got}, want {want}\n{p.stdout[-3000:]}"
