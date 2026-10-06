#!/usr/bin/env bash
# Build HelloDrawing.app (SwiftUI on isim's SwiftUI implementation). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloDrawing: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloDrawing.app; obj=$(realpath -m ../../out/swift/obj/HelloDrawing.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloDrawing -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloDrawing"
cp Info.plist "$out/"
echo "built $out"
