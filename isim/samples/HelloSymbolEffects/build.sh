#!/usr/bin/env bash
# Build HelloSymbolEffects.app (Swift UIKit: SF Symbols effects on image views) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloSymbolEffects: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloSymbolEffects.app; obj=$(realpath -m ../../out/swift/obj/HelloSymbolEffects.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSymbolEffects -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSymbolEffects"
cp Info.plist "$out/"
echo "built $out"
