#!/usr/bin/env bash
# Build HelloCounterSwift.app (Swift + UIKit) for the isim simulator. Needs the swift:6.2 image (see swift/build.sh).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloCounterSwift: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloCounterSwift.app; obj=$(realpath -m ../../out/swift/obj/HelloCounterSwift.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCounterSwift -parse-as-library -wmo -c HelloCounterSwift/*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCounterSwift"
cp HelloCounterSwift/Info.plist "$out/"
echo "built $out"
