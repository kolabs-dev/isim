#!/usr/bin/env bash
# Build HelloImaging.app (ImageIO, Core Image, UIImage extras) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloImaging: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloImaging.app; obj=$(realpath -m ../../out/swift/obj/HelloImaging.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloImaging -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloImaging"
cp Info.plist "$out/"
echo "built $out"
