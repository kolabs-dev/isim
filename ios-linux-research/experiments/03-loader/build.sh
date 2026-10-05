#!/usr/bin/env bash
# Build the Linux-native loader (host ELF). Guest binaries come from ../02-link.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p out
${CC:-clang} -O1 -g -Wall -Wextra -Wno-unused-parameter -o out/machoload machoload.c shims.c objc_rt.c -lpthread
echo "built out/machoload"
