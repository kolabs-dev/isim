#!/usr/bin/env bash
# Build tests/objc-runtime: ObjCRuntimeTest.app (forwarding, NSInvocation, NSProxy, @try/@catch/@finally),
# ObjCUncaught.app and SwiftUncaught.app (uncaught exception termination, mode = first argument).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
out=${1:?output dir}
mkdir -p "$out/ObjCRuntimeTest.app" "$out/ObjCUncaught.app"
"${ISIM_CC:-clang}" -target x86_64-apple-ios15.0-simulator -isysroot "$ISIM_SDK" -fuse-ld=lld \
    -fobjc-arc -fobjc-arc-exceptions -O1 -Wall main.m -framework Foundation -framework CoreGraphics -o "$out/ObjCRuntimeTest.app/ObjCRuntimeTest"
cp Info.plist "$out/ObjCRuntimeTest.app/"
"${ISIM_CC:-clang}" -target x86_64-apple-ios15.0-simulator -isysroot "$ISIM_SDK" -fuse-ld=lld \
    -fobjc-arc -O1 -Wall uncaught.m -framework Foundation -o "$out/ObjCUncaught.app/ObjCUncaught"
sed 's/objc-runtime-test/objc-uncaught/; s/>ObjCRuntimeTest</>ObjCUncaught</' Info.plist > "$out/ObjCUncaught.app/Info.plist"
# Swift caller (needs the Swift toolchain built by swift/build.sh)
isim=$ISIM_SDK/../bin/isim
if [ -x "$isim" ] && [ -d "$ISIM_SDK/usr/lib/swift" ]; then
  mkdir -p "$out/SwiftUncaught.app" "$ISIM_SDK/../swift"
  "$isim" swiftc -parse-as-library -c uncaught.swift -o "$ISIM_SDK/../swift/swift-uncaught.o"
  "$isim" cc "$ISIM_SDK/../swift/swift-uncaught.o" -o "$out/SwiftUncaught.app/SwiftUncaught"
  sed 's/objc-runtime-test/swift-uncaught/; s/>ObjCRuntimeTest</>SwiftUncaught</' Info.plist > "$out/SwiftUncaught.app/Info.plist"
fi
