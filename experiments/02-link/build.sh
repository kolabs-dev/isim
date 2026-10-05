#!/usr/bin/env bash
# Experiment 02: link minimal Mach-O executables for iOS simulator (x86_64) and device (arm64)
# using only LLVM + a self-authored libSystem stub. No Apple SDK.
# SDK version field is 0 (n/a): no Apple SDK is used, so none is claimed.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
CC=${CLANG:-clang}; LD=${LD64:-ld64.lld}
COMMON=(-ffreestanding -fno-builtin -O1 -fno-stack-protector)
mkdir -p out
"$CC" -target x86_64-apple-ios15.0-simulator "${COMMON[@]}" -c hello.c -o out/hello.sim.o
"$CC" -target arm64-apple-ios15.0           "${COMMON[@]}" -c hello.c -o out/hello.dev.o
"$LD" -arch x86_64 -platform_version ios-simulator 15.0 0 -o out/hello.sim out/hello.sim.o libSystem.tbd "$@"
"$LD" -arch x86_64 -platform_version ios-simulator 15.0 0 -fixup_chains -o out/hello.sim.chained out/hello.sim.o libSystem.tbd "$@"
"$LD" -arch arm64  -platform_version ios           15.0 0 -o out/hello.dev out/hello.dev.o libSystem.tbd "$@"
echo "link OK"
