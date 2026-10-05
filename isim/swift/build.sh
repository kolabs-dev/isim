#!/usr/bin/env bash
# Swift for isim (stage 1: Embedded Swift). Requires the swift:6.2 Docker image (Swift 6.2.4)
# and third_party/swift at swift-6.2.4-RELEASE. Builds:
#   out/swift/embedded/Swift.swiftmodule/x86_64-apple-ios-simulator.swiftmodule
#   out/swift/libswiftEmbeddedSupport.a   (Unicode data tables + float printing)
#   out/apps/SwiftEmbeddedTest.app        (tests/swift-embedded)
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v docker >/dev/null && docker image inspect swift:6.2 >/dev/null 2>&1 || { echo "swift: skipped (docker image swift:6.2 not available)"; exit 0; }
[ -d ../../third_party/swift/stdlib ] || { echo "swift: skipped (third_party/swift missing; see docs/swift-plan.md)"; exit 0; }
mod=../out/swift/embedded/Swift.swiftmodule/x86_64-apple-ios-simulator.swiftmodule
if [ ! -f "$mod" ] || [ build-embedded-stdlib.py -nt "$mod" ]; then
  SWIFTC="./swiftc-docker swiftc" python3 build-embedded-stdlib.py
fi
./build-embedded-support.sh
../out/bin/isim swiftc -embedded -c ../tests/swift-embedded/main.swift -o ../out/swift/emb-test.o
mkdir -p ../out/apps/SwiftEmbeddedTest.app
../out/bin/isim cc ../out/swift/emb-test.o ../out/swift/libswiftEmbeddedSupport.a -o ../out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest
echo "built ../out/apps/SwiftEmbeddedTest.app"
