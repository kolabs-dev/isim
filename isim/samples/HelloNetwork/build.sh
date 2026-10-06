#!/usr/bin/env bash
# Build HelloNetwork.app (URLSession, WebSocket, NWPathMonitor sample). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloNetwork: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloNetwork.app; obj=$(realpath -m ../../out/swift/obj/HelloNetwork.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloNetwork -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloNetwork"
cp Info.plist "$out/"
echo "built $out"
