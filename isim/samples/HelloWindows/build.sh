#!/usr/bin/env bash
# Build HelloWindows.app (Swift UIKit, scene-based, multiple windows on iPad) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloWindows: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloWindows.app; obj=$(realpath -m ../../out/swift/obj/HelloWindows.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloWindows -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloWindows"
cp Info.plist "$out/"
echo "built $out"
