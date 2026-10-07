#!/usr/bin/env bash
# Build HelloBackground.app (background execution: suspension, background audio and location, haptics). Needs the
# swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAVFoundation.dylib ] || { echo "HelloBackground: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloBackground.app; obj=$(realpath -m ../../out/swift/obj/HelloBackground.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloBackground -parse-as-library -wmo -c HelloBackground.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloBackground"
cp Info.plist "$out/"
echo "built $out"
