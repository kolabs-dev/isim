#!/usr/bin/env bash
# Build HelloConnections.app (Network framework, MultipeerConnectivity, URLSession challenges sample) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftMultipeerConnectivity.dylib ] || { echo "HelloConnections: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloConnections.app; obj=$(realpath -m ../../out/swift/obj/HelloConnections.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloConnections -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloConnections"
cp Info.plist "$out/"
echo "built $out"
