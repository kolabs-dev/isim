#!/usr/bin/env bash
# Build HelloMultiTouch.app (Swift: pinch, rotation, two-finger pan, zooming, hover, pointer) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloMultiTouch: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloMultiTouch.app; obj=$(realpath -m ../../out/swift/obj/HelloMultiTouch.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloMultiTouch -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloMultiTouch"
cp Info.plist "$out/"
echo "built $out"
