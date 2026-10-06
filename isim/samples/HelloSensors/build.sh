#!/usr/bin/env bash
# Build HelloSensors.app (Core Motion, Core Bluetooth, Core NFC, HealthKit). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftHealthKit.dylib ] || { echo "HelloSensors: skipped (HealthKit not built)"; exit 0; }
out=${1:?output dir}/HelloSensors.app; obj=$(realpath -m ../../out/swift/obj/HelloSensors.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSensors -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSensors"
cp Info.plist "$out/"
echo "built $out"
