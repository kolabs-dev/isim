#!/usr/bin/env bash
# Build HelloKeys.app (Swift + SwiftUI keyboard, focus, inspector) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloKeys: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloKeys.app; obj=$(realpath -m ../../out/swift/obj/HelloKeys.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloKeys -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloKeys"
cp Info.plist "$out/"
echo "built $out"
