#!/usr/bin/env bash
# Build HelloTransitions.app (Swift + presentations, transitions, containers) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloTransitions: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloTransitions.app; obj=$(realpath -m ../../out/swift/obj/HelloTransitions.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloTransitions -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloTransitions"
cp Info.plist "$out/"
echo "built $out"
