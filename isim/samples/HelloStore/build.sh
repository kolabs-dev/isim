#!/usr/bin/env bash
# Build HelloStore.app (StoreKit 2 + StoreKit 1 + StoreKit views, local StoreKit testing). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftStoreKit.dylib ] || { echo "HelloStore: skipped (StoreKit not built)"; exit 0; }
out=${1:?output dir}/HelloStore.app; obj=$(realpath -m ../../out/swift/obj/HelloStore.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloStore -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloStore"
cp Info.plist "$out/"
cp HelloStore.storekit "$out/isim-StoreKitConfiguration.storekit"   # what `isim build` does with a scheme's StoreKit configuration
echo "built $out"
