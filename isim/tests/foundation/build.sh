#!/usr/bin/env bash
# Build tests/foundation as FoundationTest.app using the clang driver with the isim SDK as sysroot.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
out=${1:?output dir}/FoundationTest.app
mkdir -p "$out"
"${ISIM_CC:-clang}" -target x86_64-apple-ios15.0-simulator -isysroot "$ISIM_SDK" -fuse-ld=lld \
    -fobjc-arc -O1 -Wall main.m -framework Foundation -o "$out/FoundationTest"
cp Info.plist "$out/"
