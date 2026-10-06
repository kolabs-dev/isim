#!/usr/bin/env bash
# Build HelloRotation.app (Swift + rotation) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloRotation: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloRotation.app; obj=$(realpath -m ../../out/swift/obj/HelloRotation.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloRotation -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloRotation"
cp Info.plist "$out/"
echo "built $out"
