#!/usr/bin/env bash
# Build HelloImages.app (Swift + offscreen drawing, attributed text) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloImages: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloImages.app; obj=$(realpath -m ../../out/swift/obj/HelloImages.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloImages -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloImages"
cp Info.plist "$out/"
echo "built $out"
