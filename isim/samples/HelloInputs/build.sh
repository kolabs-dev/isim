#!/usr/bin/env bash
# Build HelloInputs.app (Swift + UITextView, pickers, search, refresh, color well) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloInputs: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloInputs.app; obj=$(realpath -m ../../out/swift/obj/HelloInputs.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloInputs -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloInputs"
cp Info.plist "$out/"
echo "built $out"
