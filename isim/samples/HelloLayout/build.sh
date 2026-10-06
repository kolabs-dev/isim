#!/usr/bin/env bash
# Build HelloLayout.app (SwiftUI on isim's SwiftUI implementation). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloLayout: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloLayout.app; obj=$(realpath -m ../../out/swift/obj/HelloLayout.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloLayout -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloLayout"
cp Info.plist "$out/"
echo "built $out"
