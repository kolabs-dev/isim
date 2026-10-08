#!/usr/bin/env bash
# Swift for isim. Requires the swift:6.2 Docker image (Swift 6.2.4) and the pinned sources from
# fetch-sources.sh (third_party/swift @ swift-6.2.4-RELEASE, third_party/llvm-project @ llvmorg-22.1.8).
# Stage 1 (Embedded):  out/swift/embedded/Swift.swiftmodule, libswiftEmbeddedSupport.a, SwiftEmbeddedTest.app
# Stage 2 (full):      SDK /usr/lib/libc++.1.dylib, /usr/lib/swift/libswiftCore.dylib + Swift.swiftmodule,
#                      SwiftFullTest.app
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v docker >/dev/null && docker image inspect swift:6.2 >/dev/null 2>&1 || { echo "swift: skipped (docker image swift:6.2 not available)"; exit 0; }
[ -d ../../third_party/swift/stdlib ] || { echo "swift: skipped (third_party/swift missing; run swift/fetch-sources.sh)"; exit 0; }
# Every step is skipped when its inputs (file contents) are unchanged since it last succeeded (tools/fresh.py).
F="python3 ../tools/fresh.py"
IMG=$(docker image inspect -f '{{.Id}}' swift:6.2)                    # the compiler
TP=$($F hash ../../third_party/swift ../../third_party/llvm-project ../../third_party/swift-experimental-string-processing)
INC=$($F hash ../out/sdk/usr/include ../out/sdk/SDKSettings.json)       # the C SDK the core compiles against
SDKLIB=../out/sdk/usr/lib/swift
$F run swift-core --in build-core.sh build-stdlib.py build-concurrency.py build-distributed.py build-embedded-support.sh \
    build-libcxx.sh build-runtime.sh build-swiftcore.sh build-observation.sh build-synchronization.sh build-onone.sh \
    build-string-processing.sh swiftc-docker gen-include gyb-support synchronization-support observation-support.c \
    swift_float_to_string.c ../tools/isim --key "$IMG" --key "$TP" --key "$INC" \
  --out ../out/swift/embedded/Swift.swiftmodule ../out/swift/libswiftEmbeddedSupport.a ../out/sdk/usr/lib/libc++.1.dylib \
    $SDKLIB/libswiftCore.dylib $SDKLIB/libswift_Concurrency.dylib $SDKLIB/libswiftObservation.dylib \
    $SDKLIB/libswiftSynchronization.dylib $SDKLIB/libswiftDistributed.dylib $SDKLIB/libswiftSwiftOnoneSupport.dylib \
    $SDKLIB/libswift_StringProcessing.dylib $SDKLIB/libswiftRegexBuilder.dylib ../out/swift/resource/shims \
  -- ./build-core.sh
./build-overlays.sh
CORE_IFACE=$($F hash $SDKLIB/Swift.swiftmodule $SDKLIB/_Concurrency.swiftmodule $SDKLIB/Foundation.swiftmodule \
  $SDKLIB/Dispatch.swiftmodule $SDKLIB/libswiftFoundation.dylib)
$F run swift-testing --in build-testing.sh testing ../../third_party/swift-testing --key "$IMG" --key "$CORE_IFACE" \
  --out $SDKLIB/libswiftTesting.dylib -- bash -c './build-testing.sh | tail -1'
# the Swift self-test apps (tests/swift-*): rebuilt when their source or the SDK's Swift interfaces change
IFACE=$($F hash $SDKLIB/*.swiftmodule ../out/sdk/usr/include ../tools/isim)
testapp() { # Name source-dir [swiftc flags...] -- builds out/apps/Name.app/Name
  local name=$1 dir=$2; shift 2
  $F run "app-$name" --in "../tests/$dir" --key "$IFACE" --key "$*" --out "../out/apps/$name.app/$name" -- bash -c '
    set -e; name=$1 dir=$2; shift 2
    ../out/bin/isim swiftc -parse-as-library "$@" -c "../tests/$dir/main.swift" -o "../out/swift/$dir-test.o"
    mkdir -p "../out/apps/$name.app"
    ../out/bin/isim cc "../out/swift/$dir-test.o" -o "../out/apps/$name.app/$name"
    echo "built ../out/apps/$name.app"' _ "$name" "$dir" "$@"
}
$F run app-SwiftEmbeddedTest --in ../tests/swift-embedded ../out/swift/embedded/Swift.swiftmodule \
    ../out/swift/libswiftEmbeddedSupport.a --key "$IMG" --out ../out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest -- bash -c '
  set -e
  ../out/bin/isim swiftc -embedded -c ../tests/swift-embedded/main.swift -o ../out/swift/emb-test.o
  mkdir -p ../out/apps/SwiftEmbeddedTest.app
  ../out/bin/isim cc ../out/swift/emb-test.o ../out/swift/libswiftEmbeddedSupport.a -o ../out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest
  echo "built ../out/apps/SwiftEmbeddedTest.app"'
testapp SwiftFullTest swift-full
testapp SwiftConcurrencyTest swift-concurrency
testapp SwiftFoundationTest swift-foundation
testapp SwiftLibrariesTest swift-libraries -enable-bare-slash-regex
