#!/usr/bin/env bash
# Build SwiftExtrasTest.app: Combine operators, Dispatch sources/IO/Data, Synchronization, Distributed actors.
# Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCombine.dylib ] || { echo "SwiftExtrasTest: skipped (Swift overlays not built)"; exit 0; }
out=${1:?output dir}/SwiftExtrasTest.app; obj=$(realpath -m ../../out/swift/obj/SwiftExtrasTest.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name SwiftExtrasTest -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -framework Foundation -o "$out/SwiftExtrasTest"
cp Info.plist "$out/"
echo "built $out"
