#!/usr/bin/env bash
# Build HelloScenes.app (SwiftUI scenes, delegate adaptor, user activities, background tasks).
# Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCoreSpotlight.dylib ] || { echo "HelloScenes: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloScenes.app; obj=$(realpath -m ../../out/swift/obj/HelloScenes.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloScenes -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloScenes"
cp Info.plist "$out/"
echo "built $out"
