#!/usr/bin/env bash
# Build HelloLocation.app (Core Location: permission alert, simulated location, geocoding, regions). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCoreLocation.dylib ] || { echo "HelloLocation: skipped (CoreLocation not built)"; exit 0; }
out=${1:?output dir}/HelloLocation.app; obj=$(realpath -m ../../out/swift/obj/HelloLocation.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloLocation -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloLocation"
cp Info.plist "$out/"
echo "built $out"
