#!/usr/bin/env bash
# Build HelloCounter.app for the isim iOS simulator (x86_64) with the clang driver + isim SDK.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
out=${1:?output dir}/HelloCounter.app
rm -rf "$out"; mkdir -p "$out"
"${ISIM_CC:-clang}" -target x86_64-apple-ios15.0-simulator -isysroot "$ISIM_SDK" -fuse-ld=lld \
    -fobjc-arc -O1 -Wall HelloCounter/*.m -framework UIKit -framework Foundation -o "$out/HelloCounter"
cp HelloCounter/Info.plist "$out/"
echo "built $out"
