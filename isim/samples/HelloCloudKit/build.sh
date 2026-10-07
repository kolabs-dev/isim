#!/usr/bin/env bash
# Build HelloCloudKit.app (local CloudKit, NSPersistentCloudKitContainer, MetricKit). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCloudKit.dylib ] || { echo "HelloCloudKit: skipped (CloudKit not built)"; exit 0; }
out=${1:?output dir}/HelloCloudKit.app; obj=$(realpath -m ../../out/swift/obj/HelloCloudKit.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCloudKit -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCloudKit"
cp Info.plist "$out/"
echo "built $out"
