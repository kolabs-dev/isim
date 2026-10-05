#!/usr/bin/env bash
# Swift for isim. Requires the swift:6.2 Docker image (Swift 6.2.4) and the pinned sources from
# fetch-sources.sh (third_party/swift @ swift-6.2.4-RELEASE, third_party/llvm-project @ llvmorg-22.1.8).
# Stage 1 (Embedded):  out/swift/embedded/Swift.swiftmodule, libswiftEmbeddedSupport.a, SwiftEmbeddedTest.app
# Stage 2 (full):      SDK /usr/lib/libc++.1.dylib, /usr/lib/swift/libswiftCore.dylib + Swift.swiftmodule,
#                      SwiftFullTest.app
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v docker >/dev/null && docker image inspect swift:6.2 >/dev/null 2>&1 || { echo "swift: skipped (docker image swift:6.2 not available)"; exit 0; }
[ -d ../../third_party/swift/stdlib ] || { echo "swift: skipped (third_party/swift missing; see docs/swift-plan.md)"; exit 0; }
mod=../out/swift/embedded/Swift.swiftmodule/x86_64-apple-ios-simulator.swiftmodule
if [ ! -f "$mod" ] || [ build-stdlib.py -nt "$mod" ]; then
  SWIFTC="./swiftc-docker swiftc" python3 build-stdlib.py
fi
full=../out/swift/full/swiftCore.o
if [ ! -f "$full" ] || [ build-stdlib.py -nt "$full" ]; then
  SWIFTC="./swiftc-docker swiftc" python3 build-stdlib.py --full
fi
./build-embedded-support.sh
../out/bin/isim swiftc -embedded -c ../tests/swift-embedded/main.swift -o ../out/swift/emb-test.o
mkdir -p ../out/apps/SwiftEmbeddedTest.app
../out/bin/isim cc ../out/swift/emb-test.o ../out/swift/libswiftEmbeddedSupport.a -o ../out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest
echo "built ../out/apps/SwiftEmbeddedTest.app"

# stage 2: full Swift
./build-libcxx.sh
./build-runtime.sh | tail -1
[ ! -s ../out/swift/runtime-failures.txt ] || { echo "swift runtime: some files failed to compile"; cat ../out/swift/runtime-failures.txt; exit 1; }
./build-swiftcore.sh
../out/bin/isim swiftc -parse-as-library -c ../tests/swift-full/main.swift -o ../out/swift/full-test.o
mkdir -p ../out/apps/SwiftFullTest.app
../out/bin/isim cc ../out/swift/full-test.o -o ../out/apps/SwiftFullTest.app/SwiftFullTest
echo "built ../out/apps/SwiftFullTest.app"
