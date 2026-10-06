#!/usr/bin/env bash
# Build HelloGameCenter.app (isim's local Game Center: GameKit). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftGameKit.dylib ] || { echo "HelloGameCenter: skipped (GameKit not built)"; exit 0; }
out=${1:?output dir}/HelloGameCenter.app; obj=$(realpath -m ../../out/swift/obj/HelloGameCenter.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloGameCenter -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloGameCenter"
cp Info.plist "$out/"
cp isim-GameCenter.json "$out/"   # what `isim build` does with an isim-GameCenter.json next to the .xcodeproj
echo "built $out"
