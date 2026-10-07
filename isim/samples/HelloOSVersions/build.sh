#!/usr/bin/env bash
# Build HelloOSVersions.app (Swift UIKit + SwiftUI, an Objective-C availability helper) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloOSVersions: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloOSVersions.app
obj=$(realpath -m ../../out/swift/obj/HelloOSVersions.o); objc=$(realpath -m ../../out/swift/obj/HelloOSVersionsObjC.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloOSVersions -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc -c HelloOSVersionsObjC.m -o "$objc"
"$isim" cc "$obj" "$objc" -o "$out/HelloOSVersions" -framework Foundation
cp Info.plist "$out/"
echo "built $out"
