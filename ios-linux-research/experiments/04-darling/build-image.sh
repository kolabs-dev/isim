#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker build -t darling-eval:60ba801 . 2>&1 | tee logs/docker-build.log
