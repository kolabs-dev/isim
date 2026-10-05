#!/usr/bin/env bash
# Runs Darling (privileged container) basics + the three test binaries. Logs to logs/run-tests.log
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker run --rm --privileged --name darling-eval-run --tmpfs /root:exec,size=2g \
  -v "$PWD/inputs:/inputs:ro" darling-eval:60ba801 bash -c '
set -x
uname -a; dpkg -l | grep darling | awk "{print \$2, \$3}"
file /inputs/*
timeout 300 darling shell uname -a; echo "rc=$?"
timeout 120 darling shell sw_vers; echo "rc=$?"
timeout 60 darling shell /bin/echo hello-from-darling; echo "rc=$?"
for b in hello.sim hello.sim.chained hello.dev; do
  cp /inputs/$b /root/.darling/tmp/$b 2>/dev/null || cp /inputs/$b /root/$b
  timeout 60 darling shell /Volumes/SystemRoot/inputs/$b; echo "$b rc=$?"
done
' 2>&1
