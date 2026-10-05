#!/usr/bin/env bash
# Experiment 05: Objective-C (no Foundation, no SDK) for iOS simulator; run with ../03-loader/out/machoload
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p out
F=(-target x86_64-apple-ios15.0-simulator -ffreestanding -fno-builtin -O1 -fno-stack-protector -fobjc-runtime=ios-15.0)
for t in counter super; do
  clang "${F[@]}" -c $t.m -o out/$t.o
  ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -o out/$t out/$t.o ../02-link/libSystem.tbd libobjc.tbd
done
