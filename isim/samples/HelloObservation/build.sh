#!/usr/bin/env bash
# Build HelloObservation.app (SwiftUI on isim's SwiftUI implementation). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloObservation: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloObservation.app; obj=$(realpath -m ../../out/swift/obj/HelloObservation.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloObservation -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloObservation"
cp Info.plist "$out/"
echo "built $out"
