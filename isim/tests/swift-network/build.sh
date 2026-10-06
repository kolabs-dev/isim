#!/usr/bin/env bash
# Build SwiftNetworkTest.app (networking self-test: URLSession against an in-process socket server). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftNetwork.dylib ] || { echo "SwiftNetworkTest: skipped (Swift overlays not built)"; exit 0; }
out=${1:?output dir}/SwiftNetworkTest.app; obj=$(realpath -m ../../out/swift/obj/SwiftNetworkTest.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name SwiftNetworkTest -parse-as-library -wmo -c main.swift -o "$obj"
"$isim" cc "$obj" -o "$out/SwiftNetworkTest"
cp Info.plist "$out/"
echo "built $out"
