#!/usr/bin/env bash
# Build HelloAnimations.app (Swift + UIViewPropertyAnimator, keyframes, transitions) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloAnimations: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloAnimations.app; obj=$(realpath -m ../../out/swift/obj/HelloAnimations.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloAnimations -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloAnimations"
cp Info.plist "$out/"
echo "built $out"
