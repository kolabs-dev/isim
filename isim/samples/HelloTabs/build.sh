#!/usr/bin/env bash
# Build HelloTabs.app (Swift UIKit: iOS 18 tabs and sidebar, iOS 26 bars, update links, observation tracking) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloTabs: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloTabs.app; obj=$(realpath -m ../../out/swift/obj/HelloTabs.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloTabs -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloTabs"
cp Info.plist "$out/"
echo "built $out"
