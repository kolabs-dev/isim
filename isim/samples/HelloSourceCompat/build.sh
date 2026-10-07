#!/usr/bin/env bash
# Build HelloSourceCompat.app (source-compatibility patterns found in real apps). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloSourceCompat: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloSourceCompat.app; obj=$(realpath -m ../../out/swift/obj/HelloSourceCompat.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSourceCompat -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSourceCompat"
cp Info.plist "$out/"
echo "built $out"
