#!/usr/bin/env bash
# Build HelloCollection.app (Swift + UICollectionView) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloCollection: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloCollection.app; obj=$(realpath -m ../../out/swift/obj/HelloCollection.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCollection -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCollection"
cp Info.plist "$out/"
echo "built $out"
