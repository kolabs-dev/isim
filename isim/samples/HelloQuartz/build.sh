#!/usr/bin/env bash
# Build HelloQuartz.app (Core Graphics, Core Text, PDF) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloQuartz: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloQuartz.app; obj=$(realpath -m ../../out/swift/obj/HelloQuartz.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloQuartz -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloQuartz"
cp Info.plist "$out/"
echo "built $out"
