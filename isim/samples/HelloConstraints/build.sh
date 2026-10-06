#!/usr/bin/env bash
# Build HelloConstraints.app (Swift + layout extras) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloConstraints: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloConstraints.app; obj=$(realpath -m ../../out/swift/obj/HelloConstraints.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloConstraints -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloConstraints"
cp Info.plist "$out/"
echo "built $out"
