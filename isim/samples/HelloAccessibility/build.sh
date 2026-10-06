#!/usr/bin/env bash
# Build HelloAccessibility.app (Swift: accessibility tree, VoiceOver, Dynamic Type, SwiftUI modifiers) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloAccessibility: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloAccessibility.app; obj=$(realpath -m ../../out/swift/obj/HelloAccessibility.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloAccessibility -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloAccessibility"
cp Info.plist "$out/"
echo "built $out"
