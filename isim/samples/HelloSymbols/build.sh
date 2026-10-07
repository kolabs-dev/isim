#!/usr/bin/env bash
# Build HelloSymbols.app (SF Symbol stand-ins: variants, weight, scale, tint) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloSymbols: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloSymbols.app; obj=$(realpath -m ../../out/swift/obj/HelloSymbols.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSymbols -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSymbols"
cp Info.plist "$out/"
echo "built $out"
