#!/usr/bin/env bash
# Start the long-lived privileged container used by exp-*.sh. Stop with: docker rm -f darling-eval-run
# --privileged: Darling's setuid `darling` launcher unshares mount/UTS/IPC/PID namespaces and mounts an overlayfs prefix.
# --tmpfs /root: gives the DPREFIX (~/.darling) a tmpfs upper dir for its overlayfs (precaution; running without it was not tested).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker run -d --privileged --name darling-eval-run --tmpfs /root:exec,size=2g \
  -v "$PWD/inputs:/inputs:ro" darling-eval:60ba801 sleep infinity
