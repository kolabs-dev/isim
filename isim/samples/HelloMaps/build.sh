#!/usr/bin/env bash
# Build HelloMaps.app (MapKit sample) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftMapKit.dylib ] || { echo "HelloMaps: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloMaps.app; obj=$(realpath -m ../../out/swift/obj/HelloMaps.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloMaps -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloMaps"
cp Info.plist "$out/"
echo "built $out"
