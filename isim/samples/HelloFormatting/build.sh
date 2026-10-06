#!/usr/bin/env bash
# Build HelloFormatting.app (Foundation formatting + Swift Regex sample). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloFormatting: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloFormatting.app; obj=$(realpath -m ../../out/swift/obj/HelloFormatting.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloFormatting -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloFormatting"
cp Info.plist "$out/"
echo "built $out"
