#!/usr/bin/env bash
# Build HelloCharts.app (SwiftUI on isim's SwiftUI implementation). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCharts.dylib ] || { echo "HelloCharts: skipped (Charts not built)"; exit 0; }
out=${1:?output dir}/HelloCharts.app; obj=$(realpath -m ../../out/swift/obj/HelloCharts.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCharts -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCharts"
cp Info.plist "$out/"
echo "built $out"
