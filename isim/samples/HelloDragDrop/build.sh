#!/usr/bin/env bash
# Build HelloDragDrop.app (Swift: drag and drop interactions, table reordering, SwiftUI draggable) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloDragDrop: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloDragDrop.app; obj=$(realpath -m ../../out/swift/obj/HelloDragDrop.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloDragDrop -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloDragDrop"
cp Info.plist "$out/"
echo "built $out"
