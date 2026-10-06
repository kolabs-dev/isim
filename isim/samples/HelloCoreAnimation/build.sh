#!/usr/bin/env bash
# Build HelloCoreAnimation.app (Core Animation layers, CA animations, 3D, masks, UIKit Dynamics, CoreHaptics) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloCoreAnimation: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloCoreAnimation.app; obj=$(realpath -m ../../out/swift/obj/HelloCoreAnimation.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCoreAnimation -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCoreAnimation"
cp Info.plist "$out/"
echo "built $out"
