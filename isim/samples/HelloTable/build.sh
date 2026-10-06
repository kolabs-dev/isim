#!/usr/bin/env bash
# Build HelloTable.app (Swift + UITableView) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloTable: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloTable.app; obj=$(realpath -m ../../out/swift/obj/HelloTable.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloTable -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloTable"
cp Info.plist "$out/"
echo "built $out"
