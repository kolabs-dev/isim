#!/usr/bin/env python3
"""Rebuild the committed ABIProbe.app with an OLD isim release, e.g.:
  tests/abi/build_probe.py /path/to/isim-0.2.0-linux-x86_64
The committed binary is the test: do not rebuild it with the current SDK."""
import os
import shutil
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
rel = os.path.realpath(sys.argv[1]) if len(sys.argv) == 2 else sys.exit(__doc__)
isim = os.path.join(rel, "bin", "isim")
out = os.path.join(here, "ABIProbe.app")
obj = os.path.realpath(os.path.join(rel, "..", "abiprobe-obj", "ABIProbe.o"))   # the release's swiftc writes only inside its workspace
os.makedirs(os.path.dirname(obj), exist_ok=True)
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)
subprocess.run([isim, "swiftc", "-module-name", "ABIProbe", "-parse-as-library", "-wmo", "-c", "ABIProbe/main.swift", "-o", obj],
               cwd=here, check=True)
subprocess.run([isim, "cc", obj, "-o", os.path.join(out, "ABIProbe")], cwd=here, check=True)
shutil.copy(os.path.join(here, "ABIProbe", "Info.plist"), out)
print(f"built {out} with", subprocess.run([isim, "version"], capture_output=True, text=True).stdout.strip())
