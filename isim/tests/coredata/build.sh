#!/usr/bin/env bash
# Build CoreDataTest.app: the Core Data self-test, with TestModel.xcdatamodeld compiled by isim momc (isim's model
# format + Xcode-style generated classes). Needs the Swift toolchain (swift:6.2 image).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCoreData.dylib ] || { echo "CoreDataTest: skipped (Swift overlays not built)"; exit 0; }
out=${1:?output dir}/CoreDataTest.app; obj=$(realpath -m ../../out/swift/obj/CoreDataTest.o); gen=$(realpath -m ../../out/swift/obj/CoreDataTest-codegen)
rm -rf "$out" "$gen"; mkdir -p "$out" "$(dirname "$obj")"
python3 ../../tools/momc.py TestModel.xcdatamodeld "$out" --swift-codegen "$gen"
"$isim" swiftc -module-name CoreDataTest -parse-as-library -wmo -c ./*.swift "$gen"/*.swift -o "$obj"
"$isim" cc "$obj" -framework Foundation -framework CoreData -o "$out/CoreDataTest"
cp Info.plist "$out/"
echo "built $out"
