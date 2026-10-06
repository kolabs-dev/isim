#!/usr/bin/env bash
# Build HelloSwiftUIGestures.app (SwiftUI: magnify, rotate, sequenced, exclusive gestures, @GestureState) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloSwiftUIGestures: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloSwiftUIGestures.app; obj=$(realpath -m ../../out/swift/obj/HelloSwiftUIGestures.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSwiftUIGestures -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSwiftUIGestures"
cp Info.plist "$out/"
echo "built $out"
