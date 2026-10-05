#!/usr/bin/env bash
# Exp C (control): copy of hello.sim relabelled to macOS -> does the rest of Darling's runtime work?
# Exp D (sim root): Darling's own usr/lib copied & relabelled to iOS-simulator, used via DYLD_ROOT_PATH,
#                   with the ORIGINAL unmodified hello.sim / hello.sim.chained.
# Neither is an iOS-compatibility success; they localise the failure.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
S=${SCRATCH:-$(mktemp -d)}; mkdir -p "$S/ctl" "$S/simroot/usr"
python3 machoplat.py 1 inputs/hello.sim         "$S/ctl/hello.sim.MACOS-CONTROL"
python3 machoplat.py 1 inputs/hello.sim.chained "$S/ctl/hello.sim.chained.MACOS-CONTROL"
docker cp -q darling-eval-run:/usr/libexec/darling/usr/lib "$S/simroot/usr/lib"
rm -rf "$S/simroot/usr/lib/"{darling,swift,groff,zsh,sasl2,pam,native}
python3 machoplat.py --tree 7 "$S/simroot"
docker exec darling-eval-run mkdir -p /opt/eval/ctl
docker cp -q "$S/ctl/." darling-eval-run:/opt/eval/ctl/
docker cp -q "$S/simroot" darling-eval-run:/opt/eval/simroot
du -sh "$S"; rm -rf "$S"
docker exec darling-eval-run bash -c '
for b in hello.sim.MACOS-CONTROL hello.sim.chained.MACOS-CONTROL; do
  echo "== CONTROL (relabelled macOS, not iOS): $b"
  timeout 60 darling shell /Volumes/SystemRoot/opt/eval/ctl/$b; echo "rc=$?"
done
for b in hello.sim hello.sim.chained; do
  echo "== SIMROOT (Darling libs relabelled iOS-sim) + original $b"
  timeout 60 darling shell env DYLD_ROOT_PATH=/Volumes/SystemRoot/opt/eval/simroot /Volumes/SystemRoot/inputs/$b; echo "rc=$?"
done
' 2>&1
