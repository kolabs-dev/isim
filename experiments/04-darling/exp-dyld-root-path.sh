#!/usr/bin/env bash
# Exp A/B: set DYLD_ROOT_PATH without providing dyld_sim; observe how far Darling's host dyld gets.
set -uo pipefail
docker exec darling-eval-run bash -c '
for root in /nonexistent-simroot /; do
 for b in hello.sim hello.sim.chained; do
  echo "== DYLD_ROOT_PATH=$root $b"
  timeout 60 darling shell env DYLD_ROOT_PATH=$root DYLD_PRINT_LIBRARIES=1 /Volumes/SystemRoot/inputs/$b; echo "rc=$?"
 done
done
echo "== DYLD_FORCE_PLATFORM=2 hello.sim (no root path)"
timeout 60 darling shell env DYLD_FORCE_PLATFORM=2 /Volumes/SystemRoot/inputs/hello.sim; echo "rc=$?"
' 2>&1
