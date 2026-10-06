#!/usr/bin/env bash
# Build HelloTextEditing.app (Swift: selection, edit menu, marked text, keyboards, spelling) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloTextEditing: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloTextEditing.app; obj=$(realpath -m ../../out/swift/obj/HelloTextEditing.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloTextEditing -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloTextEditing"
cp Info.plist "$out/"
echo "built $out"
